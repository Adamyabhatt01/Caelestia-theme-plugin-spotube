import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../lib/theme_source.dart';

/// Installs a built theme into a Spotube profile.
///
/// The app has no command line, and the in-app upload is a file picker with a
/// dialog in the middle of it — fine for a user, slow for somebody editing a
/// theme. This writes the plugin where the app looks for it (the extraction
/// directory) and registers it in the profile's database, so a rebuild is one
/// command and a restart.
///
/// The app must not be running while this writes: the database is locked by
/// the app's own connection.
Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addMultiOption('theme', help: 'Theme id to install.', abbr: 't')
    ..addOption(
      'profile',
      help: 'Profile directory (the one with .local/share).',
      defaultsTo: '/tmp/spotube-bench-home',
    )
    ..addOption(
      'artifact',
      help: 'Install a built .smplug instead of a theme directory.',
    )
    ..addFlag(
      'select',
      help: 'Make the installed theme the default theme.',
      negatable: false,
    )
    ..addFlag('dry-run', help: 'Print what would happen.', negatable: false);

  final options = parser.parse(arguments);
  final profile = options['profile'] as String;
  final dataDir = Directory(p.join(profile, '.local', 'share', 'oss.krtirtho.spotube'));
  final pluginsDir = Directory(p.join(dataDir.path, 'metadata-plugins'));
  final dbFile = File(p.join(dataDir.path, 'db.sqlite'));

  final artifact = options['artifact'] as String?;
  final themes = <_Installable>[];

  if (artifact != null) {
    themes.add(_Installable.fromArchive(File(artifact)));
  } else {
    final selected = options['theme'] as List<String>;
    if (selected.isEmpty) {
      stderr.writeln('nothing to install: pass --theme <id> or --artifact <file>');
      exitCode = 64;
      return;
    }
    for (final theme in loadThemes(p.dirname(p.dirname(p.absolute(Platform.script.toFilePath()))))) {
      if (!selected.contains(theme.id)) continue;
      final built = File(p.join(
        p.dirname(p.dirname(p.absolute(Platform.script.toFilePath()))),
        'dist',
        theme.artifactName,
      ));
      if (!built.existsSync()) {
        stderr.writeln('${theme.id}: no build at ${built.path} — run the build first');
        exitCode = 66;
        return;
      }
      themes.add(_Installable.fromArchive(built));
    }
  }

  for (final installable in themes) {
    _install(installable, pluginsDir, dbFile, options);
  }
}

/// One theme ready to be written into a profile.
class _Installable {
  _Installable({
    required this.manifest,
    required this.entries,
  });

  final Map<String, dynamic> manifest;

  /// Archive entries, by name.
  final Map<String, List<int>> entries;

  String get name => manifest['name'] as String;

  String get author => manifest['author'] as String;

  String get version => manifest['version'] as String;

  String get entryPoint => manifest['entryPoint'] as String;

  List<String> get abilities => [
        for (final ability in (manifest['abilities'] as List? ?? const []))
          '$ability',
      ];

  List<String> get apis => [
        for (final api in (manifest['apis'] as List? ?? const [])) '$api',
      ];

  /// The directory the app extracts this plugin into.
  ///
  /// The host's own rule: `<author>-<name>-<version>`, each name sanitized
  /// the way `ServiceUtils.sanitizeFilename` does it.
  String get extractionDirName =>
      '${_sanitizeFilename(author)}-${_sanitizeFilename(name)}-$version';

  static _Installable fromArchive(File archive) {
    final zip = ZipDecoder().decodeBytes(archive.readAsBytesSync());
    final manifestEntry = zip.firstWhere(
      (file) => file.isFile && file.name == 'plugin.json',
      orElse: () => throw StateError('${archive.path} has no plugin.json'),
    );
    final manifest = jsonDecode(
      utf8.decode(manifestEntry.content as List<int>),
    ) as Map<String, dynamic>;

    return _Installable(
      manifest: manifest,
      entries: {
        for (final file in zip)
          if (file.isFile) file.name: file.content as List<int>,
      },
    );
  }
}

/// Writes the plugin files and registers it in the database.
void _install(
  _Installable installable,
  Directory pluginsDir,
  File dbFile,
  ArgResults options,
) {
  final target = Directory(p.join(pluginsDir.path, installable.extractionDirName));

  if (options['dry-run'] as bool) {
    stdout.writeln('would write ${target.path}');
    stdout.writeln('would register ${installable.name} ${installable.version} '
        '(${installable.author}) in ${dbFile.path}');
    return;
  }

  target.createSync(recursive: true);
  for (final entry in installable.entries.entries) {
    final file = File(p.join(target.path, entry.key));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(entry.value);
  }

  if (!dbFile.existsSync()) {
    stderr.writeln('no database at ${dbFile.path} — the plugin files are in '
        'place, but the app will not list the plugin until it is registered');
    exitCode = 69;
    return;
  }

  final database = sqlite3.open(dbFile.path);
  try {
    database.execute('PRAGMA busy_timeout = 2000');
    final existing = database.select(
      'SELECT id FROM plugins_table WHERE name = ? AND author = ?',
      [installable.name, installable.author],
    );

    final values = {
      'name': installable.name,
      'description': installable.manifest['description'] as String? ?? '',
      'version': installable.version,
      'author': installable.author,
      'entry_point': installable.entryPoint,
      'apis': jsonEncode(installable.apis),
      'abilities': jsonEncode(installable.abilities),
      'selected_for_metadata': 0,
      'selected_for_audio_source': 0,
      'selected_for_theme': 0,
      'selected_for_radio': 0,
      'repository': installable.manifest['repository'],
      'plugin_api_version':
          installable.manifest['pluginApiVersion'] as String? ?? '2.0.0',
    };

    if (existing.isEmpty) {
      final columns = values.keys.toList();
      database.execute(
        'INSERT INTO plugins_table (${columns.join(', ')}) '
        'VALUES (${columns.map((_) => '?').join(', ')})',
        columns.map((column) => values[column]).toList(),
      );
    } else {
      final id = existing.first['id'];
      database.execute(
        'UPDATE plugins_table SET '
        '${values.keys.map((key) => '$key = ?').join(', ')} WHERE id = ?',
        [...values.values, id],
      );
    }

    if (options['select'] as bool) {
      database.execute('UPDATE plugins_table SET selected_for_theme = 0');
      database.execute(
        'UPDATE plugins_table SET selected_for_theme = 1 WHERE name = ? AND author = ?',
        [installable.name, installable.author],
      );
    }

    stdout.writeln('installed ${installable.name} ${installable.version} '
        '(${installable.author}) → ${target.path}');
  } finally {
    database.dispose();
  }
}

/// The host's filename sanitizer, mirrored so the extraction directory name
/// matches what the app computes.
String _sanitizeFilename(String input) {
  var result = input
      .replaceAll(RegExp(r'[\/\?<>\\:\*\|"]'), '')
      .replaceAll(RegExp(r'[\x00-\x1f\x80-\x9f]'), '')
      .replaceFirst(RegExp(r'^\.+$'), '')
      .replaceFirst(
        RegExp(r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])(\..*)?$',
            caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'[\. ]+$'), '');
  if (result.length > 255) result = result.substring(0, 255);
  return result;
}
