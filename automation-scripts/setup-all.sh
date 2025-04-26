Content-Type: multipart/mixed; boundary="//"
MIME-Version: 1.0
 
--//
Content-Type: text/cloud-config; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment;
 filename="cloud-config.txt"
 
#cloud-config
cloud_final_modules:
- [scripts-user, always]
--//
Content-Type: text/x-shellscript; charset="us-ascii"
MIME-Version: 1.0
Content-Transfer-Encoding: 7bit
Content-Disposition: attachment; filename="userdata.txt"

#!/bin/bash

mkdir -p $VM_PROJECT_DIR
cd $VM_PROJECT_DIR

/bin/echo "Hello World" >> /tmp/testfile.txt

# Create Dockerfile
cat > Dockerfile <<EOL
FROM nginx:alpine

# Clone the simple application repository
RUN apk add --no-cache git && \
    git clone https://github.com/dockersamples/linux_tweet_app.git /tmp/app && \
    cp -r /tmp/app/* /usr/share/nginx/html/ && \
    rm -rf /tmp/app

# Expose the default Port
EXPOSE 80 443

# Start Nginx
CMD ["nginx", "-g", "daemon off;"] 
EOL

# Create docker-compose.yml file
cat > docker-compose.yml <<EOL
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - 8000:80
    expose:
      - 80

  nginx:
    container_name: nginx
    restart: unless-stopped
    image: nginx
    ports:
      - 80:80
      - 443:443
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot

  certbot:
    image: certbot/certbot
    container_name: certbot
    volumes:
      - ./certbot/conf:/etc/letsencrypt
      - ./certbot/www:/var/www/certbot
    command: certonly --webroot -w /var/www/certbot --email ${EMAIL} -d ${DOMAIN} --agree-tos --non-interactive --no-autorenew
EOL

mkdir -p nginx

cat > $NGINX_CONFIG <<EOL
events {
    worker_connections 1024;
}

http {
    include  mime.types;

    server_tokens off;
    charset utf-8;

    server {
        listen 80 default_server;

        server_name _;

        location / {
            proxy_pass http://app:80/;
            proxy_set_header Host \$${q}host;
            proxy_set_header X-Real-IP \$${q}remote_addr;
        }

        location ~ /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
    }
}
EOL

# Step 1: Generate SSL Certificates with Certbot
echo "Step 1: Generating SSL certificates for $DOMAIN..."
docker compose down --volume
docker compose up --build -d

echo "Certificates generated successfully."

sleep 10

cat > $NGINX_CONFIG <<EOL
events {
    worker_connections 1024;
}

http {
    include  mime.types;

    server_tokens off;
    charset utf-8;

    # HTTP server - redirects to HTTPS
    server {
        listen 80;
        listen [::]:80;
        server_name ${DOMAIN};

        # Redirect all HTTP requests to HTTPS with a 301 Moved Permanently response
        location / {
            return 301 https://\$${q}host\$${q}request_uri;
        }

        # Allow Let's Encrypt certificate renewal without redirection
        location ~ /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
    }

    # HTTPS server - main configuration
    server {
        listen 443 ssl;
        listen [::]:443 ssl;

        # SSL certificates
        ssl_certificate /etc/letsencrypt/live/${DOMAIN}/fullchain.pem;
        ssl_certificate_key /etc/letsencrypt/live/${DOMAIN}/privkey.pem;
        
        # Additional SSL settings for security
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers on;
        ssl_session_timeout 1d;
        ssl_session_cache shared:SSL:10m;
        
        # Enable HSTS (optional but recommended - tells browsers to always use HTTPS)
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

        server_name ${DOMAIN};
        root /var/www/html;
        index index.php index.html index.htm;

        # Proxy requests to the app container
        location / {
            proxy_pass http://app:80/;
            proxy_set_header Host \$${q}host;
            proxy_set_header X-Real-IP \$${q}remote_addr;
            proxy_set_header X-Forwarded-For \$${q}proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto https;
        }

        # Let's Encrypt validation
        location ~ /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
    }
}
EOL

echo "Nginx configuration updated successfully."

# Step 3: Restart Nginx
echo "Step 3: Restarting Nginx container..."
docker compose down --volume
sleep 5
docker compose up --build -d

echo "Setup complete. Nginx is now configured with SSL and redirection."
--//--