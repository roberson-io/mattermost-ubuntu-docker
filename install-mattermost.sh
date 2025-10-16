#!/bin/bash

set -e  # Exit on any error

echo "==========================================="
echo "Mattermost Docker Installation Script"
echo "==========================================="
echo ""

# Check if running on Ubuntu
if [ ! -f /etc/os-release ]; then
    echo "Error: Cannot detect OS version"
    exit 1
fi

source /etc/os-release
if [ "$ID" != "ubuntu" ]; then
    echo "Error: This script is designed for Ubuntu only"
    exit 1
fi

echo "Detected Ubuntu $VERSION"
echo ""

# Step 1: Uninstall conflicting packages
echo "Step 1: Removing conflicting packages..."
for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do
    sudo apt-get remove -y $pkg 2>/dev/null || true
done
echo "✓ Conflicting packages removed"
echo ""

# Step 2: Install Docker Engine
echo "Step 2: Installing Docker Engine..."

# Update package index and install prerequisites
echo "Installing prerequisites..."
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Add Docker's official GPG key
echo "Adding Docker GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "Adding Docker repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker packages
echo "Installing Docker packages..."
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

echo "✓ Docker Engine installed successfully"
echo ""

# Step 3: Verify Docker installation
echo "Step 3: Verifying Docker installation..."
sudo docker --version
sudo docker compose version
echo "✓ Docker verified"
echo ""

# Step 4: Optional - Add current user to docker group
echo "Step 4: Configuring Docker permissions..."
read -p "Add current user ($USER) to docker group to run without sudo? (y/n): " -n 1 -r
echo
USE_SUDO="sudo"
if [[ $REPLY =~ ^[Yy]$ ]]; then
    sudo usermod -aG docker $USER
    echo "✓ User added to docker group"
    echo "  Activating docker group for this session..."
    USE_SUDO="sg docker -c"
else
    echo "Skipped adding user to docker group"
    echo "  Docker commands will use sudo"
fi
echo ""

# Step 5: Deploy Mattermost
echo "Step 5: Deploying Mattermost..."

# Clone Mattermost Docker repository
if [ -d "./mattermost-docker" ]; then
    echo "Mattermost docker directory already exists, using existing directory..."
    cd mattermost-docker
else
    echo "Cloning Mattermost Docker repository..."
    git clone https://github.com/mattermost/docker mattermost-docker
    cd mattermost-docker
fi

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    echo "Creating .env configuration file..."
    cp env.example .env

    # Prompt for domain
    read -p "Enter your domain name (e.g., mattermost.example.com): " DOMAIN
    sed -i "s/DOMAIN=.*/DOMAIN=$DOMAIN/" .env

    echo "✓ Configuration file created"
    echo "  You can edit .env file to customize your installation"
else
    echo ".env file already exists, skipping creation"
fi

# Create required directories and set permissions
echo "Creating Mattermost directories..."
mkdir -p ./volumes/app/mattermost/{config,data,logs,plugins,client/plugins,bleve-indexes}
sudo chown -R 2000:2000 ./volumes/app/mattermost
echo "✓ Directories created with proper permissions"
echo ""

# Ask user about NGINX
echo "Deployment options:"
echo "1. Without NGINX (access via http://<domain>:8065)"
echo "2. With NGINX (access via https://<domain>)"
read -p "Select deployment option (1/2): " -n 1 -r
echo
echo ""

if [[ $REPLY == "2" ]]; then
    echo "Deploying Mattermost with NGINX..."
    if [ "$USE_SUDO" = "sudo" ]; then
        sudo docker compose -f docker-compose.yml -f docker-compose.nginx.yml up -d
    else
        sg docker -c "docker compose -f docker-compose.yml -f docker-compose.nginx.yml up -d"
    fi
    echo ""
    echo "==========================================="
    echo "✓ Mattermost deployed successfully!"
    echo "==========================================="
    echo ""
    echo "Access Mattermost at: https://$(grep DOMAIN= .env | cut -d'=' -f2)/"
    echo ""
    echo "Note: Configure TLS certificates in ./nginx/certs/ for HTTPS to work properly"
else
    echo "Deploying Mattermost without NGINX..."
    if [ "$USE_SUDO" = "sudo" ]; then
        sudo docker compose -f docker-compose.yml -f docker-compose.without-nginx.yml up -d
    else
        sg docker -c "docker compose -f docker-compose.yml -f docker-compose.without-nginx.yml up -d"
    fi
    echo ""
    echo "==========================================="
    echo "✓ Mattermost deployed successfully!"
    echo "==========================================="
    echo ""
    echo "Access Mattermost at: http://$(grep DOMAIN= .env | cut -d'=' -f2):8065/"
fi

echo ""
echo "Useful commands:"
if [ "$USE_SUDO" = "sudo" ]; then
    echo "  Check status: sudo docker compose ps"
    echo "  View logs:    sudo docker compose logs -f"
    echo "  Stop:         sudo docker compose down"
    echo "  Restart:      sudo docker compose restart"
    echo ""
    echo "  Start without NGINX: sudo docker compose -f docker-compose.yml -f docker-compose.without-nginx.yml up -d"
    echo "  Start with NGINX:    sudo docker compose -f docker-compose.yml -f docker-compose.nginx.yml up -d"
else
    echo "  Check status: docker compose ps"
    echo "  View logs:    docker compose logs -f"
    echo "  Stop:         docker compose down"
    echo "  Restart:      docker compose restart"
    echo ""
    echo "  Start without NGINX: docker compose -f docker-compose.yml -f docker-compose.without-nginx.yml up -d"
    echo "  Start with NGINX:    docker compose -f docker-compose.yml -f docker-compose.nginx.yml up -d"
    echo ""
    echo "  Note: Docker group is active. Log out and back in to use docker"
    echo "        without 'sg docker -c' in future sessions."
fi
echo ""
