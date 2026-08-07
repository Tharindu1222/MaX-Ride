import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

fun loadDotEnv(file: File): Map<String, String> {
    if (!file.exists()) return emptyMap()
    return file.readLines()
        .map { it.trim() }
        .filter { it.isNotEmpty() && !it.startsWith("#") && it.contains("=") }
        .associate { line ->
            val idx = line.indexOf('=')
            val key = line.substring(0, idx).trim()
            val value = line.substring(idx + 1).trim().trim('"').trim('\'')
            key to value
        }
}

fun resolveMapsApiKey(androidRoot: File): String {
    System.getenv("GOOGLE_MAPS_API_KEY")?.takeIf { it.isNotBlank() }?.let { return it }
    System.getenv("MAPS_API_KEY")?.takeIf { it.isNotBlank() }?.let { return it }

    val monorepoRoot = androidRoot.resolve("../../..").canonicalFile
    for (file in listOf(monorepoRoot.resolve(".env"), monorepoRoot.resolve("apps/api/.env"))) {
        val map = loadDotEnv(file)
        map["GOOGLE_MAPS_API_KEY"]?.takeIf { it.isNotBlank() }?.let { return it }
        map["MAPS_API_KEY"]?.takeIf { it.isNotBlank() }?.let { return it }
    }

    val localProperties = Properties()
    val localPropertiesFile = androidRoot.resolve("local.properties")
    if (localPropertiesFile.exists()) {
        localProperties.load(FileInputStream(localPropertiesFile))
    }
    localProperties.getProperty("maps.apiKey")?.takeIf { it.isNotBlank() }?.let { return it }
    localProperties.getProperty("GOOGLE_MAPS_API_KEY")?.takeIf { it.isNotBlank() }?.let { return it }
    return ""
}

val mapsApiKey: String = resolveMapsApiKey(rootProject.projectDir)
if (mapsApiKey.isNotBlank()) {
    val lp = rootProject.projectDir.resolve("local.properties")
    val props = Properties()
    if (lp.exists()) props.load(FileInputStream(lp))
    if (props.getProperty("maps.apiKey") != mapsApiKey) {
        props.setProperty("maps.apiKey", mapsApiKey)
        lp.writer().use { props.store(it, "Updated by MaX Ride maps key resolver") }
    }
}
if (mapsApiKey.isBlank()) {
    logger.warn("GOOGLE_MAPS_API_KEY is empty. Set it in apps/api/.env or environment.")
} else {
    logger.lifecycle("Google Maps API key loaded (${mapsApiKey.take(8)}…)")
}

android {
    namespace = "com.maxride.driver_app"
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
        applicationId = "com.maxride.driver_app"
        minSdk = maxOf(flutter.minSdkVersion, 21)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
