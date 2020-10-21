import 'package:flutter/material.dart';

class Loading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      padding: EdgeInsets.only(left: 75.0, right: 75.0),
      child: Text('Loading...',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24.0
        ),
      )
    );
  }
}
