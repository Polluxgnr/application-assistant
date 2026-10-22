# Application Assistant: presentation guide

*Pollux Gronier · 22 October 2026 · repo `Polluxgnr/application-assistant`, tag `v1.0`*

The examiner goes through his checklist (20 pts) line by line: he ticks what he sees, asks me to show what he doesn't, and asks quick questions. My job: **show fast, answer in two sentences.** 7 minutes max, pitch ≤ 2 minutes.

---

## 1. What I need to know cold

**How it works (30 seconds):** I type a slash command in Discord → Discord sends a signed HTTP POST through a Cloudflare tunnel to my n8n, running in Docker on my laptop → *Main* checks the signature, answers "thinking…" within 3 s, then routes the command → the *Analyzer* reads the offer and asks one question, the *Generator* writes the documents → the result replaces "thinking…" in Discord.

**Do I need to host it?** No server: everything runs on my laptop with Docker (n8n + Postgres + tunnel). The laptop must be on, with Docker Desktop open, during the demo. The tunnel gives Discord a public HTTPS URL without opening any port.

**What changed since the first version (n8n Cloud):**
| Before | Now | Why |
|---|---|---|
| n8n Cloud | Self-hosted with Docker Compose | Checklist: self-hosting, versions, volumes, healthcheck |
| n8n Data Tables | Postgres (4 tables, unique keys) | A real database; no duplicate rows |
| Ids and keys inside nodes | Everything in `.env` | No secret in the repo |
| Some calls without retry | Retry on every HTTP, AI, Google and DB call | Robustness |
| AI failure = crash | Red error output → friendly message | "AI output validated with a fallback" |
| Exact keyword match (Ipsos: 1/10) | AI suggests synonyms, Code decides (9/10) | Fairer score, still explainable |
| Workflows only | Git repo, PR, tag v1.0, README | Versioning |

**APIs used:** Discord (slash commands + editing the reply), OpenRouter → Gemini 3.5 Flash (6 LLM calls), Google Drive + Google Docs (template, PDF), the job page itself (HTTP GET). Database: Postgres.

**Memory:**
- *Long-term* = `facts` (skills, experiences, gaps I confirmed, kept forever) + `profiles` (my CV).
- *Short-term* = `sessions`: the job in progress between `/job` and `/answer`, which are two separate executions.
- *Same request twice?* Writes are idempotent: same answer → not processed again, same fact → not saved twice, finished job → "no job in progress". A repeated `/job` on the same link calls the AI again (no cache): an honest limit, and a possible next step.

**If the user makes a mistake:** Discord only offers my 4 commands, so typos can't reach n8n. Wrong usage gets an explanation: `/job` with a bad link or short text → usage message; `/cv` with a non-PDF → "attach a PDF"; `/job` before `/cv` → "send your CV first"; `/answer` with no job → "send a job first"; blocked page → "paste the text"; anything else → `/help`.

**Where are my nodes** (n8n → Overview → Workflows):
- *1. Main – Discord Router*: green = Discord in (signature, "thinking…"), grey = **Command Router**, blue = `/cv`, purple = `/job` (**Valid /job input?**, **Run Analyzer**), red = `/answer`.
- *2. Sub – Analyzer*: one line, left to right: Start (pinned test) → DB → **Fetch Offer Page** → **AI: Extract Offer** → **Code: Gap Analysis** → **AI: Draft Question** → DB session → reply.
- *3. Sub – Generator*: top = learn (**DB: Remember Answer**, **AI: Extract New Skills**), right = write (**AI: Tailor CV**, **AI: Cover Letter**), bottom = publish (Drive, Docs, PDF, reply).
- *4. Error Handler*: Error Trigger → Format Error → alert → find user → tell user.

---

## 2. Before the session (15 min before)

```bash
cd ~/Documents/application-assistant
docker compose up -d && docker compose ps      # n8n + postgres "healthy"
bash scripts/tunnel-url.sh                     # if the URL changed → paste it in the Discord portal
```
Then `/help` in Discord (warm-up: the very first command after a start can be too slow for Discord).
Tabs open: **GitHub repo** · **n8n Overview** · **Discord #n8n** · **Docker Desktop** · this guide.
Ready to paste: a **new** data offer link + its text, a **true** answer, the bad link `https://this-does-not-exist.invalid/job`.
Never open `.env` or a credential (−2).

---

## 3. Full script (7 minutes)

**Trick:** fire `/job` in the first seconds, so the AI works while I talk. Fire `/answer` around 2:00, so the documents arrive while he checks Docker and Git.

**0:00 · Pitch (≤ 2 min)**, *Discord open*
> *(sends `/job url:<offer>`)* "While this runs: students rewrite their CV and letter for every internship, or paste everything into ChatGPT, which invents skills. My bot reads my CV once, compares it with any offer, asks me one question about what's missing, and writes a tailored CV, letter and cheat sheet.
> It's 5 n8n workflows, self-hosted in Docker: n8n, Postgres and a tunnel so Discord can reach my laptop. Main answers Discord in under 3 seconds, then two sub-workflows do the slow AI work. Level 3; my cut line was cheat sheet, then letter, then the question, and I didn't need it."
> *(the reply arrives)* "Here: a score out of 10, what I have, what's missing, and one question." *(sends `/answer text:<true answer>`)* "This takes about a minute."

**2:00 · Docker + Git** *(his checklist lines 5–13)*: open `docker-compose.yml`
> "Three services, pinned versions, named volumes, a healthcheck on Postgres; n8n waits for it. Secrets in `.env`, which is ignored; `.env.example` is committed. The workflows are exported as JSON, the self-hosted version went through a PR and is tagged v1.0. I tested a fresh clone: it starts, imports, and survives down/up."

