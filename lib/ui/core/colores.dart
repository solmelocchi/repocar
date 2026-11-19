import 'package:flutter/material.dart';

import '../../domain/models/pedido.dart';

/// Colores de la marca: azul de taller y naranja de señalización.
const azul = Color(0xFF14346B);
const naranja = Color(0xFFF07A1A);
const verde = Color(0xFF15704A);
const ambar = Color(0xFFB35E00);
const azulClaro = Color(0xFFEDF1F8);

/// El color del cartelito de estado de un pedido.
/// Vive acá y no en el modelo: el dominio no conoce material.dart.
Color colorDeEstado(EstadoPedido estado) => switch (estado) {
  EstadoPedido.pagado => ambar,
  EstadoPedido.enviado => azul,
  EstadoPedido.entregado => verde,
};
