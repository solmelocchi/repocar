import '../../domain/clave.dart';
import '../../domain/cuit.dart';
import '../../domain/models/taller.dart';
import '../local/almacen_local.dart';
import '../services/autenticacion_service.dart';
import '../services/cuentas_service.dart';

// =====================================================================
// REPOSITORIO: talleres, compradores y sus claves.
//
// Es la fuente de verdad de quién existe en la app. Junta dos cosas:
// las cuentas que vienen con el ejemplo y las que se registraron en
// este teléfono, que salen de la BASE LOCAL. Sin esto último, un taller
// que se registraba desaparecía al reiniciar y sus publicaciones
// quedaban sin dueño.
// =====================================================================
class CuentasRepository {
  CuentasRepository({
    required CuentasService servicio,
    required AlmacenLocal almacen,
    AutenticacionService autenticacion = const SinAutenticacion(),
  }) : _servicio = servicio,
       _almacen = almacen,
       _autenticacion = autenticacion;

  final CuentasService _servicio;
  final AlmacenLocal _almacen;

  /// Firebase Authentication (o nada, sin servidor).
  final AutenticacionService _autenticacion;

  bool get hayServidor => _autenticacion.disponible;

  /// Si el servidor recuerda a alguien con la sesión abierta.
  bool get haySesionEnServidor => _autenticacion.haySesion;

  final List<Taller> _talleres = [];
  final List<Cliente> _clientes = [];

  /// Por cuenta (usuario o CUIT sin guiones), la HUELLA de su clave.
  final Map<String, String> _claves = {};

  bool _cargado = false;

  List<Taller> get talleres => List.unmodifiable(_talleres);

  List<Cliente> get clientes => List.unmodifiable(_clientes);

  /// Las zonas entre las que elige un taller al registrarse.
  List<String> get zonasDisponibles => zonasDeTaller;

  Future<void> cargar() async {
    if (_cargado) return;
    await _almacen.abrir();

    // 1. Lo que viene con la app. Las tres cosas no dependen entre sí,
    //    así que se piden EN PARALELO: se espera lo que tarde la más
    //    lenta, no la suma de las tres.
    final (crudosTalleres, crudosClientes, claves) = await (
      _servicio.obtenerTalleres(),
      _servicio.obtenerClientes(),
      _servicio.obtenerClaves(),
    ).wait;

    _talleres
      ..clear()
      ..addAll(crudosTalleres.map(Taller.desdeJson));
    _clientes
      ..clear()
      ..addAll(crudosClientes.map(Cliente.desdeJson));
    _claves.clear();
    claves.forEach((cuenta, clave) => _claves[cuenta] = hashDeClave(clave));

    // 2. Lo guardado: las cuentas que se registraron y las que cambiaron.
    //    Lo guardado GANA: si un taller de ejemplo editó su perfil, o
    //    TalleresYa le cambió la comisión, vale lo nuevo (antes se
    //    agregaba al final y seguía mandando el dato viejo).
    for (final guardado in await _almacen.leerCuentas('talleres')) {
      final taller = Taller.desdeJson(guardado);
      final lugar = _talleres.indexWhere(
        (t) => soloNumeros(t.cuit) == soloNumeros(taller.cuit),
      );
      if (lugar == -1) {
        _talleres.add(taller);
      } else {
        _talleres[lugar] = taller;
      }
    }
    for (final guardado in await _almacen.leerCuentas('clientes')) {
      final cliente = Cliente.desdeJson(guardado);
      final lugar = _clientes.indexWhere((c) => c.usuario == cliente.usuario);
      if (lugar == -1) {
        _clientes.add(cliente);
      } else {
        _clientes[lugar] = cliente;
      }
    }
    for (final guardada in await _almacen.leerCuentas('claves')) {
      _claves[guardada['id'] as String] = guardada['hash'] as String;
    }

    _cargado = true;
  }

  /// Vuelve a leer todo. Se usa cuando llega del servidor algo de un
  /// taller que se registró en otro teléfono después de que abrimos.
  Future<void> recargar() async {
    _cargado = false;
    await cargar();
  }

  Taller? buscarTallerPorCuit(String soloDigitos) {
    for (final taller in _talleres) {
      if (soloNumeros(taller.cuit) == soloDigitos) return taller;
    }
    return null;
  }

