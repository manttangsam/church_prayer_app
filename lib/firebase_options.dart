import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    return web;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAs8O99-xxxx-xxxx', // 형님의 실제 키는 보안상 가려져 보일 수 있으니 이전에 쓰던 코드를 참고하세요
    appId: '1:1052643534567:web:xxxx',
    messagingSenderId: '1052643534567',
    projectId: 'church-prayer-app',
    databaseURL: 'https://church-prayer-app-default-rtdb.firebaseio.com',
    storageBucket: 'church-prayer-app.appspot.com',
  );
}