import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBLynU_hVQxYZUXD9dYTVYaf8_-c9-8a9Y', 
    appId: '1:19817451561:web:166687df2ec2a373648c38',
    messagingSenderId: '19817451561',
    projectId: 'church-prayer-app-57370',
    databaseURL: 'https://church-prayer-app-57370-default-rtdb.asia-southeast1.firebasedatabase.app', 
    storageBucket: 'church-prayer-app-57370.firebasestorage.app',
  );
}