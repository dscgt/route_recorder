import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:route_recorder/classes.dart';

Firestore db = Firestore.instance;
String recordModelsCollectionName = 'test_models';
String recordsCollectionName = 'test_records';

Future<List<RecyclingRoute>> getAllRoutes() {
  return db.collection(recordModelsCollectionName).getDocuments().then((QuerySnapshot snap) {
    return snap.documents.map((DocumentSnapshot ds) {
      return RecyclingRoute(
        id: ds.documentID,
        name: ds.data['name'],
        fields: ds.data['fields'].map((dynamic fieldMap) {
          return RecyclingRouteField(
            name: fieldMap['name'],
            isOptional: fieldMap['optional'] ?? false
          );
        }).toList().cast<RecyclingRouteField>(),
        stops: ds.data['stopData']['stops'].map((dynamic stopMap) {
          return Stop(
            id: stopMap['id'],
            name: stopMap['name'],
            address: stopMap['address'] ?? null,
          );
        }).toList().cast<Stop>(),
        stopFields: ds.data['stopData']['fields'].map((dynamic stopFieldMap) {
          return StopField(
            name: stopFieldMap['name'],
            isOptional: stopFieldMap['optional'] ?? false
          );
        }).toList().cast<StopField>(),
      );
    }).toList();
  });
}

/// Submits [record] to Firebase,
Future<dynamic> submitRecord(RecyclingRouteSubmission record) {
  /// Convert [record] into a form usable by Firebase
  Map<String, dynamic> toAdd = {
    'routeId': record.routeId,
    'startTime': record.startTime,
    'endTime': record.endTime,
    ...Map.from(record.routeFields),
    'stops': record.stops.map((StopSubmission ss) {
      return {
        'id': ss.stopId,
        ...ss.stopFields
      };
//      Map<String, String> stopFields = {
//        'id': ss.stopId,
//      };
//      ss.stopFields.forEach((String key, String value) {
//        stopFields[key] = value;
//      });
//      return stopFields;
    }).toList()
  };
//  record.routeFields.forEach((String key, String value) {
//    toAdd[key] = value;
//  });
//  toAdd['stops'] = record.stops.map((StopSubmission ss) {
//    Map<String, String> stopFields = {
//      'id': ss.stopId,
//    };
//    ss.stopFields.forEach((String key, String value) {
//      stopFields[key] = value;
//    });
//    return stopFields;
//  }).toList();
  return db.collection(recordsCollectionName).add(toAdd);
}

List<RecyclingRoute> generateSampleRoutes() {
  return [
    RecyclingRoute(
      name: 'RecyclingRouteName1',
      id: 'RecyclingRoute0000',
      fields: [
        RecyclingRouteField(
          name: 'RecyclingRouteFieldName1',
          isOptional: false
        ),
        RecyclingRouteField(
          name: 'RecyclingRouteFieldName2',
          isOptional: true
        )
      ],
      stops: [
        Stop(
          name: 'StopName1',
          address: 'StopAddress1',
          id: 'Stop0000'
        ),
        Stop(
          name: 'StopName2',
          address: 'StopAddress2',
          id: 'Stop0001'
        ),
      ],
      stopFields: [
        StopField(
          name: 'StopFieldName1',
          isOptional: false
        ),
        StopField(
          name: 'StopFieldName2',
          isOptional: true
        )
      ]
    ),
    RecyclingRoute(
      name: 'RecyclingRouteName2',
      id: 'RecyclingRoute0001',
      fields: [
        RecyclingRouteField(
          name: 'RecyclingRouteFieldName1',
          isOptional: false
        ),
        RecyclingRouteField(
          name: 'RecyclingRouteFieldName2',
          isOptional: true
        )
      ],
      stops: [
        Stop(
          name: 'StopName1',
          address: 'StopAddress1',
          id: 'Stop0000'
        ),
        Stop(
          name: 'StopName2',
          address: 'StopAddress2',
          id: 'Stop0001'
        ),
      ],
      stopFields: [
        StopField(
          name: 'StopFieldName1',
          isOptional: false
        ),
        StopField(
          name: 'StopFieldName2',
          isOptional: true
        )
      ]
    ),
  ];
}
