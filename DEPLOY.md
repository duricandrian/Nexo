# Nexo-Server einrichten (chat.kandacodelab.com)

Der Server leitet nur verschlüsselte Nachrichten weiter. Er braucht einen eigenen
kleinen Linux-VPS (z.B. Hetzner CX22, Infomaniak, DigitalOcean; 1 vCPU, 2 GB RAM,
Ubuntu 24.04). Normales Webhosting reicht nicht.

## 1. DNS
Beim Domain-Anbieter von kandacodelab.com einen DNS-Eintrag anlegen:

| Typ | Name | Wert             |
|-----|------|------------------|
| A   | chat | IPv4 des VPS     |
| AAAA| chat | IPv6 des VPS (optional) |

Die bestehende Website auf kandacodelab.com bleibt unverändert.

## 2. Server vorbereiten (per SSH auf dem VPS)
```bash
curl -fsSL https://get.docker.com | sh
git clone https://github.com/duricandrian/Nexo.git
cd Nexo/server
cp .env.example .env
sed -i "s/TURN_SECRET=change-me/TURN_SECRET=$(openssl rand -hex 32)/" .env
```

## 3. Firewall öffnen
TCP 80, 443, 3478 · UDP 3478 und 49160-49200
```bash
ufw allow 22/tcp; ufw allow 80/tcp; ufw allow 443/tcp
ufw allow 3478; ufw allow 49160:49200/udp; ufw enable
```
Beim Hoster ggf. dieselben Ports in der Cloud-Firewall freigeben.

## 4. Starten
```bash
docker compose up -d
```
Caddy holt das TLS-Zertifikat automatisch (Let's Encrypt).

## 5. Prüfen
- https://chat.kandacodelab.com/health → `{"ok":true,...}`
- https://chat.kandacodelab.com/privacy → Datenschutzerklärung (diese URL in der Play Console angeben)

## Updates
```bash
cd Nexo && git pull && cd server && docker compose up -d --build
```
Daten (Warteschlange, Blobs) liegen im Docker-Volume und bleiben erhalten.
