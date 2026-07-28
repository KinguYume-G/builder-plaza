# App Demo video — recording plan (Group 19)

Part 2 deliverable: **Recorded App demo (Video)**, submitted with the code.

**Format:** three segments, one per member, **each recorded separately on the
same evening**, ~5 minutes each, camera on, feature demo only — no code
walkthrough. Every segment must show real data changing in the database.

Roles follow the Workload Allocation already registered in the proposal, so the
marker can match each speaker to the table they already have:

| Segment | Member | Adopted role | Records at |
|---|---|---|---|
| 1 | Liu Wei (TP085412) | **Builder** | 20:00 |
| 2 | Gao Xing (TP085905) | **Collaborator** | 20:30 |
| 3 | Choong Ti Huai (TP078539) | **Founder** | 21:00 |

---

## The one idea that makes this work

**The three segments are chained.** Each person's demo consumes the data the
previous person created.

```
Wei creates a project card  ──►  Gao Xing finds THAT card in the Plaza
                                 and sends a request on it
                                          │
                                          ▼
                      Ti Huai receives THAT request and accepts it
```

Because the data lives in the shared RDS database, this works even though you
record separately — but **the order is fixed, and each person must finish before
the next one starts.** Message the group when your segment is done.

Two things fall out of this for free:

1. **The database proof becomes self-evident.** When Gao Xing's phone shows a
   project card Wei created half an hour earlier on a different machine, the
   shared database is proven without anyone having to say "trust me".
2. **It reads as one product, not three feature lists.** That is the difference
   between Pass ("able to articulate basic functionality") and Credit/Distinction
   ("coherent, clear and in-depth understanding") in the grading table.

Say the handoff out loud at each seam — "the card you're about to see is the one
Wei created in his segment" — so the marker cannot miss it.

> **Recording tonight, not across days, is deliberate.** The dashboard shows
> `created_at`, so a card made two days ago while you narrate "just created"
> contradicts what is on screen. Same evening keeps the timestamps honest.

---

## Before anyone records

