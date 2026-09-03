# Gerar o .APK do Card Vault (Android nativo)

> O app já é **PWA instalável** (mesmo `dist/`, offline, sem loja). Este guia é para quem quer o **APK** de verdade via Capacitor (requer **Android Studio** instalado, 1 vez).

## 1. Preparar

```bash
npm install
npm install @capacitor/core @capacitor/cli @capacitor/android
call sync-dist.cmd
npx cap add android
npx cap sync
```

## 2. Gerar o APK (debug, instalável direto no celular)

```bash
cd android
./gradlew assembleDebug
# saída: android/app/build/outputs/apk/debug/app-debug.apk
```

## 3. APK de release (loja)

1. Gere uma chave: `keytool -genkey -v -keystore cardvault.keystore -alias cardvault -keyalg RSA -keysize 2048 -validity 10000`
2. Configure `android/app/build.gradle` (signingConfigs) e rode `./gradlew assembleRelease`

## Alternativa sem Android Studio

Hospede `dist/` em https (GitHub Pages, Netlify, Vercel) e use o **PWABuilder.com** → ele gera o APK/AAB assinável na nuvem.

## iPhone

iOS não permite APK: use a PWA — Safari → Compartilhar → *Adicionar à Tela de Início* (ícone + offline inclusos).
