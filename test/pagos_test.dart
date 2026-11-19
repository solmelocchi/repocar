import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/services/pagos_service.dart';
import 'package:repocar/domain/models/pago.dart';

void main() {
  const cobrador = PagosSimulados(demora: Duration.zero);

  test(
    'con dinero en cuenta, el pago se aprueba y trae número de operación',
    () async {
      final resultado = await cobrador.cobrar(
        total: 320000,
        medio: MedioDePago.dineroEnCuenta,
      );

      expect(resultado.aprobado, isTrue);
      expect(resultado.codigo, isNotNull);
    },
  );

  test('la tarjeta de prueba sin fondos se rechaza, con el motivo', () async {
    final resultado = await cobrador.cobrar(
      total: 320000,
      medio: MedioDePago.tarjetaRechazada,
    );

    expect(resultado.aprobado, isFalse);
    expect(resultado.motivo, contains('fondos'));
  });

  test('las cuotas se redondean para arriba: nunca queda corto', () {
    expect(valorDeCuota(100000, 3), 33334);
    expect(valorDeCuota(100000, 3) * 3, greaterThanOrEqualTo(100000));
    expect(valorDeCuota(90000, 6), 15000);
  });

  test('solo la tarjeta de crédito admite cuotas', () {
    expect(MedioDePago.credito.admiteCuotas, isTrue);
    expect(MedioDePago.debito.admiteCuotas, isFalse);
  });
}
