// Généré manuellement à partir de GoogleService-Info.plist / google-services.json
// (flutterfire configure n'a pas pu terminer sur cette machine — le gem Ruby
// xcodeproj ne compile pas ici). Mêmes valeurs qu'une génération normale.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions ne supporte pas cette plateforme : $defaultTargetPlatform',
        );
    }
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyBoH1sbtWxkd4VU-CRDHaODAV7PNC6a_kY',
    appId: '1:719199187830:web:a13918efe551fb1a244057',
    messagingSenderId: '719199187830',
    projectId: 'chevreuilscan-app',
    authDomain: 'chevreuilscan-app.firebaseapp.com',
    storageBucket: 'chevreuilscan-app.firebasestorage.app',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyBB3LvfjwTfUvvG0fbe0PInkf0TEy6cXJo',
    appId: '1:719199187830:android:c139962c82cfe704244057',
    messagingSenderId: '719199187830',
    projectId: 'chevreuilscan-app',
    storageBucket: 'chevreuilscan-app.firebasestorage.app',
  );

  static const ios = FirebaseOptions(
    apiKey: 'AIzaSyBXwb6pASSsOh8vZBFYc_CFbLpPGmP4ztQ',
    appId: '1:719199187830:ios:967929ce3fe035d8244057',
    messagingSenderId: '719199187830',
    projectId: 'chevreuilscan-app',
    storageBucket: 'chevreuilscan-app.firebasestorage.app',
    iosBundleId: 'com.bastienbouchard.chevreuilscan',
  );
}
