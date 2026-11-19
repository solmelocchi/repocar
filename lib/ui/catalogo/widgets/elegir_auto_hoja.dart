import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/auto.dart';
import '../../core/estado_carga.dart';

/// La hoja que sube desde abajo para elegir el auto: marca, modelo y
/// año, siempre de la lista (nunca escrito a mano). Devuelve el auto
/// elegido, o null si la cerró sin elegir.
Future<Auto?> elegirAuto(
  BuildContext context,
  Dependencias deps,
  Auto? actual,
) {
  return showModalBottomSheet<Auto>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _HojaAuto(deps: deps, actual: actual),
  );
}

class _HojaAuto extends StatefulWidget {
  final Dependencias deps;
  final Auto? actual;

  const _HojaAuto({required this.deps, this.actual});

  @override
  State<_HojaAuto> createState() => _HojaAutoState();
}

class _HojaAutoState extends State<_HojaAuto> {
  late String? _marca = widget.actual?.marca;
  late String? _modelo = widget.actual?.modelo;
  late int? _anio = widget.actual?.anio;

  @override
  void initState() {
    super.initState();
    widget.deps.vehiculos.cargar();
  }

  List<int> get _anios => (_marca == null || _modelo == null)
      ? []
      : widget.deps.vehiculos.aniosDe(_marca!, _modelo!);

  @override
  Widget build(BuildContext context) {
    final vm = widget.deps.vehiculos;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          if (vm.estado == EstadoCarga.cargando) {
            return const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Qué auto tenés?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Te mostramos solo los repuestos que le sirven.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey('marca-$_marca'),
                initialValue: _marca,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final marca in vm.marcas)
                    DropdownMenuItem(value: marca, child: Text(marca)),
                ],
                onChanged: (valor) => setState(() {
                  _marca = valor;
                  _modelo = null;
                  _anio = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('modelo-$_marca-$_modelo'),
                initialValue: _modelo,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  border: OutlineInputBorder(),
                ),
                items: _marca == null
                    ? []
                    : [
                        for (final v in vm.modelosDe(_marca!))
                          DropdownMenuItem(
                            value: v.modelo,
                            child: Text(v.modelo),
                          ),
                      ],
                onChanged: (valor) => setState(() {
                  _modelo = valor;
                  _anio = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey('anio-$_modelo-$_anio'),
                initialValue: _anios.contains(_anio) ? _anio : null,
                decoration: const InputDecoration(
                  labelText: 'Año',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final anio in _anios)
                    DropdownMenuItem(value: anio, child: Text('$anio')),
                ],
                onChanged: (valor) => setState(() => _anio = valor),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: (_marca == null || _modelo == null || _anio == null)
                    ? null
                    : () => Navigator.pop(
                        context,
                        Auto(marca: _marca!, modelo: _modelo!, anio: _anio!),
                      ),
                child: const Text('Ver repuestos para este auto'),
              ),
            ],
          );
        },
      ),
    );
  }
}
