import 'package:flutter/foundation.dart';

import '../../../data/local/carrito_guardado.dart';
import '../../../data/politicas_remotas.dart';
import '../../../data/repositories/borrador_repository.dart';
import '../../../data/repositories/vehiculos_repository.dart';
import '../../../data/services/pagos_service.dart';
import '../../../domain/models/envio.dart';
import '../../../domain/models/pago.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/pieza.dart';

// =====================================================================
// VIEWMODEL del carrito.
// Guarda el dato y avisa con notifyListeners() cuando cambia, igual que
// el CartModel del TP. Ahora además trae las zonas de envío, que las
// necesita el checkout para cotizar.
// =====================================================================
class CarritoViewModel extends ChangeNotifier {
  CarritoViewModel({
    required VehiculosRepository vehiculos,
    required PoliticasRemotas politicas,
    PagosService pagos = const PagosSimulados(),
    CarritoGuardado? guardado,
    BorradorRepository? borradores,
  }) : _vehiculos = vehiculos,
       _politicas = politicas,
       _pagos = pagos,
       _guardado = guardado ?? CarritoEnPreferencias(),
       _borradores = borradores ?? BorradorRepository();

  /// Dónde queda el carrito para que sobreviva a cerrar la app.
  final CarritoGuardado _guardado;

  /// Dónde queda lo que se estaba completando en el checkout.
  final BorradorRepository _borradores;

  bool _restaurado = false;

  /// Al abrir la app: vuelve a poner en el carrito lo que había la otra
  /// vez. [buscar] trae la pieza por id (del catálogo). Lo que ya no está
  /// a la venta (se vendió o lo sacaron) no vuelve.
  Future<void> restaurar(Pieza? Function(String id) buscar) async {
    if (_restaurado) return;
    _restaurado = true;
    for (final id in await _guardado.leer()) {
      final pieza = buscar(id);
      if (pieza != null && pieza.aLaVenta && !contiene(pieza)) {
        _items.add(ItemCarrito(pieza));
      }
    }
    notifyListeners();
    _guardar(); // por si alguna ya no estaba
  }

  void _guardar() =>
      _guardado.guardar([for (final item in _items) item.pieza.id]);

  // --- El borrador del checkout (se guarda en onHide) ---

  Future<void> guardarEntregas(Map<String, dynamic> entregas) =>
      _borradores.guardarCheckout(entregas);

  Future<Map<String, dynamic>?> leerEntregas() => _borradores.leerCheckout();

  final VehiculosRepository _vehiculos;
  final PoliticasRemotas _politicas;

  /// Quien cobra. Hoy, simulado; con Mercado Pago real cambia solo esto.
  final PagosService _pagos;

  /// Cobra. Es un Future: la respuesta de quien cobra llega más tarde, y
  /// puede ser "rechazado" (la pantalla lo muestra y no se arma el pedido).
  Future<ResultadoPago> cobrar({
    required int total,
    required MedioDePago medio,
    int cuotas = 1,
  }) => _pagos.cobrar(total: total, medio: medio, cuotas: cuotas);

  /// Lo decide el servidor: si el cobro en la app está habilitado.
  bool _pagoHabilitado = true;

  final List<ItemCarrito> _items = [];
  List<ZonaEnvio> _zonas = [];

  List<ItemCarrito> get items => List.unmodifiable(_items);

  List<ZonaEnvio> get zonas => List.unmodifiable(_zonas);

  bool get pagoHabilitado => _pagoHabilitado;

  int get cantidad => _items.fold(0, (suma, item) => suma + item.cantidad);

  int get total => _items.fold(0, (suma, item) => suma + item.subtotal);

  /// Los talleres que aparecen en el carrito, sin repetir: el carrito
  /// puede tener piezas de dos talleres y cada uno entrega lo suyo.
  List<ItemCarrito> itemsDeTaller(String cuit) =>
      _items.where((item) => item.pieza.taller.cuit == cuit).toList();

  /// Las tarifas de envío por zona. Si no se pueden traer, la lista
  /// queda vacía (el checkout ofrece retiro o cadete) y la pantalla se
  /// entera igual: el aviso va en el finally.
  Future<void> cargarZonas() async {
    if (_zonas.isNotEmpty) return;
    try {
      _zonas = await _vehiculos.obtenerZonas();
    } catch (_) {
      _zonas = [];
    } finally {
      notifyListeners();
    }
  }

  /// Le pregunta al servidor si se puede cobrar dentro de la app.
  Future<void> cargarPoliticas() async {
    try {
      _pagoHabilitado = await _politicas.pagoHabilitado();
    } finally {
      notifyListeners();
    }
  }

  /// Si la pieza ya está en el carrito.
  bool contiene(Pieza pieza) => _items.any((item) => item.pieza.id == pieza.id);

  /// Agrega la pieza. Son repuestos USADOS: hay UNO solo de cada uno, así
  /// que no se puede pedir dos veces ni elegir cantidad. Devuelve false si
  /// no se agregó (ya estaba, o ya no está a la venta).
  bool agregar(Pieza pieza) {
    if (contiene(pieza) || !pieza.aLaVenta) return false;
    _items.add(ItemCarrito(pieza));
    notifyListeners(); // sin esta línea, el número del carrito no cambia
    _guardar();
    return true;
  }

  void quitar(ItemCarrito item) {
    _items.remove(item);
    notifyListeners();
    _guardar();
  }

  /// Las piezas del carrito que ya no se pueden comprar: otro comprador
  /// se las llevó (llegó por el Stream del servidor) o el taller las
  /// pausó o borró. Se revisa ANTES de cobrar.
  List<Pieza> get noDisponibles => [
    for (final item in _items)
      if (!item.pieza.aLaVenta) item.pieza,
  ];

  /// Después de pagar o al cerrar sesión: el carrito y lo que se estaba
  /// completando en el checkout se borran también de lo guardado.
  void vaciar() {
    _items.clear();
    notifyListeners();
    _guardar();
    _borradores.borrarCheckout();
  }
}
