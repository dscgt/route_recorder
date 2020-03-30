
import 'package:flutter/material.dart';
import 'package:route_recorder/api.dart';
import 'package:route_recorder/classes.dart';
import 'package:route_recorder/views/loading.dart';

enum ConfirmAction { CANCEL, CONFIRM }

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

  /// The route selected by user. Defaults to first route in the list, unless
  /// empty.
  Model selectedRoute;

  /// The route selected by the user to resume. Defaults to first route in the
  /// list, unless empty.
  UnfinishedRoute selectedUnfinishedRoute;

  /// List of all recycling routes available that crewmembers can go on.
  List<Model> recyclingRoutes = [];

  /// List of unfinished recycling routes.
  List<UnfinishedRoute> unfinishedRoutes = [];

  /// Information to display to the user. Is also displayed to user when there
  /// is an error.
  String infoText = '';

  /// Loading status of the page.
  bool loading = true;

  /// Error status of the page.
  bool errored = false;


  @override
  void initState() {
    getModels();
    getUnfinished();
    super.initState();
  }

  void getModels() {
    getAllRoutes().then((RoutesRetrieval mostRecentRoutes) {
      /// Get all groups to prep the Firebase cache. This won't be used
      /// explicitly in select_route, but groups will be used in route.dart.
      if (!mostRecentRoutes.fromCache) {
        getAllGroups();
      }
      setState(() {
        recyclingRoutes = mostRecentRoutes.routes;
        selectedRoute = mostRecentRoutes.routes.length > 0
          ? recyclingRoutes[0]
          : null;
        loading = false;
        infoText = mostRecentRoutes.fromCache
          ? 'We had some connection problems getting the most recent routes. The routes you see may be out of date.'
          : '';
        errored = false;
      });
    }).catchError((Object error, StackTrace st) {
      setState(() {
        print('error: $error');
        print('Stacktrace: $st');
        infoText = error.toString();
        errored = true;
        loading = false;
      });
    });
  }

  Future<dynamic> getUnfinished() async {
    try {
      List<UnfinishedRoute> theseUnfinishedRoutes = await getUnfinishedRoutes();
      setState(() {
        unfinishedRoutes = theseUnfinishedRoutes;
        selectedUnfinishedRoute = theseUnfinishedRoutes.length > 0
          ? theseUnfinishedRoutes[0]
          : null;
      });
    } catch (error, st) {
      setState(() {
        print('error: $error');
        print('Stacktrace: $st');
        infoText = error.toString();
        errored = true;
        loading = false;
      });
    }
  }

  void deleteUnfinishedRoute() async {
    try {
      await deleteUnfinishedRecord(selectedUnfinishedRoute.id);
    } catch (e) {
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: Text('Error; try again later, or contact a supervisor.')
        )
      );
      return;
    }
    getUnfinished();
  }

  /// Handles user click to begin a route. Directs user to active route view,
  /// starting a route session.
  void _handleBeginRoute() {
    widget.setActiveRoute(selectedRoute, null, null);
    widget.changeRoute(AppView.ACTIVE_ROUTE);
  }

  /// Handles user click to delete a route that isn't finished.
  void _handleDeleteUnfinishedRoute() async {
    showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure you want to delete your progress? There\'s no going back!'),
          actions: <Widget>[
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.CANCEL);
              },
              child: const Text('CANCEL'),
            ),
            FlatButton(
              onPressed: () {
                deleteUnfinishedRoute();
                Navigator.of(context).pop(ConfirmAction.CONFIRM);
              },
              child: const Text('CONFIRM'),
            ),
          ],
        );
      }
    );
  }

  /// Handles user click to resume a route. Directs user to active route view,
  /// starting a route session with some prepopulated data.
  void _handleResumeRoute() {
    widget.setActiveRoute(
      selectedUnfinishedRoute.model,
      selectedUnfinishedRoute.record,
      selectedUnfinishedRoute.id
    );
    widget.changeRoute(AppView.ACTIVE_ROUTE);
  }

  /// View for when this widget encounters an error. Utilizes infoText.
  Widget _buildErrorMessage() {
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
              getModels();
            },
            child: Text('Retry'),
          )
        ],
      )
    );
  }

  Widget _buildNewRouteSelection() {
    if (recyclingRoutes.length == 0) {
      return Text('There are no route options available. This may be an error; if you believe it is, contact your administrators.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24.0
        ),
      );
    }

    return Column(
      children: <Widget>[
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.7,
          child: Text(
            'Select a route below and tap "Begin Route" to begin a route.',
            style: TextStyle(
              fontSize: 18.0
            ),
            textAlign: TextAlign.center,
          ),
        ),
        DropdownButton<Model>(
          value: selectedRoute,
          icon: Icon(Icons.arrow_drop_down),
          style: TextStyle(
            fontSize: 18.0,
            color: Colors.black
          ),
          iconSize: 18.0,
          onChanged: (Model newValue) {
            setState(() {
              selectedRoute = newValue;
            });
          },
          items: recyclingRoutes.map<DropdownMenuItem<Model>>((Model thisRoute) =>
            DropdownMenuItem<Model>(
              value: thisRoute,
              child: Text(thisRoute.title),
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
        ),
      ],
    );
  }

  Widget _buildUnfinishedRouteSelection() {
    return Container(
      padding: EdgeInsets.only(top: 40.0),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.only(bottom: 10.0),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.7,
              child: Text(
                'Alternatively, if you\'ve saved routes for later, they\'ll'
                + ' show up here along with their start times. You can resume these'
                + ' at any time:',
                style: TextStyle(
                  fontSize: 18.0
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          unfinishedRoutes.length > 0
            ? DropdownButton<UnfinishedRoute>(
                value: selectedUnfinishedRoute,
                icon: Icon(Icons.arrow_drop_down),
                style: TextStyle(
                  fontSize: 18.0,
                  color: Colors.black
                ),
                iconSize: 18.0,
                onChanged: (UnfinishedRoute newValue) {
                  setState(() {
                    selectedUnfinishedRoute = newValue;
                  });
                },
                items: unfinishedRoutes.map<DropdownMenuItem<UnfinishedRoute>>((UnfinishedRoute thisRoute) =>
                  DropdownMenuItem<UnfinishedRoute>(
                    value: thisRoute,
                    child: Text(thisRoute.toShortString()),
                  )
                ).toList(),
              )
            : Text(
                'Nothing yet!'
              ),
          unfinishedRoutes.length > 0
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  RaisedButton(
                    onPressed: _handleDeleteUnfinishedRoute,
                    child: Text(
                      'Delete Route',
                      style: TextStyle(
                        fontSize: 18.0
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.only(right: 5),
                  ),
                  RaisedButton(
                    onPressed: _handleResumeRoute,
                    child: Text(
                      'Resume Route',
                      style: TextStyle(
                        fontSize: 18.0
                      ),
                    ),
                  ),
                ],
              )
            : null
        ].where((Object o) => o != null).toList()
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
          _buildNewRouteSelection(),
          _buildUnfinishedRouteSelection(),
        ],
      )
    );
  }
}