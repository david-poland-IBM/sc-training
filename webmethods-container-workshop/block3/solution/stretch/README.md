# Capstone 3 — Stretch Goals (Reference Solution)

| File | Stretch goal |
|---|---|
| `stretch3-solution.sh` | Runs all three in order, prints what to look for |
| `compose.yaml` | Solution `compose.yaml` **plus** the nginx `web` service from Exercise 3.7 (goal 3) |
| `compose.no-wait.yaml` | Overlay that replaces `condition: service_healthy` with a plain `depends_on` (goal 2) |
| `.env.example` | Same as `../../capstone/.env.example` |

```bash
cp .env.example .env
./stretch3-solution.sh             # builds from a temp COPY of ../../capstone/api
./stretch3-solution.sh cleanup     # podman-compose down -v
```

Ports 3000 and 8080 must be free: stop your own Capstone 3 and Exercise 3.7 stacks first.

## 1. Change one line in `server.js`, `up -d --build`

```text
STEP 2/8: WORKDIR /app
--> Using cache d534c848...
STEP 3/8: COPY package.json .
--> Using cache 340632db...
STEP 4/8: RUN npm install --omit=dev
--> Using cache df2aa3d9...
STEP 5/8: COPY server.js .          <- rebuilt from here on
STEP 6/8: USER node
...
```

Every step **before** the first changed input comes from the cache, including
`npm install`. `COPY server.js` and everything after it runs again. That's why the
Containerfile copies `package.json` first and the code last.

**podman-compose trap:** `podman-compose up -d --build` rebuilds the image but does **not**
re-create the running `api` container. podman-compose 1.6 re-creates only when the compose
configuration changes, not when the image behind the tag changes. The old code keeps running
until you force it:

```bash
podman-compose up -d --build --force-recreate api
```

Docker Compose re-creates on an image change automatically.

## 2. Without `condition: service_healthy`

```bash
podman-compose down -v
podman-compose -f compose.yaml -f compose.no-wait.yaml up -d
curl http://localhost:3000
```

```text
t+0s: curl: (56) Recv failure: Connection reset by peer
t+3s: curl: (7) Failed to connect to localhost port 3000 ...
t+6s: curl: (7) Failed to connect to localhost port 3000 ...
shop_db_1   Up 7 seconds (healthy)
shop_api_1  Exited (1) 7 seconds ago
Error: connect ECONNREFUSED 10.89.0.2:5432
```

`api` starts as soon as the `db` *container* has started. After `down -v`, PostgreSQL is
still initialising its new data directory, so the API's first query gets `ECONNREFUSED`.
`server.js` doesn't handle that rejection, so Node exits, and with no `restart:` policy
the container **stays dead** even though `db` is healthy seconds later.
`podman-compose start api` fixes it by hand.

The two halves of the fix: `condition: service_healthy` (start order) and an app that
retries its connections, or a `restart:` policy (Block 6). MSR retries JDBC by itself.
Block 4 shows what it does *not* retry.

## 3. The web service in the same file

```yaml
  web:
    image: docker.io/library/nginx:1.27-alpine
    ports:
      - "8080:80"
    volumes:
      - ../../../block1/exercises/site:/usr/share/nginx/html:ro   # relative to THIS file
    networks: [frontend]
```

```text
shop_db_1   shop_backend   5432/tcp
shop_web_1  shop_frontend  0.0.0.0:8080->80/tcp
shop_api_1  shop_backend   0.0.0.0:3000->3000/tcp
```

`web` doesn't need `db` or `api`, so it has no `depends_on` and sits on its own `frontend`
network. Bind-mount paths are relative to the **compose file**, not your shell's current
directory. In `block3/exercises/first-compose/compose.yaml` the same site is
`../../../block1/exercises/site`.
