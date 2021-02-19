import 'package:flutter/material.dart';
import 'package:route_recorder/api.dart';
import 'package:route_recorder/classes.dart';
import 'package:route_recorder/views/active_route_widgets/active_route_stop.dart';
import 'package:route_recorder/views/active_route_widgets/active_route_title_card.dart';
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
  /// A map of a stop's title -> another map, keyed by a stop's field's title ->
  /// its StopField. Useful for faster metadata lookups, and also serves as
  /// an ordered master list of stop fields.
  Map<String, Map<String, StopField>> stopFieldsMeta;
  /// A map of a stop's title -> another map, keyed by a stop's field's title ->
  /// text controller for user's response.
  Map<String, Map<String, TextEditingController>> stopFields;
  /// A map of a stop's title -> another map, keyed by a stop's field's title ->
  /// dropdown values. For user responses that require a dropdown.
  Map<String, Map<String, String>> stopFieldsForDropdown;

  /// A record of groupId -> Group. For fast lookups about groups.
  Map<String, Group> groupsMeta = {};

  /// The time when this route was started by the user.
  DateTime startTime;

  @override
  void initState() {
    // If there is no active route, we have arrived here on error, so return to
    // selection screen.
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

  /// Sets the value of ONE of the route-level dropdown fields i.e. fields
  /// in the title card which use dropdowns.
  setRouteFieldForDropdown(String key, String value) {
    setState(() {
      routeFieldsForDropdown[key] = value;
    });
  }

  /// Sets the value of ONE of the stop-level dropdown fields i.e. fields
  /// in a stop which use dropdowns.
  setStopFieldForDropdown(String stopTitle, String stopFieldTitle, String value) {
    setState(() {
      stopFieldsForDropdown[stopTitle][stopFieldTitle] = value;
    });
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
    /// This will initialize a TextEditingController for every non-dropdown
    /// field, including stop fields.
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

  /// Returns a list of the names of nonoptional fields which are currently
  /// empty. Stop fields will be prefixed with the stop title and hyphen ex.
  /// 'title-fieldname'.
  List<String> getInvalidFields() {
    List<String> toReturn = [];
    // check route-level fields (fields which appear in the top box) for empty
    // or unselected fields
    toReturn.addAll(
      routeMeta.values
        .where((ModelField mf) => !mf.optional)
        .where((ModelField mf) => (mf.type != FieldDataType.select && (routeFields[mf.title].text.isEmpty || routeFields[mf.title].text.trim().isEmpty))
          || (mf.type == FieldDataType.select && !routeFieldsForDropdown.containsKey(mf.title)))
        .map((ModelField mf) => mf.title)
    );
    // check stop-level fields (fields which appear in stops) for empty
    // or unselected fields
    stopFieldsMeta.forEach((String stopTitle, Map<String, StopField> fields) {
      toReturn.addAll(
        fields.values
          .where((StopField sf) => !sf.optional)
          .where((StopField sf) => !stopMeta[stopTitle].exclude.contains(sf.title))
          .where((StopField sf) => (sf.type != FieldDataType.select && (stopFields[stopTitle][sf.title].text.isEmpty || stopFields[stopTitle][sf.title].text.trim().isEmpty))
            || (sf.type == FieldDataType.select && !stopFieldsForDropdown[stopTitle].containsKey(sf.title)))
          .map((StopField sf) => '$stopTitle--${sf.title}')
      );
    });
    return toReturn;
  }

  /// Takes inputs of state and converts to a Record.
  /// If [forSaving] is true, null and empty fields will be excluded,
  /// 'saves' property will be handled differently, and there won't be an
  /// end time. This is meant for routes to be saved for later.
  Record formatInputsForDb(bool forSaving) {
    // Create a submission object from info entered by user.
    // start by handling top-level fields
    Map<String, String> propertiesToAdd = {};
    routeFields.forEach((String fieldName, TextEditingController controller) {
      if (forSaving) {
        if (controller.text.length > 0) {
          propertiesToAdd[fieldName] = controller.text;
        }
      } else {
        propertiesToAdd[fieldName] = controller.text;
      }
    });
    routeFieldsForDropdown.forEach((String fieldName, String value) {
      if (forSaving) {
        if (value != null) {
          propertiesToAdd[fieldName] = value;
        }
      } else {
        propertiesToAdd[fieldName] = value;
      }
    });
    // Then, we have to handle stop fields.
    // First handle non-dropdown stop fields...
    Map<String, Map<String, String>> stopsToAdd = stopFields.map((String stopTitle, Map<String, TextEditingController> stopDetails) {
      // change texteditingcontrollers into consumable maps, then filter maps
      // before adding to submission object
      Map<String, String> propertiesToAdd = stopDetails.map((String fieldName, TextEditingController controller) =>
        MapEntry(fieldName, controller.text)
      );
      // remove fields which are empty if this record is for saving
      // otherwise, remove excluded fields for submission
      if (forSaving) {
        propertiesToAdd.removeWhere((String fieldName, String fieldVal) => fieldVal.length == 0);
      } else {
        List<String> exclude = stopMeta[stopTitle].exclude ?? [];
        propertiesToAdd.removeWhere((String fieldName, String fieldVal) => exclude.contains(fieldName));
      }
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
      if (forSaving) {
        propertiesToAdd.removeWhere((String fieldName, String fieldValue) => fieldValue == null);
      } else {
        propertiesToAdd.removeWhere((String fieldName, String fieldValue) => exclude.contains(fieldName));
      }
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

    // get previous saves if existing
    List<RecordSaveObject> newSaves = [];
    if (widget.activeRouteSavedData != null) {
      newSaves.addAll(widget.activeRouteSavedData.saves);
    }
    DateTime sessionEnd = DateTime.now();
    // start building updated 'saves',
    List<String> stopTitlesToSave;
    if (forSaving) {
      // ONLY include a stop in 'saves' if ALL of its nonoptional, nonexcluded fields have been
      // filled out. Remember, once a stop is in 'saves' it is greyed out in
      // further resumes!
      stopTitlesToSave = [];
      stopsToAddAsList.forEach((RecordStop rs) {
        bool shouldAddThisStopToSave = true;
        stopFieldsMeta[rs.title].forEach((String fieldTitle, StopField sf) {
          // translation: if this stop field is not option, AND it's not excluded from this stop, AND this stop field has no value
          if (!sf.optional && !stopMeta[rs.title].exclude.contains(fieldTitle) && !rs.properties.containsKey(fieldTitle)) {
            shouldAddThisStopToSave = false;
          }
        });
        if (shouldAddThisStopToSave) {
          stopTitlesToSave.add(rs.title);
        }
      });
    } else {
      // since we are submitting this route, these are just all titles that weren't covered
      // by previous saves
      stopTitlesToSave = stopsToAddAsList.map((RecordStop rs) =>
      rs.properties.length > 0
          ? rs.title
          : null
      ).toList();
      stopTitlesToSave.removeWhere((String s) => s == null);
    }
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
    newSaves.add(RecordSaveObject(
        stops: stopTitlesToSave,
        saveTime: sessionEnd
    ));

    // don't include end time if this isn't a submission
    DateTime thisEndDate = forSaving
      ? null
      : sessionEnd;

    Record thisSubmission = Record(
      modelId: widget.activeRoute.id,
      modelTitle: widget.activeRoute.title,
      startTime: startTime,
      endTime: thisEndDate,
      properties: propertiesToAdd,
      stops: stopsToAddAsList,
      saves: newSaves
    );

    return thisSubmission;
  }

  void saveRouteForLater() async {
    setState(() {
      loadingAfterButtonPress = true;
      isLoading = true;
    });

    Record thisSubmission = formatInputsForDb(true);

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
    Record thisSubmission = formatInputsForDb(false);
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

  void _handleCancelRoute() {
    showDialog<ConfirmAction>(
      context: context,
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

  void _handleSaveRouteForLater() {
    showDialog<ConfirmAction>(
      context: context,
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

  void _handleFinishRoute() async {
    /// Validation check.
    List<String> invalidFields = getInvalidFields();
    if (invalidFields.length != 0) {
      showDialog<ConfirmAction>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('The following fields still need to be filled out: ${invalidFields.join(", ")}'),
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

    showDialog<ConfirmAction>(
      context: context,
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

  Widget _buildSubmissionArea() {
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
                  : () => _handleCancelRoute()
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
                  : () => _handleSaveRouteForLater()
              ),
            ),
            RaisedButton(
              child: Text(
                'Finish',
                style: cardTextStyle,
              ),
              onPressed: loadingAfterButtonPress
                ? null
                : () => _handleFinishRoute(),
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

    // get stops included by all previous saves so we know if there are stops to grey out
    List<String> allPreviousSaves = [];
    if (widget.activeRouteSavedData != null) {
      widget.activeRouteSavedData.saves.forEach((RecordSaveObject rso) {
        allPreviousSaves.addAll(rso.stops);
      });
    }
    // build list of stops
    List<String> ids = stopFieldsMeta.keys.toList();

    int len = 2 + stopMeta.length;
    return Container(
      padding: const EdgeInsets.only(left: 10.0, right: 10.0, top: 30.0, bottom: 10.0),
      child: Form(
        key: _formKey,
        child: ListView.builder(
          itemCount: len,
          itemBuilder: (context, index) {
            // first element is always the title card
            if (index == 0) {
              return ActiveRouteTitleCard(
                cardTextStyle: cardTextStyle,
                title: widget.activeRoute.title,
                routeMeta: routeMeta,
                routeFields: routeFields,
                routeFieldsForDropdown: routeFieldsForDropdown,
                groupsMeta: groupsMeta,
                onDropdownRouteFieldChanged: setRouteFieldForDropdown
              );
            }
            // last element is always the submission area
            if (index == len - 1) {
              return _buildSubmissionArea();
            }
            int stopIndex = index - 1;
            String thisStopTitle = ids[stopIndex];
            return ActiveRouteStop(
              cardTextStyle: cardTextStyle,
              title: thisStopTitle,
              stopMeta: stopMeta,
              stopFieldsMeta: stopFieldsMeta,
              enabled: !allPreviousSaves.contains(thisStopTitle),
              stopFieldsForDropdown: stopFieldsForDropdown,
              stopFields: stopFields,
              groupsMeta: groupsMeta,
              onDropdownStopFieldChanged: setStopFieldForDropdown
            );
          }
        )
      )
    );
  }
}