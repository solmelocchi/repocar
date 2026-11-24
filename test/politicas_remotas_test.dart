import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/politicas_remotas.dart';
import 'package:repocar/data/services/configuracion_service.dart';

/// Un servidor que tarda más de lo que estamos dispuestos a esperar.
/// Alcanza con implementar el método público: el resto es privado.
class ConfiguracionLenta implements ConfiguracionService {
  @override
  Future<Map<String, dynamic>> obtenerConfiguracion() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const {'comision_default': 0.25, 'pagos_habilitados': true};
  }
}

/// Un servidor que contesta enseguida, pero con un error.
class ConfiguracionConError implements ConfiguracionService {
  @override
  Future<Map<String, dynamic>> obtenerConfiguracion() async =>
      throw Exception('error 500 del servidor');
}

/// Un servidor que contesta, pero sin el dato que esperamos.
class ConfiguracionIncompleta implements ConfiguracionService {
  @override
  Future<Map<String, dynamic>> obtenerConfiguracion() async => const {};
}

void main() {
  group('Cuando el servidor contesta a tiempo', () {
    final politicas = PoliticasRemotas(const ConfiguracionService());

    test('la comisión sale de la configuración', () async {
      expect(await politicas.comisionPorDefecto(), 0.10);
    });

    test('el pago en la app queda habilitado', () async {
      expect(await politicas.pagoHabilitado(), isTrue);
    });
  });

  group('Cuando el servidor no contesta a tiempo', () {
    final politicas = PoliticasRemotas(
      ConfiguracionLenta(),
      limite: const Duration(milliseconds: 20),
    );

    test('se aplica la comisión por defecto, no la del servidor', () async {
      // El servidor habría dicho 0.25, pero no llegó a tiempo.
      expect(await politicas.comisionPorDefecto(), 0.10);
    });

    test('el pago queda apagado, que es la opción segura', () async {
      expect(await politicas.pagoHabilitado(), isFalse);
    });
  });

  group('Cuando el servidor contesta, pero mal', () {
    test('con un error: comisión por defecto y pago apagado', () async {
      final politicas = PoliticasRemotas(ConfiguracionConError());
      expect(await politicas.comisionPorDefecto(), 0.10);
      expect(await politicas.pagoHabilitado(), isFalse);
    });

    test('sin el dato: comisión por defecto y pago apagado', () async {
      final politicas = PoliticasRemotas(ConfiguracionIncompleta());
      expect(await politicas.comisionPorDefecto(), 0.10);
      expect(await politicas.pagoHabilitado(), isFalse);
    });
  });
}
