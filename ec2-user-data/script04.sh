# Variables
DOMAIN="myapp.ricardoboriba.net"
EMAIL="rdobmk@gmail.com"
CERT_PATH="./certbot/conf/live/$DOMAIN/fullchain.pem"
NGINX_CONFIG="./nginx/nginx.conf"

cat > docker-compose.yml <<EOL
version: '3'

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

cat docker-compose.yml


# Check if an argument was provided
if [ $# -eq 0 ]; then
        echo "Please provide your configured domain as an argument"
        echo "Usage: $0 something.example.com/example.com something@gmail.com"
        exit 1
fi

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
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
        }

        location ~ /.well-known/acme-challenge/ {
            root /var/www/certbot;
        }
    }
}
EOL

# Step 1: Generate SSL Certificates with Certbot
echo "Step 1: Generating SSL certificates for $DOMAIN..."
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
            return 301 https://\$host\$request_uri;
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
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
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