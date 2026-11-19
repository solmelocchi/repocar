import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'imagen_guardada_web.dart'
    if (dart.library.io) 'imagen_guardada_archivo.dart'
    as lugar;

/// Las fotos que vienen como texto (del servidor), ya convertidas a bytes.
///
/// Antes se convertían de nuevo CADA VEZ que se dibujaba la tarjeta: eran
/// bytes nuevos, Flutter no los reconocía y volvía a decodificar la
/// imagen entera. Guardando los mismos bytes, Flutter usa la imagen que
/// ya tiene en su caché.
final _bytesDeFotos = <String, Uint8List>{};

/// Cuántas fotos se guardan como máximo (para no llenar la memoria).
const _maximoDeFotos = 60;

Uint8List _bytesDe(String referencia) {
  final guardados = _bytesDeFotos[referencia];
  if (guardados != null) return guardados;
  if (_bytesDeFotos.length >= _maximoDeFotos) {
    _bytesDeFotos.remove(_bytesDeFotos.keys.first); // la más vieja
  }
  final datos = referencia.substring(referencia.indexOf(',') + 1);
  return _bytesDeFotos[referencia] = base64Decode(datos);
}

/// Dibuja una foto a partir de su referencia, sea de donde sea:
///   · 'https://...'   → del servidor (cuando lo tengamos)
///   · 'data:...'      → la foto viaja como texto (en la web)
///   · cualquier otra  → la ruta de un archivo del teléfono
///
/// [anchoEnPantalla] es cuánto ocupa la foto. Con eso se decodifica a
/// ESE tamaño (cacheWidth) y no a los 1000 píxeles de la original: para
/// una tarjeta de 170 de ancho, es mucho menos trabajo y menos memoria.
Widget imagenGuardada(
  BuildContext context,
  String referencia, {
  BoxFit fit = BoxFit.cover,
  double? anchoEnPantalla,
}) {
  final ancho = anchoEnPantalla == null || !anchoEnPantalla.isFinite
      ? MediaQuery.sizeOf(context).width
      : anchoEnPantalla;
  final pixeles = (ancho * MediaQuery.devicePixelRatioOf(context)).round();

  if (referencia.startsWith('http')) {
    return Image.network(referencia, fit: fit, cacheWidth: pixeles);
  }
  if (referencia.startsWith('data:')) {
    return Image.memory(
      _bytesDe(referencia),
      fit: fit,
      cacheWidth: pixeles,
      gaplessPlayback: true,
    );
  }
  return lugar.imagenDeArchivo(referencia, fit, pixeles);
}
