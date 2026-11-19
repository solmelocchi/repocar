import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

// =====================================================================
// REPOSITORIO: el borrador de la publicación que el taller está
// escribiendo.
//
// Se guarda cuando la app DEJA DE VERSE (onHide): si entra una llamada
// y después el sistema cierra la app para liberar memoria, lo escrito
// no se pierde. onHide es el último aviso que llega en todas las
// plataformas (en la web nunca se llega a paused).
//
// Es un dato chico y suelto, uno por taller: va en preferencias.
// Se usa SharedPreferencesAsync, la de la materia, porque no tiene
// caché: con WorkManager corriendo en otro isolate, una caché quedaría
// desactualizada.
// =====================================================================
class BorradorRepository {
  BorradorRepository({SharedPreferencesAsync? preferencias})
    : _preferencias = preferencias;

  SharedPreferencesAsync? _preferencias;

  /// Se crea recién cuando se usa: así armar las dependencias no toca
  /// el almacenamiento.
  SharedPreferencesAsync get _prefs =>
      _preferencias ??= SharedPreferencesAsync();

  static String _clave(String cuit) => 'borrador_publicacion_$cuit';

  Future<void> guardar(String cuit, Map<String, dynamic> datos) =>
      _prefs.setString(_clave(cuit), jsonEncode(datos));

  Future<Map<String, dynamic>?> leer(String cuit) async {
    final texto = await _prefs.getString(_clave(cuit));
    if (texto == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(texto) as Map);
    } catch (_) {
      return null; // un borrador roto no puede trabar la pantalla
    }
  }

  Future<void> borrar(String cuit) => _prefs.remove(_clave(cuit));

  // --- El checkout: cómo recibe cada taller (forma, dirección y zona) ---

  static const _claveCheckout = 'borrador_checkout';

  Future<void> guardarCheckout(Map<String, dynamic> entregas) async {
    try {
      await _prefs.setString(_claveCheckout, jsonEncode(entregas));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> leerCheckout() async {
    try {
      final texto = await _prefs.getString(_claveCheckout);
      if (texto == null) return null;
      return Map<String, dynamic>.from(jsonDecode(texto) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> borrarCheckout() async {
    try {
      await _prefs.remove(_claveCheckout);
    } catch (_) {}
  }
}