  Cliente? buscarClientePorUsuario(String usuario) {
    final buscado = usuario.trim().toLowerCase();
    for (final cliente in _clientes) {
      if (cliente.usuario.toLowerCase() == buscado) return cliente;
    }
    return null;
  }

  /// Compara huellas, nunca contraseñas.
  bool claveCorrecta(String cuenta, String clave) =>
      _claves[cuenta] == hashDeClave(clave);

  /// Entra con el SERVIDOR (Firebase). Devuelve el error para mostrar, o
  /// null si entró.
  ///
  /// [cuenta] es el usuario o el CUIT sin guiones; [mail] es con lo que
  /// entra a Firebase (para los talleres, el armado con el CUIT).
  Future<String?> entrar(String cuenta, String mail, String clave) async {
    await cargar();
    const malaClave = 'La contraseña no coincide.';

    // Sin servidor de cuentas: se compara la huella guardada acá.
    if (!hayServidor) return claveCorrecta(cuenta, clave) ? null : malaClave;

    try {
      await _autenticacion.entrar(mail, clave);
    } on ErrorDeAcceso catch (error) {
      // Firebase no contesta (o falta activar el inicio de sesión en la
      // consola): se sigue con la huella del teléfono.
      if (error.tipo == TipoDeError.sinServidor) {
        return claveCorrecta(cuenta, clave) ? null : malaClave;
      }
      if (error.tipo != TipoDeError.datosIncorrectos) return error.mensaje;

      // Una cuenta de antes de tener servidor (las de ejemplo, o una
      // registrada en este teléfono): si la clave coincide con la huella,
      // la primera vez se la da de alta en Firebase.
      if (!claveCorrecta(cuenta, clave)) return malaClave;
      try {
        await _autenticacion.crearCuenta(mail, clave);
      } on ErrorDeAcceso catch (alta) {
        return alta.tipo == TipoDeError.yaExiste ? malaClave : alta.mensaje;
      }
    }

    // Ya con la sesión abierta, el servidor deja ver todas las cuentas
    // (las reglas piden estar adentro): se vuelven a leer.
    await recargar();
    return null;
  }

  /// Da de alta la cuenta en el servidor. Si el servidor no está, sigue
  /// sin él (queda en el teléfono); los demás errores se avisan.
  Future<void> _darDeAlta(String mail, String clave) async {
    if (!hayServidor) return;
    try {
      await _autenticacion.crearCuenta(mail, clave);
    } on ErrorDeAcceso catch (error) {
      if (error.tipo != TipoDeError.sinServidor) rethrow;
    }
  }

  Future<void> salir() => _autenticacion.salir();

  /// Guarda los datos nuevos de un taller (editar el perfil).
  Future<void> guardarTaller(Taller taller) =>
      _almacen.guardarCuenta('talleres', taller.cuit, taller.aJson());

  /// Guarda los datos nuevos de un comprador (editar el perfil).
  Future<void> guardarCliente(Cliente cliente) =>
      _almacen.guardarCuenta('clientes', cliente.usuario, cliente.aJson());

  /// Lanza ErrorDeAcceso si el servidor no lo acepta (por ejemplo, si ya
  /// existe esa cuenta).
  Future<void> agregarTaller(Taller taller, String clave) async {
    await _darDeAlta(mailDeTaller(taller.cuit), clave);
    final cuenta = soloNumeros(taller.cuit);
    _talleres.add(taller);
    _claves[cuenta] = hashDeClave(clave);

    await _almacen.guardarCuenta('talleres', taller.cuit, taller.aJson());
    await _almacen.guardarCuenta('claves', cuenta, {
      'hash': hashDeClave(clave),
    });
  }

  Future<void> agregarCliente(Cliente cliente, String clave) async {
    await _darDeAlta(cliente.usuario, clave);
    _clientes.add(cliente);
    _claves[cliente.usuario] = hashDeClave(clave);

    await _almacen.guardarCuenta('clientes', cliente.usuario, cliente.aJson());
    await _almacen.guardarCuenta('claves', cliente.usuario, {
      'hash': hashDeClave(clave),
    });
  }
}
