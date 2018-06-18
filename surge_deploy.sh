#!/bin/sh
apk update
apk add nodejs
npm install -g surge
jekyll build
surge deploy _site $SURGE_HOSTNAME
