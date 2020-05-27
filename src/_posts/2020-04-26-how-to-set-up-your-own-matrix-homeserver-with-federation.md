---
layout: post
title: "How to set up your own matrix.org homeserver with federation!"
description: ""
category: howto
tags: [docker,containers,matrix,p2p,decentralized,chat]
---



First of all let's get one thing out of the way. If you think this will be a blog post about Keanu Reeves starring in his A-role you are wrong. Although I love **The Matrix**, and I'm talking just about the first movie, this blog post will be about setting up your own homeserver of [matrix.org](https://matrix.org). Matrix is an open network for secure, decentralized communication.

*"Oh yet another chat tool? I've got telegram running and I'm fine"*, you might think. **BUT** Matrix isn't quite the same. It's **decentralized**, meaning there isn't a central server. And it is also **federated** and of course: **opensource**.

You can thing of it like **XMPP** in the good old days. Does anybody used that? Oh yeah... me. You set up your own server, you create an account on **your** server, but are able to crosschat with other homeservers or the official **matrix.org** homeserver thanks to federation.

## Preqrequesites

What you'll need to follow this tutorial:

* a self-hosted server **DOH**
* docker and docker-compose (or use your own container runtime engine) 
* your own way of dealing with Let's Encrypt certificates and proxing. I am using [traefik](https://traefik.io).
* a mail server
* DNS A Record: matrix.my.host:  IP.OF.YOUR.SERVER
* DNS SRV Record: _matrix._tcp.my.host: 0 10 443 matrix.my.host

## Let's start

This is the `docker-compose.yml` I am using to run synapse, the matrix homeserver:

```
version: '3.3'

services:
  app:
    image: matrixdotorg/synapse
    restart: always
    volumes:
      - /var/docker_data/matrix:/data
    labels:
      - "traefik.frontend.entryPoints=http,https"
      - "traefik.port=8008"
      - "traefik.backend=matrix_app"
      - "traefik.frontend.rule=Host:matrix.my.host"

```


The image I am using is: [matrixdotorg/synapse](https://hub.docker.com/r/matrixdotorg/synapse).

But before you can fire up this `docker-compose` file you'll need to first generate a configuration, as explained in their [README.md](https://github.com/matrix-org/synapse/blob/master/docker/README.md)

```bash
docker run -it --rm -v /var/docker_data/matrix:/data -e SYNAPSE_SERVER_NAME=matrix.my.host -e SYNAPSE_REPORT_STATS=yes matrixdotorg/synapse:latest generate
```

After generating the configuration, you can modify it at your will. Just go to `/var/docker_data/matrix/homeserver.yaml` and get your `$EDITOR` going.

At last, fire up your instance with `docker-compose up -d`

## Done? Not quite

Well the first thing I was missing after heading to https://matrix.my.host is a way to register my username.

Two ways of doing that:

* Set `enable_registration: true` in your `homeserver.yaml` and `docker restart matrix_app_1`
* `docker exec -it matrix_app_1 register_new_matrix_user -u myuser -p mypw -a -c /data/homeserver.yaml`

If setting `enable_registration` to true is used, be sure to set it back to false after registering your user if you do not want people to register on your homeserver.

## Well how can I register or chat now?

Just head to [riot.im](https://riot.im/app) and login or register a user, by using an alternate homeserver and setting your homeserver FQDN.

![riot](/img/p/20200426_1.png)

But what is riot? It's just one of the matrix client. You could even host your own instance or use another [client](https://matrix.org/clients/).

## Federation and base domain

Well this should work out of the box right? Well not exactly. We need federation to work, so we are able to join other channels on other homeserver and chat privately with people using other homeserver.

As explained in the [docs](https://github.com/matrix-org/synapse/blob/master/docs/federate.md), federation works by connecting to your homeserver through port 8448. But we do not want to make port 8448 publicly available, what now? 

Also we are using a subdomain to make our matrix homeserver available (matrix.my.host) but we wan't our username to look like this: `myuser@my.host` and not like this: `myuser@matrix.my.host`.

Well there is a solution for these two problems:

  In some cases you might not want to run Synapse on the machine that has the server_name as its public DNS hostname, 
  or you might want federation traffic to use a different port than 8448. For example, you might want to have your 
  user names look like @user:example.com, but you want to run Synapse on synapse.example.com on port 443. This can 
  be done using delegation, which allows an admin to control where federation traffic should be sent. See delegate.md
  for instructions on how to set this up. 

Taking a look at [delegate.md](https://github.com/matrix-org/synapse/blob/master/docs/delegate.md) explains quite a lot:

  The URL https://<server_name>/.well-known/matrix/server should return a JSON structure containing the key m.server like so:
  {
      "m.server": "<synapse.server.name>[:<yourport>]"
  }

Okay, so we set up a static file on our `matrix.host` under `.well-known/matrix/server` giving this `JSON` back:


```
{ "m.server": "matrix.my.host:443" }
```

and we are good. 

The last thing we will need to do is start from scratch. Yes, we will delete all data under `/var/docker_data/matrix` and change the `base_domain` in our generate command:

```bash
docker run -it --rm -v /var/docker_data/matrix:/data -e SYNAPSE_SERVER_NAME=my.host -e SYNAPSE_REPORT_STATS=yes matrixdotorg/synapse:latest generate
```

This is needed, as we need to recreate keys and also users. Of course you could start right away with this, but I wanted to show all the modifications I had to do to get this thing running. If you do not need federation however, and want to chat only to users from your homeserver, this step is of course not needed.


## Mail verification

I also wanted to verify my mail address. I thought this would be fairly easy, just set up a mailaccount for matrix and configure it in your `homeserver.yaml`:

```
email:
  smtp_host: mail.my.host
  smtp_port: 587
  smtp_user: "matrix@my.host"
  smtp_pass: "thisisapassword!"
  require_transport_security: true
  notif_from: "Your Friendly %(app)s homeserver <noreply@my.host>"

```

Well not quite. There is a **bug**. Synapse only tries to use TLS1.0 and some mailservers may reject that, like mine. There is already an [open issue](https://github.com/matrix-org/synapse/issues/6211) to this problem.

So I thought to myself: *"Why not use a workaround?"*

Just set up a second container, with a postfixforwarder in it, who will connect to my mail server using TLS > 1.0 and deliver the mails. Synapse can then connect to this docker container without auth and without TLS. 

**But please**, be sure this container runs on the same server and is only accessible through the container network. We do not want to make port 25 of this container publicly available.

I used [juanluisbaptiste/postfix](https://hub.docker.com/r/juanluisbaptiste/postfix) for this.

After modifying my `docker-compose.yml`:

```
version: '3.3'

services:
  app:
    image: matrixdotorg/synapse
    restart: always
    volumes:
      - /var/docker_data/matrix:/data
    labels:
      - "traefik.frontend.entryPoints=http,https"
      - "traefik.port=8008"
      - "traefik.backend=matrix_app"
      - "traefik.frontend.rule=Host:matrix.my.host"

  postfixfwd:
    image: juanluisbaptiste/postfix
    restart: always
    environment:
      - SMTP_SERVER=mail.my.host
      - SMTP_USERNAME=matrix@my.host
      - SMTP_PASSWORD=thisisapassword!
      - SERVER_HOSTNAME=postfixfwd.my.host
```

and of course the `homeserver.yaml`:

```
email:
  smtp_host: matrix_postfixfwd_1
  smtp_port: 25
  # no authentication needed
  #smtp_user: "matrix@my.host"
  #smtp_pass: "thisisapassword!"
  #require_transport_security: true
  notif_from: "Your Friendly %(app)s homeserver <noreply@my.host>"

```

I just had to restart synapse again and after that fire up the postfix forwarder container: `docker-compose up -d`

Now I was able to send mails through my matrix server and verify my mailadress.


## What now?

I am the only user on my matrix homeserver, but am able to join matrix.org chat rooms. I recently started chatting with `appservice-irc:matrix.org` too. This bot enables you to join IRC chat rooms on the `freenode.net` network. 

Some useful commands there:

```
!help
!join #myroom
!listrooms
```

This is very useful, as I can easily follow up on IRC with my smartphone. Yeah, there is [riot.im app](https://f-droid.org/en/packages/im.vector.alpha/) for Android.

## You used this tutorial with success? Contact me!

If you managed to get synapse and federation working with this tutorial, I would appreciate if you would contact me. Of course you should do that through matrix: `@eyenx:eyenx.ch`
