# Application Assistant: final notes and presentation guide

*Pollux Gronier · No-code software development · 22 October 2026*
*Repo: github.com/Polluxgnr/application-assistant (private) · tag `v1.0`*

**How the presentation works:** the examiner goes through his checklist (20 points), asks me to **show** each item, and asks quick questions. This guide follows his checklist **in his order**: for each line, what to show, where to click, and the one or two sentences to say.

**Golden rules:** stay under 7 minutes in total, and present the project itself in 2 minutes or less · never open `.env` or a credential on screen (−2 points per visible secret) · if something fails, say what the error path does: that's also a checklist item.

---

## 0. Before the session (15 minutes before)

1. **Docker Desktop is running** (whale icon in the taskbar). Then in Git Bash, in the project folder:
   ```bash
   docker compose up -d
   bash scripts/tunnel-url.sh
   ```
2. If the tunnel URL changed: Discord Developer Portal → *n8n project* → **General Information** → **Interactions Endpoint URL** → paste the URL → **Save** (Discord verifies the signature when you save).
3. In Discord: `/help` (instant answer = everything is connected).
4. Open these tabs: **VS Code / GitHub repo** · **http://localhost:5678** (Overview, Executions) · **Discord #n8n** · **Docker Desktop** (Containers) · this guide.
5. Prepare: a new job link (Welcome to the Jungle or Lever) + its text copied, a **true** answer to paste, and a bad link for the failure test (`/job url:https://this-does-not-exist.invalid/job`).

---

## 1. The project in 2 minutes (pitch)

> "Students rewrite their CV and cover letter by hand for every internship, or paste their CV, the offer and a prompt into ChatGPT each time, and it invents skills they don't have.
> Application Assistant is a Discord bot. `/cv` once, `/job` with a link, the bot compares the offer with my CV and asks **one** question about what's missing, I `/answer`, and one minute later I get a tailored CV as a PDF, a cover letter and an interview cheat sheet. It remembers my answers.
> Technically: 5 n8n workflows, self-hosted with Docker (n8n, Postgres and a Cloudflare tunnel so Discord can reach my local webhook), Gemini through OpenRouter for the 6 AI steps, Google Docs for the CV template, Postgres for memory, and an error workflow."

**Architecture in one picture** (README, top):
```
Discord ──signed POST──► 1. Main ──/job──► 2. Analyzer ──no gaps──► 3. Generator
   ▲  answer < 3 s           │  ──/answer──────────────────────────────►   │
   └──── edit the "thinking…" message (reply / PDF) ◄──────────────────────┘
   uses: OpenRouter (Gemini) · Postgres (profiles, facts, sessions, runs) · Google Drive/Docs
   on failure: 4. Error Handler → admin alert + message to the user · once: 0. Setup
```

---

## 2. The checklist, line by line

Legend: **Show** = what to open · **Say** = what to answer.

### Scoping & Design (2 pts)

| # | Criterion | Show | Say |
|---|---|---|---|
| 1 | Need in one sentence | README, first lines | "Students rewrite CV and letter by hand for every offer, or paste everything into ChatGPT each time." |
| 2 | Trigger fireable on demand, saved test payload | Discord `/help` live. Then n8n → *2. Sub – Analyzer* → **Start** node → pinned data (the pin icon); `tests/payloads/` in the repo | "The trigger is a slash command, I fire it whenever I want. Each sub-workflow also has a saved test payload pinned on its Start node, next to the real trigger." |
| 3 | Architecture diagram, data on each arrow | README *Architecture* (and the diagram above) | "On each arrow: a signed POST, then one small object `user_id, token, url, text, answer`; replies are edits of the original message." |
| 4 | Diagram matches the build; level and cut line | Open *1. Main*: same blocks as the diagram | "Level 3. Cut line: cheat sheet first, then letter, then the question. Nothing had to be cut." |

### Docker Self-Hosting (3 pts)

