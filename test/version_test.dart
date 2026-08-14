import 'package:flutter_test/flutter_test.dart';

import 'package:run_log/version.dart';

void main() {
  test('formats a valid ISO-8601 date', () {
    expect(
      formatBuildDate('2026-08-14T21:10:00Z'),
      matches(RegExp(r'^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$')),
    );
  });

  test('falls back to raw string when unparsable', () {
    expect(formatBuildDate('unknown'), 'unknown');
  });

  test(
    'gitHash and buildDate reflect --dart-define values, or "unknown" if none passed',
    () {
      expect(
        gitHash,
        anyOf('unknown', matches(RegExp(r'^[0-9a-f]{6,}(-dirty)?$'))),
      );
      expect(
        buildDate,
        anyOf(
          'unknown',
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$')),
        ),
      );
    },
  );
}
