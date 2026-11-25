import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../core/colores.dart';
import '../../core/formato.dart';
import '../../catalogo/widgets/foto_pieza.dart';
import 'checkout_screen.dart';

/// El carrito. De acá se sigue a la entrega y el pago.
class CarritoScreen extends StatelessWidget {
  final Dependencias deps;

  const CarritoScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi carrito')),
      // Escucha al carrito: si cambia una cantidad, esto se redibuja.
      body: ListenableBuilder(
        listenable: deps.carrito,
        builder: (context, _) {
          if (deps.carrito.items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 60,
                    color: Colors.black26,
                  ),
                  SizedBox(height: 12),
                  Text('Tu carrito está vacío'),
                ],
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final item in deps.carrito.items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        FotoPieza(
                          pieza: item.pieza,
                          ancho: 48,
                          alto: 48,
                          radio: 6,
                          tamanoIcono: 26,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.pieza.titulo,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                item.pieza.taller.nombre,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: grisTexto,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(pesos(item.subtotal)),
                            ],
                          ),
                        ),
                        // Sin cantidad: es una pieza usada, hay una sola.
                        IconButton(
                          tooltip: 'Quitar del carrito',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => deps.carrito.quitar(item),
                        ),
                      ],
                    ),
                  ),
                ),
              const Divider(height: 32),

              // Wrap y no Row: con la letra grande, el total baja de renglón
              // en vez de salirse de la pantalla.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                children: [
                  const Text(
                    'Repuestos',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    pesos(deps.carrito.total),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: azul,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => CheckoutScreen(deps: deps)),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continuar'),
              ),
              const SizedBox(height: 10),
              const Text(
                'En el paso que sigue elegís cómo lo recibís y pagás dentro '
                'de la app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: grisTexto),
              ),
            ],
          );
        },
      ),
    );
  }
}
