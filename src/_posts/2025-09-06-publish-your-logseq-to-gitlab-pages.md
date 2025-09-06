---
layout: post
title: "Publish Your Logseq Graph to GitLab Pages"
description: "Learn how to automate the deployment of your Logseq graph as a single page application on GitLab Pages."
category: howto
tags: [containers, automation, logseq]
---

If you're a Logseq user, you might find it useful to automate the deployment of your Logseq graph as a single page application (SPA) on GitLab Pages. This allows for easy access to your graph and the ability to link directly to specific knowledge base pages.

## Set Up logseq-plugin-git

To begin, ensure your Logseq graph is under version control with Git. The [logseq-plugin-git](https://github.com/haydenull/logseq-plugin-git) is an excellent tool for this purpose. Setting it up is straightforward; you just need a Git repository to push to, such as one on GitLab.

With the plugin, you'll receive notifications about pending changes, which you can commit and push instantly using the `<mod+s>` shortcut.

![Logseq Plugin Git](/img/p/20250906_1.png)

## Set Up GitLab Pages

Next, you'll need to set up GitLab Pages. To activate it for your repository, navigate to your Repository settings > General > Visibility, project features, permissions in GitLab v18.

![GitLab Pages Setup](/img/p/20250906_2.png)

## Set Up Automation

Now, let's focus on automation.

Create a new `.gitlab-ci.yml` file:

```yaml
image:
  name: ghcr.io/l-trump/logseq-publish-spa:alpine
  entrypoint: ["/bin/sh", "-c"]

stages:
  - deploy

pages:
  rules:
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH

  stage: deploy
  environment: live

  variables:
    THEME: dark
    ACCENT_COLOR: blue

  script:
    - mkdir -p public
    - node /opt/logseq-publish-spa/publish_spa.mjs $CI_PROJECT_DIR/public --static-directory /opt/logseq-static --directory $CI_PROJECT_DIR --theme-mode $THEME --accent-color $ACCENT_COLOR

  artifacts:
    paths:
      - public
```

This configuration uses the container image from [l-trump/logseq-publish-spa](https://github.com/l-trump/logseq-publish-spa), which simplifies the process.

Commit this file to your repository and watch the automation in action:

![CI Pipeline](/img/p/20250906_3.png)

After a successful `pages:deploy` job, your Logseq graph will be accessible at the GitLab Pages URL provided.

Have fun logseq-ing (or how it is called)!
