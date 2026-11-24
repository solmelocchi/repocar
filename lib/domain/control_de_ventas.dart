import 'models/pieza.dart';

// =====================================================================
// REGLA DEL NEGOCIO: señales de una venta que pudo haberse ido por fuera.
//
// Ramallo preguntó cómo verificar que los talleres no vendan por fuera
// de la app (y no le paguen la comisión). Ninguna app lo puede impedir
// del todo, pero hay una señal clara: una publicación que RECIBIÓ
// PREGUNTAS y después el taller la pausó o la borró SIN VENDERLA por
// RepoCar. Puede ser algo normal (la vendió en el mostrador del taller),
// pero vale la pena revisarlo.
// =====================================================================

/// Si esta publicación es una señal para revisar.
bool esSenalDeVentaPorFuera(Pieza pieza, {required int preguntas}) =>
    preguntas > 0 && !pieza.vendida && (pieza.pausada || pieza.borrada);

/// Qué pasó con la publicación, para mostrarlo.
String motivoDeLaSenal(Pieza pieza) =>
    pieza.borrada ? 'la borraron sin venderla' : 'la pausaron sin venderla';
