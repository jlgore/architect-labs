#!/bin/bash -xe

# Update packages
yum update -y

# Install dependencies
yum install -y httpd mysql git jq
amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2

# Install Node.js
curl -sL https://rpm.nodesource.com/setup_16.x | bash -
yum install -y nodejs

# Create app directory
mkdir -p /var/www/cloudmart
cd /var/www/cloudmart

# Clone the repository (adjust this to your actual repository)
# git clone https://github.com/yourusername/cloudmart .

# If we're not cloning from a repository, we'll copy the app files from CloudFormation init
cp -r /tmp/app/* .

# Install npm dependencies
npm install

# Set environment variables for database connection
cat > /etc/environment << EOL
DB_HOST=${DB_HOST}
DB_USER=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
DB_NAME=${DB_NAME}
EOL

# Set up systemd service for the Node.js application
cat > /etc/systemd/system/cloudmart.service << EOL
[Unit]
Description=CloudMart Node.js Application
After=network.target

[Service]
Environment=DB_HOST=${DB_HOST} DB_USER=${DB_USER} DB_PASSWORD=${DB_PASSWORD} DB_NAME=${DB_NAME}
WorkingDirectory=/var/www/cloudmart
ExecStart=/usr/bin/node server.js
Restart=always
User=root
Group=root
Environment=PATH=/usr/bin:/usr/local/bin
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOL

# Enable and start the service
systemctl enable cloudmart.service
systemctl start cloudmart.service

# Set up Apache as a reverse proxy
cat > /etc/httpd/conf.d/cloudmart.conf << EOL
<VirtualHost *:80>
    ServerName localhost
    DocumentRoot /var/www/cloudmart/public

    # Proxy API requests to the Node.js application
    ProxyRequests Off
    ProxyPreserveHost On
    
    <Location /api>
        ProxyPass http://localhost:80/api
        ProxyPassReverse http://localhost:80/api
    </Location>
    
    <Location /health>
        ProxyPass http://localhost:80/health
        ProxyPassReverse http://localhost:80/health
    </Location>
    
    # Serve static files directly from Apache
    <Directory "/var/www/cloudmart/public">
        AllowOverride All
        Require all granted
    </Directory>
    
    ErrorLog /var/log/httpd/cloudmart-error.log
    CustomLog /var/log/httpd/cloudmart-access.log combined
</VirtualHost>
EOL

# Load mod_proxy and related modules
cat > /etc/httpd/conf.modules.d/00-proxy.conf << EOL
LoadModule proxy_module modules/mod_proxy.so
LoadModule proxy_http_module modules/mod_proxy_http.so
LoadModule proxy_balancer_module modules/mod_proxy_balancer.so
LoadModule lbmethod_byrequests_module modules/mod_lbmethod_byrequests.so
EOL

# Set permissions
chown -R apache:apache /var/www/cloudmart/public
chmod -R 755 /var/www/cloudmart

# Enable and start Apache
systemctl enable httpd
systemctl start httpd

# Create a simple script to test the API endpoints
chmod +x /var/www/cloudmart/test-api.sh

# Create a welcome page with instructions for testing the API
cat > /var/www/cloudmart/public/welcome.html << EOL
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>CloudMart API Testing</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
        }
        pre {
            background-color: #f4f4f4;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
        }
        .command {
            font-family: monospace;
            background-color: #f0f0f0;
            padding: 2px 5px;
            border-radius: 3px;
        }
    </style>
</head>
<body>
    <h1>Welcome to CloudMart API Testing</h1>
    
    <p>This page provides instructions for testing the CloudMart API endpoints using curl commands.</p>
    
    <h2>API Endpoints</h2>
    
    <h3>1. Get all products</h3>
    <pre>curl -s http://${PUBLIC_IP}/api/products | jq</pre>
    
    <h3>2. Get a specific product</h3>
    <pre>curl -s http://${PUBLIC_IP}/api/products/1 | jq</pre>
    
    <h3>3. Create a new product</h3>
    <pre>curl -s -X POST http://${PUBLIC_IP}/api/products \\
  -H "Content-Type: application/json" \\
  -d '{"name":"New Product","price":99.99,"description":"A new product","image":"https://via.placeholder.com/300x200?text=New+Product"}' | jq</pre>
    
    <h3>4. Update a product</h3>
    <pre>curl -s -X PUT http://${PUBLIC_IP}/api/products/1 \\
  -H "Content-Type: application/json" \\
  -d '{"name":"Updated Product","price":129.99}' | jq</pre>
    
    <h3>5. Delete a product</h3>
    <pre>curl -s -X DELETE http://${PUBLIC_IP}/api/products/1 | jq</pre>
    
    <h2>Automated Testing</h2>
    
    <p>You can run all these tests automatically by connecting to the instance via SSH and running the test script:</p>
    
    <pre>ssh ec2-user@${PUBLIC_IP}
sudo /var/www/cloudmart/test-api.sh localhost</pre>
    
    <h2>View the Web Application</h2>
    
    <p>You can also view the web application by navigating to <a href="http://${PUBLIC_IP}">http://${PUBLIC_IP}</a></p>
</body>
</html>
EOL

# Print info to logs
echo "CloudMart setup completed at $(date)" > /var/log/cloudmart-setup.log
echo "Database endpoint: ${DB_HOST}" >> /var/log/cloudmart-setup.log 