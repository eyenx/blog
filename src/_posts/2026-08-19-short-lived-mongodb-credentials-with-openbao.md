---

layout: post
title: "Managing Dynamic MongoDB Credentials with OpenBao"
description: "Learn how to use the OpenBao MongoDB Plugin to dynamically create credentials on the fly."
category: howto
tags: [mongodb, openbao, secrets]

---

Managing database credentials securely across distributed systems is one of the most critical aspects of modern cloud infrastructure. Hardcoding credentials in configuration files or static secret management systems often introduces security risks like unauthorized access and secrets leakage.

This is where **[OpenBao](https://openbao.org/)** comes in. OpenBao is an open-source, community-driven project designed to securely manage secrets, keys, and sensitive data. 

One cool thing about OpenBao is its extensible **plugin architecture**. Plugins allow OpenBao to interact dynamically with custom external services, cloud providers, and databases. 

Through the plugins hosted at [github.com/openbao/openbao-plugins](https://github.com/openbao/openbao-plugins), you can easily generate short-lived, dynamic credentials for a wide variety of backend systems on demand.

In this guide, we'll look at how to set up and configure the **OpenBao MongoDB Database Plugin** to generate dynamic MongoDB users.

## Step 1: Configuring the MongoDB Plugin in OpenBao

To enable plugin auto-downloading and registering, configure your OpenBao HCL file (`config.hcl`). You can declare the MongoDB plugin directly within the configuration block:

```hcl
plugin_directory = "/openbao/plugins"
plugin_auto_download = true
plugin_auto_register = true

plugin "database" "mongodb" {
  image       = "ghcr.io/openbao/openbao-plugin-database-mongodb"
  version     = "v0.0.1"
  binary_name = "openbao-plugin-database-mongodb"
  sha256sum   = "2fc346826f30755136af974bcb42f0578747722cf49a7bb5c20c3fbb9eb01e47"
}
```

## Step 2: Verifying Plugin Installation and Enabling Database Engine

After restarting the OpenBao server, verify that the MongoDB database plugin has been registered correctly:

```bash
bao plugin list database | grep mongo
```

**Output:**
```text
mongodb                         v0.0.1
```

Next, enable the database secrets engine in OpenBao:

```bash
bao secrets enable database
```

## Step 3: Configuring the MongoDB Connection

Now, configure OpenBao with the administrative connection details to your MongoDB cluster. Replace `PASSWORD` with your administrative password.

```bash
bao write database/config/mongodb \
    plugin_name=mongodb \
    allowed_roles=mongo-role \
    connection_url="mongodb://{{username}}:{{password}}@mongodb.mongodb.svc.cluster.local:27017/admin?tls=false" \
    username=admin \
    password=PASSWORD
```

**DISCLAIMER** TLS is disabled in this example. For production, set `tls=true` in `connection_url` and configure MongoDB TLS certificates appropriately.

## Step 4: Creating a Role for Dynamic Credentials

Next, create a role (`mongo-role`) that defines the permissions and TTL (Time-To-Live) for generated credentials.

In the example below, users generated under this role will be assigned `readWrite` access to the `openbao` database on MongoDB, with a default lease time of 1 hour.

```bash
bao write database/roles/mongo-role \
    db_name=mongodb \
    creation_statements='{"db":"openbao","roles":[{"role":"readWrite"}]}' \
    default_ttl="1h" \
    max_ttl="24h"
```

## Step 5: Generating Dynamic Credentials

With everything set up, you can now request fresh, temporary MongoDB credentials via the CLI:

```bash
bao read database/creds/mongo-role
```

**Output:**
```text
Key                 Value
---                 -----
lease_id            database/creds/mongo-role/mo7HNOLvmIoAp9VQJpkxk1IX
lease_duration      1h
lease_renewable     true
password            NUXLw56O-dAGw1FfaJc-
username            v-userpass-openbao-mongo-role-R888IbZtrlPwgTaLOol1-1787120741
```

OpenBao generates a unique temporary username and strong password specifically for this request.

## Step 6: Verifying Database Access

Finally, verify that the generated dynamic credentials work by logging into MongoDB with `mongosh`:

```bash
mongodb@mongodb-0:/$ /usr/bin/mongosh openbao -u v-userpass-openbao-mongo-role-R888IbZtrlPwgTaLOol1-1787120741
Enter password: ********************
```

**Shell Output:**
```text
Current Mongosh Log ID: 6a854c82907286eec39c7288
Connecting to:          mongodb://<credentials>@127.0.0.1:27017/openbao?directConnection=true&serverSelectionTimeoutMS=2000&appName=mongosh+2.10.0
Using MongoDB:          8.3.8
Using Mongosh:          2.10.0

For mongosh info see: https://www.mongodb.com/docs/mongodb-shell/

openbao> db.myCollection.find()
[ { _id: ObjectId('6a854b09f107d547a9ae8ac8'), name: 'test' } ]
```

Access is successfully granted! Once the lease duration expires (1 hour), OpenBao automatically revokes the user from MongoDB.

## Conclusion

Using OpenBao's extensible plugin system, you can eliminate long-lived database credentials across your infrastructure. Explore more plugins and community extensions at the [OpenBao Plugins GitHub repository](https://github.com/openbao/openbao-plugins).
