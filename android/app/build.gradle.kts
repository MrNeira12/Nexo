plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.pruebas"
    
    // Nivel de compilación actualizado
    compileSdk = 36
    
    // NDK específica requerida por los renderizadores de PDF nativos
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.example.pruebas"
        
        // CORRECCIÓN: pdfx requiere mínimo 21, pero Firebase 23. Forzamos 23.
        minSdk = flutter.minSdkVersion 
        
        targetSdk = 36
        
        versionCode = 1
        versionName = "1.0"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Implementación de Firebase BoM
    implementation(platform("com.google.firebase:firebase-bom:33.1.0"))
    implementation("com.google.firebase:firebase-analytics")
    
    // Dependencias fundamentales para el proyecto Nexo
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-firestore")
    implementation("com.google.firebase:firebase-storage")
    
    // Soporte para componentes nativos de Kotlin/Android
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:1.8.22")
}
