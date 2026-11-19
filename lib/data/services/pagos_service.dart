import '../../domain/models/pago.dart';

// =====================================================================
// SERVICIO: quien cobra.
//
// Es un contrato: hoy lo cumple un cobrador SIMULADO. Para cobrar de
// verdad con Mercado Pago hace falta un servidor (las claves de Mercado
// Pago no pueden ir adentro de la app), que arme la orden de pago y la
// parta entre el taller y TalleresYa (modalidad Marketplace). Ese día,
// lo único que cambia es la clase que cumple este contrato: la pantalla
// y el view model siguen iguales.
// =====================================================================
abstract class PagosService {
  Future<ResultadoPago> cobrar({
    required int total,
    required MedioDePago medio,
    int cuotas = 1,
  });
}

/// El cobrador de mentira. Tarda como uno de verdad (es un Future: la
/// respuesta llega más tarde) y contesta como Mercado Pago: aprobado, o
/// rechazado con el motivo.
class PagosSimulados implements PagosService {
  const PagosSimulados({this.demora = const Duration(milliseconds: 2800)});

  final Duration demora;

  @override
  Future<ResultadoPago> cobrar({
    required int total,
    required MedioDePago medio,
    int cuotas = 1,
  }) async {
    await Future.delayed(demora);

    if (medio == MedioDePago.tarjetaRechazada) {
      return const ResultadoPago.rechazado(
        'La tarjeta no tiene fondos suficientes. Probá con otro medio de pago.',
      );
    }
    // Un número de operación como los de Mercado Pago.
    final operacion = DateTime.now().millisecondsSinceEpoch % 10000000000;
    return ResultadoPago.aprobado('$operacion');
  }
}
