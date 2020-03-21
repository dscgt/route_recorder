import 'package:flutter/material.dart';
import 'package:route_recorder/api.dart';
import 'package:route_recorder/classes.dart';
import 'package:route_recorder/views/loading.dart';

class ActiveRoute extends StatefulWidget {
  final Model activeRoute;
  final Record activeRouteSavedData;
  final String activeRouteSavedId;
  final Function resetRoute;

  ActiveRoute({
    Key key,
    this.activeRoute,
    this.activeRouteSavedData,
    this.activeRouteSavedId,
    this.resetRoute
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

  /// A map of a route's field's name -> its ModelField. Useful for
  /// faster repeated metadata lookups.
  Map<String, ModelField> routeMeta;
  /// A map of route field name -> text controller for user's response.
  Map<String, TextEditingController> routeFields;

  /// A map of a stop's title -> its Stop. Useful for faster repeated metadata
  /// lookups.
  Map<String, Stop> stopMeta;
  /// A map of a stop's title -> another map, keyed by a stop's field's name ->
  /// its StopField. Useful for faster metadata lookups.
  Map<String, Map<String, StopField>> stopFieldsMeta;
  /// A map of a stop's title -> another map, keyed by a stop's field's name ->
  /// text controller for user's response.
  Map<String, Map<String, TextEditingController>> stopFields;
  /// The time when this route was started by the user.
  DateTime startTime;

  @override
  void initState() {
    if (widget.activeRoute == null) {
      widget.resetRoute();
    }
    Map<String, ModelField> routeMetaToAdd = {};
    Map<String, TextEditingController> routeFieldsToAdd = {};
    Map<String, Stop> stopMetaToAdd = {};
    Map<String, Map<String, StopField>> stopFieldsMetaToAdd = {};
    Map<String, Map<String, TextEditingController>> stopFieldsToAdd = {};

    /// Convert data from given widget into forms usable by build process.
    widget.activeRoute.fields.forEach((ModelField rr) {
      routeMetaToAdd[rr.title] = rr;
      routeFieldsToAdd[rr.title] = TextEditingController();
    });
    widget.activeRoute.stops.forEach((Stop s) {
      stopMetaToAdd[s.title] = s;
      widget.activeRoute.stopFields.forEach((StopField sf) {
        if (stopFieldsMetaToAdd[s.title] == null) {
          stopFieldsMetaToAdd[s.title] = {};
        }
        stopFieldsMetaToAdd[s.title][sf.title] = sf;

        if (stopFieldsToAdd[s.title] == null) {
          stopFieldsToAdd[s.title] = {};
        }
        stopFieldsToAdd[s.title][sf.title] = TextEditingController();
      });
    });

    /// Prepopulate fields with previously entered data if provided.
    if (widget.activeRouteSavedData != null) {
      /// Prepopulate what will be the route's general fields' - the fields
      /// about which appear at the top of the screen.
      routeFieldsToAdd.forEach((String fieldTitle, TextEditingController controller) {
        String savedData = widget.activeRouteSavedData.properties[fieldTitle];
        if (savedData != null) {
          controller.text = savedData;
        }
      });

      /// Prepopulate what will be stops' fields - the fields within the rows
      /// of the main body of the screen.
      stopFieldsToAdd.forEach((String stopTitle, Map<String, TextEditingController> routeFields) {
        stopFieldsToAdd[stopTitle].forEach((String stopFieldTitle, TextEditingController controller) {
          /// TODO: make this lookup more efficient
          String savedData = widget.activeRouteSavedData.stops.firstWhere((RecordStop stop) => stop.title == stopTitle).properties[stopFieldTitle];
          if (savedData != null) {
            controller.text = savedData;
          }
        });
      });
    }

    /// Set start time as the current time, unless this is a resumed route.
    DateTime startTimeToAdd = widget.activeRouteSavedData != null
      ? widget.activeRouteSavedData.startTime
      : DateTime.now();

    setState(() {
      routeMeta = routeMetaToAdd;
      routeFields = routeFieldsToAdd;
      stopMeta = stopMetaToAdd;
      stopFields = stopFieldsToAdd;
      stopFieldsMeta = stopFieldsMetaToAdd;
      isLoading = false;
      startTime = startTimeToAdd;
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

  void saveRouteForLater() async {
    setState(() {
      loadingAfterButtonPress = true;
      isLoading = true;
    });

    /// Create a submission object from info entered by user. Doesn't create
    /// properties for empty values; these are allowed to be null.
    Map<String, String> propertiesToSave = {};
    routeFields.forEach((String fieldName, TextEditingController fieldController) {
      if (fieldController.text.length > 0) {
        propertiesToSave[fieldName] = fieldController.text;
      }
    });
    Record thisSubmission = Record(
      modelId: widget.activeRoute.id,
      modelTitle: widget.activeRoute.title,
      startTime: startTime,
      endTime: null,
      properties: propertiesToSave,
      stops: stopFields.entries.map((MapEntry me) {
        String thisStopTitle = me.key;
        Map<String, TextEditingController> thisStopDetails = me.value;

        Map<String, String> stopPropertiesToSave = {};
        thisStopDetails.forEach((String key, TextEditingController controller) {
          if (controller.text.length > 0) {
            stopPropertiesToSave[key] = controller.text;
          }
        });
        return RecordStop(
          title: thisStopTitle,
          properties: stopPropertiesToSave,
        );
      }).toList()
    );

    try {
      await saveRecord(UnfinishedRoute(
        record: thisSubmission,
        model: widget.activeRoute,
        id: widget.activeRouteSavedId
      ));
    } catch (e, st) {
      setState(() {
        loadingAfterButtonPress = false;
        isLoading = false;
        print('error: $e');
        print('Stacktrace: $st');
        showDialog<ConfirmAction>(
          context: context,
          barrierDismissible: true,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Something went wrong. Wait a bit, then try to submit it again. \nIf this issue persists, keep this screen open or write it down, and report the problem to your supervisors.'),
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
      });
      return;
    }
    Scaffold.of(context).showSnackBar(
      SnackBar(
        content: Text('Route saved. Thanks!')
      )
    );
    widget.resetRoute();
  }

  void submitRoute() async {
    setState(() {
      loadingAfterButtonPress = true;
      isLoading = true;
    });

    /// Create a submission object from info entered by user.
    Record thisSubmission = Record(
      modelId: widget.activeRoute.id,
      modelTitle: widget.activeRoute.title,
      startTime: startTime,
      endTime: DateTime.now(),
      properties: routeFields.map((String fieldName, TextEditingController fieldController) {
        return MapEntry(fieldName, fieldController.text);
      }),
      stops: stopFields.entries.map((MapEntry me) {
        String thisStopTitle = me.key;
        Map<String, TextEditingController> thisStopDetails = me.value;

        return RecordStop(
          title: thisStopTitle,
          properties: thisStopDetails.map((String stopFieldName, TextEditingController thisController) {
            return MapEntry(stopFieldName, thisController.text);
          }),
        );
      }).toList()
    );

    /// Submit this route record, and direct user back to route selection if
    /// successful.
    bool directlySuccessful;
    try {
      directlySuccessful = await submitRecord(thisSubmission);
      if (widget.activeRouteSavedId != null) {
        await deleteUnfinishedRecord(widget.activeRouteSavedId);
      }
    } catch (e, st) {
      setState(() {
        loadingAfterButtonPress = false;
        isLoading = false;
      });
      print('error: $e');
      print('Stacktrace: $st');
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
    if (directlySuccessful) {
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: Text('Route submitted. Thanks!')
        )
      );
    } else {
      Scaffold.of(context).showSnackBar(
        SnackBar(
          content: Text('Route will be submitted once you are connected to the Internet.')
        )
      );
    }
    widget.resetRoute();
  }

  void _handleCancelRoute(BuildContext context) {
    showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure you want to cancel? All newly-entered data will be lost.'),
          actions: <Widget>[
            FlatButton(
              onPressed: () {
                Navigator.of(context).pop(ConfirmAction.CANCEL);
              },
              child: const Text('NO'),
            ),
            FlatButton(
              onPressed: () {
                widget.resetRoute();
                Navigator.of(context).pop(ConfirmAction.CONFIRM);
              },
              child: const Text('YES'),
            ),
          ],
        );
      }
    );
  }

  void _handleSaveRouteForLater(BuildContext context) {
    showDialog<ConfirmAction>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure you want to save this for later?'),
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
                saveRouteForLater();
              },
              child: const Text('CONFIRM'),
            ),
          ],
        );
      }
    );
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
      bool isOptional = routeMeta[fieldName].optional;
      TextInputType thisKeyboardType = routeMeta[fieldName].type == 'number'
        ? TextInputType.number
        : TextInputType.text;
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
                keyboardType: thisKeyboardType,
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
              widget.activeRoute.title,
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
    return Column(
      children: ids.map((String thisStopId) {
        Map<String, TextEditingController> theseControllers = stopFields[thisStopId];
        List<Widget> rowElements = [];
        theseControllers.forEach((String fieldName, TextEditingController thisController) {
          bool isOptional = stopFieldsMeta[thisStopId][fieldName].optional;
          TextInputType thisKeyboardType = stopFieldsMeta[thisStopId][fieldName].type == 'number'
            ? TextInputType.number
            : TextInputType.text;
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
              ),
              keyboardType: thisKeyboardType,
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
                          stopMeta[thisStopId].title,
                          style: cardTextStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        stopMeta[thisStopId].description != null && stopMeta[thisStopId].description.trim().length > 0
                          ? Text(
                              '${stopMeta[thisStopId].description}',
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
      }).toList()
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
            Container(
              padding: const EdgeInsets.only(right: 10),
              child: RaisedButton(
                child: Text(
                  'Save',
                  style: cardTextStyle,
                ),
                onPressed: loadingAfterButtonPress
                  ? null
                  : () => _handleSaveRouteForLater(context)
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

    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 30.0, bottom: 10.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              _buildRouteTitleCard(),
              _buildStops(),
              _buildSubmissionArea(context)
            ],
          ),
        ),
      )
    );
  }
}