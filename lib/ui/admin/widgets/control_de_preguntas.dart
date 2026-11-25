import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../core/colores.dart';
import '../../preguntas/widgets/preguntas_de_pieza.dart';

/// En el panel de TalleresYa: las preguntas y respuestas de todos los
/// talleres, y las publicaciones para revisar.
class ControlDePreguntas extends StatelessWidget {
  const ControlDePreguntas({super.key, required this.deps});

  final Dependencias deps;

  @override
  Widget build(BuildContext context) {
    final vm = deps.controlDePreguntas;
    return ListenableBuilder(
      // Se redibuja si llega una pregunta nueva o si cambia una pieza.
      listenable: Listenable.merge([vm, deps.catalogo]),
      builder: (context, _) {
        final paraRevisar = vm.paraRevisar;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            const Text(
              'Preguntas y respuestas',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text(
              'Para controlar que las consultas, y las ventas, queden en '
              'RepoCar.',
              style: TextStyle(fontSize: 12, color: grisTexto),
            ),
            const SizedBox(height: 10),
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.forum_outlined, color: azul),
                title: Text('${vm.todas.length} preguntas'),
                subtitle: Text('${vm.sinResponder} sin responder'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _TodasLasPreguntas(deps: deps),
                  ),
                ),
              ),
            ),
            if (paraRevisar.isEmpty)
              const Text(
                'Nada para revisar: ninguna publicación con preguntas se '
                'sacó sin venderse.',
                style: TextStyle(fontSize: 13, color: grisTexto),
              )
            else ...[
              const Text(
                'Para revisar',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const Text(
                'Tuvieron preguntas y no se vendieron por la app. Puede ser '
                'normal, o una venta por fuera.',
                style: TextStyle(fontSize: 12, color: grisTexto),
              ),
              const SizedBox(height: 6),
              for (final senal in paraRevisar)
                Card(
                  color: const Color(0xFFFFF3E0),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const Icon(Icons.warning_amber, color: ambar),
                    title: Text(senal.pieza.titulo),
                    subtitle: Text(
                      '${senal.pieza.taller.nombre} · ${senal.preguntas} '
                      '${senal.preguntas == 1 ? 'pregunta' : 'preguntas'}, y '
                      '${senal.motivo}',
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Todas las preguntas, de todos los talleres, la más nueva primero.
class _TodasLasPreguntas extends StatelessWidget {
  const _TodasLasPreguntas({required this.deps});

  final Dependencias deps;

  @override
  Widget build(BuildContext context) {
    final vm = deps.controlDePreguntas;
    return Scaffold(
      appBar: AppBar(title: const Text('Todas las preguntas')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) => vm.todas.isEmpty
            ? const Center(child: Text('Todavía no hay preguntas.'))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final pregunta in vm.todas)
                    TarjetaPregunta(pregunta: pregunta, mostrarPieza: true),
                ],
              ),
      ),
    );
  }
}
