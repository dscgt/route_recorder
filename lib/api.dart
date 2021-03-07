
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:route_recorder/utils.dart';
import 'package:route_recorder/classes.dart' as Classes;
import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

FirebaseFirestore firestore = FirebaseFirestore.instance;
final String modelsCollectionName = 'route_models';
final String recordsCollectionName = 'route_records';
final String unfinishedRecordsCollectionName = 'route_records_in_progress';
final String groupsCollectionName = 'route_groups';

final String savedRouteDbName = 'route';

/// Gets an accessor for the Sembast local data storage
Future<Database> getLocalDb() async {
  var factory = databaseFactoryWeb;
  var db = await factory.openDatabase('route_recorder_storage');
  return db;
}

/// Gets the locally stored unfinished route. The future will resolve to null
/// if there is no locally stored unfinished route.
Future<Classes.UnfinishedRoute> getUnfinishedRouteLocalStorage() async {
  StoreRef store = stringMapStoreFactory.store();
  Database localDb = await getLocalDb();

  var route = await store.record(savedRouteDbName).get(localDb);

  if (route == null) {
    return null;
  }

  Classes.UnfinishedRoute toReturn = Classes.UnfinishedRoute.fromMap(route);
  return toReturn;
}

/// Saves an unfinished route to local storage. Deletes any existing version of
/// the record.
Future<dynamic> saveUnfinishedRouteLocalStorage(Classes.UnfinishedRoute unfinishedRoute) async {
  StoreRef store = stringMapStoreFactory.store();
  Database localDb = await getLocalDb();

  Map<String, dynamic> toAdd = unfinishedRoute.toMap();
  // Convert DateTime's to UNIX timestamps
  toAdd['record']['startTime'] = (toAdd['record']['startTime'].millisecondsSinceEpoch / 1000).round();
  toAdd['record']['saves'].forEach((Map<String, dynamic> saveObject) {
    saveObject['saveTime'] = (saveObject['saveTime'].millisecondsSinceEpoch / 1000).round();
  });
  // Convert enums to strings
  toAdd['model']['fields'].forEach((Map modelFields) {
    modelFields['type'] = fieldDataTypeToString(modelFields['type']);
  });
  toAdd['model']['stopData']['fields'].forEach((Map modelFields) {
    modelFields['type'] = fieldDataTypeToString(modelFields['type']);
  });

  return store.record(savedRouteDbName).put(localDb, toAdd);
}

/// Saves an unfinished route to local storage. Deletes any existing version of
/// the record.
Future<dynamic> deleteUnfinishedRouteLocalStorage() async {
  StoreRef store = stringMapStoreFactory.store();
  Database localDb = await getLocalDb();

  return store.record(savedRouteDbName).delete(localDb);
}

/// Get route models from Firebase, and convert to a format that the app can
/// use.
Future<Classes.RoutesRetrieval> getAllRoutes() {
  return firestore.collection(modelsCollectionName).get().then((QuerySnapshot snap) {
    return Classes.RoutesRetrieval(
      routes: snap.docs.map((DocumentSnapshot ds) {
        Classes.Model toReturn = Classes.Model.fromMap(ds.data());
        /// also include model ID
        toReturn.id = ds.id;
        return toReturn;
      }).toList(),
      fromCache: snap.metadata.isFromCache
    );
  });
}

