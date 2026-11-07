import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Public client identifiers. Server policies enforce verified ownership.
class FirebaseConfig {
  static FirebaseOptions get options => FirebaseOptions(
    apiKey: 'AIzaSyAXnH3NHviyb6vCPKZTvXs_cui0MxPXuz8',
    appId: kIsWeb
        ? '1:364651729957:web:b359238715c399dc1edbcc'
        : '1:364651729957:android:a0b9d6245921bade1edbcc',
    messagingSenderId: '364651729957',
    projectId: 'autopulseai-1fca7',
    authDomain: 'autopulseai-1fca7.firebaseapp.com',
  );
}
