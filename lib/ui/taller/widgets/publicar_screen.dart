import 'package:flutter/material.dart';

import '../../../data/services/fuente_de_fotos.dart';
import '../../../dependencias.dart';
import '../../../domain/models/auto.dart';
import '../../../domain/models/pieza.dart';
import '../../core/aviso.dart';
import '../../core/colores.dart';
import '../../core/iconos.dart';
import '../../core/imagen_guardada.dart';
import '../view_models/foto_view_model.dart';

/// El formulario con el que el taller publica un repuesto de verdad:
/// lo que carga acá aparece en el catálogo y en las búsquedas.
///
/// Es el MISMO formulario para publicar y para editar: si viene una
/// pieza, arranca con sus datos y al guardar la reemplaza (mismo id).
class PublicarScreen extends StatefulWidget {
  final Dependencias deps;

  /// La publicación a editar. Null = publicar una nueva.
  final Pieza? pieza;

  const PublicarScreen({super.key, required this.deps, this.pieza});

  @override
  State<PublicarScreen> createState() => _PublicarScreenState();
}

class _PublicarScreenState extends State<PublicarScreen> {
  final _formulario = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _precio = TextEditingController();
  final _descripcion = TextEditingController();

  EstadoPieza _estado = EstadoPieza.usado;
  String _icono = 'build';
  String? _marca;
  String? _modelo;
  int? _desde;
  int? _hasta;
  bool _publicando = false;

  /// EVENTO DEL SISTEMA: el ciclo de vida de la app. Se registra en
  /// initState y se da de baja en dispose.
  late final AppLifecycleListener _cicloDeVida;

  late final String _id = widget.pieza?.id ?? widget.deps.catalogo.proximoId;

  /// La foto: elegirla, achicarla y reemplazarla es cosa de su ViewModel.
  /// Esta pantalla no sabe que existe la cámara.
  late final FotoViewModel _foto = widget.deps.nuevaFoto(
    idPieza: _id,
    inicial: widget.pieza?.foto,
  );

  bool get _editando => widget.pieza != null;

  String get _cuit => widget.deps.sesion.taller!.cuit;

  @override
  void initState() {
    super.initState();
    // La lista de autos sale del mismo view model que usa el comprador.
    widget.deps.vehiculos.cargar();
    _foto.consultarCapacidades();

    // onHide: la app dejó de verse (entró una llamada, fue a otra app).
    // Es el último aviso seguro, y llega en todas las plataformas: si
    // después el sistema la cierra, lo escrito ya está guardado.
    _cicloDeVida = AppLifecycleListener(onHide: _guardarBorrador);

    final pieza = widget.pieza;
    if (pieza != null) {
      _cargarDe(pieza);
    } else {
      _recuperarBorrador();
    }
  }

  /// Editar: el formulario arranca con lo que ya está publicado.
  void _cargarDe(Pieza pieza) {
    _titulo.text = pieza.titulo;
    _precio.text = '${pieza.precio}';
    _descripcion.text = pieza.descripcion;
    _estado = pieza.estado;
    _icono = pieza.icono;
    if (pieza.compatibles.isNotEmpty) {
      final primera = pieza.compatibles.first;
      _marca = primera.marca;
      _modelo = primera.modelo;
      _desde = primera.desde;
      _hasta = primera.hasta;
    }
  }

