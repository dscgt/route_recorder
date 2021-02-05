import 'package:flutter/material.dart';
import 'package:route_recorder/classes.dart';

/// A single stop displayed in the list of stops during an active route.
class ActiveRouteStop extends StatelessWidget {
  ActiveRouteStop({
    Key key,

    @required this.cardTextStyle,
    @required this.title,
    @required this.stopMeta,
    @required this.stopFieldsMeta,
    @required this.enabled,
    @required this.stopFieldsForDropdown,
    @required this.stopFields,
    @required this.groupsMeta,
    @required this.onDropdownStopFieldChanged,
  }) : super(key: key);

  final TextStyle cardTextStyle;
  final String title;
  final Map<String, Stop> stopMeta;
  final Map<String, Map<String, StopField>> stopFieldsMeta;
  final bool enabled;
  final Map<String, Map<String, String>> stopFieldsForDropdown;
  final Map<String, Map<String, TextEditingController>> stopFields;
  final Map<String, Group> groupsMeta;
  final Function onDropdownStopFieldChanged;

  Widget build(BuildContext context) {
    List<Widget> fieldsForUserEntry = [];
    stopFieldsMeta[title].forEach((String stopFieldTitle, StopField sf) {
      // don't include fields excluded by this stop
      if (stopMeta[title].exclude != null && stopMeta[title].exclude.contains(stopFieldTitle)) {
        return;
      }
      if (sf.type == FieldDataType.select) {
        fieldsForUserEntry.add(
            DropdownButtonFormField<String>(
              value: stopFieldsForDropdown[title][stopFieldTitle],
              // display already-entered data if resuming route and this is disabled
              hint: enabled
                  ? Text(stopFieldTitle)
                  : stopFieldsForDropdown[title][stopFieldTitle] ?? Text(stopFieldTitle),
              icon: Icon(Icons.arrow_drop_down),
              onChanged: enabled
                  ? (String newValue) {
                onDropdownStopFieldChanged(title, stopFieldTitle, newValue);
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
              controller: stopFields[title][stopFieldTitle],
              enabled: enabled,
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
                      stopMeta[title].title,
                      style: cardTextStyle.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    stopMeta[title].description != null && stopMeta[title].description.trim().length > 0
                        ? Text(
                      '${stopMeta[title].description}',
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
  }
}
