# Nexo – private messenger

A Threema-style end-to-end encrypted messenger: **no phone number, no e-mail**. Each user gets a random 8-character ID generated on the device.

- `app/` – Flutter app (Android; iOS-ready code). Languages: German, English, Russian.
- `firebase/` – **production backend**: Firestore/Storage security rules, Cloud Functions (ID registration, key-possession proof, content-free FCM push, cleanup), Hosting for the privacy page. Setup guide: [FIREBASE.md](FIREBASE.md).
- `server/` – alternative self-hosted Node.js relay (WebSocket store-and-forward, encrypted blob storage, TURN credentials) + Docker Compose with Caddy (TLS) and coturn.
- `store/` – Play Store listing texts (DE/EN/RU). `PRIVACY.md` – privacy policy.

## Security model
- Identity: X25519 keypair created on device; private key stored in Android Keystore-backed secure storage.
- Messages: NaCl `crypto_box` (X25519 + XSalsa20-Poly1305) per recipient, random padding. Groups are fanned out client-side (each member gets an individually encrypted copy).
- Attachments: random symmetric key, `secretbox`-encrypted before upload; key travels inside the E2E message.
- Backend login: anonymous Firebase Auth; the Nexo ID is bound to the account as custom claim `nid` only after a challenge encrypted to the identity key is answered (proves key possession). Firebase only sees sender/recipient IDs and ciphertext; queued messages are deleted on delivery (max 30 days), blobs after 14 days. Pushes contain no content.
- Calls: WebRTC (DTLS-SRTP); signaling runs through the E2E channel. Group calls are a full mesh (good for up to ~6 people).
- Trust levels: red = key from server, green = verified by scanning the contact's QR code.

## Firebase backend (default)
See [FIREBASE.md](FIREBASE.md). Local dev: `cd firebase && firebase emulators:start --project demo-nexo`, then `flutter run --dart-define=FB_EMULATOR_HOST=10.0.2.2`.

## Self-hosted relay (alternative, legacy transport)
```bash
cd server
cp .env.example .env   # set DOMAIN and a long random TURN_SECRET
docker compose up -d   # Caddy gets a Let's Encrypt cert for DOMAIN automatically
```
Open ports: 80/443 TCP (Caddy), 3478 TCP/UDP and 49160-49200 UDP (coturn).
Local dev: `cd server && npm install && npm test && node src/index.js`.

## Build the app
```bash
cd app
flutter pub get
# Values from google-services.json (see FIREBASE.md):
flutter build appbundle --release \
  --dart-define=FB_API_KEY=... --dart-define=FB_APP_ID=... --dart-define=FB_SENDER_ID=... \
  --dart-define=FB_PROJECT_ID=... --dart-define=FB_BUCKET=... \
  --dart-define=PRIVACY_URL=https://<project>.web.app/privacy
```
Release signing: create `app/android/key.properties` (not committed):
```
storePassword=...
keyPassword=...
keyAlias=upload
storeFile=/absolute/path/to/upload-keystore.jks
```
Create a keystore with `keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`.

## Publishing checklist (Google Play)
1. Set up Firebase (FIREBASE.md), deploy rules/functions/hosting, build the AAB with the Firebase values.
2. Host `PRIVACY.md` publicly and put the URL in the Play Console and `PRIVACY_URL`.
3. Play Console: create app, upload AAB, fill in the listing from `store/listing.md`, Data safety, content rating, and the **foreground service** declaration (microphone, only during calls).
4. Change the application ID `ch.nexo.messenger` in `app/android/app/build.gradle.kts` if you want your own.
