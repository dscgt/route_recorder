
import 'package:intl/intl.dart';

String dateTimeToString(DateTime dt) {
  DateTime local = dt.toLocal();
  String toReturn = DateFormat.yMMMMd().add_jm().format(local);
  return toReturn;
}
