# App Demo video — recording plan (Group 19)

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

Message the group when your segment is done so the next person can start. Same
evening, because the dashboard shows `created_at` — a card from two days ago
while you say "just created" contradicts the screen.

---

## Before recording

**Install** [`manual-b8712a4`](https://github.com/KinguYume-G/builder-plaza/releases/tag/manual-b8712a4)
(`app-arm64-v8a-release.apk`). Uninstall any older build first — it carries a
stale token and may point at someone's laptop. Use the APK as-is.

**Quit Tailscale.** Its MagicDNS intermittently fails to resolve the ALB, and the
app then says "Cannot reach backend" as if the server were down.

**Open the dashboard on a laptop** (not a phone — the ALB has no TLS and mobile
Chrome forces HTTPS):

```
http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com:8080
```

Row counts plus live rows, refreshing every 5s. Open it 30s early; first load
takes ~20s.

**Nobody runs `seed.py`** — it wipes all 11 tables and destroys the chain.

**Layout:** phone mirror (`scrcpy`) left, dashboard right, webcam corner. OBS
does all three.

**Signing in.** The landing screen only offers Connect GitHub, which 409s for
accounts that have finished onboarding.

- **Wei** — use a GitHub username **not yet in the database** so Connect works.
- **Gao Xing / Ti Huai** — don't tap Connect. Use the `dev · system check` link
  at the bottom → CONTINUE → LOGIN → your GitHub login → DEV LOGIN. Practise it
  once; the link is small.

---

## Segment 1 — Wei · Builder

| # | Do | Database |
|---|---|---|
| 1 | Connect GitHub with an unused username — live repos, languages, stars | `users` +1 |
| 2 | LinkedIn step — name the **SIMULATED FOR DEMO** watermark out loud | — |
| 3 | Pick Builder | — |
| 4 | Profile → completeness bar, mention the 40/70 gates | — |
| 5 | Tap avatar → upload a photo | `avatar_s3_key` fills |
| 6 | Home → edit intent | `intents` +1 |
| 7 | ＋ New project — title, stage, needs, team division, link a real repo | `project_cards` +1 |
| 8 | **＋ Add screenshot** — required by the rubric, don't skip | `screenshot_s3_keys` `{}` → 1 |
| 9 | View project → linked repo activity | — |
| 10 | **Refresh growth** → AI summary | `growth_posts` +1 |
| 11 | Plaza → GROWTH shows it | same row |
| 12 | Profile → Verified activity & evidence (continuity chart, repo roles, timeline) | — |

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
| 8 | Request collaboration — try a pitch under 20 chars first, then send a real one | `collab_requests` +1, `pending` |
| 9 | Request market → open a posting → Apply | `collab_requests` +1 |
| 10 | Network off → Plaza still renders, marked offline | — |

Close: "That request is in the founder's inbox."

## Segment 3 — Ti Huai · Founder

| # | Do | Database |
|---|---|---|
| 1 | Sign in | — |
| 2 | Inbox — **say it's Gao Xing's request from earlier** | the row from segment 2 |
| 3 | **Accept** — "accepting is the only way a conversation can exist" | `pending`→`accepted` **and** `conversations` +1 — linger here |
| 4 | Conversation → send messages (10s poll) | `messages` +N |
| 5 | Decline another request — 7-day cooldown | `state` → declined |
| 6 | Peer review the counterpart | `peer_reviews` +1, score moves |
| 7 | Market → new team-role posting; submit empty first to show validation | `role_postings` +1 |
| 8 | Market → maintainer posting with access tier | — |
| 9 | Profile → Simulated suite (sandbox, shortlist, agent scopes, PoW) — say "simulated" | — |
| 10 | Unfold the phone — tabs become a side rail | — |

---

## Open / close

**Open** (all three, film once): group number, names, one line — *"unifies proof
of work, professional identity and current collaboration intent, so builders can
decide who to contact"* — and who demos which role.

**Close:** one line each, then: AWS ECS Fargate + ALB + RDS with pgvector, 176
backend tests and 15 widget tests green, CI on every push.

---

## Coverage check (tick after editing)

| Module | Where | ✓ |
|---|---|---|
| F1 Trust Gateway | S1 · 1–3 | ☐ |
| F2 Profile, gates, avatar | S1 · 4–5 | ☐ |
| F3 Project cards, intent, screenshots | S1 · 6–8 | ☐ |
| F4 Growth Plaza | S1 · 10–11 | ☐ |
| F5 Matching, WHY, credibility | S2 · 5–6 | ☐ |
| F6 Trust score | S2 · 7 | ☐ |
| F7 Controlled DM, cooldown, peer review | S2 · 8 / S3 · 2–6 | ☐ |
| F8 Request market, both types, Apply | S2 · 9 / S3 · 7–8 | ☐ |
| F9 Simulated suite | S3 · 9 | ☐ |
| F10 Verified activity + evidence | S1 · 12 | ☐ |
| Offline feed | S2 · 10 | ☐ |
| Wide layout | S3 · 10 | ☐ |
| Discovery filter + search | S2 · 2 | ☐ |
| 3rd-party APIs (GitHub, Bedrock, S3) | S1 · 1, 8, 10 | ☐ |

## Loses marks

- Camera off, or one person talking — the criteria say "by all group members",
  and not being able to explain your own work counts as academic dishonesty.
- Running `seed.py`, or pointing the app at a local backend.
- Skipping the screenshot upload — image binary data is an explicit rubric line.
- Explaining code. Show behaviour; *how* belongs in the live viva.
- Not naming the SIMULATED components out loud.

## After the assessment

In `docs/DEPLOYMENT.md`: turn off `ALLOW_DEV_LOGIN`, delete the 8080 listener.
