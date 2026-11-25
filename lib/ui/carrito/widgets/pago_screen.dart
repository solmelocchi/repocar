import 'dart:async';

import 'package:flutter/material.dart';

import '../../../data/repositories/pedidos_repository.dart';
import '../../../dependencias.dart';
import '../../../domain/models/envio.dart';
import '../../../domain/models/pago.dart';
import '../../../domain/models/pedido.dart';
import '../../core/colores.dart';
import '../../core/formato.dart';
import 'pedido_confirmado_screen.dart';

/// El pago. Se elige con qué pagar, se ve cómo se reparte la plata y se
/// cobra. Quien cobra está SIMULADO (PagosSimulados): tarda y contesta
/// como Mercado Pago, aprobado o rechazado.
class PagoScreen extends StatefulWidget {
  final List<CompraTaller> compras;
  final Dependencias deps;

  const PagoScreen({super.key, required this.compras, required this.deps});

  @override
  State<PagoScreen> createState() => _PagoScreenState();
}

class _PagoScreenState extends State<PagoScreen> {
  MedioDePago _medio = MedioDePago.dineroEnCuenta;
  int _cuotas = 1;

  /// Mientras se cobra, se muestra "procesando" y no se puede tocar nada:
  /// así nadie paga dos veces por tocar rápido.
  bool _pagando = false;

  /// Lo que se va mostrando mientras se cobra.
  String _etapa = '';
  Timer? _reloj;

  /// Si el último intento se rechazó, por qué.
  String? _rechazo;

  int get _total =>
      widget.compras.fold(0, (suma, compra) => suma + compra.total);

