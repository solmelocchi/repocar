import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// =====================================================================
// LA BASE DEL SERVIDOR, vista como contrato.
//
// Cuatro cosas: leer una colección, guardar un documento, ESCUCHAR una
// colección y pedir el próximo número de un contador. Escuchar devuelve
// un Stream: cada vez que alguien (otro teléfono) cambia algo, llega la
// lista nueva.
//
// La versión de verdad es Firestore (Firebase). En los tests se usa una
// falsa en memoria, así se prueba sin internet.
// =====================================================================
abstract class BaseRemota {
  Future<List<Map<String, dynamic>>> leer(
    String coleccion, {
    String? campo,
    Object? igualA,
  });

  Future<void> guardar(String coleccion, String id, Map<String, dynamic> dato);

  Stream<List<Map<String, dynamic>>> escuchar(String coleccion);

  /// El próximo número de un contador compartido (por ejemplo, el de los
  /// pedidos). Lo da el SERVIDOR, así dos teléfonos nunca reciben el
  /// mismo. Si el contador no existe, arranca después de [minimo].
  Future<int> siguienteNumero(String contador, {required int minimo});
}

/// Firestore: la base de Firebase. Guarda documentos (mapas) adentro de
/// colecciones, igual que el JSON que ya usan los servicios.
class BaseFirestore implements BaseRemota {
  BaseFirestore({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  @override
  Future<List<Map<String, dynamic>>> leer(
    String coleccion, {
    String? campo,
    Object? igualA,
  }) async {
    Query<Map<String, dynamic>> consulta = _db.collection(coleccion);
    if (campo != null) consulta = consulta.where(campo, isEqualTo: igualA);
    final resultado = await consulta.get();
    return [for (final documento in resultado.docs) documento.data()];
  }

  @override
  Future<void> guardar(
    String coleccion,
    String id,
    Map<String, dynamic> dato,
  ) => _db.collection(coleccion).doc(id).set(dato);

  /// Escucha la colección MIENTRAS haya alguien con la sesión abierta.
  ///
  /// Por qué así: las reglas no dejan leer sin sesión. Cuando alguien
  /// cierra sesión, Firestore corta la escucha con un error y no la
  /// vuelve a abrir sola. Entonces se escucha también quién está adentro
  /// (authStateChanges, otro Stream): cada vez que entra alguien, se abre
  /// una escucha nueva; cuando sale, se cierra.
  @override
  Stream<List<Map<String, dynamic>>> escuchar(String coleccion) {
    StreamSubscription<User?>? sesion;
    StreamSubscription<List<Map<String, dynamic>>>? datos;
    late final StreamController<List<Map<String, dynamic>>> salida;

    salida = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        sesion = _auth.authStateChanges().listen((usuario) {
          datos?.cancel();
          datos = null;
          if (usuario == null) return;
          datos = _db
              .collection(coleccion)
              .snapshots()
              .map((foto) => [for (final doc in foto.docs) doc.data()])
              .listen(
                salida.add,
                // Un error (sin permiso, sin red) no corta la salida: la
                // próxima vez que entre alguien se vuelve a escuchar.
                onError: (_) {},
              );
        });
      },
      onCancel: () async {
        await datos?.cancel();
        await sesion?.cancel();
      },
    );
    return salida.stream;
  }

  /// Una TRANSACCIÓN: lee el último número y guarda el siguiente en un
  /// solo paso. Si dos teléfonos piden a la vez, Firestore repite la de
  /// uno de ellos, así nunca salen dos números iguales.
  @override
  Future<int> siguienteNumero(String contador, {required int minimo}) {
    final documento = _db.collection('contadores').doc(contador);
    return _db.runTransaction((transaccion) async {
      final actual = await transaccion.get(documento);
      final ultimo = actual.exists
          ? (actual.data()!['ultimo'] as num).toInt()
          : minimo;
      final siguiente = ultimo + 1;
      transaccion.set(documento, {'ultimo': siguiente});
      return siguiente;
    });
  }
}
