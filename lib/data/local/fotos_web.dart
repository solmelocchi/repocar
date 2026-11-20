import 'dart:convert';
import 'dart:typed_data';

/// En el navegador no hay archivos: la foto viaja como texto (data URL)
/// adentro del dato de la pieza. Ya viene achicada, así que entra.
Future<String> guardarFoto(String id, Uint8List bytes) async =>
    'data:image/jpeg;base64,${base64Encode(bytes)}';

/// En el navegador las fotos ya son texto: no hay archivos que leer.
Future<String?> leerComoTexto(String referencia) async => null;

/// En el navegador no hay archivos que borrar.
Future<void> borrarFoto(String referencia) async {}
