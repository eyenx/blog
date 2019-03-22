FROM ruby:alpine as builder

LABEL maintainer="eye@eyenx.ch"

RUN apk update && apk upgrade && apk add build-base python py-pip && pip install --upgrade pip && pip install pygments && gem install github-pages jekyll jekyll-redirect-from kramdown pygments.rb && apk del build-base  && rm -rf /root/.cache 

WORKDIR /src

COPY src /src

RUN jekyll b


FROM nginx:alpine 

LABEL maintainer="eye@eyenx.ch"

COPY --from=builder /src/_site /usr/share/nginx/html
