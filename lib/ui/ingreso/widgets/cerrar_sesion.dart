import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import 'ingreso_screen.dart';

/// Pregunta antes de salir y, si confirma, vuelve al inicio de sesión.
///
/// Importa que limpie todas las pantallas de atrás: antes se hacía un
/// pop y, como al taller se entra reemplazando la pantalla de login, no
/// quedaba nada abajo y la app se veía en blanco.
Future<void> cerrarSesion(BuildContext context, Dependencias deps) async {
  final confirmado = await showDialog<bool>(
    context: context,
    builder: (dialogo) => AlertDialog(
      title: const Text('¿Seguro que querés salir?'),
      content: const Text('Vas a volver a la pantalla de inicio de sesión.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogo, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogo, true),
          style: FilledButton.styleFrom(minimumSize: const Size(130, 44)),
          child: const Text('Cerrar sesión'),
        ),
      ],
    ),
  );

  if (confirmado != true || !context.mounted) return;

  deps.sesion.salir();
  deps.carrito.vaciar(); // el próximo que entre no ve el carrito de otro
  deps.pestanaComprador.value = 0;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => IngresoScreen(deps: deps)),
    (route) => false,
  );
}
