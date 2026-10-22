# Application Assistant

http://localhost:5678/

A Discord bot built with n8n that tailors my CV, cover letter and interview prep to each job offer. I upload my CV once, send an offer, answer one question about what's missing, and get back a tailored CV (PDF), a cover letter and a cheat sheet in Google Docs. What I confirm is remembered for the next offers.

No-Code Software Development project, Pollux Gronier, ESSEC/CentraleSupélec AIDAMS, October 2026.

**The need:** students applying to many internships rewrite their CV and letter by hand for every offer, or paste their CV, the offer and a prompt into ChatGPT each time, which also invents skills they don't have.

## What it does

| Command | Result |
|---|---|
| `/cv file:<cv.pdf>` | Reads the CV once; an LLM turns it into JSON, saved in Postgres. Not a PDF → "attach a PDF". |
| `/job url:<link>` or `/job text:<offer>` | An LLM lists the offer's requirements, a Code node compares them with my CV: score /10, found / missing, and **one** question. Bad link → usage message; blocked page → "paste the text". |
| `/answer text:<answer>` | Saves what I confirm, then writes the CV (5 fields of my Google Docs template), the letter and the cheat sheet, in the offer's language. About 1 minute. |
| `/help` (or anything unknown) | Usage message. |

## Architecture

Workflows, one job each (exported in `workflows/`):

| File | Trigger | Role |
|---|---|---|
| `1-main-discord-router.json` | Discord slash command (Webhook) | Signature check (Code), "thinking…" within 3 s, run log, input check, **Command Router** (Switch) → `/cv`, `/job`, `/answer` |
| `2-sub-analyzer.json` | Execute Workflow (defined inputs) | Fetch the offer → LLM extracts requirements + synonyms → **Code: Gap Analysis** → one question → session saved |
| `3-sub-generator.json` | Execute Workflow (defined inputs) | Learn from the answer → LLM writes CV, letter, cheat sheet → Google Drive/Docs → PDF back in Discord |
| `4-error-handler.json` | Error Trigger | Discord alert with workflow name, failing node, error and execution URL; tells the user |
| `0-setup-register-commands.json` | Manual, once | Registers the slash commands |
| `5-inspect-database.json` | Manual | Shows the project tables |

```
Discord ──signed POST──► 1. Main ──/job──► 2. Analyzer ──no gaps──► 3. Generator
   ▲  "thinking…" < 3 s      │  ──/answer─────────────────────────────►   │
   └──── edit that message: reply, PDF, links ◄────────────────────────────┘
```


APIs: Discord, OpenRouter (Gemini 3.5 Flash), Google Drive and Docs, the job pages (HTTP). Database: Postgres, tables `profiles`, `facts`, `sessions`, `runs` (`db/init/01-assistant-db.sh`).

## Run it locally with Docker

Requirements: Docker with Docker Compose v2.

```bash
git clone https://github.com/Polluxgnr/application-assistant.git
cd application-assistant
cp .env.example .env          # then edit .env (see the comments in it)
docker compose up -d
docker compose ps             # postgres and n8n must show "healthy"
```

Open http://localhost:5678 and create the owner account. On its first start Postgres also creates the project database `assistant` and its tables. Data survives a restart (named volumes `pg_data`, `n8n_data`):

```bash
docker compose down && docker compose up -d   # workflows and data are still there
```

### Import the workflows

```bash
docker compose exec n8n n8n import:workflow --separate --input=/workflows
```

Then, in n8n:
1. Create the credentials and select them in the nodes that show a warning: **Header Auth** `Discord Bot Auth` (`Authorization: Bot <token>`), **OpenRouter** (API key), **Google Drive OAuth2** and **Google Docs OAuth2** (same Google client, then *Sign in with Google*), **Postgres** (host `postgres`, database `assistant`, user and password from `.env`).
2. Google Cloud: enable the Drive **and** Docs APIs, OAuth client "Web application" with redirect `http://localhost:5678/rest/oauth2-credential/callback`, and add your account as a test user.
3. Discord needs a public HTTPS URL: the `tunnel` service (ngrok, free account; put `NGROK_AUTHTOKEN` in `.env`) gives one that never changes (`docker compose logs tunnel | grep url=`). Paste `<url>/webhook/application-assistant` once in Discord Developer Portal → General Information → Interactions Endpoint URL.
4. Publish the workflows, run *0. Setup* once, then `/help` in Discord.

Tested on 22 October 2026 from a fresh clone: Postgres healthy with the 4 tables, n8n `/healthz` 200, 6 workflows imported, still present after down / up.

## How to test

Each sub-workflow has a saved test payload pinned on its *Start* node, so it can be run from the editor.

| Send | Expected |
|---|---|
| `/help` | Usage message |
| `/cv` with a PDF | "CV saved: 29 skills/tools, 6 experiences" |
| `/job url:` a data offer (Qonto, Lever) | 7/10 and one question |
| `/answer` | CV PDF + letter + cheat sheet links |
| Same `/answer` again | "No job in progress", nothing new saved |
| `/job text:` a French offer | Question and letter in French |
| `/job url:hello` | Usage message |
| `/job url:https://this-does-not-exist.invalid/job` | 3 retries, then "I couldn't read that page" |
| A Google API disabled | User told + one admin alert with the execution link |

## Security

- No secret is stored in this repository: n8n exports only credential names and ids, `.env` is git-ignored.
- `N8N_ENCRYPTION_KEY` comes from the environment; keep a copy, without it the stored credentials can't be decrypted.
- Every Discord request is checked with its Ed25519 signature (401 otherwise).

## Use of AI

An AI assistant was used throughout the project: to design the workflows, write the Code nodes, prompts and SQL, set up Docker, and run and debug the tests.
