#!/bin/bash

# Certbot SSL Setup Script for Task Management API
# Usage: ./setup-ssl.sh your-domain.com

set -e

DOMAIN=${1:-""}
EMAIL=${2:-"admin@$DOMAIN"}

if [ -z "$DOMAIN" ]; then
    echo "❌ Error: Domain is required"
    echo "Usage: ./setup-ssl.sh your-domain.com [email@domain.com]"
    exit 1
fi

echo "🔒 Setting up SSL certificates for $DOMAIN"

# Update system packages
echo "📦 Updating system packages..."
sudo apt-get update -y

# Install Certbot and Nginx plugin
echo "🛠️ Installing Certbot..."
sudo apt-get install -y certbot python3-certbot-nginx

# Create initial nginx configuration without SSL
echo "🔧 Creating initial Nginx configuration..."
cat > nginx-initial.conf << EOF
events {
    worker_connections 1024;
}

http {
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=health:10m rate=30r/s;

    upstream task-api {
        server task-api:8080;
        keepalive 32;
    }

    server {
        listen 80;
        server_name $DOMAIN www.$DOMAIN;

        # Let's Encrypt challenge
        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        # Temporary redirect to allow certificate generation
        location / {
            proxy_pass http://task-api;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

# Create certbot webroot directory
echo "📁 Creating certbot webroot directory..."
sudo mkdir -p /var/www/certbot

# Update docker-compose configuration
echo "🐳 Updating Docker Compose configuration..."
cat > docker-compose.ssl.yml << EOF
version: '3.8'

services:
  task-api:
    build: .
    container_name: task-management-api-prod
    ports:
      - "8080:8080"
    environment:
      - KTOR_ENV=production
      - KTOR_LOG_LEVEL=INFO
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    volumes:
      - ./logs:/app/logs
    networks:
      - app-network

  nginx:
    image: nginx:alpine
    container_name: task-api-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
      - /var/www/certbot:/var/www/certbot:ro
    depends_on:
      - task-api
    restart: unless-stopped
    networks:
      - app-network

  # Certbot for SSL certificate renewal
  certbot:
    image: certbot/certbot
    container_name: certbot
    volumes:
      - /etc/letsencrypt:/etc/letsencrypt
      - /var/www/certbot:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait \$\${!}; done;'"

networks:
  app-network:
    driver: bridge

volumes:
  logs:
    driver: local
EOF

# Start services with initial configuration
echo "🚀 Starting services with initial configuration..."
cp nginx-initial.conf nginx.conf
docker-compose -f docker-compose.ssl.yml up -d

# Wait for services to be ready
echo "⏳ Waiting for services to start..."
sleep 30

# Obtain SSL certificate
echo "🔐 Obtaining SSL certificate from Let's Encrypt..."
sudo certbot certonly --webroot \
    --webroot-path=/var/www/certbot \
    --email $EMAIL \
    --agree-tos \
    --no-eff-email \
    -d $DOMAIN \
    -d www.$DOMAIN

# Update nginx configuration with SSL
echo "🔧 Updating Nginx configuration with SSL..."
cat > nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    limit_req_zone \$binary_remote_addr zone=health:10m rate=30r/s;

    upstream task-api {
        server task-api:8080;
        keepalive 32;
    }

    # HTTP to HTTPS redirect
    server {
        listen 80;
        server_name $DOMAIN www.$DOMAIN;

        location /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }

        location / {
            return 301 https://\$server_name\$request_uri;
        }
    }

    # HTTPS server
    server {
        listen 443 ssl http2;
        server_name $DOMAIN www.$DOMAIN;

        # SSL configuration
        ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

        # SSL settings
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 10m;

        # API routes
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://task-api;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
        }

        # Health check with higher rate limit
        location /api/health {
            limit_req zone=health burst=50 nodelay;
            access_log off;
            proxy_pass http://task-api/api/health;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Root and home endpoints
        location / {
            limit_req zone=api burst=10 nodelay;
            proxy_pass http://task-api;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        # Static files (if any)
        location /static/ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            proxy_pass http://task-api;
        }
    }
}
EOF

# Reload nginx with new SSL configuration
echo "🔄 Reloading Nginx with SSL configuration..."
docker-compose -f docker-compose.ssl.yml restart nginx

# Set up automatic renewal
echo "🔄 Setting up automatic certificate renewal..."
sudo crontab -l 2>/dev/null | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet && docker-compose -f $(pwd)/docker-compose.ssl.yml restart nginx"; } | sudo crontab -

# Test SSL configuration
echo "🧪 Testing SSL configuration..."
sleep 10
if curl -k https://$DOMAIN/api/health > /dev/null 2>&1; then
    echo "✅ SSL setup completed successfully!"
    echo "🌐 Your API is now available at: https://$DOMAIN"
    echo "🔐 SSL certificate is valid and auto-renewal is configured"
else
    echo "⚠️ SSL setup completed but health check failed. Please check the logs."
fi

# Display SSL certificate information
echo "📋 SSL Certificate Information:"
sudo certbot certificates

echo "🎉 Setup completed! Your Task Management API is now secured with HTTPS."
echo "📝 Next steps:"
echo "   - Update your DNS to point to this server"
echo "   - Test all endpoints with https://$DOMAIN"
echo "   - Monitor certificate renewal with: sudo certbot renew --dry-run"
