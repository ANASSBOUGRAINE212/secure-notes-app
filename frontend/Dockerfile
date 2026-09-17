FROM nginxinc/nginx-unprivileged:alpine

# runs as non-root (uid 101) out of the box - listens on 8080, not 80.

COPY index.html /usr/share/nginx/html/
COPY style.css /usr/share/nginx/html/
COPY app.js /usr/share/nginx/html/

EXPOSE 8080