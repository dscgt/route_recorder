
import 'package:flutter/material.dart';
import 'package:route_recorder/api.dart';
import 'package:route_recorder/classes.dart';

class ActiveRoute extends StatefulWidget {
  final RecyclingRoute activeRoute;
  final Function changeRoute;

  ActiveRoute({
    Key key,
    this.activeRoute,
    this.changeRoute,
  }) : super(key: key);

  @override
  ActiveRouteState createState() => ActiveRouteState();
}

class ActiveRouteState extends State<ActiveRoute> {

  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;

  /// A map of a route's field's name -> another map of metadata about the
  /// route's field. Useful for faster repeated metadata lookups.
  Map<String, Map<String, dynamic>> routeMeta;
  /// A map of route field name -> text controller for user's response.
  Map<String, TextEditingController> routeFields;


  /// A map of a stop's ID -> another map of metadata about that stop. Useful
  /// for faster repeated metadata lookups.
  Map<String, Map<String, dynamic>> stopMeta;
  /// A map of a stop's ID -> another map, keyed by a stop's field's name ->
  /// metadata about the stop's field. Useful for faster metadata lookups.
  /// TODO: triple-deep map seems awful...consider refactoring, maybe splitting into another widget
  Map<String, Map<String, Map<String, dynamic>>> stopFieldsMeta;
  /// A map of a stop's ID -> another map, keyed by a stop's field's name ->
  /// text controller for user's response.
  Map<String, Map<String, TextEditingController>> stopFields;

  @override
  void initState() {
    if (widget.activeRoute == null) {
      widget.changeRoute(AppView.SELECT_ROUTE);
    }
    Map<String, Map<String, dynamic>> routeMetaToAdd = {};
    Map<String, TextEditingController> routeFieldsToAdd = {};
    Map<String, Map<String, dynamic>> stopMetaToAdd = {};
    Map<String, Map<String, Map<String, dynamic>>> stopFieldsMetaToAdd = {};
    Map<String, Map<String, TextEditingController>> stopFieldsToAdd = {};

    /// Convert data from given widget into forms usable by build process.
    widget.activeRoute.fields.forEach((RecyclingRouteField rr) {
      if (routeMetaToAdd[rr.name] == null) {
        routeMetaToAdd[rr.name] = {};
      }
      routeMetaToAdd[rr.name]['optional'] = rr.isOptional;
      routeFieldsToAdd[rr.name] = TextEditingController();
    });
    widget.activeRoute.stops.forEach((Stop s) {
      if (stopMetaToAdd[s.id] == null) {
        stopMetaToAdd[s.id] = {};
      }
      stopMetaToAdd[s.id]['name'] = s.name;
      stopMetaToAdd[s.id]['address'] = s.address;
      widget.activeRoute.stopFields.forEach((StopField sf) {
        if (stopFieldsMetaToAdd[s.id] == null) {
          stopFieldsMetaToAdd[s.id] = {};
        }
        if (stopFieldsMetaToAdd[s.id][sf.name] == null) {
          stopFieldsMetaToAdd[s.id][sf.name] = {};
        }
        stopFieldsMetaToAdd[s.id][sf.name]['optional'] = sf.isOptional;

        if (stopFieldsToAdd[s.id] == null) {
          stopFieldsToAdd[s.id] = {};
        }
        stopFieldsToAdd[s.id][sf.name] = TextEditingController();
      });
    });

    setState(() {
      routeMeta = routeMetaToAdd;
      routeFields = routeFieldsToAdd;
      stopMeta = stopMetaToAdd;
      stopFields = stopFieldsToAdd;
      stopFieldsMeta = stopFieldsMetaToAdd;
      isLoading = false;
    });
    super.initState();
  }

  @override
  void dispose() {
    /// Clean up all active TextEditingController's.
    routeFields.forEach((String s, TextEditingController controller) {
      controller.dispose();
    });
    stopFields.forEach((String s, Map<String, TextEditingController> controllerMap) {
      controllerMap.forEach((String s2, TextEditingController controller) {
        controller.dispose();
      });
    });

    super.dispose();
  }

  void _handleFinishRoute() async {
    /// Create a submission object from info entered by user.
    RecyclingRouteSubmission thisSubmission = RecyclingRouteSubmission(
      routeId: widget.activeRoute.id,
      routeFields: routeFields.map((String fieldName, TextEditingController fieldController) {
        return MapEntry(fieldName, fieldController.text);
      }),
      stops: stopFields.entries.map((MapEntry me) {
        String thisStopId = me.key;
        Map<String, TextEditingController> thisStopDetails = me.value;

        return StopSubmission(
          stopId: thisStopId,
          routeFields: thisStopDetails.map((String stopFieldName, TextEditingController thisController) {
            return MapEntry(stopFieldName, thisController.text);
          }),
        );
      }).toList()
    );

    /// Submit this route record, and direct user back to route selection if
    /// successful.
    try {
      await submitRecord(thisSubmission);
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: Text('Route submitted. Thanks!')
        )
      );
      widget.changeRoute(AppView.SELECT_ROUTE);
    } catch (e) {
      /// TODO: handle errors...
      print('Error happened.');
    }
  }

  /// Builds the upper portion of the screen, the part of the form that displays
  /// route information, and gathers user entry about the route overall (and
  /// not individual stops).
  Widget _buildRouteTitleCard() {
    List<Widget> theseFields = [];
    routeFields.forEach((String fieldName, TextEditingController thisController) {
      bool isOptional = routeMeta[fieldName]['optional'];
      theseFields.add(
        Row(
          children: <Widget>[
            Text('$fieldName:'),
            Expanded(
              child: TextFormField(
                controller: thisController,
                validator: (value) {
                  if (value.isEmpty && !isOptional) {
                    return 'Please enter a $fieldName.';
                  }
                  return null;
                },
                decoration: isOptional
                    ? InputDecoration(
                    hintText: '(optional)'
                )
                    : null,
              )
            )
          ],
        )
      );
    });

    return Card(
      child: Column(
        children: <Widget>[
          Text(widget.activeRoute.name),
          ...theseFields
        ]
      )
    );
  }

  /// Builds the part of the form that gathers user entry about stops along the
  /// route.
  Widget _buildRows() {
    List<String> ids = stopFields.keys.toList();
    return ListView.builder(
      itemCount: stopFields.length,
      itemBuilder: (BuildContext context, int index) {
        String thisStopId = ids[index];
        Map<String, TextEditingController> theseControllers = stopFields[thisStopId];

        List<Widget> rowElements = [];
        theseControllers.forEach((String fieldName, TextEditingController thisController) {
          bool isOptional = stopFieldsMeta[thisStopId][fieldName]['optional'];
          rowElements.add(
            Expanded(
              child: TextFormField(
                controller: thisController,
                validator: (value) {
                  if (value.isEmpty && !isOptional) {
                    return 'Please enter a $fieldName.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: isOptional ? '$fieldName (optional)' : fieldName
                )
              )
            )
          );
        });
        return Row(
          children: <Widget>[
            Text(stopMeta[thisStopId]['name']),
            ...rowElements
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Text('Loading...');
    }

    return Form(
      key: _formKey,
      child: Column(
        children: <Widget>[
          _buildRouteTitleCard(),
          Expanded(
              child: _buildRows()
          ),
          RaisedButton(
            child: Text('Finish'),
            onPressed: _handleFinishRoute,
          )
        ],
      ),
    );
  }
}