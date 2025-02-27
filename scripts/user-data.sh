#!/bin/bash
# Update package lists
dnf update -y

# Install Docker
dnf install -y docker
systemctl start docker
systemctl enable docker

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Install Nginx and other tools
dnf install -y nginx jq

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
dnf install -y unzip
unzip awscliv2.zip
./aws/install
rm -rf awscliv2.zip aws

# Configure Docker permissions
usermod -aG docker ec2-user
chmod 666 /var/run/docker.sock

# Set up AWS region configuration
mkdir -p /root/.aws /home/ec2-user/.aws
cat > /home/ec2-user/.aws/config << AWSCONFIG
[default]
region = us-west-2
output = json
AWSCONFIG

# Copy config to root user
cp /home/ec2-user/.aws/config /root/.aws/config

# Set correct permissions
chown -R ec2-user:ec2-user /home/ec2-user/.aws

# Create Nginx configuration
cat > /etc/nginx/conf.d/default.conf << 'NGINXCONF'
server {
    listen 80;
    server_name happylucy.works www.happylucy.works;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    location /api {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

# For direct IP access
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
    
    location /api {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
NGINXCONF

# Install certbot for SSL (Amazon Linux 2023 method)
dnf install -y python3-pip
pip3 install certbot certbot-nginx

# Set up the SSL certificate script
cat > /home/ec2-user/setup-ssl.sh << 'SSLFILE'
#!/bin/bash

# Request SSL certificate from Let's Encrypt
sudo certbot --nginx -d happylucy.works -d www.happylucy.works --non-interactive --agree-tos --email hblee8080@gmail.com

# Set up auto-renewal of SSL certificates
echo "0 0,12 * * * root python3 -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew -q" | sudo tee -a /etc/crontab > /dev/null
SSLFILE

chmod +x /home/ec2-user/setup-ssl.sh
chown ec2-user:ec2-user /home/ec2-user/setup-ssl.sh

# Start nginx service
systemctl start nginx
systemctl enable nginx