plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.distributed_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.distributed_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    flavorDimensions += "default"
    productFlavors {
        create("development") {
            dimension = "default"
            resValue(type = "string", name = "app_name", value = "Distributed App development")
            namespace = "com.example.distributed_app.dev"
            applicationId = "com.example.distributed_app.dev"
        }
        create("staging") {
            dimension = "default"
            resValue(type = "string", name = "app_name", value = "Distributed App staging")
            namespace = "com.example.distributed_app.staging"
            applicationId = "com.example.distributed_app.staging"
        }
        create("production") {
            dimension = "default"
            resValue(type = "string", name = "app_name", value = "Distributed App")
            namespace = "com.example.distributed_app"
        }
    }
}

flutter {
    source = "../.."
}
