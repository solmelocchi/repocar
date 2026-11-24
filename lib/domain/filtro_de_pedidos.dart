import 'models/pedido.dart';

// =====================================================================
// REGLAS para encontrar un pedido en una lista larga (lo pidieron los
// talleres y Ramallo: "es un lío scrollear buscando un pedido").
// Son funciones puras: reciben la lista y devuelven otra. Por eso se
// pueden probar sin pantalla.
// =====================================================================

enum OrdenDePedidos { masNuevos, masViejos, porNumero }

extension OrdenDePedidosTexto on OrdenDePedidos {
  String get texto => switch (this) {
    OrdenDePedidos.masNuevos => 'Más nuevos',
    OrdenDePedidos.masViejos => 'Más viejos',
    OrdenDePedidos.porNumero => 'Por número',
  };
}

/// El número del pedido sin el "#" (para ordenar como número, no como
/// texto: si no, el #999 quedaría antes que el #1044).
int numeroDe(Pedido pedido) =>
    int.tryParse(pedido.numero.replaceAll(RegExp(r'\D'), '')) ?? 0;

/// Busca por número, comprador, taller o repuesto; filtra por estado; y
/// ordena. Los filtros se suman.
List<Pedido> filtrarPedidos(
  Iterable<Pedido> pedidos, {
  String texto = '',
  EstadoPedido? estado,
  OrdenDePedidos orden = OrdenDePedidos.masNuevos,
}) {
  final buscado = texto.trim().toLowerCase().replaceAll('#', '');
  final lista = pedidos
      .where((p) => estado == null || p.estado == estado)
      .where(
        (p) =>
            buscado.isEmpty ||
            p.numero.replaceAll('#', '').contains(buscado) ||
            p.cliente.toLowerCase().contains(buscado) ||
            p.taller.nombre.toLowerCase().contains(buscado) ||
            p.detalle.toLowerCase().contains(buscado),
      )
      .toList();
  return switch (orden) {
    OrdenDePedidos.masNuevos =>
      lista..sort((a, b) => b.fecha.compareTo(a.fecha)),
    OrdenDePedidos.masViejos =>
      lista..sort((a, b) => a.fecha.compareTo(b.fecha)),
    OrdenDePedidos.porNumero =>
      lista..sort((a, b) => numeroDe(b) - numeroDe(a)),
  };
}

/// De qué período son los números del resumen de TalleresYa.
enum PeriodoDeResumen { semana, mes, tresMeses, todo }

extension PeriodoDeResumenTexto on PeriodoDeResumen {
  String get texto => switch (this) {
    PeriodoDeResumen.semana => 'Últimos 7 días',
    PeriodoDeResumen.mes => 'Últimos 30 días',
    PeriodoDeResumen.tresMeses => 'Últimos 3 meses',
    PeriodoDeResumen.todo => 'Desde el principio',
  };

  String get corto => switch (this) {
    PeriodoDeResumen.semana => '7 días',
    PeriodoDeResumen.mes => '30 días',
    PeriodoDeResumen.tresMeses => '3 meses',
    PeriodoDeResumen.todo => 'Todo',
  };

  /// Desde qué fecha cuentan los pedidos (null: todos).
  DateTime? desde(DateTime ahora) => switch (this) {
    PeriodoDeResumen.semana => ahora.subtract(const Duration(days: 7)),
    PeriodoDeResumen.mes => ahora.subtract(const Duration(days: 30)),
    PeriodoDeResumen.tresMeses => ahora.subtract(const Duration(days: 90)),
    PeriodoDeResumen.todo => null,
  };
}
