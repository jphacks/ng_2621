import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

const studyStorageMode = String.fromEnvironment(
  'ZOOSTUDY_STORAGE',
  defaultValue: 'local',
);
Future<void> initializeStudyFirebase() async {
  final emulator = studyStorageMode == 'emulator';
  if (emulator && !kDebugMode) throw StateError('エミュレーターはデバッグ実行でのみ利用できます');
  const project = String.fromEnvironment('FIREBASE_PROJECT_ID');
  const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  const appId = String.fromEnvironment('FIREBASE_APP_ID');
  const sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  if (!emulator && [project, apiKey, appId, sender].any((s) => s.isEmpty)) {
    throw StateError(
      'Firebaseの接続設定がありません。config/firebase.example.jsonを参考に設定してください。',
    );
  }
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: emulator ? 'demo-api-key' : apiKey,
        appId: emulator ? '1:1234567890:android:1234567890abcdef' : appId,
        messagingSenderId: emulator ? '1234567890' : sender,
        projectId: emulator ? 'demo-zoostudy' : project,
        authDomain: emulator
            ? 'demo-zoostudy.firebaseapp.com'
            : '$project.firebaseapp.com',
      ),
    );
  }
  if (emulator) {
    final defaultHost =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1';
    const suppliedHost = String.fromEnvironment('FIREBASE_EMULATOR_HOST');
    final host = suppliedHost.isEmpty ? defaultHost : suppliedHost;
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );
    FirebaseFunctions.instanceFor(region: 'asia-northeast1')
        .useFunctionsEmulator(host, 5001);
  }
}
