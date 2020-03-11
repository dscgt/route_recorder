import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:route_recorder/classes.dart';

Firestore db = Firestore.instance;
String recordModelsCollectionName = 'test_models';
String recordsCollectionName = 'test_records';

/// Get route models from Firebase, and convert to a format that the app can
/// use. The map that is returned has two properties; "routes", which stores
/// a List<RecyclingRoute>, and "fromCache", which is boolean and will be true
/// if the routes were retrieved from local storage, indicating no internet
/// connection.
Future<RoutesRetrieval> getAllRoutes() {
  return db.collection(recordModelsCollectionName).getDocuments().then((QuerySnapshot snap) {
    return RoutesRetrieval(
      routes: snap.documents.map((DocumentSnapshot ds) {
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
      }).toList(),
      fromCache: snap.metadata.isFromCache
    );
  });
}

/// Submits [record] to Firebase. The boolean returned by this future will be
/// true if the record submitted successfully, and false if the record is being
/// cached due to unsuccessful internet connectivity.
Future<bool> submitRecord(RecyclingRouteSubmission record) {
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
  return Future.any([
    db.collection(recordsCollectionName).add(toAdd).then((onValue) => true),
    Future.delayed(Duration(seconds: 5), () => Future.value(false))
  ]);
}
