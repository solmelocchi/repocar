---
name: antes-de-entregar
description: La lista de control antes de una entrega o de mostrar RepoCar - formato, analizador, pruebas, APK firmado y web publicada. Usala antes de cada entrega, después de un cambio grande o cuando pidan "dejalo listo".
---

# Antes de entregar RepoCar

Hacé los pasos en orden. Si uno falla, se arregla antes de seguir: no se saltea nada.

## 1. El código

```bash
dart format lib test
flutter analyze
flutter test
```

- `dart format` no tiene que cambiar nada después de formatear.
- `flutter analyze`: **sin errores ni avisos**. Si un aviso se deja a propósito, va con un comentario que explique por qué.
- `flutter test`: todas en verde. No se modifica una prueba para que pase: se arregla el código.

## 2. Android

```bash
flutter build apk --release
```

- Se firma con `android/key.properties` (nunca mostrar ni copiar su contenido).
- Copiá `build/app/outputs/flutter-apk/app-release.apk` a `../RepoCar - para instalar/RepoCar.apk`. Como la firma es siempre la misma, se instala encima de la versión anterior.

## 3. Web y servidor

```bash
flutter build web --release
firebase.cmd deploy --only hosting --project repocar-8cad3
```

Si cambió `firestore.rules`:

```bash
firebase.cmd deploy --only firestore:rules --project repocar-8cad3
```

Abrí https://repocar-8cad3.web.app y fijate que arranque sin errores en la consola.

## 4. Lo que se muestra

- `README.md`: cómo correr la app y las pruebas, y la estructura **actual** de carpetas.
- `CLAUDE.md` y las skills: que describan el código como está hoy.
- Contale al grupo qué cambió desde la última entrega, en dos o tres frases.
