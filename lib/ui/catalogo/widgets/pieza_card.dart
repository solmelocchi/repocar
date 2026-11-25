import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/auto.dart';
import '../../../domain/models/pieza.dart';
import '../../core/colores.dart';
import '../../core/formato.dart';
import 'detalle_screen.dart';
import 'etiqueta_estado.dart';
import 'foto_pieza.dart';

/// La tarjeta de un repuesto en una lista. Si viene el auto del
/// comprador, al tocarla se ve la ficha con la compatibilidad confirmada.
class PiezaCard extends StatelessWidget {
  final Pieza pieza;
  final Auto? auto;
  final Dependencias deps;

  const PiezaCard({
    super.key,
    required this.pieza,
    required this.deps,
    this.auto,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleScreen(pieza: pieza, auto: auto, deps: deps),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              FotoPieza(pieza: pieza, ancho: 74, alto: 74),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pieza.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pieza.taller.nombre,
                      style: const TextStyle(fontSize: 12, color: grisTexto),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          pesos(pieza.precio),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: azul,
                          ),
                        ),
                        const SizedBox(width: 8),
                        EtiquetaEstado(estado: pieza.estado),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
