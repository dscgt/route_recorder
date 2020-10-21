// Invoke "debug painting" (press "p" in the console, choose the
// "Toggle Debug Paint" action from the Flutter Inspector in Android
// Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
// to see the wireframe for each widget.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:route_recorder/views/loading.dart';
import 'package:route_recorder/views/route.dart';
import 'package:route_recorder/views/select_route.dart';
import 'classes.dart';

void main() => runApp(App());

class App extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Recycling Route Recorder',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Main(),
    );
  }
}

class Main extends StatefulWidget {
  Main({Key key}) : super(key: key);

  @override
  _MainState createState() => _MainState();
}

class _MainState extends State<Main> {

  // wait for Firebase to initialize before building rest of app
  // From https://firebase.flutter.dev/docs/overview/#initializing-flutterfire
  final Future<FirebaseApp> _firebaseInitialization = Firebase.initializeApp();

  AppView currentView = AppView.SELECT_ROUTE;
  Model activeRoute;
  Record activeRouteSavedData;
  String activeRouteSavedId;

  void resetRoute() {
    setState(() {
      currentView = AppView.SELECT_ROUTE;
      activeRoute = null;
      activeRouteSavedData = null;
      activeRouteSavedId = null;
    });
  }

  void changeRoute(AppView route) {
    setState(() {
      currentView = route;
    });
  }

  void setActiveRoute(Model route, Record savedData, String savedDataId) {
    setState(() {
      activeRoute = route;
      activeRouteSavedData = savedData;
      activeRouteSavedId = savedDataId;
    });
  }

  @override
  Widget build(BuildContext context) {

    Widget toDisplay = currentView == AppView.SELECT_ROUTE
      ? SelectRoute(
          changeRoute: changeRoute,
          setActiveRoute: setActiveRoute,
        )
      : ActiveRoute(
          resetRoute: resetRoute,
          activeRoute: activeRoute,
          activeRouteSavedData: activeRouteSavedData,
          activeRouteSavedId: activeRouteSavedId,
        );

    return FutureBuilder(
      future: _firebaseInitialization,
      builder: (context, snapshot) {
        Widget finalToDisplay = Loading();
        if (snapshot.hasError) {
          finalToDisplay = Container(
            alignment: Alignment.center,
            padding: EdgeInsets.only(left: 75.0, right: 75.0),
            child: Text('ERROR: There was an error: ${snapshot.error.toString()}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24.0
              ),
            )
          );
        } else if (snapshot.connectionState == ConnectionState.done) {
          finalToDisplay = toDisplay;
        }

        return Scaffold(
          appBar: currentView == AppView.SELECT_ROUTE
            ? AppBar(
                title: Text('OSWM&R Recorder App'),
              )
            : null,
          body: finalToDisplay
        );

        return Loading();
      }
    );
  }
}
