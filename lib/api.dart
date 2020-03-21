
import 'dart:io';

import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:route_recorder/classes.dart' as Classes;

Firestore db = Firestore.instance;
final String recordModelsCollectionName = 'models';
final String recordsCollectionName = 'records';
final String groupsCollectionName = 'records';
final String localDbUnfinishedRecordsName = 'unfinished_records';

/// Gets the path on local filesystem that will be used to reference local
/// storage for Sembast.
Future<String> getLocalDbPath() async {
  Directory directory = await getApplicationDocumentsDirectory();
  return join(directory.path, 'route_recorder.db');
}

/// Get route models from Firebase, and convert to a format that the app can
/// use. The map that is returned has two properties; "routes", which stores
/// a List<Model>, and "fromCache", which is boolean and will be true
/// if the routes were retrieved from local storage, indicating no internet
/// connection.
Future<Classes.RoutesRetrieval> getAllRoutes() {
  return db.collection(recordModelsCollectionName).getDocuments().then((QuerySnapshot snap) {
    return Classes.RoutesRetrieval(
      routes: snap.documents.map((DocumentSnapshot ds) {
        Classes.Model toReturn = Classes.Model.mapDeserialize(ds.data, true);
        /// also include model ID
        toReturn.id = ds.documentID;
        return toReturn;
      }).toList(),
      fromCache: snap.metadata.isFromCache
    );
  });
}

/// Retrieve unfinished routes from local storage.
Future<List<Classes.UnfinishedRoute>> getUnfinishedRoutes() async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbUnfinishedRecordsName);
  return store.find(localDb).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) {
      Classes.UnfinishedRoute toReturn = Classes.UnfinishedRoute.mapDeserialize(snap.value);
      toReturn.id = snap.key;
      return toReturn;
    }).toList().cast<Classes.UnfinishedRoute>();
  });
}

/// Saves an unfinished route to local storage. Deletes any existing version of
/// the record.
Future<dynamic> saveRecord(Classes.UnfinishedRoute unfinishedRoute) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbUnfinishedRecordsName);

  /// If [unfinishedRoute] has an ID, this means it exists in local storage;
  /// must delete the old version.
  if (unfinishedRoute.id != null) {
    await deleteUnfinishedRecord(unfinishedRoute.id);
  }

  Map<String, dynamic> toAdd = unfinishedRoute.mapSerialize();
  /// Convert DateTime's to UNIX timestamps if so.
  toAdd['record']['startTime'] = (toAdd['record']['startTime'].millisecondsSinceEpoch / 1000).round();
  return store.add(localDb, toAdd);
}

/// Deletes an unfinished route from local storage.
Future<dynamic> deleteUnfinishedRecord(String unfinishedRouteId) async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbUnfinishedRecordsName);

  return store.record(unfinishedRouteId).delete(localDb);
}

/// Submits [record] to Firebase. The boolean returned by this future will be
/// true if the record submitted successfully, and false if the record is being
/// cached due to unsuccessful internet connectivity.
Future<bool> submitRecord(Classes.Record record) {
  /// Convert [record] into a form usable by Firebase
  Map toAdd = record.mapSerialize();
  /// make transformations for Firebase:
  ///   - remove the ID
  toAdd.remove('id');

  return Future.any([
    db.collection(recordsCollectionName)
      .add(toAdd)
      .then((onValue) => true),
    Future.delayed(Duration(seconds: 5), () => Future.value(false))
  ]);
}
