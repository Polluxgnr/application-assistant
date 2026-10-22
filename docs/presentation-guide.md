# Application Assistant: final notes and presentation guide

*Pollux Gronier · No-code software development · 22 October 2026*
*Repo: github.com/Polluxgnr/application-assistant (private) · tag `v1.0` = the demo version*

**How the session works:** the examiner reads his checklist (20 points) line by line, asks me to **show** each item, and fires quick questions ("show the executions", "is this a sub-workflow?", "why a Code node and not AI?"). This guide follows **his order**: for each line, *what to show*, *where to click*, *what to say*.

**Three rules:** stay under 7 minutes in total, pitch included (pitch ≤ 2 min) · **never** open `.env` or a credential on screen (−2) · if something fails live, explain the error path: that's also a checklist line.

---

## 0. Before the session (15 minutes before)

1. **Docker Desktop is open** (whale icon). In Git Bash, in `Documents\application-assistant`:
   ```bash
   docker compose up -d
   docker compose ps            # 3 services up, n8n and postgres "healthy"
   bash scripts/tunnel-url.sh   # public URL for Discord
   ```
2. If the URL changed: Discord Developer Portal → *n8n project* → General Information → **Interactions Endpoint URL** → paste → **Save** (Discord checks the signature).
3. **Warm-up:** `/help` in Discord. The first command after a start can miss Discord's 3-second limit; the second never does.
4. Tabs, in this order: **GitHub repo** · **n8n** (`localhost:5678`: Overview, then the 3 workflows) · **Discord #n8n** · **Docker Desktop → Containers** · this guide.
5. Ready to paste: a **new** data offer link (Welcome to the Jungle or Lever) + its text, a **true** answer, and the bad link `https://this-does-not-exist.invalid/job`.

---

## 1. Pitch (≤ 2 minutes)

> "Students rewrite their CV and cover letter by hand for every internship, or paste their CV, the offer and a prompt into ChatGPT each time, and it invents skills they don't have.
> Application Assistant is a Discord bot: `/cv` once, `/job` with any offer, the bot compares the offer with my CV and asks **one** question about what's missing, I `/answer`, and one minute later I get a tailored CV as a PDF, a cover letter and an interview cheat sheet. It remembers everything I confirm.
> It's 5 n8n workflows, self-hosted with Docker: n8n, Postgres, and a Cloudflare tunnel so Discord can reach my local webhook. Gemini does 6 AI steps, Google Docs holds my CV template, Postgres is the memory, and an error workflow watches everything."

```
Discord ──signed POST──► 1. Main ──/job──► 2. Analyzer ──no gaps──► 3. Generator
   ▲  "thinking…" < 3 s       │  ──/answer─────────────────────────────►   │
   └──── edit that message: reply, PDF, links ◄────────────────────────────┘
   uses: OpenRouter (Gemini) · Postgres (profiles, facts, sessions, runs) · Google Drive/Docs
   on failure: 4. Error Handler → admin alert + message to the user · once: 0. Setup
```
*On every arrow: one small object `user_id, app_id, token, url, text, answer`.*

---

## 2. The checklist, line by line

### Scoping & Design (2 pts)
| # | Criterion | Show | Say |
|---|---|---|---|
| 1 | Need in one sentence | README, top | "Students rewrite their CV and letter by hand for every offer, or paste everything into ChatGPT, which invents skills." |
| 2 | Trigger on demand + saved test payload | `/help` live. n8n → *2. Sub – Analyzer* → **Start** node → pinned data (📌); repo `tests/payloads/` | "The trigger is a slash command, fired whenever I want. Each sub-workflow also has a saved test payload pinned on its Start node, next to the real trigger." |
| 3 | Architecture diagram with data on arrows | README *Architecture* (diagram above) | "Signed POST in; one small object between workflows; replies are edits of the original message." |
| 4 | Diagram matches the build; level + cut line | *1. Main* canvas, same blocks | "Level 3. Cut line: cheat sheet, then letter, then the question. Nothing was cut." |

