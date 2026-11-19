import 'package:firebase_auth/firebase_auth.dart';

// =====================================================================
// SERVICIO: quién es el usuario, comprobado por el SERVIDOR.
//
// Con Firebase Authentication la contraseña nunca se guarda en la app
// ni en la base: la valida Firebase y devuelve un "token" que dice
// quién sos. Las reglas de Firestore miran ese token para decidir qué
// puede leer y escribir cada uno.
//
// Firebase pide un mail para cada cuenta. Los compradores ya entran con
// su mail; los talleres entran con el CUIT, así que se les arma uno a
// partir del CUIT (30712345671@taller.repocar.app). Las reglas usan ese
// mail para saber de qué taller es cada publicación.
// =====================================================================

/// Lo que puede salir mal al entrar o registrarse, ya traducido.
class ErrorDeAcceso implements Exception {
  const ErrorDeAcceso(this.tipo);

  final TipoDeError tipo;

  /// El texto para mostrar en pantalla.
  String get mensaje => switch (tipo) {
    TipoDeError.datosIncorrectos => 'La contraseña no coincide.',
    TipoDeError.yaExiste => 'Ya hay una cuenta con esos datos.',
    TipoDeError.claveCorta =>
      'La contraseña tiene que tener 6 caracteres o más.',
    TipoDeError.sinRed => 'No hay conexión. Probá de nuevo en un rato.',
    TipoDeError.sinServidor => 'El servidor no está disponible.',
  };
}

enum TipoDeError { datosIncorrectos, yaExiste, claveCorta, sinRed, sinServidor }

abstract class AutenticacionService {
  /// Si hay servidor de cuentas. Sin Firebase (escritorio, tests), la app
  /// valida con la huella de la clave guardada en el teléfono.
  bool get disponible;

  /// Si hay alguien con la sesión abierta en el servidor.
  bool get haySesion;

  Future<void> entrar(String mail, String clave);

  Future<void> crearCuenta(String mail, String clave);

  Future<void> salir();
}

/// El mail con el que un taller entra a Firebase, armado con su CUIT.
String mailDeTaller(String cuit) =>
    '${cuit.replaceAll(RegExp(r'[^0-9]'), '')}@taller.repocar.app';

/// La de verdad: Firebase Authentication con mail y contraseña.
class AutenticacionFirebase implements AutenticacionService {
  AutenticacionFirebase({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  bool get disponible => true;

  @override
  bool get haySesion => _auth.currentUser != null;

  @override
  Future<void> entrar(String mail, String clave) => _traducir(
    () => _auth.signInWithEmailAndPassword(email: mail, password: clave),
  );

  @override
  Future<void> crearCuenta(String mail, String clave) => _traducir(
    () => _auth.createUserWithEmailAndPassword(email: mail, password: clave),
  );

  @override
  Future<void> salir() => _auth.signOut();

  /// Los errores de Firebase vienen con códigos en inglés: acá se pasan
  /// a los nuestros, así las capas de arriba no conocen a Firebase.
  Future<void> _traducir(Future<Object?> Function() pedido) async {
    try {
      await pedido();
    } on FirebaseAuthException catch (error) {
      throw ErrorDeAcceso(switch (error.code) {
        'invalid-credential' ||
        'wrong-password' ||
        'user-not-found' ||
        'invalid-email' => TipoDeError.datosIncorrectos,
        'email-already-in-use' => TipoDeError.yaExiste,
        'weak-password' => TipoDeError.claveCorta,
        'network-request-failed' => TipoDeError.sinRed,
        _ => TipoDeError.sinServidor,
      });
    }
  }
}

/// Sin servidor de cuentas (la versión de escritorio y los tests).
class SinAutenticacion implements AutenticacionService {
  const SinAutenticacion();

  @override
  bool get disponible => false;

  @override
  bool get haySesion => false;

  @override
  Future<void> entrar(String mail, String clave) async =>
      throw const ErrorDeAcceso(TipoDeError.sinServidor);

  @override
  Future<void> crearCuenta(String mail, String clave) async =>
      throw const ErrorDeAcceso(TipoDeError.sinServidor);

  @override
  Future<void> salir() async {}
}
