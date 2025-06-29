#!/bin/bash

# --- Configuration Variables ---
GITHUB_REPO_URL="https://github.com/jlhudson/HudServer.git"
GIT_BRANCH="main"
APP_DIR="/opt/hud-server"
JAR_NAME="hudson-0.0.1-SNAPSHOT.jar" # IMPORTANT: Update if your artifactId/version changes
SERVICE_NAME="hud-server.service"
JAVA_VERSION="24" # Using already installed Java 24

WIFI_COUNTRY_CODE="AU" # Your Wi-Fi country code

WIFI_SSID1="HudsonNetwork" #
WIFI_PSK1="Budgies123" #
WIFI_PRIORITY1=10

WIFI_SSID2="Claust wifi" #
WIFI_PSK2="cla*wpa-psk" #
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
    log_error "Please run this script with sudo: sudo ./setup.sh"
fi

# --- 1. Install System Dependencies ---
log_info "Updating package lists..."
apt update || log_error "Failed to update package lists."

log_info "Installing UFW (firewall)..."
apt install -y ufw || log_error "Failed to install UFW."

# --- 2. Verify Required Tools ---
log_info "Verifying Java installation..."
java -version || log_error "Java is not installed or not in PATH."

log_info "Verifying Git installation..."
git --version || log_error "Git is not installed or not in PATH."

log_info "Verifying Maven installation..."
if ! mvn -version &>/dev/null; then
    log_info "Maven is not working properly with Java 24. Trying latest Maven version..."

    # Try latest Maven version first (3.9.10)
    MAVEN_VERSION="3.9.10"
    MAVEN_URL="https://archive.apache.org/dist/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"
    MAVEN_ARCHIVE="apache-maven-${MAVEN_VERSION}-bin.tar.gz"

    log_info "Downloading Maven ${MAVEN_VERSION}..."
    wget -O /tmp/${MAVEN_ARCHIVE} "${MAVEN_URL}" || log_error "Failed to download Maven."

    log_info "Installing Maven to /opt/maven..."
    mkdir -p /opt/maven
    tar -xzf /tmp/${MAVEN_ARCHIVE} -C /opt/maven/ --strip-components=1 || log_error "Failed to extract Maven."

    log_info "Setting up Maven environment..."
    # Update alternatives to use the new Maven
    update-alternatives --install "/usr/bin/mvn" "mvn" "/opt/maven/bin/mvn" 1
    update-alternatives --set mvn "/opt/maven/bin/mvn"

    # Set MAVEN_HOME environment variable
    echo 'export MAVEN_HOME=/opt/maven' >> /etc/environment
    echo 'export PATH=$PATH:$MAVEN_HOME/bin' >> /etc/environment
    export MAVEN_HOME=/opt/maven
    export PATH=$PATH:$MAVEN_HOME/bin

    log_info "Cleaning up Maven archive..."
    rm /tmp/${MAVEN_ARCHIVE}

    log_info "Verifying new Maven installation..."
    if ! /opt/maven/bin/mvn -version &>/dev/null; then
        log_info "Maven 3.9.10 still has issues with Java 24. Installing Java 17 as fallback..."

        # Install Java 17 as fallback for Maven builds
        apt install -y openjdk-17-jdk || log_error "Failed to install Java 17."

        # Create a wrapper script that uses Java 17 for Maven
        cat > /opt/maven/bin/mvn-java17 << 'EOF'
#!/bin/bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-arm64
export PATH=$JAVA_HOME/bin:$PATH
exec /opt/maven/bin/mvn "$@"
EOF
        chmod +x /opt/maven/bin/mvn-java17

        log_info "Testing Maven with Java 17..."
        /opt/maven/bin/mvn-java17 -version || log_error "Maven with Java 17 fallback failed."

        log_info "Maven will use Java 17 for builds. Created mvn-java17 wrapper."
    else
        log_info "Maven 3.9.10 is working with Java 24."
    fi
else
    log_info "Maven is working correctly."
fi

# --- 3. Configure Wi-Fi ---
log_info "Configuring Wi-Fi networks..."
# Clear existing network configurations (optional, but ensures clean slate)
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
wpa_cli -i wlan0 reconfigure || log_error "Failed to reconfigure wpa_supplicant."
sleep 5 # Give time for network to connect

# --- 4. Build Spring Boot Application ---
log_info "Building Spring Boot application with Maven..."
# Determine which Maven command to use
if [ -f "/opt/maven/bin/mvn-java17" ]; then
    log_info "Using Maven with Java 17 fallback for build compatibility..."
    /opt/maven/bin/mvn-java17 clean package -DskipTests || log_error "Maven build failed."
elif [ -f "/opt/maven/bin/mvn" ]; then
    /opt/maven/bin/mvn clean package -DskipTests || log_error "Maven build failed."
else
    mvn clean package -DskipTests || log_error "Maven build failed."
fi

# --- 5. Deploy Application and Setup Systemd Service ---
log_info "Creating application directory ${APP_DIR}..."
mkdir -p "${APP_DIR}" || log_error "Failed to create application directory."

log_info "Copying JAR file to ${APP_DIR}..."
cp "target/${JAR_NAME}" "${APP_DIR}/${JAR_NAME}" || log_error "Failed to copy JAR file."

log_info "Creating systemd service file..."
cp "pi-setup/${SERVICE_NAME}" "/etc/systemd/system/${SERVICE_NAME}" || log_error "Failed to copy service file."

log_info "Setting correct permissions for application directory and service file."
chown -R pi:pi "${APP_DIR}" # Ensure pi user owns the application directory
chmod 644 "/etc/systemd/system/${SERVICE_NAME}" # Standard permissions for service files

log_info "Reloading systemd daemon..."
systemctl daemon-reload || log_error "Failed to reload systemd daemon."

log_info "Enabling ${SERVICE_NAME} to start on boot..."
systemctl enable "${SERVICE_NAME}" || log_error "Failed to enable service."

log_info "Starting ${SERVICE_NAME}..."
systemctl start "${SERVICE_NAME}" || log_error "Failed to start service."

log_info "Checking status of ${SERVICE_NAME}..."
systemctl status "${SERVICE_NAME}"

# --- 6. Configure Firewall (UFW) ---
log_info "Configuring firewall (UFW)..."
ufw allow ssh || log_error "Failed to allow SSH in UFW."
ufw allow 8080/tcp || log_error "Failed to allow Spring Boot port 8080 in UFW."
ufw --force enable || log_error "Failed to enable UFW."

log_info "Firewall status:"
ufw status verbose

# --- 7. Final Steps ---
log_info "Setup complete. Your Spring Boot application should now be running."
log_info "You can check its logs with: sudo journalctl -u ${SERVICE_NAME} -f"
log_info "Access your application at http://$(hostname -I | awk '{print $1}'):8080/hello (using IP) or http://$(hostname).local:8080/hello (using hostname.local)"
log_info "It is recommended to reboot your Raspberry Pi for all changes to take full effect."
read -p "Reboot now? (y/n): " REBOOT_CHOICE
if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
    log_info "Rebooting Raspberry Pi..."
    reboot
else
    log_info "Please remember to reboot later."
fi