import 'dart:typed_data';

// En el celular la foto va a un ARCHIVO (dart:io + path_provider). En la
// web no hay archivos: se guarda como texto adentro del dato. El resto
// de la app no se entera: recibe una referencia y se la da a FotoPieza.
import 'fotos_web.dart' if (dart.library.io) 'fotos_archivo.dart' as lugar;

// =====================================================================
// LAS FOTOS de los repuestos.
//
// Con la regla de la materia para persistir: una foto es GRANDE y
// BINARIA, así que no va en la base ni en preferencias, va en un
// archivo. En la base queda solo la referencia (la ruta del archivo).
//
// Cuando esté el servidor, acá se sube la foto y la referencia pasa a
// ser su dirección (https://...).
// =====================================================================
class FotosLocales {
  const FotosLocales();

  /// Guarda la foto y devuelve la referencia para ponerle a la pieza.
  Future<String> guardar(String id, Uint8List bytes) =>
      lugar.guardarFoto(id, bytes);

  /// Borra una foto que ya no usa nadie (se reemplazó por otra). Así no
  /// quedan archivos huérfanos ocupando lugar en el teléfono.
  Future<void> borrar(String referencia) async {
    if (referencia.startsWith('data:') || referencia.startsWith('http')) {
      return; // no es un archivo de este teléfono
    }
    await lugar.borrarFoto(referencia);
  }

  /// La foto como texto, para mandarla al servidor adentro de la pieza
  /// (los otros teléfonos no tienen el archivo de este). Si ya es texto
  /// o una dirección, queda igual; si no hay foto, null.
  Future<String?> comoTexto(String? referencia) async {
    if (referencia == null) return null;
    if (referencia.startsWith('data:') || referencia.startsWith('http')) {
      return referencia;
    }
    return lugar.leerComoTexto(referencia);
  }
}
