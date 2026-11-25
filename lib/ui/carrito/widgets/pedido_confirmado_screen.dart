import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/envio.dart';
import '../../../domain/models/pedido.dart';
import '../../core/colores.dart';
import '../../core/formato.dart';

/// El pago salió bien.
class PedidoConfirmadoScreen extends StatelessWidget {
  final List<Pedido> nuevos;
  final Dependencias deps;

  const PedidoConfirmadoScreen({
    super.key,
    required this.nuevos,
    required this.deps,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.check_circle, size: 84, color: verde),
              const SizedBox(height: 18),
              const Text(
                '¡Pago acreditado!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                nuevos.length == 1
                    ? 'El taller ya ve tu pedido en su panel.'
                    : 'Se armó un pedido por taller: cada uno prepara y '
                          'entrega lo suyo.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: grisTexto),
              ),
              const SizedBox(height: 20),
              for (final pedido in nuevos)
                Card(
                  child: ListTile(
                    title: Text('Pedido ${pedido.numero}'),
                    subtitle: Text(
                      '${pedido.taller.nombre}\n${pedido.entrega.texto}',
                    ),
                    isThreeLine: true,
                    trailing: Text(
                      pesos(pedido.total),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  deps.pestanaComprador.value = 2; // Pedidos
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Ver mis pedidos'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  deps.pestanaComprador.value = 0; // Inicio
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                child: const Text('Seguir comprando'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
