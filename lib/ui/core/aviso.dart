import 'dart:async';

import 'package:flutter/material.dart';

/// Un cartelito que aparece arriba y se va solo.
///
/// No usamos SnackBar: el de Material vive en el ScaffoldMessenger, así que
/// se queda pegado aunque cambies de pantalla, y si agregabas tres repuestos
/// seguidos te quedaban tres carteles haciendo cola.
void avisar(BuildContext context, String mensaje) {
  final overlay = Overlay.of(context);
  late OverlayEntry entrada;

  entrada = OverlayEntry(
    builder: (context) => Positioned(
      top: MediaQuery.of(context).padding.top + 70,
      left: 20,
      right: 20,
      child: IgnorePointer(
        child: Material(
          color: Colors.transparent,
          child: _Aviso(mensaje: mensaje),
        ),
      ),
    ),
  );

  overlay.insert(entrada);
  Timer(const Duration(milliseconds: 1400), () {
    if (entrada.mounted) entrada.remove();
  });
}

/// Aparece con un fundido y empieza a irse antes de que lo saquen.
class _Aviso extends StatefulWidget {
  final String mensaje;

  const _Aviso({required this.mensaje});

  @override
  State<_Aviso> createState() => _AvisoState();
}

class _AvisoState extends State<_Aviso> {
  double _opacidad = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _opacidad = 1);
    });
    Timer(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _opacidad = 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _opacidad,
      duration: const Duration(milliseconds: 250),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF15704A),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.mensaje,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
