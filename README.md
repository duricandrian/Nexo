# Arcana – private messenger

A Threema-style end-to-end encrypted messenger: **no phone number, no e-mail**. Each user gets a random 8-character ID generated on the device.

- `app/` – Flutter app (Android; iOS-ready code). Languages: German, English, Russian.
- `server/` – Node.js relay (WebSocket store-and-forward, encrypted blob storage, TURN credentials) + Docker Compose with Caddy (TLS) and coturn.
- `store/` – Play Store listing texts (DE/EN/RU). `PRIVACY.md` – privacy policy.

## Security model
- Identity: X25519 keypair created on device; private key stored in Android Keystore-backed secure storage.
- Messages: NaCl `crypto_box` (X25519 + XSalsa20-Poly1305) per recipient, random padding. Groups are fanned out client-side (each member gets an individually encrypted copy).
- Attachments: random symmetric key, `secretbox`-encrypted before upload; key travels inside the E2E message.
- Server login: challenge encrypted to the client's public key (proves key possession). Server only sees sender/recipient IDs and ciphertext; queued messages are deleted on delivery (max 30 days), blobs after 14 days.
- Calls: WebRTC (DTLS-SRTP); signaling runs through the E2E channel. Group calls are a full mesh (good for up to ~6 people).
- Trust levels: red = key from server, green = verified by scanning the contact's QR code.

## Run the server
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
# Point the app to your server:
flutter build appbundle --release --dart-define=SERVER_URL=wss://chat.yourdomain.com/ws \
  --dart-define=PRIVACY_URL=https://yourdomain.com/privacy
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
1. Deploy the server on a domain, build the AAB with that `SERVER_URL`.
2. Host `PRIVACY.md` publicly and put the URL in the Play Console and `PRIVACY_URL`.
3. Play Console: create app, upload AAB, fill in the listing from `store/listing.md`, Data safety, content rating, and the **foreground service** declaration (remote messaging + microphone for calls).
4. Change the application ID `ch.arcana.arcana` in `app/android/app/build.gradle.kts` if you want your own.
