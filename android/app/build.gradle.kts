import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val veepooSdkArtifacts =
    listOf(
        "vpprotocol-2.3.77.15.aar",
        "vpbluetooth-1.20.aar",
        "abpartool-release.aar",
    )
val veepooSdkFiles = veepooSdkArtifacts.map { file("libs/$it") }
val hasAnyVeepooArtifact = veepooSdkFiles.any { it.isFile }
val hasCompleteVeepooSdk = veepooSdkFiles.all { it.isFile }
val signingPropertiesFile = rootProject.file("key.properties")
val signingProperties = Properties().apply {
    if (signingPropertiesFile.isFile) {
        signingPropertiesFile.inputStream().use(::load)
    }
}
val playSigningPropertiesFile = rootProject.file("play-upload.properties")
val playSigningProperties = Properties().apply {
    if (playSigningPropertiesFile.isFile) {
        playSigningPropertiesFile.inputStream().use(::load)
    }
}
val jpushAppKey =
    providers.gradleProperty("JPUSH_APPKEY")
        .orElse(providers.environmentVariable("JPUSH_APP_KEY"))
        .orNull
        ?.trim()
        .orEmpty()
val jpushChannel =
    providers.gradleProperty("JPUSH_CHANNEL")
        .orElse(providers.environmentVariable("JPUSH_CHANNEL"))
        .orNull
        ?.trim()
        .orEmpty()
val wechatAppId =
    providers.gradleProperty("WECHAT_APP_ID")
        .orElse(providers.environmentVariable("WECHAT_APP_ID"))
        .orElse("")
        .get()
        .trim()
fun releaseModeFlag(name: String): Boolean {
    val value = providers.environmentVariable(name).orNull?.trim()?.lowercase().orEmpty()
    return when (value) {
        "", "false" -> false
        "true" -> true
        else -> throw GradleException("$name must be true, false, or unset")
    }
}

val productionReleaseRequested = releaseModeFlag("SAIDIAN_PRODUCTION_RELEASE")
val qaReleaseAllowed = releaseModeFlag("SAIDIAN_ALLOW_QA_RELEASE")
val playStoreDartDefine =
    providers.gradleProperty("dart-defines").orNull.orEmpty()
        .split(',')
        .any { encoded ->
            runCatching {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8) ==
                    "SAIDIAN_PLAY_STORE=true"
            }.getOrDefault(false)
        }
// The production App supports physical ARM devices only.  Local Android
// emulators are x86_64, so permit that ABI only when the explicit Debug-only
// switch is supplied.  Release tasks below reject this switch.
val emulatorDebugRequested = releaseModeFlag("SAIDIAN_EMULATOR_DEBUG")
val debugEmulatorAbis = if (emulatorDebugRequested) setOf("x86_64") else emptySet()
val splitPerAbiRequested = providers.gradleProperty("split-per-abi").orNull == "true"
val updateManifestUrl =
    providers.environmentVariable("SAYDIAN_UPDATE_MANIFEST_URL")
        .orNull
        ?.trim()
        .orEmpty()
val apiBaseUrl =
    providers.environmentVariable("SAYDIAN_API_BASE_URL")
        .orNull
        ?.trim()
        .orEmpty()
val updateAllowedHosts =
    providers.environmentVariable("SAYDIAN_UPDATE_ALLOWED_HOSTS")
        .orNull
        ?.trim()
        .orEmpty()
val jpushVendorChannels =
    providers.environmentVariable("JPUSH_VENDOR_CHANNELS")
        .orNull
        ?.trim()
        .orEmpty()
val enabledJpushVendorChannels =
    jpushVendorChannels
        .split(',')
        .map { it.trim().lowercase() }
        .filter(String::isNotEmpty)
        .toSet()
