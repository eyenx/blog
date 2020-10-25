---
layout: post
title: "Managing your DNS records with Terraform"
description: ""
category: howto
tags: [dns,terraform]
---

At my first FOSDEM, I went together with a co-worker to see a talk from [Matteo Valentini](https://github.com/Amygos) regarding DNS and how to manage your records with a CI/CD pipeline.

He showed us [octoDNS](https://github.com/github/octodns) a python tool from GitHub able to sync your local configuration with your DNS records managed at any thinkable cloud provider.

Until last weekend I was still using octoDNS to automatically manage my DNS on Azure through a CI/CD pipeline run with [drone](https://drone.io).

But I decided to switch to a different solution consisting of [terraform](https://terraform.io) and [Digitalocean](https://digitalocean.com) while keeping the pipeline on a self hosted drone server.

## Setting up your project

I created a `main.tf` file and a separate file for every single DNS zone I want to manage:

* `main.tf`
* `eyenx.ch.tf`
* `example.com.tf`

etc.

The contents of `main.tf` will describe the provider we want to use (in this case `digitalocean/digitalocean`), our API Token as variable and the remote backend `s3` which will be a space/bucket on Digitalocean. We will use the backend to save our `terraform.tfstate`.

```hcl
terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "2.0.1"
    }
  }

  # DigitalOcean uses the S3 spec.
  backend "s3" {
    bucket = "mybucketname"
    # filename to use for saving our tfstate
    key    = "terraform.tfstate" 
    # depends where you are setting up the space (fra1/ams1 etc..)
    endpoint = "https://ams1.digitaloceanspaces.com" 
    # DO uses the S3 format
    # eu-west-1 is used to pass TF validation
    region = "eu-west-1" 
    # Deactivate a few checks as TF will attempt these against AWS
    skip_credentials_validation = true
    skip_metadata_api_check = true
  }
}

# our digitalocean api token
variable "do_token" {} 

provider "digitalocean" {
  token = var.do_token 
}

```

## The domain zone file

Our domain zone file will be kept very simple:

```hcl
resource "digitalocean_domain" "examplecom" {
   name = "example.com"
   ip_address = "1.2.3.4" # default @ record
}

resource "digitalocean_record" "examplecom-mail" {
  domain = digitalocean_domain.examplecom.name
  type = "A"
  name = "mail"
  value = "1.2.3.5" # mail.example.com resolves to this IP
}

resource "digitalocean_record" "examplecom-mx" {
  domain = digitalocean_domain.examplecom.name
  type = "MX"
  name = "@"
  priority = 10
  value = "mail.example.com." # MX record
}

resource "digitalocean_record" "examplecom-www" {
  domain = digitalocean_domain.examplecom.name
  type = "CNAME"
  name = "www"
  value = "@" # CNAME record www.example.com > example.com
}

resource "digitalocean_record" "examplecom-txt-keybase" {
  domain = digitalocean_domain.examplecom.name
  type = "TXT"
  name = "_keybase"
  value = "keybase-site-verification=SECRETCODE" # keybase verification TXT record
}


resource "digitalocean_record" "examplecom-srv-imap-tcp" {
  domain = digitalocean_domain.examplecom.name
  type = "SRV"
  name = "_imap._tcp"
  value = "mail.example.com." # SRV record for imap
  port = "143"
  priority = 0
  weight = 1
 }
```

## Init/plan/apply

What we now need is a init, plan & apply to finish this up. But first we will have to export our secrets

```bash

export TF_VAR_do_token=SECRET_API_TOKEN
# has nothing to do with AWS, it's still Digitalocean, but terraform's s3 backend reads this
export AWS_ACCESS_KEY_ID=KEY_ID_FOR_ACCESS_TO_DO_SPACE 
export AWS_SECRET_ACCESS_KEY=ACCES_KEY_FOR_ACCESS_TO_DO_SPACE 

terraform init
Initializing the backend...

Initializing provider plugins...
- Using previously-installed digitalocean/digitalocean v2.0.1

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.

terraform plan
[...]
digitalocean_record.examplecom-www: Refreshing state... 
digitalocean_record.examplecom-mail: Refreshing state...
digitalocean_record.examplecom-mx: Refreshing state... 
[...]
Plan: 6 to add, 0 to change, 0 to destroy.


terraform apply # confirm with yes
```

After applying the changes, please check that your `terraform.tfstate` has been uploaded to the Digitalocean space and check if the DNS is actually working:

```bash
host example.com
example.com has address 1.2.3.4
```


## Automating it

Let's automate this by running a pipeline with drone. You can of course use any other CI/CD pipeline tooling you want to. For the main step in the pipeline we'll be using the [hashicorp/terraform](hub.docker.com/r/hashicorp/terraform) container image.

Example `.drone.yml`:

```yaml
kind: pipeline
type: docker
name: dns

steps:
  - name: terraform
    image: hashicorp/terraform:0.13.4
    commands:
      - terraform init
      - terraform plan
      - terraform apply -auto-approve
    # keep your secrets secret and not inside GIT!
    environment:
      TF_VAR_do_token:
        from_secret: tf_var_do_token
      AWS_SECRET_ACCESS_KEY:
        from_secret: aws_secret_access_key
      AWS_ACCESS_KEY_ID:
        from_secret: aws_access_key_id
    when:
      branch: master
```

This way any time you push a new change to your master branch, the pipeline will take care of the rest.

And thanks to the remote backend being configured, you'll be able to also apply your changes manually, from any device.
