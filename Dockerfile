FROM ruby:latest

MAINTAINER eye@eyenx.ch

RUN apt-get update && apt-get install -y node python-pygments

RUN apt-get clean && rm -rf /var/lib/apt/lists/

RUN gem install github-pages jekyll jekyll-redirect-from kramdown pygments.rb

WORKDIR /src

COPY src /src

EXPOSE 4000

CMD jekyll serve -H 0.0.0.0

