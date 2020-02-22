
import 'package:flutter/material.dart';
import 'package:route_recorder/api.dart';
import 'package:route_recorder/classes.dart';

class SelectRoute extends StatefulWidget {
  final Function changeRoute;
  final Function setActiveRoute;

  SelectRoute({
    Key key,
    this.changeRoute,
    this.setActiveRoute
  }) : super(key: key);
  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  @override
  _SelectRouteState createState() => _SelectRouteState();
}

class _SelectRouteState extends State<SelectRoute> {

  /// The route selected by user. Defaults to first route received.
  String selectedRoute;
  List<RecyclingRoute> recyclingRoutes = [];
  bool loading = true;

  @override
  initState() {
    getAllRoutes().then((List<RecyclingRoute> routes) {
      setState(() {
        recyclingRoutes = routes;
        selectedRoute = routes.length >= 0
          ? recyclingRoutes[0].name
          : null;
        loading = false;
      });
    });
    super.initState();
  }

  _handleBeginRoute() {
    RecyclingRoute activeRoute = recyclingRoutes.firstWhere((RecyclingRoute thisRoute) {
      return thisRoute.name == selectedRoute;
    });
    widget.setActiveRoute(activeRoute);
    widget.changeRoute(AppView.ACTIVE_ROUTE);
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Text('Loading...');
    }
    if (recyclingRoutes.length == 0) {
      return Text('There are no route options available. This may be due to an error; contact your administrators.');
    }
    return Column(
      children: <Widget>[
        Text('Select Route'),
        DropdownButton<String>(
          value: selectedRoute,
          icon: Icon(Icons.arrow_drop_down),
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
          child: Text('Begin Route'),
        )
      ],
    );
  }
}