import 'envio.dart';
import 'pieza.dart';
import 'taller.dart';

// =====================================================================
// DOMINIO: el pedido y su calificación.
// Acá viven las reglas de la plata: qué paga el comprador, qué se lleva
// TalleresYa y qué le queda al taller. No están en la pantalla a
// propósito, para poder probarlas sin dibujar nada.
// =====================================================================

/// Una línea del carrito: una pieza y cuántas unidades.
class ItemCarrito {
  final Pieza pieza;
  int cantidad;

  ItemCarrito(this.pieza, {this.cantidad = 1});

  int get subtotal => pieza.precio * cantidad;
}

/// En qué anda el pedido. Con el pago dentro de la app, un pedido
/// arranca pagado: la plata ya se cobró y se repartió.
enum EstadoPedido { pagado, enviado, entregado }

extension EstadoPedidoTexto on EstadoPedido {
  String get texto => switch (this) {
    EstadoPedido.pagado => 'Pagado',
    EstadoPedido.enviado => 'En camino',
    EstadoPedido.entregado => 'Entregado',
  };

  String get clave => name;
}

/// La calificación que deja el comprador cuando el pedido está entregado.
/// Solo califica el que compró: por eso vive adentro del pedido.
class Calificacion {
  final int estrellas;
  final String comentario;

  /// El taller puede contestar una mala nota para dar su versión.
  String? respuesta;

  Calificacion({required this.estrellas, this.comentario = '', this.respuesta});
}

/// Un pedido: lo que se le compró a UN taller.
/// Si el carrito tiene piezas de dos talleres se arman dos pedidos,
/// porque cada taller cobra, prepara y entrega lo suyo por separado.
class Pedido {
  final String numero;
  final DateTime fecha;
  final String cliente;
  final Taller taller;
  final List<ItemCarrito> items;
  final MetodoEntrega entrega;
  final String direccion;
  final int costoEnvio;

  /// La comisión queda congelada con el porcentaje del día de la venta:
  /// si mañana TalleresYa lo cambia, las ventas viejas no se mueven.
  final double comisionPct;

  EstadoPedido estado;
  Calificacion? calificacion;

  Pedido({
    required this.numero,
    required this.fecha,
    required this.cliente,
    required this.taller,
    required this.items,
    required this.entrega,
    required this.comisionPct,
    this.direccion = '',
    this.costoEnvio = 0,
    this.estado = EstadoPedido.pagado,
    this.calificacion,
  });

  /// Lo que valen las piezas, sin el envío.
  int get subtotal => items.fold(0, (suma, item) => suma + item.subtotal);

  /// Lo que pagó el comprador.
  int get total => subtotal + costoEnvio;

  /// Lo que se lleva TalleresYa. El envío no paga comisión:
  /// esa plata es del cadete o de la empresa de envíos.
  int get comision => (subtotal * comisionPct).round();

  /// Lo que le entra al taller.
  int get neto => subtotal - comision;

  String get detalle => items.map((item) => item.pieza.titulo).join(', ');

  bool get sePuedeCalificar =>
      estado == EstadoPedido.entregado && calificacion == null;
}

/// Lo que el comprador eligió para un taller en el checkout: todavía no
/// es un pedido, es lo que hace falta para armarlo.
class CompraTaller {
  final Taller taller;
  final List<ItemCarrito> items;
  final MetodoEntrega entrega;
  final String direccion;
  final int costoEnvio;

  const CompraTaller({
    required this.taller,
    required this.items,
    required this.entrega,
    this.direccion = '',
    this.costoEnvio = 0,
  });

  int get subtotal => items.fold(0, (suma, item) => suma + item.subtotal);

  int get comision => (subtotal * taller.comision).round();

  int get neto => subtotal - comision;

  int get total => subtotal + costoEnvio;
}
