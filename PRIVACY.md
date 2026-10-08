# Nexo – Privacy Policy

_Last updated: 2026-10-08_

Nexo is built so that neither we nor our hosting provider can read your messages or learn who you are.

Nexo uses **Google Firebase** (Google Ireland Ltd. / Google LLC) as its service provider for message delivery, encrypted file storage and push notifications. Google acts as a data processor; data may be processed in the EU and the USA (EU Standard Contractual Clauses / EU-US Data Privacy Framework).

## What we do NOT collect
- No phone number, no e-mail address, no real name.
- No access to your address book.
- No advertising or analytics SDKs, no tracking.
- No message content: all messages, images, files, voice messages and call setup data are end-to-end encrypted on your device (X25519 + XSalsa20-Poly1305). Neither we nor Google can decrypt them.

## What is processed in Firebase
| Data | Purpose | Retention |
|---|---|---|
| Your random 8-character Nexo ID and public key | So others can find your public key and send you messages | Until you delete your ID |
| Anonymous Firebase account ID (no name, e-mail or phone) | Authenticating your device to the service | Until you delete your ID |
| Push token (Firebase Cloud Messaging) | Waking your device when a new message arrives. Pushes contain only the sender's Nexo ID, never content | Until you delete your ID or reinstall |
| Delivery metadata (sender ID, recipient ID, time, approximate size) | Routing encrypted messages | Deleted with the message |
| Encrypted messages waiting for delivery | Store-and-forward delivery when you are offline | Deleted on delivery, at the latest after 30 days |
| Encrypted attachments (images, files, voice) | Delivery of large content | Deleted after 14 days |
| IP address | Required for the network connection; may be logged by Google for security and abuse prevention | According to Google's retention policies |

Voice and video calls are peer-to-peer (WebRTC, DTLS-SRTP encrypted). If a direct connection is impossible, encrypted media is relayed through a TURN server, which cannot decrypt it. Call setup messages are end-to-end encrypted and travel through Firebase like chat messages.

## Data on your device
Your private key is stored in the Android Keystore-backed secure storage. Chats are stored locally on your device only and are excluded from cloud backups. You can create an optional password-encrypted backup of your ID.

## Permissions
Camera (QR codes, photos, video calls), microphone (voice messages, calls), notifications, and a foreground service to keep calls running in the background. All are optional and used only for the stated feature.

## Deleting your data
Settings → Delete ID deletes your ID, your queued messages and your anonymous account from Firebase and erases all local data.

## Children
Nexo is not directed at children under 13.

## Contact
Questions: mail@kandacodelab.com

---

# Datenschutzerklärung (Deutsch)

Nexo erfasst **keine** Telefonnummer, E-Mail, Namen oder Kontakte und enthält keine Tracking- oder Werbe-SDKs. Alle Nachrichten, Medien und Anrufsignale sind Ende-zu-Ende-verschlüsselt; der Server kann sie nicht lesen. Für Zustellung, Speicherung verschlüsselter Anhänge und Push-Benachrichtigungen nutzt Nexo **Google Firebase** (Google Ireland Ltd. / Google LLC) als Auftragsverarbeiter; eine Verarbeitung in der EU und den USA ist möglich. Gespeichert werden nur deine zufällige ID mit öffentlichem Schlüssel, ein anonymes Firebase-Konto (ohne Name, E-Mail oder Telefonnummer), ein Push-Token, verschlüsselte Nachrichten bis zur Zustellung (max. 30 Tage) und verschlüsselte Anhänge (max. 14 Tage). Google sieht dabei Metadaten (welche ID wann an welche ID sendet) und IP-Adressen, aber keine Inhalte. Chats liegen nur auf deinem Gerät. Über Einstellungen → ID löschen werden alle Daten entfernt.

# Политика конфиденциальности (Русский)

Nexo **не** собирает номер телефона, e-mail, имя или контакты и не содержит трекеров и рекламы. Все сообщения, медиа и сигналы звонков защищены сквозным шифрованием; сервер не может их прочитать. Для доставки, хранения зашифрованных вложений и push-уведомлений Nexo использует **Google Firebase** (Google Ireland Ltd. / Google LLC) как обработчика данных; обработка возможна в ЕС и США. Хранятся только ваш случайный ID с открытым ключом, анонимная учётная запись Firebase (без имени, e-mail и телефона), push-токен, зашифрованные сообщения до доставки (макс. 30 дней) и зашифрованные вложения (макс. 14 дней). Google видит метаданные (какой ID когда пишет какому ID) и IP-адреса, но не содержимое. Чаты хранятся только на вашем устройстве. Настройки → Удалить ID удаляет все данные.
