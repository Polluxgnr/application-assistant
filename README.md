# Application Assistant

A Discord bot, built with **n8n**, that tailors your CV, cover letter and interview cheat sheet to each job offer.

You upload your CV once (`/cv`), send any job link (`/job`), answer **one** question about the skills the offer asks for and your CV doesn't show (`/answer`), and get back a tailored CV as a PDF, a cover letter and an interview cheat sheet in Google Docs. Everything you confirm is remembered for the next applications.

> **Need, in one sentence:** students who apply to many internships rewrite their CV and cover letter by hand for every posting (or paste their background, the offer and a prompt into a generic AI chat each time, which also invents skills they don't have).

Self-hosted with Docker Compose: **n8n + Postgres + a Cloudflare tunnel** (so Discord can reach the local webhook).

---

## Contents
- [Architecture](#architecture)
- [Quick start (from a fresh clone)](#quick-start-from-a-fresh-clone)
- [Environment variables](#environment-variables)
- [Credentials](#credentials)
- [How to test](#how-to-test)
- [Design choices](#design-choices)
- [Robustness and error handling](#robustness-and-error-handling)
- [Versioning workflow](#versioning-workflow)
- [Project structure](#project-structure)
- [Troubleshooting](#troubleshooting)

---

## Architecture

```
            signed POST (slash command)                       /job                      no gaps
Discord ─────────────────────────────► 1. Main ──────────────────────► 2. Analyzer ───────────► 3. Generator
   ▲      answer < 3 s ("thinking…")      │   /answer ─────────────────────────────────────────►    │
   └──────────── PATCH the "thinking…" message (reply, PDF) ◄────────────────────────────────────────┘

  All workflows use:  OpenRouter (Gemini 3.5 Flash) · Postgres "assistant" DB · Google Drive + Docs
  On failure:         4. Error Handler  →  alert in the admin channel + message to the user
  Once, by hand:      0. Setup          →  registers /help /cv /job /answer
```

| Workflow | Started by | Job |
|---|---|---|
| `0-setup-register-commands` | me, once | Registers the 4 slash commands through the Discord API |
| `1-main-discord-router` | every slash command (Webhook) | Verifies the Ed25519 signature, answers within 3 s, logs the run, validates input, routes the command, handles `/cv` |
| `2-sub-analyzer` | Main on `/job` (Execute Workflow) | Reads the offer, AI extracts requirements, **Code** compares them with the CV, asks one question, saves the session |
| `3-sub-generator` | Main on `/answer` (or after the Analyzer when nothing is missing) | Learns from the answer, AI tailors 5 fields of the CV template, writes the letter and cheat sheet, sends the PDF |
| `4-error-handler` | n8n, when Main / Analyzer / Generator still fail after retries | Alerts me (workflow name, failed node, execution URL) and tells the user |

**What travels on the arrows:** after *Verify & Parse*, one small object: `user_id, app_id, token, url, text, answer`. The sub-workflows declare exactly these inputs.

**The Discord contract:** every command is an HTTP POST signed with Ed25519 (checked, otherwise `401`); Discord needs an answer within **3 seconds** (Main answers a *deferred* "thinking…"); the real answer is sent later by editing that message with the interaction token (valid 15 minutes, a full run takes about one minute).

### Data model (Postgres database `assistant`)
| Table | Role |
|---|---|
| `profiles` | One row per user: CV text + parsed CV (JSON). `/cv` again replaces it (upsert). |
| `facts` | Long-term memory: `skill`, `experience`, `gap` confirmed in answers. Unique on `(user_id, kind, md5(value))` → saving the same fact twice does nothing. |
| `sessions` | Short-term memory: the job in progress, one row per user (`waiting` → `done`, or `ready` → `done`). |
| `runs` | Execution id → user and reply token, so the error workflow can warn the right user. |

Schema: [`db/init/01-assistant-db.sh`](db/init/01-assistant-db.sh).

### Minimum technical requirements
| Requirement | Where |
|---|---|
| If / Set | *Signature valid?*, *Valid /job input?*, *Has CV?*, *Readable?*, *Missing skills?*, *Not alerted yet?*; Set payloads and *Question (with fallback)* |
| Code | *Verify & Parse* (Ed25519), *Clean Page to Text*, *Code: Gap Analysis*, *Build Profile*, *Format Error* |
| Switch | *Interaction Type* (ping / command / other), *Command Router* (`/cv`, `/job`, `/answer`) |
| API | Discord API, job pages (HTTP), OpenRouter, Google Drive and Docs, all with stored credentials |
| Message trigger | Discord slash commands (Interactions webhook) |
| Database | Postgres (`profiles`, `facts`, `sessions`, `runs`) |
| AI | 6 LLM Chains with written prompts, 5 with a Structured Output Parser |
| Sub-workflow | Analyzer and Generator via Execute Workflow, with defined inputs |
| Error handling + retries | Retry on fail on every external call, fallback branches, Error Workflow |

---

## Quick start (from a fresh clone)

**Requirements:** Docker Desktop (WSL 2 on Windows), Git Bash or any bash, a Discord application with a bot, an OpenRouter API key, a Google Cloud OAuth client (Drive + Docs APIs).

```bash
git clone https://github.com/Polluxgnr/application-assistant.git
cd application-assistant
./scripts/setup.sh          # 1st run: creates .env with random secrets, then stops
# edit .env: Discord ids + public key, Google template and folder ids
./scripts/setup.sh          # 2nd run: starts the stack, imports credentials + workflows, prints the tunnel URL
```

Then:
1. Open **http://localhost:5678** and create the owner account (local only).
2. Fill the 4 credentials (see [Credentials](#credentials)).
3. In the **Discord Developer Portal** → your app → *General Information* → **Interactions Endpoint URL**, paste the URL printed by `./scripts/tunnel-url.sh` (ends with `/webhook/application-assistant`). Discord checks the signature when you save.
4. Run the **0. Setup** workflow once (registers the slash commands).
5. In Discord: `/help`.

Stop with `docker compose down` and start again with `docker compose up -d`: workflows, credentials and data survive (named volumes `pg_data` and `n8n_data`). The quick tunnel gets a **new URL** every time its container restarts: re-run `./scripts/tunnel-url.sh` and update the Discord portal.

---

## Environment variables

`.env` is never committed; [`.env.example`](.env.example) lists every variable.

| Variable | Used for |
|---|---|
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Postgres server and n8n's own database |
| `ASSISTANT_DB` | The project database (created on first start) |
| `N8N_ENCRYPTION_KEY` | Encrypts the credentials stored by n8n. Keep it: losing it makes stored credentials unreadable |
| `N8N_EDITOR_BASE_URL` | Base of the execution links in error alerts |
| `GENERIC_TIMEZONE` | Dates in documents and schedules |
| `DISCORD_APP_ID`, `DISCORD_GUILD_ID` | Command registration (Setup workflow) |
| `DISCORD_PUBLIC_KEY` | Ed25519 signature check (Main → *Verify & Parse*) |
| `DISCORD_ADMIN_CHANNEL_ID` | Where the error workflow posts alerts |
| `GOOGLE_CV_TEMPLATE_ID` | Google Doc with the `{{SUMMARY}}`, `{{…_BULLETS}}`, `{{SKILLS}}` placeholders |
| `GOOGLE_DRIVE_FOLDER_ID` | Folder where each application gets its sub-folder |

## Credentials

`scripts/import.sh` imports **placeholders** (names and ids only, no secrets) so every node is already linked. Open *Credentials* in n8n and fill them:

| Credential | Type | What to paste |
|---|---|---|
| Discord Bot Auth | Header Auth | Name `Authorization`, value `Bot <your bot token>` |
| OpenRouter account 2 | OpenRouter | API key |
| Google Drive account | Google Drive OAuth2 | Client ID + secret, then *Sign in with Google* |
| Google Docs account | Google Docs OAuth2 | Same client, then *Sign in with Google* |
| Assistant DB (Postgres) | Postgres | Nothing: generated from `.env` |

Google OAuth client: Google Cloud Console → enable *Google Drive API* and *Google Docs API* → OAuth consent screen (External, add yourself as test user) → Credentials → *OAuth client ID* (Web application) with redirect URI `http://localhost:5678/rest/oauth2-credential/callback`.

---

## How to test

**On demand from Discord** (the real trigger):

| Command | Expected |
|---|---|
| `/help` | Usage message, instantly |
| `/cv file:<cv.pdf>` | "CV saved for … N skills/tools, M experiences" (a non-PDF → "attach a PDF") |
| `/job url:<offer link>` | Score /10, ✅ found, ❔ missing, one question |
| `/job text:<pasted offer>` | Same, without fetching the page |
| `/job url:not-a-link` | Usage message (input validation) |
| `/answer text:<your answer>` | About 1 min: CV as PDF + links to the letter, cheat sheet and Drive folder |
| `/answer` with no job in progress | "I have no job offer in progress" |
| `/job url:https://www.jobteaser.com/...` (JavaScript page) | "I couldn't read that page… use `/job text:`" |

**Saved test payloads (no Discord needed):** the *Start* node of the Analyzer and of the Generator has a **pinned test payload** (a real offer, a real answer). Open the workflow → *Execute workflow* to run it step by step. The last node (the Discord reply) needs a real interaction token, so it fails in this mode: that is expected. The same payloads are in [`tests/payloads/`](tests/payloads).

**Idempotency check:** send the same `/answer` twice → the second one is refused ("no job in progress"); confirming the same skill in two applications → still one row in `facts`.

**Failure test:** stop the AI key (wrong OpenRouter key in the credential) and send `/job` → the user gets a friendly message and the admin channel gets an alert with the workflow name, the failed node and the execution URL.

---

## Design choices
- **Slash commands + webhook**, not a message trigger: reading messages needs a permanent Gateway connection; interactions are plain signed HTTP POSTs and arrive already structured (file, url, text).
- **Answer fast, finish later:** the deferred response is the only way to run minute-long AI work behind Discord's 3-second limit.
- **AI reads, code decides:** the AI turns messy text (CV, offer, answer) into JSON; Code nodes compare, score and format. Deterministic, free and explainable.
- **LLM Chains, not an AI Agent:** the steps are fixed; a chain with a Structured Output Parser gives typed JSON, an agent would be slower, costlier and less predictable.
- **Fill a template, don't generate a CV:** the AI writes only 5 fields of the real CV, so layout and dates can't break.
- **Four guards against invented facts:** 5 fields only; known gaps and "requirements not on the CV" listed as *never claim*; prompts forbid new skills, numbers and motivations; `[add your detail]` instead of invention in the cheat sheet.
- **Postgres** for the project data: unique keys and upserts make every write idempotent.

## Robustness and error handling
1. **Retries:** every external call (HTTP, OpenRouter, Google, Postgres) retries 3 times with a wait.
2. **Fallbacks for expected problems:** invalid `/job` input, page blocked, no CV, not a PDF, no job in progress, AI output still invalid after retries (friendly message, fallback question, or the raw answer saved).
3. **Error workflow:** linked in the settings of Main, Analyzer and Generator. Alerts the admin channel with the workflow name, failed node, error and **execution URL**, and tells the user through the `runs` table. A sub-workflow failure produces one alert, not two.

## Versioning workflow
Workflows are edited in n8n, then exported to the repo:
```bash
./scripts/export.sh     # n8n export:workflow --all --separate → ./workflows/*.json
git diff --stat && git commit -am "…"
```
On another machine, `./scripts/import.sh` loads the same versions. No credential or token is ever exported or committed (`.env` and `credentials/*.local.json` are gitignored).

## Project structure
```
docker-compose.yml        n8n + Postgres + Cloudflare tunnel, pinned versions, named volumes, healthchecks
.env.example              every variable, no values
db/init/                  creates the project database and its 4 tables (first start only)
workflows/                the 5 n8n workflows (exported JSON, same version as the demo)
credentials/stubs.json    credential placeholders (names and ids only)
scripts/                  setup.sh, import.sh, export.sh, tunnel-url.sh
tests/payloads/           sample inputs for the sub-workflows
docs/                     scoping deliverable, final build notes, screenshots
```

## Troubleshooting
| Symptom | Fix |
|---|---|
| Discord: "The application did not respond" | `docker compose ps` (all healthy?), `./scripts/tunnel-url.sh` and update the portal if the URL changed |
| Discord refuses the endpoint URL | Wrong `DISCORD_PUBLIC_KEY`, or Main not active |
| `Cannot find module 'crypto'` in Verify & Parse | `NODE_FUNCTION_ALLOW_BUILTIN=crypto` missing in the n8n service |
| Credentials unreadable after a reinstall | `N8N_ENCRYPTION_KEY` changed: put the old one back |
| Want a clean database | `docker compose down -v` (**deletes all data**) then `./scripts/setup.sh` |
