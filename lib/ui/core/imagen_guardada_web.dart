import 'package:flutter/material.dart';

/// En el navegador no hay archivos del teléfono: si llegara una ruta,
/// se muestra un ícono en vez de romper.
Widget imagenDeArchivo(String ruta, BoxFit fit, int pixeles) =>
    const Icon(Icons.image_not_supported_outlined);
