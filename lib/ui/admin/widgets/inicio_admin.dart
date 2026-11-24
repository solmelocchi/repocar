import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/taller.dart';
import '../../core/colores.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';
import '../../core/vistas_de_carga.dart';
import '../../cuenta/widgets/cuenta_screen.dart';
import '../../pedidos/widgets/detalle_pedido_screen.dart';
import 'control_de_preguntas.dart';

/// El panel de TalleresYa (el que pidió el cliente): cuánto vendió cada
/// taller y cuánta comisión le toca cobrar. Solo lo ve la cuenta de
/// administración. Es del celular; si el cliente lo quiere también en la
/// computadora, es la misma pantalla en la versión web.
class InicioAdmin extends StatefulWidget {
  final Dependencias deps;

  const InicioAdmin({super.key, required this.deps});

  @override
  State<InicioAdmin> createState() => _InicioAdminState();
}

class _InicioAdminState extends State<InicioAdmin> {
  int _pestana = 0;

  @override
  void initState() {
    super.initState();
    widget.deps.pedidos.cargar();
    // Para el control de preguntas: las piezas (también las pausadas y
    // borradas) y todas las preguntas.
    widget.deps.catalogo.cargar();
    widget.deps.controlDePreguntas.iniciar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _pestana,
        children: [
          _Resumen(deps: widget.deps),
          _TodosLosPedidos(deps: widget.deps),
          CuentaScreen(deps: widget.deps),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Resumen',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}

/// La pestaña Resumen: los números del mes y la tabla por taller.
class _Resumen extends StatelessWidget {
  final Dependencias deps;

  const _Resumen({required this.deps});

  @override
  Widget build(BuildContext context) {
    final vm = deps.pedidos;

    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TalleresYa', style: TextStyle(fontSize: 18)),
            Text(
              'Últimos 30 días',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        // Los pedidos llegan del servidor por un Stream: si un comprador
        // compra ahora, el número sube solo.
        listenable: vm,
        builder: (context, _) {
          if (vm.estado == EstadoCarga.cargando) return const VistaCargando();
          if (vm.estado == EstadoCarga.error) {
            return VistaError(alReintentar: vm.cargar);
          }

          final porTaller = vm.ventasPorTaller(deps.sesion.talleres);
          return RefreshIndicator(
            onRefresh: vm.cargar,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Numero(
                  titulo: 'Comisión a cobrar',
                  valor: pesos(vm.comisionDelMes),
                  icono: Icons.savings_outlined,
                  destacado: true,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _Numero(
                        titulo: 'Vendido',
                        valor: pesos(vm.vendidoDelMes),
                        icono: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _Numero(
                        titulo: 'Pedidos',
                        valor: '${vm.pedidosDelMes}',
                        icono: Icons.receipt_long_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const Text(
                  'Por taller',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Del que más vendió al que menos. Tocá uno para ver sus '
                  'pedidos.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                for (final fila in porTaller)
                  Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: azulClaro,
                        child: Text(
                          '${fila.ventas}',
                          style: const TextStyle(
                            color: azul,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        fila.taller.nombre,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        'Vendió ${pesos(fila.vendido)} · comisión '
                        '${(fila.taller.comision * 100).round()}%',
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        pesos(fila.comision),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: verde,
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _PedidosDeTaller(deps: deps, taller: fila.taller),
                        ),
                      ),
                    ),
                  ),
                ControlDePreguntas(deps: deps),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Numero extends StatelessWidget {
  final String titulo;
  final String valor;
  final IconData icono;
  final bool destacado;

  const _Numero({
    required this.titulo,
    required this.valor,
    required this.icono,
    this.destacado = false,
  });

  @override
  Widget build(BuildContext context) {
    final texto = destacado ? Colors.white : Colors.black87;
    return Card(
      margin: EdgeInsets.zero,
      color: destacado ? azul : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, size: 18, color: destacado ? naranja : azul),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 13,
                      color: destacado ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                valor,
                style: TextStyle(
                  fontSize: destacado ? 28 : 20,
                  fontWeight: FontWeight.bold,
                  color: texto,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Los pedidos de un taller, con lo que se lleva cada parte.
class _PedidosDeTaller extends StatelessWidget {
  final Dependencias deps;
  final Taller taller;

  const _PedidosDeTaller({required this.deps, required this.taller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(taller.nombre)),
      body: ListenableBuilder(
        listenable: deps.pedidos,
        builder: (context, _) {
          final pedidos = deps.pedidos.deTaller(taller);
          if (pedidos.isEmpty) {
            return const Center(child: Text('Este taller no tiene pedidos.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final pedido in pedidos)
                _FilaPedido(deps: deps, pedido: pedido),
            ],
          );
        },
      ),
    );
  }
}

/// La pestaña Pedidos: todos los de la red, del más nuevo al más viejo.
class _TodosLosPedidos extends StatelessWidget {
  final Dependencias deps;

  const _TodosLosPedidos({required this.deps});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Todos los pedidos')),
      body: ListenableBuilder(
        listenable: deps.pedidos,
        builder: (context, _) {
          final pedidos = [...deps.pedidos.todos]
            ..sort((a, b) => b.fecha.compareTo(a.fecha));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final pedido in pedidos)
                _FilaPedido(deps: deps, pedido: pedido, conTaller: true),
            ],
          );
        },
      ),
    );
  }
}

class _FilaPedido extends StatelessWidget {
  final Dependencias deps;
  final Pedido pedido;
  final bool conTaller;

  const _FilaPedido({
    required this.deps,
    required this.pedido,
    this.conTaller = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text(
          '${pedido.numero} · ${pedido.cliente}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '${conTaller ? '${pedido.taller.nombre}\n' : ''}'
          '${pedido.fecha.day}/${pedido.fecha.month} · ${pedido.estado.texto}'
          ' · total ${pesos(pedido.total)}',
          style: const TextStyle(fontSize: 12),
        ),
        isThreeLine: conTaller,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              pesos(pedido.comision),
              style: const TextStyle(fontWeight: FontWeight.bold, color: verde),
            ),
            const Text(
              'comisión',
              style: TextStyle(fontSize: 10, color: Colors.black45),
            ),
          ],
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetallePedidoScreen(
              pedido: pedido,
              deps: deps,
              comoAdmin: true,
            ),
          ),
        ),
      ),
    );
  }
}
