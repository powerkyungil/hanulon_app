import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use(keystoreProperties::load)
}

fun signingValue(propertyName: String, environmentName: String): String? {
    return keystoreProperties.getProperty(propertyName)?.takeIf(String::isNotBlank)
        ?: System.getenv(environmentName)?.takeIf(String::isNotBlank)
}

val releaseKeyAlias = signingValue("keyAlias", "ANDROID_UPLOAD_KEY_ALIAS")
val releaseKeyPassword = signingValue(
    "keyPassword",
    "ANDROID_UPLOAD_KEY_PASSWORD",
)
val releaseStorePassword = signingValue(
    "storePassword",
    "ANDROID_UPLOAD_STORE_PASSWORD",
)
val releaseStoreFilePath = signingValue(
    "storeFile",
    "ANDROID_UPLOAD_STORE_FILE",
)
val releaseStoreFile = releaseStoreFilePath?.let(rootProject::file)
val hasReleaseSigning = releaseKeyAlias != null &&
    releaseKeyPassword != null &&
    releaseStorePassword != null &&
    releaseStoreFile?.isFile == true

if (isReleaseBuild && !hasReleaseSigning) {
    throw GradleException(
        "배포용 업로드 키 설정이 없습니다. docs/release-deployment.md를 확인해 주세요.",
    )
}

android {
    namespace = "com.odinguild.odin_guild_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.odinguild.odin_guild_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        multiDexEnabled = true
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
                storeFile = releaseStoreFile
                storePassword = releaseStorePassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
