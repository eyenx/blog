#!/bin/sh
apk update
apk add nodejs
npm install -g surge
jekyll build
surge _site $SURGE_HOSTNAME
