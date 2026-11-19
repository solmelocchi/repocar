import 'package:flutter/foundation.dart';

import '../../../data/local/sesion_guardada.dart';
import '../../../data/politicas_remotas.dart';
import '../../../data/repositories/cuentas_repository.dart';
import '../../../data/services/autenticacion_service.dart';
import '../../../domain/administracion.dart';
import '../../../domain/cuit.dart';
import '../../../domain/models/taller.dart';

// =====================================================================
// VIEWMODEL de la sesión: quién está usando la app.
// De esto depende qué pantalla ve cada uno al entrar.
//
// La contraseña la valida el servidor (Firebase Authentication, a
// través del repositorio). Lo que queda guardado en el teléfono, en
// almacenamiento seguro, es solo QUIÉN entró, para no pedirle que
// vuelva a entrar cada vez que abre la app.
// =====================================================================
class SesionViewModel extends ChangeNotifier {
  SesionViewModel({
    required CuentasRepository repositorio,
    required PoliticasRemotas politicas,
    SesionGuardada? guardada,
    void Function(String cuit)? alEntrarTaller,
    VoidCallback? alSalir,
  }) : _repositorio = repositorio,
       _politicas = politicas,
       _guardada = guardada ?? SesionEnMemoria(),
       _alEntrarTaller = alEntrarTaller,
       _alSalir = alSalir;

  final CuentasRepository _repositorio;
  final PoliticasRemotas _politicas;
  final SesionGuardada _guardada;

  /// Qué hacer cuando entra un taller y cuando alguien sale. Se lo pasa
  /// dependencias.dart (prende y apaga la tarea de segundo plano): así
  /// este view model no conoce a WorkManager, solo avisa.
  final void Function(String cuit)? _alEntrarTaller;
  final VoidCallback? _alSalir;

  static const _rolTaller = 'taller';
  static const _rolCliente = 'cliente';

  Cliente? _cliente;
  Taller? _taller;

  Cliente? get cliente => _cliente;

  Taller? get taller => _taller;

  bool get hayCliente => _cliente != null;

  bool get hayTaller => _taller != null;

  /// TalleresYa: entra como comprador, con la cuenta de administración,
  /// y ve el panel de ventas y comisiones.
  bool get esAdmin => _cliente?.usuario == correoAdministrador;

  /// Con qué nombre se guardan los pedidos que se hacen ahora.
  String get nombreComprador => _cliente?.nombre ?? 'Invitado';

  List<String> get zonasDisponibles => _repositorio.zonasDisponibles;

  List<Taller> get talleres => _repositorio.talleres;

  Future<void> cargar() => _repositorio.cargar();

  // --- Abrir la app con la sesión de la otra vez ---

  /// Si quedó alguien con la sesión abierta, entra solo. Si el servidor
  /// ya no lo reconoce (cerró sesión en otro lado, venció), se olvida.
  Future<void> restaurar() async {
    final guardada = await _guardada.leer();
    if (guardada == null) return;

    if (_repositorio.hayServidor && !_repositorio.haySesionEnServidor) {
      await _guardada.borrar();
      return;
    }

    await _repositorio.cargar();
    if (guardada.rol == _rolTaller) {
      _taller = _repositorio.buscarTallerPorCuit(soloNumeros(guardada.cuenta));
      if (_taller != null) _alEntrarTaller?.call(_taller!.cuit);
    } else {
      _cliente = _repositorio.buscarClientePorUsuario(guardada.cuenta);
    }
    if (_taller == null && _cliente == null) await _guardada.borrar();
    notifyListeners();
  }

  // --- Comprador ---

  /// Devuelve el error para mostrar, o null si entró bien.
  Future<String?> ingresarCliente(String usuario, String clave) async {
    await _repositorio.cargar();
    final cuenta = usuario.trim().toLowerCase();

    // Sin servidor, si no está la cuenta no hay nada que probar.
    if (!_repositorio.hayServidor &&
        _repositorio.buscarClientePorUsuario(cuenta) == null) {
      return 'No hay ninguna cuenta con ese usuario.';
    }

    final error = await _repositorio.entrar(cuenta, cuenta, clave);
    if (error != null) return error;

    final cliente = _repositorio.buscarClientePorUsuario(cuenta);
    if (cliente == null) return 'No hay ninguna cuenta con ese usuario.';

    _cliente = cliente;
    _taller = null;
    await _guardada.guardar(_rolCliente, cliente.usuario);
    notifyListeners();
    return null;
  }

