plugins {
    id("com.android.application")
    id("kotlin-android")
    id("org.jetbrains.kotlin.plugin.compose") version "2.2.20"
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.payday"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        compose = true
    }

    defaultConfig {
        applicationId = "com.example.payday"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val releaseStoreFile = System.getenv("PAYDAY_KEYSTORE_PATH")
    val releaseStorePassword = System.getenv("PAYDAY_KEYSTORE_PASSWORD")
    val releaseKeyAlias = System.getenv("PAYDAY_KEY_ALIAS")
    val releaseKeyPassword = System.getenv("PAYDAY_KEY_PASSWORD")
    val releaseSigningConfigured = !releaseStoreFile.isNullOrBlank() &&
        !releaseStorePassword.isNullOrBlank() &&
        !releaseKeyAlias.isNullOrBlank() &&
        !releaseKeyPassword.isNullOrBlank()
    val releaseRequested = gradle.startParameter.taskNames.any {
        it.contains("Release", ignoreCase = true)
    }
    if (releaseRequested && !releaseSigningConfigured) {
        throw GradleException(
            "Signed release builds require PAYDAY_KEYSTORE_PATH, " +
                "PAYDAY_KEYSTORE_PASSWORD, PAYDAY_KEY_ALIAS and PAYDAY_KEY_PASSWORD."
        )
    }

    signingConfigs {
        create("paydayRelease") {
            if (releaseSigningConfigured) {
                storeFile = file(releaseStoreFile!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("paydayRelease")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.android.material:material:1.13.0")
    implementation("androidx.concurrent:concurrent-futures:1.3.0")

    // Jetpack Compose for ReminderActivity
    val composeBom = platform("androidx.compose:compose-bom:2024.06.00")
    implementation(composeBom)
    implementation("androidx.compose.ui:ui")
    implementation("androidx.compose.ui:ui-tooling-preview")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.activity:activity-compose:1.9.0")
}
