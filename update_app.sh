#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# These variables will be replaced by setup_pi.sh
GITHUB_REPO_URL="{{GITHUB_REPO_URL}}"
REPO_NAME="{{REPO_NAME}}"
APP_DIR="{{APP_DIR}}"
JAR_NAME="{{JAR_NAME}}"
SERVICE_FILE="{{SERVICE_FILE}}"

# Derived paths
PROJECT_ROOT="/home/pi/$REPO_NAME" # Assuming cloned to /home/pi/my-hud-server-app
BRANCH="main" # Or your main branch name

echo "--- Starting application update process ---"

# 1. Stop the application service
echo "Stopping $SERVICE_FILE..."
sudo systemctl stop "$SERVICE_FILE" || true # Use || true to prevent script from exiting if service isn't running
sleep 5 # Give it time to stop

# 2. Update source code from GitHub
echo "Updating source code from GitHub: $GITHUB_REPO_URL"
if [ ! -d "$PROJECT_ROOT" ]; then
    echo "Repository not found at $PROJECT_ROOT. Cloning now."
    git clone "$GITHUB_REPO_URL" "$PROJECT_ROOT"
    cd "$PROJECT_ROOT"
else
    echo "Repository exists. Pulling latest changes."
    cd "$PROJECT_ROOT"
    git pull origin "$BRANCH"
fi

# Check if git pull/clone was successful
if [ $? -ne 0 ]; then
    echo "ERROR: Git pull/clone failed. Aborting update. Attempting to restart previous application."
    sudo systemctl start "$SERVICE_FILE" || true
    exit 1
fi

# 3. Rebuild the application
echo "Building the application on the Pi using Maven..."
mvn clean package -DskipTests
if [ $? -ne 0 ]; then
    echo "ERROR: Maven build failed. Check logs for errors. Attempting to restart previous application."
    sudo systemctl start "$SERVICE_FILE" || true
    exit 1
fi

# 4. Copy the new JAR to the application directory
echo "Copying the new JAR to $APP_DIR."
if [ -f "$PROJECT_ROOT/target/$JAR_NAME" ]; then
    sudo cp "$PROJECT_ROOT/target/$JAR_NAME" "$APP_DIR/$JAR_NAME"
else
    echo "ERROR: New JAR not found at $PROJECT_ROOT/target/$JAR_NAME. Build failed or JAR name is incorrect. Attempting to restart previous application."
    sudo systemctl start "$SERVICE_FILE" || true
    exit 1
fi

# 5. Restart the application service
echo "Restarting $SERVICE_FILE..."
sudo systemctl start "$SERVICE_FILE"
echo "--- Update process finished. Check service status using 'sudo systemctl status $SERVICE_FILE'. ---"