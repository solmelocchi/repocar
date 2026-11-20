import 'dart:async';

import 'package:repocar/data/repositories/vehiculos_repository.dart';
import 'package:repocar/data/services/autenticacion_service.dart';
import 'package:repocar/data/services/fuente_de_fotos.dart';
import 'package:repocar/data/services/notificaciones_service.dart';
import 'package:repocar/domain/models/auto.dart';
import 'package:repocar/domain/models/envio.dart';
import 'package:repocar/plataforma/capacidades.dart';
import 'package:repocar/plataforma/conectividad.dart';
import 'package:repocar/plataforma/segundo_plano.dart';

/// El sistema de notificaciones, de mentira: anota lo que le piden.
class NotificacionesFalsas implements NotificacionesService {
  NotificacionesFalsas({this.permiso = true});

  /// Si el usuario dio permiso. Se puede cambiar en el medio del test.
  bool permiso;

  /// Los títulos de las notificaciones que se mostraron.
  final mostradas = <String>[];

  /// Lo programado para más tarde: id → cuándo.
  final programadas = <int, DateTime>{};

  final _toques = StreamController<String>.broadcast();

  /// Simula que el usuario toca una notificación.
  void tocar(String payload) => _toques.add(payload);

  @override
  Future<void> iniciar() async {}

  @override
  Future<bool> tienePermiso() async => permiso;

  @override
  Future<bool> pedirPermiso() async => permiso = true;

  @override
  Future<void> mostrar({
    required int id,
    required String titulo,
    required String texto,
    String? payload,
  }) async => mostradas.add(titulo);

  @override
  Future<void> programar({
    required int id,
    required String titulo,
    required String texto,
    required DateTime cuando,
    String? payload,
  }) async => programadas[id] = cuando;

  @override
  Future<void> cancelar(int id) async => programadas.remove(id);

  @override
  Stream<String> get toques => _toques.stream;

  @override
  Future<String?> avisoConElQueSeAbrio() async => null;
}

/// Un teléfono que no puede mostrar notificaciones.
class SinNotificaciones implements Capacidades {
  @override
  Future<bool> puedeNotificar() async => false;

  @override
  Future<bool> tieneCamara() async => true;

  @override
  Future<bool> tieneGaleria() async => true;

  @override
  bool get correTareasDeFondo => false;
}

/// La red, de mentira: el test decide cuándo se va y cuándo vuelve.
class ConectividadFalsa implements Conectividad {
  ConectividadFalsa({this.ahora = true});

  bool ahora;
  final _cambios = StreamController<bool>.broadcast();

  void cambiar(bool hay) {
    ahora = hay;
    _cambios.add(hay);
  }

  /// Cuántos están escuchando: para comprobar que se canceló.
  bool get alguienEscucha => _cambios.hasListener;

  @override
  Future<bool> hayRed() async => ahora;

  @override
  Stream<bool> get cambios => _cambios.stream;
}

/// WorkManager de mentira: anota qué taller se sigue.
class SegundoPlanoFalso implements SegundoPlano {
  String? siguiendo;

  @override
  Future<void> iniciar() async {}

  @override
  Future<void> seguirPedidosDe(String cuit) async => siguiendo = cuit;

  @override
  Future<void> dejarDeSeguir() async => siguiendo = null;

  int alTanto = 0;

  @override
  Future<void> marcarAlTanto() async => alTanto++;
}

// =====================================================================
// FAKES: implementaciones de mentira para los tests.
//
// Esto es lo que se gana con las capas y con la inyección por
// constructor: el view model no sabe si del otro lado hay una API, una
// base de datos o esta clase, así que se puede probar sin red y sin
// esperar un segundo por cada caso.
// =====================================================================

/// Un repositorio que devuelve dos autos, al toque.
class VehiculosFake implements VehiculosRepository {
  @override
  Future<List<ModeloVehiculo>> obtenerVehiculos() async => const [
    ModeloVehiculo('Volkswagen', 'Gol Trend', 2008, 2016),
    ModeloVehiculo('Ford', 'Ranger', 2012, 2022),
  ];

  @override
  Future<List<ZonaEnvio>> obtenerZonas() async => const [
    ZonaEnvio('San Rafael centro', 5, 3800),
  ];
}

/// Un repositorio que siempre falla, para probar el estado de error.
class VehiculosQueFalla implements VehiculosRepository {
  @override
  Future<List<ModeloVehiculo>> obtenerVehiculos() async =>
      throw Exception('se cayó la red');

  @override
  Future<List<ZonaEnvio>> obtenerZonas() async =>
      throw Exception('se cayó la red');
}

/// Firebase Authentication de mentira: cuentas en un mapa (mail → clave).
class AutenticacionFalsa implements AutenticacionService {
  final cuentas = <String, String>{};
  String? conectado;

  /// Cuántas cuentas se dieron de alta (para ver la migración).
  int altas = 0;

  @override
  bool get disponible => true;

  @override
  bool get haySesion => conectado != null;

  @override
  Future<void> entrar(String mail, String clave) async {
    if (cuentas[mail] != clave) {
      throw const ErrorDeAcceso(TipoDeError.datosIncorrectos);
    }
    conectado = mail;
  }

  @override
  Future<void> crearCuenta(String mail, String clave) async {
    if (cuentas.containsKey(mail)) {
      throw const ErrorDeAcceso(TipoDeError.yaExiste);
    }
    if (clave.length < 6) throw const ErrorDeAcceso(TipoDeError.claveCorta);
    cuentas[mail] = clave;
    conectado = mail;
    altas++;
  }

  @override
  Future<void> salir() async => conectado = null;
}

/// La cámara de mentira: devuelve, en orden, lo que le cargamos. Una
/// [Foto], null (el usuario canceló) o un [ErrorDeFoto] (falló).
class FuenteFalsa implements FuenteDeFotos {
  FuenteFalsa(this._respuestas);

  final List<Object?> _respuestas;

  /// Cuántas veces se abrió la cámara.
  int veces = 0;

  @override
  Future<Foto?> elegir(OrigenDeFoto origen) async {
    final respuesta = _respuestas[veces++];
    await Future<void>.delayed(Duration.zero); // como la de verdad: tarda
    if (respuesta is ErrorDeFoto) throw respuesta;
    return respuesta as Foto?;
  }
}
