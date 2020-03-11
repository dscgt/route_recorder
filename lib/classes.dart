
enum AppView { SELECT_ROUTE, ACTIVE_ROUTE }

/// Stores information regarding a retrieval of all routes.
class RoutesRetrieval {
  /// Routes that were successfully retrieved.
  final List<RecyclingRoute> routes;

  /// The cache status of the routes; a value of "true" indicates that [routes]
  /// were retrieved from cache, indicating no internet connection.
  final bool fromCache;

  RoutesRetrieval({
    this.routes,
    this.fromCache
  });
}

class RecyclingRouteField {
  final String name;
  final String type;
  final bool isOptional;

  RecyclingRouteField({
    this.name,
    this.type,
    this.isOptional
  });
}
class StopField {
  final String name;
  final String type;
  final bool isOptional;

  StopField({
    this.name,
    this.type,
    this.isOptional
  });
}

class RecyclingRoute {

  final String id;
  final String name;
  final List<RecyclingRouteField> fields;
  final List<Stop> stops;
  final List<StopField> stopFields;

  RecyclingRoute({
    this.id,
    this.name,
    this.fields,
    this.stops,
    this.stopFields,
  });
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
  DateTime startTime;
  DateTime endTime;
  final Map<String, String> routeFields;
  final List<StopSubmission> stops;

  RecyclingRouteSubmission({
    this.id,
    this.routeId,
    this.routeFields,
    this.stops,
    endTime,
    startTime,
  }) {
    // don't allow for endTime unless a startTime is also specified
    if (endTime != null && startTime == null) {
      throw new RangeError('Record with a check-in time cannot be created without a check-out time.');
    }
    this.startTime = startTime;
    this.endTime = endTime;
  }
}
class StopSubmission {
  String stopId;
  final Map<String, String> stopFields;

  StopSubmission({
    this.stopId,
    this.stopFields
  });
}