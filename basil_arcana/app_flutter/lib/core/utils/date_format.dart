import 'package:intl/intl.dart';

String formatDateTime(DateTime dateTime) {
  return DateFormat('MMM d, yyyy • HH:mm').format(dateTime);
}
