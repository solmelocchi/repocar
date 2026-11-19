import 'package:flutter/material.dart';

import '../../../domain/models/pieza.dart';
import '../../core/colores.dart';

/// Etiqueta de color según el estado de la pieza.
class EtiquetaEstado extends StatelessWidget {
  final EstadoPieza estado;

  const EtiquetaEstado({super.key, required this.estado});

  @override
  Widget build(BuildContext context) {
    final esUsado = estado == EstadoPieza.usado;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: esUsado ? const Color(0xFFFDEEDC) : const Color(0xFFDDF1E6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.texto,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: esUsado ? ambar : verde,
        ),
      ),
    );
  }
}