  /// Devuelve el error para mostrar, o null si se registró bien.
  Future<String?> registrarCliente({
    required String nombre,
    required String usuario,
    required String telefono,
    required String clave,
  }) async {
    await _repositorio.cargar();

    final nuevo = Cliente(
      nombre: nombre,
      usuario: usuario.trim().toLowerCase(),
      telefono: telefono,
    );
    try {
      await _repositorio.agregarCliente(nuevo, clave);
    } on ErrorDeAcceso catch (error) {
      return error.mensaje;
    }

    _cliente = nuevo;
    _taller = null;
    await _guardada.guardar(_rolCliente, nuevo.usuario);
    notifyListeners();
    return null;
  }

  bool usuarioOcupado(String usuario) =>
      _repositorio.buscarClientePorUsuario(usuario) != null;

  // --- Taller ---

  Taller? buscarPorCuit(String cuit) =>
      _repositorio.buscarTallerPorCuit(soloNumeros(cuit));

  Future<String?> ingresarTaller(String cuit, String clave) async {
    await _repositorio.cargar();

    if (!cuitValido(cuit)) return 'Ese CUIT no existe: revisá el número.';
    final cuenta = soloNumeros(cuit);

    if (!_repositorio.hayServidor &&
        _repositorio.buscarTallerPorCuit(cuenta) == null) {
      return 'No hay ningún taller registrado con ese CUIT.';
    }

    final error = await _repositorio.entrar(cuenta, mailDeTaller(cuit), clave);
    if (error != null) return error;

    final taller = _repositorio.buscarTallerPorCuit(cuenta);
    if (taller == null) return 'No hay ningún taller registrado con ese CUIT.';

    _taller = taller;
    _cliente = null;
    await _guardada.guardar(_rolTaller, taller.cuit);
    notifyListeners();
    _alEntrarTaller?.call(taller.cuit);
    return null;
  }

  /// Devuelve el error para mostrar, o null si se registró bien.
  Future<String?> registrarTaller({
    required String nombre,
    required String cuit,
    required String telefono,
    required String zona,
    required String clave,
    bool tieneCadete = false,
    int costoCadete = 0,
  }) async {
    await _repositorio.cargar();

    final nuevo = Taller(
      nombre: nombre,
      telefono: telefono,
      zona: zona,
      cuit: formatearCuit(cuit),
      tieneCadete: tieneCadete,
      costoCadete: costoCadete,
      // La comisión la decide el servidor: si no contesta a tiempo,
      // PoliticasRemotas devuelve el 10% de siempre.
      comision: await _politicas.comisionPorDefecto(),
    );
    try {
      await _repositorio.agregarTaller(nuevo, clave);
    } on ErrorDeAcceso catch (error) {
      return error.mensaje;
    }

    _taller = nuevo;
    _cliente = null;
    await _guardada.guardar(_rolTaller, nuevo.cuit);
    notifyListeners();
    _alEntrarTaller?.call(nuevo.cuit);
    return null;
  }

  // --- Editar el perfil ---

  Future<void> actualizarTaller({
    required String telefono,
    required String zona,
    required bool tieneCadete,
    required int costoCadete,
  }) async {
    final taller = _taller;
    if (taller == null) return;
    taller
      ..telefono = telefono
      ..zona = zona
      ..tieneCadete = tieneCadete
      ..costoCadete = tieneCadete ? costoCadete : 0;
    await _repositorio.guardarTaller(taller);
    notifyListeners();
  }

  Future<void> actualizarCliente({required String telefono}) async {
    final cliente = _cliente;
    if (cliente == null) return;
    cliente.telefono = telefono;
    await _repositorio.guardarCliente(cliente);
    notifyListeners();
  }

  Future<void> salir() async {
    _cliente = null;
    _taller = null;
    notifyListeners();
    await _guardada.borrar();
    await _repositorio.salir();
    _alSalir?.call();
  }
}
