import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/preguntas_service.dart';

// =====================================================================
// Las preguntas en Firestore, colección "preguntas".
//
// Las reglas del servidor dicen: las ve cualquiera (como en una tienda),
// pregunta quien inició sesión (con su propio usuario) y responde SOLO el
// taller dueño de la pieza, sin poder tocar la pregunta.
// =====================================================================
class PreguntasFirestore implements PreguntasService {
  CollectionReference<Map<String, dynamic>> get _preguntas =>
      FirebaseFirestore.instance.collection('preguntas');

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// Sin señal, Firestore deja lo escrito en cola y lo manda cuando
  /// vuelve: no se espera más de unos segundos para no trabar la pantalla.
  static const _espera = Duration(seconds: 5);

  /// snapshots(): un Stream que trae la lista de nuevo cada vez que algo
  /// cambia en el servidor. Si falla (sin permiso), se ignora.
  Stream<List<Map<String, dynamic>>> _escuchar(
    Query<Map<String, dynamic>> consulta,
  ) => consulta
      .snapshots()
      .map((foto) => [for (final documento in foto.docs) documento.data()])
      .handleError((Object _) {});

  @override
  Stream<List<Map<String, dynamic>>> dePieza(String piezaId) =>
      _escuchar(_preguntas.where('pieza_id', isEqualTo: piezaId));

  @override
  Stream<List<Map<String, dynamic>>> deTaller(String tallerCuit) =>
      _escuchar(_preguntas.where('taller_cuit', isEqualTo: tallerCuit));

  @override
  Stream<List<Map<String, dynamic>>> mias() {
    final uid = _uid;
    if (uid == null) return Stream.value(const []);
    return _escuchar(_preguntas.where('autor_uid', isEqualTo: uid));
  }

  @override
  Future<void> crear(Map<String, dynamic> pregunta) => _preguntas
      .doc(pregunta['id'] as String)
      .set({...pregunta, 'autor_uid': _uid})
      .timeout(_espera, onTimeout: () {});

  @override
  Future<void> responder(
    String id, {
    required String respuesta,
    required DateTime cuando,
  }) => _preguntas
      .doc(id)
      .update({'respuesta': respuesta, 'respondida': cuando.toIso8601String()})
      .timeout(_espera, onTimeout: () {});
}
