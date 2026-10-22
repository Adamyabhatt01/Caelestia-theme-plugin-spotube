import 'dart:convert';
import 'dart:io';

import 'package:spotube_themes/compile.dart';
import 'package:spotube_themes/theme_source.dart';
import 'package:spotube_themes/validator.dart';
import 'package:test/test.dart';

/// The repository root, from the test's own location.
final repoRoot = Directory.current.path;

Map<String, dynamic> readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('the golden payloads', () {
    test('every theme has one', () {
      final themes = loadThemes(repoRoot);
      expect(themes, isNotEmpty);

      for (final theme in themes) {
        expect(
          File('$repoRoot/conformance/${theme.id}.json').existsSync(),
          isTrue,
          reason: '${theme.id} has no golden payload — run tools/export.dart',
        );
      }
    });

    test('they are what the themes actually produce', () async {
      for (final theme in loadThemes(repoRoot)) {
        final byteCode = compileThemeSource(
          theme.source,
          sourceName: '${theme.id}_theme',
        );
        final compiled = await evaluateTheme(
          byteCode,
          entryPoint: theme.entryPoint,
        );

        expect(
          compiled.payload,
          equals(readJson('$repoRoot/conformance/${theme.id}.json')),
          reason: '${theme.id} changed — regenerate with tools/export.dart',
        );
      }
    });

    test('they are payloads the app accepts', () {
      for (final file in Directory('$repoRoot/conformance').listSync()) {
        if (file is! File || !file.path.endsWith('.json')) continue;
        final report = validateThemePayload(readJson(file.path));
        expect(report.hasErrors, isFalse, reason: file.path);
        expect(report.warningCount, 0, reason: file.path);
      }
    });
  });

  group('the hand-written fixtures', () {
    test('the minimal payload is valid', () {
      final report =
          validateThemePayload(readJson('$repoRoot/conformance/handwritten/v2-minimal.json'));
      expect(report.hasErrors, isFalse);
      expect(report.warningCount, 0);
    });

    test('the out-of-range payload is clamped rather than rejected', () {
      final report =
          validateThemePayload(readJson('$repoRoot/conformance/broken/out-of-range.json'));
      expect(report.hasErrors, isFalse);
      expect(report.warningCount, greaterThan(0));
      expect((report.resolved!['radius'] as Map)['large'], 64.0);
    });

    test('the unknown-field payload is only a warning', () {
      final report =
          validateThemePayload(readJson('$repoRoot/conformance/broken/unknown-field.json'));
      expect(report.hasErrors, isFalse);
      expect(report.warningCount, 1);
    });
  });

  group('the v3 draft', () {
    test('a v2 app can still read it — the new blocks are warnings', () {
      final report = validateThemePayload(
        readJson('$repoRoot/conformance/draft/v3-kitchen-sink.json'),
      );

      // The v2 part has to be complete and valid, otherwise a v2 app would
      // throw on the whole payload instead of ignoring the new blocks.
      expect(report.hasErrors, isFalse);
      expect(report.resolved, isNotNull);

      final unknown = {
        for (final issue in report.issues)
          if (issue.severity == Severity.warning) issue.path
      };
      expect(
        unknown,
        containsAll([
          'specVersion',
          'typography',
          'spacing',
          'motion',
          'scale',
          'icons',
          'components',
          'branding',
          'ui',
        ]),
      );
    });
  });
}
