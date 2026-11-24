import 'package:flutter/foundation.dart';

import 'data/local/almacen_local.dart';
import 'data/local/sesion_guardada.dart';
import 'data/politicas_remotas.dart';
import 'data/repositories/catalogo_repository.dart';
import 'data/repositories/cuentas_repository.dart';
import 'data/repositories/notificaciones_repository.dart';
import 'data/remoto/tokens_push.dart';
import 'data/repositories/pedidos_repository.dart';
import 'data/repositories/preguntas_repository.dart';
import 'data/repositories/push_repository.dart';
import 'data/repositories/vehiculos_repository.dart';
import 'data/services/catalogo_service.dart';
import 'data/services/configuracion_service.dart';
import 'data/services/fuente_de_fotos.dart';
import 'data/services/cuentas_service.dart';
import 'data/services/autenticacion_service.dart';
import 'data/services/notificaciones_service.dart';
import 'data/services/pedidos_service.dart';
import 'data/services/preguntas_service.dart';
import 'data/services/push_service.dart';
import 'data/services/vehiculos_service.dart';
import 'data/services/vehiculos_service_http.dart';
import 'domain/models/pieza.dart';
import 'plataforma/capacidades.dart';
import 'plataforma/conectividad.dart';
import 'plataforma/segundo_plano.dart';
import 'ui/admin/view_models/control_de_preguntas_view_model.dart';
import 'ui/busqueda/view_models/vehiculos_view_model.dart';
import 'ui/carrito/view_models/carrito_view_model.dart';
import 'ui/catalogo/view_models/catalogo_view_model.dart';
import 'ui/core/estado_carga.dart';
import 'ui/ingreso/view_models/sesion_view_model.dart';
import 'ui/notificaciones/view_models/notificaciones_view_model.dart';
import 'ui/pedidos/view_models/pedidos_view_model.dart';
import 'ui/preguntas/view_models/mis_preguntas_view_model.dart';
import 'ui/preguntas/view_models/preguntas_view_model.dart';
import 'ui/sistema/view_models/conexion_view_model.dart';
import 'ui/taller/view_models/foto_view_model.dart';

// =====================================================================
// ENSAMBLADO DE LAS CAPAS, de abajo hacia arriba:
//   1. servicios y plataforma (hablan con el exterior y con el aparato)
//   2. repositorios y políticas (fuente de verdad y reglas del servidor)
//   3. view models (estado de pantalla, reciben el repositorio)
//
// Se arma una sola vez en main() y baja por constructor hasta las
// pantallas. Por eso no hay variables globales: en un test se puede
// armar esto mismo con servicios falsos y la app no se entera.
// =====================================================================
/// De dónde se baja la lista de autos (una API REST: GET que devuelve
/// JSON). Está en web/api/vehiculos.json y se publica con la web.
const urlApiDeAutos = 'https://repocar-8cad3.web.app/api/vehiculos.json';

class Dependencias {
  Dependencias._({
    required this.vehiculos,
    required this.catalogo,
    required this.carrito,
    required this.pedidos,
    required this.sesion,
    required this.notificaciones,
    required this.conexion,
    required this.capacidades,
    required this.segundoPlano,
    required this.almacen,
    required this.nuevaFoto,
    required this.misPreguntas,
    required this.nuevasPreguntas,
    required this.controlDePreguntas,
  });

  final VehiculosViewModel vehiculos;
  final CatalogoViewModel catalogo;
  final CarritoViewModel carrito;
  final PedidosViewModel pedidos;
  final SesionViewModel sesion;
  final NotificacionesViewModel notificaciones;

  /// ¿Hay red? Lo escucha toda la app para mostrar la franja.
  final ConexionViewModel conexion;

  /// Lo que el dispositivo puede hacer. Lo consultan las pantallas que
  /// dependen del aparato, como la de publicar (la cámara).
  final Capacidades capacidades;

  /// Las tareas que corren con la app cerrada (WorkManager).
  final SegundoPlano segundoPlano;

