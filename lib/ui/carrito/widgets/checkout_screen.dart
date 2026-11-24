import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/envio.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/taller.dart';
import '../../core/colores.dart';
import '../../core/formato.dart';
import 'pago_screen.dart';

/// Lo que el comprador eligió para un taller.
class _Entrega {
  MetodoEntrega metodo = MetodoEntrega.retiro;
  ZonaEnvio? zona;
  String direccion = '';

  int costo(Taller taller) => switch (metodo) {
    MetodoEntrega.retiro => 0,
    MetodoEntrega.cadete => taller.costoCadete,
    MetodoEntrega.envio => zona?.tarifa ?? 0,
  };

  /// Sin dirección no se puede mandar nada, y sin zona no hay tarifa.
  Map<String, dynamic> aJson() => {
    'metodo': metodo.name,
    'direccion': direccion,
    'zona': zona?.nombre,
  };

  bool get lista => switch (metodo) {
    MetodoEntrega.retiro => true,
    MetodoEntrega.cadete => direccion.trim().isNotEmpty,
    MetodoEntrega.envio => direccion.trim().isNotEmpty && zona != null,
  };
}

/// Cómo se entrega cada cosa y cuánto sale.
/// El carrito puede tener piezas de dos talleres, y cada taller entrega
/// lo suyo: por eso la entrega se elige taller por taller.
class CheckoutScreen extends StatefulWidget {
  final Dependencias deps;

  const CheckoutScreen({super.key, required this.deps});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final Map<String, _Entrega> _entregas = {};

  /// EVENTO DEL SISTEMA: si entra una llamada y la app deja de verse,
  /// lo que se estaba completando se guarda (onHide). Es el último aviso
  /// seguro, y llega en todas las plataformas.
  late final AppLifecycleListener _cicloDeVida;

  /// Cambia cuando se recupera el borrador: así los campos se vuelven a
  /// dibujar con lo guardado.
  int _version = 0;

  @override
  void initState() {
    super.initState();
    // Y el servidor decide si el cobro dentro de la app está habilitado.
    widget.deps.carrito.cargarPoliticas();
    _cicloDeVida = AppLifecycleListener(onHide: _guardarBorrador);
    _recuperarBorrador();
  }

  @override
  void dispose() {
    _cicloDeVida.dispose();
    super.dispose();
  }

  Future<void> _guardarBorrador() => widget.deps.carrito.guardarEntregas({
    for (final entrada in _entregas.entries) entrada.key: entrada.value.aJson(),
  });

  /// Las tarifas por zona vienen de la capa de datos: primero se esperan,
  /// y después se recupera lo que se había completado (la zona se busca
  /// por su nombre entre las que hay).
  Future<void> _recuperarBorrador() async {
    await widget.deps.carrito.cargarZonas();
    final guardado = await widget.deps.carrito.leerEntregas();
    if (guardado == null || !mounted) return;

    setState(() {
      guardado.forEach((cuit, dato) {
        final mapa = Map<String, dynamic>.from(dato as Map);
        final entrega = _entregas.putIfAbsent(cuit, () => _Entrega());
        entrega
          ..metodo = MetodoEntrega.values.firstWhere(
            (m) => m.name == mapa['metodo'],
            orElse: () => MetodoEntrega.retiro,
          )
          ..direccion = mapa['direccion'] as String? ?? ''
          ..zona = widget.deps.carrito.zonas
              .where((z) => z.nombre == mapa['zona'])
              .firstOrNull;
      });
      _version++;
    });
  }

  /// Los talleres que aparecen en el carrito, sin repetir.
  List<Taller> get _talleres {
    final encontrados = <String, Taller>{};
    for (final item in widget.deps.carrito.items) {
      encontrados[item.pieza.taller.cuit] = item.pieza.taller;
    }
    return encontrados.values.toList();
  }

  _Entrega _entregaDe(Taller taller) =>
      _entregas.putIfAbsent(taller.cuit, () => _Entrega());

  int get _envios => _talleres.fold(
    0,
    (suma, taller) => suma + _entregaDe(taller).costo(taller),
  );

  int get _total => widget.deps.carrito.total + _envios;

  bool get _puedePagar => _talleres.every((taller) => _entregaDe(taller).lista);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrega y pago')),
      body: ListenableBuilder(
        listenable: widget.deps.carrito,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final taller in _talleres) _tarjetaTaller(taller),
            const Divider(height: 28),
            _fila('Repuestos', pesos(widget.deps.carrito.total)),
            _fila('Envíos', _envios == 0 ? 'Sin cargo' : pesos(_envios)),
            const SizedBox(height: 6),
            _fila('Total', pesos(_total), grande: true),
            const SizedBox(height: 18),

