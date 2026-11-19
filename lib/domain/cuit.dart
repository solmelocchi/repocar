// =====================================================================
// DOMINIO: la regla del CUIT.
// Es una regla de negocio pura, sin pantallas ni datos de afuera, así
// que se puede probar sola. Por eso no vive en una pantalla.
// =====================================================================

/// Deja solo los números: '30-71234567-1' queda '30712345671'.
String soloNumeros(String texto) => texto.replaceAll(RegExp(r'[^0-9]'), '');

/// Valida el CUIT con el dígito verificador, el mismo cálculo que usa
/// ARCA. Así la app se da cuenta de que el número está bien formado y no
/// son once números cualquiera. OJO: no consulta a ARCA, así que no
/// prueba que el contribuyente exista: eso necesitaría su servicio web.
bool cuitValido(String texto) {
  final digitos = soloNumeros(texto);
  if (digitos.length != 11) return false;

  // 20, 23, 24 y 27 son personas (monotributistas);
  // 30, 33 y 34 son empresas. Cualquier otro prefijo no existe.
  const prefijos = ['20', '23', '24', '27', '30', '33', '34'];
  if (!prefijos.contains(digitos.substring(0, 2))) return false;

  const multiplicadores = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];
  var suma = 0;
  for (var i = 0; i < 10; i++) {
    suma += int.parse(digitos[i]) * multiplicadores[i];
  }

  var verificador = 11 - (suma % 11);
  if (verificador == 11) verificador = 0;
  if (verificador == 10) return false; // ese CUIT no existe

  return verificador == int.parse(digitos[10]);
}

/// Muestra el CUIT como 30-71234567-1.
String formatearCuit(String texto) {
  final digitos = soloNumeros(texto);
  if (digitos.length != 11) return texto;
  return '${digitos.substring(0, 2)}-${digitos.substring(2, 10)}-'
      '${digitos.substring(10)}';
}
