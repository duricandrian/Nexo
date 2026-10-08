# Nexo – Privacy Policy

_Last updated: 2026-10-08_

Nexo is built so that the operator of the server learns as little as possible about you.

## What we do NOT collect
- No phone number, no e-mail address, no real name.
- No access to your address book.
- No advertising or analytics SDKs, no tracking.
- No message content: all messages, images, files, voice messages and call setup data are end-to-end encrypted on your device (X25519 + XSalsa20-Poly1305). The server cannot decrypt them.

## What the server processes
| Data | Purpose | Retention |
|---|---|---|
| Your random 8-character Nexo ID and public key | So others can find your public key and send you messages | Until you delete your ID |
| Encrypted messages waiting for delivery | Store-and-forward delivery when you are offline | Deleted on delivery, at the latest after 30 days |
| Encrypted attachments (images, files, voice) | Delivery of large content | Deleted after 14 days |
| IP address (transient) | Required for the network connection | Not stored |

Voice and video calls are peer-to-peer (WebRTC, DTLS-SRTP encrypted). If a direct connection is impossible, encrypted media is relayed through a TURN server, which cannot decrypt it.

## Data on your device
Your private key is stored in the Android Keystore-backed secure storage. Chats are stored locally on your device only and are excluded from cloud backups. You can create an optional password-encrypted backup of your ID.

## Permissions
Camera (QR codes, photos, video calls), microphone (voice messages, calls), notifications, and a foreground service to receive messages and keep calls running. All are optional and used only for the stated feature.

## Deleting your data
Settings → Delete ID revokes your ID on the server and erases all local data.

## Children
Nexo is not directed at children under 13.

## Contact
Questions: mail@kandacodelab.com

---

# Datenschutzerklärung (Deutsch)

Nexo erfasst **keine** Telefonnummer, E-Mail, Namen oder Kontakte und enthält keine Tracking- oder Werbe-SDKs. Alle Nachrichten, Medien und Anrufsignale sind Ende-zu-Ende-verschlüsselt; der Server kann sie nicht lesen. Der Server speichert nur deine zufällige ID mit öffentlichem Schlüssel sowie verschlüsselte Nachrichten bis zur Zustellung (max. 30 Tage) und verschlüsselte Anhänge (max. 14 Tage). IP-Adressen werden nicht gespeichert. Chats liegen nur auf deinem Gerät. Über Einstellungen → ID löschen werden alle Daten entfernt.

# Политика конфиденциальности (Русский)

Nexo **не** собирает номер телефона, e-mail, имя или контакты и не содержит трекеров и рекламы. Все сообщения, медиа и сигналы звонков защищены сквозным шифрованием; сервер не может их прочитать. Сервер хранит только ваш случайный ID с открытым ключом, зашифрованные сообщения до доставки (макс. 30 дней) и зашифрованные вложения (макс. 14 дней). IP-адреса не сохраняются. Чаты хранятся только на вашем устройстве. Настройки → Удалить ID удаляет все данные.