### Docker Self-Hosting (3 pts)
| # | Criterion | Show | Say |
|---|---|---|---|
| 5 | Compose: n8n + ≥1 service | `docker-compose.yml`; Docker Desktop → 3 containers | "n8n, Postgres for n8n and for my project data, and a Cloudflare tunnel." |
| 6 | Named volumes survive down/up | `volumes: pg_data, n8n_data`. If asked: `docker compose down` → `docker compose up -d` → workflows and data still there | "Data lives in named volumes, outside the containers." |
| 7 | Versions pinned | `n8nio/n8n:2.44.6`, `postgres:17.11-alpine`, `cloudflared:2026.10.2` | "No `:latest`: a fresh clone runs exactly what I tested." |
| 8 | `.env.example` committed, `.env` ignored, encryption key via env | GitHub: `.env.example`, `.gitignore`; compose: `N8N_ENCRYPTION_KEY: ${N8N_ENCRYPTION_KEY}` | "Every setting and secret comes from `.env`, never committed. Even ids and the Discord public key are env variables." |
| 9 | Fresh clone starts cleanly, DB healthcheck | compose `healthcheck` (Postgres also checks my tables exist) + `depends_on: service_healthy`; `scripts/setup.sh` | "n8n waits for a healthy Postgres. `setup.sh` goes from clone to running." |

### Git & Versioning (2.5 pts)
| # | Criterion | Show | Say |
|---|---|---|---|
| 10 | Workflows exported as JSON, same version | `workflows/`; `scripts/export.sh` (`n8n export:workflow`); tag `v1.0` | "I export from n8n after every change; the tag is the demo version." |
| 11 | No secrets in history; `.gitignore` | `.gitignore`; `credentials/stubs.json` (names only) | "Secrets live in `.env` and are loaded by `import.sh`. I scanned the whole history for tokens and keys." |
| 12 | ≥10 commits over ≥2 days | GitHub → Commits (~30) | "About 30 commits with clear messages, but honestly all from one day: I built first on n8n Cloud and moved to Git when I self-hosted." *(likely −0.5)* |
| 13 | Feature branch merged by PR, or `v1.0` | GitHub → Pull requests (merged `feature/self-hosted`) + Tags → `v1.0` | "Both." |

### Core n8n Requirements (4 pts)
| # | Criterion | Show (node) | Say |
|---|---|---|---|
| 14 | Message trigger | Main → **Discord Interaction** (Webhook) | "Discord slash commands; a message trigger needs a permanent Gateway connection n8n can't hold, slash commands are signed HTTP POSTs." |
| 15 | API with stored credential | **Reply:** nodes (Discord), **Gemini ·** nodes (OpenRouter), Drive/Docs nodes (Google OAuth), Postgres nodes | "Four services, all through stored n8n credentials." |
| 16 | If or Set shaping data | **Valid /job input?** (If), **Payload: Job** (Set), Analyzer **Question (with fallback)** (Set) | "Set nodes build the exact payload for the sub-workflows; If nodes validate and branch." |
| 17 | Code node with real logic | Analyzer → **Code: Gap Analysis** (open it) | "Requirements vs my CV: lower-case, no accents, whole words, plus the synonyms the AI suggested; score out of 10. And **Verify & Parse** checks Discord's Ed25519 signature." |
| 18 | Switch with ≥2 reachable paths | Main → **Command Router** (/cv, /job, /answer), **Interaction Type** | "Three paths, all used in the demo." |
| 19 | Database | Postgres nodes; run *5. Inspect – Project database* | "Postgres, 4 tables: profiles, facts, sessions, runs." |
| 20 | AI node with written prompt | Generator → **AI: Tailor CV** → prompt | "6 LLM chains with written prompts; 5 with a structured output parser." |
| 21 | Sub-workflow with defined inputs | Main → **Run Analyzer** (mapped inputs); Analyzer → **Start** | "Declared inputs `user_id, app_id, token, url, text, answer`, mapped explicitly by Main." |

### Robustness & Error Handling (3.5 pts)
| # | Criterion | Show | Say |
|---|---|---|---|
| 22 | Retry on every external call | Any HTTP / AI / Postgres / Google node → **Settings** → Retry On Fail, 3 tries, 2–3 s | "Every external call retries 3 times." |
| 23 | Error workflow linked; alert with name + URL | Main → ⋯ → Settings → Error workflow = *4. Error Handler*; alert in Discord #n8n ("3. Sub – Generator failed · Node: Docs: Fill CV · Execution: http://localhost:5678/…") | "Workflow name, failed node, error and execution URL; the user is warned through the `runs` table; one alert per failure." |
| 24 | Invalid input → usage | `/job url:hello` → usage message | "Validated right after the router." |
| 25 | Idempotent | Send the same `/answer` twice → "no job in progress"; *Inspect* → no duplicate in `facts` | "Unique keys and upserts in Postgres, each answer remembered, a finished job can't be redone." |
| 26 | AI output validated + fallback | **AI:** node → structured output parser + red **error** output → friendly reply / fallback question / raw answer saved | "If the JSON is still invalid after retries, the error output takes over instead of crashing." |
| 27 | Failure triggered live | `/job url:https://this-does-not-exist.invalid/job` → 3 retries → "I couldn't read that page…" | "Error path, live." |

