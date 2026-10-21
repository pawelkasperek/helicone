# Docker Setup

## Quick Start: All-in-One Container

For the simplest self-hosted setup, use the all-in-one Docker image:

```bash
docker pull helicone/helicone-all-in-one:latest
docker run -d --name helicone -p 3000:3000 -p 8585:8585 -p 9080:9080 helicone/helicone-all-in-one:latest
```

**Ports:**
- `3000` - Web dashboard
- `8585` - Jawn API + LLM proxy
- `9080` - MinIO S3 storage (for request/response bodies)

For production deployments with custom domains, see the [official self-hosting docs](https://docs.helicone.ai/getting-started/self-host/docker).

---

# Local Development

## Running with Docker Compose

```
cp .env.example .env
docker compose up
```

NOTE: To create a user go to http://localhost:54323/project/default/auth/users and add your account.
You can use this account to sign into Helicone at localhost:3000 via your browser.

**Default URLs (Development):**

- Helicone Webpage: localhost:3000
- Helicone Jawn API/Proxy: localhost:8585
- OpenAI Proxy Worker: localhost:8787 (when running workers separately)
- Helicone API Worker: localhost:8788 (when running workers separately)

# Maintenance

### Helicone container builds

```
docker build -t helicone/supabase-migration-runner -f dockerfiles/dockerfile_supabase_migration_runner ../supabase
docker build -t helicone/worker -f dockerfiles/dockerfile_worker ../worker
docker build -t helicone/web -f dockerfiles/dockerfile_web ../web
docker build -t helicone/clickhouse-migration-runner -f dockerfiles/dockerfile_clickhouse_migration_runner ../clickhouse
```

Note: we are in the process of updating our `docker-compose.yml` file.
If you are looking to self-host, we also provide an up-to-date Helm
Chart. Please reach out to us if you would like access!


# Running for development

This guide will lead you through running the infrastructure components
of Helicone locally via `docker compose`, and the services locally
bare-metal, so that you can have a fast and easy local development feedback loop.

```
git clone git@github.com:Helicone/helicone.git
cd helicone
```

## Step 1 - Install all the things

Requirements:
- [Docker](https://docs.docker.com/engine/install/)
- [Supabase](https://supabase.com/docs/guides/local-development/cli/getting-started)
- [NVM](https://github.com/nvm-sh/nvm?tab=readme-ov-file#installing-and-updating)

Install Node version and NPM packages:

```
nvm install 20
nvm use 20
npm install -g yarn
yarn global add wrangler
```

## Step 2 - Configure all the things

From the root of the repo,

```
cp .env.example .env
cp valhalla/jawn/.env.example valhalla/jawn/.env
```

Start up Supabase: `supabase start`

Then update the values in the `.env` files based off
your API keys, including the Supabase Anon and Secret
Key that were printed after running `supabase start`.

## Step 3 - Start all the things

### Infra

Start the infrastructure components via docker compose:

```
cd docker
docker compose -f docker-compose-local.yml --profile include-worker up -d
```

### Workers

*Note*: If you are developing locally on the workers, simply exclude the
`--profile include-worker` arguments and instead start each worker you need
manually from the command line with the following commands:

```
cd worker
yarn
# Start OpenAI Proxy Worker
# WORKER_TYPEs: [OPENAI_PROXY, ANTHROPIC_PROXY, HELICONE_API]
npx wrangler dev --local --var WORKER_TYPE:OPENAI_PROXY --port 8787 --test-scheduled
```

### Jawn (Backend)

In a new terminal, from the root of the repo:

```
cd valhalla/jawn
yarn && yarn dev
```

### Web

In a new terminal, from the root of the repo:

```
cd web
yarn && yarn dev:local
```

## Step 4 - Verification

You can login to Helicone at `http://localhost:3000`
with the following credentials:

User: `test@helicone.ai`
Password: `password`

Change the Org to `Organization for Test` and then you should be able to see your requests!

Please do not hesitate to reach out on discord if you have any questions.

Feel free to run some of the examples from `helicone/examples` against
your new local Helicone instance!


Alternatively, you can also test the API against your local via the following
`curl` command:

```
export OPENAI_API_KEY="sk-..."
export HELICONE_API_KEY="sk-..."
curl --request POST \
  --url http://localhost:8787/v1/chat/completions \
  --header "Authorization: Bearer $OPENAI_API_KEY" \
  --header "Helicone-Auth: Bearer $HELICONE_API_KEY" \
  --header 'Content-Type: application/json' \
  --header 'Accept-Encoding: identity' \
  --header 'helicone-property-hello: world' \
  --data '{
    "model": "gpt-4o-mini",
    "messages": [
        {
            "role": "system",
            "content": "generate a prompt for stable diffusion using this article.\n The prompt should instruct the image generation model to generate a image that would be suitable for the main image of the article.\n Therefore, the image should be relevant to the article, while being photorealistic, and safe for work.\n Only include the prompt, and do not include a introduction to the prompt. The entire prompt should be 90 characters or less. Make it as relevant to the image as possible, but do not include people or faces in the prompt."
        }
    ]
}'
```

## Notes

- If you update the migration files, then do not forget to rebuild the 
  `clickhouse-migration-runner-local` Docker image!
- Currently there are some stability issues with the local Kafka and worker
  configurations, hence the `unstable` profile for those services. It's
  recommended to keep it disabled for now, until the stability issues are
  resolved.

## Troubleshooting

### `yarn install` fails with `Couldn't find package "@helicone-package/pricing@*"`

```
error Couldn't find package "@helicone-package/pricing@*" required by "bifrost@0.1.0" on the "npm" registry.
ERROR: process "/bin/sh -c yarn install --frozen-lockfile --network-timeout 300000" did not complete successfully: exit code: 1
target web: failed to solve
```

`dockerfiles/dockerfile_web` installs the monorepo with
`yarn install --frozen-lockfile` *before* copying any source, so every workspace
referenced by the copied `package.json` files needs its own
`COPY packages/<name>/package.json ./packages/<name>/` line. Both
`bifrost/package.json` and `valhalla/jawn/package.json` depend on
`@helicone-package/pricing`, so omitting `packages/pricing/package.json` makes Yarn
resolve that dependency from the npm registry instead of the local workspace, and
the build fails.

When you add a workspace under `packages/`, add the matching
`COPY packages/<name>/package.json ./packages/<name>/` line to
`dockerfiles/dockerfile_web`.

### `mailhog` fails to start: `failed to bind host port 0.0.0.0:1025/tcp: address already in use`

```
failed to set up container networking: driver failed programming external connectivity on endpoint mailhog (...): failed to bind host port 0.0.0.0:1025/tcp: address already in use
```

`docker-compose.yml` publishes MailHog on the host as `1025:1025` (SMTP) and
`8025:8025` (Web UI). Anything already listening on port 1025 aborts
`docker compose up` and leaves the services that come after it in the `Created`
state. ProtonMail Bridge, for example, binds `127.0.0.1:1025`.

Nothing inside the stack needs the host-side SMTP publish: `web` and `jawn` reach
MailHog over the Compose network as `mailhog:1025`. Only the Web UI needs a host
port for your browser, so create `docker-compose.override.yml` (already
`gitignore`d) and remap it:

```yaml
services:
  mailhog:
    ports: !override
      - "18025:8025"
```

`!override` is required because Compose concatenates `ports` lists across files by
default. Read the verification emails at http://localhost:18025.

### Build time

The `jawn` image is expensive to build: it compiles mbedTLS 3.6.4 from source,
installs PyTorch 2.7.1 (CPU) and pulls ffmpeg from the Debian `testing` repository.
Expect the first build to take tens of minutes. Also, `BETTER_AUTH_SECRET` is not
passed as a build arg to the `web` image, so `next build` logs
`ERROR [Better Auth]: You are using the default secret` while generating static
pages; the secret is set correctly at runtime by `docker-compose.yml`.
