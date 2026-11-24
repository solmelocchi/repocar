import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/pieza.dart';
import '../../../domain/models/pregunta.dart';
import '../../core/aviso.dart';
import '../../core/colores.dart';
import '../../core/estado_carga.dart';
import '../view_models/preguntas_view_model.dart';

/// "Preguntas y respuestas" en la ficha de una publicación. El comprador
/// pregunta; el taller dueño responde. Las ven todos.
class PreguntasDePieza extends StatefulWidget {
  const PreguntasDePieza({
    super.key,
    required this.deps,
    required this.pieza,
    required this.esDelTaller,
    this.sugerencia,
  });

  final Dependencias deps;
  final Pieza pieza;
  final bool esDelTaller;

  /// Un ejemplo de pregunta (por ejemplo, con el auto que eligió).
  final String? sugerencia;

  @override
  State<PreguntasDePieza> createState() => _PreguntasDePiezaState();
}

class _PreguntasDePiezaState extends State<PreguntasDePieza> {
  /// Uno por ficha: nace con la pantalla y se da de baja con ella.
  late final PreguntasViewModel _vm = widget.deps.nuevasPreguntas(widget.pieza);
  final _texto = TextEditingController();

  @override
  void initState() {
    super.initState();
    _vm.iniciar();
  }

  @override
  void dispose() {
    _vm.dispose();
    _texto.dispose();
    super.dispose();
  }

  Future<void> _preguntar() async {
    final salio = await _vm.preguntar(_texto.text);
    if (!salio || !mounted) return;
    _texto.clear();
    FocusScope.of(context).unfocus();
    avisar(context, 'Le mandamos tu pregunta al taller');
  }

  Future<void> _responder(Pregunta pregunta) async {
    final texto = await pedirRespuesta(context, pregunta);
    if (texto == null || !mounted) return;
    final error = await _vm.responder(pregunta, texto);
    if (!mounted) return;
    avisar(context, error ?? 'Respuesta publicada');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _vm,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 24),
            const Text(
              'Preguntas y respuestas',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text(
              'Las preguntas y las respuestas las ven todos.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            if (!widget.esDelTaller && _vm.puedePreguntar) ...[
              TextField(
                controller: _texto,
                maxLength: 300,
                minLines: 1,
                maxLines: 3,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _preguntar(),
                decoration: InputDecoration(
                  hintText:
                      widget.sugerencia ??
                      '¿Le sirve a mi auto? ¿Está probada?',
                  errorText: _vm.error,
                  border: const OutlineInputBorder(),
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _vm.enviando ? null : _preguntar,
                  icon: const Icon(Icons.send, size: 18),
                  label: Text(_vm.enviando ? 'Enviando...' : 'Preguntar'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            ...switch (_vm.estado) {
              EstadoCarga.cargando => [const LinearProgressIndicator()],
              EstadoCarga.error => [
                const Text('No se pudieron traer las preguntas.'),
              ],
              EstadoCarga.exito when _vm.preguntas.isEmpty => [
                Text(
                  widget.esDelTaller
                      ? 'Todavía no te hicieron preguntas.'
                      : 'Todavía nadie preguntó.',
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
              EstadoCarga.exito => [
                for (final pregunta in _vm.preguntas)
                  TarjetaPregunta(
                    pregunta: pregunta,
                    alResponder: widget.esDelTaller && !pregunta.respondida
                        ? () => _responder(pregunta)
                        : null,
                  ),
              ],
            },
          ],
        ),
      ),
    );
  }
}

/// Una pregunta con su respuesta (o el botón para responderla).
class TarjetaPregunta extends StatelessWidget {
  const TarjetaPregunta({
    super.key,
    required this.pregunta,
    this.alResponder,
    this.mostrarPieza = false,
  });

  final Pregunta pregunta;
  final VoidCallback? alResponder;

  /// En la lista del taller: de qué publicación es.
  final bool mostrarPieza;

  @override
  Widget build(BuildContext context) {
    final respuesta = pregunta.respuesta;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (mostrarPieza)
            Text(
              pregunta.piezaTitulo,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: azul,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.help_outline, size: 18, color: azul),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  pregunta.texto,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          Text(
            '${pregunta.autor} · ${hace(pregunta.fecha)}',
            style: const TextStyle(fontSize: 12, color: Colors.black45),
          ),
          const SizedBox(height: 8),
          if (respuesta != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: azulClaro,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.subdirectory_arrow_right, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(respuesta)),
                ],
              ),
            )
          else if (alResponder != null)
            OutlinedButton.icon(
              onPressed: alResponder,
              icon: const Icon(Icons.reply, size: 18),
              label: const Text('Responder'),
            )
          else
            const Text(
              'Todavía sin respuesta del taller.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.black54,
              ),
            ),
        ],
      ),
    );
  }
}

/// "hoy", "ayer", "hace 3 días".
String hace(DateTime fecha) {
  final dias = DateTime.now().difference(fecha).inDays;
  if (dias <= 0) return 'hoy';
  if (dias == 1) return 'ayer';
  return 'hace $dias días';
}

/// El cartel para que el taller escriba la respuesta. Devuelve el texto,
/// o null si canceló.
Future<String?> pedirRespuesta(BuildContext context, Pregunta pregunta) {
  final texto = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('Responder'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '"${pregunta.texto}"',
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: texto,
            autofocus: true,
            maxLength: 300,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Tu respuesta',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogo),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogo, texto.text),
          child: const Text('Responder'),
        ),
      ],
    ),
  ).whenComplete(texto.dispose);
}
