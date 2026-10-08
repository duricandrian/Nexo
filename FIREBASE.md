# Nexo mit Firebase betreiben

Nexo nutzt Firebase nur als "Briefträger". Nachrichten, Bilder, Dateien und
Anrufsignale werden **auf dem Gerät** verschlüsselt; Firebase speichert nur
verschlüsselte Daten.

| Dienst | Zweck |
|---|---|
| Authentication (anonym) | Gerät anmelden, ohne Telefonnummer oder E-Mail |
| Firestore | Öffentliche Schlüssel (`ids/`), verschlüsselte Warteschlangen (`queues/{id}/msgs`), Push-Tokens (`private/`) |
| Storage | Verschlüsselte Anhänge (`blobs/`), Löschung nach 14 Tagen |
| Cloud Functions | ID-Vergabe, Schlüssel-Nachweis, Push ohne Inhalt, Aufräumen |
| Cloud Messaging | Wecken des Empfängers |

## 1. Projekt anlegen
1. https://console.firebase.google.com → Projekt **Nexo** anlegen (Google Analytics nicht nötig).
2. **Blaze-Tarif** aktivieren (nötig für Cloud Functions). Ein Budget-Alarm z.B. bei 10 € ist empfehlenswert.
3. Build → Authentication → Sign-in method → **Anonym** aktivieren.
4. Build → Firestore Database → erstellen, Standort `europe-west6` (Zürich).
5. Build → Storage → erstellen, gleicher Standort.
6. Projekteinstellungen → Android-App hinzufügen, Paketname `ch.nexo.messenger`,
   SHA-256 des Upload-Schlüssels eintragen. `google-services.json` herunterladen.

## 2. Backend deployen
```bash
npm i -g firebase-tools
cd firebase
firebase login
firebase use --add            # dein Projekt wählen
(cd functions && npm ci)
firebase deploy --only firestore,storage,functions
```
Optional TURN für Anrufe in schwierigen Netzen (z.B. eigener coturn oder ein Anbieter):
```bash
firebase functions:secrets:set TURN_SECRET   # oder TURN_USERNAME / TURN_CREDENTIAL
# TURN_URLS z.B. in functions/.env:  TURN_URLS=turn:turn.example.com:3478
```

## 3. App bauen
Die Werte stehen in `google-services.json` (öffentliche Kennungen, keine Geheimnisse):
```bash
cd app
flutter build appbundle --release \
  --dart-define=FB_API_KEY=...      # client[0].api_key[0].current_key
  --dart-define=FB_APP_ID=...       # client[0].client_info.mobilesdk_app_id
  --dart-define=FB_SENDER_ID=...    # project_info.project_number
  --dart-define=FB_PROJECT_ID=...   # project_info.project_id
  --dart-define=FB_BUCKET=...       # project_info.storage_bucket
```

## Lokale Entwicklung
```bash
cd firebase && firebase emulators:start --project demo-nexo
cd app && flutter run --dart-define=FB_EMULATOR_HOST=10.0.2.2
```
