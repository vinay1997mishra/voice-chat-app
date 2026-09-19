plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "ai.anamika.app"
    compileSdk = 35

    defaultConfig {
        applicationId = "ai.anamika.app"
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField("String", "ANAMIKA_API_BASE_URL", "\"https://example.invalid\"")
        buildConfigField("String", "ANAMIKA_DISTRIBUTION_MODE", "\"OWNER\"")
        buildConfigField("String", "ANAMIKA_OWNER_POLICY_URL", "\"https://example.invalid/entitlements\"")
        buildConfigField("String", "ANAMIKA_OWNER_POLICY_PUBLIC_KEY", "\"\"")
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"\"")
        buildConfigField("String", "ANAMIKA_PUBLIC_AUTH_URL", "\"https://example.invalid/auth/google\"")
        buildConfigField("String", "ANAMIKA_POLICY_BASE_URL", "\"https://example.invalid\"")
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        debug {
            buildConfigField("String", "ANAMIKA_DISTRIBUTION_MODE", "\"OWNER\"")
        }
        release {
            isMinifyEnabled = false
            buildConfigField("String", "ANAMIKA_DISTRIBUTION_MODE", "\"PUBLIC\"")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    implementation("org.eclipse.jgit:org.eclipse.jgit:6.10.0.202406032230-r")
    implementation("androidx.core:core:1.15.0")
    implementation("androidx.credentials:credentials:1.6.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.6.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
    testImplementation("junit:junit:4.13.2")
}
