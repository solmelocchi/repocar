import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

// =====================================================================
// SERVICIO: de dónde salen las fotos (la cámara o la galería).
//
// La pantalla nunca llama a ImagePicker: si lo hiciera, no se podría
// probar (en flutter test no hay cámara ni usuario que toque botones).
// Por eso el plugin queda detrás de esta clase abstracta, como en el
// apunte de Cámara. En las pruebas se usa una fuente falsa que devuelve
// lo que le carguemos: una foto, null (canceló) o un error.
// =====================================================================

enum OrigenDeFoto { camara, galeria }

/// La foto elegida, como bytes y no como archivo: así el mismo código
/// anda en el celular, en la web y en las pruebas.
class Foto {
  const Foto(this.bytes);

  final Uint8List bytes;
}

/// Algo falló DE VERDAD (no dio permiso, no hay cámara). Cancelar no es
/// un error: eso es null.
class ErrorDeFoto implements Exception {
  const ErrorDeFoto(this.mensaje);

  final String mensaje;

  @override
  String toString() => mensaje;
}

abstract class FuenteDeFotos {
  /// La foto elegida, o null si el usuario se arrepintió (tocó atrás o
  /// cerró la cámara). Si algo falla de verdad, lanza [ErrorDeFoto].
  Future<Foto?> elegir(OrigenDeFoto origen);
}

/// La de verdad, con image_picker.
class FuenteImagePicker implements FuenteDeFotos {
  FuenteImagePicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  @override
  Future<Foto?> elegir(OrigenDeFoto origen) async {
    try {
      final archivo = await _picker.pickImage(
        source: origen == OrigenDeFoto.camara
            ? ImageSource.camera
            : ImageSource.gallery,
        // Se achica ya al elegirla: una foto de celular pesa de 3 a 8 MB.
        // Después, en otro isolate, queda de 1000 px para guardarla.
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (archivo == null) return null; // canceló: no pasa nada
      return Foto(await archivo.readAsBytes());
    } on PlatformException catch (error) {
      throw ErrorDeFoto(_mensajePara(error.code, origen));
    }
  }

  static String _mensajePara(String codigo, OrigenDeFoto origen) =>
      switch (codigo) {
        'camera_access_denied' =>
          'No diste permiso para usar la cámara. Lo podés activar en los '
              'Ajustes del teléfono.',
        'photo_access_denied' =>
          'No diste permiso para ver tus fotos. Lo podés activar en los '
              'Ajustes del teléfono.',
        'no_available_camera' => 'Este teléfono no tiene cámara disponible.',
        _ =>
          origen == OrigenDeFoto.camara
              ? 'No se pudo usar la cámara.'
              : 'No se pudo abrir la galería.',
      };
}
