
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:route_recorder/utils.dart';

enum AppView { SELECT_ROUTE, ACTIVE_ROUTE }
enum FieldDataType { string, number, select }

/// Stores information regarding a retrieval of routes.
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

/// Stores information regarding a retrieval of groups.
class GroupsRetrieval {
  /// Groups that were successfully retrieved.
  final List<Group> groups;

  /// The cache status of the groups; a value of "true" indicates that [groups]
  /// were retrieved from cache, indicating no internet connection.
  final bool fromCache;

  GroupsRetrieval({
    this.groups,
    this.fromCache
  });
}

class Group {
  final List<String> members;
  String id;

  Group({
    this.id,
    this.members
  });

  Group.fromMap(Map map)
    : members = map['members']
        .map((dynamic) => dynamic['title']).toList().cast<String>(),
      id = map['id'];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'members': members.map((String s) => {
        'title': s
      })
    };
  }
}



class ModelField {
  final String title;
  final FieldDataType type;
  final bool optional;
  String groupId;

  ModelField({
    this.title,
    this.type,
    this.optional,
    this.groupId
  });

  static ModelField mapDeserialize(dynamic map) {
    return ModelField(
      title: map['title'],
      type: map['type'] == null
        ? FieldDataType.string
        : stringToFieldDataType(map['type']),
      optional: map['optional'] ?? false,
      /// Handle groupId being both a DocumentReference when retrieved
      /// from Firestore, and a String when retrieved from local storage
      groupId: map['groupId'] is DocumentReference
        ? map['groupId'].documentID
        : map['groupId']
    );
  }

  Map<String, dynamic> mapSerialize() {
    return {
      'title': title,
      'type': fieldDataTypeToString(type),
      'optional': optional,
      'groupId': groupId
    };
  }
}

class StopField {
  final String title;
  final FieldDataType type;
  final bool optional;
  String groupId;

  StopField({
    @required this.title,
    @required this.type,
    @required this.optional,
    this.groupId
  });

  static StopField mapDeserialize(Map<String, dynamic> map) {
    return StopField(
      title: map['title'],
      type: map['type'] == null
        ? FieldDataType.string
        : stringToFieldDataType(map['type']),
      optional: map['optional'] ?? false,
      groupId: map['groupId'] is DocumentReference
        ? map['groupId'].documentID
        : map['groupId']
    );
  }

  Map<String, dynamic> mapSerialize() {
    return {
      'title': title,
      'type': fieldDataTypeToString(type),
      'optional': optional,
      'groupId': groupId
    };
  }
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

  static Stop mapDeserialize(Map<String, dynamic> map) {
    return Stop(
      title: map['title'],
      description: map['description'],
      exclude: map['exclude'] == null
        ? null
        : map['exclude'].cast<String>()
    );
  }

  Map<String, dynamic> mapSerialize() {
    return {
      'title': title,
      'description': description,
      'exclude': exclude,
    };
  }
}

class Model {
  final String title;
  final List<ModelField> fields;
  final List<Stop> stops;
  final List<StopField> stopFields;
  String id;

  Model({
    @required this.title,
    @required this.fields,
    @required this.stops,
    @required this.stopFields,
    @required this.id,
  });

  static Model mapDeserialize(Map<String, dynamic> map, bool fromFirebase) {
    Map<String, dynamic> thisMap = Map.from(map);
    if (fromFirebase) {
      /// bubble up fields within stopData
      thisMap['stops'] = thisMap['stopData']['stops'];
      thisMap['stopFields'] = thisMap['stopData']['fields'];
    }

    return Model(
      id: thisMap['id'],
      title: thisMap['title'],
      fields: thisMap['fields'].map((dynamic field) =>
        ModelField.mapDeserialize(field)
      ).toList().cast<ModelField>(),
      stops: thisMap['stops'].map((dynamic stop) =>
        Stop.mapDeserialize(stop)
      ).toList().cast<Stop>(),
      stopFields: thisMap['stopFields'].map((dynamic field) =>
        StopField.mapDeserialize(field)
      ).toList().cast<StopField>(),
    );
  }

  Map<String, dynamic> mapSerialize() {
    return {
      'id': id,
      'title': title,
      'fields': fields.map((ModelField mf) => mf.mapSerialize()).toList(),
      'stops': stops.map((Stop stop) => stop.mapSerialize()).toList(),
      'stopFields': stopFields.map((StopField sf) => sf.mapSerialize()).toList(),
    };
  }
}

class RecordStop {
  final String title;
  final Map<String, String> properties;

  RecordStop({
    @required this.title,
    @required this.properties
  });

  static RecordStop mapDeserialize(Map<String, dynamic> map) {
    return RecordStop(
      title: map['title'],
      properties: map['properties'].cast<String, String>(),
    );
  }

  Map<String, dynamic> mapSerialize() {
    return {
      'title': title,
      'properties': properties
    };
  }
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

  static Record mapDeserialize(Map<String, dynamic> map) {
    return Record(
      modelId: map['modelId'],
      modelTitle: map['modelTitle'],
      properties: map['properties'].cast<String, String>(),
      startTime: map['startTime'] is DateTime
        ? map['startTime']
        : DateTime.fromMillisecondsSinceEpoch(map['startTime'] * 1000),
      endTime: map['endTime'] is DateTime
        ? map['endTime']
        : map['endTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['endTime'] * 1000)
          : null,
      id: map['id'],
      stops: map['stops'].map((dynamic stop) =>
        RecordStop.mapDeserialize(stop)
      ).toList().cast<RecordStop>()
    );
  }

  Map<String, dynamic> mapSerialize() {
    return {
      'modelId': modelId,
      'modelTitle': modelTitle,
      'properties': properties,
      'startTime': startTime,
      'endTime': endTime,
      'id': id,
      'stops': stops.map((RecordStop stop) =>
        stop.mapSerialize()
      ).toList()
    };
  }
}

class UnfinishedRoute {
  final Model model;
  final Record record;
  String id;

  UnfinishedRoute({
    @required this.model,
    @required this.record,
    this.id
  });

  static mapDeserialize(Map<String, dynamic> map) {
    return UnfinishedRoute(
      model: Model.mapDeserialize(map['model'], false),
      record: Record.mapDeserialize(map['record']),
      id: map['id'],
    );
  }

  Map<String, dynamic> mapSerialize() {
    return {
      'model': model.mapSerialize(),
      'record': record.mapSerialize(),
      'id': id
    };
  }

  String toShortString() {
    return '${record.modelTitle}, ${dateTimeToString(record.startTime)}';
  }
}