  int get _comision =>
      widget.compras.fold(0, (suma, compra) => suma + compra.comision);

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  Future<void> _pagar() async {
    // Antes de cobrar: ¿siguen todas a la venta? Si otro comprador se
    // llevó una mientras la tenías en el carrito, no se cobra nada.
    final vendidas = widget.deps.carrito.noDisponibles;
    if (vendidas.isNotEmpty) {
      setState(
        () => _rechazo =
            '${vendidas.map((p) => p.titulo).join(', ')} ya no está '
            'disponible: otro comprador se lo llevó. Sacalo del carrito.',
      );
      return;
    }

    setState(() {
      _pagando = true;
      _rechazo = null;
      _etapa = 'Conectando con Mercado Pago...';
    });
    // Mientras espera, cambia el mensaje, como en la app de verdad.
    var paso = 0;
    const etapas = ['Validando el medio de pago...', 'Confirmando el pago...'];
    _reloj = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (paso < etapas.length && mounted) {
        setState(() => _etapa = etapas[paso++]);
      }
    });

    final resultado = await widget.deps.carrito.cobrar(
      total: _total,
      medio: _medio,
      cuotas: _cuotas,
    );
    _reloj?.cancel();

    // Después de un await hay que preguntar si la pantalla sigue viva.
    if (!mounted) return;

    if (!resultado.aprobado) {
      // Rechazado: NO se arma el pedido y el carrito queda como estaba.
      setState(() {
        _pagando = false;
        _rechazo = resultado.motivo;
      });
      return;
    }

    setState(() => _etapa = '¡Pago aprobado!');
    final List<Pedido> nuevos;
    try {
      nuevos = await widget.deps.pedidos.confirmarCompra(
        widget.compras,
        widget.deps.sesion.nombreComprador,
        usuario: widget.deps.sesion.idComprador,
      );
    } on PiezaNoDisponible catch (error) {
      // Otro comprador se la llevó justo mientras se procesaba el pago.
      // En la app real, acá se devuelve la plata (Mercado Pago lo hace con
      // un reintegro); en la simulación, se avisa y no se arma el pedido.
      if (!mounted) return;
      setState(() {
        _pagando = false;
        _rechazo = '$error: otro comprador se lo llevó. No se te cobró.';
      });
      return;
    }
    widget.deps.carrito.vaciar();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            PedidoConfirmadoScreen(nuevos: nuevos, deps: widget.deps),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Mientras se cobra no se puede volver atrás.
      canPop: !_pagando,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pagar'),
          automaticallyImplyLeading: !_pagando,
        ),
        body: _pagando ? _procesando() : _formulario(),
      ),
    );
  }

  /// La pantalla de "procesando", como la de Mercado Pago.
  Widget _procesando() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.account_balance_wallet, color: azul, size: 48),
          const SizedBox(height: 8),
          const Text(
            'Mercado Pago',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: azul,
            ),
          ),
          const SizedBox(height: 28),
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          Text(
            _etapa,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15),
          ),
          const SizedBox(height: 8),
          Text(
            pesos(_total),
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: azul,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _formulario() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Card(
        color: const Color(0xFFE8F2FD),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet, color: azul),
                  SizedBox(width: 8),
                  Text(
                    'Mercado Pago',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: azul,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Total a pagar', style: TextStyle(color: grisTexto)),
              Text(
                pesos(_total),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: azul,
                ),
              ),
              if (_medio.admiteCuotas && _cuotas > 1)
                Text(
                  '$_cuotas cuotas sin interés de '
                  '${pesos(valorDeCuota(_total, _cuotas))}',
                  style: const TextStyle(color: verde, fontSize: 13),
                ),
            ],
          ),
        ),
      ),

      // El rechazo, si lo hubo: el pedido NO se armó.
      if (_rechazo != null)
        Card(
          color: const Color(0xFFFDECEA),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Pago rechazado. $_rechazo',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ),

      const SizedBox(height: 16),
      const Text(
        '¿Con qué pagás?',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      Card(
        margin: EdgeInsets.zero,
        child: RadioGroup<MedioDePago>(
          groupValue: _medio,
          onChanged: (medio) => setState(() {
            _medio = medio!;
            if (!_medio.admiteCuotas) _cuotas = 1;
          }),
          child: Column(
            children: [
              for (final medio in MedioDePago.values)
                RadioListTile<MedioDePago>(
                  value: medio,
                  title: Text(medio.titulo),
                  subtitle: Text(
                    medio.detalle,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
      if (_medio.admiteCuotas) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _cuotas,
          decoration: const InputDecoration(
            labelText: 'Cuotas',
            border: OutlineInputBorder(),
          ),
          items: [
            for (final cuotas in const [1, 3, 6])
              DropdownMenuItem(
                value: cuotas,
                child: Text(
                  cuotas == 1
                      ? '1 pago de ${pesos(_total)}'
                      : '$cuotas cuotas sin interés de '
                            '${pesos(valorDeCuota(_total, cuotas))}',
                ),
              ),
          ],
          onChanged: (valor) => setState(() => _cuotas = valor ?? 1),
        ),
      ],

      const SizedBox(height: 20),
      const Text(
        'Cómo se reparte',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 4),
      const Text(
        'El pago se parte solo: a cada taller le entra lo suyo y '
        'TalleresYa retiene su comisión, sin transferencias a mano.',
        style: TextStyle(fontSize: 12, color: grisTexto),
      ),
      const SizedBox(height: 10),
      for (final compra in widget.compras)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compra.taller.nombre,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _linea('Repuestos', pesos(compra.subtotal)),
                if (compra.costoEnvio > 0)
                  _linea(
                    compra.entrega == MetodoEntrega.cadete
                        ? 'Cadete del taller'
                        : 'Envío por zona',
                    pesos(compra.costoEnvio),
                  ),
                const Divider(height: 18),
                _linea('Le entra al taller', pesos(compra.neto), color: verde),
                _linea(
                  'Comisión TalleresYa '
                  '(${(compra.taller.comision * 100).round()}%)',
                  pesos(compra.comision),
                  color: ambar,
                ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 8),
      Text(
        'TalleresYa cobra ${pesos(_comision)} por esta operación. '
        'Aparte, Mercado Pago cobra su propia comisión por el cobro.',
        style: const TextStyle(fontSize: 11, color: grisTexto),
      ),
      const SizedBox(height: 8),
      const Text(
        'Pago de prueba: no se cobra plata de verdad.',
        style: TextStyle(fontSize: 11, color: grisTexto),
      ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: _pagar,
        icon: const Icon(Icons.lock_outline),
        label: Text('Pagar ${pesos(_total)}'),
      ),
    ],
  );

  Widget _linea(String texto, String valor, {Color? color}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(texto, style: TextStyle(fontSize: 13, color: color)),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 13,
            fontWeight: color == null ? FontWeight.normal : FontWeight.bold,
            color: color,
          ),
        ),
      ],
    ),
  );
}
