// En web no existe dart:io y sqflite no corre, así que ahí se usa el
// almacenamiento del navegador. El resto de la app no se entera: pide
// crearAlmacenLocal() y recibe algo que cumple el mismo contrato.
import 'almacen_preferencias.dart'
    if (dart.library.io) 'almacen_sqlite.dart'
    as implementacion;

// =====================================================================
// LA BASE LOCAL, vista como contrato.
//
// Guarda lo que tiene que sobrevivir a cerrar la app: la lista de autos
// que se bajó una vez, las publicaciones, las cuentas, los pedidos y
// los avisos.
// =====================================================================
abstract class AlmacenLocal {
  /// Cómo se llama esta base. Se muestra en pantalla para saber dónde
  /// se está guardando sin tener que mirar el código.
  String get nombre;

  /// Abre la base y crea las tablas si es la primera vez.
  Future<void> abrir();

  Future<List<Map<String, dynamic>>> leerVehiculos();

  Future<void> guardarVehiculos(List<Map<String, dynamic>> vehiculos);

  Future<List<Map<String, dynamic>>> leerPiezas();

  Future<void> guardarPieza(Map<String, dynamic> pieza);

  /// Las cuentas que se registraron en este teléfono. El tipo dice si
  /// son talleres, compradores o claves; el id es el CUIT o el usuario.
  Future<List<Map<String, dynamic>>> leerCuentas(String tipo);

  Future<void> guardarCuenta(String tipo, String id, Map<String, dynamic> dato);

  /// Los pedidos que se hicieron o cambiaron en este teléfono. Se
  /// reemplazan por número: guardar dos veces el #1051 deja uno solo.
  Future<List<Map<String, dynamic>>> leerPedidos();

  Future<void> guardarPedido(Map<String, dynamic> pedido);

  /// Los avisos de la campanita, por id.
  Future<List<Map<String, dynamic>>> leerAvisos();

  Future<void> guardarAviso(Map<String, dynamic> aviso);

  /// Lo que cambian OTROS teléfonos, a medida que pasa (un Stream). La
  /// base local sola no tiene servidor, así que no emite nada; la base
  /// con servidor (data/remoto) sí.
  Stream<List<Map<String, dynamic>>> piezasDelServidor();

  Stream<List<Map<String, dynamic>>> pedidosDelServidor();

  /// El número del próximo pedido, dado por el servidor para que no se
  /// repita entre teléfonos. Sin servidor (o sin señal), null: el número
  /// lo saca el teléfono.
  Future<int?> numeroDePedidoDelServidor(int minimo);
}

/// Devuelve la base que corresponda a esta plataforma.
AlmacenLocal crearAlmacenLocal() => implementacion.crearAlmacen();
