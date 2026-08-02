import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Push bildirimleri (FCM) için `google-services.json`'ı işler.
    id("com.google.gms.google-services")
}

// --- Release imzalama: yalniz Git disi kaynaklar (FAIL-CLOSED) -----------
//
// Release APK/AAB, Google Play tarafindan kabul edilebilmesi ve gelecekteki
// guncellemelerin ayni imzayla dogrulanabilmesi icin gercek bir production
// keystore ile imzalanmalidir. Bu deger Git'e ASLA commit edilmez; iki
// kaynaktan biri saglar (asagidaki oncelik sirasiyla):
//
//   1) `android/key.properties` (repo disi, .gitignore'da) - yerel/gelistirici
//      makinesinde tek seferlik olusturulan dosya. Beklenen anahtarlar:
//        storeFile=/mutlak/yol/veya/android/koke/gore/relatif/keystore.jks
//        storePassword=...
//        keyAlias=...
//        keyPassword=...
//   2) Ortam degiskenleri (CI/release makinesi):
//        PANELYA_ANDROID_KEYSTORE_PATH
//        PANELYA_ANDROID_KEYSTORE_PASSWORD
//        PANELYA_ANDROID_KEY_ALIAS
//        PANELYA_ANDROID_KEY_PASSWORD
//
// `key.properties` dosyasi varsa ve ilgili alan doluysa o deger kullanilir;
// yoksa/bossa karsilik gelen ortam degiskenine dusulur. Debug build bu
// degerlerden hicbirini gerektirmez ve etkilenmez.
//
// Bir RELEASE gorevi (assembleRelease/bundleRelease vb.) tetiklenirken bu
// degerlerden herhangi biri eksikse build ACIK bir hata ile durur ve HANGI
// property/env adinin eksik oldugunu soyler - DEGERLERI ASLA yazdirmaz ve
// hicbir kosulda debug anahtarina sessizce dusmez (bkz. asagidaki
// `missingReleaseSigningKeys` kontrolu).
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

fun releaseSigningValue(propertyKey: String, envKey: String): String? {
    val fromFile = keystoreProperties.getProperty(propertyKey)?.takeIf { it.isNotBlank() }
    if (fromFile != null) return fromFile
    return System.getenv(envKey)?.takeIf { it.isNotBlank() }
}

val releaseStoreFilePath = releaseSigningValue("storeFile", "PANELYA_ANDROID_KEYSTORE_PATH")
val releaseStorePassword = releaseSigningValue("storePassword", "PANELYA_ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = releaseSigningValue("keyAlias", "PANELYA_ANDROID_KEY_ALIAS")
val releaseKeyPassword = releaseSigningValue("keyPassword", "PANELYA_ANDROID_KEY_PASSWORD")

val missingReleaseSigningKeys = buildList {
    if (releaseStoreFilePath.isNullOrBlank()) add("storeFile (key.properties) / PANELYA_ANDROID_KEYSTORE_PATH (env)")
    if (releaseStorePassword.isNullOrBlank()) add("storePassword (key.properties) / PANELYA_ANDROID_KEYSTORE_PASSWORD (env)")
    if (releaseKeyAlias.isNullOrBlank()) add("keyAlias (key.properties) / PANELYA_ANDROID_KEY_ALIAS (env)")
    if (releaseKeyPassword.isNullOrBlank()) add("keyPassword (key.properties) / PANELYA_ANDROID_KEY_PASSWORD (env)")
}

// Sadece gercekten bir release gorevi calistirilmaya calisiliyorsa dogrula;
// boylece `flutter build apk --debug` bu degerler olmadan da calismaya
// devam eder (debug/other gorevlerde signingConfigs.release nesnesi
// olusturulur ama kullanilmaz, bu yuzden eksik/null degerler zararsizdir).
val isRunningReleaseTask = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }

