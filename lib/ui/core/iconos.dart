import 'package:flutter/material.dart';

/// El dominio guarda el NOMBRE del ícono, no el ícono.
/// Acá se traduce ese nombre a algo que se pueda dibujar. En la app real
/// este archivo no existiría: la pieza traería la dirección de su foto.
const iconosDeRepuestos = <String, IconData>{
  'build': Icons.build,
  'electric_bolt': Icons.electric_bolt,
  'album': Icons.album,
  'compress': Icons.compress,
  'settings': Icons.settings,
  'lightbulb': Icons.lightbulb,
  'water_drop': Icons.water_drop,
  'ac_unit': Icons.ac_unit,
  'flip': Icons.flip,
};

/// Si el nombre no está en la lista, cae en la llave de taller.
IconData iconoDe(String clave) => iconosDeRepuestos[clave] ?? Icons.build;

/// Las opciones entre las que elige el taller al publicar.
List<String> get clavesDeIconos => iconosDeRepuestos.keys.toList();

/// El nombre del rubro de cada ícono, para los filtros del buscador.
const nombresDeRubros = <String, String>{
  'build': 'Varios',
  'electric_bolt': 'Eléctrico',
  'album': 'Frenos y embrague',
  'compress': 'Suspensión',
  'settings': 'Motor y caja',
  'lightbulb': 'Iluminación',
  'water_drop': 'Agua y combustible',
  'ac_unit': 'Refrigeración',
  'flip': 'Carrocería',
};
