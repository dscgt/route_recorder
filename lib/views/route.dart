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
  /// faster repeated metadata lookups, and also an ordered master list of
  /// route fields.
  Map<String, ModelField> routeMeta;
  /// A map of route field name -> text controller for user's response.
  Map<String, TextEditingController> routeFields;
  /// A map of route field name -> dropdown value. For user responses that
  /// require a dropdown.
  Map<String, String> routeFieldsForDropdown;

  /// A map of a stop's title -> its Stop. Useful for faster repeated metadata
  /// lookups, and also serves as an ordered master list of stops.
  Map<String, Stop> stopMeta;
  /// A map of a stop's title -> another map, keyed by a stop's field's name ->
  /// its StopField. Useful for faster metadata lookups, and also serves as
  /// an ordered master list of stop fields.
  Map<String, Map<String, StopField>> stopFieldsMeta;
  /// A map of a stop's title -> another map, keyed by a stop's field's name ->
  /// text controller for user's response.
  Map<String, Map<String, TextEditingController>> stopFields;
  /// A map of a stop's title -> another map, keyed by a stop's field's name ->
  /// dropdown values. For user responses that require a dropdown.
  Map<String, Map<String, String>> stopFieldsForDropdown;

  /// A record of groupId -> Group. For fast lookups about groups.
  Map<String, Group> groupsMeta = {};

  /// The time when this route was started by the user.
  DateTime startTime;

  @override
  void initState() {
    if (widget.activeRoute == null) {
      widget.resetRoute();
    }

    initRouteState();
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

  initRouteState() async {
    /// Extract needed group IDs from active route
    List<String> groupIds = [];
    widget.activeRoute.fields.forEach((ModelField mf) {
      if (mf.type == FieldDataType.select) groupIds.add(mf.groupId);
    });
    widget.activeRoute.stopData.fields.forEach((StopField sf) {
      if (sf.type == FieldDataType.select) groupIds.add(sf.groupId);
    });
    List<Group> groups;
    try {
      groups = (await getGroups(groupIds)).groups;
    } catch (e, st) {
      setState(() {
        print('error: $e');
        print('Stacktrace: $st');
      });
      showDialog<ConfirmAction>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Something went wrong. Try to retry below. \nIf this issue persists, report the problem to your supervisors.'),
            actions: <Widget>[
              FlatButton(
                onPressed: () {
                  Navigator.of(context).pop(ConfirmAction.CONFIRM);
                  initRouteState();
                },
                child: const Text('RETRY'),
              ),
            ],
          );
        }
      );
      return;
    }
    Map<String, Group> groupsMetaToAdd = {};
    groups.forEach((Group g) {
      groupsMetaToAdd[g.id] = g;
    });

    Map<String, ModelField> routeMetaToAdd = {};
    Map<String, TextEditingController> routeFieldsToAdd = {};
    Map<String, String> routeFieldsForDropdownToAdd = {}; // nothing is done to this for now except including it in the setState
    Map<String, Stop> stopMetaToAdd = {};
    Map<String, Map<String, StopField>> stopFieldsMetaToAdd = {};
    Map<String, Map<String, TextEditingController>> stopFieldsToAdd = {};
    Map<String, Map<String, String>> stopFieldsForDropdownToAdd = {};


    /// Convert data from given widget into forms usable by build process.
    widget.activeRoute.fields.forEach((ModelField rr) {
      routeMetaToAdd[rr.title] = rr;
      if (rr.type != FieldDataType.select) {
        routeFieldsToAdd[rr.title] = TextEditingController();
      }
    });
    widget.activeRoute.stopData.stops.forEach((Stop s) {
      stopMetaToAdd[s.title] = s;
      stopFieldsMetaToAdd[s.title] = {};
      stopFieldsToAdd[s.title] = {};
      stopFieldsForDropdownToAdd[s.title] = {};

      widget.activeRoute.stopData.fields.forEach((StopField sf) {
        stopFieldsMetaToAdd[s.title][sf.title] = sf;
        if (sf.type != FieldDataType.select) {
          stopFieldsToAdd[s.title][sf.title] = TextEditingController();
        }
      });
    });

    /// Prepopulate fields with previously entered data if provided.
    if (widget.activeRouteSavedData != null) {
      /// Prepopulate what will be the route's general fields' - the fields
      /// which appear at the top of the screen.
      routeMetaToAdd.forEach((String title, ModelField mf) {
        String savedData = widget.activeRouteSavedData.properties[title];
        if (savedData != null) {
          if (mf.type == FieldDataType.select) {
            routeFieldsForDropdownToAdd[title] = savedData;
          } else {
            routeFieldsToAdd[title].text = savedData;
          }
        }
      });

      /// Prepopulate what will be stops' fields - the fields within the rows
      /// of the main body of the screen.
      stopFieldsMetaToAdd.forEach((String stopTitle, Map<String, StopField> fields) {
        fields.forEach((String fieldTitle, StopField sf) {
          /// TODO: make this lookup more efficient
          String savedData = widget.activeRouteSavedData.stops
            .firstWhere((RecordStop stop) => stop.title == stopTitle)
            .properties[fieldTitle];
          if (savedData != null) {
            if (sf.type == FieldDataType.select) {
              stopFieldsForDropdownToAdd[stopTitle][fieldTitle] = savedData;
            } else {
              stopFieldsToAdd[stopTitle][fieldTitle].text = savedData;
            }
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
      routeFieldsForDropdown = routeFieldsForDropdownToAdd;
      stopMeta = stopMetaToAdd;
      stopFields = stopFieldsToAdd;
      stopFieldsForDropdown = stopFieldsForDropdownToAdd;
      stopFieldsMeta = stopFieldsMetaToAdd;
      isLoading = false;
      startTime = startTimeToAdd;
      groupsMeta = groupsMetaToAdd;
    });
  }

  void saveRouteForLater() async {
    setState(() {
      loadingAfterButtonPress = true;
      isLoading = true;
    });

    // Create a submission object from info entered by user. Doesn't create
    // properties for empty values; these are allowed to be null.
    // start by handling top-level fields
    Map<String, String> propertiesToAdd = {};
    routeFields.forEach((String fieldName, TextEditingController fieldController) {
      if (fieldController.text.length > 0) {
        propertiesToAdd[fieldName] = fieldController.text;
      }
    });
    routeFieldsForDropdown.forEach((String fieldName, String value) {
      if (value != null) {
        propertiesToAdd[fieldName] = value;
      }
    });
    // Then, we have to handle stop fields.
    // First handle non-dropdown stop fields...
    Map<String, Map<String, String>> stopsToAdd = stopFields.map((String stopTitle, Map<String, TextEditingController> stopDetails) {
      Map<String, String> propertiesToAdd = {};
      stopDetails.forEach((String stopFieldTitle, TextEditingController controller) {
        if (controller.text.length > 0) {
          propertiesToAdd[stopFieldTitle] = controller.text;
        }
      });
      return MapEntry(
        stopTitle,
        propertiesToAdd
      );
    });
    // ...then handle dropdown stop fields
    stopFieldsForDropdown.forEach((String stopTitle, Map<String, String> stopDetails) {
      Map<String, String> propertiesToAdd = {};
      stopDetails.forEach((String stopFieldTitle, String value) {
        if (value != null) {
          propertiesToAdd[stopFieldTitle] = value;
        }
      });
      propertiesToAdd.forEach((String fieldName, String fieldValue) {
        if (!stopsToAdd.containsKey(stopTitle)) {
          stopsToAdd[stopTitle] = {};
        }
        stopsToAdd[stopTitle][fieldName] = fieldValue;
      });
    });
    // Now that we have gathered both non-dropdown and dropdown fields, can
    // build the list of RecordStop
    List<RecordStop> stopsToAddAsList = stopsToAdd.entries.map((MapEntry<String, Map<String, String>> me) =>
      RecordStop(
        title: me.key,
        properties: me.value
      )
    ).toList();

    // create titles for `saves` property
    // ONLY include a stop in 'saves' if ALL of its nonoptional fields have been
    // filled out. Remember, once a stop is in 'saves' it is greyed out in
    // further resumes!
    List<String> stopTitlesToSave = [];
    stopsToAddAsList.forEach((RecordStop rs) {
      bool shouldAddThisStopToSave = true;
      stopFieldsMeta[rs.title].forEach((String fieldTitle, StopField sf) {
        if (!sf.optional && !rs.properties.containsKey(fieldTitle)) {
          shouldAddThisStopToSave = false;
        }
      });
      if (shouldAddThisStopToSave) {
        stopTitlesToSave.add(rs.title);
      }
    });

    // remove titles that belong to previous saves, if any exist
    if (widget.activeRouteSavedData != null) {
      widget.activeRouteSavedData.saves.forEach((RecordSaveObject rso) {
        rso.stops.forEach((String s) {
          int ind = stopTitlesToSave.indexOf(s);
          if (ind != -1) {
            stopTitlesToSave.removeAt(ind);
          }
        });
      });
    }
    // add this save to previous saves, if any exist
    List<RecordSaveObject> newSaves = [];
    if (widget.activeRouteSavedData != null) {
      newSaves.addAll(widget.activeRouteSavedData.saves);
    }
    newSaves.add(RecordSaveObject(
      stops: stopTitlesToSave,
      saveTime: DateTime.now()
    ));

    Record thisSubmission = Record(
      modelId: widget.activeRoute.id,
      modelTitle: widget.activeRoute.title,
      startTime: startTime,
      endTime: null,
      properties: propertiesToAdd,
      stops: stopsToAddAsList,
      saves: newSaves
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
      });
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

    // Create a submission object from info entered by user.
    // start by handling top-level fields
    Map<String, String> propertiesToAdd = {};
    routeFields.forEach((String fieldName, TextEditingController controller) {
      propertiesToAdd[fieldName] = controller.text;
    });
    routeFieldsForDropdown.forEach((String fieldName, String value) {
      propertiesToAdd[fieldName] = value;
    });
    // Then, we have to handle stop fields.
    // First handle non-dropdown stop fields...
    Map<String, Map<String, String>> stopsToAdd = stopFields.map((String stopTitle, Map<String, TextEditingController> stopDetails) {
      // change texteditingcontrollers into consumable maps, then filter maps
      // for excluded fields before adding to submission object
      Map<String, String> propertiesToAdd = stopDetails.map((String fieldName, TextEditingController controller) =>
        MapEntry(fieldName, controller.text)
      );
      List<String> exclude = stopMeta[stopTitle].exclude ?? [];
      propertiesToAdd.removeWhere((String fieldName, String fieldVal) => exclude.contains(fieldName));
      return MapEntry(
        stopTitle,
        propertiesToAdd
      );
    });
    // ...then handle dropdown stop fields
    stopFieldsForDropdown.forEach((String stopTitle, Map<String, String> stopDetails) {
      // filter dropdown maps for excluded fields before adding to submission object
      Map<String, String> propertiesToAdd = Map.from(stopDetails);
      List<String> exclude = stopMeta[stopTitle].exclude ?? [];
      propertiesToAdd.removeWhere((String fieldName, String fieldValue) => exclude.contains(fieldName));
      propertiesToAdd.forEach((String fieldName, String fieldValue) {
        if (!stopsToAdd.containsKey(stopTitle)) {
          stopsToAdd[stopTitle] = {};
        }
        stopsToAdd[stopTitle][fieldName] = fieldValue;
      });
    });
    // Now that we have gathered both non-dropdown and dropdown fields, can
    // build the list of RecordStop
    List<RecordStop> stopsToAddAsList = stopsToAdd.entries.map((MapEntry<String, Map<String, String>> me) =>
      RecordStop(
        title: me.key,
        properties: me.value
      )
    ).toList();

    // create titles for `saves` property
    // since we are submitting this route, these are just all titles that weren't covered
    // by previous saves
    List<String> stopTitlesToSave = stopsToAddAsList.map((RecordStop rs) =>
        rs.properties.length > 0
          ? rs.title
          : null
    ).toList();
    stopTitlesToSave.removeWhere((String s) => s == null);
    // remove titles that belong to previous saves, if any exist
    if (widget.activeRouteSavedData != null) {
      widget.activeRouteSavedData.saves.forEach((RecordSaveObject rso) {
        rso.stops.forEach((String s) {
          int ind = stopTitlesToSave.indexOf(s);
          if (ind != -1) {
            stopTitlesToSave.removeAt(ind);
          }
        });
      });
    }
    // add current save to previous saves, if any exist
    List<RecordSaveObject> newSaves = [];
    if (widget.activeRouteSavedData != null) {
      newSaves.addAll(widget.activeRouteSavedData.saves);
    }
    DateTime thisEndDate = DateTime.now();
    newSaves.add(RecordSaveObject(
      stops: stopTitlesToSave,
      saveTime: thisEndDate
    ));

    Record thisSubmission = Record(
      modelId: widget.activeRoute.id,
      modelTitle: widget.activeRoute.title,
      startTime: startTime,
      endTime: thisEndDate,
      properties: propertiesToAdd,
      stops: stopsToAddAsList,
      saves: newSaves
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
          title: const Text('Are you sure you want to save this for later? You can resume it later. If someone else will be resuming it, they can resume it from their tablet.'),
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
    routeMeta.forEach((String fieldName, ModelField mf) {
      if (mf.type == FieldDataType.select) {
        theseFields.add(
          DropdownButtonFormField<String>(
            validator: (String value) {
              if (value == null && !mf.optional) {
                return 'Please enter a $fieldName.';
              }
              return null;
            },
            value: routeFieldsForDropdown[fieldName],
            hint: Text(fieldName),
            icon: Icon(Icons.arrow_drop_down),
            onChanged: (String newValue) {
              setState(() {
                routeFieldsForDropdown[fieldName] = newValue;
              });
            },
            items: groupsMeta[mf.groupId].members.map((String member) =>
              DropdownMenuItem<String>(
                value: member,
                child: Text(member)
              )
            ).toList(),
          )
        );
      } else {
        TextInputType thisKeyboardType = routeMeta[fieldName].type == FieldDataType.number
          ? TextInputType.number
          : TextInputType.text;
        theseFields.add(
          TextFormField(
            controller: routeFields[fieldName],
            validator: (value) {
              if (value.isEmpty && !mf.optional) {
                return 'Please enter a $fieldName.';
              }
              return null;
            },
            decoration: InputDecoration(
              hintText: mf.optional
                ? '$fieldName (optional)'
                : fieldName
            ),
            keyboardType: thisKeyboardType,
          )
        );
      }
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
            Text(
              'If you\'re resuming a partially-completed route, the stops that have already been visited will be locked.',
              style: cardTextStyle.copyWith(
                fontSize: cardTextStyle.fontSize - 4.0
              ),
              textAlign: TextAlign.center,
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
    List<String> ids = stopFieldsMeta.keys.toList();
    // get stops included by all previous saves so we know if there are stops to grey out
    List<String> allPreviousSaves = [];
    if (widget.activeRouteSavedData != null) {
      widget.activeRouteSavedData.saves.forEach((RecordSaveObject rso) {
        allPreviousSaves.addAll(rso.stops);
      });
    }
    return Column(
      children: ids.map((String stopTitle) {
        bool thisStopEnabled = !allPreviousSaves.contains(stopTitle);
        List<Widget> fieldsForUserEntry = [];
        stopFieldsMeta[stopTitle].forEach((String stopFieldTitle, StopField sf) {
          // don't include fields excluded by this stop
          if (stopMeta[stopTitle].exclude != null && stopMeta[stopTitle].exclude.contains(stopFieldTitle)) {
            return;
          }
          if (sf.type == FieldDataType.select) {
            fieldsForUserEntry.add(
              DropdownButtonFormField<String>(
                validator: (String value) {
                  if (value == null && !sf.optional) {
                    return 'Please enter a $stopFieldTitle.';
                  }
                  return null;
                },
                value: stopFieldsForDropdown[stopTitle][stopFieldTitle],
                // display already-entered data if resuming route and this is disabled
                hint: thisStopEnabled
                  ? Text(stopFieldTitle)
                  : stopFieldsForDropdown[stopTitle][stopFieldTitle] ?? Text(stopFieldTitle),
                icon: Icon(Icons.arrow_drop_down),
                onChanged: thisStopEnabled
                  ? (String newValue) {
                      setState(() {
                        stopFieldsForDropdown[stopTitle][stopFieldTitle] = newValue;
                      });
                    }
                  : null,
                items: groupsMeta[sf.groupId].members.map((String member) =>
                  DropdownMenuItem<String>(
                    value: member,
                    child: Text(member)
                  )
                ).toList(),
              )
            );
          } else {
            TextInputType thisKeyboardType = sf.type == FieldDataType.number
              ? TextInputType.number
              : TextInputType.text;
            fieldsForUserEntry.add(
              TextFormField(
                controller: stopFields[stopTitle][stopFieldTitle],
                enabled: thisStopEnabled,
                validator: (value) {
                  if (value.isEmpty && !sf.optional) {
                    return 'Please enter a $stopFieldTitle.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: sf.optional ? '$stopFieldTitle (optional)' : stopFieldTitle
                ),
                keyboardType: thisKeyboardType,
              )
            );
          }
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
                          stopMeta[stopTitle].title,
                          style: cardTextStyle.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        stopMeta[stopTitle].description != null && stopMeta[stopTitle].description.trim().length > 0
                          ? Text(
                              '${stopMeta[stopTitle].description}',
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
                    children: fieldsForUserEntry
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
                  'Save Route for Later',
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