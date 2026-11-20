import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

// =====================================================================
// CAPACIDADES del dispositivo, en versión asíncrona.
//
// Son cosas que el teléfono PUEDE o NO puede hacer. La app nunca asume:
// si no hay cámara, el botón de la foto no se dibuja; si la plataforma
// no tiene notificaciones, la campanita no aparece.
//
// Nunca un `if (Platform.isAndroid)` repartido por las pantallas: eso
// dice DÓNDE corre la app, no POR QUÉ. Acá cada pregunta tiene nombre, y
// las pantallas reciben esta clase por constructor (en los tests, una
// falsa).
//
// Ojo: el PERMISO de notificaciones no es una capacidad. La plataforma
// puede notificar y el usuario igual decir que no: eso lo maneja el
// repositorio de notificaciones.
// =====================================================================
class Capacidades {
  const Capacidades();

  /// Si se puede abrir la cámara para sacar una foto.
  Future<bool> tieneCamara() async {
    try {
      return ImagePicker().supportsImageSource(ImageSource.camera);
    } catch (_) {
      // Si el plugin no está (por ejemplo en una prueba), no hay cámara.
      return false;
    }
  }

  /// Si se puede elegir una foto que ya está en el teléfono.
  Future<bool> tieneGaleria() async {
    try {
      return ImagePicker().supportsImageSource(ImageSource.gallery);
    } catch (_) {
      return false;
    }
  }

  /// Si la plataforma sabe mostrar notificaciones: el celular y el
  /// navegador sí; la versión de escritorio de este proyecto, no.
  Future<bool> puedeNotificar() async =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// Si el sistema deja correr tareas con la app cerrada. Lo hacemos
  /// solo en Android: en iOS hay que registrar las tareas en Xcode y el
  /// sistema decide cuándo (puede ser una vez por día, o nunca).
  bool get correTareasDeFondo =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
