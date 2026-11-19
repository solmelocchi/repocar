/// Formato de precios, en un solo lugar.
/// Muestra 85000 como "$ 85.000".
String pesos(int valor) {
  final s = valor.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write('.');
    buffer.write(s[i]);
  }
  return '\$ $buffer';
}