  @override
  void dispose() {
    _cicloDeVida.dispose();
    _foto.dispose();
    _titulo.dispose();
    _precio.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  // --- El borrador ---

  Map<String, dynamic> get _borrador => {
    'titulo': _titulo.text,
    'precio': _precio.text,
    'descripcion': _descripcion.text,
    'estado': _estado.name,
    'icono': _icono,
    'marca': _marca,
    'modelo': _modelo,
    'desde': _desde,
    'hasta': _hasta,
    'foto': _foto.referencia,
  };

  bool get _escribioAlgo =>
      _titulo.text.isNotEmpty ||
      _precio.text.isNotEmpty ||
      _descripcion.text.isNotEmpty ||
      _foto.referencia != null;

  Future<void> _guardarBorrador() async {
    // Editando, lo publicado ya está guardado: el borrador es para lo nuevo.
    if (_editando || _publicando || !_escribioAlgo) return;
    await widget.deps.catalogo.guardarBorrador(_cuit, _borrador);
  }

  Future<void> _recuperarBorrador() async {
    final guardado = await widget.deps.catalogo.leerBorrador(_cuit);
    if (guardado == null || !mounted) return;

    setState(() {
      _titulo.text = guardado['titulo'] as String? ?? '';
      _precio.text = guardado['precio'] as String? ?? '';
      _descripcion.text = guardado['descripcion'] as String? ?? '';
      _estado = guardado['estado'] == EstadoPieza.reacondicionado.name
          ? EstadoPieza.reacondicionado
          : EstadoPieza.usado;
      _icono = guardado['icono'] as String? ?? 'build';
      _marca = guardado['marca'] as String?;
      _modelo = guardado['modelo'] as String?;
      _desde = guardado['desde'] as int?;
      _hasta = guardado['hasta'] as int?;
    });
    _foto.restaurar(guardado['foto'] as String?);
    avisar(context, 'Seguís donde lo habías dejado');
  }

  Future<void> _descartarBorrador() async {
    await widget.deps.catalogo.borrarBorrador(_cuit);
    if (!mounted) return;
    setState(() {
      _titulo.clear();
      _precio.clear();
      _descripcion.clear();
      _estado = EstadoPieza.usado;
      _icono = 'build';
      _marca = null;
      _modelo = null;
      _desde = null;
      _hasta = null;
    });
    _foto.quitar();
  }

  List<int> get _anios {
    if (_marca == null || _modelo == null) return [];
    return widget.deps.vehiculos.aniosDe(_marca!, _modelo!);
  }

  Future<void> _publicar() async {
    final mensajero = ScaffoldMessenger.of(context);
    mensajero.clearSnackBars();

    if (!_formulario.currentState!.validate()) return;

    if (_marca == null || _modelo == null || _desde == null || _hasta == null) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('Elegí para qué auto sirve el repuesto'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_hasta! < _desde!) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('El año "hasta" no puede ser menor que el "desde"'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _publicando = true);

    final titulo = _titulo.text.trim();
    final anterior = widget.pieza;
    final pieza = Pieza(
      id: _id,
      titulo: titulo,
      descripcion: _descripcion.text.trim(),
      precio: int.parse(_precio.text.trim()),
      estado: _estado,
      taller: widget.deps.sesion.taller!,
      icono: _icono,
      foto: _foto.referencia,
      compatibles: [
        Compatibilidad(_marca!, _modelo!, _desde!, _hasta!),
        // Editando, los otros autos para los que ya servía se conservan.
        ...?anterior?.compatibles.skip(1),
      ],
      vendida: anterior?.vendida ?? false,
      pausada: anterior?.pausada ?? false,
    );

    if (anterior != null) {
      await widget.deps.catalogo.editar(pieza);
      // Si cambió la foto, la vieja ya no la usa nadie: se borra.
      await _foto.confirmarGuardado();
    } else {
      await widget.deps.catalogo.publicar(pieza);
      // Ya se publicó: el borrador no sirve más.
      await widget.deps.catalogo.borrarBorrador(_cuit);
    }

    if (!mounted) return;
    avisar(
      context,
      anterior != null ? 'Guardaste los cambios' : '$titulo ya está publicado',
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.deps.vehiculos;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editando ? 'Editar publicación' : 'Publicar un repuesto'),
        actions: [
          if (!_editando)
            IconButton(
              tooltip: 'Empezar de nuevo',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: _descartarBorrador,
            ),
        ],
      ),
      body: Form(
        key: _formulario,
        child: ListenableBuilder(
          // Se redibuja cuando cambian los autos o la foto.
          listenable: Listenable.merge([vm, _foto]),
          builder: (context, _) => ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _titulo,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Título',
                  hintText: 'Ej: Alternador Bosch 90A',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) => (valor == null || valor.trim().isEmpty)
                    ? 'Poné un título'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _precio,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Precio',
                  prefixText: '\$ ',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) {
                  final numero = int.tryParse((valor ?? '').trim());
                  if (numero == null || numero <= 0) return 'Poné el precio';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descripcion,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  hintText: 'Estado real de la pieza, garantía, kilómetros...',
                  border: OutlineInputBorder(),
                ),
                validator: (valor) => (valor == null || valor.trim().isEmpty)
                    ? 'Contá cómo está la pieza'
                    : null,
              ),
              const SizedBox(height: 18),

