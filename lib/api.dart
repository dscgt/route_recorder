import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:route_recorder/classes.dart';

Firestore db = Firestore.instance;

Future<List<RecyclingRoute>> getAllRoutes() async {
  /// return sample routes for now
  return generateSampleRoutes();
}

Future<void> submitRecord(RecyclingRouteSubmission record) {
  print(record);
  /// For now, don't actually submit this record
  return Future.delayed(const Duration(milliseconds: 1000), () {
    print('submitted');
    return null;
  });
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
