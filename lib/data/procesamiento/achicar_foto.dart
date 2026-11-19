import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

// =====================================================================
// ISOLATE: achicar la foto del repuesto.
//
// Una foto del Pixel tiene unos 12 megapíxeles. Decodificarla, achicarla
// y volver a comprimirla en Dart es CALCULAR (no esperar): ocupa el hilo
// un buen rato, y si se hace en el hilo de la pantalla, la app se traba
// (Flutter necesita dibujar un cuadro cada ~16 ms).
//
// Por eso se hace en OTRO ISOLATE con compute. Cada isolate tiene su
// propia memoria: se le mandan SOLO los bytes (no el view model ni la
// pantalla) y devuelve los bytes de la foto chica.
//
// compute y no Isolate.run: compute compila también en la web (donde no
// hay isolates y corre en el hilo principal), Isolate.run no existe ahí.
// =====================================================================

/// El ancho máximo con el que se guarda una foto.
const anchoMaximo = 1000;

/// Lanza el trabajo en otro isolate y espera el resultado.
Future<Uint8List> achicarFotoAparte(Uint8List original) =>
    compute(achicarFoto, original);

/// El trabajo en sí. Tiene que ser una función de NIVEL SUPERIOR (o
/// estática): compute la manda a otro isolate, y no puede arrastrar
/// nada de afuera.
Uint8List achicarFoto(Uint8List original) {
  final imagen = img.decodeImage(original);
  if (imagen == null) return original; // no es una imagen: queda igual

  // La orientación que guardó la cámara se aplica antes de achicar.
  final derecha = img.bakeOrientation(imagen);
  final chica = derecha.width > anchoMaximo
      ? img.copyResize(derecha, width: anchoMaximo)
      : derecha;
  return img.encodeJpg(chica, quality: 75);
}
