import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'data/remoto/conectar_servidor.dart';
import 'dependencias.dart';
import 'ui/core/colores.dart';
import 'ui/inicio/widgets/pantalla_principal.dart';
import 'ui/notificaciones/widgets/notificaciones_screen.dart';
import 'ui/sistema/widgets/franja_sin_conexion.dart';

Future<void> main() async {
  // Hace falta antes de usar cualquier plugin antes de runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // El servidor: la base (la del teléfono MÁS Firestore) y el inicio de
  // sesión (Firebase Authentication). Si no arranca, queda la base del
  // teléfono sola y la app anda igual.
  final servidor = await conectarServidor();

  // Se arman las capas una sola vez, de abajo hacia arriba, y de acá
  // bajan por constructor. No hay variables globales.
  final deps = Dependencias.crear(
    almacen: servidor.almacen,
    autenticacion: servidor.autenticacion,
    push: servidor.push,
    tokensPush: servidor.tokens,
  );

  // Notificaciones y WorkManager se preparan antes de dibujar. Si algo
  // del sistema falla, la app abre igual: son extras, no la base.
  try {
    await deps.iniciarPlataforma();
  } catch (_) {}

  // Si quedó alguien con la sesión abierta, entra directo, sin pedirle
  // usuario y contraseña de nuevo.
  try {
    await deps.sesion.restaurar();
  } catch (_) {}

  runApp(RepoCarApp(deps: deps));
}

class RepoCarApp extends StatefulWidget {
  final Dependencias deps;

  const RepoCarApp({super.key, required this.deps});

  @override
  State<RepoCarApp> createState() => _RepoCarAppState();
}

// =====================================================================
// La raíz escucha los EVENTOS DEL SISTEMA que le importan a toda la app.
// Todo lo que se registra en initState se da de baja en dispose.
//   · AppLifecycleListener: el ciclo de vida (se fue, volvió).
//   · WidgetsBindingObserver: lo que el listener no trae, como el aviso
//     de poca memoria.
//   · El Stream de conectividad, a través de ConexionViewModel.
//   · El Stream de toques de notificaciones.
// =====================================================================
class _RepoCarAppState extends State<RepoCarApp> with WidgetsBindingObserver {
  final _navegador = GlobalKey<NavigatorState>();

  late final AppLifecycleListener _cicloDeVida;
  StreamSubscription<String>? _toques;

  Dependencias get _deps => widget.deps;

  @override
  void initState() {
    super.initState();

    _cicloDeVida = AppLifecycleListener(onResume: _alVolver, onHide: _alIrse);
    WidgetsBinding.instance.addObserver(this);

    _deps.conexion.iniciar();

    // Tocaron una notificación con la app abierta: se abre la bandeja
    // de quien tiene la sesión.
    _toques = _deps.notificaciones.toques.listen((_) => _abrirBandeja());
  }

  /// onResume: volvió a la app. Lo que hay en pantalla puede estar
  /// viejo. Por ejemplo, pudo haber ido a los Ajustes del teléfono a
  /// activar las notificaciones: se vuelve a preguntar. Cuando esté el
  /// servidor, acá también se vuelven a pedir los pedidos.
  void _alVolver() {
    _deps.notificaciones.consultarCapacidad();
  }

  /// onHide: la app deja de verse. Si hay un taller adentro, todo lo que
  /// llegó hasta ahora ya lo vio en la app; desde acá, lo nuevo se lo
  /// avisa la tarea de segundo plano (WorkManager).
  void _alIrse() {
    if (_deps.sesion.hayTaller) _deps.segundoPlano.marcarAlTanto();
  }

  /// El sistema avisa que queda poca memoria: se sueltan las imágenes
  /// guardadas en memoria (las fotos), que se pueden volver a leer.
  @override
  void didHaveMemoryPressure() {
    PaintingBinding.instance.imageCache.clear();
  }

  void _abrirBandeja() {
    final sesion = _deps.sesion;
    final para =
        sesion.taller?.cuit ??
        (sesion.hayCliente ? sesion.nombreComprador : null);
    if (para == null) return; // nadie entró todavía

    _navegador.currentState?.push(
      MaterialPageRoute(
        builder: (_) => NotificacionesScreen(deps: _deps, para: para),
      ),
    );
  }

  @override
  void dispose() {
    _toques?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cicloDeVida.dispose();
    _deps.conexion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navegador,
      title: 'RepoCar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: azul,
          primary: azul,
          secondary: naranja,
        ),
        useMaterial3: true,
        // Fondo gris muy claro y tarjetas blancas: así las tarjetas se
        // separan solas, sin bordes pesados.
        scaffoldBackgroundColor: const Color(0xFFF3F5F9),
        appBarTheme: const AppBarTheme(
          backgroundColor: azul,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: Color(0xFFE3E7EF)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: azulClaro,
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white,
          selectedColor: azulClaro,
          side: const BorderSide(color: Color(0xFFE3E7EF)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      // La franja de "Sin conexión" envuelve a todas las pantallas.
      builder: (context, pantalla) => _ConEspacioAbajo(
        child: FranjaSinConexion(
          conexion: _deps.conexion,
          child: pantalla ?? const SizedBox.shrink(),
        ),
      ),
      // Si hay sesión recordada, directo a su pantalla; si no, a entrar.
      home: pantallaPrincipal(_deps),
    );
  }
}

/// En el iPhone, abajo de todo está la rayita para volver al inicio, y
/// esa zona está reservada. Una app instalada se entera sola (el sistema
/// le dice cuánto lugar dejar), pero la versión WEB de Flutter en el
/// iPhone no recibe ese dato: la barra de abajo quedaba pegada al borde y
/// la rayita tapaba los textos. Acá se le agrega ese espacio a mano, solo
/// en ese caso (iPhone, web y sin el dato del sistema).
class _ConEspacioAbajo extends StatelessWidget {
  const _ConEspacioAbajo({required this.child});

  final Widget child;

  /// Lo que ocupa la zona de la rayita en los iPhone actuales.
  static const _zonaDeLaRayita = 24.0;

  @override
  Widget build(BuildContext context) {
    final medidas = MediaQuery.of(context);
    final iPhoneWeb = kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (!iPhoneWeb || medidas.viewPadding.bottom > 0) return child;

    // NavigationBar ya deja abajo el espacio que diga MediaQuery: con
    // decirle que hay que reservar la zona de la rayita, alcanza.
    return MediaQuery(
      data: medidas.copyWith(
        padding: medidas.padding.copyWith(bottom: _zonaDeLaRayita),
        viewPadding: medidas.viewPadding.copyWith(bottom: _zonaDeLaRayita),
      ),
      child: child,
    );
  }
}
