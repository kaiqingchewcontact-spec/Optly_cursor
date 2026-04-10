# Optly

Android app built with Kotlin and Jetpack Compose (Material 3). The repository is structured for publishing on Google Play.

## Prerequisites

- [Android Studio](https://developer.android.com/studio) (recommended) or Android SDK command-line tools
- JDK 17 (the project uses `jvmToolchain(17)`)

Create `local.properties` in the project root (see `local.properties.example`):

```properties
sdk.dir=/path/to/Android/sdk
```

## Build

Debug APK:

```bash
./gradlew :app:assembleDebug
```

Release **Android App Bundle** (upload this to Play Console):

```bash
./gradlew :app:bundleRelease
```

Output: `app/build/outputs/bundle/release/app-release.aab`

## Signing for Play Store

1. Create an upload key and keystore (or use Play App Signing and an upload certificate as [documented by Google](https://developer.android.com/studio/publish/app-signing)).
2. Copy `keystore.properties.example` to `keystore.properties` and point `storeFile` at your keystore; set passwords and `keyAlias`.
3. Run `./gradlew :app:bundleRelease` again. The release build uses minification and shrinking when `keystore.properties` is present.

`keystore.properties`, `*.jks`, and `*.keystore` must stay out of version control.

## Play Console checklist

- **Package name**: `com.optly.app` (change in `app/build.gradle.kts` before your first public release if you need a different id).
- **Target API**: `targetSdk` / `compileSdk` 35 in `app/build.gradle.kts`.
- **Store listing**: title, short/full description, screenshots, feature graphic, app icon (adaptive icons are under `app/src/main/res/mipmap-*` and `mipmap-anydpi-v26`).
- **Privacy policy**: This sample app does not collect user data; if you add analytics or accounts, host a policy URL and declare data safety in Play Console.
- **Content rating** and **Data safety** forms in Play Console.

## Tests

```bash
./gradlew :app:test
```
