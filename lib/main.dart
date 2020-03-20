// Invoke "debug painting" (press "p" in the console, choose the
// "Toggle Debug Paint" action from the Flutter Inspector in Android
// Studio, or the "Toggle Debug Paint" command in Visual Studio Code)
// to see the wireframe for each widget.

import 'package:flutter/material.dart';
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

  AppView currentView = AppView.SELECT_ROUTE;
  Model activeRoute;

  void changeRoute(AppView route) {
    setState(() {
      currentView = route;
    });
  }

  void setActiveRoute(Model route) {
    setState(() {
      activeRoute = route;
    });
  }

  @override
  Widget build(BuildContext context) {

    Widget toDisplay;
    if (currentView == AppView.SELECT_ROUTE) {
      toDisplay = SelectRoute(
        changeRoute: changeRoute,
        setActiveRoute: setActiveRoute,
      );
    } else { // currentView == AppView.SELECT_ROUTE
      toDisplay = ActiveRoute(
        changeRoute: changeRoute,
        activeRoute: activeRoute,
      );
    }

    return Scaffold(
      appBar: currentView == AppView.SELECT_ROUTE
        ? AppBar(
            title: Text('OSWM&R Checkout App'),
          )
        : null,
      body: toDisplay
    );
  }
}
