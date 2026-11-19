import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/auto.dart';
import '../../core/colores.dart';
import '../../core/estado_carga.dart';
import '../../core/iconos.dart';
import '../../core/vistas_de_carga.dart';
import '../../notificaciones/widgets/boton_notificaciones.dart';
import 'elegir_auto_hoja.dart';
import 'tarjeta_producto.dart';

/// La pestaña Inicio del comprador: el buscador azul de RepoCar arriba y
/// el catálogo en grilla abajo.
///
/// El buscador FILTRA en el momento, y los filtros se suman: tu auto
/// (marca, modelo y año), lo que escribís y el rubro.
class HomeScreen extends StatefulWidget {
  final Dependencias deps;

  const HomeScreen({super.key, required this.deps});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _texto = TextEditingController();

  /// Los filtros elegidos. Qué piezas pasan lo decide el view model
  /// (filtrar): la pantalla solo guarda qué tocó el usuario.
  String? _rubro;
  Auto? _auto;

  @override
  void initState() {
    super.initState();
    // Cuando el catálogo cargó, vuelve el carrito de la otra vez (se busca
    // cada pieza por su id).
    widget.deps.catalogo.cargar().then((_) {
      if (mounted) {
        widget.deps.carrito.restaurar(widget.deps.catalogo.buscarPorId);
      }
    });
    // Cada letra que escribe vuelve a filtrar.
    _texto.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  bool get _hayFiltros =>
      _texto.text.isNotEmpty || _rubro != null || _auto != null;

  void _limpiar() => setState(() {
    _texto.clear();
    _rubro = null;
    _auto = null;
  });

  Future<void> _elegirAuto() async {
    final elegido = await elegirAuto(context, widget.deps, _auto);
    if (elegido != null && mounted) setState(() => _auto = elegido);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.deps.catalogo;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RepoCar',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: -0.5),
        ),
        actions: [
          BotonNotificaciones(
            deps: widget.deps,
            para: widget.deps.sesion.nombreComprador,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: vm.cargar,
        // CustomScrollView con "slivers": la parte de arriba es una lista
        // común y la grilla es un SliverGrid, que arma SOLO las tarjetas
        // que se ven (y las que están por aparecer). Antes la grilla iba
        // adentro de un ListView con shrinkWrap y armaba todas a la vez:
        // volver atrás desde una ficha tardaba en el celular.
        child: ListenableBuilder(
          // Escucha al view model: lo que publica un taller aparece solo.
          listenable: vm,
          builder: (context, _) => CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverList.list(
                  children: [
                    _buscador(),
                    const SizedBox(height: 12),
                    _rubros(),
                    const SizedBox(height: 8),
                    if (vm.estado == EstadoCarga.cargando)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: VistaCargando(
                          mensaje: 'Trayendo el catálogo...',
                        ),
                      ),
                    if (vm.estado == EstadoCarga.error)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: VistaError(alReintentar: vm.cargar),
                      ),
                  ],
                ),
              ),
              if (vm.estado == EstadoCarga.exito) ..._resultados(),
            ],
          ),
        ),
      ),
    );
  }

  /// La caja azul de siempre, ahora con los dos buscadores adentro: el
  /// del auto (abre la hoja de marca, modelo y año) y el de texto.
  Widget _buscador() {
    final auto = _auto;

    return Card(
      color: azul,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.car_repair, color: naranja),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '¿Qué auto tenés?',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Elegí marca, modelo y año, y te mostramos solo los '
              'repuestos que le sirven.',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
            const SizedBox(height: 14),

            // 1. El auto: se elige de la lista, nunca a mano.
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: _elegirAuto,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        color: auto == null ? Colors.black45 : azul,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          auto == null
                              ? 'Buscar por marca, modelo y año'
                              : '$auto',
                          style: TextStyle(
                            fontSize: 14,
                            color: auto == null
                                ? Colors.black54
                                : Colors.black87,
                            fontWeight: auto == null
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (auto != null)
                        InkWell(
                          onTap: () => setState(() => _auto = null),
                          child: const Icon(
                            Icons.close,
                            size: 20,
                            color: Colors.black45,
                          ),
                        )
                      else
                        const Icon(Icons.expand_more, color: Colors.black45),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 2. El texto: filtra mientras escribís.
            TextField(
              controller: _texto,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: '¿Qué repuesto buscás? (ej: alternador)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _texto.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar',
                        icon: const Icon(Icons.close),
                        onPressed: _texto.clear,
                      ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Los rubros, para filtrar con un toque.
  Widget _rubros() => SizedBox(
    height: 40,
    child: ListView(
      scrollDirection: Axis.horizontal,
      children: [
        for (final rubro in nombresDeRubros.entries) ...[
          FilterChip(
            avatar: Icon(iconoDe(rubro.key), size: 18),
            label: Text(rubro.value),
            selected: _rubro == rubro.key,
            showCheckmark: false,
            onSelected: (si) => setState(() => _rubro = si ? rubro.key : null),
          ),
          const SizedBox(width: 8),
        ],
      ],
    ),
  );

  /// El título y la grilla, como slivers (piezas de un CustomScrollView).
  List<Widget> _resultados() {
    final piezas = widget.deps.catalogo.filtrar(
      texto: _texto.text,
      rubro: _rubro,
      auto: _auto,
    );

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _hayFiltros
                      ? '${piezas.length} '
                            '${piezas.length == 1 ? 'resultado' : 'resultados'}'
                      : 'Último en el catálogo',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_hayFiltros)
                TextButton(
                  onPressed: _limpiar,
                  child: const Text('Limpiar filtros'),
                ),
            ],
          ),
        ),
      ),
      if (piezas.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.search_off, size: 52, color: Colors.black26),
                  SizedBox(height: 10),
                  Text(
                    'No hay repuestos con esos filtros.\nProbá sacando '
                    'alguno.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          sliver: SliverGrid.builder(
            itemCount: piezas.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              // Alto fijo: así la tarjeta no se corta si el título ocupa
              // dos renglones o la letra del teléfono está agrandada.
              mainAxisExtent: 300,
            ),
            itemBuilder: (context, i) => TarjetaProducto(
              pieza: piezas[i],
              auto: _auto,
              deps: widget.deps,
            ),
          ),
        ),
    ];
  }
}
