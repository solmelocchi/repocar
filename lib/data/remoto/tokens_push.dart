import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// =====================================================================
// LOS TOKENS DE PUSH, en el servidor.
//
// Para mandarle una push a alguien, el servidor tiene que saber su
// token. Por eso la app lo guarda en Firestore, en la colección
// "tokens", un documento por usuario de Firebase Authentication. Las
// reglas dejan que cada uno escriba SOLO el suyo.
// =====================================================================
abstract class TokensPush {
  Future<void> guardar({required String usuario, required String token});

  /// Al cerrar sesión: ese teléfono ya no tiene que recibir los avisos
  /// de esa cuenta.
  Future<void> borrar();
}

class TokensEnFirestore implements TokensPush {
  DocumentReference<Map<String, dynamic>>? get _documento {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance.collection('tokens').doc(uid);
  }

  @override
  Future<void> guardar({required String usuario, required String token}) async {
    await _documento?.set({
      'token': token,
      'usuario': usuario,
      'plataforma': 'android',
      'actualizado': DateTime.now().toIso8601String(),
    });
  }

  @override
  Future<void> borrar() async {
    await _documento?.delete();
  }
}

/// Sin servidor: no hay dónde guardarlo.
class SinTokens implements TokensPush {
  const SinTokens();

  @override
  Future<void> guardar({
    required String usuario,
    required String token,
  }) async {}

  @override
  Future<void> borrar() async {}
}
