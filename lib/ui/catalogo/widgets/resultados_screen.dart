import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/auto.dart';
import 'boton_carrito.dart';
import 'pieza_card.dart';
import '../../core/colores.dart';

/// Las piezas que le sirven a ese auto.
class ResultadosScreen extends StatelessWidget {
  final Auto auto;
  final Dependencias deps;

  const ResultadosScreen({super.key, required this.auto, required this.deps});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Repuestos', style: TextStyle(fontSize: 18)),
            Text(
              '$auto',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
        actions: [BotonCarrito(deps: deps)],
      ),
      // Escucha al view model: si un taller publica algo que le sirve a
      // este auto, aparece acá sin salir de la pantalla.
      body: ListenableBuilder(
        listenable: deps.catalogo,
        builder: (context, _) {
          // Acá está la búsqueda: solo lo compatible y no vendido.
          final piezas = deps.catalogo.paraAuto(auto);

          if (piezas.isEmpty) {
            return const Center(
              child: Text('No hay repuestos para este auto todavía.'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: piezas.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Text(
                  '${piezas.length} repuestos compatibles',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: grisTexto,
                  ),
                );
              }
              return PiezaCard(pieza: piezas[i - 1], auto: auto, deps: deps);
            },
          );
        },
      ),
    );
  }
}
