FROM ruby:alpine as builder

LABEL maintainer="eye@eyenx.ch"

COPY src /src

WORKDIR /src

RUN apk update && apk upgrade && \ 
apk add build-base git && gem install bundler && \
bundle && jekyll b

FROM nginx:alpine 

LABEL maintainer="eye@eyenx.ch"

RUN sed -i 's#.*error_page.*404.*404.*#    error_page  404   /404/;#g' /etc/nginx/conf.d/default.conf 

COPY --from=builder /src/_site /usr/share/nginx/html
