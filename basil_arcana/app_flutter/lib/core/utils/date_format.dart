import 'package:intl/intl.dart';

String formatDateTime(DateTime dateTime, {String? locale}) {
  return DateFormat('MMM d, yyyy • HH:mm', locale).format(dateTime);
}
