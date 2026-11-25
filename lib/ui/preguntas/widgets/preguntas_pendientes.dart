import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/pregunta.dart';
import '../../core/aviso.dart';
import 'preguntas_de_pieza.dart';
import '../../core/colores.dart';

/// En la pantalla del taller: las preguntas que todavía no respondió.
/// Si no hay ninguna, no se dibuja nada.
class PreguntasPendientes extends StatelessWidget {
  const PreguntasPendientes({super.key, required this.deps});

  final Dependencias deps;

  Future<void> _responder(BuildContext context, Pregunta pregunta) async {
    final texto = await pedirRespuesta(context, pregunta);
    if (texto == null || !context.mounted) return;
    final error = await deps.misPreguntas.responder(pregunta, texto);
    if (!context.mounted) return;
    avisar(context, error ?? 'Respuesta publicada');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deps.misPreguntas,
      builder: (context, _) {
        final pendientes = deps.misPreguntas.sinResponder;
        if (pendientes.isEmpty) return const SizedBox.shrink();
        final cuantas = pendientes.length;
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tenés $cuantas ${cuantas == 1 ? 'pregunta' : 'preguntas'} '
                  'sin responder',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Contestá rápido: una pregunta sin respuesta es una venta '
                  'que se puede perder.',
                  style: TextStyle(fontSize: 12, color: grisTexto),
                ),
                const SizedBox(height: 10),
                for (final pregunta in pendientes)
                  TarjetaPregunta(
                    pregunta: pregunta,
                    mostrarPieza: true,
                    alResponder: () => _responder(context, pregunta),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
