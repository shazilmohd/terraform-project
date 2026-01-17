#!/bin/bash
set -e

# Environment passed from Terraform
ENVIRONMENT="${environment}"

# Update system packages
apt-get update -y
apt-get upgrade -y

# Install Apache2
apt-get install -y apache2

# Enable Apache2 service
systemctl enable apache2
systemctl start apache2

# Create Apache health check page
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
    <title>Apache Server Running - ${environment} Environment</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 50px; background-color: #f5f5f5; }
        .container { 
            text-align: center; 
            background-color: white; 
            padding: 40px; 
            border-radius: 10px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            max-width: 600px;
            margin: 0 auto;
        }
        h1 { color: #333; }
        .environment-badge {
            display: inline-block;
            padding: 10px 20px;
            border-radius: 5px;
            font-weight: bold;
            font-size: 20px;
            margin: 20px 0;
        }
        .dev { background-color: #d4edda; color: #155724; }
        .stage { background-color: #fff3cd; color: #856404; }
        .prod { background-color: #f8d7da; color: #721c24; }
        .success { color: #28a745; font-size: 18px; }
        .info { color: #666; font-size: 16px; margin: 10px 0; }
        .timestamp { color: #999; font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>Apache2 Web Server</h1>
        <p class="success">✓ Server is running successfully!</p>

        <div class="environment-badge ${environment}">
            Environment: ${environment}
        </div>

        <div class="info">
            <strong>Hostname:</strong> $$(hostname)<br>
            <strong>IP Address:</strong> $$(hostname -I | awk '{print $1}')<br>
            <strong>Instance ID:</strong> $$(ec2-metadata --instance-id 2>/dev/null | awk '{print $$2}' || echo "N/A")<br>
            <strong>Availability Zone:</strong> $$(ec2-metadata --availability-zone 2>/dev/null | awk '{print $$2}' || echo "N/A")
        </div>

        <p class="timestamp">Deployed at: $$(date)</p>
    </div>
</body>
</html>
EOF

echo "Apache2 installation completed successfully for ${environment} environment"