#!/bin/bash

# Quick redeploy script for HudServer
# Usage: ./redeploy.sh

APP_DIR="/opt/hud-server"
JAR_NAME="hudson-0.0.1-SNAPSHOT.jar"
SERVICE_NAME="hud-server.service"
REPO_DIR="~/HudServer"

echo "🛑 Stopping HudServer..."
sudo systemctl stop $SERVICE_NAME

echo "📥 Pulling latest code from GitHub..."
cd $REPO_DIR
git pull

echo "🔨 Building application..."
mvn clean package -DskipTests

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"

    echo "📦 Deploying new JAR..."
    sudo cp target/$JAR_NAME $APP_DIR/$JAR_NAME

    echo "🚀 Starting HudServer..."
    sudo systemctl start $SERVICE_NAME

    echo "📊 Service status:"
    sudo systemctl status $SERVICE_NAME --no-pager -l

    echo ""
    echo "🎉 Redeploy complete!"
    echo "🌐 Access at: http://$(hostname -I | awk '{print $1}'):8080/hello"
    echo "📋 Dashboard: http://$(hostname -I | awk '{print $1}'):8080/dashboard"
else
    echo "❌ Build failed! Service remains stopped."
    echo "🔧 Check logs with: mvn clean package -DskipTests"
fi