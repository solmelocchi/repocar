import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../core/colores.dart';

/// El cartel que pide el permiso de notificaciones EN CONTEXTO: dice qué
/// gana el usuario y pide recién cuando toca el botón. Nunca al abrir la
/// app (en iOS el cuadro aparece una sola vez, y en la web el navegador
/// lo bloquea si no viene de un toque).
///
/// Si ya dio permiso, o el aparato no puede notificar, no se dibuja.
class ActivarAvisos extends StatelessWidget {
  final Dependencias deps;

  /// Lo que gana, dicho para este usuario ("enterarte de un pedido…").
  final String beneficio;

  const ActivarAvisos({super.key, required this.deps, required this.beneficio});

  @override
  Widget build(BuildContext context) {
    final vm = deps.notificaciones;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (!vm.puedeNotificar || vm.tienePermiso) {
          return const SizedBox.shrink();
        }

        return Card(
          color: azulClaro,
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(Icons.notifications_active_outlined, color: azul),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(beneficio, style: const TextStyle(fontSize: 13)),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: vm.pedirPermiso,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(90, 40),
                  ),
                  child: const Text('Activar'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
