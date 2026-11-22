import java.io.File
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val updateDownloadHost = providers.gradleProperty("dart-defines").orNull.orEmpty().split(",").mapNotNull { runCatching { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }.getOrNull() }.firstOrNull { it.startsWith("UPDATE_DOWNLOAD_HOST=") }?.substringAfter("=") ?: ""
require(updateDownloadHost.matches(Regex("^[a-z0-9.-]*$"))) { "Invalid update download hostname" }

android {
    buildFeatures { buildConfig = true }
    namespace = "com.rayeq.rayeq"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.rayeq.rayeq"
        buildConfigField("String", "UPDATE_DOWNLOAD_HOST", "\"$updateDownloadHost\"")
        ndk { abiFilters += listOf("arm64-v8a") }
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs.useLegacyPackaging = true
        jniLibs.excludes += setOf("**/x86_64/**", "**/armeabi-v7a/**")
    }
    val releaseStore = System.getenv("RAYEQ_STORE_FILE")
    val releasePasswordFile = System.getenv("RAYEQ_STORE_PASSWORD_FILE")
    require((releaseStore == null) == (releasePasswordFile == null)) {
        "Set both RAYEQ_STORE_FILE and RAYEQ_STORE_PASSWORD_FILE, or neither for an unsigned artifact."
    }
    if (releaseStore != null && releasePasswordFile != null) {
        signingConfigs.create("rayeqRelease") {
            storeFile = File(releaseStore)
            storePassword = File(releasePasswordFile).readText().trimEnd('\n', '\r')
            keyAlias = "rayeq"
            keyPassword = storePassword
            storeType = "PKCS12"
        }
    }
    buildTypes {
        release {
            // Never ship a development key. Without the private inputs this is unsigned.
            signingConfig = signingConfigs.findByName("rayeqRelease")
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
