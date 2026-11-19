import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:repocar/data/local/almacen_memoria.dart';
import 'package:repocar/data/remoto/tokens_push.dart';
import 'package:repocar/data/repositories/notificaciones_repository.dart';
import 'package:repocar/data/repositories/push_repository.dart';
import 'package:repocar/data/services/push_service.dart';
import 'package:repocar/plataforma/capacidades.dart';
import 'package:repocar/ui/notificaciones/view_models/notificaciones_view_model.dart';

import 'fakes.dart';

/// FCM de mentira: el test hace de servidor y de sistema operativo.
class PushFalso implements PushService {
  PushFalso({this.inicial});

  String? tokenActual = 'token-del-pixel';
  final MensajePush? inicial;

  final _nuevos = StreamController<String>.broadcast();
  final _abierta = StreamController<MensajePush>.broadcast();
  final _tocadas = StreamController<MensajePush>.broadcast();

  void cambiarToken(String nuevo) {
    tokenActual = nuevo;
    _nuevos.add(nuevo);
  }

  /// Llega una push con la app ABIERTA.
  void llegaConLaAppAbierta(MensajePush mensaje) => _abierta.add(mensaje);

  /// El usuario toca una push con la app MINIMIZADA.
  void tocanConLaAppMinimizada(MensajePush mensaje) => _tocadas.add(mensaje);

  @override
  Future<void> iniciar() async {}

  @override
  Future<String?> token() async => tokenActual;

  @override
  Stream<String> get tokensNuevos => _nuevos.stream;

  @override
  Stream<MensajePush> get enPrimerPlano => _abierta.stream;

  @override
  Stream<MensajePush> get tocadas => _tocadas.stream;

  @override
  Future<MensajePush?> conLaQueSeAbrio() async => inicial;
}

/// El servidor de tokens, de mentira: anota lo que le guardan.
class TokensFalsos implements TokensPush {
  final guardados = <String, String>{}; // usuario → token
  int borrados = 0;

  @override
  Future<void> guardar({
    required String usuario,
    required String token,
  }) async => guardados[usuario] = token;

  @override
  Future<void> borrar() async => borrados++;
}

const _pedido = MensajePush(
  titulo: 'Pedido nuevo #2005',
  texto: 'Sol Melocchi te hizo un pedido',
);

void main() {
  late NotificacionesFalsas sistema;
  late PushFalso fcm;
  late TokensFalsos tokens;
  late NotificacionesViewModel avisos;
  String? quienEntro;

  Future<void> armar({MensajePush? inicial}) async {
    sistema = NotificacionesFalsas();
    fcm = PushFalso(inicial: inicial);
    tokens = TokensFalsos();
    quienEntro = '30-71234567-1';
    avisos = NotificacionesViewModel(
      repositorio: NotificacionesRepository(
        servicio: sistema,
        capacidades: const Capacidades(),
        almacen: AlmacenEnMemoria(),
      ),
      push: PushRepository(servicio: fcm, tokens: tokens),
      destinatario: () => quienEntro,
    );
    await avisos.iniciar();
  }

  group('Push (FCM)', () {
    test('estado 1, app ABIERTA: no se muestra sola, la mostramos '
        'nosotros y queda en la campanita', () async {
      await armar();

      fcm.llegaConLaAppAbierta(_pedido);
      await pumpEventQueue();

      expect(sistema.mostradas, ['Pedido nuevo #2005']);
      expect(avisos.para('30-71234567-1').single.titulo, 'Pedido nuevo #2005');
    });

    test('estado 2, app MINIMIZADA: el sistema ya la mostró; al tocarla '
        'se anota (sin mostrarla otra vez) y se abre la bandeja', () async {
      await armar();
      final toques = <String>[];
      avisos.toques.listen(toques.add);

      fcm.tocanConLaAppMinimizada(_pedido);
      await pumpEventQueue();

      expect(sistema.mostradas, isEmpty);
      expect(avisos.sinLeerDe('30-71234567-1'), 1);
      expect(toques, ['push']);
    });

    test('estado 3, app CERRADA: se abrió tocándola; la bandeja se abre '
        'al entrar y el aviso queda anotado', () async {
      await armar(inicial: _pedido);

      expect(avisos.consumirAperturaPendiente(), isTrue);
      await pumpEventQueue();

      expect(avisos.sinLeerDe('30-71234567-1'), 1);
      expect(avisos.consumirAperturaPendiente(), isFalse); // una sola vez
    });

    test('el token se guarda en el servidor al entrar, de nuevo si '
        'cambia, y se borra al salir', () async {
      fcm = PushFalso();
      tokens = TokensFalsos();
      final repositorio = PushRepository(servicio: fcm, tokens: tokens);
      await repositorio.iniciar();
      expect(tokens.guardados, isEmpty); // nadie entró todavía

      await repositorio.usuarioActual('30-71234567-1');
      expect(tokens.guardados['30-71234567-1'], 'token-del-pixel');

      fcm.cambiarToken('token-nuevo');
      await pumpEventQueue();
      expect(tokens.guardados['30-71234567-1'], 'token-nuevo');

      await repositorio.usuarioActual(null);
      expect(tokens.borrados, 1);
    });

    test('sin push (web, compu): la app anda igual con las locales', () async {
      final repositorio = PushRepository(
        servicio: const SinPush(),
        tokens: const SinTokens(),
      );
      await repositorio.iniciar();
      await repositorio.usuarioActual('alguien');

      expect(repositorio.token, isNull);
    });
  });
}
