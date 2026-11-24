import 'package:flutter/material.dart';

import '../../../dependencias.dart';
import '../../../domain/models/auto.dart';
import '../../../domain/models/pieza.dart';
import '../../core/aviso.dart';
import '../../core/colores.dart';
import '../../core/formato.dart';
import '../../preguntas/widgets/preguntas_de_pieza.dart';
import '../../taller/widgets/publicar_screen.dart';
import 'boton_carrito.dart';
import 'etiqueta_estado.dart';
import 'foto_pieza.dart';

/// La ficha del repuesto.
/// El auto puede venir o no: si entraste por la búsqueda, se confirma
/// que la pieza le sirve; si entraste desde el inicio, se muestran los
/// autos para los que sirve y listo.
///
/// Si la abre el TALLER DUEÑO, en vez de comprar ve su publicación como
/// la ve el comprador, y el botón para editarla.
class DetalleScreen extends StatelessWidget {
  final Pieza pieza;
  final Auto? auto;
  final Dependencias deps;

  const DetalleScreen({
    super.key,
    required this.pieza,
    required this.deps,
    this.auto,
  });

  bool get _esDelTaller => deps.sesion.taller?.cuit == pieza.taller.cuit;

  @override
  Widget build(BuildContext context) {
    // Escucha al catálogo: si el taller la edita, la ficha se actualiza.
    return ListenableBuilder(
      listenable: deps.catalogo,
      builder: (context, _) =>
          _ficha(context, deps.catalogo.buscarPorId(pieza.id) ?? pieza),
    );
  }

  Widget _ficha(BuildContext context, Pieza pieza) {
    final miAuto = auto;
    final esDelTaller = _esDelTaller;

    return Scaffold(
      appBar: AppBar(
        title: Text(esDelTaller ? 'Tu publicación' : 'Detalle del repuesto'),
        actions: [if (!esDelTaller) BotonCarrito(deps: deps)],
      ),
      body: ListView(
        children: [
          FotoPieza(
            pieza: pieza,
            ancho: double.infinity,
            alto: 260,
            radio: 0,
            tamanoIcono: 90,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    EtiquetaEstado(estado: pieza.estado),
                    if (pieza.vendida) ...[
                      const SizedBox(width: 8),
                      const Chip(
                        label: Text('Vendida'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  pieza.titulo,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  pesos(pieza.precio),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: azul,
                  ),
                ),
                if (pieza.taller.tieneCadete) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Envío con el cadete del taller',
                    style: TextStyle(color: verde, fontWeight: FontWeight.w600),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  pieza.descripcion,
                  style: const TextStyle(fontSize: 15, height: 1.5),
                ),
                const SizedBox(height: 20),

                // Confirmación de que le sirve a SU auto.
                if (miAuto != null)
                  Card(
                    color: const Color(0xFFDDF1E6),
                    elevation: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, color: verde),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Compatible con tu $miAuto',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: verde,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  miAuto == null ? 'Sirve para:' : 'También sirve para:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in pieza.compatibles)
                      Chip(
                        label: Text(
                          c.texto,
                          style: const TextStyle(fontSize: 12),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // El vendedor.
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.store)),
                  title: Text(pieza.taller.nombre),
                  // Sin el teléfono: antes de comprar, las consultas van por
                  // las preguntas de abajo, así la venta queda en RepoCar.
                  subtitle: Text(pieza.taller.zona),
                ),
                const SizedBox(height: 12),

                if (esDelTaller)
                  ..._accionesDelTaller(context, pieza)
                else
                  ..._accionesDelComprador(context, pieza),
              ],
            ),
          ),
          PreguntasDePieza(
            deps: deps,
            pieza: pieza,
            esDelTaller: esDelTaller,
            sugerencia: miAuto == null ? null : '¿Le sirve a mi $miAuto?',
          ),
        ],
      ),
    );
  }

  List<Widget> _accionesDelComprador(BuildContext context, Pieza pieza) => [
    // Escucha al carrito: si la agregás, el botón cambia solo.
    ListenableBuilder(
      listenable: deps.carrito,
      builder: (context, _) {
        final enCarrito = deps.carrito.contiene(pieza);
        return FilledButton.icon(
          onPressed: (!pieza.aLaVenta || enCarrito)
              ? null
              : () => _agregar(context, pieza),
          icon: Icon(enCarrito ? Icons.check : Icons.add_shopping_cart),
          label: Text(
            pieza.vendida
                ? 'Ya se vendió'
                : enCarrito
                ? 'Ya está en tu carrito'
                : 'Agregar al carrito',
          ),
        );
      },
    ),
    const SizedBox(height: 6),
    const Text(
      'Es un repuesto usado: hay una sola unidad.',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 12, color: Colors.black45),
    ),
  ];

  List<Widget> _accionesDelTaller(BuildContext context, Pieza pieza) => [
    if (pieza.vendida)
      const Text(
        'Esta pieza ya se vendió: queda en tu lista para que veas el '
        'pedido, pero no se puede editar.',
        style: TextStyle(fontSize: 13, color: Colors.black54),
      )
    else ...[
      if (pieza.pausada)
        Card(
          color: const Color(0xFFFFF3E0),
          margin: const EdgeInsets.only(bottom: 12),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              'Está pausada: los compradores no la ven hasta que la vuelvas '
              'a publicar.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
      FilledButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PublicarScreen(deps: deps, pieza: pieza),
          ),
        ),
        icon: const Icon(Icons.edit),
        label: const Text('Editar publicación'),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () => deps.catalogo.pausar(pieza, pausada: !pieza.pausada),
        icon: Icon(pieza.pausada ? Icons.play_arrow : Icons.pause),
        label: Text(pieza.pausada ? 'Volver a publicar' : 'Pausar publicación'),
        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
      ),
      const SizedBox(height: 6),
      TextButton.icon(
        onPressed: () => _borrar(context, pieza),
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        label: const Text(
          'Borrar publicación',
          style: TextStyle(color: Colors.red),
        ),
      ),
    ],
  ];

  /// Pregunta antes: borrar no se puede deshacer desde la app.
  Future<void> _borrar(BuildContext context, Pieza pieza) async {
    final seguro = await showDialog<bool>(
      context: context,
      builder: (dialogo) => AlertDialog(
        title: const Text('¿Borrar la publicación?'),
        content: Text(
          '"${pieza.titulo}" deja de verse en el catálogo. Si la querés '
          'sacar solo por un tiempo, mejor pausala.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogo, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogo, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              minimumSize: const Size(100, 44),
            ),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (seguro != true || !context.mounted) return;
    await deps.catalogo.borrar(pieza);
    if (context.mounted) Navigator.pop(context);
  }

  /// Agrega al carrito y avisa con un cartel que se va solo.
  void _agregar(BuildContext context, Pieza pieza) {
    deps.carrito.agregar(pieza);
    avisar(context, 'Agregado al carrito');
  }
}
