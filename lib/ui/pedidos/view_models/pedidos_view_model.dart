import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/repositories/pedidos_repository.dart';
import '../../../domain/models/envio.dart';
import '../../../domain/filtro_de_pedidos.dart';
import '../../../domain/models/pedido.dart';
import '../../../domain/models/taller.dart';
import '../../../domain/politica_de_avisos.dart';
import '../../core/estado_carga.dart';
import '../../notificaciones/view_models/notificaciones_view_model.dart';

/// Lo que vendió un taller en el mes, para el panel de TalleresYa.
typedef VentasDeTaller = ({
  Taller taller,
  int ventas,
  int vendido,
  int comision,
});

// =====================================================================
// VIEWMODEL de los pedidos: los usa el comprador (sus compras), el
// taller (lo que le pidieron) y TalleresYa (cuánto vendió cada uno).
//
// ESCUCHA el Stream de cambios del repositorio (así lo recomienda la
// cátedra: la lógica queda en el view model y se prueba sin dibujar).
// Cada vez que un pedido cambia, redibuja y decide si avisa. Los
// comandos (comprar, entregar, calificar) solo mandan la orden: el
// aviso sale de lo que llega por el Stream, venga de este teléfono o,
// el día de mañana, del servidor.
// =====================================================================
class PedidosViewModel extends ChangeNotifier {
  PedidosViewModel({
    required PedidosRepository repositorio,
    required NotificacionesViewModel notificaciones,
    VoidCallback? alVender,
  }) : _repositorio = repositorio,
       _notificaciones = notificaciones,
       _alVender = alVender {
    // Lo que se abre, se cierra: esta suscripción se cancela en dispose.
    _suscripcion = _repositorio.cambios.listen(_alCambiar);
  }

  final PedidosRepository _repositorio;
  final NotificacionesViewModel _notificaciones;

  /// Qué hacer cuando una compra deja repuestos vendidos. Se lo pasa
  /// dependencias.dart: así este view model no conoce al del catálogo,
  /// solo sabe que tiene que avisar.
  final VoidCallback? _alVender;

  late final StreamSubscription<CambioDePedido> _suscripcion;

  EstadoCarga _estado = EstadoCarga.cargando;
  EstadoCarga get estado => _estado;

  List<Pedido> _pedidos = [];
  List<Pedido> get todos => List.unmodifiable(_pedidos);

  Future<void> cargar() async {
    _estado = EstadoCarga.cargando;
    notifyListeners();

    try {
      _pedidos = await _repositorio.obtenerPedidos();
      _estado = EstadoCarga.exito;
    } catch (_) {
      _estado = EstadoCarga.error;
    } finally {
      // Se ejecuta SIEMPRE, haya error o no: la vista siempre se entera
      // de que terminó la carga (aunque el catch volviera a lanzar el
      // error, o alguien lo cambiara por un "on" que no atrape todo).
      notifyListeners();
    }
  }

  /// Lo que pasa cada vez que llega un cambio por el Stream.
  Future<void> _alCambiar(CambioDePedido cambio) async {
    _pedidos = _repositorio.todos;
    notifyListeners();

    final pedido = cambio.pedido;
    switch (cambio.tipo) {
      case TipoDeCambio.nuevo:
        _alVender?.call();
        // Al taller le avisamos en el momento: es lo que pidió el
        // cliente para no perder ventas por no mirar la app.
        await _notificaciones.avisar(
          para: pedido.taller.cuit,
          titulo: 'Pedido nuevo ${pedido.numero}',
          texto:
              '${pedido.cliente} compró ${pedido.detalle}. '
              'Entrega: ${pedido.entrega.texto}.',
          payload: 'pedido:${pedido.numero}',
        );

      case TipoDeCambio.estado when pedido.estado == EstadoPedido.enviado:
        // El taller lo despachó (o lo dejó listo para retirar): el
        // comprador se entera. Mismo id que el de "llegó", así en la
        // barra queda un solo aviso por pedido.
        final retira = pedido.entrega == MetodoEntrega.retiro;
        await _notificaciones.avisar(
          para: pedido.clienteUsuario ?? pedido.cliente,
          titulo: retira
              ? 'Tu pedido ${pedido.numero} está listo'
              : 'Tu pedido ${pedido.numero} está en camino',
          texto: retira
              ? 'Pasá a retirarlo por ${pedido.taller.nombre}.'
              : '${pedido.taller.nombre} ya lo despachó.',
          payload: 'pedido:${pedido.numero}',
          idDelSistema: PoliticaDeAvisos.idDeEstado(pedido.numero),
        );

      case TipoDeCambio.estado when pedido.estado == EstadoPedido.entregado:
        // Cuando llega, el comprador se entera y ya puede calificar.
        await _notificaciones.avisar(
          para: pedido.clienteUsuario ?? pedido.cliente,
          titulo: 'Tu pedido ${pedido.numero} llegó',
          texto: 'Ya podés calificar a ${pedido.taller.nombre}.',
          payload: 'pedido:${pedido.numero}',
          idDelSistema: PoliticaDeAvisos.idDeEstado(pedido.numero),
        );
        // Y si en un día no calificó, el SISTEMA se lo recuerda, aunque
        // la app esté cerrada: queda programado en el teléfono.
        await _notificaciones.programar(
          id: PoliticaDeAvisos.idRecordatorio(pedido.numero),
          titulo: '¿Ya probaste el repuesto?',
          texto:
              'Contale a otros compradores cómo te fue con '
              '${pedido.taller.nombre}.',
          cuando: DateTime.now().add(
            PoliticaDeAvisos.recordarCalificarDespuesDe,
          ),
          payload: 'pedido:${pedido.numero}',
        );

      case TipoDeCambio.calificacion:
        // Ya calificó: el recordatorio no tiene sentido.
        await _notificaciones.cancelar(
          PoliticaDeAvisos.idRecordatorio(pedido.numero),
        );

      case TipoDeCambio.arrepentimiento:
        // Al taller: el comprador usó el botón de arrepentimiento.
        await _notificaciones.avisar(
          para: pedido.taller.cuit,
          titulo: 'Devolución del pedido ${pedido.numero}',
          texto:
              '${pedido.cliente} se arrepintió de la compra. Coordiná la '
              'devolución.',
          payload: 'pedido:${pedido.numero}',
        );

      case TipoDeCambio.estado:
      case TipoDeCambio.respuesta:
        break;
    }
  }

