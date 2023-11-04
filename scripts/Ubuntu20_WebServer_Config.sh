#!/bin/bash

# Update the package repository and install Nginx
sudo apt update
sudo apt install -y nginx

# Start the Nginx service
sudo systemctl start nginx

# Enable Nginx to start on boot
sudo systemctl enable nginx

# Configure a basic Nginx site
sudo tee /etc/nginx/sites-available/default >/dev/null <<EOL
server {
    listen 80;
    server_name your_domain.com;  # Replace with your domain name or server IP

    location / {
        root /var/www/html;
        index index.html;
    }

    # Additional Nginx configuration (if needed)

    error_page 404 /404.html;
    error_page 500 502 503 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
    }
}
EOL

# Create the web root directory
sudo mkdir -p /var/www/html

# Create a sample index.html file
sudo tee /var/www/html/index.html >/dev/null <<EOL
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to Nginx</title>
</head>
<body>
    <h1>Hello, Nginx!</h1>
</body>
</html>
EOL

# Reload Nginx to apply the configuration changes
sudo systemctl reload nginx