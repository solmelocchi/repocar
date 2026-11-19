import 'dart:convert';

import 'package:crypto/crypto.dart';

// =====================================================================
// DOMINIO: la contraseña nunca se guarda.
//
// Lo que se guarda es su huella (un hash). Cuando alguien entra, se
// calcula la huella de lo que escribió y se compara con la guardada:
// así, aunque alguien abra la base del teléfono, no ve ninguna clave.
// =====================================================================
String hashDeClave(String clave) =>
    sha256.convert(utf8.encode('repocar:$clave')).toString();
