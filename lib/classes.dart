
enum AppView { SELECT_ROUTE, ACTIVE_ROUTE }

class RecyclingRouteField {
  final String name;
  final bool isOptional;

  RecyclingRouteField({
    this.name,
    this.isOptional
  });
}
class StopField {
  final String name;
  final bool isOptional;

  StopField({
    this.name,
    this.isOptional
  });
}

class RecyclingRoute {

  final String id;
  final String name;
  final List<RecyclingRouteField> fields;
  final List<Stop> stops;
  final List<StopField> stopFields;
  DateTime checkinTime;
  DateTime checkoutTime;

  RecyclingRoute({
    this.id,
    this.name,
    this.fields,
    this.stops,
    this.stopFields,
    checkinTime,
    checkoutTime,
  }) {
    // don't allow for checkinTimes unless a checkoutTime is also specified
    if (checkinTime != null && checkoutTime == null) {
      throw new RangeError('Record with a check-in time cannot be created without a check-out time.');
    }
    this.checkoutTime = checkoutTime;
    this.checkinTime = checkinTime;
  }
}

class Stop {
  final String id;
  final String name;
  String address;

  Stop({
    this.id,
    this.name,
    this.address
  });
}

class RecyclingRouteSubmission {
  String id;
  final String routeId;
  final Map<String, String> routeFields;
  final List<StopSubmission> stops;

  RecyclingRouteSubmission({
    this.id,
    this.routeId,
    this.routeFields,
    this.stops
  });
}
class StopSubmission {
  String stopId;
  final Map<String, String> routeFields;

  StopSubmission({
    this.stopId,
    this.routeFields
  });
}