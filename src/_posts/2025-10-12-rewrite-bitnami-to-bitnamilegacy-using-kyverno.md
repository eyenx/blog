---
layout: post
title: "Migrating from Bitnami to Bitnami Legacy with Kyverno"
description: "Learn how to use Kyverno to automatically update Pods to pull images from docker.io/bitnamilegacy instead of docker.io/bitnami."
category: howto
tags: [containers, automation, kyverno]
---

You may have recently heard about [Bitnami's move to Secure Images for Production-Ready containerized Applications](https://news.broadcom.com/app-dev/broadcom-introduces-bitnami-secure-images-for-production-ready-containerized-applications).

Bitnami has transitioned to providing Secure Images for containerized applications, which are no longer free. If you're encountering `ImagePullBackOff` errors in your Kubernetes cluster, it's likely due to this change.

In short, Bitnami container images now require a subscription. However, they've provided a temporary solution by allowing access to older images through the `docker.io/bitnamilegacy` registry.

**Note:** This is a stopgap measure. The long-term goal is to move away from Bitnami entirely. Projects like [CloudPirates](https://github.com/cloudpirates) are already working on providing alternative images and charts.

## Kyverno Policy Example

```
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: patch-bitnami-to-bitnamilegacy
spec:
  admission: true
  background: false
  validationFailureAction: Audit
  rules:
    - name: patch
      match:
        any:
          - resources:
              kinds:
                - Pod
              operations:
                - CREATE
      mutate:
        foreach:
          - list: request.object.spec.containers
            patchStrategicMerge:
              spec:
                containers:
                  - image: >-
                      {{ images.containers."{{element.name}}".registry }}/bitnamilegacy/{{ images.containers."{{element.name}}".path | split(@,'/')[1] }}:{{ images.containers."{{element.name}}".tag }}
                    name: "{{ element.name }}"
            preconditions:
              all:
                - value: True
                  operator: Equals
                  key: '{{ images.containers."{{element.name}}".path | contains(@,''bitnami/'') }}'
                - key: '{{ images.containers."{{element.name}}".registry }}'
                  operator: Equals
                  value: docker.io
          - list: request.object.spec.initContainers || []
            patchStrategicMerge:
              spec:
                containers:
                  - image: >-
                      {{ images.initContainers."{{element.name}}".registry }}/bitnamilegacy/{{ images.initContainers."{{element.name}}".path | split(@,'/')[1] }}:{{ images.initContainers."{{element.name}}".tag }}
                    name: "{{ element.name }}"
            preconditions:
              all:
                - value: True
                  operator: Equals
                  key: '{{ images.initContainers."{{element.name}}".path | contains(@,''bitnami/'') }}'
                - key: '{{ images.initContainers."{{element.name}}".registry }}'
                  operator: Equals
                  value: docker.io
      skipBackgroundRequests: true
```

See also on [playground.kyverno.io](https://playground.kyverno.io/#/?content=N4IgDg9gNglgxgTxALhAWgwHQHYEMwwBqApgE4DOME2yABANYIBuZ2EAdFQPRMCMO9GNgAmdAMJQAruQAuZAArR4CHAFtiM3MNybkOWrTzq6YHXAAWaAEYwZRhGhkRrt%2B1GIBzXIhzkwxOD1sAy1VGHJKajoZUklifVorb3oPUghJEToAM1wocnjg2iZcmG0ZKmwAMVwYKVJiAEE4cqjaBslhWwTY93IggwM0Q1xjWlMZCwSB2lUzc37pgdxsBAXFgaH68nTSOGI%2BqfXFwREDwqOjocVhQ4uDCH9SHQqzu8vaMQAlAFEGgBVvrcZpJNHI1osshB6t55kDpkNYLI6PUAI5xWTsCBWABWARk7D8AXYcGomiEZHIcMW4wsAGUYjpPPAALJkDzEcFvQmBKkXEnYMnYCmct4bWgwWbsugAPjQvNFBmAwHFkv2xNJNSFFHYmBASuI7nUAvYRmIAF8zbr2PUPOEYghaBauDY7CNap5vAguEqVbh2eR1QLNRSdXrgAbiEb8aaLVbxuZaAAfWh%2BWAyAAUAAEADQAci4uYAlABtXgAXUdZuQPolfrV/MFId1%2BsNxGNMctIHYmg8lflb1NdGbyojUZNI2IfZA/bG9X5nRa2FeCtouSgIreQ2KUg5tD%2BsQKK8WDzIOihdG%2BaNylPOR4YxFWtFzNdVAYbwe1w9HbejE9jXfjJNaHfIRyCzPNcxdIwYALItK1zGd4XvR9n2VWt/UDRtPzDb92z/TtrSZWRSAdC0ENvI8TyeJxSAvK88kQxZtziOhhAgOB6DITgIHlBE7WRYg0X2fEsVxZoCX8OBOGwWwxA1ckKCTZNizLGcaXMelqKZOBWVIKVGO5Dc7hArVlzvWghnQ3dZUYi4XzrAMhFk%2BTTNDFtIx/cd1H/QjbWI0izWdVw3XcLxEG9NDX2k5ygwUgMv1bPDvIIwDk1TWxwPzItSwrC1q0ihzopkOTYtchKPKS80CJ7PsKLvQdaGHWhcN/dQpzUudqAXF4jPWNdeveZjd33OJbIGKiz1o2hL0ka8xoMTiUPsjCnOKlymxwxLWqquMdATZMTLAnNc0g4Kwlgwt4LGoZFroVDfRWmS1tKjb3LHDsrRtO0SKuuqFQmmi6Nmhi/tFIbWPYzjSG4oFyEEMAACFklSdIRE%2BQT0RkPpaBiOIQGzEAth2PYUBAfAiApCo6D4AQhFEWhrjUDQtB0XAFgauRZDQSBhDQDwIAgG5ClNPxvF3YRiBySQoBkBIoFwKwDTM2dBaHEBcfiacl0khZVpKrDlaGBr6EkRXmigIErIhjiuO4KC3S4E2zZkdd5c52XChM4VDiNic6GwW1sAAD0t1U7rYm3obts6YPqTpyDQOApFkMhkAAdnYAAWdheDQCWbGWNBeAAJjQUgAAZc3xkBoGEdHtkkXZiFJ6u4GkJxVHr4niAAEUl1aXhbgmk/bsgu8bvZyCHkBiCDvYwEXKfUBAM0gA=).

This example policy replaces the `docker.io/bitnami` image references of a Pod to `docker.io/bitnamilegacy` registry.
