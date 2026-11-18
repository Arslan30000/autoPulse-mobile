import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public client identifiers. Server policies enforce verified ownership.
class FirebaseConfig {
  static FirebaseOptions? get options {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      const apiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
      const appId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
      const bundleId = String.fromEnvironment(
        'FIREBASE_IOS_BUNDLE_ID',
        defaultValue: 'com.example.autopulse_ai',
      );
      if (apiKey.isEmpty || appId.isEmpty) return null;
      return const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        iosBundleId: bundleId,
        messagingSenderId: '364651729957',
        projectId: 'autopulseai-1fca7',
      );
    }
    return FirebaseOptions(
      apiKey: 'AIzaSyAXnH3NHviyb6vCPKZTvXs_cui0MxPXuz8',
      appId: kIsWeb
          ? '1:364651729957:web:b359238715c399dc1edbcc'
          : '1:364651729957:android:a0b9d6245921bade1edbcc',
      messagingSenderId: '364651729957',
      projectId: 'autopulseai-1fca7',
      authDomain: 'autopulseai-1fca7.firebaseapp.com',
    );
  }
}
