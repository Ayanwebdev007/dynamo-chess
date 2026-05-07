// File generated manually to support Web launch
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBr872cFnJt2NV4vslVr6MzBr9xaoxGph4',
    appId: '1:113235320266:web:1932864e9b508010648333',
    messagingSenderId: '113235320266',
    projectId: 'dynamo-chess-6ad12',
    authDomain: 'dynamo-chess-6ad12.firebaseapp.com',
    storageBucket: 'dynamo-chess-6ad12.firebasestorage.app',
    databaseURL: 'https://dynamo-chess-6ad12-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDzYCRfug8djoR9rB9oo2gTT1cNz90hOP0',
    appId: '1:113235320266:android:d95e93bb4681b38d648333',
    messagingSenderId: '113235320266',
    projectId: 'dynamo-chess-6ad12',
    storageBucket: 'dynamo-chess-6ad12.firebasestorage.app',
     databaseURL: 'https://dynamo-chess-6ad12-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
  
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDzYCRfug8djoR9rB9oo2gTT1cNz90hOP0',
    appId: '1:113235320266:ios:dummy',
    messagingSenderId: '113235320266',
    projectId: 'dynamo-chess-6ad12',
    storageBucket: 'dynamo-chess-6ad12.firebasestorage.app',
     databaseURL: 'https://dynamo-chess-6ad12-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
}
