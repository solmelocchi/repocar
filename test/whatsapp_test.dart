import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/plataforma/whatsapp.dart';

// =====================================================================
// El enlace de WhatsApp. Abrirlo depende del teléfono, pero armarlo es
// una regla nuestra, y esa se puede probar.
// =====================================================================
void main() {
  test('el número queda solo con dígitos, con el código de país', () {
    final enlace = enlaceWhatsApp('+54 9 260 411-2233', 'Hola');

    expect(enlace.host, 'wa.me');
    expect(enlace.path, '/5492604112233');
  });

  test('el mensaje va escrito, con espacios y acentos codificados', () {
    final enlace = enlaceWhatsApp(
      '+54 9 260 411-2233',
      'Hola! Consulto por el alternador. ¿Me sirve?',
    );

    expect(enlace.scheme, 'https');
    // Al leerlo de vuelta, el texto es exactamente el que armamos.
    expect(
      enlace.queryParameters['text'],
      'Hola! Consulto por el alternador. ¿Me sirve?',
    );
  });
}
