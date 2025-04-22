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