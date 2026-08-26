---
layout: post
title: "Forgejo Actions JWT ID Tokens for OpenBao"
description: "Learn how to use Forgejo Actions JWT ID Tokens for secure, short-lived authentication in automation workflows."
category: howto
tags: [forgejo, openbao, secrets, opentofu, jwt]
---

In the past, Forgejo Actions required long-lived secrets for authenticating with external services, such as configuring OpenBao or managing DNS records with OpenTofu. However, with the release of [Forgejo version 15](https://forgejo.org/2026-04-release-v15-0/), a new feature has been introduced: OpenID Connect support. This allows for secure, short-lived JWT ID Tokens, enhancing security and simplifying authentication processes.

## Setting Up Forgejo Actions

To leverage this feature, enable OpenID Connect in your workflow by adding `enable-openid-connect: true` to your `.forgejo/workflows/myaction.yaml`:

```yaml
on: [push]
enable-openid-connect: true
jobs:
  build:
    ...
```

Retrieve the JWT token using a simple curl command:

```yaml
- name: get jwt
  run: |
    curl -qH "Authorization: Bearer $ACTIONS_ID_TOKEN_REQUEST_TOKEN" "$ACTIONS_ID_TOKEN_REQUEST_URL&audience=https://audience.example.com" | jq -r '.value' > /tmp/jwt
```

This token, stored in `/tmp/jwt`, can be used for authentication with third-party services.

## Authenticating with OpenBao

To configure OpenBao for JWT authentication, enable the JWT engine:

```bash
bao auth enable -path=forgejo jwt
```

Set up the OpenID configuration:

```bash
bao write auth/forgejo/config oidc_discovery_url="https://forgejo.example.com/api/actions"
```

Create a policy and role with appropriate permissions (avoid wildcard policies in production; scope to only the specific paths/capabilities your workflow needs):

```bash
bao policy write forgejo - <<EOF
path "*" {
   capabilities = [ "create", "read", "update", "delete", "list", "sudo"]
}
EOF

bao write auth/forgejo/role/forgejo - <<EOF
{
"ttl":"15m",
"role_type":"jwt",
"user_claim":"actor",
"policies":["forgejo"],
"bound_audiences":["https://audience.example.com"],
"bound_claims": { "repository" : "user/repo", "iss" : "https://forgejo.example.com/api/actions" }
}
EOF
```

Log in during your pipeline:

```bash
bao write -format=json auth/forgejo/login role=forgejo jwt=$(cat /tmp/jwt) | jq -r .auth.client_token > /tmp/.bao-token
```

## Integrating with OpenTofu

For OpenTofu, export the JWT as `TERRAFORM_VAULT_AUTH_JWT` and execute your Terraform commands:

```bash
export TERRAFORM_VAULT_AUTH_JWT=$(cat /tmp/jwt)
tofu plan
```

Use the following provider configuration:

```hcl
provider "vault" {
  address = var.openbao_address

  auth_login_jwt {
    mount = "forgejo"
    role  = "forgejo"
  }
}
```

This setup ensures secure, efficient authentication for your automation workflows.
