import 'package:url_launcher/url_launcher.dart';

import '../domain/cuit.dart';

// =====================================================================
// PLATAFORMA: abrir WhatsApp.
//
// La app no manda ningún mensaje. Arma el enlace oficial de WhatsApp
// (wa.me) con el número del taller y el mensaje ya escrito, y le pide
// al teléfono que lo abra. WhatsApp se abre en ese chat y el usuario
// decide si lo envía.
// =====================================================================

/// El enlace oficial: `https://wa.me/NUMERO?text=MENSAJE`.
/// El número va con código de país, sin "+", espacios ni guiones.
Uri enlaceWhatsApp(String telefono, String mensaje) =>
    Uri.https('wa.me', '/${soloNumeros(telefono)}', {'text': mensaje});

/// Abre WhatsApp en el chat con ese número. Devuelve false si el
/// teléfono no lo pudo abrir (por ejemplo, si no tiene navegador ni
/// WhatsApp).
Future<bool> abrirWhatsApp(String telefono, String mensaje) async {
  try {
    return await launchUrl(
      enlaceWhatsApp(telefono, mensaje),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}
