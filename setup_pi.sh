#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

REPO_NAME="my-hud-server-app" # Name of your GitHub repository
APP_DIR="/opt/hud-server"
SERVICE_FILE="hud-server.service"
UPDATE_SCRIPT="update_app.sh"
GITHUB_REPO_URL="https://github.com/your-github-username/$REPO_NAME.git" # IMPORTANT: CHANGE THIS TO YOUR REPO URL!
JAR_NAME="hud-server-0.0.1-SNAPSHOT.jar" # Adjust if your pom.xml generates a different name

echo "--- Starting Raspberry Pi Spring Boot Application Setup ---"
echo "This script will: "
echo "1. Update system packages."
echo "2. Install OpenJDK 17 and Maven."
echo "3. Build your Spring Boot application."
echo "4. Create necessary directories and copy the application JAR."
echo "5. Set up the application as a systemd service."
echo "6. Configure UFW firewall."
echo "7. Deploy the update script."
echo "8. Provide guidance on Wi-Fi configuration and security."
echo ""
read -p "Press Enter to continue or Ctrl+C to abort..."

# --- 1. Update System and Install Prerequisites ---
echo "Updating system packages and installing prerequisites..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y openjdk-17-jdk maven git ufw

echo "Prerequisites installed."

# --- 2. Build the Spring Boot Application ---
echo "Building the Spring Boot application on the Pi..."
# Navigate to the root of the cloned repository (one level up from pi_setup)
CURRENT_DIR=$(pwd)
cd ../ # Move up to my-hud-server-app/
PROJECT_ROOT=$(pwd)

# Perform Maven clean package
# -DskipTests: Skip running tests to save time and resources on the Pi.
mvn clean package -DskipTests
if [ $? -ne 0 ]; then
    echo "ERROR: Maven build failed. Please check the output above for errors."
    echo "Aborting setup."
    exit 1
fi

echo "Application built successfully."
cd "$CURRENT_DIR" # Go back to pi_setup directory

# --- 3. Create Application Directory and Copy JAR ---
echo "Creating application directory and copying JAR..."
sudo mkdir -p "$APP_DIR"
sudo cp "$PROJECT_ROOT/target/$JAR_NAME" "$APP_DIR/$JAR_NAME"

# Check if JAR was copied
if [ ! -f "$APP_DIR/$JAR_NAME" ]; then
    echo "ERROR: JAR file was not copied to $APP_DIR. Check JAR_NAME and build path."
    exit 1
fi
echo "JAR copied to $APP_DIR"

# --- 4. Set up Systemd Service ---
echo "Setting up systemd service..."
sudo cp "$SERVICE_FILE" "/etc/systemd/system/$SERVICE_FILE"
sudo sed -i "s|{{APP_DIR}}|$APP_DIR|g" "/etc/systemd/system/$SERVICE_FILE"
sudo sed -i "s|{{JAR_NAME}}|$JAR_NAME|g" "/etc/systemd/system/$SERVICE_FILE"

sudo systemctl daemon-reload
sudo systemctl enable "$SERVICE_FILE"
sudo systemctl start "$SERVICE_FILE"

echo "Systemd service '$SERVICE_FILE' set up and started."
echo "Check service status: sudo systemctl status $SERVICE_FILE"
echo "View logs: sudo journalctl -u $SERVICE_FILE -f"

# --- 5. Configure UFW Firewall ---
echo "Configuring UFW firewall..."
sudo ufw allow ssh
sudo ufw allow 8080/tcp # Assuming your Spring Boot app runs on port 8080
sudo ufw enable
echo "UFW enabled. SSH (port 22) and Spring Boot app (port 8080) are allowed."
echo "Check UFW status: sudo ufw status verbose"