val huaweiPushEnabled = "huawei" in enabledJpushVendorChannels
if (huaweiPushEnabled) {
    val huaweiConfig = file("agconnect-services.json")
    if (!huaweiConfig.isFile) {
        throw GradleException(
            "Huawei push is enabled but android/app/agconnect-services.json is missing",
        )
    }
    apply(from = "huawei-agconnect.gradle")
}
val productionSigningValues =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .associateWith { signingProperties.getProperty(it)?.trim().orEmpty() }
val productionStoreFile =
    productionSigningValues.getValue("storeFile")
        .takeIf(String::isNotEmpty)
        ?.let(::file)
val hasCompleteProductionSigning =
    signingPropertiesFile.isFile &&
        productionSigningValues.values.all(String::isNotEmpty) &&
        productionStoreFile?.isFile == true
val playSigningValues =
    listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        .associateWith { playSigningProperties.getProperty(it)?.trim().orEmpty() }
val playStoreFile =
    playSigningValues.getValue("storeFile")
        .takeIf(String::isNotEmpty)
        ?.let(::file)
val hasCompletePlaySigning =
    playSigningPropertiesFile.isFile &&
        playSigningValues.values.all(String::isNotEmpty) &&
        playStoreFile?.isFile == true

if (hasAnyVeepooArtifact && !hasCompleteVeepooSdk) {
    val missing = veepooSdkFiles.filterNot { it.isFile }.joinToString { it.name }
    throw GradleException("Veepoo SDK 文件不完整，缺少：$missing")
}

