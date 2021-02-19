import 'package:flutter/material.dart';
import 'package:route_recorder/classes.dart';

/// The upper portion of the active route screen, the part of the form that
/// displays gathers user entry about the route overall (but not individual
/// stops).
class ActiveRouteTitleCard extends StatelessWidget {
  ActiveRouteTitleCard({
    Key key,
    @required this.cardTextStyle,
    @required this.title,
    @required this.routeMeta,
    @required this.routeFields,
    @required this.routeFieldsForDropdown,
    @required this.groupsMeta,
    @required this.onDropdownRouteFieldChanged,
  }) : super(key: key);

  final TextStyle cardTextStyle;
  final String title;
  final Map<String, ModelField> routeMeta;
  final Map<String, TextEditingController> routeFields;
  final Map<String, String> routeFieldsForDropdown;
  final Map<String, Group> groupsMeta;
  final Function onDropdownRouteFieldChanged;

  Widget build(BuildContext context) {
    List<Widget> theseFields = [];
    routeMeta.forEach((String fieldName, ModelField mf) {
      if (mf.type == FieldDataType.select) {
        theseFields.add(
          DropdownButtonFormField<String>(
            value: routeFieldsForDropdown[fieldName],
            hint: Text(fieldName),
            icon: Icon(Icons.arrow_drop_down),
            onChanged: (String newValue) {
              onDropdownRouteFieldChanged(fieldName, newValue);
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
              title,
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
}
