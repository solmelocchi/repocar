import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../carrito/widgets/carrito_screen.dart';

/// El ícono del carrito con el numerito.
/// ListenableBuilder escucha al view model del carrito: cuando avisa
/// con notifyListeners(), SOLO esto se redibuja.
class BotonCarrito extends StatelessWidget {
  final Dependencias deps;

  const BotonCarrito({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deps.carrito,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.only(right: 8),
        // El numerito va sobre el ÍCONO y no sobre el botón entero: así
        // queda adentro de la barra y no se corta arriba.
        child: IconButton(
          tooltip: 'Carrito',
          icon: Badge(
            label: Text('${deps.carrito.cantidad}'),
            isLabelVisible: deps.carrito.cantidad > 0,
            child: const Icon(Icons.shopping_cart),
          ),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CarritoScreen(deps: deps)),
          ),
        ),
      ),
    );
  }
}