  /// La base local que quedó elegida para esta plataforma.
  final AlmacenLocal almacen;

  /// Cada pantalla de publicar tiene su propio ViewModel de la foto (con
  /// el id de la pieza y la foto que ya tenía). Esta función lo arma con
  /// lo que hace falta, sin que la pantalla conozca la cámara.
  final FotoViewModel Function({required String idPieza, String? inicial})
  nuevaFoto;

  /// Las preguntas de quien tiene la sesión: avisa al taller de las nuevas
  /// y al comprador de las respuestas. Vive toda la app.
  final MisPreguntasViewModel misPreguntas;

  /// Cada ficha abierta tiene su propio ViewModel de preguntas.
  final PreguntasViewModel Function(Pieza pieza) nuevasPreguntas;

  /// El control de TalleresYa: todas las preguntas y las publicaciones
  /// para revisar. Lo usa el panel de administración.
  final ControlDePreguntasViewModel controlDePreguntas;

  /// En qué pestaña de la barra de abajo está el comprador. Vive acá
  /// para que otra pantalla (el pedido confirmado) lo pueda llevar a una.
  final pestanaComprador = ValueNotifier<int>(0);

  /// Lo que toca el sistema operativo se puede reemplazar: los tests
  /// pasan versiones falsas, sin plugins.
  factory Dependencias.crear({
    AlmacenLocal? almacen,
    AutenticacionService? autenticacion,
    SesionGuardada? sesionGuardada,
    NotificacionesService? notificacionesService,
    Conectividad? conectividad,
    SegundoPlano? segundoPlano,
    PushService? push,
    TokensPush? tokensPush,
    FuenteDeFotos? fuenteDeFotos,
    PreguntasService? preguntas,
  }) {
    // 0. La base: de dónde salen y a dónde van los datos que tienen que
    //    sobrevivir a cerrar la app. main() pasa la que tiene SERVIDOR
    //    (Firebase); si no viene ninguna, la del teléfono solo.
    final base = almacen ?? crearAlmacenLocal();

    // 1. Servicios y plataforma
    const vehiculosService = VehiculosService();
    // La API de autos: un JSON publicado en Firebase Hosting, junto con
    // la versión web. Si no contesta, se usa la lista que trae la app.
    const vehiculosHttp = VehiculosServiceHttp(url: urlApiDeAutos);
    final catalogoService = CatalogoService(almacen: base);
    const cuentasService = CuentasService();
    final pedidosService = PedidosService(almacen: base);
    const configuracionService = ConfiguracionService();
    final avisosDelSistema =
        notificacionesService ?? NotificacionesDelSistema();
    const capacidades = Capacidades();
    final fotos = fuenteDeFotos ?? FuenteImagePicker();
    final fondo = segundoPlano ?? SegundoPlano(capacidades: capacidades);

    // 2. Repositorios y políticas
    final vehiculosRepo = VehiculosRepositoryConBase(
      servicio: vehiculosService,
      descarga: vehiculosHttp,
      almacen: base,
    );
    final cuentasRepo = CuentasRepository(
      servicio: cuentasService,
      almacen: base,
      // Firebase Authentication valida las contraseñas. Sin servidor,
      // se compara la huella guardada en el teléfono.
      autenticacion: autenticacion ?? const SinAutenticacion(),
    );
    final catalogoRepo = CatalogoRepository(
      servicio: catalogoService,
      cuentas: cuentasRepo,
    );
    final pedidosRepo = PedidosRepository(
      servicio: pedidosService,
      catalogo: catalogoRepo,
      cuentas: cuentasRepo,
    );
    final notificacionesRepo = NotificacionesRepository(
      servicio: avisosDelSistema,
      capacidades: capacidades,
      almacen: base,
    );
    final politicas = PoliticasRemotas(configuracionService);
    final preguntasRepo = PreguntasRepository(
      servicio: preguntas ?? PreguntasEnMemoria(),
    );
    final pushRepo = PushRepository(
      servicio: push ?? const SinPush(),
      tokens: tokensPush ?? const SinTokens(),
    );

    // 3. View models
    // La sesión se arma más abajo; las push necesitan saber quién entró
    // para anotar en SU bandeja. La función la consulta recién cuando
    // llega un mensaje.
    late final SesionViewModel sesion;
    String? quienEntro() =>
        sesion.taller?.cuit ??
        (sesion.hayCliente ? sesion.nombreComprador : null);

    final notificaciones = NotificacionesViewModel(
      repositorio: notificacionesRepo,
      push: pushRepo,
      destinatario: quienEntro,
    );

    final catalogo = CatalogoViewModel(repositorio: catalogoRepo);
    final vehiculos = VehiculosViewModel(repositorio: vehiculosRepo);

    sesion = SesionViewModel(
      repositorio: cuentasRepo,
      politicas: politicas,
      // Quién entró queda en almacenamiento seguro (no en preferencias).
      guardada: sesionGuardada ?? SesionEnAlmacenSeguro(),
      // Entra un taller: el sistema empieza a revisar sus pedidos con
      // la app cerrada. Sale: se cancela.
      alEntrarTaller: fondo.seguirPedidosDe,
      alSalir: fondo.dejarDeSeguir,
    );
    // OBSERVER: cada vez que cambia la sesión, el repositorio de push se
    // entera de quién entró (guarda el token) o de que salió (lo borra).
    sesion.addListener(() => pushRepo.usuarioActual(quienEntro()));

    // Las preguntas siguen a la sesión de la misma forma (OBSERVER): un
    // taller escucha las que le hacen; un comprador, las que él hizo.
    final misPreguntas = MisPreguntasViewModel(
      repositorio: preguntasRepo,
      avisos: notificaciones,
    );
    sesion.addListener(() {
      final taller = sesion.taller;
      if (taller != null) {
        misPreguntas.seguirTaller(taller.cuit);
      } else if (sesion.hayCliente) {
        misPreguntas.seguirComprador(sesion.nombreComprador);
      } else {
        misPreguntas.dejar();
      }
    });

    return Dependencias._(
      vehiculos: vehiculos,
      catalogo: catalogo,
      carrito: CarritoViewModel(vehiculos: vehiculosRepo, politicas: politicas),
      pedidos: PedidosViewModel(
        repositorio: pedidosRepo,
        notificaciones: notificaciones,
        // Cuando una compra deja repuestos vendidos, el catálogo se
        // vuelve a dibujar sin ellos.
        alVender: catalogo.refrescarVista,
      ),
      sesion: sesion,
      notificaciones: notificaciones,
      conexion: ConexionViewModel(
        conectividad: conectividad ?? Conectividad(),
        // Volvió la red: se reintenta lo que había fallado.
        alVolver: () {
          if (catalogo.estado == EstadoCarga.error) catalogo.cargar();
          if (vehiculos.estado == EstadoCarga.error) vehiculos.cargar();
        },
      ),
      capacidades: capacidades,
      segundoPlano: fondo,
      almacen: base,
      nuevaFoto: ({required String idPieza, String? inicial}) => FotoViewModel(
        fuente: fotos,
        repositorio: catalogoRepo,
        capacidades: capacidades,
        idPieza: idPieza,
        inicial: inicial,
      ),
      misPreguntas: misPreguntas,
      controlDePreguntas: ControlDePreguntasViewModel(
        repositorio: preguntasRepo,
        buscarPieza: catalogo.buscarPorId,
      ),
      nuevasPreguntas: (pieza) => PreguntasViewModel(
        repositorio: preguntasRepo,
        pieza: pieza,
        // Pregunta el comprador con sesión; un taller no pregunta.
        autor: () => sesion.hayCliente ? sesion.nombreComprador : null,
      ),
    );
  }

  /// Lo que hay que preparar del sistema ANTES de runApp: el plugin de
  /// notificaciones (y si la app se abrió tocando una) y WorkManager.
  Future<void> iniciarPlataforma() async {
    await notificaciones.iniciar();
    await segundoPlano.iniciar();
  }
}
