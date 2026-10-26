# Capstone 1 — Stretch Goal (Reference Solution)

> Add nginx serving `block1/exercises/site` on `shop-net`, and reach the database from
> inside it with `getent hosts shop-db`.

```bash
../capstone1-solution.sh           # shop-net + shop-db must exist
./stretch1-solution.sh
./stretch1-solution.sh cleanup     # removes shop-web only
```

## The two commands that matter

```bash
podman run -d --name shop-web --network shop-net -p 8081:80 \
  -v "$PWD/block1/exercises/site:/usr/share/nginx/html:ro" \
  docker.io/library/nginx:1.27-alpine

podman exec shop-web getent hosts shop-db
```

## Expected output

```text
== 1. nginx on the SAME user-defined network as the database
  <h1>Served from a folder on my laptop</h1>
== 2. name resolution from inside the web container
10.89.0.6         shop-db.dns.podman  shop-db.dns.podman shop-db
== 3. reachable, not just resolvable: TCP connect to PostgreSQL's port
   shop-db:5432 open
== 4. counter-check: a container on the DEFAULT network cannot resolve shop-db
   no answer (exit 2) ...
```

## Why it works

* `shop-net` is a user-defined network, so it has DNS: every container on it can be found
  by its container name (`shop-db.dns.podman`). The default network has no name resolution,
  which is why `backend` couldn't be resolved in Exercise 1.7.
* `getent hosts` only proves the **name** resolves. `nc -z shop-db 5432` proves the **port**
  is reachable, too. nginx itself never talks to PostgreSQL. Being on the same network is
  what makes it *possible*.
* Port 8081 is the one Exercise 1.6 used for the same site: `podman rm -f site` first if that
  container still runs.
