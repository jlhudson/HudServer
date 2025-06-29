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

# --- 1. Install UFW if needed ---
log_info "Installing UFW firewall if not present..."
apt update && apt install -y ufw

# --- 2. Configure Wi-Fi ---
log_info "Configuring Wi-Fi networks..."
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
wpa_cli -i wlan0 reconfigure
sleep 5

# --- 3. Build Spring Boot Application ---
log_info "Building Spring Boot application with Maven..."
mvn clean package -DskipTests || log_error "Maven build failed."

# --- 4. Deploy Application ---
log_info "Creating application directory ${APP_DIR}..."
mkdir -p "${APP_DIR}"

log_info "Copying JAR file to ${APP_DIR}..."
cp "target/${JAR_NAME}" "${APP_DIR}/${JAR_NAME}" || log_error "Failed to copy JAR file."

# --- 5. Setup Systemd Service ---
log_info "Creating systemd service file..."
cp "${SERVICE_NAME}" "/etc/systemd/system/${SERVICE_NAME}" || log_error "Failed to copy service file. Make sure ${SERVICE_NAME} exists in current directory."

log_info "Setting correct permissions..."
chown -R pi:pi "${APP_DIR}"
chmod 644 "/etc/systemd/system/${SERVICE_NAME}"

log_info "Enabling and starting ${SERVICE_NAME}..."
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}"
systemctl start "${SERVICE_NAME}"

log_info "Checking service status..."
systemctl status "${SERVICE_NAME}" --no-pager -l

# --- 6. Configure Firewall ---
log_info "Configuring firewall..."
ufw allow ssh
ufw allow 8080/tcp
ufw --force enable

log_info "Firewall status:"
ufw status verbose

# --- 7. Final Steps ---
log_info "Setup complete! Your Spring Boot application is running."
log_info ""
log_info "Useful commands:"
log_info "  Check logs: sudo journalctl -u ${SERVICE_NAME} -f"
log_info "  Restart app: sudo systemctl restart ${SERVICE_NAME}"
log_info "  Stop app: sudo systemctl stop ${SERVICE_NAME}"
log_info ""
log_info "Access your application at:"
log_info "  http://$(hostname -I | awk '{print $1}'):8080/hello"
log_info "  http://$(hostname).local:8080/hello"
log_info ""
read -p "Reboot now to ensure all changes take effect? (y/n): " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    log_info "Rebooting..."
    reboot
else
    log_info "Remember to reboot later for all changes to take effect."
fi