
import 'package:intl/intl.dart';
import 'package:route_recorder/classes.dart';

FieldDataType stringToFieldDataType(String s) {
  if (s == 'number') {
    return FieldDataType.number;
  } else if (s == 'string') {
    return FieldDataType.string;
  } else if (s == 'select') {
    /// default to string for now
    return FieldDataType.select;
  } else {
    throw new Exception('Illegal argument. Provided string does not convert to FieldDataType');
  }
}

String fieldDataTypeToString(FieldDataType d) {
  if (d == FieldDataType.number) {
    return 'number';
  } else if ( d == FieldDataType.string) {
    return 'string';
  } else if ( d == FieldDataType.select) {
    return 'select';
  } else {
    throw new Exception('Illegal argument. Provided datatype is null or not an accepted FieldDataType');
  }
}

String dateTimeToString(DateTime dt) {
  DateTime local = dt.toLocal();
  String toReturn = DateFormat.yMMMMd().add_jm().format(local);
  return toReturn;
}
