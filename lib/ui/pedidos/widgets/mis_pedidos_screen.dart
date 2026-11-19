import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/envio.dart';
import '../../core/colores.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';
import '../../core/vistas_de_carga.dart';
import '../view_models/pedidos_view_model.dart';
import 'detalle_pedido_screen.dart';

/// Lo que compró el usuario: en qué anda cada pedido y, cuando llega,
/// la calificación. Solo califica el que compró y recibió el repuesto.
class MisPedidosScreen extends StatefulWidget {
  final Dependencias deps;

  const MisPedidosScreen({super.key, required this.deps});

  @override
  State<MisPedidosScreen> createState() => _MisPedidosScreenState();
}

class _MisPedidosScreenState extends State<MisPedidosScreen> {
  @override
  void initState() {
    super.initState();
    widget.deps.pedidos.cargar();
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.deps.pedidos;

    return Scaffold(
      appBar: AppBar(title: const Text('Mis pedidos')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => switch (vm.estado) {
          EstadoCarga.cargando => const VistaCargando(
            mensaje: 'Buscando tus pedidos...',
          ),
          EstadoCarga.error => VistaError(
            mensaje: 'No pudimos traer tus pedidos.',
            alReintentar: vm.cargar,
          ),
          EstadoCarga.exito => _lista(vm),
        },
      ),
    );
  }

  Widget _lista(PedidosViewModel vm) {
    final mios = vm.deCliente(widget.deps.sesion.nombreComprador);

    if (mios.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.receipt_long, size: 60, color: Colors.black26),
              SizedBox(height: 12),
              Text(
                'Todavía no compraste nada.\nBuscá un repuesto para tu auto '
                'y vas a verlo acá.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final pedido in mios)
          _TarjetaPedido(pedido: pedido, vm: vm, deps: widget.deps),
      ],
    );
  }
}

/// Un pedido como lo ve el comprador: el seguimiento y la calificación.
class _TarjetaPedido extends StatelessWidget {
  final Pedido pedido;
  final PedidosViewModel vm;
  final Dependencias deps;

  const _TarjetaPedido({
    required this.pedido,
    required this.vm,
    required this.deps,
  });

  @override
  Widget build(BuildContext context) {
    final calificacion = pedido.calificacion;
    final actual = EstadoPedido.values.indexOf(pedido.estado);

    // Se puede tocar toda la tarjeta para ver el detalle del pedido.
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetallePedidoScreen(pedido: pedido, deps: deps),
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
                      'Pedido ${pedido.numero}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '${pedido.fecha.day}/${pedido.fecha.month}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                pedido.taller.nombre,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(pedido.detalle, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${pedido.entrega.texto} · ${pesos(pedido.total)}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const Divider(height: 20),

              // El seguimiento: en qué paso está el pedido.
              for (var i = 0; i < EstadoPedido.values.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(
                        i <= actual
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 18,
                        color: i <= actual ? verde : Colors.black26,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        EstadoPedido.values[i].texto,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: i == actual
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: i <= actual ? Colors.black87 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),

              if (calificacion != null) ...[
                const Divider(height: 20),
                Row(
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Icon(
                        i <= calificacion.estrellas
                            ? Icons.star
                            : Icons.star_border,
                        size: 18,
                        color: naranja,
                      ),
                    const SizedBox(width: 6),
                    const Text(
                      'Ya lo calificaste',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
                if (calificacion.respuesta != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'El taller te respondió: ${calificacion.respuesta}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ] else if (pedido.sePuedeCalificar) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => DialogoCalificar(pedido: pedido, vm: vm),
                  ),
                  icon: const Icon(Icons.star),
                  label: const Text('Calificar al taller'),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Vas a poder calificar cuando el taller marque el pedido '
                    'como entregado.',
                    style: TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Las estrellas y el comentario. Se abre solo si el pedido está
/// entregado, así nadie califica un taller al que no le compró.
class DialogoCalificar extends StatefulWidget {
  final Pedido pedido;
  final PedidosViewModel vm;

  const DialogoCalificar({super.key, required this.pedido, required this.vm});

  @override
  State<DialogoCalificar> createState() => _DialogoCalificarState();
}

class _DialogoCalificarState extends State<DialogoCalificar> {
  final _comentario = TextEditingController();
  int _estrellas = 5;

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('¿Cómo te fue con ${widget.pedido.taller.nombre}?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40),
                  icon: Icon(
                    i <= _estrellas ? Icons.star : Icons.star_border,
                    color: naranja,
                    size: 30,
                  ),
                  onPressed: () => setState(() => _estrellas = i),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _comentario,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Contá cómo fue la compra (opcional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'El taller va a poder responderte.',
            style: TextStyle(fontSize: 11, color: Colors.black45),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ahora no'),
        ),
        FilledButton(
          onPressed: () {
            widget.vm.calificar(
              widget.pedido,
              _estrellas,
              _comentario.text.trim(),
            );
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          child: const Text('Calificar'),
        ),
      ],
    );
  }
}
