import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';

// =====================================================================
// LA CONFIGURACIÓN DE FIREBASE (proyecto repocar-8cad3).
//
// Son los datos que da la consola de Firebase al registrar cada app:
// la de Android (sale de android/app/google-services.json) y la web.
// No son contraseñas: identifican al proyecto y van adentro de la app.
// Lo que protege los datos son las reglas de Firestore.
//
// En la versión de escritorio no hay Firebase: tira error, y
// conectar_servidor.dart sigue solo con la base del teléfono.
// =====================================================================
class DefaultFirebaseOptions {
  const DefaultFirebaseOptions._();

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    if (defaultTargetPlatform == TargetPlatform.android) return android;
    throw UnsupportedError(
      'Firebase no está configurado para esta plataforma.',
    );
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDDR2yXMNSjv4yFT6nfhEbRPtr4P5I9StE',
    appId: '1:2598896431:android:91a401a8751b6fc99357da',
    messagingSenderId: '2598896431',
    projectId: 'repocar-8cad3',
    storageBucket: 'repocar-8cad3.firebasestorage.app',
  );

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDoqyvvJIgnDVsWhn3oBAG3M3rT5woixeo',
    appId: '1:2598896431:web:b83fd433801bc4039357da',
    messagingSenderId: '2598896431',
    projectId: 'repocar-8cad3',
    authDomain: 'repocar-8cad3.firebaseapp.com',
    storageBucket: 'repocar-8cad3.firebasestorage.app',
  );
}
