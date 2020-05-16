
import 'dart:io';

import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:route_recorder/utils.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:route_recorder/classes.dart' as Classes;

Firestore db = Firestore.instance;
final String recordModelsCollectionName = 'models';
final String recordsCollectionName = 'records';
final String groupsCollectionName = 'groups';
final String localDbUnfinishedRecordsName = 'unfinished_records';

/// Gets the path on local filesystem that will be used to reference local
/// storage for Sembast.
Future<String> getLocalDbPath() async {
  Directory directory = await getApplicationDocumentsDirectory();
  return join(directory.path, 'route_recorder.db');
}

/// Get route models from Firebase, and convert to a format that the app can
/// use.
Future<Classes.RoutesRetrieval> getAllRoutes() {
  return db.collection(recordModelsCollectionName).getDocuments().then((QuerySnapshot snap) {
    return Classes.RoutesRetrieval(
      routes: snap.documents.map((DocumentSnapshot ds) {
        Classes.Model toReturn = Classes.Model.fromMap(ds.data);
        /// also include model ID
        toReturn.id = ds.documentID;
        return toReturn;
      }).toList(),
      fromCache: snap.metadata.isFromCache
    );
  });
}

/// Get groups from Firebase, and convert to a format that the app can
/// use.
Future<Classes.GroupsRetrieval> getAllGroups() {
  return db.collection(groupsCollectionName).getDocuments().then((QuerySnapshot snap) {
    return Classes.GroupsRetrieval(
      groups: snap.documents.map((DocumentSnapshot ds) {
        Classes.Group toReturn = Classes.Group.fromMap(ds.data);
        /// also include model ID
        toReturn.id = ds.documentID;
        return toReturn;
      }).toList(),
      fromCache: snap.metadata.isFromCache
    );
  });
}

/// Get groups specified by [ids] from Firebase, and convert to a format that
/// the app can use. Will throw an error if any of the IDs given refers to a
/// document that does not exist.
Future<Classes.GroupsRetrieval> getGroups(List<String> ids) async {
  if (ids.length == 0) {
    return Classes.GroupsRetrieval(
      groups: [],
      fromCache: true
    );
  }

  List<Future<DocumentSnapshot>> promises = ids
    .map((String id) =>
      db.collection(groupsCollectionName)
      .document(id)
      .get())
    .toList();
  List<DocumentSnapshot> result = await Future.wait(promises);
  Iterable<DocumentSnapshot> nonExistants = result.where((DocumentSnapshot ds) => !ds.exists);
  if (nonExistants.length > 0) {
    throw new Exception('Attempted to get groups that do not exist: ${nonExistants.map((DocumentSnapshot ds) => ds.documentID).join(', ')}');
  }

  return Classes.GroupsRetrieval(
    groups: result.map((DocumentSnapshot ds) {
      Classes.Group toReturn = Classes.Group.fromMap(ds.data);
      /// also include model ID
      toReturn.id = ds.documentID;
      return toReturn;
    }).toList(),
    fromCache: result[0].metadata.isFromCache
  );
}

/// Retrieve unfinished routes from local storage.
Future<List<Classes.UnfinishedRoute>> getUnfinishedRoutes() async {
  String dbPath = await getLocalDbPath();
  DatabaseFactory dbFactory = databaseFactoryIo;
  Database localDb = await dbFactory.openDatabase(dbPath);
  StoreRef store = stringMapStoreFactory.store(localDbUnfinishedRecordsName);
  return store.find(localDb).then((List<RecordSnapshot> snapshots) {
    return snapshots.map((RecordSnapshot snap) {
      Classes.UnfinishedRoute toReturn = Classes.UnfinishedRoute.fromMap(snap.value);
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

  // If [unfinishedRoute] has an ID, this means it exists in local storage;
  // must delete the old version.
  if (unfinishedRoute.id != null) {
    await deleteUnfinishedRecord(unfinishedRoute.id);
  }

  Map<String, dynamic> toAdd = unfinishedRoute.toMap();
  // Convert DateTime's to UNIX timestamps
  toAdd['record']['startTime'] = (toAdd['record']['startTime'].millisecondsSinceEpoch / 1000).round();
  // Convert enums to strings
  toAdd['model']['fields'].forEach((Map modelFields) {
    modelFields['type'] = fieldDataTypeToString(modelFields['type']);
  });
  toAdd['model']['stopData']['fields'].forEach((Map modelFields) {
    modelFields['type'] = fieldDataTypeToString(modelFields['type']);
  });

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
  // Convert [record] into a form usable by Firebase
  Map toAdd = record.toMap();
  // make transformations for Firebase:
  //   - remove the ID
  toAdd.remove('id');

  return Future.any([
    db.collection(recordsCollectionName)
      .add(toAdd)
      .then((onValue) => true),
    Future.delayed(Duration(seconds: 5), () => Future.value(false))
  ]);
}
