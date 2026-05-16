// ไฟล์: android/app/build.gradle.kts (ฉบับสมบูรณ์)
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ✅ 1. ส่วนโหลดไฟล์ key.properties (กุญแจ)
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.sorbolikan.slink"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ 2. ใช้ Java 17 เพื่อแก้ Warning "obsolete value 8"
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
  
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.sorbolikan.slink"
        
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

      
        multiDexEnabled = true
    }

    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }

    // ✅ 3. ตั้งค่าลายเซ็น (Signing Config) สำหรับ Release
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // ✅ เรียกใช้ลายเซ็น release (ห้ามใช้ debug สำหรับ Play Store)
            signingConfig = signingConfigs.getByName("release")
            
            // การตั้งค่าเพิ่มเติม (Optional)
            isMinifyEnabled = false
        
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}