if (isRunningReleaseTask && missingReleaseSigningKeys.isNotEmpty()) {
    throw GradleException(
        "Release imzalama yapilandirmasi eksik. Asagidaki degerler bulunamadi:\n" +
            missingReleaseSigningKeys.joinToString("\n") { " - $it" } +
            "\n\nCozum: android/key.properties dosyasi olustur (storeFile, storePassword, " +
            "keyAlias, keyPassword) VEYA yukaridaki PANELYA_ANDROID_* ortam degiskenlerini " +
            "ayarla. Bu depoda gercek keystore/parola tutulmaz; release build hicbir kosulda " +
            "debug anahtarina dusmez. (Bu hata mesaji hicbir degeri gostermez.)",
    )
}

// --- App Links host (Universal Links/Android tarafi) ---------------------
//
// AndroidManifest.xml'deki `https` intent-filter'i (bkz. asagida, ayni
// `.MainActivity` icinde) gercek bir production domain'i BU DOSYAYA veya
// manifeste GOMMEZ; `android:host` degeri asagidaki `appLinkHost`
// manifestPlaceholder'indan gelir. Deger, `key.properties`/release imzalama
// ile ayni oncelik deseniyle iki kaynaktan biriyle saglanir:
//
//   1) Gradle ozelligi: `-PpanelyaAndroidAppLinkHost=<domain>` (veya
//      `android/gradle.properties` icinde `panelyaAndroidAppLinkHost=<domain>`,
//      repo disi/commit edilmez).
//   2) Ortam degiskeni: `PANELYA_ANDROID_APP_LINK_HOST` (CI/release makinesi).
//
// Production domain karari HENUZ verilmedi (bkz. production-bible.md ADR,
// apps/mobile/README.md "Gelecek adim"); bu yuzden ikisi de saglanmazsa
// `.invalid` TLD'li (RFC 2606 - asla gercek/kayitli bir domain OLAMAZ)
// anlamsiz bir varsayilana dusulur. Boylece yapilandirilmamis bir build,
// intent-filter'i GERCEK bir domain'e YANLISLIKLA baglamaz; filtre hicbir
// gercek App Link'i eslemez. Bu, Android manifest/`autoVerify` katmanindaki
// fail-closed davranistir - detayli host/path guvenligi (allowlist, path
// esleme) zaten Flutter tarafinda `UniversalLinkConfig` +
// `mapWebPathToMobileRoute` ile saglanir (bkz. apps/mobile/README.md).
val appLinkHost = (project.findProperty("panelyaAndroidAppLinkHost") as String?)
    ?.takeIf { it.isNotBlank() }
    ?: System.getenv("PANELYA_ANDROID_APP_LINK_HOST")?.takeIf { it.isNotBlank() }
    ?: "app-links-not-configured.invalid"

android {
    namespace = "com.panelya.panelya_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.panelya.panelya_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Bkz. yukaridaki `appLinkHost` yorumu: AndroidManifest.xml'deki
        // `${appLinkHost}` yer tutucusunu doldurur, gercek domain repo icinde
        // hic gorunmez.
        manifestPlaceholders["appLinkHost"] = appLinkHost
    }

    signingConfigs {
        // Bu blok debug build sirasinda da olusturulur (config-phase), fakat
        // degerler bossa/eksikse yalniz atanir; gercekten IMZALAMA icin
        // KULLANILMASI yukaridaki fail-closed kontrolunden gecmis olmayi
        // gerektirir - kontrol release gorevlerinde build'i zaten durdurur.
        create("release") {
            if (missingReleaseSigningKeys.isEmpty()) {
                storeFile = file(releaseStoreFilePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // Gercek release imzasi (bkz. dosyanin ustundeki fail-closed
            // kontrolu). DEBUG anahtarina dusulmez: degerler eksikken bir
            // release gorevi calistirilirsa build bu noktaya hic ulasmadan
            // yukarida acik bir hata ile durur.
            signingConfig = signingConfigs.getByName("release")
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
