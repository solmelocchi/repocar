import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../firebase_options.dart';

// =====================================================================
// SERVICIO de las notificaciones PUSH (Firebase Cloud Messaging, FCM).
//
// Local: la app decide avisar, con datos que ya tiene.
// Push: el aviso viene de AFUERA. Un servidor le manda el mensaje a FCM
// con el TOKEN del teléfono, y FCM se lo entrega aunque la app esté
// cerrada.
//
// Nosotros no programamos ese servidor (en Firebase es Cloud Functions,
// que pide el plan pago). Los mensajes se mandan desde la consola de
// Firebase, en Messaging, pegando el token: es la forma de probar que
// muestra el apunte. La app ya los recibe en los tres estados.
//
// Como los demás servicios, el plugin queda detrás de una clase
// abstracta: en la web, en la compu y en los tests se usa SinPush.
// =====================================================================

/// Lo que nos importa de un mensaje push, sin depender del plugin.
class MensajePush {
  const MensajePush({
    required this.titulo,
    required this.texto,
    this.datos = const {},
  });

  final String titulo;
  final String texto;

  /// La parte de "datos" del mensaje (por ejemplo, el número de pedido).
  final Map<String, dynamic> datos;
}

abstract class PushService {
  /// Se registra en FCM. NO pide permiso: en Android es el mismo de las
  /// locales (POST_NOTIFICATIONS) y se pide en contexto, con "Activar".
  Future<void> iniciar();

  /// El token: la "dirección" de esta instalación de la app en FCM.
  Future<String?> token();

  /// El token puede cambiar (si reinstalan la app o borran sus datos).
  /// Es un Stream porque puede pasar en cualquier momento.
  Stream<String> get tokensNuevos;

  /// 1. App en PRIMER PLANO: el mensaje llega acá y NO se muestra solo.
  Stream<MensajePush> get enPrimerPlano;

  /// 2. App en SEGUNDO PLANO: el sistema mostró la notificación y el
  ///    usuario la tocó.
  Stream<MensajePush> get tocadas;

  /// 3. App CERRADA: el usuario tocó la notificación y eso abrió la app.
  ///    Es un Future porque pasa una sola vez, al arrancar.
  Future<MensajePush?> conLaQueSeAbrio();
}

/// El manejador de SEGUNDO PLANO: lo llama el sistema cuando llega un
/// mensaje con la app minimizada o cerrada.
///
/// Tiene que ser una función de nivel superior (no un método) y llevar
/// el @pragma, para que el compilador no la borre en la versión de
/// release: nadie la llama desde nuestro código.
///
/// Corre en OTRO ISOLATE: no ve nada de la app (ni la pantalla ni los
/// view models). Por eso solo se conecta a Firebase. La notificación
/// ya la muestra el sistema.
@pragma('vm:entry-point')
Future<void> manejarPushEnSegundoPlano(RemoteMessage mensaje) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// La de verdad, con firebase_messaging. Solo en Android.
class PushFcm implements PushService {
  FirebaseMessaging get _fcm => FirebaseMessaging.instance;

  static MensajePush _convertir(RemoteMessage mensaje) => MensajePush(
    titulo:
        mensaje.notification?.title ??
        mensaje.data['titulo']?.toString() ??
        'RepoCar',
    texto:
        mensaje.notification?.body ?? mensaje.data['texto']?.toString() ?? '',
    datos: mensaje.data,
  );

  @override
  Future<void> iniciar() async {
    FirebaseMessaging.onBackgroundMessage(manejarPushEnSegundoPlano);
  }

  // getToken y onTokenRefresh son los del apunte. La versión 17 del
  // paquete los marca "en desuso" y propone register(), que devuelve
  // otro identificador; la consola de Firebase, para el mensaje de
  // prueba, sigue pidiendo ESTE token. Por eso se usan a propósito.

  @override
  // ignore: deprecated_member_use
  Future<String?> token() => _fcm.getToken();

  @override
  // ignore: deprecated_member_use
  Stream<String> get tokensNuevos => _fcm.onTokenRefresh;

  @override
  Stream<MensajePush> get enPrimerPlano =>
      FirebaseMessaging.onMessage.map(_convertir);

  @override
  Stream<MensajePush> get tocadas =>
      FirebaseMessaging.onMessageOpenedApp.map(_convertir);

  @override
  Future<MensajePush?> conLaQueSeAbrio() async {
    final mensaje = await _fcm.getInitialMessage();
    return mensaje == null ? null : _convertir(mensaje);
  }
}

/// Sin push: en la web (necesita otra configuración), en la compu, sin
/// servidor y en los tests. La app anda igual con las locales.
class SinPush implements PushService {
  const SinPush();

  @override
  Future<void> iniciar() async {}

  @override
  Future<String?> token() async => null;

  @override
  Stream<String> get tokensNuevos => const Stream.empty();

  @override
  Stream<MensajePush> get enPrimerPlano => const Stream.empty();

  @override
  Stream<MensajePush> get tocadas => const Stream.empty();

  @override
  Future<MensajePush?> conLaQueSeAbrio() async => null;
}