**1. Install the current build on your own phone.**
[`manual-b8712a4`](https://github.com/KinguYume-G/builder-plaza/releases/tag/manual-b8712a4)
— take `app-arm64-v8a-release.apk`. **Uninstall any older Builder Plaza first**:
an old install carries a stale token and may point at someone's laptop. Install
the release APK as-is; it targets the deployed backend with no configuration.

**2. Quit Tailscale.** Its MagicDNS resolver (`100.100.100.100`) intermittently
fails to resolve the ALB hostname — `dig` succeeds while `getaddrinfo` returns
nothing, so the app says *"Cannot reach backend"* and browsers show
`ERR_NAME_NOT_RESOLVED`. It looks exactly like a broken backend and it is not.
This bit us during preparation; assume it will happen on camera if Tailscale runs.

**3. Open the live database dashboard — on a laptop, not a phone.**

```
http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com:8080
```

Row counts plus the actual rows, refreshing every 5s, so a counter moves and the
new row appears while you keep talking. **Open it 30 seconds before you start** —
the first load takes 15–20s (stat tiles first, then the tables).

Do not open it on a phone: the ALB has no TLS (no domain, no ACM certificate — a
known limitation recorded in `docs/DEPLOYMENT.md`) and mobile Chrome's
HTTPS-first mode fails the handshake with `ERR_SSL_PROTOCOL_ERROR`. The app
itself is unaffected — it uses Dio, not a browser.

**4. Nobody runs `seed.py`.** It **wipes all 11 tables**. One person running it
mid-evening destroys the chain and invalidates everything already filmed. If you
get stuck, ask in the group — do not "reset the environment".

**5. Screen layout.** Phone mirror on the left (`scrcpy`), dashboard on the
right, webcam picture-in-picture in a corner. OBS does all three in one scene.

**6. Rehearse the two slow calls.** `Connect GitHub` hits the GitHub API and has
timed out at 10s when GitHub was slow; `Refresh growth` posts nothing when the
linked repo has no new events. Run both once before recording.

### How each of you signs in

The landing screen offers only **Connect GitHub**, and that returns 409 for any
account that has already completed onboarding. The entry screen was not
redesigned for the assessment — we work around it.

- **Wei** — use a real GitHub username **not yet in the database**, so Connect
  succeeds and the Trust Gateway pulls live data on camera. Check first:
  `curl -s "http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com/users?q=<login>"`
- **Gao Xing and Ti Huai** — your accounts exist, so **do not tap Connect
  GitHub**. Tap the small **`dev · system check`** link at the bottom →
  **CONTINUE → LOGIN** → replace `demo-builder` with your own GitHub login →
  pick your role → **DEV LOGIN**. Practise this once; the link is easy to miss
  and fumbling for it on camera is noticeable.

If you hit the 409 anyway, its error card has a **Sign in instead →** button that
takes you there with the username already filled in. Recover with that.

---

## Segment 1 — Liu Wei · Builder (20:00, ~5 min)

**Selling:** *a builder's credibility should come from evidence, not
self-description.*

| # | Show | Say | Database proof |
|---|---|---|---|
| 1 | Step 1 — enter your unused GitHub username → Connect | "These repos, languages and stars are pulled live from GitHub. Nothing here is self-reported." | `users` +1 |
| 2 | Step 2 — LinkedIn | Point at the **SIMULATED FOR DEMO** watermark: "labelled because it's a class project; the real OIDC path exists behind the same interface." | — |
| 3 | Step 3 → Builder → Builder Home | "The role picks the lens, not a separate app." | — |
| 4 | Profile → completeness bar | "The 40 and 70 gates unlock contact and matching — you can't lurk with an empty profile." | — |
| 5 | Tap avatar → upload a photo | "Images go straight to object storage, not into the database." | `users.avatar_s3_key` fills in |
| 6 | Home → edit intent | "This is the piece no other tool has: am I open *right now*." | `intents` +1 |
| 7 | ＋ New project → title, stage, needs, team division, link a real `owner/repo` | "This card is what collaborators will judge me on." | `project_cards` +1 — show `title`, `repo_full_names` |
| 8 | **＋ Add screenshot → pick an image** | "Screenshots also go to object storage." | `screenshot_s3_keys` `{}` → 1 key — **this is the binary/image-data marking criterion, do not skip it** |
| 9 | View project → linked repo activity | "Live commits and issues from the repo I linked." | — |
| 10 | **Refresh growth** | "It polls my repo for new activity and writes a neutral AI summary — I don't write my own progress reports." | `growth_posts` +1 — the `summary` text matches the phone |
| 11 | Plaza → GROWTH | "And it's public here immediately." | same row |
| 12 | Profile → Verified activity & evidence | "12-week continuity chart, the roles I hold on my repos, a typed event timeline — all from public events." | — |

**Close:** "That card is live in the Plaza now — Gao Xing, over to you."
Then message the group.

---

## Segment 2 — Gao Xing · Collaborator (20:30, ~5 min)

**Selling:** *finding someone credible, and reaching them without spamming.*

| # | Show | Say | Database proof |
|---|---|---|---|
| 1 | Sign in via `dev · system check` | — | — |
| 2 | Plaza → PROJECTS, filter by stage, search | **"This is the card Wei created half an hour ago, from a different machine."** | the card's existence *is* the proof — say so |
| 3 | Open Wei's card → screenshot gallery + repo activity | "His screenshot and his repo activity." | — |
| 4 | Plaza → GROWTH, filter by owner role | "And the AI summary his repo activity generated." | same `growth_posts` row |
| 5 | Match tab | "Every match explains **WHY**. The mustard **EXPLORE** badge is the exploration pick — pull to refresh and that slot changes." | `matches` rows |
| 6 | Credibility → plain-language summary | "I'm not a deep backend person; this translates the technical signals for me." | — |
| 7 | Trust score of that candidate | "Component bars with their own weights. The payment badge is **simulated and labelled**, and by design can never carry the score alone." | — |
| 8 | **Request collaboration** — try a pitch under 20 chars first, then a real one → Send | "First contact is always structured. There's no way to DM someone out of nowhere, and no email or phone number is ever exposed." | `collab_requests` +1, `state = 'pending'` |
| 9 | Home → Request market → open a posting → **Apply** | "Applying reuses the same request pipeline — one contact mechanism, not two." | `collab_requests` +1 |
| 10 | Turn the network off → Plaza | "Offline it still renders the last sync, clearly marked." | — |

**Close:** "That request is in the founder's inbox — Ti Huai." Then message the group.

---

## Segment 3 — Choong Ti Huai · Founder (21:00, ~5 min)

**Selling:** *evaluating and recruiting, with the trust signals doing the work.*

| # | Show | Say | Database proof |
|---|---|---|---|
| 1 | Sign in via `dev · system check` | — | — |
| 2 | Requests & messages → inbox | **"This is Gao Xing's request from half an hour ago."** | the `collab_requests` row from segment 2 |
| 3 | **Accept** | "Accepting is the *only* way a conversation can exist — that's the anti-spam rule, enforced server-side." | `state` pending → accepted **and** `conversations` +1 in the same refresh — **the single most convincing moment in the video; linger on it** |
| 4 | Conversation → exchange messages | "Messages poll every 10 seconds." | `messages` +N |
| 5 | Decline another request | "Declining enforces a 7-day cooldown, so nobody can re-pitch you the next morning." | `state` → declined |
| 6 | Peer review the counterpart | "Peer review feeds back into their trust score." | `peer_reviews` +1, then show the score move |
| 7 | Request market → **new team-role posting**; submit empty first to show validation, then fill in | "Stage, tech stack and commitment are always required, so the market can't fill with vague posts." | `role_postings` +1 |
| 8 | Market → maintainer posting with access tier | "The other posting type is repo-backed, with an access tier attached." | — |
| 9 | Profile → **Simulated suite** | "Clearly separated and labelled: sandbox log replay, human-approved shortlist, agent scopes, proof-of-work. Simulated, and we say so." | — |
| 10 | Unfold the phone (or rotate) | "Same code adapts — the bottom tabs become a side rail on a wide screen." | — |

**Close:** hand to the group outro.

---

## Opening and closing

**Open (~40s, all three, can be filmed once and cut in):** group number, names,
one sentence on what Builder Plaza is — *"a mobile app that unifies proof of
work, professional identity and current collaboration intent, so builders can
decide who to contact"* — and who demos which role. State up front: *"Each of us
demos the role we owned, and you'll see the same records move through the shared
database across all three segments."*

**Close (~40s):** one sentence each on your part, then: runs on AWS (ECS Fargate
behind an ALB, RDS Postgres with pgvector), 176 backend tests and 15 widget tests
green, CI on every push.

---

## Feature coverage checklist

Tick these off after editing — the 37-mark rubric rewards breadth.

| Module | Where | ✓ |
|---|---|---|
| F1 Trust Gateway (GitHub live + LinkedIn simulated + role) | S1 · 1–3 | ☐ |
| F2 Profile, completeness gates, avatar upload | S1 · 4–5 | ☐ |
| F3 Project cards, intent, screenshots | S1 · 6–8 | ☐ |
| F4 Growth Plaza (GitHub poll + AI summary) | S1 · 10–11 | ☐ |
| F5 Matching + WHY + EXPLORE + credibility | S2 · 5–6 | ☐ |
| F6 Trust score + simulated badge | S2 · 7 | ☐ |
| F7 Controlled DM, accept, conversation, cooldown, peer review | S2 · 8 / S3 · 2–6 | ☐ |
| F8 Request market, both posting types, validation, Apply | S2 · 9 / S3 · 7–8 | ☐ |
| F9 Simulated suite (labelled) | S3 · 9 | ☐ |
| F10 Verified activity + ownership evidence | S1 · 12 | ☐ |
| NFR offline cached feed | S2 · 10 | ☐ |
| NFR adaptive/wide layout | S3 · 10 | ☐ |
| Discovery: filter + search | S2 · 2 | ☐ |
| Third-party API usage (GitHub, Bedrock, S3) | S1 · 1, 8, 10 | ☐ |

---

## What loses marks

- **Camera off, or one person doing all the talking.** The criteria say
  demonstration "by all group members", and the brief warns that being unable to
  explain your own work is treated as *plausible academic dishonesty*. Demo the
  role you actually built.
- **Running `seed.py` mid-evening.** It wipes the chain.
- **A local backend.** Install the release APK as-is; don't `flutter run` with a
  `--dart-define` pointing at your laptop.
- **Skipping the screenshot upload.** "Intuitive usage of both textual and image
  based binary data" is an explicit line in the 37-mark rubric.
- **Explaining code.** Agreed constraint, and it eats your five minutes. Show
  behaviour; *how* belongs in the live viva.
- **Silent SIMULATED components.** Name them out loud when they appear —
  labelling them is a credibility gain, not an admission.

## After the assessment

Both are in `docs/DEPLOYMENT.md`:

- **Turn off `ALLOW_DEV_LOGIN`** — right now anyone with the ALB address can sign
  in as any account.
- **Delete the 8080 listener** — the dashboard is anonymous and public, and shows
  real pitches and message bodies.