/// Get groups from Firebase, and convert to a format that the app can
/// use.
Future<Classes.GroupsRetrieval> getAllGroups() {
  return firestore.collection(groupsCollectionName).get().then((QuerySnapshot snap) {
    return Classes.GroupsRetrieval(
      groups: snap.docs.map((DocumentSnapshot ds) {
        Classes.Group toReturn = Classes.Group.fromMap(ds.data());
        /// also include model ID
        toReturn.id = ds.id;
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
      firestore.collection(groupsCollectionName)
      .doc(id)
      .get())
    .toList();
  List<DocumentSnapshot> result = await Future.wait(promises);
  Iterable<DocumentSnapshot> nonExistants = result.where((DocumentSnapshot ds) => !ds.exists);
  if (nonExistants.length > 0) {
    throw new Exception('Attempted to get groups that do not exist: ${nonExistants.map((DocumentSnapshot ds) => ds.id).join(', ')}');
  }

  return Classes.GroupsRetrieval(
    groups: result.map((DocumentSnapshot ds) {
      Classes.Group toReturn = Classes.Group.fromMap(ds.data());
      /// also include model ID
      toReturn.id = ds.id;
      return toReturn;
    }).toList(),
    fromCache: result[0].metadata.isFromCache
  );
}

/// Retrieve unfinished routes from Firebase, and convert to a format that the
/// app can use.
Future<Classes.UnfinishedRoutesRetrieval> getUnfinishedRoutes() async {
  return firestore.collection(unfinishedRecordsCollectionName).get().then((QuerySnapshot snap) {
    return Classes.UnfinishedRoutesRetrieval(
        unfinishedRoutes: snap.docs.map((DocumentSnapshot ds) {
          Classes.UnfinishedRoute toReturn = Classes.UnfinishedRoute.fromMap(ds.data());
          /// also include unfinished route ID
          toReturn.id = ds.id;
          // and include the route model's ID
          toReturn.model.id = toReturn.record.modelId;
          return toReturn;
        }).toList(),
        fromCache: snap.metadata.isFromCache
    );
  });
}

/// Submits [unfinishedRoute] to Firebase. The boolean returned by this future will be
/// true if the record submitted successfully, and false if the record takes over 5 seconds
/// long to submit, which is being used to indicate caching due to unsuccessful
/// internet connectivity.
Future<bool> saveRecord(Classes.UnfinishedRoute unfinishedRoute) async {
  // convert to a format Firebase can use
  Map<String, dynamic> toAdd = unfinishedRoute.toMap();
  // make transformations for Firebase:
  //   - remove the ID, save for document replacement
  //   - remove the model's ID
  //   - remove the record's ID
  //   - convert enums to strings
  String id = toAdd.remove('id');
  toAdd['model'].remove('id');
  toAdd['record'].remove('id');
  toAdd['model']['fields'].forEach((Map modelFields) {
    modelFields['type'] = fieldDataTypeToString(modelFields['type']);
  });
  toAdd['model']['stopData']['fields'].forEach((Map modelFields) {
    modelFields['type'] = fieldDataTypeToString(modelFields['type']);
  });

  if (id != null) {
    // indicates that this unfinished record exists, so we perform a replace
    return Future.any([
      firestore.collection(unfinishedRecordsCollectionName)
          .doc(id).set(toAdd)
          .then((onValue) => true),
      Future.delayed(Duration(seconds: 5), () => Future.value(false))
    ]);
  } else {
    return Future.any([
      firestore.collection(unfinishedRecordsCollectionName)
        .add(toAdd)
        .then((onValue) => true),
      Future.delayed(Duration(seconds: 5), () => Future.value(false))
    ]);
  }

  
}

/// Deletes the unfinished record with ID [unfinishedRouteId] from Firebase. The
/// boolean returned by this future will be true if the record was deleted
/// successfully, and false if the record takes over 5 seconds to submit, which is
/// being used to indicate caching due to unsuccessful internet connectivity.
Future<bool> deleteUnfinishedRecord(String unfinishedRouteId) async {
  return Future.any([
    firestore.collection(unfinishedRecordsCollectionName)
      .doc(unfinishedRouteId)
      .delete()
      .then((onValue) => true),
    Future.delayed(Duration(seconds: 5), () => Future.value(false))
  ]);
}

/// Submits [record] to Firebase. The boolean returned by this future will be
/// true if the record submitted successfully, and false if the record takes
/// over 5 seconds to submit, which is being used to indicate caching due to
/// unsuccessful internet connectivity.
Future<bool> submitRecord(Classes.Record record) {
  // Convert [record] into a form usable by Firebase
  Map toAdd = record.toMap();
  // make transformations for Firebase:
  //   - remove the ID
  toAdd.remove('id');

  return Future.any([
    firestore.collection(recordsCollectionName)
      .add(toAdd)
      .then((onValue) => true),
    Future.delayed(Duration(seconds: 5), () => Future.value(false))
  ]);
}
