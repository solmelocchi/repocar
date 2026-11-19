import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import '../local/almacen_local.dart';
import '../services/autenticacion_service.dart';
import '../services/push_service.dart';
import 'almacen_con_servidor.dart';
import 'base_remota.dart';
import 'tokens_push.dart';

/// Lo que da el servidor: la base, el inicio de sesión y las push (con
/// dónde se guarda el token de cada teléfono).
typedef Servidor = ({
  AlmacenLocal almacen,
  AutenticacionService autenticacion,
  PushService push,
  TokensPush tokens,
});

/// Arma la base que va a usar la app (la del teléfono MÁS el servidor)
/// y el inicio de sesión con Firebase.
///
/// Si Firebase no arranca (no está configurado, o es la versión de
/// escritorio), devuelve la base del teléfono sola y sin servidor de
/// cuentas: la app funciona igual, sin compartir los datos.
///
/// La usan main() y también la tarea de segundo plano, que corre en
/// otro isolate y tiene que conectarse por su cuenta.
Future<Servidor> conectarServidor() async {
  final local = crearAlmacenLocal();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    // Firestore guarda una copia en el teléfono: con la app sin señal
    // se sigue leyendo lo último que bajó, y lo que se escribe queda en
    // cola hasta que vuelva internet.
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
    );
    // Firebase recuerda la sesión de la otra vez, pero tarda un momento
    // en recuperarla: se espera, así las primeras lecturas ya van con
    // permiso (las reglas piden estar adentro).
    await FirebaseAuth.instance.authStateChanges().first.timeout(
      const Duration(seconds: 5),
    );

    // Push solo en Android: en la web FCM pide otra configuración (un
    // service worker y una clave más), y en la compu no existe.
    final esAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return (
      almacen: AlmacenConServidor(local: local, remota: BaseFirestore()),
      autenticacion: AutenticacionFirebase(),
      push: esAndroid ? PushFcm() : const SinPush(),
      tokens: esAndroid ? TokensEnFirestore() : const SinTokens(),
    );
  } catch (_) {
    return (
      almacen: local,
      autenticacion: const SinAutenticacion(),
      push: const SinPush(),
      tokens: const SinTokens(),
    );
  }
}
