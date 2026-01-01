FROM nginx:latest
LABEL maintainer="Dan Fedele <dan.fedele@gmail.com>"

EXPOSE 80
WORKDIR /usr/share/nginx/html
COPY _site .
