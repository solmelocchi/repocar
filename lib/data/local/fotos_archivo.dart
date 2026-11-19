import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as ruta;
import 'package:path_provider/path_provider.dart';

/// En el celular: la foto se escribe en la carpeta de documentos de la
/// app (la borra el sistema solo si se desinstala la app) y se devuelve
/// la ruta del archivo.
Future<String> guardarFoto(String id, Uint8List bytes) async {
  final documentos = await getApplicationDocumentsDirectory();
  final carpeta = Directory(ruta.join(documentos.path, 'fotos'));
  await carpeta.create(recursive: true);

  // La hora en el nombre: si se vuelve a sacar la foto, es otro archivo
  // y la imagen vieja no queda guardada en la memoria de Flutter.
  final nombre = '${id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final archivo = File(ruta.join(carpeta.path, nombre));
  await archivo.writeAsBytes(bytes, flush: true);
  return archivo.path;
}

/// Lee el archivo y lo devuelve como texto (data URL). Si no está, null.
Future<String?> leerComoTexto(String ruta) async {
  try {
    final bytes = await File(ruta).readAsBytes();
    return 'data:image/jpeg;base64,${base64Encode(bytes)}';
  } catch (_) {
    return null;
  }
}
