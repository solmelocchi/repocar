import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/taller.dart';
import '../../core/aviso.dart';
import '../../core/colores.dart';
import '../../core/formato.dart';

/// Lo que paga un taller hoy, en una línea: "10%" o "Sin comisión hasta
/// el 24/02/2027 (después, 10%)".
String textoDeComision(Taller taller) {
  final porcentaje = '${(taller.comision * 100).round()}%';
  final hasta = taller.sinComisionHasta;
  if (hasta != null && taller.enPromocion(DateTime.now())) {
    return 'Sin comisión hasta el ${fechaCorta(hasta)} (después, $porcentaje)';
  }
  return 'Comisión $porcentaje';
}

/// En el panel, arriba de los pedidos de un taller: su comisión y el
/// botón para cambiarla.
class ComisionDelTaller extends StatelessWidget {
  const ComisionDelTaller({
    super.key,
    required this.deps,
    required this.taller,
  });

  final Dependencias deps;
  final Taller taller;

  Future<void> _cambiar(BuildContext context) async {
    final eleccion = await showDialog<(double, bool)>(
      context: context,
      builder: (_) => _DialogoComision(taller: taller),
    );
    if (eleccion == null || !context.mounted) return;
    final guardo = await deps.comisiones.cambiar(
      taller,
      porcentaje: eleccion.$1,
      promocion: eleccion.$2,
    );
    if (!context.mounted) return;
    avisar(
      context,
      guardo
          ? 'Listo: vale para los pedidos que vienen'
          : deps.comisiones.error ?? 'No se pudo guardar',
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deps.comisiones,
      // El texto arriba y el botón abajo: el botón ocupa todo el ancho
      // (así son en esta app) y al costado no le dejaba lugar al texto.
      builder: (context, _) => Card(
        color: azulClaro,
        margin: const EdgeInsets.only(bottom: 12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.percent, color: azul),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          textoDeComision(taller),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const Text(
                          'Los pedidos que ya se hicieron conservan la suya.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: deps.comisiones.guardando
                    ? null
                    : () => _cambiar(context),
                child: const Text('Cambiar la comisión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// El cartel para elegir el porcentaje y la promoción.
class _DialogoComision extends StatefulWidget {
  const _DialogoComision({required this.taller});

  final Taller taller;

  @override
  State<_DialogoComision> createState() => _DialogoComisionState();
}

class _DialogoComisionState extends State<_DialogoComision> {
  late final _porcentaje = TextEditingController(
    text: '${(widget.taller.comision * 100).round()}',
  );
  late bool _promocion = widget.taller.enPromocion(DateTime.now());
  String? _error;

  @override
  void dispose() {
    _porcentaje.dispose();
    super.dispose();
  }

  void _aceptar() {
    final numero = int.tryParse(_porcentaje.text.trim());
    if (numero == null || numero < 0 || numero > 30) {
      setState(() => _error = 'Poné un número entre 0 y 30');
      return;
    }
    Navigator.pop(context, (numero / 100, _promocion));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Comisión de ${widget.taller.nombre}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _porcentaje,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Porcentaje',
              suffixText: '%',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _promocion,
            onChanged: (valor) => setState(() => _promocion = valor),
            title: const Text('Primeros 3 meses sin comisión'),
            subtitle: const Text(
              'Termina sola: después se cobra el porcentaje de arriba.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _aceptar,
          style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
