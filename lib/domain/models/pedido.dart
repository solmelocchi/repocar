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

  /// El nombre del comprador, para mostrarlo.
  final String cliente;

  /// QUIÉN lo compró: el usuario (mail) de su cuenta, que es único. El
  /// nombre no sirve para eso: dos personas pueden llamarse igual, y sus
  /// pedidos se mezclarían.
  final String? clienteUsuario;

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

  /// Cuándo el taller lo marcó como entregado. Desde ahí corren los 10
  /// días para arrepentirse.
  DateTime? entregadoEl;

  /// Cuándo el comprador usó el botón de arrepentimiento (null si no).
  DateTime? arrepentidoEl;

  Pedido({
    required this.numero,
    required this.fecha,
    required this.cliente,
    this.clienteUsuario,
    required this.taller,
    required this.items,
    required this.entrega,
    required this.comisionPct,
    this.direccion = '',
    this.costoEnvio = 0,
    this.estado = EstadoPedido.pagado,
    this.calificacion,
    this.entregadoEl,
    this.arrepentidoEl,
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

  bool get arrepentido => arrepentidoEl != null;

  /// Desde cuándo corren los 10 días: la entrega. Los pedidos viejos, que
  /// no la guardaban, cuentan desde la compra.
  DateTime? get _recibido =>
      entregadoEl ?? (estado == EstadoPedido.entregado ? fecha : null);

  /// Hasta cuándo puede arrepentirse (null si todavía no lo recibió).
  DateTime? get limiteParaArrepentirse =>
      _recibido?.add(plazoDeArrepentimiento);

  /// LEY 24.240 (art. 34) y Resolución 424/2020: en una compra a
  /// distancia, el comprador puede arrepentirse sin dar explicaciones
  /// dentro de los 10 días corridos desde que la recibe. Antes de
  /// recibirla, también. Una sola vez.
  bool puedeArrepentirse(DateTime ahora) {
    if (arrepentido) return false;
    final limite = limiteParaArrepentirse;
    return limite == null || !ahora.isAfter(limite);
  }
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

/// El plazo para arrepentirse de una compra a distancia (Ley 24.240).
const plazoDeArrepentimiento = Duration(days: 10);
