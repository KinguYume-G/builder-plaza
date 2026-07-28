# App Demo video — final recording plan (Group 19)

Three segments, one per member, recorded separately on the same evening. ~5 min
each, camera on, features only — no code. Each segment shows real data changing
in the database.

| # | Member | Role |
|---|---|---|
| 1 | Liu Wei (TP085412) | Builder |
| 2 | Gao Xing (TP085905) | Collaborator |
| 3 | Choong Ti Huai (TP078539) | Founder |

**Order is fixed** — each segment uses the data the previous one created:

```
Wei creates a project card → Gao Xing finds it and sends a request
                           → Ti Huai receives it and accepts
```

Message the group when your segment is done. Same evening, because the dashboard
shows `created_at`.

**Demo the role you built.** The brief treats "cannot explain your own work" as
plausible academic dishonesty, so each person walks their own module.

---

## Before recording

**Install** [`manual-b8712a4`](https://github.com/KinguYume-G/builder-plaza/releases/tag/manual-b8712a4)
(`app-arm64-v8a-release.apk`). Uninstall any older build first. Use the APK
as-is — do not `flutter run` against a laptop.

**Quit Tailscale.** Its MagicDNS intermittently fails to resolve the ALB and the
app then reports "Cannot reach backend" as if the server were down.

**Open the dashboard on a laptop** (not a phone — no TLS on the ALB, mobile
Chrome forces HTTPS):

```
http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com:8080
```

Open it 30s early; first load takes ~20s.

**Nobody runs `seed.py`** — it wipes all 11 tables.

**Layout:** phone mirror (`scrcpy`) left, dashboard right, webcam corner. OBS.

**Signing in.** The landing screen only offers Connect GitHub, which 409s for
accounts that have onboarded.
- **Wei** — use a GitHub username **not yet in the database** so Connect works.
- **Gao Xing / Ti Huai** — `dev · system check` → CONTINUE → LOGIN → your GitHub
  login → DEV LOGIN. Practise once; the link is small.

---

## Segment 1 — Wei · Builder

| # | Do | Database |
|---|---|---|
| 1 | Connect GitHub with an unused username — live repos, languages, stars | `users` +1 |
| 2 | LinkedIn — the **real** OIDC flow (production runs `LINKEDIN_MODE=live`). Consent in the browser, close the tab, and the app picks the binding up by itself | `linkedin_sub` fills |
| 3 | Pick Builder | — |
| 4 | Profile → completeness bar, point at the 40/70 gates | — |
| 5 | Tap avatar → upload a photo | `avatar_s3_key` fills |
| 6 | Home → edit intent | `intents` +1 |
| 7 | ＋ New project — title, stage, needs, team division, link a real repo | `project_cards` +1 |
| 8 | **＋ Add screenshot** | `screenshot_s3_keys` `{}` → 1 |
| 9 | View project → linked repo activity | — |
| 10 | **Refresh growth** → AI summary appears | `growth_posts` +1 |
| 11 | Plaza → GROWTH shows it publicly | same row |
| 12 | Profile → Verified activity & evidence — continuity chart, repo roles, timeline | — |

**Say these three things** — this is what turns a feature tour into a design
argument:

- *"Every signal here is pulled from GitHub's API, and the LinkedIn step is real
  OpenID Connect, not a mock. Nothing on this profile is typed in by me."*
  (steps 1, 2, 9, 12)
- *"The 40 and 70 gates mean you can't lurk — you unlock contact and matching by
  actually having evidence."* (step 4)
- *"I don't write my own progress updates. It reads the repo events and an AI
  model summarises them, so the feed can't be gamed by self-promotion."* (step 10)

Close: "That card is live in the Plaza now."

## Segment 2 — Gao Xing · Collaborator

| # | Do | Database |
|---|---|---|
| 1 | Sign in | — |
| 2 | Plaza → PROJECTS, filter by stage, search. **Say it's the card Wei just made** | the card itself |
| 3 | Open it — screenshot gallery, repo activity | — |
| 4 | Plaza → GROWTH, filter by owner role | Wei's `growth_posts` row |
| 5 | Match tab — WHY reasons, EXPLORE badge, pull to refresh | `matches` |
| 6 | Credibility → plain-language summary | — |
| 7 | Trust score — components, weights, the labelled simulated badge | — |
| 8 | Request collaboration — pitch under 20 chars first, then send a real one | `collab_requests` +1, `pending` |
| 9 | Request market → open a posting → Apply | `collab_requests` +1 |
| 10 | Network off → Plaza still renders, marked OFFLINE | — |

**Say these three things:**

- *"Matching isn't keyword search. Skills are embedded as vectors and ranked by
  a model that also reserves a slot for exploration — that's the EXPLORE badge,
  so you don't only ever see the same top five people."* (step 5)
- *"Every match explains itself. I can see why this person was suggested, and as
  someone who isn't deeply technical, the credibility summary translates the
  GitHub signals for me."* (steps 5–6)
- *"The payment badge is simulated and labelled, and by design it can never carry
  the score on its own — the weights renormalise when a component is missing."*
  (step 7)

Close: "That request is in the founder's inbox."

## Segment 3 — Ti Huai · Founder

| # | Do | Database |
|---|---|---|
| 1 | Sign in | — |
| 2 | Inbox — **say it's Gao Xing's request from earlier** | the row from segment 2 |
| 3 | **Accept** | `pending`→`accepted` **and** `conversations` +1 — linger here |
| 4 | Conversation → send messages (10s poll) | `messages` +N |
| 5 | Decline another request — 7-day cooldown | `state` → declined |
| 6 | Peer review the counterpart | `peer_reviews` +1, score moves |
| 7 | Market → new team-role posting; submit empty first to show validation | `role_postings` +1 |
| 8 | Market → maintainer posting with access tier | — |
| 9 | Profile → Simulated suite (sandbox, shortlist, agent scopes, PoW) — say "simulated" | — |
| 10 | **Unfold the phone** — bottom tabs become a side rail | — |

**Say these three things:**

- *"Accepting is the only way a conversation can exist, and that's enforced on
  the server, not just hidden in the UI. Declining starts a 7-day cooldown, so
  nobody can re-pitch you the next morning."* (steps 3, 5)
- *"Both posting types force the fields that make a post useful — stage, tech
  stack, commitment — so the market can't fill with vague asks."* (step 7)
- *"Same codebase, same build: the tab bar becomes a side rail when the screen is
  wide enough."* (step 10)

---

## Open / close

**Open** (all three, film once): group number, names, one line — *"unifies proof
of work, professional identity and current collaboration intent, so builders can
decide who to contact"* — and who demos which role. Add: *"you'll see the same
records move through the shared database across all three segments."*

**Close** (all three): one line each, then the engineering claim:

- AWS ECS Fargate behind an ALB, RDS Postgres with pgvector
- Third-party APIs: **GitHub** (evidence), **LinkedIn OpenID Connect — live**
  (identity), **AWS Bedrock** (growth summaries), **S3** (avatars and
  screenshots)
- 176 backend tests, 15 widget tests, CI on every push
- **Real-device testing on AWS Device Farm** — show a few seconds of the
  crawler's own video from `docs/test-evidence/`, and say the offline path is
  exercised there under a 100%-packet-loss network profile

---

## Rubric coverage

| Rubric line (37 + 15 marks) | Shown in |
|---|---|
| Appropriateness of the user interface | throughout; S3 · 10 for adaptive |
| Program functionalities | S1–S3, all ten modules |
| Mock-ups where not fully implemented | S3 · 9, labelled simulated |
| Mobile data access implementation | every DB proof column |
| Textual **and image binary** data | S1 · 5, 8 (avatar + screenshot to S3) |
| Usage of 3rd-party data APIs | S1 · 1, 10; closing |
| Mobile adaptive design | S3 · 10 |
| App testing frameworks + automated report | closing (Device Farm + CI) |

| Module | Where |
|---|---|
| F1 Trust Gateway | S1 · 1–3 |
| F2 Profile, gates, avatar | S1 · 4–5 |
| F3 Project cards, intent, screenshots | S1 · 6–8 |
| F4 Growth Plaza | S1 · 10–11 |
| F5 Matching, WHY, credibility | S2 · 5–6 |
| F6 Trust score | S2 · 7 |
| F7 Controlled DM, cooldown, peer review | S2 · 8 / S3 · 2–6 |
| F8 Request market, both types, Apply | S2 · 9 / S3 · 7–8 |
| F9 Simulated suite | S3 · 9 |
| F10 Verified activity + evidence | S1 · 12 |
| Offline feed | S2 · 10 |
| Wide layout | S3 · 10 |

## Loses marks

- Camera off, or one person talking for someone else's module.
- Running `seed.py`, or pointing the app at a local backend.
- Skipping the avatar or screenshot upload — image binary data is an explicit
  rubric line and those two steps are the only place it appears.
- Explaining code. Show behaviour; *how* belongs in the live viva.
- Not naming the SIMULATED components out loud.

## After the assessment

In `docs/DEPLOYMENT.md`: turn off `ALLOW_DEV_LOGIN`, delete the 8080 listener.