              const Text(
                'Estado',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final estado in EstadoPieza.values)
                    ChoiceChip(
                      label: Text(estado.texto),
                      selected: _estado == estado,
                      onSelected: (_) => setState(() => _estado = estado),
                    ),
                ],
              ),
              const SizedBox(height: 18),

              // La cámara y la galería son CAPACIDADES del dispositivo:
              // si no hay ninguna, la sección no se dibuja, en vez de
              // fallar al tocarla.
              if (_foto.hayDeDonde) ...[
                const Text(
                  'Foto',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                _vistaFoto(),
                const SizedBox(height: 18),
              ],

              const Text(
                'Ícono',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              const Text(
                'Si no sacás una foto, la publicación muestra este ícono.',
                style: TextStyle(fontSize: 13, color: grisTexto),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final clave in clavesDeIconos)
                    // Con nombre: el lector de pantalla dice "Frenos y
                    // embrague" y no solo "botón". Y de 48 x 48, el tamaño
                    // mínimo para tocarlo sin errarle.
                    Tooltip(
                      message: nombresDeRubros[clave] ?? clave,
                      child: Semantics(
                        button: true,
                        selected: _icono == clave,
                        child: InkWell(
                          onTap: () => setState(() => _icono = clave),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: _icono == clave ? azul : azulClaro,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              iconoDe(clave),
                              color: _icono == clave ? Colors.white : azul,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 22),

              const Text(
                '¿Para qué autos sirve?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              const Text(
                'Se elige de la lista. Nunca se escribe a mano: por eso la '
                'búsqueda del comprador funciona.',
                style: TextStyle(fontSize: 12, color: grisTexto),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                isExpanded: true,
                // La key hace que el campo se redibuje si el valor llega
                // del borrador después del primer cuadro.
                key: ValueKey('marca-$_marca'),
                initialValue: _marca,
                decoration: const InputDecoration(
                  labelText: 'Marca',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final marca in vm.marcas)
                    DropdownMenuItem(value: marca, child: Text(marca)),
                ],
                onChanged: (valor) => setState(() {
                  _marca = valor;
                  _modelo = null;
                  _desde = null;
                  _hasta = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                key: ValueKey('modelo-$_marca-$_modelo'),
                initialValue: _modelo,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  border: OutlineInputBorder(),
                ),
                items: _marca == null
                    ? []
                    : [
                        for (final vehiculo in vm.modelosDe(_marca!))
                          DropdownMenuItem(
                            value: vehiculo.modelo,
                            child: Text(vehiculo.modelo),
                          ),
                      ],
                onChanged: (valor) => setState(() {
                  _modelo = valor;
                  _desde = null;
                  _hasta = null;
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      key: ValueKey('desde-$_modelo-$_desde'),
                      initialValue: _anios.contains(_desde) ? _desde : null,
                      decoration: const InputDecoration(
                        labelText: 'Desde',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final anio in _anios)
                          DropdownMenuItem(value: anio, child: Text('$anio')),
                      ],
                      onChanged: (valor) => setState(() => _desde = valor),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      key: ValueKey('hasta-$_modelo-$_hasta'),
                      initialValue: _anios.contains(_hasta) ? _hasta : null,
                      decoration: const InputDecoration(
                        labelText: 'Hasta',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final anio in _anios)
                          DropdownMenuItem(value: anio, child: Text('$anio')),
                      ],
                      onChanged: (valor) => setState(() => _hasta = valor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _publicando || _foto.cargando ? null : _publicar,
                icon: Icon(_editando ? Icons.save : Icons.publish),
                label: Text(
                  _publicando
                      ? 'Guardando...'
                      : (_editando ? 'Guardar cambios' : 'Publicar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vistaFoto() {
    if (_foto.cargando) {
      return Container(
        height: 180,
        decoration: BoxDecoration(
          color: azulClaro,
          borderRadius: BorderRadius.circular(10),
        ),
        // Mientras se achica la foto en el otro isolate, la rueda sigue
        // girando sin trabarse: el cálculo no está en el hilo de la
        // pantalla.
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Preparando la foto...'),
          ],
        ),
      );
    }

    final error = _foto.error;
    final foto = _foto.referencia;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (foto != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 180,
              width: double.infinity,
              child: imagenGuardada(context, foto),
            ),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(error, style: const TextStyle(color: Colors.red)),
          ),
        Wrap(
          spacing: 8,
          children: [
            if (_foto.puedeUsarCamara)
              TextButton.icon(
                onPressed: () => _foto.elegir(OrigenDeFoto.camara),
                icon: const Icon(Icons.photo_camera),
                label: Text(foto == null ? 'Sacar una foto' : 'Sacar otra'),
              ),
            if (_foto.puedeUsarGaleria)
              TextButton.icon(
                onPressed: () => _foto.elegir(OrigenDeFoto.galeria),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Elegir de la galería'),
              ),
            if (foto != null)
              TextButton.icon(
                onPressed: _foto.quitar,
                icon: const Icon(Icons.close),
                label: const Text('Sin foto'),
              ),
          ],
        ),
      ],
    );
  }
}
