import 'models/pedido.dart';

// =====================================================================
// REGLA: de qué pedido salió cada pieza vendida.
//
// La pieza solo sabe que está vendida; cuándo y a quién lo sabe el
// pedido. El taller lo necesita para ver, en "Vendidas", la fecha de
// cada venta y abrir su pedido.
// =====================================================================

/// De cada pieza (por su id), el pedido que la compró. Si aparece en más
/// de uno (por ejemplo, uno de las pruebas viejas), gana el más nuevo.
Map<String, Pedido> pedidoDeCadaPieza(Iterable<Pedido> pedidos) {
  final resultado = <String, Pedido>{};
  for (final pedido in pedidos) {
    for (final item in pedido.items) {
      final antes = resultado[item.pieza.id];
      if (antes == null || pedido.fecha.isAfter(antes.fecha)) {
        resultado[item.pieza.id] = pedido;
      }
    }
  }
  return resultado;
}
