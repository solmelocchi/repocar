import 'package:flutter/material.dart';

import '../../domain/models/pedido.dart';

/// Colores de la marca: azul de taller y naranja de señalización.
const azul = Color(0xFF14346B);
const naranja = Color(0xFFF07A1A);
const verde = Color(0xFF15704A);
const ambar = Color(0xFFB35E00);
const azulClaro = Color(0xFFEDF1F8);

/// El gris del texto secundario (ayudas, fechas, aclaraciones). Antes era
/// Colors.black45 o black54: sobre el fondo gris claro daba un contraste
/// de 3,3 a 4,4, por debajo del mínimo de 4,5 que piden las guías de
/// accesibilidad. Este da 5,5 sobre el fondo y 6 sobre blanco: se lee
/// bien también con la vista cansada.
const grisTexto = Color(0xFF5F6368);

/// El color del cartelito de estado de un pedido.
/// Vive acá y no en el modelo: el dominio no conoce material.dart.
Color colorDeEstado(EstadoPedido estado) => switch (estado) {
  EstadoPedido.pagado => ambar,
  EstadoPedido.enviado => azul,
  EstadoPedido.entregado => verde,
};
