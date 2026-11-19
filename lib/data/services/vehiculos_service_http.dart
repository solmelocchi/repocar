import 'dart:convert';

import 'package:http/http.dart' as http;

// =====================================================================
// SERVICIO: baja la lista de autos de una API, por HTTP de verdad.
//
// Por qué la URL viene vacía por defecto: InfoAuto no publica una API
// (hay que pedirles acceso comercial) y deruedas.com.ar no permite que
// un programa le lea el sitio, su robots.txt lo dice. Así que el día
// que consigamos una fuente, lo ÚNICO que cambia es esta URL.
//
// Mientras tanto no pasa nada malo: el repositorio tiene con qué
// seguir, que es justamente la gracia de tener capas.
// =====================================================================
class VehiculosServiceHttp {
  const VehiculosServiceHttp({
    this.url = '',
    this.limite = const Duration(seconds: 5),
    http.Client? cliente,
  }) : _cliente = cliente;

  /// De dónde se baja la lista. Vacía significa "todavía no tenemos".
  final String url;

  /// Cuánto esperamos antes de rendirnos.
  final Duration limite;

  /// El cliente HTTP. En los tests se le pasa uno falso.
  final http.Client? _cliente;

  bool get configurado => url.isNotEmpty;

  Future<List<Map<String, dynamic>>> descargar() async {
    if (!configurado) {
      throw Exception('Todavía no hay una URL de autos configurada');
    }

    final cliente = _cliente ?? http.Client();
    final respuesta = await cliente.get(Uri.parse(url)).timeout(limite);

    if (respuesta.statusCode != 200) {
      throw Exception('El servidor contestó ${respuesta.statusCode}');
    }

    final lista = jsonDecode(respuesta.body) as List;
    return [for (final item in lista) Map<String, dynamic>.from(item as Map)];
  }
}
