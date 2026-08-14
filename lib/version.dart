import 'package:intl/intl.dart';

const String gitHash = String.fromEnvironment(
  'GIT_HASH',
  defaultValue: 'unknown',
);
const String buildDate = String.fromEnvironment(
  'BUILD_DATE',
  defaultValue: 'unknown',
);

String formatBuildDate(String isoDate) {
  try {
    return DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(DateTime.parse(isoDate).toLocal());
  } catch (_) {
    return isoDate;
  }
}
