---
layout: post
title: "Migrating from Disqus to Isso"
description: ""
category: howto
tags: [comments,selfhosted]
---

First of all: Thank you [Disqus](https://disqus.com/). I used it for a few years. And it worked well. But it was time to look for a self-hosted commenting server. And this is where [Isso](https://posativ.org/isso/) comes into play.

Isso is a very lightweight commenting server you can host yourself, and the cool thing is, it even allows you to import comments from other providers like Disqus or Wordpress.

In this post, I will quickly show you how I migrated to Isso in a matter of minutes!

# export your data first

Head out to your Disqus dashboard. Login in to the admin interface and you'll find an export button. It should be available under the URL Path: `/admin/discussions/export`.

You can then start an export and wait for the download link you'll get per mail.

The download is hosted on the domain https://media.disqus.com which had a expired SSL certificate for me:

```bash
openssl s_client -connect media.disqus.com:443 <<< QUIT | openssl x509  -noout -enddate
depth=2 C = US, O = DigiCert Inc, OU = www.digicert.com, CN = DigiCert Global Root CA
verify return:1
depth=1 C = US, O = DigiCert Inc, CN = DigiCert SHA2 Secure Server CA
verify return:1
depth=0 C = US, ST = California, L = San Francisco, O = "Disqus, Inc.", CN = *.disqus.com
verify error:num=10:certificate has expired
notAfter=Apr 27 12:00:00 2020 GMT
verify return:1
depth=0 C = US, ST = California, L = San Francisco, O = "Disqus, Inc.", CN = *.disqus.com
notAfter=Apr 27 12:00:00 2020 GMT
verify return:1
DONE
notAfter=Apr 27 12:00:00 2020 GMT
```

As we are migrating away from this provider, it doesn't matter to us:

```bash
curl https://media.disqus.com/uploads/exports/your/download/url/you/got/per/mail.xml.gz -o disqus.xml.gz
gunzip disqus.xml
```

# setting up the Isso environment

You'll need a subdomain with the sole purpose of hosting your commenting server. A.e `isso.domain.tld`.

After that, I headed to [Isso's GitHub repository](github.com/posativ/isso) and build a Docker image for the server

```bash
git clone github.com/posativ/isso
cd isso
docker build . -t isso
```

**FYI**: I'm planning to automate the build, as I only found some old images on Docker hub and usually use newer images. I'll share the image URL as soon as I set up the CI build.

Now let's set up our directories to hold the database (SQLite) and the `isso.cfg` file:

```bash
mkdir /myissoinstance/config
mkdir /myissoinstance/db
```

The [isso.cfg](https://posativ.org/isso/docs/configuration/server/) is a really easy to configure file. This is a template of mine:

```
[general]
dbpath = /db/comments.db # where the db is located at
host = # allowed hosts to use the server
    http://domain.tld
    https://domain.tld
    https://otherblog.domain.tld
    http://localhost:8080/

notify = smtp # notify per mail

[smtp] # mail notification configuration
username = isso@domain.tld
password = mailpasswordsaredumb
host = mail.domain.tld
port = 587
security = starttls
to = me@domain.tld
from = isso@domain.tld
timeout = 10

[guard] # spam guard
enabled = true
ratelimit = 2
direct-reply = 3
reply-to-self = false # some of this stuff can be overridden with the clien configuration
require-author = true
require-email = false

[markup] # what options can be used on the client-side
options = strikethrough, superscript, autolink
allowed-elements =
allowed-attributes =

[admin] # wether to have the /admin interface enabled or not 
enabled = true
password = THEVERYSECRETPASSWORD
```

Put it inside `/myissoinstance/config/isso.cfg` and also put your `disqus.xml` under `/myissosinstance/config`. Now it's time to import your Disqus comments:

```bash
docker run -it --rm -v /myissoinstance/config:/config -v /myissoinstance/db:/db isso -c /config/isso.cfg import /config/disqus.xml
```

A database should now be available under `/myissoinstance/db` and you should see, that there is something inside it:

```bash
sqlite3 /myissoinstance/db
sqlite> select count(*) from comments;
18
```

Wow, all this fuss for 18 comments. But that is me. You might as well have 1800 comments as far as I know.


# Docker compose 

Now it's time to make it run indefinitely with [docker-compose](https://docs.docker.com/compose/).

I use [traefik](https://hub.docker.com/r/containous/traefik) as my reverse proxy and have to configure this to make `https://isso.domain.tld` available:

```yaml
version: '3.3'

services:
  app:
    image: isso
    networks:
      - default
    volumes:
      - /myissoinstance/config:/config
      - /myissoinstance/db:/db
    restart: always
    labels:
      - "traefik.frontend.entryPoints=http,https"
      - "traefik.port=8080"
      - "traefik.backend=myissoinstance_app"
      - "traefik.frontend.rule=Host:isso.domain.tld"
networks:
  default:
    external:
      name: docker
```

You could make it also available with any other reverse proxy, but the main thing here is, to be able to head to https://isso.domain.tld (or with /admin if the administration panel is active) and find your Isso instance. 


# client configuration

Now it's time for the client configuration, or in other words, the configuration of javascript on your blog post.

There is a whole [documenation page](https://posativ.org/isso/docs/configuration/client/)  dedicated to it.

For my part it was pretty easy. Just include this block at the end of your posts:

```html
<div class="block">
<script data-isso="https://isso.domain.tld/" data-isso-require-author="true" # overwriting spam guard preferences data-isso-avatar="false" src="https://isso.domain.tld/js/embed.min.js"></script> 
<section id="isso-thread"></section>
</div>
```

# problems

I tested it out first on localhost and then deployed it to **PROD**.  This way I saw that there was a problem with one of the comments which gave back a `500 internal server error` and also, that my blog post scheme had changed. 

I've been using trailing slash in my blog post URI for quite a while now, and Disqus was handling this without problems. But Isso isn't. If my blog post requested the comments for a post with a trailing slash, it didn't receive any comments back from Isso as there wasn't a blog post registered in the database (after the import from Disqus) with trailing slash. 

The easiest fix for me was obviously to read the whole code of Isso and create a pull request on Github to fix this, **NOT**. I'm no superman. I just used `sqlite` and added a trailing slash to all my registered blog post inside the Isso database. But perhaps some folks out there might want to take a look at this.

# final words

This was quite a big change for only hosting 18 comments IMHO. But I've got now a good feeling about it because I'm not hosting the comments somewhere on a third party provider anymore, but have them under my complete control.