| # | Criterion | Show | Say |
|---|---|---|---|
| 5 | docker-compose: n8n + ≥1 other service | `docker-compose.yml`; Docker Desktop → Containers (3 green) | "n8n, Postgres for n8n and for my project data, and a Cloudflare tunnel." |
| 6 | Named volumes survive down/up | `volumes: pg_data, n8n_data`. Live if asked: `docker compose down` then `docker compose up -d`, refresh n8n: workflows still there | "Named volumes: data lives outside the containers." |
| 7 | Versions pinned | `n8nio/n8n:2.44.6`, `postgres:17.11-alpine`, `cloudflared:2026.10.2` | "No `:latest`, so a fresh clone runs exactly what I tested." |
| 8 | `.env.example` committed, `.env` ignored, encryption key via env | `.env.example` and `.gitignore` in GitHub; `N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}` in compose | "All config and secrets come from `.env`, which is never committed. Even the Discord ids and Google file ids are env variables, nothing is hard-coded." |
| 9 | Fresh clone starts cleanly, DB healthcheck | `healthcheck:` on postgres (also checks my tables exist) and n8n; `depends_on: condition: service_healthy`; `scripts/setup.sh` | "n8n waits for Postgres to be healthy. `setup.sh` goes from clone to running: creates `.env`, starts, imports credentials and workflows." |

### Git & Versioning (2.5 pts)

| # | Criterion | Show | Say |
|---|---|---|---|
| 10 | Workflows exported as JSON, same version as the demo | `workflows/` folder; `scripts/export.sh` (`n8n export:workflow`) | "I export after each change, so the repo always has the demo version." |
| 11 | No secrets in Git history; `.gitignore` covers `.env` and volumes | `.gitignore`; `credentials/stubs.json` (names only) | "Credentials are placeholders; the real values are typed into `.env` and loaded by `import.sh`. I scanned the history for tokens and keys." |
| 12 | ≥10 commits over ≥2 days | GitHub → Commits | "About 20 commits with clear messages. Honestly, they're all from one day, because I first built on n8n Cloud and moved to Git when I self-hosted." (likely −0.5) |
| 13 | Feature branch merged through a PR, or tag `v1.0` | GitHub → Pull requests (merged `feature/self-hosted`) and Tags → `v1.0` | "Both: the self-hosted version was a feature branch, merged through a PR, and tagged v1.0." |

### Core n8n Requirements (4 pts)

| # | Criterion | Show (node) | Say |
|---|---|---|---|
| 14 | Message trigger (Discord) | Main → **Discord Interaction** (Webhook) | "Discord slash commands. A Discord *message* trigger needs a permanent connection that n8n can't hold; slash commands are signed HTTP POSTs, so a webhook is enough." |
| 15 | API connection with a stored credential | Any **Reply:** node (Discord API), **Gemini ·** nodes (OpenRouter credential), **Drive/Docs** nodes (Google OAuth) | "Discord API, OpenRouter and Google, all through stored n8n credentials." |
| 16 | If or Set shaping data | Main → **Valid /job input?** (If), **Payload: Job** (Set); Analyzer → **Question (with fallback)** (Set) | "The Set nodes build the exact payload for the sub-workflows; the If nodes validate input and branch." |
| 17 | Code node with real logic | Analyzer → **Code: Gap Analysis** (open it) | "Compares the offer's requirements with my CV: lower-case, no accents, whole words only, then a score out of 10. Also **Verify & Parse** checks Discord's Ed25519 signature." |
| 18 | Switch with ≥2 paths, both reachable | Main → **Command Router** (/cv, /job, /answer) and **Interaction Type** | "Three paths, all used in the demo." |
| 19 | Database (not a Sheet) | Postgres nodes (e.g. **DB: Save New Facts**); run *5. Inspect – Project database* | "Postgres, 4 tables: profiles, facts, sessions, runs." |
| 20 | AI node with a written prompt | Generator → **AI: Tailor CV** (open the prompt) | "6 LLM chains with written prompts, 5 with a structured output parser." |
| 21 | Sub-workflow with defined inputs | Main → **Run Analyzer** (inputs mapped); Analyzer → **Start** (declared inputs) | "The sub-workflow declares `user_id, app_id, token, url, text, answer`, and Main maps them explicitly." |

### Robustness & Error Handling (3.5 pts)

