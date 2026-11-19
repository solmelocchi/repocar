import 'package:flutter/material.dart';

import '../view_models/conexion_view_model.dart';

/// La franja de abajo que dice "Sin conexión". Envuelve a toda la app
/// (se usa en el builder de MaterialApp), así aparece en cualquier
/// pantalla sin que cada una tenga que acordarse.
class FranjaSinConexion extends StatelessWidget {
  final ConexionViewModel conexion;
  final Widget child;

  const FranjaSinConexion({
    super.key,
    required this.conexion,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: child),
        ListenableBuilder(
          listenable: conexion,
          builder: (context, _) => AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: conexion.hayRed
                ? const SizedBox(width: double.infinity)
                : Material(
                    color: const Color(0xFF424242),
                    child: SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.wifi_off, color: Colors.white, size: 18),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Sin conexión. Lo que hagas se guarda en el '
                                'teléfono.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
