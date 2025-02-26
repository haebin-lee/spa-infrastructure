# ECR Repository 
resource "aws_ecr_repository" "spa_ecr" {
  name = "spa-application" 
  image_tag_mutability = "MUTABLE" # Allows overwriting image tags

  image_scanning_configuration {
    scan_on_push = true # Automatically scan images for vulnerabilities
  }
}

# ECR Repository Policy 
resource "aws_ecr_repository_policy" "spa_ecr_policy" {
  repository = aws_ecr_repository.spa_ecr.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid = "AllowPushPull",
        Effect = "Allow",
        Principal = "*",
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
      }
    ]
  })
}

# Security Group for EC2
resource "aws_security_group" "ec2_sg" {
  name        = "spa-ec2-sg"
  description = "Allow inbound traffic on port 80 and 22"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0    # All outbound traffic allowed
    to_port     = 0
    protocol    = "-1" # All protocols 
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for RDS 
resource "aws_security_group" "rds_sg" {
  name        = "spa-rds-sg"
  description = "Allow inbound traffic on port 3306"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2_sg.id] # Reference to EC2 security group
  }

  egress {
    from_port   = 0    # All outbound traffic allowed
    to_port     = 0
    protocol    = "-1" # All protocols 
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_vpc" "default" {
  default = true # Use the default VPC
} 

resource "aws_db_instance" "spa_db" {
  identifier        = "spa-mysql"
  engine            = "mysql"
  engine_version    = "5.7"
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  username          = var.db_username
  password          = var.db_password
  db_name           = var.db_name  

  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  parameter_group_name = aws_db_parameter_group.spa_mysql_params.name

  skip_final_snapshot = true  # For development/testing purposes
  publicly_accessible = true  # For development/testing purposes
}

# Create a parameter group to modify authentication settings 
resource "aws_db_parameter_group" "spa_mysql_params" {
  name = "spa-mysql-params"
  family = "mysql5.7"

  parameter {
    name = "character_set_server"
    value = "utf8"
  }

  parameter { 
    name = "character_set_client"
    value = "utf8"
  }
}
# Create a key pair 
resource "aws_key_pair" "developer" {
  key_name   = "spa-key"
  public_key = file("${path.module}/spa-key.pub")
}