  List<Pedido> deTaller(Taller taller) => _repositorio.deTaller(taller);

  List<Pedido> deCliente(String usuario) => _repositorio.deCliente(usuario);

  /// Comando: confirma la compra y devuelve un pedido por taller.
  Future<List<Pedido>> confirmarCompra(
    List<CompraTaller> compras,
    String cliente, {
    String? usuario,
  }) => _repositorio.confirmarCompra(compras, cliente, usuario: usuario);

  Future<void> cambiarEstado(Pedido pedido, EstadoPedido estado) =>
      _repositorio.cambiarEstado(pedido, estado);

  Future<void> calificar(Pedido pedido, int estrellas, String comentario) =>
      _repositorio.calificar(pedido, estrellas, comentario);

  Future<void> responder(Pedido pedido, String respuesta) =>
      _repositorio.responder(pedido, respuesta);

  /// El botón de arrepentimiento. Devuelve false si ya pasó el plazo.
  Future<bool> arrepentirse(Pedido pedido) async {
    try {
      await _repositorio.arrepentirse(pedido);
      return true;
    } on FueraDePlazo {
      return false;
    }
  }

  @override
  void dispose() {
    _suscripcion.cancel();
    super.dispose();
  }

  // --- Los números de TalleresYa, según el período que elija ---

  PeriodoDeResumen _periodo = PeriodoDeResumen.mes;

  PeriodoDeResumen get periodo => _periodo;

  /// Ramallo elige otro período: los números se recalculan y el panel se
  /// redibuja.
  set periodo(PeriodoDeResumen nuevo) {
    if (nuevo == _periodo) return;
    _periodo = nuevo;
    notifyListeners();
  }

  List<Pedido> get _delPeriodo =>
      _repositorio.desde(_periodo.desde(DateTime.now()));

  int get pedidosDelPeriodo => _delPeriodo.length;

  int get vendidoDelPeriodo =>
      _delPeriodo.fold(0, (suma, p) => suma + p.subtotal);

  int get comisionDelPeriodo =>
      _delPeriodo.fold(0, (suma, p) => suma + p.comision);

  /// Cuánto vendió cada taller y cuánta comisión le toca cobrar a
  /// TalleresYa, del que más vendió al que menos.
  List<VentasDeTaller> ventasPorTaller(List<Taller> talleres) {
    final resumen = [
      for (final taller in talleres)
        (
          taller: taller,
          ventas: _delPeriodo.where((p) => p.taller.cuit == taller.cuit).length,
          vendido: _delPeriodo
              .where((p) => p.taller.cuit == taller.cuit)
              .fold(0, (suma, p) => suma + p.subtotal),
          comision: _delPeriodo
              .where((p) => p.taller.cuit == taller.cuit)
              .fold(0, (suma, p) => suma + p.comision),
        ),
    ];
    resumen.sort((a, b) => b.vendido.compareTo(a.vendido));
    return resumen;
  }
}
