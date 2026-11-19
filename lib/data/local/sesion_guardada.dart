import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// =====================================================================
// LA SESIÓN GUARDADA: quién tiene la sesión abierta en este teléfono,
// para no pedirle que entre cada vez que abre la app.
//
// Va en ALMACENAMIENTO SEGURO (flutter_secure_storage), no en
// preferencias. Es la primera pregunta de la regla de la materia:
// ¿es un secreto? Saber "quién está adentro" alcanza para entrar como
// esa persona, así que sí lo es. En Android se guarda cifrado con el
// Keystore del sistema; en preferencias quedaría en texto plano.
//
// La contraseña NO se guarda nunca: solo el rol y la cuenta.
// =====================================================================
typedef Sesion = ({String rol, String cuenta});

abstract class SesionGuardada {
  Future<Sesion?> leer();

  Future<void> guardar(String rol, String cuenta);

  Future<void> borrar();
}

class SesionEnAlmacenSeguro implements SesionGuardada {
  SesionEnAlmacenSeguro({FlutterSecureStorage? almacen})
    : _almacen = almacen ?? const FlutterSecureStorage();

  final FlutterSecureStorage _almacen;

  static const _claveRol = 'sesion_rol';
  static const _claveCuenta = 'sesion_cuenta';

  @override
  Future<Sesion?> leer() async {
    try {
      final rol = await _almacen.read(key: _claveRol);
      final cuenta = await _almacen.read(key: _claveCuenta);
      if (rol == null || cuenta == null) return null;
      return (rol: rol, cuenta: cuenta);
    } catch (_) {
      return null; // si el almacén no anda, se pide entrar y listo
    }
  }

  @override
  Future<void> guardar(String rol, String cuenta) async {
    try {
      await _almacen.write(key: _claveRol, value: rol);
      await _almacen.write(key: _claveCuenta, value: cuenta);
    } catch (_) {}
  }

  @override
  Future<void> borrar() async {
    try {
      await _almacen.delete(key: _claveRol);
      await _almacen.delete(key: _claveCuenta);
    } catch (_) {}
  }
}

/// Para los tests: la misma idea, en memoria.
class SesionEnMemoria implements SesionGuardada {
  Sesion? _sesion;

  @override
  Future<Sesion?> leer() async => _sesion;

  @override
  Future<void> guardar(String rol, String cuenta) async =>
      _sesion = (rol: rol, cuenta: cuenta);

  @override
  Future<void> borrar() async => _sesion = null;
}
