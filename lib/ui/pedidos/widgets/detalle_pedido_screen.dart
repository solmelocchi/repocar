import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/envio.dart';
import '../../../domain/models/pedido.dart';
import '../../catalogo/widgets/detalle_screen.dart';
import '../../catalogo/widgets/foto_pieza.dart';
import '../../core/aviso.dart';
import '../../core/colores.dart';
import '../../core/formato.dart';
import '../../taller/widgets/tarjeta_pedido_taller.dart';
import 'mis_pedidos_screen.dart';

/// El detalle de un pedido. Lo usan los dos lados:
///   · el COMPRADOR ve qué compró, cuánto pagó, en qué anda, y puede
///     escribirle al taller o calificarlo cuando llega;
///   · el TALLER ve qué le pidieron, cuánto le queda después de la
///     comisión, y lo marca en camino o entregado.
/// Cada repuesto del pedido se puede tocar para ver su ficha.
class DetallePedidoScreen extends StatelessWidget {
  final Pedido pedido;
  final Dependencias deps;

  /// true si lo mira el taller que lo vende.
  final bool comoTaller;

  /// true si lo mira TalleresYa desde su panel: ve las dos partes y el
  /// reparto de la plata, sin botones para cambiar nada.
  final bool comoAdmin;

  const DetallePedidoScreen({
    super.key,
    required this.pedido,
    required this.deps,
    this.comoTaller = false,
    this.comoAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    // Escucha a los pedidos: si cambia el estado o lo califican, el
    // detalle se redibuja solo.
    return ListenableBuilder(
      listenable: deps.pedidos,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text('Pedido ${pedido.numero}')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _cabecera(),
            const SizedBox(height: 12),
            _seguimiento(),
            const SizedBox(height: 12),
            _productos(context),
            const SizedBox(height: 12),
            _entrega(),
            const SizedBox(height: 12),
            _plata(),
            const SizedBox(height: 12),
            _contraparte(context),
            if (pedido.calificacion != null) ...[
              const SizedBox(height: 12),
              _calificacion(context),
            ],
            const SizedBox(height: 16),
            ..._acciones(context),
          ],
        ),
      ),
    );
  }

  Widget _seccion(String titulo, List<Widget> contenido) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 10),
          ...contenido,
        ],
      ),
    ),
  );

  Widget _cabecera() => Row(
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: colorDeEstado(pedido.estado),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          pedido.estado.texto,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          'Comprado el ${pedido.fecha.day}/${pedido.fecha.month}/'
          '${pedido.fecha.year}',
          textAlign: TextAlign.end,
          style: const TextStyle(fontSize: 12, color: grisTexto),
        ),
      ),
    ],
  );

  Widget _seguimiento() {
    final actual = EstadoPedido.values.indexOf(pedido.estado);
    return _seccion('Seguimiento', [
      for (var i = 0; i < EstadoPedido.values.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                i <= actual ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: i <= actual ? verde : Colors.black26,
              ),
              const SizedBox(width: 10),
              Text(
                EstadoPedido.values[i].texto,
                style: TextStyle(
                  fontWeight: i == actual ? FontWeight.bold : FontWeight.normal,
                  color: i <= actual ? Colors.black87 : grisTexto,
                ),
              ),
            ],
          ),
        ),
    ]);
  }

  Widget _productos(BuildContext context) => _seccion(
    comoTaller ? 'Qué te pidieron' : 'Qué compraste',
    [
      for (final item in pedido.items)
        InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DetalleScreen(pieza: item.pieza, deps: deps),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                FotoPieza(
                  pieza: item.pieza,
                  ancho: 56,
                  alto: 56,
                  radio: 8,
                  tamanoIcono: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.pieza.titulo,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${item.cantidad} × ${pesos(item.pieza.precio)}',
                        style: const TextStyle(fontSize: 12, color: grisTexto),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.black26),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _entrega() => _seccion('Entrega', [
    Row(
      children: [
        Icon(switch (pedido.entrega) {
          MetodoEntrega.retiro => Icons.storefront,
          MetodoEntrega.cadete => Icons.delivery_dining,
          MetodoEntrega.envio => Icons.local_shipping,
        }, color: azul),
        const SizedBox(width: 10),
        Expanded(child: Text(pedido.entrega.texto)),
      ],
    ),
    if (pedido.direccion.isNotEmpty) ...[
      const SizedBox(height: 6),
      Text(
        pedido.direccion,
        style: const TextStyle(fontSize: 13, color: grisTexto),
      ),
    ],
  ]);

  Widget _plata() => comoAdmin
      ? _seccion('Reparto de la plata', [
          _linea('Pagó el comprador', pesos(pedido.total)),
          if (pedido.costoEnvio > 0) _linea('Envío', pesos(pedido.costoEnvio)),
          _linea('Al taller', pesos(pedido.neto)),
          const Divider(),
          _linea(
            'Comisión TalleresYa (${(pedido.comisionPct * 100).round()}%)',
            pesos(pedido.comision),
            fuerte: true,
          ),
        ])
      : _seccion(
          comoTaller ? 'Cuánto te queda' : 'Lo que pagaste',
          comoTaller
              ? [
                  _linea('Total que pagó', pesos(pedido.total)),
                  if (pedido.costoEnvio > 0)
                    _linea('Envío', '- ${pesos(pedido.costoEnvio)}'),
                  _linea(
                    'Comisión TalleresYa (${(pedido.comisionPct * 100).round()}%)',
                    '- ${pesos(pedido.comision)}',
                  ),
                  const Divider(),
                  _linea('Te queda', pesos(pedido.neto), fuerte: true),
                ]
              : [
                  _linea('Repuestos', pesos(pedido.subtotal)),
                  _linea(
                    'Envío',
                    pedido.costoEnvio > 0
                        ? pesos(pedido.costoEnvio)
                        : 'Sin cargo',
                  ),
                  const Divider(),
                  _linea('Total', pesos(pedido.total), fuerte: true),
                ],
        );

  Widget _contraparte(BuildContext context) => comoAdmin
      ? Column(
          // A todo el ancho, como las demás secciones (centrado quedaba
          // angosto).
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _seccion('Comprador', [Text(pedido.cliente)]),
            const SizedBox(height: 12),
            _vendedor(context),
          ],
        )
      : comoTaller
      ? _seccion('Comprador', [
          Row(
            children: [
              const CircleAvatar(child: Icon(Icons.person)),
              const SizedBox(width: 12),
              Expanded(child: Text(pedido.cliente)),
            ],
          ),
        ])
      : _vendedor(context);

  Widget _vendedor(BuildContext context) => _seccion('Vendedor', [
    Row(
      children: [
        const CircleAvatar(child: Icon(Icons.store)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pedido.taller.nombre,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              // Sin el teléfono: todo se hace por RepoCar.
              Text(
                pedido.taller.zona,
                style: const TextStyle(fontSize: 12, color: grisTexto),
              ),
            ],
          ),
        ),
      ],
    ),
  ]);

  Widget _calificacion(BuildContext context) {
    final calificacion = pedido.calificacion!;
    return _seccion('Calificación', [
      Row(
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              i <= calificacion.estrellas ? Icons.star : Icons.star_border,
              color: naranja,
              size: 22,
            ),
        ],
      ),
      if (calificacion.comentario.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text(
          calificacion.comentario,
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
      if (calificacion.respuesta != null) ...[
        const SizedBox(height: 8),
        Text(
          comoTaller
              ? 'Tu respuesta: ${calificacion.respuesta}'
              : 'El taller respondió: ${calificacion.respuesta}',
          style: const TextStyle(fontSize: 13, color: grisTexto),
        ),
      ],
    ]);
  }

  List<Widget> _acciones(BuildContext context) {
    // TalleresYa mira, no toca: los cambios los hacen el taller y el
    // comprador.
    if (comoAdmin) {
      return [if (pedido.arrepentido) _avisoDeArrepentimiento()];
    }
    if (comoTaller) {
      return [
        if (pedido.arrepentido) _avisoDeArrepentimiento(),
        if (pedido.estado != EstadoPedido.entregado)
          FilledButton(
            onPressed: () => deps.pedidos.cambiarEstado(
              pedido,
              pedido.estado == EstadoPedido.pagado
                  ? EstadoPedido.enviado
                  : EstadoPedido.entregado,
            ),
            child: Text(
              pedido.estado == EstadoPedido.pagado
                  ? 'Marcar en camino'
                  : 'Marcar entregado',
            ),
          ),
        if (pedido.calificacion != null &&
            pedido.calificacion!.respuesta == null)
          OutlinedButton.icon(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => DialogoResponder(pedido: pedido, deps: deps),
            ),
            icon: const Icon(Icons.reply),
            label: const Text('Responder la calificación'),
          ),
      ];
    }

    return [
      // La regla de quién puede calificar está en el modelo, no acá.
      if (pedido.sePuedeCalificar)
        FilledButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => DialogoCalificar(pedido: pedido, vm: deps.pedidos),
          ),
          icon: const Icon(Icons.star),
          label: const Text('Calificar al taller'),
        )
      else if (pedido.calificacion == null)
        const Text(
          'Vas a poder calificar cuando el taller marque el pedido como '
          'entregado.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: grisTexto),
        ),
      const SizedBox(height: 16),
      _arrepentimiento(context),
    ];
  }

  /// Para el taller y para TalleresYa: el comprador se arrepintió.
  Widget _avisoDeArrepentimiento() => Card(
    color: const Color(0xFFFFEBEE),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        'El comprador usó el botón de arrepentimiento el '
        '${fechaCorta(pedido.arrepentidoEl!)}. El taller coordina la '
        'devolución (Ley 24.240).',
        style: const TextStyle(fontSize: 13),
      ),
    ),
  );

  /// El BOTÓN DE ARREPENTIMIENTO (obligatorio en las ventas por internet,
  /// Resolución 424/2020): sin dar explicaciones, dentro de los 10 días
  /// desde que recibe la compra.
  Widget _arrepentimiento(BuildContext context) {
    final cuando = pedido.arrepentidoEl;
    if (cuando != null) {
      return Card(
        color: const Color(0xFFFFEBEE),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Te arrepentiste de esta compra el ${fechaCorta(cuando)}. Le '
            'avisamos al taller para coordinar la devolución.',
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );
    }
    if (!pedido.puedeArrepentirse(DateTime.now())) {
      return const Text(
        'Ya pasaron los 10 días para arrepentirte de esta compra.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12, color: grisTexto),
      );
    }
    final limite = pedido.limiteParaArrepentirse;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () => _confirmarArrepentimiento(context),
          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
          icon: const Icon(Icons.undo),
          label: const Text('Botón de arrepentimiento'),
        ),
        const SizedBox(height: 4),
        Text(
          limite == null
              ? 'Podés arrepentirte sin dar explicaciones: tenés 10 días '
                    'desde que lo recibís (Ley 24.240).'
              : 'Podés arrepentirte sin dar explicaciones hasta el '
                    '${fechaCorta(limite)} (Ley 24.240).',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: grisTexto),
        ),
      ],
    );
  }

  Future<void> _confirmarArrepentimiento(BuildContext context) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Te arrepentís de la compra?'),
        content: const Text(
          'Le avisamos al taller para que coordine la devolución con vos. '
          'No hace falta dar explicaciones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(110, 44),
            ),
            child: const Text('Sí, me arrepiento'),
          ),
        ],
      ),
    );
    if (seguro != true || !context.mounted) return;
    final listo = await deps.pedidos.arrepentirse(pedido);
    if (!context.mounted) return;
    avisar(
      context,
      listo ? 'Listo: le avisamos al taller' : 'Ya pasó el plazo de 10 días',
    );
  }

  Widget _linea(String texto, String valor, {bool fuerte = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            texto,
            style: TextStyle(
              fontWeight: fuerte ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontWeight: fuerte ? FontWeight.bold : FontWeight.normal,
            color: fuerte ? verde : Colors.black87,
          ),
        ),
      ],
    ),
  );
}