# EC2 Instance 
resource "aws_instance" "spa_ec2" {
  ami           = "ami-027951e78de46a00e"  # Amazon Linux 2023 in us-west-2
  instance_type = "t2.micro"
  key_name      = aws_key_pair.developer.key_name

  security_groups = [aws_security_group.ec2_sg.name]

  user_data = <<-EOF
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
    
    # Configure Docker permissions
    usermod -aG docker ec2-user
    chmod 666 /var/run/docker.sock
    
    # Setup AWS credentials directories
    mkdir -p /root/.aws /home/ec2-user/.aws
    
    # Pass AWS credentials to instance
    cat > /home/ec2-user/.aws/credentials << AWSCREDS
    [default]
    aws_access_key_id=${var.aws_access_key}
    aws_secret_access_key=${var.aws_secret_key}
    aws_session_token=${var.aws_session_token}
    AWSCREDS
    
    # Copy credentials to root user
    cp /home/ec2-user/.aws/credentials /root/.aws/credentials
    
    # Set up AWS region configuration
    cat > /home/ec2-user/.aws/config << AWSCONFIG
    [default]
    region = us-west-2
    output = json
    AWSCONFIG
    
    # Copy config to root user
    cp /home/ec2-user/.aws/config /root/.aws/config
    
    # Set correct permissions
    chown -R ec2-user:ec2-user /home/ec2-user/.aws
    
    # Create deployment script - this will be run AFTER you push images to ECR
    cat > /home/ec2-user/deploy.sh << 'DEPLOYFILE' 
    #!/bin/bash
    
    # Get the ECR repository URL and RDS info
    ECR_REPO="${aws_ecr_repository.spa_ecr.repository_url}"
    RDS_HOST=$(echo "${aws_db_instance.spa_db.endpoint}" | cut -d: -f1)
    DB_USER="${var.db_username}"
    DB_PASSWORD="${var.db_password}"
    DB_NAME="${var.db_name}"
    
    # Login to ECR 
    aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin $ECR_REPO
    
    # Pull the latest images
    docker pull $ECR_REPO:frontend
    docker pull $ECR_REPO:backend
    
    # Create a docker-compose.yml file for production
    cat > /home/ec2-user/docker-compose.yml << DOCKERCOMPOSE
    version: "3.8"
    
    services:
      frontend:
        image: $ECR_REPO:frontend
        restart: always
        ports:
          - "3000:3000"
        environment:
          - REACT_APP_BACKEND_URL=http://localhost:8080
        depends_on:
          - backend
    
      backend:
        image: $ECR_REPO:backend
        restart: always
        ports:
          - "8080:8080"
        environment:
          - DB_HOST=$RDS_HOST
          - DB_USER=$DB_USER
          - DB_PASSWORD=$DB_PASSWORD
          - DB_NAME=$DB_NAME
          - DB_PORT=3306
          - NODE_ENV=production
    DOCKERCOMPOSE
    
    # Stop any running containers
    cd /home/ec2-user
    docker-compose down || true
    
    # Start the containers
    docker-compose up -d
    
    # Configure Nginx as a reverse proxy
    cat > /etc/nginx/conf.d/default.conf << NGINXCONF
    server {
        listen 80 default_server;
        server_name _;
    
        location / {
            proxy_pass http://localhost:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    
        location /api {
            proxy_pass http://localhost:8080;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_cache_bypass \$http_upgrade;
        }
    }
    NGINXCONF
    
    # Reload Nginx
    systemctl reload nginx
    DEPLOYFILE
    
    chmod +x /home/ec2-user/deploy.sh
    chown ec2-user:ec2-user /home/ec2-user/deploy.sh
    
    # Install certbot for SSL (Amazon Linux 2023 method)
    dnf install -y python3-pip
    pip3 install certbot certbot-nginx
    
    # Set up the SSL certificate script
    cat > /home/ec2-user/setup-ssl.sh << 'SSLFILE'
    #!/bin/bash
    
    # Request SSL certificate from Let's Encrypt
    certbot --nginx -d happylucy.works -d www.happylucy.works --non-interactive --agree-tos --email hblee8080@gmail.com
    
    # Set up auto-renewal of SSL certificates
    echo "0 0,12 * * * root python3 -c 'import random; import time; time.sleep(random.random() * 3600)' && certbot renew -q" | sudo tee -a /etc/crontab > /dev/null
    SSLFILE
    
    chmod +x /home/ec2-user/setup-ssl.sh
    chown ec2-user:ec2-user /home/ec2-user/setup-ssl.sh
    
    # Start nginx service
    systemctl start nginx
    systemctl enable nginx
    
    # Create a note about next steps
    cat > /home/ec2-user/README.txt << NOTEFILE
    Next Steps:
    1. Run your push-to-ecr.sh script from your local machine to build and push Docker images
    2. SSH into this EC2 instance
    3. Run the deployment script: ./deploy.sh
    4. Set up SSL certificates: ./setup-ssl.sh
    NOTEFILE
    
    chown ec2-user:ec2-user /home/ec2-user/README.txt
  EOF

  tags = {
    Name = "spa-qa-instance"
  }
}

#  Route53 Domain Configuration 
resource "aws_route53_zone" "spa_domain" {
  name = "happylucy.works"
}

# A record for the EC2 instance 
resource "aws_route53_record" "www" {
  zone_id   = aws_route53_zone.spa_domain.zone_id
  name      = "www.happylucy.works"
  type      = "A"
  ttl       = "300"
  records   = [aws_instance.spa_ec2.public_ip]
}

# Root domain A record 
resource "aws_route53_record" "root" {
  zone_id = aws_route53_zone.spa_domain.zone_id
  name    = "happylucy.works"
  type    = "A"
  ttl     = "300"
  records = [aws_instance.spa_ec2.public_ip]
}