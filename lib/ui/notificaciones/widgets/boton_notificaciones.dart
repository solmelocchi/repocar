import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import 'notificaciones_screen.dart';

/// La campanita con el numerito de avisos sin leer.
///
/// Si el dispositivo no puede notificar, este botón directamente NO se
/// dibuja: no tiene sentido ofrecer algo que el teléfono no soporta.
class BotonNotificaciones extends StatefulWidget {
  final Dependencias deps;

  /// A quién pertenecen los avisos: el CUIT del taller o el nombre del
  /// comprador.
  final String para;

  const BotonNotificaciones({
    super.key,
    required this.deps,
    required this.para,
  });

  @override
  State<BotonNotificaciones> createState() => _BotonNotificacionesState();
}

class _BotonNotificacionesState extends State<BotonNotificaciones> {
  @override
  void initState() {
    super.initState();
    // Le preguntamos al dispositivo si puede notificar.
    widget.deps.notificaciones.consultarCapacidad();

    // Si la app se abrió tocando una notificación, apenas entra alguien
    // le mostramos la bandeja (después del primer cuadro, cuando ya hay
    // un Navigator listo).
    if (widget.deps.notificaciones.consumirAperturaPendiente()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _abrirBandeja();
      });
    }
  }

  void _abrirBandeja() => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          NotificacionesScreen(deps: widget.deps, para: widget.para),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final vm = widget.deps.notificaciones;

    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) {
        if (!vm.puedeNotificar) return const SizedBox.shrink();

        final sinLeer = vm.sinLeerDe(widget.para);
        // El numerito sobre el ícono, no sobre el botón (si no, se corta).
        return IconButton(
          tooltip: 'Avisos',
          icon: Badge(
            label: Text('$sinLeer'),
            isLabelVisible: sinLeer > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: _abrirBandeja,
        );
      },
    );
  }
}
