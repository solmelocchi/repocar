import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../core/colores.dart';
import 'activar_avisos.dart';

/// La bandeja de avisos.
class NotificacionesScreen extends StatefulWidget {
  final Dependencias deps;
  final String para;

  const NotificacionesScreen({
    super.key,
    required this.deps,
    required this.para,
  });

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  @override
  void initState() {
    super.initState();
    // Entrar a la bandeja es leerlos.
    widget.deps.notificaciones.marcarLeidas(widget.para);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.deps.notificaciones;

    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          final avisos = vm.para(widget.para);

          // El permiso se ofrece acá, donde el usuario ve para qué sirve.
          final activar = ActivarAvisos(
            deps: widget.deps,
            beneficio:
                'Activá los avisos del teléfono para enterarte aunque '
                'tengas la app cerrada.',
          );

          if (avisos.isEmpty) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                activar,
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_off_outlined,
                        size: 56,
                        color: Colors.black26,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Todavía no tenés avisos.',
                        style: TextStyle(color: grisTexto),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              activar,
              for (final aviso in avisos)
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: azulClaro,
                      child: Icon(Icons.notifications, color: azul, size: 20),
                    ),
                    title: Text(
                      aviso.titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      aviso.texto,
                      style: const TextStyle(fontSize: 13),
                    ),
                    trailing: Text(
                      '${aviso.fecha.hour.toString().padLeft(2, '0')}:'
                      '${aviso.fecha.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 11, color: grisTexto),
                    ),
                    isThreeLine: true,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
