import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:route_recorder/classes.dart';

Firestore db = Firestore.instance;
String recordModelsCollectionName = 'models';
String recordsCollectionName = 'records';
String groupsCollectionName = 'records';

/// Get route models from Firebase, and convert to a format that the app can
/// use. The map that is returned has two properties; "routes", which stores
/// a List<Model>, and "fromCache", which is boolean and will be true
/// if the routes were retrieved from local storage, indicating no internet
/// connection.
Future<RoutesRetrieval> getAllRoutes() {
  return db.collection(recordModelsCollectionName).getDocuments().then((QuerySnapshot snap) {
    return RoutesRetrieval(
      routes: snap.documents.map((DocumentSnapshot ds) {
        return Model(
          id: ds.documentID,
          title: ds.data['title'],
          fields: ds.data['fields'].map((dynamic fieldMap) {
            return ModelField(
              title: fieldMap['title'],
              type: fieldMap['type'] ?? 'string',
              optional: fieldMap['optional'] ?? false,
            );
          }).toList().cast<ModelField>(),
          stops: ds.data['stopData']['stops'].map((dynamic stopMap) {
            return Stop(
              title: stopMap['title'],
              description: stopMap['description'] ?? null,
              exclude: stopMap['exclude'] == null
                ? null
                : stopMap['exclude'].cast<String>()
            );
          }).toList().cast<Stop>(),
          stopFields: ds.data['stopData']['fields'].map((dynamic stopFieldMap) {
            return StopField(
              title: stopFieldMap['title'],
              optional: stopFieldMap['optional'] ?? false,
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
Future<bool> submitRecord(Record record) {
  /// Convert [record] into a form usable by Firebase
  Map<String, dynamic> toAdd = {
    'modelId': record.modelId,
    'modelTitle': record.modelTitle,
    'startTime': record.startTime,
    'endTime': record.endTime,
    'properties': record.properties,
    'stops': record.stops.map((RecordStop ss) {
      return {
        'title': ss.title,
        'properties': ss.properties
      };
    }).toList()
  };
  return Future.any([
    db.collection(recordsCollectionName).add(toAdd).then((onValue) => true),
    Future.delayed(Duration(seconds: 5), () => Future.value(false))
  ]);
}
