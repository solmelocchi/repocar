import 'package:flutter/material.dart';

import 'colores.dart';

/// Lo que se muestra mientras el Future no terminó.
class VistaCargando extends StatelessWidget {
  final String mensaje;

  const VistaCargando({super.key, this.mensaje = 'Cargando...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 14),
          Text(mensaje, style: const TextStyle(color: grisTexto)),
        ],
      ),
    );
  }
}

/// Lo que se muestra si el Future falló. Siempre con forma de salir:
/// el botón vuelve a ejecutar el comando del view model.
class VistaError extends StatelessWidget {
  final String mensaje;
  final VoidCallback alReintentar;

  const VistaError({
    super.key,
    required this.alReintentar,
    this.mensaje = 'No pudimos cargar los datos.',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 56, color: Colors.black26),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(color: grisTexto),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
