#!/bin/bash

# Deploy script for Task Management API with SSL support
# Usage: ./deploy.sh [production|staging] [domain]

set -e

ENVIRONMENT=${1:-production}
DOMAIN=${2:-""}
PROJECT_NAME="task-management-api"
DOCKER_IMAGE="$PROJECT_NAME:latest"
CONTAINER_NAME="$PROJECT_NAME-$ENVIRONMENT"

echo "🚀 Starting deployment for $ENVIRONMENT environment..."

# Build the project
echo "📦 Building application..."
./gradlew clean buildFatJar

# Build Docker image
echo "🐳 Building Docker image..."
docker build -t $DOCKER_IMAGE .

# Stop existing containers
echo "🛑 Stopping existing containers..."
docker-compose -f docker-compose.ssl.yml down 2>/dev/null || true
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

# Check if SSL is requested and domain is provided
if [ "$ENVIRONMENT" = "production" ] && [ -n "$DOMAIN" ]; then
    echo "🔒 Production deployment with SSL for domain: $DOMAIN"

    # Check if SSL certificates exist
    if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo "⚠️ SSL certificates not found. Running SSL setup..."
        ./setup-ssl.sh $DOMAIN
    else
        echo "✅ SSL certificates found. Starting with SSL configuration..."
        docker-compose -f docker-compose.ssl.yml up -d
    fi

    # Health check with HTTPS
    echo "🏥 Performing HTTPS health check..."
    sleep 15
    HEALTH_URL="https://$DOMAIN/api/health"

elif [ "$ENVIRONMENT" = "production" ]; then
    echo "🔓 Production deployment without SSL (HTTP only)"
    # Run without SSL
    docker run -d \
        --name $CONTAINER_NAME \
        --restart unless-stopped \
        -p 8080:8080 \
        -e KTOR_ENV=production \
        -e KTOR_LOG_LEVEL=INFO \
        $DOCKER_IMAGE

    HEALTH_URL="http://localhost:8080/api/health"

else
    echo "🧪 Staging deployment"
    # Staging environment
    docker run -d \
        --name $CONTAINER_NAME \
        --restart unless-stopped \
        -p 8081:8080 \
        -e KTOR_ENV=staging \
        -e KTOR_LOG_LEVEL=DEBUG \
        $DOCKER_IMAGE

    HEALTH_URL="http://localhost:8081/api/health"
fi

# Health check
echo "🏥 Performing health check..."
sleep 10

if curl -f -k $HEALTH_URL > /dev/null 2>&1; then
    echo "✅ Deployment successful! API is healthy."
    echo "🌐 API is available at: $HEALTH_URL"
    if [ -n "$DOMAIN" ]; then
        echo "🔐 HTTPS URL: https://$DOMAIN"
        echo "🔗 API endpoints:"
        echo "   - Tasks: https://$DOMAIN/api/tasks"
        echo "   - Health: https://$DOMAIN/api/health"
        echo "   - Info: https://$DOMAIN/home"
    fi
else
    echo "❌ Health check failed!"
    echo "🔍 Check logs with: docker logs $CONTAINER_NAME"
    exit 1
fi

# Clean up old images
echo "🧹 Cleaning up old Docker images..."
docker image prune -f

echo "🎉 Deployment completed successfully!"

# Show SSL certificate info if available
if [ -n "$DOMAIN" ] && [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    echo "📋 SSL Certificate Status:"
    sudo certbot certificates -d $DOMAIN 2>/dev/null || echo "Run 'sudo certbot certificates' to check SSL status"
fi
