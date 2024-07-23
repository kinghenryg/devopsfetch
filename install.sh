#!/bin/bash

set -e

# Install dependencies
sudo apt-get update
sudo apt-get install -y docker.io nginx

# Copy devopsfetch script to /usr/local/bin
sudo cp devopsfetch.sh /usr/local/bin/devopsfetch
sudo chmod +x /usr/local/bin/devopsfetch

# Set up systemd service
cat << EOF | sudo tee /etc/systemd/system/devopsfetch.service
[Unit]
Description=DevOpsFetch Monitoring Service
After=network.target

[Service]
ExecStart=/usr/local/bin/devopsfetch -t "1 hour ago"
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable devopsfetch.service
sudo systemctl start devopsfetch.service

echo "DevOpsFetch has been installed and the monitoring service has been started."