### Live Demo (3 pts)
| # | Criterion | Do | Say |
|---|---|---|---|
| 28 | Full round trip, first attempt | `/job url:<offer>` → score + question → `/answer text:<true answer>` → PDF + links in #n8n (≈ 1 min) | "Message in, answer back in the same channel." |
| 29 | Second scenario | `/job text:<pasted offer>` or `/cv` | "Another router branch." |
| 30 | State across runs | *Inspect*: `sessions` = waiting after /job, done after /answer; new rows in `facts` | "`/job` writes the session, `/answer` reads it: two separate executions." |
| 31 | Readable reply | The Discord messages, the PDF | "Formatted text, links, a PDF; never raw JSON." |
| 32 | Executions green, failures explained | n8n → **Executions** | "Each command = one Main run plus one sub-workflow run. The few red ones are my failure tests and two real bugs I found and fixed today." |

### Documentation & Q&A (2 pts)
| # | Show / do |
|---|---|
| 33 | README: setup from clone, env table, credentials, tests, test results, screenshots |
| 34–35 | Section 4 |
| 36 | Pitch ≤ 2 min, short answers |

### Penalties
| Penalty | How it's avoided |
|---|---|
| Visible secret (−2) | Never open `.env` or a credential; show `.env.example` and `credentials/stubs.json` |
| Can't explain a node (−5) | Section 3 |
| Demo ≠ committed JSON (−1) | `export.sh` then commit; tag `v1.0` |
| Over 7 min (−1) | Pitch ≤ 2 min |
| Not working (−5) | Section 0; backup: today's test runs in Executions and Discord |

---

## 3. Every node, what it does and why

### 1. Main: Discord Router
| Node | What / why |
|---|---|
| Discord Interaction (Webhook) | Every slash command arrives here; the raw body is kept for the signature check. |
| Verify & Parse (Code) | Ed25519 check with the app's public key (from `.env`); flattens the payload. |
| Signature valid? (If) | No → **Reject 401**. |
| Interaction Type (Switch) | Ping → **PONG**; command → continue; anything else → help. |
| Known command? (If) | `/help` or unknown → **Help / Usage**, instant. |
| Defer: Thinking… (Respond) | Answers within 3 s; the slow work continues after. |
| DB: Log Run (Postgres) | Execution id → user + reply token, for the error workflow. |
| Command Router (Switch) | `/cv`, `/job`, `/answer`. |
| /cv path | Is a PDF? → Download CV PDF → Extract PDF Text → **AI: Parse Base CV** (JSON) → **DB: Save Profile** (upsert) → Reply. AI failure → *Reply: CV Not Readable*. |
| /job path | **Valid /job input?** (bad → *Reply: Job Usage*) → Payload: Job (Set) → **Run Analyzer** → No gaps? → Run Generator directly. |
| /answer path | Payload: Answer (Set) → **Run Generator**. |

### 2. Analyzer (sub-workflow)
| Node | What / why |
|---|---|
| Start | Declared inputs + pinned test payload. |
| DB: My Facts → Load Profile (Code) | CV, parsed profile and confirmed skills from Postgres. |
| Has CV? / Offer text pasted? | No CV → "send your CV first"; pasted text skips the download. |
| Fetch Offer Page (HTTP) → Clean Page to Text (Code) → Readable? | Reads the schema.org **JobPosting** block job boards embed; blocked → "paste the text". |
| AI: Extract Offer (+ JSON schema) | Company, role, language, 6–12 requirements, and for each the **aliases** a CV would contain (synonyms, methods, tools). Error → "try /job text:". |
| **Code: Gap Analysis** | For each requirement: found as whole words, or one of its aliases is. Score = 10 × found / total. First 3 missing asked, all saved. |
| Missing skills? → AI: Draft Question → Question (with fallback) | One friendly question in the offer's language; template question if the AI fails. |
| DB: Session = waiting (upsert) → Reply: Ask Question | Saves the job, replies. Nothing missing → DB: Session = ready → back to Main. |

