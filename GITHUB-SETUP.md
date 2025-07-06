# GitHub Configuration Guide

## 🐙 GitHub Setup

### 1. Crea Repository su GitHub

1. Vai su [GitHub](https://github.com) e crea un nuovo repository
2. Nome suggerito: `task-management-api`
3. **NON** inizializzare con README (abbiamo già tutto)

### 2. Collega Repository Locale

```bash
# Aggiungi remote origin
git remote add origin https://github.com/arkenidar/task-management-api.git

# Push del codice
git branch -M main
git push -u origin main
```

### 3. Configura GitHub Secrets

Per abilitare il deployment automatico, aggiungi questi secrets nelle impostazioni del repository:

**Settings → Secrets and variables → Actions → New repository secret**

#### Secrets per VPS Deployment:
- `VPS_HOST` - IP del tuo VPS (es. 123.456.789.101)
- `VPS_USER` - Username SSH (es. ubuntu, root)
- `VPS_SSH_KEY` - Chiave SSH privata per accesso VPS
- `VPS_PORT` - Porta SSH (di solito 22)
- `DOMAIN_NAME` - Il tuo dominio (es. api.tuodominio.com)

#### Secrets per Docker Hub (opzionale):
- `DOCKERHUB_USERNAME` - Username Docker Hub
- `DOCKERHUB_TOKEN` - Token Docker Hub

### 4. Configura SSH Key per VPS

```bash
# Sul tuo computer locale, genera una chiave SSH
ssh-keygen -t rsa -b 4096 -C "github-actions"

# Copia la chiave pubblica sul VPS
ssh-copy-id -i ~/.ssh/id_rsa.pub user@your-vps-ip

# Copia la chiave privata nei GitHub Secrets
cat ~/.ssh/id_rsa  # Copia tutto il contenuto in VPS_SSH_KEY
```

### 5. Prepara VPS per Deployment

```bash
# Sul VPS, crea la directory di deployment
sudo mkdir -p /opt/task-management-api
sudo chown $USER:$USER /opt/task-management-api

# Clona il repository
cd /opt/task-management-api
git clone https://github.com/arkenidar/task-management-api.git .

# Rendi eseguibili gli script
chmod +x deploy.sh setup-ssl.sh
```

## 🚀 Workflow Automatici

### GitHub Actions Workflows:

1. **CI/CD Pipeline** (`ci-cd.yml`):
   - Esegue test automatici
   - Build dell'applicazione
   - Push immagine Docker su Docker Hub

2. **Deploy to VPS** (`deploy.yml`):
   - Deployment automatico su VPS
   - Attivazione SSL automatica
   - Health check post-deployment

### Trigger dei Workflow:
- **Push su main** → Deployment automatico in produzione
- **Push su develop** → Build e test
- **Pull Request** → Test automatici

## 📋 Checklist per GitHub

- [ ] Repository creato su GitHub
- [ ] Codice pushato su GitHub
- [ ] Secrets configurati
- [ ] SSH key configurata per VPS
- [ ] Directory `/opt/task-management-api` creata sul VPS
- [ ] Dominio configurato e puntato al VPS
- [ ] Firewall VPS configurato (porte 22, 80, 443)

## 🔄 Workflow di Sviluppo

```bash
# Sviluppo locale
git checkout -b feature/nuova-funzionalita
# ... sviluppo ...
git commit -m "Aggiungi nuova funzionalità"
git push origin feature/nuova-funzionalita

# Crea Pull Request su GitHub
# Dopo merge su main → deployment automatico
```

## 🛠️ Comandi Utili

```bash
# Verifica stato GitHub Actions
# Vai su: https://github.com/arkenidar/task-management-api/actions

# Trigger manuale deployment
git tag v1.0.0
git push origin v1.0.0

# Rollback su VPS
ssh user@vps-ip
cd /opt/task-management-api
git checkout HEAD~1
./deploy.sh production your-domain.com
```

## 📊 Monitoring

Dopo il setup, potrai monitorare:
- **Build status** tramite GitHub Actions
- **Deployment status** tramite badge nel README
- **API health** tramite endpoint `/api/health`
- **SSL certificate** tramite browser o strumenti SSL