android {
    namespace = "cc.saidian.saydian_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "cn.saydian.app.global"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Keep all distributable variants on the same two supported ARM ABIs.
        // A local emulator Debug run may opt into x86_64 through the explicit
        // switch above; the release gate separately checks ARM symmetry.
        ndk {
            // Flutter configures explicit ABI splits when requested; NDK
            // filters conflict with splits. Universal builds keep both ARMs.
            if (!splitPerAbiRequested) {
                abiFilters += setOf("armeabi-v7a", "arm64-v8a") + debugEmulatorAbis
            }
        }
        manifestPlaceholders["JPUSH_APPKEY"] =
            jpushAppKey.ifEmpty { "debug-disabled" }
        manifestPlaceholders["JPUSH_CHANNEL"] =
            jpushChannel.ifEmpty { "developer-disabled" }
        buildConfigField("boolean", "VEEPOO_SDK_PRESENT", hasCompleteVeepooSdk.toString())
        buildConfigField("String", "WECHAT_APP_ID", "\"$wechatAppId\"")
    }

    buildFeatures {
        buildConfig = true
    }

    packaging {
        jniLibs {
            // Several transitive AARs also publish desktop/emulator binaries.
            // Distribution is intentionally limited to the two supported ARM
            // ABIs; release_gate.py verifies that their .so sets are symmetric.
            excludes +=
                buildSet {
                    add("lib/armeabi/**")
                    add("lib/x86/**")
                    if (!emulatorDebugRequested) {
                        add("lib/x86_64/**")
                    }
                }
        }
    }

    signingConfigs {
        if (hasCompleteProductionSigning) {
            create("productionRelease") {
                keyAlias = productionSigningValues.getValue("keyAlias")
                keyPassword = productionSigningValues.getValue("keyPassword")
                storeFile = productionStoreFile
                storePassword = productionSigningValues.getValue("storePassword")
            }
        }
        if (hasCompletePlaySigning) {
            create("playUploadRelease") {
                keyAlias = playSigningValues.getValue("keyAlias")
                keyPassword = playSigningValues.getValue("keyPassword")
                storeFile = playStoreFile
                storePassword = playSigningValues.getValue("storePassword")
            }
        }
    }

    flavorDimensions += "distribution"
    productFlavors {
        create("sideload") {
            dimension = "distribution"
            signingConfig =
                if (productionReleaseRequested && !qaReleaseAllowed && hasCompleteProductionSigning) {
                    signingConfigs.getByName("productionRelease")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
        create("play") {
            dimension = "distribution"
            signingConfig =
                if (productionReleaseRequested && !qaReleaseAllowed && hasCompletePlaySigning) {
                    signingConfigs.getByName("playUploadRelease")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }

    buildTypes {
        release {
            // Signing is selected by distribution flavor. QA falls back to
            // debug signing; production Play uses an independent upload key.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

val verifySaidianReleaseMode by tasks.registering {
    group = "verification"
    description = "Rejects ambiguous or unconfigured Saydian Release builds."
    doLast {
        if (productionReleaseRequested == qaReleaseAllowed) {
            throw GradleException(
                "Release builds require exactly one mode: " +
                    "SAIDIAN_PRODUCTION_RELEASE=true or SAIDIAN_ALLOW_QA_RELEASE=true",
            )
        }
        if (qaReleaseAllowed) {
            logger.warn("QA RELEASE - NOT FOR DISTRIBUTION; debug signing and disabled push are expected.")
            return@doLast
        }
        if (jpushAppKey.isEmpty() || jpushChannel != "production") {
            throw GradleException(
                "Production release requires JPUSH_APP_KEY and JPUSH_CHANNEL=production",
            )
        }
        if (jpushVendorChannels.isEmpty()) {
            throw GradleException("Production release requires an explicit JPUSH_VENDOR_CHANNELS decision")
        }
        if (!apiBaseUrl.startsWith("https://")) {
            throw GradleException("Production release requires an HTTPS SAYDIAN_API_BASE_URL")
        }
        if (!playStoreDartDefine &&
            (!updateManifestUrl.startsWith("https://") || updateAllowedHosts.isEmpty())
        ) {
            throw GradleException(
                "Production release requires an HTTPS SAYDIAN_UPDATE_MANIFEST_URL and " +
                    "SAYDIAN_UPDATE_ALLOWED_HOSTS",
            )
        }
        if (playStoreDartDefine && !hasCompletePlaySigning) {
            throw GradleException(
                "Production Play release requires complete android/play-upload.properties and its keystore file",
            )
        }
        if (!playStoreDartDefine && !hasCompleteProductionSigning) {
            throw GradleException(
                "Production release requires complete android/key.properties and its keystore file",
            )
        }
    }
}

tasks.matching {
    it.name.startsWith("pre") && it.name.endsWith("ReleaseBuild")
}.configureEach {
    dependsOn(verifySaidianReleaseMode)
}

val verifyPlayReleaseChannel by tasks.registering {
    group = "verification"
    doLast {
        if (!playStoreDartDefine) {
            throw GradleException("Play release requires --dart-define=SAIDIAN_PLAY_STORE=true")
        }
        if (emulatorDebugRequested) {
            throw GradleException("SAIDIAN_EMULATOR_DEBUG=true is Debug-only and cannot be used for Release builds.")
        }
    }
}

val verifySideloadReleaseChannel by tasks.registering {
    group = "verification"
    doLast {
        if (playStoreDartDefine) {
            throw GradleException("Sideload release must not enable the Play update channel")
        }
        if (emulatorDebugRequested) {
            throw GradleException("SAIDIAN_EMULATOR_DEBUG=true is Debug-only and cannot be used for Release builds.")
        }
    }
}

// AGP puts both flavors' preReleaseBuild tasks in either flavor's task graph.
// Attach channel-specific checks only to the actual package/bundle tasks.
tasks.matching { it.name == "packagePlayRelease" || it.name == "bundlePlayRelease" }
    .configureEach { dependsOn(verifyPlayReleaseChannel) }
tasks.matching { it.name == "packageSideloadRelease" || it.name == "bundleSideloadRelease" }
    .configureEach { dependsOn(verifySideloadReleaseChannel) }

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("com.tencent.mm.opensdk:wechat-sdk-android:6.8.40")
    implementation("com.alipay.sdk:alipaysdk-android:15.8.42")
    if (hasCompleteVeepooSdk) {
        implementation(files(veepooSdkFiles))
        implementation("com.google.code.gson:gson:2.13.2")
        implementation("no.nordicsemi.android:mcumgr-core:2.7.4")
        implementation("no.nordicsemi.android:mcumgr-ble:2.7.4")
        implementation("no.nordicsemi.android.support.v18:scanner:1.4.2")
        implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
    }
}
