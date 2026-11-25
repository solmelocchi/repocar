import 'package:flutter/material.dart';

import '../../../domain/filtro_de_pedidos.dart';
import '../../../domain/models/pedido.dart';
import '../../core/colores.dart';

/// Una lista de pedidos con una barra arriba para buscar (por número,
/// comprador, taller o repuesto), filtrar por estado y ordenar.
///
/// La regla de filtrar está en el dominio (filtrarPedidos); este widget
/// solo recuerda lo que eligió el usuario. No scrollea solo: va adentro
/// de la lista de la pantalla.
class PedidosFiltrables extends StatefulWidget {
  const PedidosFiltrables({
    super.key,
    required this.pedidos,
    required this.construir,
    this.vacio = 'No hay pedidos.',
  });

  final List<Pedido> pedidos;
  final Widget Function(Pedido pedido) construir;

  /// Qué decir si no hay ninguno (sin filtros).
  final String vacio;

  @override
  State<PedidosFiltrables> createState() => _PedidosFiltrablesState();
}

class _PedidosFiltrablesState extends State<PedidosFiltrables> {
  final _texto = TextEditingController();
  EstadoPedido? _estado;
  OrdenDePedidos _orden = OrdenDePedidos.masNuevos;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pedidos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          widget.vacio,
          textAlign: TextAlign.center,
          style: const TextStyle(color: grisTexto),
        ),
      );
    }

    final visibles = filtrarPedidos(
      widget.pedidos,
      texto: _texto.text,
      estado: _estado,
      orden: _orden,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _texto,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar por número, comprador o repuesto',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _texto.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(_texto.clear),
                  ),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              DropdownButton<OrdenDePedidos>(
                value: _orden,
                underline: const SizedBox.shrink(),
                items: [
                  for (final orden in OrdenDePedidos.values)
                    DropdownMenuItem(value: orden, child: Text(orden.texto)),
                ],
                onChanged: (orden) => setState(() => _orden = orden!),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Todos'),
                selected: _estado == null,
                onSelected: (_) => setState(() => _estado = null),
              ),
              for (final estado in EstadoPedido.values) ...[
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(estado.texto),
                  selected: _estado == estado,
                  onSelected: (_) => setState(() => _estado = estado),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (visibles.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Ningún pedido coincide con la búsqueda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: grisTexto),
            ),
          )
        else
          for (final pedido in visibles) widget.construir(pedido),
      ],
    );
  }
}
