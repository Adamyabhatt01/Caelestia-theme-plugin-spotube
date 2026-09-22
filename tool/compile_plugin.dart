import 'dart:io';

import 'package:hetu_script/hetu_script.dart';

/// Compiles one Hetu source file into the bytecode Spotube loads as
/// `plugin.out`.
///
///   dart run compile_plugin.dart <source.ht> <out> [sourceName]
void main(List<String> args) async {
  if (args.length < 2) {
    stderr.writeln(
      'usage: dart run compile_plugin.dart <source.ht> <out> [sourceName]',
    );
    exit(64);
  }

  final sourcePath = args[0];
  final source = File(sourcePath).readAsStringSync();
  // The name is baked into the bytecode, so it has to stay stable across
  // rebuilds or every diff of plugin.out looks like a real change.
  final sourceName = args.length > 2 ? args[2] : 'caelestia_theme';

  final hetu = Hetu();
  hetu.init();
  final bytes = hetu.compile(source, sourceName: sourceName);
  if (bytes.isEmpty) {
    stderr.writeln('COMPILE FAILED (empty bytecode)');
    exit(1);
  }

  File(args[1]).writeAsBytesSync(bytes);
  stdout.writeln('COMPILED ${bytes.length} bytes -> ${args[1]}');
}