| # | Criterion | Show | Say |
|---|---|---|---|
| 22 | Retry on every external call (HTTP, AI, DB) | Open any HTTP, AI or Postgres node → **Settings** → Retry On Fail, max tries 3, wait 2–3 s | "Every call to Discord, OpenRouter, Google and Postgres retries 3 times." |
| 23 | Error workflow linked, alert with name + execution URL | Main → ⋯ → **Settings** → Error workflow = *4. Error Handler*; Discord admin channel alert | "It alerts my admin channel with the workflow name, the failed node, the error and the execution URL, and tells the user through the `runs` table." |
| 24 | Invalid input → usage message | Discord: `/job url:hello` → usage message; `/blabla` → help | "Validation is the first thing after the router." |
| 25 | Idempotent | `/answer` twice → the second says "no job in progress"; *Inspect* → `facts` has no duplicates | "Postgres unique keys and upserts: the same fact or the same run is never saved twice, and a finished job can't be regenerated." |
| 26 | AI output validated, with a fallback path | Any **AI:** node: structured output parser + red **error output** to a friendly reply | "If the JSON is still invalid after the retries, the error output sends a friendly message, a fallback question, or keeps the raw answer." |
| 27 | Failure triggered live, error path works | Discord: `/job url:https://this-does-not-exist.invalid/job` → "I couldn't read that page…" | "The HTTP request fails 3 times, then the error output answers the user instead of crashing." |

### Live Demo (3 pts)

| # | Criterion | Do | Say |
|---|---|---|---|
| 28 | Full round trip, first attempt | `/job url:<offer>` → score + question → `/answer text:<true answer>` → PDF + links in the same channel | "Message in, answer back in the same channel." |
| 29 | Second scenario | `/cv` or `/help`, or `/job text:<pasted offer>` | "Another branch of the router." |
| 30 | State across runs | *Inspect* → `sessions` (`waiting` after /job, `done` after /answer) and new rows in `facts` | "`/job` writes the session, `/answer` reads it back: two different executions." |
| 31 | Reply readable, no raw JSON | The Discord messages and the PDF | "Formatted text, emojis, links, a PDF." |
| 32 | Executions tab green, failures explained | n8n → **Executions** | "The red ones are the failure tests I just did; each one has an alert." |

### Documentation & Q&A (2 pts)

| # | Criterion | Show / do |
|---|---|---|
| 33 | README: setup, env, testing, screenshots | GitHub README |
| 34–35 | Two questions answered accurately | Section 4 below |
| 36 | Timing kept | 2 min pitch, then checklist |

### Penalties to avoid
| Penalty | How I avoid it |
|---|---|
| Secret visible (−2) | Never open `.env` or a credential; only `.env.example` and `credentials/stubs.json` |
| Can't explain a node (−5) | Section 3: every node, what and why |
| Demo differs from the JSON in the repo (−1) | `scripts/export.sh` before the last commit; tag `v1.0` = demo version |
| Over 7 minutes (−1) | Pitch ≤ 2 min, short answers |
| Not working (−5) | Section 0 checklist; backup: executions from the dry run |

---

## 3. Every workflow, node by node (for "explain this node")

### 1. Main: Discord Router
| Node | What / why |
|---|---|
| Discord Interaction (Webhook) | Receives every slash command. Keeps the raw body, needed for the signature check. |
| Verify & Parse (Code) | Checks the Ed25519 signature with the app's public key (from `.env`), flattens the payload into `user_id, command, url, text, token, attachment`. |
| Signature valid? (If) | Invalid → **Reject 401**. Discord tests this when you save the endpoint. |
| Interaction Type (Switch) | Ping → **PONG**; command → continue; anything else → help message. |
| Known command? (If) | `/help` or unknown → **Help / Usage** (instant). |
| Defer: Thinking… (Respond) | Answers within 3 s with "thinking…" (deferred response). The AI work continues after. |
| DB: Log Run (Postgres) | Saves execution id → user and reply token, for the error workflow. |
| Command Router (Switch) | `/cv`, `/job`, `/answer`. |
| /cv: Is a PDF? → Download CV PDF → Extract PDF Text → AI: Parse Base CV → DB: Save Profile → Reply: CV Saved | Reads the CV once and upserts it in `profiles`. AI failure → *Reply: CV Not Readable*. |
| /job: Valid /job input? → Payload: Job (Set) → Run Analyzer → No gaps? → Run Generator | Invalid → *Reply: Job Usage*. No missing skill → documents generated straight away. |
| /answer: Payload: Answer → Run Generator | |

