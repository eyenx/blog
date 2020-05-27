---
layout: post
title: "How to manage IRC notifications in 2019"
description: ""
category: howto
tags: [docker,web,python,websocket,go,irc]
---

What? IRC? There are still people using it? Yes, there are. 

In a world where [Slack](https://slack.com), [Mattermost](https://mattermost.org) and [Matrix](https://matrix.org) are words being said out loud by non-techie people, there are still people who love the internet relay chat protocol (there, you don't need to google it now). 

It's simple, it can't do threads, no images or memes are being sent around, it can't do emoji out of the box **BUT** I love it because it's reliable and easy to manage.

Yet, in a world where being 24/7 online is the case, how can you manage being notified on highlights if you aren't always constantly looking to your terminal? How can you be notified when you are travelling and are only on your mobile? 

Yes, there are a lot of notifying implementation for your localhost irssi or weechat client, and there are some [IRC cloud providers](https://www.irccloud.com/) giving you the possibility to be notified even when you are on the loo. 

But how can one manage notifications if you are running your IRC client in a *fricking* container on your standalone server?

## Websockets to the rescue!

I came across yet another [Go](https://golang.org) project named: [Gotify](https://gotify.net), a notifier server for the new age. It's quite simple to run and it's thought to be run in a container.

![gotify-logo](/img/p/20191105_1.png)

*sudden docker-compose.yml appears*

```
version: '3.3'

services:
  app:
    image: gotify/server
    restart: always
    networks:
      - default
    volumes:
      - ./data/:/app/data
    ports:
      - "8080:80"
```

The default username:password combination is "admin:admin". Once logged in you can find client and apps and **change your password**

Clients are for reading or receiving notifications by using WebSockets. Your browser should already be a client by now.

![gotify-clients](/img/p/20191105_2.png)

Apps are the sending components of notifications. In our example: [weechat](https://weechat.org). 

## make weechat send notifications to gotify

After setting the gotify server up, we now need to configure weechat to send notifications to it, as an app.

We create a new app named "weechat" in our gotify server and `CTLR+C` the token.

![gotify-apps](/img/p/20191105_3.png)

For sending IRC notifications, weechat needs to use a plugin named [weechat-gotify](https://github.com/flocke/weechat-gotify) **DOH**.

When the plugin is loaded the only two configuration variables that need to be changed are:

```
/set plugins.var.python.gotify.host https://mygotify.server
/set plugins.var.python.gotify.token MYSECRETTOKEN
```

After that, the notifications should arrive at the server and can be seen in your browser.

## Well I'm not always on my browser!

Now we need something to read this stuff. There is an [Android App](https://f-droid.org/de/packages/com.github.gotify/) for connecting to your gotify server and receive notifications for it.

But what about our workstation? We are not on the browser at all time (or are we?) 

For this problem, I searched a lot. I wanted to read the WebSocket stream from the gotify server and send new messages via notify-send. 

After a while, I decided to write a python script myself.

## The simple python script

I just needed three modules: [websocket](https://pypi.org/project/websocket-client/) **DOH**, json (to load the message object) and [notify2](https://pypi.org/project/notify2/) (send notifications from python).

And this is the easy script that came out of it:

```
#!/usr/bin/env python3

import json
import notify2
import WebSocket


def notify(text):
    notification = notify2.Notification(text)
    notification.show()


def on_message(ws, message):
    notify(json.loads(message)["message"])


def on_error(ws, error):
    notify(error)


def on_close(ws):
    print("### closed ###")


def on_open(ws):
    print("### open ###")


if __name__ == "__main__":
    notify2.init('gotify-send')
    websocket.enableTrace(True)
    ws = websocket.WebSocketApp('wss://mygotify.server:443/stream',
                                header={"X-Gotify-Key": "MYSECRETTOKEN"},
                                on_message=on_message,
                                on_error=on_error,
                                on_close=on_close)
    ws.on_open = on_open
    ws.run_forever()

```

The Token to be used here is a new custom "Client" one. Like the one from your browser.

## testing it

Well, the only thing remaining was testing it. There are three possibilities to do this:

* asking someone on IRC to send you messages for no apparent reason
* getting into an argument with someone on #archlinux (by saying it sucks or something)
* or the easiest way: connect to freenode with a different client and different username and message yourself (What I did)

![gotify-test](/img/p/20191105_4.gif)

