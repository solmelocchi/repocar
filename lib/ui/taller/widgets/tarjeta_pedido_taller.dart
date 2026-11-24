import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/envio.dart';
import '../../../domain/models/pedido.dart';
import '../../core/colores.dart';
import '../../core/formato.dart';
import '../../pedidos/widgets/detalle_pedido_screen.dart';

/// Un pedido como lo ve el taller: qué le pidieron, cómo lo entrega
/// y cuánta plata le queda después de la comisión.
class TarjetaPedidoTaller extends StatelessWidget {
  final Pedido pedido;
  final Dependencias deps;

  const TarjetaPedidoTaller({
    super.key,
    required this.pedido,
    required this.deps,
  });

  @override
  Widget build(BuildContext context) {
    final calificacion = pedido.calificacion;

    // Se puede tocar toda la tarjeta para ver el detalle del pedido.
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              DetallePedidoScreen(pedido: pedido, deps: deps, comoTaller: true),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${pedido.numero} · ${pedido.cliente}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorDeEstado(pedido.estado),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      pedido.estado.texto,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(pedido.detalle, style: const TextStyle(fontSize: 13)),
              if (pedido.arrepentido)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'El comprador se arrepintió: coordiná la devolución',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Text(
                pedido.entrega == MetodoEntrega.retiro
                    ? pedido.entrega.texto
                    : '${pedido.entrega.texto} · ${pedido.direccion}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const Divider(height: 18),
              _linea('Total que pagó', pesos(pedido.total)),
              if (pedido.costoEnvio > 0)
                _linea('Envío', '- ${pesos(pedido.costoEnvio)}'),
              _linea(
                'Comisión TalleresYa (${(pedido.comisionPct * 100).round()}%)',
                '- ${pesos(pedido.comision)}',
              ),
              _linea('Te queda', pesos(pedido.neto), fuerte: true),
              if (calificacion != null) ...[
                const Divider(height: 18),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(
                        i <= calificacion.estrellas
                            ? Icons.star
                            : Icons.star_border,
                        size: 16,
                        color: naranja,
                      ),
                    const SizedBox(width: 6),
                    const Text(
                      'Calificó el comprador',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
                if (calificacion.comentario.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      calificacion.comentario,
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                if (calificacion.respuesta != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 10),
                    child: Text(
                      'Tu respuesta: ${calificacion.respuesta}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) =>
                            DialogoResponder(pedido: pedido, deps: deps),
                      ),
                      icon: const Icon(Icons.reply, size: 16),
                      label: const Text('Responder'),
                    ),
                  ),
              ],
              if (pedido.estado != EstadoPedido.entregado) ...[
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => deps.pedidos.cambiarEstado(
                    pedido,
                    pedido.estado == EstadoPedido.pagado
                        ? EstadoPedido.enviado
                        : EstadoPedido.entregado,
                  ),
                  child: Text(switch (pedido.estado) {
                    EstadoPedido.pagado
                        when pedido.entrega == MetodoEntrega.retiro =>
                      'Marcar listo para retirar',
                    EstadoPedido.pagado => 'Marcar en camino',
                    _ => 'Marcar entregado',
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _linea(String texto, String valor, {bool fuerte = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 13,
              fontWeight: fuerte ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: fuerte ? FontWeight.bold : FontWeight.normal,
            color: fuerte ? verde : Colors.black87,
          ),
        ),
      ],
    ),
  );
}

/// La respuesta del taller a una calificación. Lo pidió el cliente:
/// a veces el comprador pone mal la pieza y después culpa al taller.
class DialogoResponder extends StatefulWidget {
  final Pedido pedido;
  final Dependencias deps;

  const DialogoResponder({super.key, required this.pedido, required this.deps});

  @override
  State<DialogoResponder> createState() => _DialogoResponderState();
}

class _DialogoResponderState extends State<DialogoResponder> {
  final _texto = TextEditingController();

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Responder la calificación'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.pedido.calificacion?.comentario ?? '',
            style: const TextStyle(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _texto,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Dale tu versión al comprador',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final texto = _texto.text.trim();
            if (texto.isEmpty) return;
            widget.deps.pedidos.responder(widget.pedido, texto);
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          child: const Text('Responder'),
        ),
      ],
    );
  }
}
