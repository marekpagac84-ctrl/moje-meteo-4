# Live Storm Radar - Flutter Aplikácia (Gradle 8+ / Codemagic Ready)

Tento balík obsahuje kompletný moderný zdrojový kód pre Flutter aplikáciu **Live Storm Radar** pre Android s plnou podporou **Gradle 8.3**, Java 17 a CI/CD v prostredí **Codemagic** a **GitHub Actions**.

## Obsah projektu:
- `lib/main.dart`: Hlavný vstupný bod Flutter aplikácie.
- `lib/models/`, `lib/services/`, `lib/components/`: Modulárna štruktúra kódov (barometer, radar, mapa, varovný banner).
- `pubspec.yaml`: Konfigurácia knižníc (`sensors_plus`, `flutter_map`, `geolocator`, `http`).
- `android/`: Moderná konfigurácia pre **Gradle 8.3** bez zastaraných skriptov (`app_plugin_loader.gradle` odstránený).
- `codemagic.yaml`: Oficiálna konfigurácia pre automatické vygenerovanie APK v prostredí **Codemagic**.
- `.github/workflows/build-apk.yml`: GitHub Actions automatická kompilácia APK.

---

## 🚀 Spôsoby vygenerovania APK súboru:

### 1. Codemagic (Odporúčané pre Codemagic CI/CD)
1. Nahraj tento projekt na tvoj GitHub / GitLab / Bitbucket repozitár.
2. Prihlás sa na [Codemagic.io](https://codemagic.io) a pridaj aplikáciu z tvojho repozitára.
3. Codemagic automaticky deteguje súbor `codemagic.yaml`.
4. Spusť build - Codemagic skompiluje `flutter build apk --release` bez akýchkoľvek chyba a sprístupní stiahnuteľný **.apk** súbor.

### 2. GitHub Actions (Zadarmo na GitHube)
1. Nahraj projekt do GitHub repozitára.
2. Otvor záložku **Actions**.
3. Spusť workflow **Build Flutter APK**, ktorý vygeneruje `app-release.apk`.

### 3. Lokálne vo Flutter SDK
1. Spusť v termináli:
   ```bash
   flutter pub get
   flutter build apk --release
   ```
2. Výsledné APK nájdeš v: `build/app/outputs/flutter-apk/app-release.apk`
