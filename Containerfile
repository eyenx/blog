FROM ruby as builder

LABEL org.opencontainers.image.authors="Toni Tauro <eye@eyenx.ch>"
 
COPY src /src

WORKDIR /src

RUN apt update && apt full-upgrade -y && \
gem install bundler && \
bundle && bundle exec jekyll b

FROM nginx:alpine 

LABEL maintainer="eye@eyenx.ch"

RUN sed -i 's#.*error_page.*404.*404.*#    error_page  404   /404/;#g' /etc/nginx/conf.d/default.conf 

COPY --from=builder /src/_site /usr/share/nginx/html
