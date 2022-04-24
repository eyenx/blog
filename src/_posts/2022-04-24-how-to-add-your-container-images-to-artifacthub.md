---
layout: post
title: "How to add your container images to ArtifactHub"
description: ""
category: howto
tags: [containers,automation]
---

Do you know [ArtifactHub](https://artifacthub.io)? If not, go check it out, it's a very cool site, holding over 8000 [kubernetes](https://kubernetes.io/) packages. I mostly use the site for lurking around and find [Helm](https://helm.sh) charts. What I did not know, is that ArtifactHub supports way more packages then only Helm Charts:

* Falco Rules
* OPA policies
* OLM operators
* Container Images 
* and more!

![artifacthub](/img/p/20220424_1.png)

So that brought me to the idea to add my container images, which I host on [ghcr.io](https://ghcr.io). But why do that? 

The images are then searchable on ArtifactHub, but the one other cool feature is: you get a security report of your container image for free.

As an example, this very site, is running in a container. And I added the container image to ArtifactHub, which tells me now, I got a vulnerability on it:

![vulnerability](/img/p/20220424_2.png)

This is very useful, right? 

But how do you add your container images to ArtifactHub? Well first of all, create an account there. You can directly register with GitHub or Google, or use your email for registration:

![signup](/img/p/20220424_3.png)

Now you need to follow their [instructions](https://artifacthub.io/docs/topics/repositories/#container-images-repositories) on how to label your container images properly so they can be shown on their site.

They support a whole lot of the [opencontainers](https://opencontainers.org/) labels, but for starters these 3 labels are required for your image to even appear there. 

* `io.artifacthub.package.readme-url` url of the readme file (in markdown format) for this package version. Please make sure it points to a raw markdown document, not HTML
* `org.opencontainers.image.created` date and time on which the image was built (RFC3339)
* `org.opencontainers.image.description` a short description of the package

But as you are already adding labels to your images, please take the time and add the ones listed in the [image-spec](https://github.com/opencontainers/image-spec/blob/main/annotations.md).

I set those labels in my CI/CD pipeline. And as all of my public repos are hosted on [GitHub](https://github.com) I end up doing this with [GitHub Actions](https://github.com/features/actions)

[Here](https://github.com/eyenx/blog/blob/main/.github/workflows/build-image.yaml) is the action I'm using for setting the labels on my blog container image:

```yaml
   - name: Build and push
        id: docker_build
        uses: docker/build-push-action@v2
        with:
          context: ./
          file: ./Dockerfile
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.prep.outputs.tags }}
          labels: |
            io.artifacthub.package.readme-url=https://raw.githubusercontent.com/${{ github.repository }}/${{ github.event.repository.default_branch }}/README.md
            org.opencontainers.image.title=${{ github.event.repository.name }}
            org.opencontainers.image.description=${{ github.event.repository.description }}
            org.opencontainers.image.url=${{ github.event.repository.html_url }}
            org.opencontainers.image.source=${{ github.event.repository.clone_url }}
            org.opencontainers.image.version=${{ steps.prep.outputs.version }}
            org.opencontainers.image.created=${{ steps.prep.outputs.created }}
            org.opencontainers.image.revision=${{ github.sha }}
            org.opencontainers.image.licenses=${{ github.event.repository.license.spdx_id }}
```

As you can see, I'm having a hard time creating the `readme-url` dynamically. I've not found a better solution yet.

For some standalone golang applications you might be using [goreleaser](https://goreleaser.com/). For such cases you can use [this configuration]( https://github.com/eyenx/gursht/blob/main/.goreleaser.yaml) for adding the right labels:

```yaml
dockers:
  - image_templates:
      - "ghcr.io/eyenx/gursht:{{ .Tag }}"
      - "ghcr.io/eyenx/gursht:v{{ .Major }}"
      - "ghcr.io/eyenx/gursht:v{{ .Major }}.{{ .Minor }}"
      - "ghcr.io/eyenx/gursht:latest"
    build_flag_templates:
      - "--label=io.artifacthub.package.readme-url=https://raw.githubusercontent.com/eyenx/{{.ProjectName}}/main/README.md"
      - "--label=org.opencontainers.image.created={{.Date}}"
      - "--label=org.opencontainers.image.name={{.ProjectName}}"
      - "--label=org.opencontainers.image.revision={{.FullCommit}}"
      - "--label=org.opencontainers.image.version={{.Version}}"
      - "--label=org.opencontainers.image.source={{.GitURL}}"
```

After you've done that, and your image was built, you need to manually add it once on ArtifactHub.

On the control panel you can add a repository. Chose "Container images" as a kind and fill out the form:

![addimage](/img/p/20220424_4.png)

The image will be then listed in the control panel, and you'll see any errors that might happen while checking it. Usually it takes up to 30 minutes to have the first import and security scan happening.

![image](/img/p/20220424_5.png)

With the three dots menu of the image you are also able to copy a badge you could add on the `README` of your repository, as I did for [eyenx/blog](https://github.com/eyenx/blog).

![badge](/img/p/20220424_6.png)

In the next few weeks I'm planning to add all my container images on ArtifactHub, so that I've got the security scanning covered without having to host any scanning tooling myself!

You can see my progress by searching directly on ArtifactHub for [eyenx](https://artifacthub.io/packages/search?user=eyenx&sort=relevance&page=1).
