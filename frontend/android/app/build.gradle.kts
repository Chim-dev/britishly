import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ------------------------------------------------------------------
// Penandatanganan rilis (release signing)
//
// Kredensial dibaca dari android/key.properties. File itu berisi password,
// jadi TIDAK boleh masuk git — sudah tercantum di android/.gitignore.
// Contoh isinya ada di android/key.properties.example
// ------------------------------------------------------------------
val fileKeyProperties = rootProject.file("key.properties")
val adaKeyProperties = fileKeyProperties.exists()
val keyProperties = Properties().apply {
    if (adaKeyProperties) {
        FileInputStream(fileKeyProperties).use { load(it) }
    }
}

// Build debug tetap berjalan normal tanpa keystore. Build RILIS sengaja
// dihentikan kalau key.properties belum ada.
//
// Sebelumnya rilis ditandatangani memakai debug key. Debug key itu bawaan
// Android SDK dan passwordnya publik ("android"), jadi siapa pun bisa
// membuat APK yang dianggap sistem sebagai update resmi aplikasi ini —
// dan Play Store menolak APK yang ditandatangani dengannya.
val sedangBuildRilis = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}
if (sedangBuildRilis && !adaKeyProperties) {
    throw GradleException(
        "\n\n" +
        "==================================================================\n" +
        " Build RILIS dibatalkan: android/key.properties tidak ditemukan.\n" +
        "\n" +
        " Aplikasi rilis harus ditandatangani dengan keystore milikmu sendiri.\n" +
        " Cara membuatnya ada di: android/key.properties.example\n" +
        "==================================================================\n"
    )
}

android {
    namespace = "com.britishly.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "30.0.16138531"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.britishly.app"
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
        if (adaKeyProperties) {
            create("release") {
                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Kalau key.properties belum ada, build rilis sudah dihentikan
            // lebih dulu di atas — jadi baris ini tidak pernah menghasilkan
            // APK rilis tanpa tanda tangan.
            signingConfig = if (adaKeyProperties) {
                signingConfigs.getByName("release")
            } else {
                null
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