### 3. Generator (sub-workflow)
| Node | What / why |
|---|---|
| DB: My Session → Load Session → Job in progress? | No session or already `done` → "no job in progress". |
| Answer given? → **DB: Remember Answer** → **New answer?** | The raw answer is stored with a unique key: the same answer twice is not processed twice. |
| AI: Extract New Skills → Split Facts → DB: Save New Facts | Skills / experiences / gaps, saved forever, no duplicates. AI failure → raw answer kept. |
| DB: All My Facts → Build Profile (Code) | CV + confirmed facts + known gaps + "never claim" list. |
| AI: Tailor CV | Writes only 5 fields of my real CV template; each bullet stays on its own job. |
| AI: Cover Letter & Cheat Sheet | "Strict facts" rule; in the offer's language; `[add your detail]` instead of inventing. Failure → *Reply: Writing Failed*. |
| Drive / Docs nodes | New folder → copy template → fill 5 placeholders → write the 2 docs. |
| DB: Session = done → Drive: Export CV PDF → Reply: Send Documents | Closes the job; PDF + links in Discord. |

### 4. Error Handler · 0. Setup · 5. Inspect
Error Trigger → Format Error (name, node, error, execution URL) → Not alerted yet? (one alert per failure) → Discord: Alert Me → DB: Find Run → User to notify? → Discord: Tell User (never fails the run if the interaction expired). Setup registers the 4 commands. Inspect shows the 4 tables.

---

## 4. Quick questions (2 sentences, then stop)

**Why a Code node instead of AI for the gaps?** Comparing two lists is deterministic: free, instant, same result every time, and I can explain every decision. The AI only reads messy text, and suggests synonyms that the code then checks.

**Do you have sub-workflows?** Yes: Analyzer and Generator, Execute Workflow with defined inputs; each testable alone with its pinned payload; the Generator is called from two places.

**Show me the executions.** Executions tab: each command is a Main run plus a sub-workflow run; I can open one and follow the data node by node.

**Why LLM Chains, not an AI Agent?** Fixed steps in a fixed order; a chain with an output parser gives typed JSON. An agent picks its own steps: slower, costlier, less predictable.

**How do you beat the 3-second limit?** "Thinking…" immediately, then edit that message with the interaction token (valid 15 min).

**How do you know only Discord calls you?** Ed25519 signature in a Code node; 401 otherwise.

**Why Postgres?** Real relational DB in the same Docker stack; unique keys and upserts make it idempotent; schema versioned in `db/init`.

**Why a tunnel?** Discord needs public HTTPS; the quick tunnel gives it without an account. Limit: new URL when it restarts.

**How do you stop the AI from inventing?** Only 5 template fields; known gaps and unconfirmed requirements marked "never claim"; prompts forbid new skills, numbers and motivations; my tests caught invented skills and an invented motivation, both fixed.

**What did testing find?** Today alone: a usage message that crashed (a line break in an expression), the Google Docs API not enabled (the error workflow caught it), keyword matching that gave a data-science offer 1/10 (fixed with AI synonyms checked by code: 9/10), and near-duplicate facts on a repeated answer (fixed by remembering answers).

**What if it fails?** 3 retries; known problems get a friendly reply; anything else → error workflow → me + the user.

**Limits?** Built for one person (my CV template); the bot trusts my answers; one job at a time; the tunnel URL changes on restart; a cold start can miss the first 3-second window.

---

## 5. Test results (22 October 2026, local stack, through Discord)
| Offer / case | Result |
|---|---|
| Qonto, Data Engineering Intern (Lever) | 7/10 → CV PDF, letter, cheat sheet |
| Ipsos, Data Scientist intern (WTTJ) | 9/10; honest gap (no unsupervised learning) stated in the letter, not claimed in the CV |
| Papernest, Data Analyst (French, pasted text) | 9/10; question and letter in French |
| Batch, Data Analyst (French) | 7/10; date and addressee in French |
| `/job url:hello` | usage message |
| unreachable link | 3 retries → "paste the text" |
| same `/answer` twice | "no job in progress", no duplicate |
| Google Docs API disabled (real) | user told + one admin alert with node and execution URL |

---

## 6. Commands
```bash
docker compose up -d            # start (data kept in named volumes)
docker compose ps               # all healthy?
bash scripts/tunnel-url.sh      # Discord endpoint URL
bash scripts/export.sh          # n8n → workflows/*.json (before committing)
bash scripts/import.sh          # workflows/*.json (+ .env secrets, once) → n8n
docker compose down             # stop, keeps data
```
