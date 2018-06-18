FROM ruby:2.3-alpine

MAINTAINER eye@eyenx.ch

COPY test.sh /test.sh
COPY surge_deploy.sh /surge_deploy.sh

RUN chmod +x /surge_deploy.sh && chmod +x /test.sh && apk update && apk upgrade && apk add build-base python py-pip && pip install --upgrade pip && pip install pygments && gem install github-pages jekyll jekyll-redirect-from kramdown pygments.rb && apk del build-base  && rm -rf /root/.cache

WORKDIR /src

COPY src /src

EXPOSE 4000

CMD jekyll serve -H 0.0.0.0