### 2. Analyzer (sub-workflow)
| Node | What / why |
|---|---|
| Start (declared inputs, pinned test payload) | The contract with Main. |
| DB: My Facts → Load Profile (Code) | Reads the CV and confirmed skills from Postgres. |
| Has CV? / Offer text pasted? (If) | No CV → "send your CV first"; pasted text → skip the download. |
| Fetch Offer Page (HTTP) → Clean Page to Text (Code) → Readable? | Reads the schema.org **JobPosting** block job boards embed; blocked page → "paste the text". |
| AI: Extract Offer (+ JSON schema) | Company, role, language, 6–12 requirements. Error → "try /job text:". |
| **Code: Gap Analysis** | Requirements vs CV, whole words, score /10; first 3 missing asked, all saved. |
| Missing skills? → AI: Draft Question → Question (with fallback) | One friendly question; if the AI fails, a template question. |
| DB: Session = waiting (upsert) → Reply: Ask Question | Saves the job in progress, replies in Discord. |

### 3. Generator (sub-workflow)
| Node | What / why |
|---|---|
| DB: My Session → Load Session → Job in progress? | No session or already `done` → "send a job first". |
| AI: Extract New Skills → Split Facts → DB: Save New Facts | Learns skills / experiences / gaps; unique key = no duplicates. AI failure → raw answer saved. |
| DB: All My Facts → Build Profile (Code) | CV + confirmed facts + known gaps + "never claim these". |
| AI: Tailor CV | Writes only 5 fields of my real CV template. |
| AI: Cover Letter & Cheat Sheet | Letter + interview prep, "strict facts" rule. Failure → *Reply: Writing Failed*. |
| Drive / Docs nodes | New folder, copy the template, fill the 5 placeholders, write the 2 docs. |
| DB: Session = done → Drive: Export CV PDF → Reply: Send Documents | Closes the job, sends the PDF and links. |

### 4. Error Handler
Error Trigger → Format Error (Code: workflow, node, error, execution URL) → Not alerted yet? (skips the duplicate alert when a sub-workflow already alerted) → Discord: Alert Me → DB: Find Run → User to notify? → Discord: Tell User.

### 0. Setup / 5. Inspect
Setup registers the 4 slash commands (run once). Inspect shows the 4 tables for the demo.

---

## 4. Quick questions (answer in 2 sentences, then stop)

**Why a Code node instead of an AI node for the gap analysis?** Comparing two lists is deterministic: code is free, instant, gives the same answer every time and I can explain every decision. The AI is used where text is messy: reading the CV, the offer and my answers.

**Do you have sub-workflows? Why?** Yes, Analyzer and Generator, called with Execute Workflow and defined inputs. Each has one job, can be tested alone with its pinned payload, and the Generator is reused from two places.

**Why LLM Chains and not an AI Agent?** My steps are always the same and in the same order; a chain with a structured output parser gives typed JSON. An agent chooses its own steps: slower, costlier, less predictable.

**Why slash commands and a webhook?** A message trigger needs a permanent Gateway connection; interactions are signed HTTP POSTs that arrive already structured.

**How do you beat Discord's 3-second limit?** Answer "thinking…" immediately, keep working, then edit that message with the interaction token (valid 15 minutes).

**How do you know only Discord calls you?** Ed25519 signature check in a Code node, 401 otherwise.

**Why Postgres?** Real relational DB in the same Docker stack; unique keys and upserts make it idempotent; schema versioned in `db/init`.

**Why a tunnel?** Discord needs a public HTTPS URL; the Cloudflare quick tunnel gives one to my local n8n without an account. Limit: the URL changes when the tunnel restarts.

**How do you stop the AI from inventing?** Only 5 template fields are generated; known gaps and unconfirmed requirements are listed as "never claim"; prompts forbid new skills, numbers and motivations; tests caught invented skills and I fixed it.

**What happens when something fails?** Retry 3 times; known problems get a friendly message; anything else goes to the error workflow, which alerts me and tells the user.

**What did your tests find?** Ten problems: a crash on links, invented skills, "Git" matched inside "github.com", the template saved as my CV, a scrambled PDF, an invented motivation, double alerts… All fixed.

**Show me the executions.** n8n → Executions: each slash command = one Main run plus one sub-workflow run; red ones are deliberate failure tests.

**Limits?** Built for one person (my CV template), no synonym matching, one job at a time, the bot trusts my answers, the tunnel URL changes on restart.

---

## 5. Useful commands
```bash
docker compose up -d            # start (data kept in named volumes)
docker compose ps               # all healthy?
bash scripts/tunnel-url.sh      # public URL for the Discord portal
bash scripts/export.sh          # n8n → workflows/*.json (before committing)
bash scripts/import.sh          # workflows/*.json + .env secrets → n8n
docker compose down             # stop (keeps data)
```
