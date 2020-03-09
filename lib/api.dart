import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:route_recorder/classes.dart';

Firestore db = Firestore.instance;
String recordModelsCollectionName = 'test_models';
String recordsCollectionName = 'test_records';

/// Get route models from Firebase, and convert to a format that the app can
/// use.
Future<List<RecyclingRoute>> getAllRoutes() {
  return db.collection(recordModelsCollectionName).getDocuments().then((QuerySnapshot snap) {
    return snap.documents.map((DocumentSnapshot ds) {
      return RecyclingRoute(
        id: ds.documentID,
        name: ds.data['name'],
        fields: ds.data['fields'].map((dynamic fieldMap) {
          return RecyclingRouteField(
            name: fieldMap['name'],
            isOptional: fieldMap['optional'] ?? false,
            type: fieldMap['type'] ?? 'string',
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
            isOptional: stopFieldMap['optional'] ?? false,
            type: stopFieldMap['type'] ?? 'string',
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
    }).toList()
  };
  return db.collection(recordsCollectionName).add(toAdd);
}
