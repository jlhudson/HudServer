#!/bin/bash

# --- Configuration Variables ---
APP_DIR="/opt/hud-server"
JAR_NAME="hudson-0.0.1-SNAPSHOT.jar"
SERVICE_NAME="hud-server.service"

WIFI_COUNTRY_CODE="AU"
WIFI_SSID1="HudsonNetwork"
WIFI_PSK1="Budgies123"
WIFI_PRIORITY1=10

WIFI_SSID2="Claust wifi"
WIFI_PSK2="cla*wpa-psk"
WIFI_PRIORITY2=5

# --- Functions ---
log_info() {
    echo "INFO: $1"
}

log_error() {
    echo "ERROR: $1" >&2
    exit 1
}

# --- Pre-Checks ---
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script with sudo: sudo ./pi-setup.sh"
fi

# --- Display Version Information ---
log_info "=== HudServer Deployment Script ==="
log_info "Checking system requirements..."

# Check Java
if command -v java &> /dev/null; then
    JAVA_VERSION=$(java -version 2>&1 | head -n 1)
    log_info "✓ Java: $JAVA_VERSION"
else
    log_error "✗ Java not found. Install with: sudo apt update && sudo apt install -y openjdk-17-jdk"
fi

# Check Maven
if command -v mvn &> /dev/null; then
    MAVEN_VERSION=$(mvn -version 2>&1 | head -n 1)
    log_info "✓ Maven: $MAVEN_VERSION"
else
    log_error "✗ Maven not found. Install with: sudo apt update && sudo apt install -y maven"
fi

log_info "All requirements met. Proceeding with deployment..."
log_info ""

# --- 1. Configure Firewall FIRST (Security) ---
log_info "Configuring firewall for security..."
apt update && apt install -y ufw
ufw allow ssh
ufw allow 8080/tcp
ufw --force enable
log_info "Firewall configured: SSH and port 8080 allowed"

# --- 2. Configure Wi-Fi ---
log_info "Configuring Wi-Fi networks..."

# Check if wlan0 interface exists
if ! ip link show wlan0 &> /dev/null; then
    log_info "⚠ Warning: wlan0 interface not found. Skipping Wi-Fi configuration."
    log_info "  This is normal for wired connections or different wireless interfaces."
else
    # Clear existing network configurations
    sed -i '/^network={/,/^}$/d' /etc/wpa_supplicant/wpa_supplicant.conf

    cat <<EOF >> /etc/wpa_supplicant/wpa_supplicant.conf
country=${WIFI_COUNTRY_CODE}
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
    ssid="${WIFI_SSID1}"
    psk="${WIFI_PSK1}"
    priority=${WIFI_PRIORITY1}
}

network={
    ssid="${WIFI_SSID2}"
    psk="${WIFI_PSK2}"
    priority=${WIFI_PRIORITY2}
}
EOF

    log_info "Reloading Wi-Fi configuration..."
    if wpa_cli -i wlan0 reconfigure &> /dev/null; then
        log_info "✓ Wi-Fi configuration updated successfully"
        sleep 3
    else
        log_info "⚠ Warning: Could not reload Wi-Fi configuration. You may need to reboot."
    fi
fi

# --- 3. Build Spring Boot Application ---
log_info "Building Spring Boot application..."
mvn clean package -DskipTests || log_error "Maven build failed."
log_info "✓ Application built successfully"

# --- 4. Deploy Application ---
log_info "Deploying application to ${APP_DIR}..."
mkdir -p "${APP_DIR}"
cp "target/${JAR_NAME}" "${APP_DIR}/${JAR_NAME}" || log_error "Failed to copy JAR file."
log_info "✓ Application deployed"

# --- 5. Setup Systemd Service ---
log_info "Setting up systemd service..."
if [ ! -f "${SERVICE_NAME}" ]; then
    log_error "Service file ${SERVICE_NAME} not found in current directory."
fi

cp "${SERVICE_NAME}" "/etc/systemd/system/${SERVICE_NAME}" || log_error "Failed to copy service file."

log_info "Setting permissions and starting service..."
chown -R pi:pi "${APP_DIR}"
chmod 644 "/etc/systemd/system/${SERVICE_NAME}"

systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl start "${SERVICE_NAME}"

# Wait a moment for service to start
sleep 2

log_info "Service status:"
if systemctl is-active --quiet "${SERVICE_NAME}"; then
    log_info "✓ ${SERVICE_NAME} is running successfully"
    systemctl status "${SERVICE_NAME}" --no-pager -l
else
    log_info "⚠ ${SERVICE_NAME} may have issues starting. Check logs below:"
    systemctl status "${SERVICE_NAME}" --no-pager -l
fi

# --- 6. Final Information ---
log_info ""
log_info "=== Deployment Complete! ==="
log_info ""
log_info "🚀 Your HudServer application is running!"
log_info ""
log_info "📡 Access URLs:"
log_info "  Local IP:   http://$(hostname -I | awk '{print $1}'):8080/hello"
log_info "  Hostname:   http://$(hostname).local:8080/hello"
log_info ""
log_info "🔧 Useful commands:"
log_info "  View logs:     sudo journalctl -u ${SERVICE_NAME} -f"
log_info "  Restart app:   sudo systemctl restart ${SERVICE_NAME}"
log_info "  Stop app:      sudo systemctl stop ${SERVICE_NAME}"
log_info "  Service status: sudo systemctl status ${SERVICE_NAME}"
log_info ""
log_info "🛡️ Firewall status:"
ufw status verbose
log_info ""

read -p "Reboot now to ensure all changes take effect? (y/n): " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    log_info "Rebooting in 3 seconds..."
    sleep 3
    reboot
else
    log_info "✓ Setup complete! Remember to reboot later if needed."
fi