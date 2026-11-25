import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/auto.dart';
import '../../catalogo/widgets/resultados_screen.dart';
import '../../core/estado_carga.dart';
import '../../core/vistas_de_carga.dart';
import '../../core/colores.dart';

/// Elegir el auto. Los tres desplegables salen de la lista de vehículos
/// que trae el view model: nadie escribe el modelo a mano, y por eso la
/// búsqueda funciona.
///
/// Esta pantalla es la que mejor muestra los tres estados del Future:
/// mientras la lista no llega hay un indicador, si falla hay un cartel
/// con Reintentar, y recién con los datos se dibuja el formulario.
class BuscarAutoScreen extends StatefulWidget {
  final Dependencias deps;

  const BuscarAutoScreen({super.key, required this.deps});

  @override
  State<BuscarAutoScreen> createState() => _BuscarAutoScreenState();
}

class _BuscarAutoScreenState extends State<BuscarAutoScreen> {
  String? marca;
  String? modelo;
  int? anio;

  @override
  void initState() {
    super.initState();
    // El comando del view model se dispara al entrar a la pantalla.
    widget.deps.vehiculos.cargar();
  }

  bool get completo => marca != null && modelo != null && anio != null;

  @override
  Widget build(BuildContext context) {
    final vm = widget.deps.vehiculos;

    return Scaffold(
      appBar: AppBar(title: const Text('¿Qué auto tenés?')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => switch (vm.estado) {
          EstadoCarga.cargando => const VistaCargando(
            mensaje: 'Buscando los modelos...',
          ),
          EstadoCarga.error => VistaError(
            mensaje: 'No pudimos traer la lista de autos.',
            alReintentar: vm.cargar,
          ),
          EstadoCarga.exito => _formulario(),
        },
      ),
    );
  }

  Widget _formulario() {
    final vm = widget.deps.vehiculos;

    // Se puede desplazar: con la letra grande no entra en la pantalla.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Elegí tu vehículo y te mostramos solo los repuestos que le '
            'sirven.',
            style: TextStyle(fontSize: 15, color: grisTexto),
          ),
          const SizedBox(height: 24),

          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: marca,
            decoration: const InputDecoration(
              labelText: 'Marca',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.directions_car),
            ),
            items: [
              for (final m in vm.marcas)
                DropdownMenuItem(value: m, child: Text(m)),
            ],
            onChanged: (valor) => setState(() {
              marca = valor;
              modelo = null; // al cambiar la marca se reinicia lo de abajo
              anio = null;
            }),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: modelo,
            decoration: const InputDecoration(
              labelText: 'Modelo',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.commit),
            ),
            items: marca == null
                ? []
                : [
                    for (final v in vm.modelosDe(marca!))
                      DropdownMenuItem(value: v.modelo, child: Text(v.modelo)),
                  ],
            onChanged: (valor) => setState(() {
              modelo = valor;
              anio = null;
            }),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: anio,
            decoration: const InputDecoration(
              labelText: 'Año',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.calendar_today),
            ),
            items: [
              for (final a in _anios)
                DropdownMenuItem(value: a, child: Text('$a')),
            ],
            onChanged: (valor) => setState(() => anio = valor),
          ),
          const SizedBox(height: 28),

          FilledButton.icon(
            // Si falta algo, el botón queda apagado.
            onPressed: completo ? _buscar : null,
            icon: const Icon(Icons.search),
            label: const Text('Buscar repuestos'),
          ),
          const SizedBox(height: 24),

          if (!completo)
            const Card(
              color: Color(0xFFF3F5F9),
              elevation: 0,
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: grisTexto),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Probá con Volkswagen · Gol Trend · 2014',
                        style: TextStyle(fontSize: 13, color: grisTexto),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<int> get _anios {
    if (marca == null || modelo == null) return [];
    return widget.deps.vehiculos.aniosDe(marca!, modelo!);
  }

  void _buscar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultadosScreen(
          auto: Auto(marca: marca!, modelo: modelo!, anio: anio!),
          deps: widget.deps,
        ),
      ),
    );
  }
}
