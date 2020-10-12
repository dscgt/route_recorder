
import 'dart:io';

import 'package:path/path.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:route_recorder/utils.dart';
// keep sembast around; it may still be useful for automatic route saving on app crash in future.
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_io.dart';
import 'package:route_recorder/classes.dart' as Classes;

Firestore db = Firestore.instance;
final String modelsCollectionName = 'route_models';
final String recordsCollectionName = 'route_records';
final String unfinishedRecordsCollectionName = 'route_records_in_progress';
final String groupsCollectionName = 'route_groups';

/// Gets the path on local filesystem that will be used to reference local
/// storage for Sembast.
/// Currently unused, but may still be useful for automatic route saving on app crash in future.
Future<String> getLocalDbPath() async {
  Directory directory = await getApplicationDocumentsDirectory();
  return join(directory.path, 'route_recorder.db');
}

/// Get route models from Firebase, and convert to a format that the app can
/// use.
Future<Classes.RoutesRetrieval> getAllRoutes() {
  return db.collection(modelsCollectionName).getDocuments().then((QuerySnapshot snap) {
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

/// Retrieve unfinished routes from Firebase, and convert to a format that the
/// app can use.
Future<Classes.UnfinishedRoutesRetrieval> getUnfinishedRoutes() async {
  return db.collection(unfinishedRecordsCollectionName).getDocuments().then((QuerySnapshot snap) {
    return Classes.UnfinishedRoutesRetrieval(
        unfinishedRoutes: snap.documents.map((DocumentSnapshot ds) {
          Classes.UnfinishedRoute toReturn = Classes.UnfinishedRoute.fromMap(ds.data);
          /// also include unfinished route ID
          toReturn.id = ds.documentID;
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
      db.collection(unfinishedRecordsCollectionName)
          .document(id).setData(toAdd)
          .then((onValue) => true),
      Future.delayed(Duration(seconds: 5), () => Future.value(false))
    ]);
  } else {
    return Future.any([
      db.collection(unfinishedRecordsCollectionName)
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
    db.collection(unfinishedRecordsCollectionName)
      .document(unfinishedRouteId)
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
    db.collection(recordsCollectionName)
      .add(toAdd)
      .then((onValue) => true),
    Future.delayed(Duration(seconds: 5), () => Future.value(false))
  ]);
}
