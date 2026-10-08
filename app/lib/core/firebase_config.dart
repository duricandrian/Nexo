import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Firebase project settings. These values are public identifiers (they are
/// also contained in google-services.json); access is enforced by the
/// security rules. Override at build time with --dart-define.
class FirebaseConfig {
  static const apiKey = String.fromEnvironment('FB_API_KEY', defaultValue: 'demo-key');
  static const appId = String.fromEnvironment('FB_APP_ID', defaultValue: '1:000000000000:android:0000000000000000000000');
  static const senderId = String.fromEnvironment('FB_SENDER_ID', defaultValue: '000000000000');
  static const projectId = String.fromEnvironment('FB_PROJECT_ID', defaultValue: 'demo-nexo');
  static const bucket = String.fromEnvironment('FB_BUCKET', defaultValue: 'demo-nexo.appspot.com');
  static const region = String.fromEnvironment('FB_REGION', defaultValue: 'europe-west6');

  /// Host of the local Firebase emulators (e.g. 10.0.2.2 from an Android emulator).
  static const emulatorHost = String.fromEnvironment('FB_EMULATOR_HOST');

  static FirebaseFunctions get functions => FirebaseFunctions.instanceFor(region: region);

  static Future<void> init() async {
    if (Firebase.apps.isNotEmpty) return;
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: senderId,
        projectId: projectId,
        storageBucket: bucket,
      ),
    );
    if (emulatorHost.isNotEmpty) {
      await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8085);
      await FirebaseStorage.instance.useStorageEmulator(emulatorHost, 9199);
      functions.useFunctionsEmulator(emulatorHost, 5001);
    }
  }
}
