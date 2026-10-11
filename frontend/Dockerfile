FROM nginxinc/nginx-unprivileged:1.27-alpine
ENV BACKEND_HOST=backend:3000
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html
EXPOSE 8080
