# PKPMusic Server Deployment & Configuration

This document contains all the necessary configuration, credentials, and steps for deploying and managing the PKPMusic backend on the Raspberry Pi.

## 1. Cloudflare Tunnel Configuration

The Raspberry Pi runs a Cloudflare tunnel (`cloudflared`) to expose the local services to the internet securely without port forwarding.

**Configuration File Location:** `/etc/cloudflared/config.yml`

**Current `ingress` Rules:**
```yaml
ingress:
  - hostname: pottapk.win
    service: http://localhost:3000
  - hostname: app.pottapk.win
    service: http://localhost:8080
  - hostname: api.pottapk.win
    service: http://localhost:5000
  - hostname: cloud.pottapk.win
    service: http://localhost:80
  - hostname: pkpmusic.pottapk.win
    service: http://localhost:8000
  - hostname: postgresql.pottapk.win
    service: http://localhost:5050
  - hostname: portainer.pottapk.win
    service: http://localhost:9000
  - service: http_status:404
```

**To update the tunnel configuration:**
1. SSH into the Raspberry Pi.
2. Edit the file using `sudo nano /etc/cloudflared/config.yml` (or use the `sudo tee` command from previous chats).
3. Restart the tunnel: `sudo systemctl restart cloudflared`.

## 2. Docker Services (docker-compose.yml)

The backend is deployed using Docker Compose and contains three primary services:

1. **api:** The FastAPI Python backend (Port `8000`)
2. **db:** The PostgreSQL 15 database (Port `5432` internal)
3. **pgadmin:** The web-based database management interface (Port `5050`)

### Deployment Commands

**To deploy or update the server:**
```bash
# From your laptop, sync the latest code to the Pi
rsync -avz --exclude='__pycache__' --exclude='venv' --exclude='.env' backend docker-compose.yml pavankumarpotta@192.168.1.151:~/pkpmusic-backend/

# Then, SSH into the Pi and restart the containers
ssh pavankumarpotta@192.168.1.151 "cd ~/pkpmusic-backend && docker compose up --build -d"
```

**To view live logs:**
```bash
docker compose logs -f api
```

## 3. Database Credentials

### PostgreSQL Database
The primary database is running inside the Docker container `pkpmusic-backend-db-1`.

- **Host name:** `db` (when connecting from inside the Docker network)
- **Port:** `5432`
- **Database:** `musicapp`
- **Username:** `pkpmusic`
- **Password:** `password`

### pgAdmin GUI
The pgAdmin graphical interface is accessible via `https://postgresql.pottapk.win`.

**Login Credentials:**
- **Email:** `admin@pkpmusic.com`
- **Password:** `admin`

**Connecting pgAdmin to the database:**
1. Log into pgAdmin.
2. Add a new server.
3. Under the **Connection** tab, use the PostgreSQL credentials listed above (`Host: db`, `Username: pkpmusic`, `Password: password`).

## 4. Troubleshooting

**If the API is returning 500 errors after a database change:**
This usually happens if a new column was added to the SQLAlchemy models (like `otp_code` for forgot password), but the database schema wasn't migrated. 

You can manually add columns to the running PostgreSQL database via SSH:
```bash
docker exec pkpmusic-backend-db-1 psql -U pkpmusic -d musicapp -c 'ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_code VARCHAR; ALTER TABLE users ADD COLUMN IF NOT EXISTS otp_expires_at FLOAT;'
```
