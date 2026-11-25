import 'package:flutter/material.dart';

import 'colores.dart';

/// El tema de RepoCar: los colores de la marca, el fondo gris muy claro
/// y las tarjetas blancas. Está acá y no adentro de main.dart para que
/// las pruebas de accesibilidad dibujen las pantallas con los mismos
/// colores que la app de verdad.
ThemeData temaRepoCar() => ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: azul,
    primary: azul,
    secondary: naranja,
  ),
  useMaterial3: true,
  // Fondo gris muy claro y tarjetas blancas: así las tarjetas se
  // separan solas, sin bordes pesados.
  scaffoldBackgroundColor: const Color(0xFFF3F5F9),
  appBarTheme: const AppBarTheme(
    backgroundColor: azul,
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0xFFE3E7EF)),
    ),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: azulClaro,
    surfaceTintColor: Colors.transparent,
    labelTextStyle: WidgetStateProperty.all(
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: Colors.white,
    selectedColor: azulClaro,
    side: const BorderSide(color: Color(0xFFE3E7EF)),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    ),
  ),
);
