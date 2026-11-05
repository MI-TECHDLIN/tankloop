library;

import 'package:intl/intl.dart';
import 'package:timezone/data/latest.dart' as zones;
import 'package:timezone/timezone.dart' as tz;

bool _initialized = false;
tz.TZDateTime _local(DateTime value, String timezone) {
  if (!_initialized) {
    zones.initializeTimeZones();
    _initialized = true;
  }
  try {
    return tz.TZDateTime.from(value, tz.getLocation(timezone));
  } on tz.LocationNotFoundException {
    return tz.TZDateTime.from(value, tz.UTC);
  }
}

String recordDate(DateTime value, {String timezone = 'Africa/Lagos'}) =>
    DateFormat('d MMM yyyy', 'en_US').format(_local(value, timezone));
String recordTime(DateTime value, {String timezone = 'Africa/Lagos'}) {
  final local = _local(value, timezone);
  return '${DateFormat('d MMM yyyy, HH:mm', 'en_US').format(local)} ${local.timeZoneName}';
}

String dayGreeting(DateTime value, {String timezone = 'Africa/Lagos'}) =>
    DateFormat('EEEE, d MMMM', 'en_US').format(_local(value, timezone));
String humanState(String wire) => wire
    .split('_')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');