**3:00 · Result** *(lines 28, 31)*: back to Discord, open the PDF and the letter
> "Same layout as my real CV: the AI only fills 5 fields, so it can't break dates. And the letter is honest about what I don't have."

**3:30 · Core nodes** *(lines 14–21)*: open *1. Main*, then *2. Analyzer*
> "Webhook trigger with a signature check in a Code node; this Switch routes the commands; Set nodes build the payload for the sub-workflows, which declare their inputs. Here's the main Code node: it compares the requirements with my CV, whole words plus synonyms the AI suggested. The AI reads, the code decides. Postgres stores everything."

**4:30 · Robustness** *(lines 22–27)*
> *(sends `/job url:hello`)* "Invalid input → usage message." *(sends the bad link)* "Unreachable page: 3 retries, then a friendly message." *(opens a node's Settings)* "Retry on every external call." *(shows the alert in #n8n)* "The error workflow: workflow name, node, execution link, and the user is told. Sending the same answer twice doesn't create anything new."

**5:30 · State + executions** *(lines 30, 32)*: run *5. Inspect*, then Executions
> "The session written by /job and read by /answer; the facts it learned. Executions: each command is one Main run plus one sub-workflow run; the red ones are my failure tests."

**6:00 · Questions.** Two sentences each (section 5).

**If something breaks:** say what the error path does, then show today's successful runs in Executions and the earlier PDFs in Discord.

---

## 4. The checklist: where to point

| # | Line | Show |
|---|---|---|
| 1 | Need in one sentence | README, top |
| 2 | Trigger on demand + saved payload | `/help` live; Analyzer **Start** node, pinned data 📌; `tests/payloads/` |
| 3 | Diagram, data on arrows | README *Architecture* |
| 4 | Diagram = build; level + cut line | *1. Main* canvas; "Level 3, cut line not needed" |
| 5 | Compose: n8n + other service | `docker-compose.yml`; Docker Desktop: 3 containers |
| 6 | Named volumes | `pg_data`, `n8n_data`; down/up keeps everything |
| 7 | Pinned versions | n8n 2.44.6, Postgres 17.11, cloudflared 2026.10.2 |
| 8 | `.env.example`, `.env` ignored, encryption key | `.gitignore`; `N8N_ENCRYPTION_KEY: ${…}` |
| 9 | Fresh clone, DB healthcheck | compose healthcheck + `depends_on: service_healthy`; README "Tested … from a fresh clone" |
| 10 | Workflows JSON = demo | `workflows/`, `scripts/export.sh`, tag v1.0 |
| 11 | No secrets in history | `credentials/stubs.json` = names only; history scanned |
| 12 | ≥10 commits over ≥2 days | ~30 commits, **all today** (honest: "I moved from Cloud to Git when I self-hosted"; likely −0.5) |
| 13 | PR or v1.0 | Pull request #1 merged + tag v1.0 |
| 14 | Message trigger | Main → **Discord Interaction** |
| 15 | API + stored credential | Reply nodes (Discord), Gemini nodes (OpenRouter), Drive/Docs (Google) |
| 16 | If / Set | **Valid /job input?**, **Payload: Job**, **Question (with fallback)** |
| 17 | Code node | **Code: Gap Analysis**, **Verify & Parse** |
| 18 | Switch, ≥2 paths | **Command Router** |
| 19 | Database | Postgres nodes; *5. Inspect* |
| 20 | AI + written prompt | **AI: Tailor CV** prompt |
| 21 | Sub-workflow, defined inputs | **Run Analyzer** mapping; Analyzer **Start** |
| 22 | Retry everywhere | node → Settings → Retry On Fail (3 tries) |
| 23 | Error workflow + URL | workflow Settings → Error workflow; alert in #n8n |
| 24 | Invalid input → usage | `/job url:hello` |
| 25 | Idempotent | same `/answer` twice; no duplicate in `facts` |
| 26 | AI validated + fallback | output parser + red error output on **AI:** nodes |
| 27 | Live failure | bad link → retries → friendly message |
| 28–32 | Demo | round trip, 2nd command, Inspect, readable reply, Executions |
| 33 | README | setup, env, tests, screenshots |

---

## 5. Quick questions

- **Why a Code node and not AI for the gaps?** Comparing two lists is deterministic: free, instant, same result every time, and I can explain each decision. The AI only reads messy text and suggests synonyms that the code checks.
- **Do you have sub-workflows? Why?** Analyzer and Generator, with declared inputs; each one testable alone; the Generator is called from two places.
- **Why an LLM Chain and not an AI Agent?** Fixed steps in a fixed order; a chain plus an output parser gives typed JSON. An agent picks its own steps: slower, costlier, less predictable.
- **How do you beat the 3-second limit?** "Thinking…" right away, then I edit that message with the interaction token (valid 15 min).
- **How do you know it's Discord calling?** Ed25519 signature check in a Code node; 401 otherwise.
- **Why Postgres?** Real relational DB in the same Docker stack; unique keys and upserts make it idempotent.
- **Why a tunnel?** Discord needs public HTTPS to reach my laptop; the quick tunnel gives one without an account. Limit: a new URL when it restarts.
- **How do you stop the AI from inventing?** Only 5 template fields; my known gaps are passed as "never claim"; prompts forbid new skills, numbers and motivations. Tests caught it inventing twice, and both are fixed.
- **What broke during testing?** A usage message that crashed (a line break in an expression), the Google Docs API not enabled (the error workflow caught it), a 1/10 score from exact matching (now synonyms), duplicate facts on a repeated answer (answers are now remembered).
- **Limits / next step?** Built for my own CV template; no cache for an identical `/job`; one job at a time. Next: one template per user, an offer cache, a named tunnel.
