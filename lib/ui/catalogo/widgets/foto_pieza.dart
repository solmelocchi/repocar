import 'package:flutter/material.dart';

import '../../../domain/models/pieza.dart';
import '../../core/colores.dart';
import '../../core/iconos.dart';
import '../../core/imagen_guardada.dart';

/// La imagen de un repuesto: la foto, si el taller sacó una, y si no, su
/// ícono sobre un fondo claro. Es el mismo widget en todas las pantallas,
/// así la regla "foto o ícono" está escrita una sola vez.
class FotoPieza extends StatelessWidget {
  final Pieza pieza;
  final double ancho;
  final double alto;
  final double radio;
  final double tamanoIcono;

  const FotoPieza({
    super.key,
    required this.pieza,
    required this.ancho,
    required this.alto,
    this.radio = 10,
    this.tamanoIcono = 36,
  });

  @override
  Widget build(BuildContext context) {
    final foto = pieza.foto;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radio),
      child: SizedBox(
        width: ancho,
        height: alto,
        child: foto == null
            ? ColoredBox(
                color: azulClaro,
                child: Icon(
                  iconoDe(pieza.icono),
                  size: tamanoIcono,
                  color: azul,
                ),
              )
            : imagenGuardada(context, foto, anchoEnPantalla: ancho),
      ),
    );
  }
}
