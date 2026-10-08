# Google Play Store listing

App name: **Nexo – Private Messenger**
Category: Communication · Content rating: Everyone (IARC questionnaire: user-to-user communication = yes)
Data safety: see "Data safety form (Play Console)" at the end of this file.

## English
**Short description (80):** Encrypted messenger without phone number. Chats, groups and calls – private.

**Full description:**
Nexo is a private messenger that works without a phone number or e-mail. Your identity is a random ID created on your device.

• No phone number, no e-mail, no address-book upload
• End-to-end encryption for messages, images, files, voice messages and calls
• Encrypted voice & video calls – 1:1 and in groups
• Group chats with admin management
• Emoji, reactions, replies, editing and "delete for everyone"
• Delivery and read receipts, typing indicator (can be switched off)
• Verify contacts in person by scanning their QR code
• App lock with fingerprint/face, dark mode
• German, English and Russian
• No ads, no tracking

## Deutsch
**Kurzbeschreibung:** Verschlüsselter Messenger ohne Telefonnummer. Chats, Gruppen und Anrufe – privat.

**Vollständige Beschreibung:**
Nexo ist ein privater Messenger, der ohne Telefonnummer und E-Mail funktioniert. Deine Identität ist eine zufällige ID, die auf deinem Gerät erstellt wird.

• Keine Telefonnummer, keine E-Mail, kein Adressbuch-Upload
• Ende-zu-Ende-Verschlüsselung für Nachrichten, Bilder, Dateien, Sprachnachrichten und Anrufe
• Verschlüsselte Sprach- & Videoanrufe – einzeln und in Gruppen
• Gruppenchats mit Admin-Verwaltung
• Emoji, Reaktionen, Antworten, Bearbeiten und „Für alle löschen“
• Zustell- und Lesebestätigungen, Tipp-Anzeige (abschaltbar)
• Kontakte persönlich per QR-Code verifizieren
• App-Sperre mit Fingerabdruck/Gesicht, Dunkelmodus
• Deutsch, Englisch und Russisch
• Keine Werbung, kein Tracking

## Русский
**Краткое описание:** Зашифрованный мессенджер без номера телефона. Чаты, группы и звонки – приватно.

**Полное описание:**
Nexo — приватный мессенджер, который работает без номера телефона и e-mail. Ваша личность — случайный ID, созданный на устройстве.

• Без номера телефона, e-mail и загрузки контактов
• Сквозное шифрование сообщений, изображений, файлов, голосовых сообщений и звонков
• Зашифрованные аудио- и видеозвонки — один на один и в группах
• Групповые чаты с управлением администратором
• Эмодзи, реакции, ответы, редактирование и «удалить у всех»
• Отчёты о доставке и прочтении, индикатор набора (отключаемые)
• Проверка контактов лично по QR-коду
• Блокировка приложения отпечатком/лицом, тёмная тема
• Немецкий, английский и русский
• Без рекламы и слежки

## Data safety form (Play Console)

Answers for the Firebase backend. Message, media and call content is end-to-end encrypted on the device and is not readable by the developer or Google, so it is not declared as collected.

- **Does your app collect or share any of the required user data types?** Yes
- **Is all of the user data collected by your app encrypted in transit?** Yes (TLS to Firebase; content additionally end-to-end encrypted)
- **Do you provide a way for users to request that their data is deleted?** Yes: Settings → Delete ID removes the identity, queued messages and the Firebase account. Web: mail@kandacodelab.com

| Data type | Collected | Shared | Optional | Purpose | Why |
|---|---|---|---|---|---|
| Personal info → User IDs | Yes | No | No | App functionality | Random Nexo ID and anonymous Firebase account, needed to route encrypted messages |
| Device or other IDs | Yes | No | Yes (notification permission) | App functionality | Firebase Cloud Messaging push token for content-free wake-ups |
| Messages, Photos, Audio, Files | No | No | – | – | End-to-end encrypted; only sender and recipient can read them |
| Contacts, Location, Name, Email, Phone | No | No | – | – | Not accessed |
| App activity, Diagnostics, Analytics | No | No | – | – | No analytics or crash reporting SDK included |

Notes:
- Google Firebase is a service provider processing data on the developer's behalf; per Play policy this is not "sharing".
- Encrypted envelopes are deleted after delivery, at the latest after 30 days; encrypted blobs after 14 days.
- Calls connect peer-to-peer (DTLS-SRTP); a TURN relay, if configured, only forwards encrypted media.

