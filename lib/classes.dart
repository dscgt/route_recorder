
import 'package:flutter/material.dart';

enum AppView { SELECT_ROUTE, ACTIVE_ROUTE }

/// Stores information regarding a retrieval of all routes from local storage.
class RoutesRetrieval {
  /// Routes that were successfully retrieved.
  final List<Model> routes;

  /// The cache status of the routes; a value of "true" indicates that [routes]
  /// were retrieved from cache, indicating no internet connection.
  final bool fromCache;

  RoutesRetrieval({
    this.routes,
    this.fromCache
  });
}

class Group {
  final String id;
  final String members;

  Group({
    this.id,
    this.members
  });
}

class ModelField {
  final String title;
  final String type;
  final bool optional;
  String groupId;

  ModelField({
    this.title,
    this.type,
    this.optional,
    this.groupId
  });
}
class StopField {
  final String title;
  final String type;
  final bool optional;
  String groupId;

  StopField({
    @required this.title,
    @required this.type,
    @required this.optional,
    this.groupId
  });
}

class Stop {
  final String title;
  final String description;
  List<String> exclude;

  Stop({
    @required this.title,
    @required this.description,
    @required this.exclude
  });
}

class Model {
  final String id;
  final String title;
  final List<ModelField> fields;
  final List<Stop> stops;
  final List<StopField> stopFields;

  Model({
    @required this.id,
    @required this.title,
    @required this.fields,
    @required this.stops,
    @required this.stopFields,
  });
}

class Record {
  final String modelId;
  final String modelTitle;
  final Map<String, String> properties;
  final List<RecordStop> stops;
  final DateTime startTime;
  final DateTime endTime;
  String id;

  Record({
    @required this.modelId,
    @required this.modelTitle,
    @required this.properties,
    @required this.stops,
    @required this.startTime,
    @required this.endTime,
    this.id,
  });
}
class RecordStop {
  final String title;
  final Map<String, String> properties;

  RecordStop({
    @required this.title,
    @required this.properties
  });
}