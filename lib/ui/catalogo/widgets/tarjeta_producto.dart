import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/auto.dart';
import '../../../domain/models/pieza.dart';
import '../../core/colores.dart';
import '../../core/formato.dart';
import 'detalle_screen.dart';
import 'etiqueta_estado.dart';
import 'foto_pieza.dart';

/// Un repuesto en la grilla del inicio: la foto grande arriba y los
/// datos abajo. Se toca entera para ver la ficha.
class TarjetaProducto extends StatelessWidget {
  final Pieza pieza;
  final Dependencias deps;

  /// Si el comprador eligió su auto, la ficha le confirma que le sirve.
  final Auto? auto;

  const TarjetaProducto({
    super.key,
    required this.pieza,
    required this.deps,
    this.auto,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleScreen(pieza: pieza, auto: auto, deps: deps),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // La foto ocupa lo que sobra: los datos de abajo quedan siempre
            // enteros (aunque el teléfono tenga la letra agrandada) y no
            // queda un hueco entre el título y el precio.
            Expanded(
              child: LayoutBuilder(
                builder: (context, lado) => FotoPieza(
                  pieza: pieza,
                  ancho: lado.maxWidth,
                  alto: lado.maxHeight,
                  radio: 0,
                  tamanoIcono: 44,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EtiquetaEstado(estado: pieza.estado),
                  const SizedBox(height: 6),
                  // El título ocupa SIEMPRE el lugar de dos renglones,
                  // tenga uno o dos: así el precio queda a la misma altura
                  // en todas las tarjetas de la fila.
                  SizedBox(
                    height: 34,
                    child: Text(
                      pieza.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, height: 1.25),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pesos(pieza.precio),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: azul,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    pieza.taller.tieneCadete
                        ? 'Cadete del taller'
                        : pieza.taller.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: pieza.taller.tieneCadete
                          ? FontWeight.w600
                          : FontWeight.normal,
                      color: pieza.taller.tieneCadete ? verde : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
