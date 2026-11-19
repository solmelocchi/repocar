import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as zonas;
import 'package:timezone/timezone.dart' as tz;

// =====================================================================
// SERVICIO: el sistema de notificaciones del teléfono.
//
// Es el borde de la app. Quien muestra la notificación es el SISTEMA
// OPERATIVO, no la app: nosotros le pedimos que la muestre.
//
// Es un contrato (abstract) para poder probar el repositorio con uno
// falso, sin teléfono. La versión de verdad es NotificacionesDelSistema,
// que usa flutter_local_notifications.
// =====================================================================
abstract class NotificacionesService {
  /// Se llama una vez, antes de runApp.
  Future<void> iniciar();

  /// Si el usuario dio permiso (desde Android 13 hay que pedirlo).
  Future<bool> tienePermiso();

  /// Muestra el cuadro del sistema. Se llama desde un botón, cuando el
  /// usuario entiende qué gana, nunca al abrir la app.
  Future<bool> pedirPermiso();

  /// Muestra una notificación ya mismo. El payload viaja con ella y
  /// vuelve cuando la tocan (por ejemplo 'pedido:#1051').
  Future<void> mostrar({
    required int id,
    required String titulo,
    required String texto,
    String? payload,
  });

  /// Le deja al sistema una notificación para más tarde. Con la app
  /// cerrada no corre nada nuestro: el sistema la guarda y la muestra él.
  Future<void> programar({
    required int id,
    required String titulo,
    required String texto,
    required DateTime cuando,
    String? payload,
  });

  Future<void> cancelar(int id);

  /// Los payload de las notificaciones que el usuario tocó con la app
  /// abierta. Es un Stream porque llegan muchos a lo largo del tiempo.
  Stream<String> get toques;

  /// Si la app se abrió tocando una notificación (estaba cerrada), su
  /// payload. Si se abrió normal, null.
  Future<String?> avisoConElQueSeAbrio();
}

/// La de verdad: flutter_local_notifications.
class NotificacionesDelSistema implements NotificacionesService {
  NotificacionesDelSistema({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  // Broadcast: lo puede escuchar más de una pantalla.
  final _toques = StreamController<String>.broadcast();

  bool _iniciado = false;

  /// El canal de Android. La importancia se fija cuando se crea el canal
  /// por primera vez: cambiarla después no tiene efecto.
  static const _detalles = NotificationDetails(
    android: AndroidNotificationDetails(
      'pedidos',
      'Pedidos',
      channelDescription: 'Pedidos nuevos, entregas y recordatorios',
      importance: Importance.high,
      priority: Priority.high,
      // Si llega otra con el mismo id, la reemplaza sin volver a sonar.
      onlyAlertOnce: true,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Los mismos detalles, pero con el estilo de TEXTO LARGO: si el aviso
  /// tiene varios renglones (varios pedidos), al desplegarlo se ven todos.
  /// Sin esto, Android muestra solo el primer renglón.
  static NotificationDetails _detallesCon(String texto) => NotificationDetails(
    android: AndroidNotificationDetails(
      'pedidos',
      'Pedidos',
      channelDescription: 'Pedidos nuevos, entregas y recordatorios',
      importance: Importance.high,
      priority: Priority.high,
      onlyAlertOnce: true,
      styleInformation: BigTextStyleInformation(texto),
    ),
    iOS: const DarwinNotificationDetails(),
  );

  static bool get _esCelular =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// En la computadora (Windows) la app no notifica: Capacidades
  /// responde que no, y acá no se hace nada.
  static bool get _soportado => kIsWeb || _esCelular;

  @override
  Future<void> iniciar() async {
    if (_iniciado || !_soportado) return;
    _iniciado = true;

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // En iOS el permiso NO se pide al iniciar: se pide en contexto.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        web: WebInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (respuesta) {
        final payload = respuesta.payload;
        if (payload != null) _toques.add(payload);
      },
    );

    // El canal se crea ya al arrancar, y no recién con el primer aviso:
    // así las PUSH que muestra el sistema con la app cerrada también lo
    // usan (el manifest dice que su canal es "pedidos").
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        'pedidos',
        'Pedidos',
        description: 'Pedidos nuevos, entregas y recordatorios',
        importance: Importance.high,
      ),
    );

    // Para programar hace falta la zona horaria (TZDateTime).
    if (_esCelular) {
      zonas.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('America/Argentina/Buenos_Aires'));
    }
  }

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  IOSFlutterLocalNotificationsPlugin? get _ios => _plugin
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >();

  WebFlutterLocalNotificationsPlugin? get _web => _plugin
      .resolvePlatformSpecificImplementation<
        WebFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> tienePermiso() async {
    if (!_soportado) return false;
    if (kIsWeb) {
      return _web?.permissionStatus == WebNotificationPermission.granted;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _android?.areNotificationsEnabled() ?? false;
    }
    final opciones = await _ios?.checkPermissions();
    return opciones?.isEnabled ?? false;
  }

  @override
  Future<bool> pedirPermiso() async {
    if (!_soportado) return false;
    if (kIsWeb) return await _web?.requestNotificationsPermission() ?? false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return await _android?.requestNotificationsPermission() ?? false;
    }
    return await _ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        false;
  }

  @override
  Future<void> mostrar({
    required int id,
    required String titulo,
    required String texto,
    String? payload,
  }) async {
    if (!_soportado) return;
    await _plugin.show(
      id: id,
      title: titulo,
      body: texto,
      notificationDetails: _detallesCon(texto),
      payload: payload,
    );
  }

  @override
  Future<void> programar({
    required int id,
    required String titulo,
    required String texto,
    required DateTime cuando,
    String? payload,
  }) async {
    // Programar es cosa del sistema del celular: en la web no se hace.
    if (!_esCelular) return;
    // zonedSchedule tira error si la fecha ya pasó.
    if (!cuando.isAfter(DateTime.now())) return;

    await _plugin.zonedSchedule(
      id: id,
      title: titulo,
      body: texto,
      scheduledDate: tz.TZDateTime.from(cuando, tz.local),
      notificationDetails: _detalles,
      // INEXACTA: unos minutos de demora no le hacen nada a un
      // recordatorio, y la exacta pide un permiso especial que Google
      // Play solo acepta en apps de alarma o calendario.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  @override
  Future<void> cancelar(int id) async {
    if (!_soportado) return;
    await _plugin.cancel(id: id);
  }

  @override
  Stream<String> get toques => _toques.stream;

  @override
  Future<String?> avisoConElQueSeAbrio() async {
    if (!_soportado) return null;
    final detalles = await _plugin.getNotificationAppLaunchDetails();
    if (detalles == null || !detalles.didNotificationLaunchApp) return null;
    return detalles.notificationResponse?.payload;
  }
}
