---
layout: post
title: "automatic git deploy"
description: ""
category: webserver 
tags: [git,jekyll,nginx]
---
{% include JB/setup %}

## this blog update was deployed automatically

**Believe me**, it was. 

## first things first

I put my whole [jekyll](http://jekyllbootstrap.com) project on my [github](https://github.com/eyenx/eyenx.ch) page.

Afterwards I installed ruby and the jekyll gem on my [ArchLinux](http://archlinux.org) webserver.

Normally ruby would install all gems into the `$HOME/.gem` directory. Since I was gonna use the `http` user to build the homepage, I didn't want to install the gem into the http directory *(/srv/http)*.

Instead I put it under `/usr/lib/ruby/gems`

~~~ bash
# pacman install ruby
# gem install --install-dir /usr/lib/ruby/gems/2.1.0 --no-user-install jekyll
~~~
\\
My next step was to clone my git repository into the http home folder.

~~~ bash
# git clone https://github.com/eyenx/eyenx.ch /srv/http
# chown http.http /srv/http -R
~~~
\\
and modify my `nginx.conf`:

~~~
        location / {
            root   /srv/http/_site;
            index  index.html index.htm index.php;
        }
~~~
\\
finally, make it be cloned and built automatically every hour, without checking if there was a commit or not. Simple but **reliable**.

~~~ bash
# cat /etc/cron.d/jekyll
0 * * * * http git pull; jekyll build 
~~~
\\
Test it simply by removing the `_site/categories.html` file and wait for **cron** to do his magic.

## still keeping my todo list

Thanks to this simple modification, my **todo** list just got a lot shorter:

- I want to create an **about** page
- <s> share the code on **github** </s> 
- <s>**automatically deploy** this static site on my [DigitalOcean](http://digitalocean.com) vhost</s>
- **post comments** over [Disqus](http://disqus.com)
