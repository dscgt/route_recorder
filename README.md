# route_recorder

Buddy app for recycling department crewmembers working recycling routes.

This is part of a suite of apps made for Georgia Tech's [OSWM&R](http://www.recycle.gatech.edu/), which also includes:
* [recycling-checkin](https://github.com/dscgt/recycling_checkin): Daily check-out/check-in for recycling department crewmembers needing GT property
* [recycling-website](https://github.com/dscgt/recycling_website): Management and data viewing portal for recycling department administrators

## Running this code

Currently, for development, this code can be run in Android Studio.

1. If you haven't already, [install Flutter](https://flutter.dev/docs/get-started/install) and [Android Studio](https://developer.android.com/studio)
1. If you haven't already, [install the Flutter and Dart plugins for Android Studio](https://flutter.dev/docs/get-started/editor#install-the-flutter-and-dart-plugins)
1. Fork this branch and clone your fork to your local machine
1. Open the project in Android Studio, and install dependencies by clicking "Get dependencies" in the alert that pops up.
1. Set up a Firebase project with Cloud Firestore, and start an Android app. Copy the provided `google-services.json` to the project's `android/app` directory.
    1. For further guidance, see [here](https://firebase.google.com/docs/flutter/setup?platform=android).
1. Run the app on a physical device or an emulator; see [here](https://developer.android.com/training/basics/firstapp/running-app) for more details.

The app isn't very interesting without route options, which require route models to be added to the database. See `models/model.json` for these models' structure, and [here](https://github.com/dscgt/route_recorder/blob/master/models/README.md) for more info.

## About
Made by the [Developer Student Club at Georgia Tech](https://dscgt.club/). 
