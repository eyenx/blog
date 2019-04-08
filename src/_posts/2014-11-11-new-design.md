---
layout: post
title: "new design"
description: ""
category: announcement
tags: [web,jekyll]
disqus: y
share: n
---

## big surprise - new design!

I was already going through the interwebs for a few weeks, until I found some promising themes I wanted to try out on [jekyllthemes.org](http://jekyllthemes.org).

After some days, I got hooked by the wonderful, yet simple jekyll themes [Mu-An Chiou](http://muan.co) designed. Seriously, go check her work out on [muan.co](http://muan.co) or on her [github profile](http://github.com/muan).

## trying hard again

In the last 5 days I went full jekyll mode. I switched to so many themes on my [development environment](http://dev.eyenx.ch), that I can hardly remember a single one of them.

But what caught my eye was [scribble](http://scribble.muan.co). I find it:

- simple
- beautiful
- fresh
- clean

That's about it. I'm easy to impress, I know. A few of my friends like it, others don't. But what matters is my own opinion. And I like it a lot.

## systemctl stop nginx

My standalone HTTP Server isn't required anymore. I switched using [Docker](http://docker.io) with [tutum](http://tutum.co) now, even on my production homepage. 

![betatag](/img/p/20141111_1.png){: .w60 .center }

**Oops**. Let's look at a few more details.


### node clusters


I've only got one cluster with two really cheap **(5$)** [Digitalocean](http://www.digitalocean.com) nodes deployed on it. It may seem not that much, but the cool thing is, that at the moment it's more than enough.

### service clusters

On the other side, I've got way to many docker instances.

![services](/img/p/20141111_2.png){: .center }

Yes, you saw right. **9 docker instances** deployed on two **1CPU/500MB** nodes. It gets kinda interesting to see how the services are connected with each other.

It took me way more time than I intended to draw this. So please, at least look at it for a few seconds.

![network](/img/p/20141111_3.png){: .center}

Every connection between the services is accomplished with the docker linking technology. **eyenx-ch-rp**, the nginx reversproxy, is linked with the two loadbalancers **eyen-ch-lb** and **eyenx-ch-dev-lb** and these services are linked with their respective jekyll backends. For the loadbalancers I'm using the [haproxy docker image](http://https://registry.hub.docker.com/u/tutum/haproxy/) provided by tutum as described in my [previous post](http://eyenx.ch/2014/10/03/tutum-ftw/).

Personally I think that 4 containers in the production **eyenx-ch-jekyll** service might be a little overkill. But I'm just playing around with the tutum scaling capabilities.

### sequential deployment

When creating the jekyll services, I wanted them to have the *sequential deployment* option active. Sadly, upon finishing the service creation process, I saw the missing **ON** flag in the **eyenx-ch-jekyll** service details.

![servicedetail](/img/p/20141111_4.png)


A few minutes later I tried again and took some screenshots for the purpose to contact the [tutum support](http://support.tutum.co) team. This was their response:

![mail](/img/p/20141111_5.png){: .center }

I gratefullly denied their kind offer. It just was nice to know they were already working on the fix.

## Dockerfiles

This might not be a mistery. Anyway, I'll show you my Dockerfiles on which I worked so hard (~10 minutes).

{% highlight bash %}
FROM ruby:latest
MAINTAINER eye@eyenx.ch
RUN apt-get update && apt-get install -y node python-pygments
RUN apt-get clean && rm -rf /var/lib/apt/lists/
RUN gem install github-pages jekyll jekyll-redirect-from \
kramdown redcarpet rouge rdiscount
WORKDIR /src
RUN git clone http://github.com/eyenx/eyenx.ch /src
EXPOSE 4000
CMD git pull;jekyll serve
{% endhighlight %}

You may ask yourself why my start command is `git pull;jekyll serve`. 
I update the git repository under `/src` every time the container starts. This gives me the possibility to update my static generated homepage without actually having to redeploy the whole service. I can achieve an update with absolutely **no downtime** with this simple for loop:

{% highlight bash %}
for c in $(tutum container ps | awk '/eyenx-ch-jekyll/ {print $2}')
  do tutum container stop $c; sleep 45; tutum container start $c; sleep 5
done
{% endhighlight %}

Finally let's take a look at the **eyenx-ch-rp** Dockerfile.

{% highlight bash %}
FROM nginx:latest
MAINTAINER eye@eyenx.ch
RUN apt-get install -y python-pip
RUN pip install j2cli
COPY start /start
RUN chmod +x /start
COPY nginx.tmpl /nginx.tmpl
CMD /start
EXPOSE 80
{% endhighlight %}

The `nginx.conf` is created from a [Jinja2](http://jinja.pocoo.org/) template file using [j2cli](https://pypi.python.org/pypi/j2cli/). For more information visit my [github project](https://github.com/eyenx/docker-nginx-rp) or the public [docker repository](https://registry.hub.docker.com/u/eyenx/nginx-rp/)
