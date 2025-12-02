---
layout: post
title: "Cleaning Up My Closet AKA Synapse"
description: "Discover how to eliminate old events and reclaim disk space on your self-hosted Synapse server."
category: howto
tags: [containers, automation, matrix, synapse]
---

I've been running a self-hosted Matrix installation with the [Synapse](https://github.com/matrix-org/synapse/) homeserver, which includes a variety of integrations from Signal to IRC with [Heisenbridge](https://github.com/hifi/heisenbridge).

Over time, the number of rooms and chats can really add up, along with the disk space used by events in the PostgreSQL database. This led me to look for a way to purge the history of channels and free up space in my database.

Thankfully, the Synapse server provides an [open API](https://matrix-org.github.io/synapse/latest/admin_api/purge_history_api.html) that allows for history purging via a simple curl command:

```sh
TIMESTAMP=$(($(date -d "-1 year" +%s) * 1000)) # 1 year ago
curl -H "Authorization: Bearer $TOKEN" "http://localhost:8008/_synapse/admin/v1/purge_history/$room" -X POST -d "{\"purge_up_to_ts\":$TIMESTAMP,\"delete_local_events\":true}"
```

You'll need an admin token, which you can obtain from your user account in the Element web app (assuming you are an admin).

Next, we need a list of rooms. The API can assist with this as well:

```sh
curl -H "Authorization: Bearer $TOKEN" "http://localhost:8008/_synapse/admin/v1/rooms?limit=1000" > roomlist.json
```

To prepare for the purge, we'll clean up the `roomlist.json` and encode the room IDs:

```sh
cat roomlist.json | jq '.rooms[] | .room_id' -r | sed 's/\!/%21/g' > to_purge.txt
```

Now, let's execute the `purge_history` API call for all the rooms:

```sh
TIMESTAMP=$(($(date -d "-1 year" +%s) * 1000)) # 1 year ago
while read room; do
  curl -H "Authorization: Bearer $TOKEN" "http://localhost:8008/_synapse/admin/v1/purge_history/$room" -X POST -d "{\"purge_up_to_ts\":$TIMESTAMP,\"delete_local_events\":true}"
done < to_purge.txt
```

This process will remove all events older than one year.

It might take a while, but don't forget to run a `VACUUM FULL;` on your database afterward to reclaim the space.

I managed to reclaim about 40GiB of space:

![disk](/img/p/20251202_1.png)
