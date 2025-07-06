# Task Management API

![CI/CD Pipeline](https://github.com/arkenidar/task-management-api/actions/workflows/ci-cd.yml/badge.svg)
![Deploy to VPS](https://github.com/arkenidar/task-management-api/actions/workflows/deploy.yml/badge.svg)

Una REST API completa per la gestione di task, costruita con Ktor e Kotlin. Include deployment automatico su VPS con SSL/HTTPS.

## 🚀 Funzionalità

- **CRUD completo** per task management
- **Autenticazione e sicurezza** con headers di sicurezza
- **Rate limiting** per proteggere l'API
- **SSL/HTTPS** automatico con Let's Encrypt
- **Docker** containerizzazione completa
- **GitHub Actions** CI/CD automation
- **Health checks** e monitoring
- **Documentazione OpenAPI/Swagger**

## 📋 Endpoints API

- `GET /api/tasks` - Ottieni tutti i task
- `POST /api/tasks` - Crea un nuovo task
- `GET /api/tasks/{id}` - Ottieni un task specifico
- `PUT /api/tasks/{id}` - Aggiorna un task
- `DELETE /api/tasks/{id}` - Elimina un task
- `GET /api/health` - Health check
- `GET /home` - Informazioni API

## 🛠️ Tecnologie

- **Ktor** - Framework web Kotlin
- **Kotlinx Serialization** - Serializzazione JSON
- **Docker** - Containerizzazione
- **Nginx** - Reverse proxy e load balancing
- **Let's Encrypt** - Certificati SSL gratuiti
- **GitHub Actions** - CI/CD automation

## 📦 Quick Start

### Sviluppo Locale

```bash
# Clona il repository
git clone https://github.com/arkenidar/task-management-api.git
cd task-management-api

# Avvia l'applicazione
./gradlew run

# L'API sarà disponibile su http://localhost:8080
```

### Test

```bash
# Esegui tutti i test
./gradlew test

# Build del JAR
./gradlew buildFatJar
```

# Task Management API - VPS Deployment Guide

## 🚀 Deployment su VPS con SSL/HTTPS

### Prerequisiti sul VPS

1. **Docker e Docker Compose installati**
```bash
# Installa Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Installa Docker Compose
sudo apt-get update
sudo apt-get install docker-compose-plugin
```

2. **Configurazione del firewall**
```bash
# Apri le porte necessarie
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS
sudo ufw enable
```

### 🔐 Deployment con SSL Automatico (Consigliato)

#### 1. Clona il repository sul VPS
```bash
git clone <your-repo-url>
cd ktor-sample
```

#### 2. Configura DNS
Prima di procedere, assicurati che il tuo dominio punti all'IP del VPS:
```bash
# Verifica che il dominio risolva correttamente
nslookup your-domain.com
```

#### 3. Deployment con SSL automatico
```bash
# Deployment di produzione con SSL
./deploy.sh production your-domain.com

# Lo script farà automaticamente:
# - Build dell'applicazione
# - Installazione di Certbot
# - Richiesta certificati SSL da Let's Encrypt
# - Configurazione Nginx con HTTPS
# - Attivazione auto-renewal dei certificati
```

### 🔧 Configurazione SSL Manuale (Opzionale)

Se vuoi configurare SSL separatamente:

```bash
# 1. Esegui solo il setup SSL
./setup-ssl.sh your-domain.com your-email@domain.com

# 2. Poi esegui il deployment normale
./deploy.sh production your-domain.com
```

### 📋 Verifica SSL

Dopo il deployment, verifica che SSL funzioni:

```bash
# Test HTTPS
curl -I https://your-domain.com/api/health

# Verifica certificato SSL
echo | openssl s_client -connect your-domain.com:443 -servername your-domain.com 2>/dev/null | openssl x509 -noout -dates

# Controlla stato certificati
sudo certbot certificates
```

### 🔄 Rinnovo Automatico

Il rinnovo dei certificati SSL è configurato automaticamente:

```bash
# Controlla il cron job
sudo crontab -l

# Test manuale del rinnovo
sudo certbot renew --dry-run

# Forza il rinnovo (se necessario)
sudo certbot renew --force-renewal
```

### 📊 Monitoraggio

#### Verifica lo stato dei container
```bash
docker ps
docker logs task-management-api-prod
docker logs task-api-nginx
```

#### Test completo dell'API
```bash
# Health check HTTPS
curl -k https://your-domain.com/api/health

# Test API completo
curl -k https://your-domain.com/api/tasks
curl -k -X POST https://your-domain.com/api/tasks \
  -H "Content-Type: application/json" \
  -d '{"title":"Test","description":"Test task"}'
```

### 🔒 Sicurezza Avanzata

#### Headers di sicurezza inclusi:
- `Strict-Transport-Security` - Forza HTTPS
- `X-Frame-Options` - Previene clickjacking
- `X-Content-Type-Options` - Previene MIME sniffing
- `X-XSS-Protection` - Protezione XSS
- `Referrer-Policy` - Controllo referrer

#### Rate limiting configurato:
- API generale: 10 richieste/secondo
- Health check: 30 richieste/secondo
- Burst capacity per picchi di traffico

### 🛠️ Troubleshooting SSL

#### Errori comuni e soluzioni:

**1. Certificato non valido**
```bash
# Controlla i logs di Certbot
sudo tail -f /var/log/letsencrypt/letsencrypt.log

# Rigenera certificato
sudo certbot delete --cert-name your-domain.com
./setup-ssl.sh your-domain.com
```

**2. Nginx non si avvia**
```bash
# Controlla configurazione Nginx
docker exec task-api-nginx nginx -t

# Riavvia Nginx
docker-compose -f docker-compose.ssl.yml restart nginx
```

**3. Dominio non raggiungibile**
```bash
# Verifica DNS
dig your-domain.com

# Controlla connettività
telnet your-domain.com 443
```

### 🎯 URLs di Produzione

Dopo il deployment con SSL:

- **HTTPS Base**: `https://your-domain.com/`
- **Health Check**: `https://your-domain.com/api/health`
- **All Tasks**: `https://your-domain.com/api/tasks`
- **API Info**: `https://your-domain.com/home`
- **Swagger**: `https://your-domain.com/openapi`

*Nota: Il traffico HTTP viene automaticamente reindirizzato a HTTPS*

### 🚀 Opzioni di Deployment

```bash
# Deployment completo con SSL
./deploy.sh production your-domain.com

# Deployment senza SSL (solo HTTP)
./deploy.sh production

# Deployment di staging
./deploy.sh staging

# Setup SSL separato
./setup-ssl.sh your-domain.com your-email@domain.com
```

### 📈 Performance e Scaling

#### Ottimizzazioni SSL incluse:
- HTTP/2 abilitato
- Session caching SSL
- Compressione gzip
- Keep-alive connections
- Caching per contenuti statici

#### Monitoring certificati:
```bash
# Controlla scadenza certificati
sudo certbot certificates

# Imposta alerting per scadenza
echo "30 2 * * * /usr/bin/certbot renew --quiet --deploy-hook 'docker-compose -f $(pwd)/docker-compose.ssl.yml restart nginx'" | sudo crontab -
```

### 🔧 Configurazione Avanzata

#### Per domini multipli:
```bash
# Aggiungi più domini al certificato
sudo certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    -d your-domain.com \
    -d www.your-domain.com \
    -d api.your-domain.com
```

#### Per certificati wildcard:
```bash
# Richiedi certificato wildcard (richiede DNS challenge)
sudo certbot certonly --manual \
    --preferred-challenges dns \
    -d "*.your-domain.com"
```

### 📝 Note Importanti

1. **DNS**: Assicurati che il dominio punti al VPS prima di richiedere SSL
2. **Email**: Usa un email valido per Let's Encrypt notifications
3. **Firewall**: Porte 80 e 443 devono essere aperte
4. **Backup**: I certificati sono in `/etc/letsencrypt/`
5. **Limiti**: Let's Encrypt ha limiti di rate (50 certificati/settimana per dominio)

### 🆘 Supporto

In caso di problemi:
1. Controlla i logs: `docker logs task-api-nginx`
2. Verifica certificati: `sudo certbot certificates`
3. Test configurazione: `docker exec task-api-nginx nginx -t`
4. Riavvia servizi: `docker-compose -f docker-compose.ssl.yml restart`