# --- 6. Deploy Update Script ---
echo "Deploying update script..."
sudo cp "$UPDATE_SCRIPT" "/usr/local/bin/$UPDATE_SCRIPT"
sudo chmod +x "/usr/local/bin/$UPDATE_SCRIPT"
sudo sed -i "s|{{GITHUB_REPO_URL}}|$GITHUB_REPO_URL|g" "/usr/local/bin/$UPDATE_SCRIPT"
sudo sed -i "s|{{APP_DIR}}|$APP_DIR|g" "/usr/local/bin/$UPDATE_SCRIPT"
sudo sed -i "s|{{JAR_NAME}}|$JAR_NAME|g" "/usr/local/bin/$UPDATE_SCRIPT"
sudo sed -i "s|{{SERVICE_FILE}}|$SERVICE_FILE|g" "/usr/local/bin/$UPDATE_SCRIPT"
sudo sed -i "s|{{REPO_NAME}}|$REPO_NAME|g" "/usr/local/bin/$UPDATE_SCRIPT"

echo "Update script '$UPDATE_SCRIPT' deployed to /usr/local/bin/. You can run it manually with: sudo /usr/local/bin/$UPDATE_SCRIPT"

# --- 7. Post-Setup Guidance ---
echo "--- Setup Complete! ---"
echo ""
echo "############################################################"
echo "### IMPORTANT MANUAL STEPS AND CONSIDERATIONS            ###"
echo "############################################################"
echo ""
echo "1.  Wi-Fi Configuration (if not done via Imager or needs multi-network setup):"
echo "    DO NOT COMMIT WI-FI PASSWORDS TO GITHUB!"
echo "    Edit /etc/wpa_supplicant/wpa_supplicant.conf directly on the Pi:"
echo "    sudo nano /etc/wpa_supplicant/wpa_supplicant.conf"
echo "    Add your networks with priority:"
echo "    network={"
echo "        ssid=\"YourHomeWifiName\""
echo "        psk=\"YourHomeWifiPassword\""
echo "        priority=10"
echo "    }"
echo "    Then: sudo wpa_cli -i wlan0 reconfigure or sudo reboot"
echo ""
echo "2.  Security Best Practices:"
echo "    - Change the default 'pi' user password immediately: passwd"
echo "    - Set up SSH Key authentication and disable password login (highly recommended for security)."
echo "      Guide: https://www.raspberrypi.com/documentation/computers/remote-access.html#ssh"
echo "    - (Optional) Change the default SSH port (remember to update UFW rules)."
echo ""
echo "3.  Accessing Your Application:"
echo "    Your app should be accessible at http://<your_pi_hostname>.local:8080/hello"
echo "    (e.g., http://raspberrypi.local:8080/hello)"
echo "    If you changed the hostname: sudo raspi-config -> System Options -> Hostname"
echo ""
echo "4.  Remote Access (from outside your local network):"
echo "    - VPN (Recommended for Security): Use PiVPN (WireGuard/OpenVPN) for secure remote access."
echo "      Install: curl -L https://install.pivpn.io | bash"
echo "    - Port Forwarding (Less Secure): Configure your router to forward port 8080 to the Pi's IP."
echo "      Only do this if you understand the risks and have strong Spring Security enabled."
echo ""
echo "5.  Automating Updates (Optional):"
echo "    To make the update script run periodically (e.g., daily):"
echo "    sudo nano /etc/systemd/system/hud-server-update.service"
echo "    [Unit]"
echo "    Description=Hudson's Spring Boot Application Updater"
echo "    [Service]"
echo "    Type=oneshot"
echo "    ExecStart=/usr/local/bin/$UPDATE_SCRIPT"
echo "    User=pi"
echo "    Group=pi"
echo ""
echo "    sudo nano /etc/systemd/system/hud-server-update.timer"
echo "    [Unit]"
echo "    Description=Run Hudson's Spring Boot Application Update Daily"
echo "    [Timer]"
echo "    OnCalendar=daily"
echo "    [Install]"
echo "    WantedBy=timers.target"
echo ""
echo "    sudo systemctl daemon-reload"
echo "    sudo systemctl enable hud-server-update.timer"
echo "    sudo systemctl start hud-server-update.timer"
echo "    sudo systemctl list-timers"
echo ""
echo "Please reboot your Raspberry Pi to ensure all changes take full effect: sudo reboot"