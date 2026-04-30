import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError('Unsupported platform');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAgpz59JuRQ88eW9v1lLRLtHn99d75AtnY',
    authDomain: 'travel-buddy-4b0a2.firebaseapp.com',
    projectId: 'travel-buddy-4b0a2',
    storageBucket: 'travel-buddy-4b0a2.firebasestorage.app',
    messagingSenderId: '756568280634',
    appId: '1:756568280634:web:42d3a074de52504411ef03',
  );

  // Android config from google-services.json
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyB-oM-WOixTODBxpXz7RgmFGB8RMVlnowc',
    projectId: 'travel-buddy-4b0a2',
    storageBucket: 'travel-buddy-4b0a2.firebasestorage.app',
    messagingSenderId: '756568280634',
    appId: '1:756568280634:android:434b11f08f7adcd011ef03',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAgpz59JuRQ88eW9v1lLRLtHn99d75AtnY',
    projectId: 'travel-buddy-4b0a2',
    storageBucket: 'travel-buddy-4b0a2.firebasestorage.app',
    messagingSenderId: '756568280634',
    appId: '1:756568280634:web:42d3a074de52504411ef03',
  );
}
