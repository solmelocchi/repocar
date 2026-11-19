import 'package:shared_preferences/shared_preferences.dart';

// =====================================================================
// EL CARRITO GUARDADO.
//
// El carrito vivía solo en la memoria: si el sistema cerraba la app
// (por ejemplo, durante una llamada larga), se perdía. Ahora se guarda
// cada vez que cambia.
//
// Qué se guarda: solo la LISTA DE IDS de las piezas. Es un dato chico y
// suelto, así que va en preferencias (una List<String>, que es de los
// tipos que acepta). Las piezas en sí ya están en la base: al abrir, se
// buscan por id.
// =====================================================================
abstract class CarritoGuardado {
  Future<List<String>> leer();

  Future<void> guardar(List<String> ids);
}

class CarritoEnPreferencias implements CarritoGuardado {
  CarritoEnPreferencias({SharedPreferencesAsync? preferencias})
    : _preferencias = preferencias;

  SharedPreferencesAsync? _preferencias;

  static const _clave = 'carrito_ids';

  @override
  Future<List<String>> leer() async {
    try {
      final prefs = _preferencias ??= SharedPreferencesAsync();
      return await prefs.getStringList(_clave) ?? const [];
    } catch (_) {
      return const []; // si no se puede leer, arranca vacío
    }
  }

  @override
  Future<void> guardar(List<String> ids) async {
    try {
      final prefs = _preferencias ??= SharedPreferencesAsync();
      await prefs.setStringList(_clave, ids);
    } catch (_) {}
  }
}

/// Para los tests: lo mismo, en memoria.
class CarritoEnMemoria implements CarritoGuardado {
  List<String> ids = [];

  @override
  Future<List<String>> leer() async => List.of(ids);

  @override
  Future<void> guardar(List<String> nuevos) async => ids = List.of(nuevos);
}
