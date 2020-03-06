// TODO: test on galaxy tab!

import 'package:flutter/material.dart';
import 'package:route_recorder/api.dart';
import 'package:route_recorder/classes.dart';
import 'package:route_recorder/views/loading.dart';

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

enum ConfirmAction { CANCEL, CONFIRM }

class ActiveRouteState extends State<ActiveRoute> {

  TextStyle cardTextStyle = TextStyle(
    fontSize: 18.0
  );

  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  bool loadingAfterButtonPress = false;

  /// A map of a route's field's name -> its RecyclingRouteField. Useful for
  /// faster repeated metadata lookups.
  Map<String, RecyclingRouteField> routeMeta;
  /// A map of route field name -> text controller for user's response.
  Map<String, TextEditingController> routeFields;

  /// A map of a stop's ID -> its Stop. Useful for faster repeated metadata
  /// lookups.
  Map<String, Stop> stopMeta;
  /// A map of a stop's ID -> another map, keyed by a stop's field's name ->
  /// its StopField. Useful for faster metadata lookups.
  /// TODO: triple-deep map seems awful...consider refactoring...somehow?
  Map<String, Map<String, StopField>> stopFieldsMeta;
  /// A map of a stop's ID -> another map, keyed by a stop's field's name ->
  /// text controller for user's response.
  Map<String, Map<String, TextEditingController>> stopFields;
  /// The time when this route was started by the user.
  DateTime startTime;

