import 'dart:io';

import 'package:flutter/material.dart';

/// En el celular: la foto está en un archivo. Se decodifica al ancho en
/// que se muestra ([pixeles]), no al de la foto original.
Widget imagenDeArchivo(String ruta, BoxFit fit, int pixeles) => Image.file(
  File(ruta),
  fit: fit,
  cacheWidth: pixeles,
  gaplessPlayback: true,
  // Si el archivo no está (por ejemplo, se borraron los datos de la
  // app), no se rompe la pantalla: se ve un ícono.
  errorBuilder: (_, _, _) => const Icon(Icons.image_not_supported_outlined),
);
