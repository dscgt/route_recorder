# Route Recorder

Buddy app for recycling department crewmembers working recycling routes.

This is part of a suite of apps made for Georgia Tech's [OSWM&R](http://www.recycle.gatech.edu/), which also includes:
* [recycling-checkin](https://github.com/dscgt/recycling_checkin): Daily check-out/check-in for recycling department crewmembers needing GT property
* [recycling-website](https://github.com/dscgt/recycling_website): Management and data viewing portal for recycling department administrators

## For Developers

### Prerequisites

* [Flutter](https://flutter.dev/docs/get-started/install) install
   * also be sure to [set up your editor](https://flutter.dev/docs/get-started/editor?tab=androidstudio)
   * After Flutter is installed, Flutter web support must be set up
      * make sure you have a recent Chrome or Chromium-based web browser installed
      * run:
         * `flutter channel beta`
         * `flutter upgrade`
         * `flutter config --enable-web`
      * More information [here](https://flutter.dev/docs/get-started/web), though this documentation is not exact for our situation.
* the [Firebase CLI](https://firebase.google.com/docs/cli)
* access to our Firebase console
* read/write access to this Github repo
* read/write access to our [private Github repo](https://github.gatech.edu/dscgt/recycling_checkin_dist)
* credentials (see below)

### Getting your credentials

1. Go to our [Firebase console settings](https://console.firebase.google.com/u/0/project/gt-recycling/settings/general/)
1. Retrieve the code for the Firebase config object (Your Apps -> Web apps -> recorder-web -> Firebase SDK Snippet -> Config)
1. Copy the file `web/index-template.html` to a new file, `web/index.html`
   1. Since this file contains your private config, it's been placed into `.gitignore` -- do not attempt to un-ignore it
1. Replace the `firebaseConfig` variable in `web/index.html` with the Firebase config object

This process initializes Flutterfire, the official Firebase services for Flutter, with our credentials.

It is [not necessary to secure Firebase API keys](https://firebase.google.com/docs/projects/api-keys) like this, but we do so as an extra layer of security.

### Running this code

This project uses Firebase Firestore.

To run locally for development:

1. In a CLI, install dependencies with `flutter pub get` (this is also easily done in the Android Studio UI)
1. Set your output device to be a web browser; this option should have been made available by the Flutter web setup
1. In the root directory of this project, run firestore emulators with `firebase emulators:start --import=./test/sample-data`
   1. Only Firestore is emulated. The app will use the emulated Firestore instance instead of the production instance.
   1. Firestore Rules are not emulated, so be mindful when testing new changes.
   1. Some sample model data will be initialized for your testing convenience. You can also add more models in the emulator UI.
1. In another CLI window or tab, run the app with `flutter run --dart-define=ENVIRONMENT=development`

### Deploying this code

The current deployment method builds this Flutter project as a webapp and deploys it to a private Github Pages instance.

1. Make sure our [private Github repo](https://github.gatech.edu/dscgt/route_recorder_dist) is cloned to your machine
1. In your clone of the private repo, delete all non-hidden files (don't delete the `.git` directory, of course)
1. In a CLI, navigate to this app and build for the web with `flutter build web`
1. Copy the contents of the `build/web` directory to your clone of the private repo
1. Push the changes of the private repo

More information:

* https://flutter.dev/docs/get-started/web#create-and-run
* https://flutter.dev/docs/deployment/web

## About

Made by the [Developer Student Club at Georgia Tech](https://dscgt.club/).
