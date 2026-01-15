#!/bin/bash
set -e

# Update system packages
apt-get update
apt-get upgrade -y

# Install Apache2
apt-get install -y apache2

# Enable Apache2 service
systemctl enable apache2
systemctl start apache2

# Create a simple health check page
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Apache Server Running</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; }
        .container { text-align: center; }
        h1 { color: #333; }
        .success { color: #28a745; font-size: 18px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Apache2 Web Server</h1>
        <p class="success">✓ Server is running successfully!</p>
        <p>Hostname: $(hostname)</p>
        <p>IP Address: $(hostname -I)</p>
        <p>Timestamp: $(date)</p>
    </div>
</body>
</html>
EOF

echo "Apache2 installation and configuration completed successfully"
