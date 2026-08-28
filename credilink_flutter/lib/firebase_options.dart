// Firebase options for credilink-ad684 (shared with v1 Ionic app).
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

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
      case TargetPlatform.macOS:
        return macos;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAclLorWJDD06XmFbZZ2EhsFcncM-XeKZU',
    appId: '1:78811039807:web:3a534bc550634e33c4508a',
    messagingSenderId: '78811039807',
    projectId: 'credilink-ad684',
    authDomain: 'credilink-ad684.firebaseapp.com',
    storageBucket: 'credilink-ad684.firebasestorage.app',
    measurementId: 'G-24NSSJ6KR1',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAclLorWJDD06XmFbZZ2EhsFcncM-XeKZU',
    appId: '1:78811039807:android:3a534bc550634e33c4508a',
    messagingSenderId: '78811039807',
    projectId: 'credilink-ad684',
    storageBucket: 'credilink-ad684.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAclLorWJDD06XmFbZZ2EhsFcncM-XeKZU',
    appId: '1:78811039807:ios:3a534bc550634e33c4508a',
    messagingSenderId: '78811039807',
    projectId: 'credilink-ad684',
    storageBucket: 'credilink-ad684.firebasestorage.app',
    iosBundleId: 'com.credilink.credilinkFlutter',
  );

  static const FirebaseOptions macos = ios;
}
