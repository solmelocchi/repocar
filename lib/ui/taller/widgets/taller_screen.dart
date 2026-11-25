import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/pieza.dart';
import '../../../domain/models/taller.dart';
import '../../core/colores.dart';
import '../../core/estado_carga.dart';
import '../../core/formato.dart';
import '../../catalogo/widgets/detalle_screen.dart';
import '../../catalogo/widgets/foto_pieza.dart';
import '../../core/vistas_de_carga.dart';
import '../../cuenta/widgets/cuenta_screen.dart';
import '../../notificaciones/widgets/activar_avisos.dart';
import '../../notificaciones/widgets/boton_notificaciones.dart';
import '../../pedidos/widgets/pedidos_filtrables.dart';
import '../../preguntas/widgets/preguntas_pendientes.dart';
import 'publicar_screen.dart';
import 'tarjeta_pedido_taller.dart';

/// La vista del taller que entró con su CUIT: sus publicaciones y los
/// pedidos que recibió.
class TallerScreen extends StatefulWidget {
  final Dependencias deps;

  const TallerScreen({super.key, required this.deps});

  @override
  State<TallerScreen> createState() => _TallerScreenState();
}

class _TallerScreenState extends State<TallerScreen> {
  int _pestana = 0;

  @override
  void initState() {
    super.initState();
    // Se carga DESPUÉS del primer dibujo: cargar() avisa "cargando" al
    // instante, y si en ese momento se está cerrando otra pantalla que
    // escucha al mismo ViewModel (al cambiar de cuenta), avisar en pleno
    // dibujo es un error de Flutter ("setState() called during build").
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.deps.catalogo.cargar();
      widget.deps.pedidos.cargar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final taller = widget.deps.sesion.taller;
    if (taller == null) {
      return const Scaffold(body: VistaCargando());
    }

    final titulos = ['Mis publicaciones', 'Pedidos recibidos', 'Mi cuenta'];

    // La barra de abajo, como cualquier app: Publicaciones, Pedidos y
    // Cuenta. La pestaña Cuenta trae su propia barra de arriba.
    return Scaffold(
      appBar: _pestana == 2
          ? null
          : AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulos[_pestana], style: const TextStyle(fontSize: 18)),
                  Text(
                    taller.nombre,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
              actions: [
                BotonNotificaciones(deps: widget.deps, para: taller.cuit),
                const SizedBox(width: 4),
              ],
            ),
      body: IndexedStack(
        index: _pestana,
        children: [
          _publicaciones(taller),
          _pedidos(taller),
          CuentaScreen(deps: widget.deps),
        ],
      ),
      floatingActionButton: _pestana == 0
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PublicarScreen(deps: widget.deps),
                ),
              ),
              // Ámbar y no naranja: con letra blanca, el naranja daba
              // un contraste de 2,8 (el mínimo es 4,5).
              backgroundColor: ambar,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Publicar'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _pestana,
        onDestinationSelected: (i) => setState(() => _pestana = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Publicaciones',
          ),
          NavigationDestination(
            // El numerito: los pedidos pagados que todavía no despachó.
            icon: ListenableBuilder(
              listenable: widget.deps.pedidos,
              builder: (context, _) {
                final pendientes = widget.deps.pedidos
                    .deTaller(taller)
                    .where((p) => p.estado == EstadoPedido.pagado)
                    .length;
                return Badge(
                  label: Text('$pendientes'),
                  isLabelVisible: pendientes > 0,
                  child: const Icon(Icons.receipt_long_outlined),
                );
              },
            ),
            selectedIcon: const Icon(Icons.receipt_long),
            label: 'Pedidos',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }

  Widget _publicaciones(Taller taller) {
    final vm = widget.deps.catalogo;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.estado == EstadoCarga.cargando) return const VistaCargando();
        if (vm.estado == EstadoCarga.error) {
          return VistaError(alReintentar: vm.cargar);
        }

        final misPiezas = vm.deTaller(taller);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: const Color(0xFFDDF1E6),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: verde),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Taller registrado · CUIT válido',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: verde,
                            ),
                          ),
                          Text(
                            'CUIT ${taller.cuit} · comisión '
                            '${(taller.comision * 100).round()}% · '
                            'guardado en ${widget.deps.almacen.nombre}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: grisTexto,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (misPiezas.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Todavía no publicaste ningún repuesto.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: grisTexto),
                ),
              ),
            for (final pieza in misPiezas)
              Card(
                child: ListTile(
                  leading: FotoPieza(
                    pieza: pieza,
                    ancho: 44,
                    alto: 44,
                    radio: 6,
                    tamanoIcono: 22,
                  ),
                  title: Text(pieza.titulo),
                  subtitle: Text(
                    pieza.vendida
                        ? '${pesos(pieza.precio)} · Vendida'
                        : pieza.pausada
                        ? '${pesos(pieza.precio)} · Pausada'
                        : '${pesos(pieza.precio)} · ${pieza.estado.texto}',
                  ),
                  // Tocar la tarjeta: la ficha, como la ve el comprador.
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          DetalleScreen(pieza: pieza, deps: widget.deps),
                    ),
                  ),
                  // El lápiz: editar. Lo vendido ya no se edita.
                  trailing: pieza.vendida
                      ? const Icon(Icons.check_circle, color: verde, size: 20)
                      : IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PublicarScreen(
                                deps: widget.deps,
                                pieza: pieza,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            // Lugar para que el botón flotante no tape la última.
            const SizedBox(height: 72),
          ],
        );
      },
    );
  }

  Widget _pedidos(Taller taller) {
    final vm = widget.deps.pedidos;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (vm.estado == EstadoCarga.cargando) return const VistaCargando();
        if (vm.estado == EstadoCarga.error) {
          return VistaError(alReintentar: vm.cargar);
        }

        final mios = vm.deTaller(taller);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ActivarAvisos(
              deps: widget.deps,
              beneficio:
                  'Activá los avisos para enterarte de cada pedido nuevo '
                  'aunque no estés mirando la app.',
            ),
            PreguntasPendientes(deps: widget.deps),
            PedidosFiltrables(
              pedidos: mios,
              vacio: 'Todavía no te hicieron ningún pedido.',
              construir: (pedido) =>
                  TarjetaPedidoTaller(pedido: pedido, deps: widget.deps),
            ),
          ],
        );
      },
    );
  }
}