  @override
  void initState() {
    if (widget.activeRoute == null) {
      widget.changeRoute(AppView.SELECT_ROUTE);
    }
    Map<String, RecyclingRouteField> routeMetaToAdd = {};
    Map<String, TextEditingController> routeFieldsToAdd = {};
    Map<String, Stop> stopMetaToAdd = {};
    Map<String, Map<String, StopField>> stopFieldsMetaToAdd = {};
    Map<String, Map<String, TextEditingController>> stopFieldsToAdd = {};

    /// Convert data from given widget into forms usable by build process.
    widget.activeRoute.fields.forEach((RecyclingRouteField rr) {
      routeMetaToAdd[rr.name] = rr;
      routeFieldsToAdd[rr.name] = TextEditingController();
    });
    widget.activeRoute.stops.forEach((Stop s) {
      stopMetaToAdd[s.id] = s;
      widget.activeRoute.stopFields.forEach((StopField sf) {
        if (stopFieldsMetaToAdd[s.id] == null) {
          stopFieldsMetaToAdd[s.id] = {};
        }
        stopFieldsMetaToAdd[s.id][sf.name] = sf;

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
      startTime = DateTime.now();
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

  void _handleCancelRoute(BuildContext context) {
    showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure you want to cancel? All entered data will be lost.'),
          actions: <Widget>[
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.CANCEL);
              },
              child: const Text('NO'),
            ),
            FlatButton(
              onPressed: () {
                widget.changeRoute(AppView.SELECT_ROUTE);
                Navigator.of(context).pop(ConfirmAction.CONFIRM);
              },
              child: const Text('YES'),
            ),
          ],
        );
      }
    );
  }

  void submitRoute() async {
    setState(() {
      loadingAfterButtonPress = true;
    });

    /// Create a submission object from info entered by user.
    RecyclingRouteSubmission thisSubmission = RecyclingRouteSubmission(
      routeId: widget.activeRoute.id,
      startTime: startTime,
      endTime: DateTime.now(),
      routeFields: routeFields.map((String fieldName, TextEditingController fieldController) {
        return MapEntry(fieldName, fieldController.text);
      }),
      stops: stopFields.entries.map((MapEntry me) {
        String thisStopId = me.key;
        Map<String, TextEditingController> thisStopDetails = me.value;

        return StopSubmission(
          stopId: thisStopId,
          stopFields: thisStopDetails.map((String stopFieldName, TextEditingController thisController) {
            return MapEntry(stopFieldName, thisController.text);
          }),
        );
      }).toList()
    );

    /// Submit this route record, and direct user back to route selection if
    /// successful.
    try {
      await submitRecord(thisSubmission);
    } catch (e) {
      setState(() {
        loadingAfterButtonPress = false;
      });
      print('error: $e');
      showDialog<ConfirmAction>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Something went wrong. Wait a bit, then try to submit it again. Try moving to an area with a better connection.\nIf this issue persists, keep this screen open or write it down, and report the problem to your supervisors.'),
            actions: <Widget>[
              FlatButton(
                onPressed: () {
                  Navigator.of(context).pop(ConfirmAction.CANCEL);
                },
                child: const Text('OKAY'),
              ),
            ],
          );
        }
      );
      return;
    }
    Scaffold.of(context).showSnackBar(
      SnackBar(
        content: Text('Route submitted. Thanks!')
      )
    );
    widget.changeRoute(AppView.SELECT_ROUTE);
  }

  void _handleFinishRoute(BuildContext context) async {
    /// Validation check.
    if (!_formKey.currentState.validate()) {
      return;
    }

    showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure you want to submit this?'),
          actions: <Widget>[
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.CANCEL);
              },
              child: const Text('CANCEL'),
            ),
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.CONFIRM);
                submitRoute();
              },
              child: const Text('CONFIRM'),
            ),
          ],
        );
      }
    );
  }

  /// Builds the upper portion of the screen, the part of the form that displays
  /// route information, and gathers user entry about the route overall (and
  /// not individual stops).
  Widget _buildRouteTitleCard() {
    List<Widget> theseFields = [];
    routeFields.forEach((String fieldName, TextEditingController thisController) {
      bool isOptional = routeMeta[fieldName].isOptional;
      theseFields.add(
        Row(
          children: <Widget>[
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
                  hintText: isOptional
                    ? '$fieldName (optional)'
                    : fieldName
                ),
              )
            )
          ],
        )
      );
    });

    return Card(
      child: Container(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: <Widget>[
            Text(
              widget.activeRoute.name,
              style: cardTextStyle,
            ),
            Text(
              'Your start and end times for this route will be recorded automatically.',
              style: cardTextStyle.copyWith(
                fontSize: cardTextStyle.fontSize - 4.0
              ),
            ),
            ...theseFields
          ]
        )
      )
    );
  }

  /// Builds the part of the form that gathers user entry about stops along the
  /// route.
  Widget _buildStops() {
    List<String> ids = stopFields.keys.toList();
    return ListView.builder(
      itemCount: stopFields.length,
      itemBuilder: (BuildContext context, int index) {
        String thisStopId = ids[index];
        Map<String, TextEditingController> theseControllers = stopFields[thisStopId];
        List<Widget> rowElements = [];
        theseControllers.forEach((String fieldName, TextEditingController thisController) {
          bool isOptional = stopFieldsMeta[thisStopId][fieldName].isOptional;
          rowElements.add(
            TextFormField(
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
          );
        });
        return Card(
          child: Container(
            padding: const EdgeInsets.all(10.0),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.3,
                  child: Container(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: <Widget>[
                        Text(
                          stopMeta[thisStopId].name,
                          style: cardTextStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        stopMeta[thisStopId].address != null
                          ? Text(
                              'Address: ${stopMeta[thisStopId].address}',
                              style: cardTextStyle.copyWith(
                                fontSize: cardTextStyle.fontSize - 2.0
                              ),
                              textAlign: TextAlign.center,
                            )
                          : null
                      ].where((o) => o != null).toList(),
                    ),
                  ),
                ),
                Expanded(
                 child: Column(
                    children: rowElements
                  )
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubmissionArea(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(right: 10),
              child: RaisedButton(
                child: Text(
                  'Cancel',
                  style: cardTextStyle,
                ),
                onPressed: loadingAfterButtonPress
                  ? null
                  : () => _handleCancelRoute(context)
              ),
            ),
            RaisedButton(
              child: Text(
                'Finish',
                style: cardTextStyle,
              ),
              onPressed: loadingAfterButtonPress
                ? null
                : () => _handleFinishRoute(context),
            ),
          ]
        ),
        loadingAfterButtonPress
          ? Text('Loading...')
          : null
      ].where((o) => o != null).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Loading();
    }

    return Container(
      padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 30.0, bottom: 10.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: <Widget>[
            _buildRouteTitleCard(),
            Expanded(
              child: _buildStops()
            ),
            _buildSubmissionArea(context)
          ],
        ),
      ),
    );
  }
}