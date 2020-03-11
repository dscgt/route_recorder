
import 'package:flutter/material.dart';
import 'package:route_recorder/api.dart';
import 'package:route_recorder/classes.dart';
import 'package:route_recorder/views/loading.dart';

class SelectRoute extends StatefulWidget {
  final Function changeRoute;
  final Function setActiveRoute;

  SelectRoute({
    Key key,
    this.changeRoute,
    this.setActiveRoute
  }) : super(key: key);

  @override
  _SelectRouteState createState() => _SelectRouteState();
}

class _SelectRouteState extends State<SelectRoute> {

  /// The route selected by user. Defaults to first route received.
  String selectedRoute;

  /// List of all recycling routes available that crewmembers can go on.
  List<RecyclingRoute> recyclingRoutes = [];

  /// Information to display to the user. Is also displayed to user when there
  /// is an error.
  String infoText = '';

  /// Loading status of the page.
  bool loading = true;

  /// Error status of the page.
  bool errored = false;


  @override
  initState() {
    attemptGetRoutes();
    super.initState();
  }

  attemptGetRoutes() {
    getAllRoutes().then((RoutesRetrieval mostRecentRoutes) {

      /// Convert retrieved routes into formats usable by build process.
      setState(() {
        recyclingRoutes = mostRecentRoutes.routes;
        selectedRoute = mostRecentRoutes.routes.length >= 0
          ? recyclingRoutes[0].name
          : null;
        loading = false;
        infoText = mostRecentRoutes.fromCache
          ? 'We had some connection problems getting the most recent routes. The routes you see may be out of date.'
          : '';
        errored = false;
      });
    }).catchError((Object error, StackTrace st) {
      /// Convert retrieved routes into formats usable by build process.
      setState(() {
        print('error: $error');
        print('Stacktrace: $st');
        infoText = error.toString();
        errored = true;
        loading = false;
      });
    });
  }

  /// Handles user click to begin a route. Directs user to active route view,
  /// starting a route session.
  _handleBeginRoute() {
    RecyclingRoute activeRoute = recyclingRoutes.firstWhere((RecyclingRoute thisRoute) {
      return thisRoute.name == selectedRoute;
    });
    widget.setActiveRoute(activeRoute);
    widget.changeRoute(AppView.ACTIVE_ROUTE);
  }

  /// View for when this widget encounters an error. Utilizes infoText.
  _buildErrorMessage() {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.only(left: 75.0, right: 75.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('Sorry! We encountered an error getting page routes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.0
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: Text('Here\'s some more information: $infoText',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.0
              ),
            ),
          ),
          Text('Wait a moment, then retry by hitting the button below. If the problem persists, contact an administrator.'),
          RaisedButton(
            onPressed: () {
              setState(() {
                loading = true;
              });
              attemptGetRoutes();
            },
            child: Text('Retry'),
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Loading();
    }
    if (errored) {
      return _buildErrorMessage();
    }
    if (recyclingRoutes.length == 0) {
      return Container(
        alignment: Alignment.center,
        padding: EdgeInsets.only(left: 75.0, right: 75.0),
        child: Text('There are no route options available. This may be an error; if you believe it is, contact your administrators.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24.0
          ),
        )
      );
    }
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.only(left: 20.0, right: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            child: Text(
              infoText,
              style: TextStyle(
                fontSize: 14.0,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
            padding: EdgeInsets.only(bottom: 5.0),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.7,
            child: Text(
              'As you begin to go on a route, select a route below, then tap "Begin Route".',
              style: TextStyle(
                fontSize: 18.0
              ),
              textAlign: TextAlign.center,
            ),
          ),
          DropdownButton<String>(
            value: selectedRoute,
            icon: Icon(Icons.arrow_drop_down),
            style: TextStyle(
              fontSize: 18.0,
              color: Colors.black
            ),
            iconSize: 18.0,
            onChanged: (String newValue) {
              setState(() {
                selectedRoute = newValue;
              });
            },
            items: recyclingRoutes.map<DropdownMenuItem<String>>((RecyclingRoute thisRoute) => DropdownMenuItem<String>(
                value: thisRoute.name,
                child: Text(thisRoute.name),
              )
            ).toList(),
          ),
          RaisedButton(
            onPressed: _handleBeginRoute,
            child: Text(
              'Begin Route',
              style: TextStyle(
                fontSize: 18.0
              ),
            ),
          )
        ],
      )
    );
  }
}