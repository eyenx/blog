---
layout: post
title: "Self-hosted ACME Certificates with OpenBao and Traefik"
description: "Leverage OpenBao's ACME directory to create certificates for Traefik Ingresses"
category: howto
tags: [containers, automation, traefik, openbao, secrets, pki, acme]
---

[ACME](https://en.wikipedia.org/wiki/Automatic_Certificate_Management_Environment) is an excellent protocol that allows us to obtain free certificates from Let's Encrypt CA.

But what if you want to do the same thing internally within your company using your own CA?

There are many ACME-compatible software options available. Today, we're going to specifically look into using OpenBao to generate and maintain your own Root CA, including Intermediates, and use that engine as an ACME Server.

Traefik will act as the client, requesting certificates via ACME for the Kubernetes ingresses it manages.

Let's start with setting up [OpenBao](https://openbao.org).

## OpenBao Setup

Initially forked from HashiCorp Vault, OpenBao is a OSS secrets management solution that you can self-host. It includes several secrets engines, one of which is the PKI Engine, with which you can create your own certificates.

The PKI Engine has integrated [ACME directories](https://openbao.org/api-docs/secret/pki/#acme-directories), and we'll utilize that.

Assuming you already have an OpenBao instance running, if not, here's a sample `values.yaml` file to use with the official [openbao/openbao-helm Chart](https://github.com/openbao/openbao-helm):

```yaml
global:
  # TLS termination at the OpenBao level is recommended
  tlsDisable: false
csi:
  enabled: false
injector:
  enabled: false
server:
  # DISCLAIMER: Do not use static keys in production!
  extraSecretEnvironmentVars:
    - envName: STATIC_SEAL_KEY
      secretName: bao-static-seal-key
      secretKey: key
  resources:
    requests:
      memory: 1Gi
      cpu: 500m
    limits:
      memory: 2Gi
      cpu: 1000m
  ha:
    enabled: true
    replicas: 3
    raft:
      enabled: true
      config: |
        ui = true
        listener "tcp" {
          address = "[::]:8200"
          cluster_address = "[::]:8201"

          tls_cert_file = "/openbao/tls/tls.crt"
          tls_key_file = "/openbao/tls/tls.key"
        }
        storage "raft" {
          path = "/openbao/data"

          retry_join {
            leader_tls_servername = "bao.example.com"
            leader_api_addr = "https://openbao-active:8200"
            leader_client_cert_file = "/openbao/tls/tls.crt"
            leader_client_key_file = "/openbao/tls/tls.key"
            leader_ca_cert_file = "/openbao/tls/ca.crt"
          }
        }

        # DISCLAIMER: Do not use static keys in production!
        seal "static" {
          current_key_id = "ID"
          current_key = "env://STATIC_SEAL_KEY"
        }
        service_registration "kubernetes" {}

  updateStrategyType: RollingUpdate

  livenessProbe:
    enabled: true

  ingress:
    tls:
      - hosts:
          - bao.example.com
        secretName: bao-tls
    enabled: true
    ingressClassName: myingress
    hosts:
      - host: bao.example.com
        paths: []
  volumes:
    - name: tls
      secret:
        secretName: bao-tls
  volumeMounts:
    - name: tls
      mountPath: /openbao/tls
      readOnly: true
```

After setup, you'll need to initialize your OpenBao instance:

```
bao operator init --recovery-threshold=NUMBER --recovery-shares=NUMBER
```

Choose a number of recovery-shares and threshold that suits your needs. For more information about recovery keys, refer to the [documentation](https://openbao.org/docs/2.4.x/concepts/seal/#recovery-key).

Once initialized, you'll have a root token that you can use to configure your OpenBao instance. 
The root token is meant for short-term use to set up another authentication method. Revoke your root token as soon as you've done that, as keeping it around is considered bad practice. 
Ideally, set up a working authentication method directly upon initialization using the [self-init feature](https://openbao.org/docs/2.4.x/configuration/self-init/) of OpenBao.

## PKI Engine

Now, let's create our PKI Engines to host our Root and Intermediate CAs (also see the official [documentation](https://openbao.org/docs/secrets/pki/quick-start-root-ca/)):

```
# Enable one PKI Engine for our Root CA
bao secrets enable pki_root

# Tune it to have a maximum TTL of 10 years
bao secrets tune -max-lease-ttl=3650d pki_root

# Generate our Root CA
bao write pki_root/root/generate/internal common_name="Company CA" ttl=3650d

# Set URL Configuration
bao write pki_root/config/urls issuing_certificates="https://bao.example.com/v1/pki_root/ca" crl_distribution_points="https://bao.example.com/v1/pki_root/crl"

# Enable PKI Engine for our Intermediate CA
bao secrets enable pki_int

# Tune it to have a maximum TTL of 5 years
bao secrets tune -max-lease-ttl=43800h pki_int

# Create our Intermediate CA
bao write pki_int/intermediate/generate/internal common_name="Company INT 2025" ttl=43800h -format=json | jq .data.csr -r > int.csr

# Use the created CSR to get it signed by the Root PKI
bao write pki_root/root/sign-intermediate csr=@int.csr format=pem_bundle ttl=43800h -format=json | jq .data.certificate -r > int.crt

# Now set the Intermediate CA to be signed with the signed CRT
bao write pki_int/intermediate/set-signed certificate=@int.crt

# Finally, set URL Configuration for the Intermediate CA
bao write pki_int/config/urls issuing_certificates="https://bao.example.com/v1/pki_int/ca" crl_distribution_points="https://bao.example.com/v1/pki_int/crl"
```

Next, activate the ACME feature on the Intermediate PKI Engine and create a role for Traefik's use:

```
bao write pki_int/config/cluster aia_path=https://bao.example.com/v1/pki_int path=https://bao.example.com/v1/pki_int

bao write pki_int/config/acme enabled=true

# This will set the max_ttl of the created certificates to 1 year
bao write pki_int/roles/traefik allowed_domains=example.com allow_subdomains=true max_ttl=365d
```

We are now ready to use OpenBao with Traefik.

## Traefik

Configuring Traefik can be somewhat challenging to understand, and it took me some time to get this working. If you think my configuration could be improved, please let me know.

```yaml
# Values.yaml for Traefik Helm Chart
volumes:
providers:
  kubernetesIngress:
    ingressClass: traefik
deployment:
  replicas: 1
ingressClass:
  name: traefik
  isDefaultClass: true
certificatesResolvers:
  openbao:
    acme:
      email: admin@openbao.example.com
      storage: /data/acme.json
      caServer: https://bao.example.com/v1/pki_int/roles/traefik/acme/directory
      httpChallenge:
        entrypoint: web
ports:
  web:
    redirectTo:
      port: websecure
  websecure:
    tls:
      enabled: true
      resolver: openbao
```

There might be other configurations you would want, such as how to expose Traefik, but that is beyond the scope of this guide.

Upon starting Traefik, you should see it initiating the `acme.Provider`:

```
2025-12-23T06:21:18Z INF Starting provider *acme.Provider
2025-12-23T06:21:24Z INF Register... providerName=openbao.acme
```

## Ingress

Now, let's create an Ingress for an application:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "true"
    traefik.ingress.kubernetes.io/router.tls.certresolver: openbao
  name: monitoring-grafana
  namespace: monitoring
spec:
  ingressClassName: traefik
  rules:
  - host: grafana.example.com
    http:
      paths:
      - backend:
          service:
            name: monitoring-grafana
            port:
              number: 80
        path: /
        pathType: ImplementationSpecific
  tls:
  - hosts:
    - grafana.example.com
```

The critical annotations here are:

```yaml
traefik.ingress.kubernetes.io/router.tls: "true"
traefik.ingress.kubernetes.io/router.tls.certresolver: openbao
```

These tell Traefik to create a certificate for this Ingress using our certresolver, OpenBao.

If everything is configured correctly, you shouldn't see many logs from Traefik. The Ingress should work, and in OpenBao, you'll find the generated certificate as well:

```
bao list pki_int/certs
Keys
----
xz:xy:x0:tt

bao read pki_int/cert/xz:xy:x0:tt -format=json | jq .data.certificate -r | openssl x509 -noout -text
Certificate:
    Data:
        Version: 3 (0x2)
        Serial Number: xyz
        Signature Algorithm: sha256WithRSAEncryption
        Issuer: CN=Company INT
        Validity
            Not Before: Dec 23 06:28:44 2025 GMT
            Not After : Jan 24 06:29:14 2026 GMT
        Subject: CN=grafana.example.com
        Subject Public Key Info:
            Public Key Algorithm: rsaEncryption
                Public-Key: (too many bits)
                Modulus:
                    xyz
                Exponent: 65537 (0x10001)
        X509v3 extensions: [xyz]
    Signature Algorithm: sha256WithRSAEncryption
    Signature Value: xyz
```

Congratulations, you have created certificates with your own PKI by using the ACME protocol on [OpenBao](https://openbao.org)!