            // El cobro dentro de la app es una POLÍTICA del servidor: si
            // TalleresYa lo apaga, o si el servidor no contesta a tiempo,
            // se vuelve a coordinar con el taller como en la etapa 1.
            if (widget.deps.carrito.pagoHabilitado) ...[
              FilledButton.icon(
                onPressed: _puedePagar ? _irAPagar : null,
                icon: const Icon(Icons.lock_outline),
                label: Text('Pagar ${pesos(_total)}'),
              ),
              const SizedBox(height: 8),
              Text(
                _puedePagar
                    ? 'El pago se hace dentro de la app con Mercado Pago.'
                    : 'Completá la dirección y la zona para poder pagar.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black45),
              ),
            ] else
              const Card(
                color: Color(0xFFFDEEDC),
                elevation: 0,
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: ambar),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'El cobro por la app está apagado. Le pagás al '
                          'taller cuando retirás o recibís el pedido.',
                          style: TextStyle(fontSize: 13, color: ambar),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaTaller(Taller taller) {
    final entrega = _entregaDe(taller);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.store, size: 18, color: azul),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    taller.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in widget.deps.carrito.itemsDeTaller(taller.cuit))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.cantidad} x ${item.pieza.titulo}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      pesos(item.subtotal),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              '¿Cómo lo recibís?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  label: const Text('Retiro en el taller'),
                  selected: entrega.metodo == MetodoEntrega.retiro,
                  onSelected: (_) =>
                      setState(() => entrega.metodo = MetodoEntrega.retiro),
                ),
                if (taller.tieneCadete)
                  ChoiceChip(
                    label: Text(
                      'Cadete del taller · ${pesos(taller.costoCadete)}',
                    ),
                    selected: entrega.metodo == MetodoEntrega.cadete,
                    onSelected: (_) =>
                        setState(() => entrega.metodo = MetodoEntrega.cadete),
                  ),
                ChoiceChip(
                  label: const Text('Envío a domicilio'),
                  selected: entrega.metodo == MetodoEntrega.envio,
                  onSelected: (_) =>
                      setState(() => entrega.metodo = MetodoEntrega.envio),
                ),
              ],
            ),
            if (!taller.tieneCadete)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Este taller no tiene cadete propio: el envío lo cotiza la '
                  'empresa según tu zona.',
                  style: TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
            if (entrega.metodo != MetodoEntrega.retiro) ...[
              const SizedBox(height: 12),
              TextFormField(
                // La key cambia al recuperar el borrador: así el campo
                // arranca con la dirección guardada.
                key: ValueKey('direccion-${taller.cuit}-$_version'),
                initialValue: entrega.direccion,
                decoration: const InputDecoration(
                  labelText: 'Dirección',
                  hintText: 'Calle, número y piso',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (valor) => setState(() => entrega.direccion = valor),
              ),
            ],
            if (entrega.metodo == MetodoEntrega.envio) ...[
              const SizedBox(height: 10),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Zona de entrega',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ZonaEnvio>(
                    value: entrega.zona,
                    isExpanded: true,
                    hint: const Text(
                      'Elegí tu zona',
                      style: TextStyle(fontSize: 13),
                    ),
                    items: [
                      for (final zona in widget.deps.carrito.zonas)
                        DropdownMenuItem(
                          value: zona,
                          child: Text(
                            '${zona.nombre} · ${zona.km} km · '
                            '${pesos(zona.tarifa)}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                    ],
                    onChanged: (zona) => setState(() => entrega.zona = zona),
                  ),
                ),
              ),
            ],
            if (entrega.costo(taller) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Envío: ${pesos(entrega.costo(taller))}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fila(String texto, String valor, {bool grande = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          texto,
          style: TextStyle(
            fontSize: grande ? 18 : 14,
            fontWeight: grande ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: grande ? 22 : 14,
            fontWeight: grande ? FontWeight.bold : FontWeight.normal,
            color: grande ? azul : Colors.black87,
          ),
        ),
      ],
    ),
  );

  void _irAPagar() {
    final compras = [
      for (final taller in _talleres)
        CompraTaller(
          taller: taller,
          items: widget.deps.carrito.itemsDeTaller(taller.cuit),
          entrega: _entregaDe(taller).metodo,
          direccion: _entregaDe(taller).direccion,
          costoEnvio: _entregaDe(taller).costo(taller),
        ),
    ];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PagoScreen(compras: compras, deps: widget.deps),
      ),
    );
  }
}
