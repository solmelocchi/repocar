// =====================================================================
// POLÍTICA DE AVISOS: cuándo conviene interrumpir al usuario.
//
// Que el teléfono PUEDA mostrar una notificación es una capacidad
// (plataforma/capacidades.dart). Decidir CUÁNDO vale la pena molestar
// es una política de la app, y está acá, con nombre, en un solo lugar.
// =====================================================================
class PoliticaDeAvisos {
  const PoliticaDeAvisos._();

  /// Después de la entrega, cuánto esperar para recordarle al comprador
  /// que califique. Antes no tiene sentido: todavía no probó la pieza.
  static const recordarCalificarDespuesDe = Duration(hours: 24);

  /// Cada cuánto el sistema revisa, con la app cerrada, si el taller
  /// tiene pedidos sin despachar. 15 minutos es lo MÍNIMO que acepta
  /// Android: aunque se pida menos, no lo corre más seguido. Y es un
  /// pedido, no una orden: con el modo ahorro (Doze) puede tardar más.
  static const revisarPedidosCada = Duration(minutes: 15);

  /// El id fijo de la notificación de "pedidos sin despachar": como es
  /// siempre el mismo, la nueva reemplaza a la anterior en vez de apilarse.
  static const idPedidosSinDespachar = 1;

  /// Los avisos de ESTADO de un pedido ("en camino", "llegó") usan
  /// siempre el mismo id: el nuevo REEMPLAZA al anterior en la barra del
  /// teléfono, así no se juntan avisos viejos del mismo pedido.
  static int idDeEstado(String numeroPedido) =>
      2000000 + (int.tryParse(numeroPedido.replaceAll('#', '')) ?? 0);

  /// Los recordatorios de calificar usan el número del pedido más esto,
  /// así no chocan con los demás ids.
  static int idRecordatorio(String numeroPedido) =>
      1000000 + (int.tryParse(numeroPedido.replaceAll('#', '')) ?? 0);
}
