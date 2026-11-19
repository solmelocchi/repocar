import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// La firma del APK de release. La clave y sus contraseñas están en
// android/key.properties y android/app/repocar-release.jks, que NO se
// comparten (están en .gitignore). Si no están, se firma con la de debug.
val propiedadesDeFirma = Properties()
val archivoDeFirma = rootProject.file("key.properties")
if (archivoDeFirma.exists()) {
    propiedadesDeFirma.load(FileInputStream(archivoDeFirma))
}

android {
    namespace = "com.example.repocar"
    // 37 y no el de Flutter (36): flutter_local_notifications trae
    // androidx.core 1.19, que pide compilar contra Android 37. Esto NO
    // cambia en qué teléfonos se instala (eso es minSdk).
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications usa APIs de fechas nuevas: el
        // desugaring las hace andar también en Android viejos.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.repocar"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (archivoDeFirma.exists()) {
                keyAlias = propiedadesDeFirma["keyAlias"] as String
                keyPassword = propiedadesDeFirma["keyPassword"] as String
                storeFile = file(propiedadesDeFirma["storeFile"] as String)
                storePassword = propiedadesDeFirma["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (archivoDeFirma.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
