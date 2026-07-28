# App Demo video — recording plan (Group 19)

Part 2 deliverable: **Recorded App demo (Video)**, submitted with the code.
Constraints agreed by the group: three members take turns, **feature demo only —
no code walkthrough**, ~5 minutes each, **camera on**, and every segment must
show **real data changing in the database**.

Roles follow the Workload Allocation already registered in the proposal, so the
marker can match each speaker to the table they already have:

| Segment | Member | Adopted role |
|---|---|---|
| 1 | Liu Wei (TP085412) | **Builder** |
| 2 | Gao Xing (TP085905) | **Collaborator** |
| 3 | Choong Ti Huai (TP078539) | **Founder** |

---

## The one idea that makes this demo work

**Chain the three segments causally.** Do not demo three unrelated feature
tours.

```
Liu Wei creates a project card  ──►  Gao Xing finds THAT card in the Plaza
                                     and sends a request on it
                                              │
                                              ▼
                          Choong Ti Huai receives THAT request and accepts it
```

Two things fall out of this for free:

1. **The database proof becomes self-evident.** When Gao Xing's phone shows a
   project card Liu Wei created ten minutes earlier on a different machine, the
   shared database is proven without anyone having to say "trust me". Every
   SQL check below then becomes confirmation rather than the whole argument.
2. **It reads as one product, not three feature lists.** That is the difference
   between Pass ("able to articulate basic functionality") and Credit/Distinction
   ("coherent, clear and in-depth understanding") in the grading table.

Say the handoff out loud at each seam — "the card you're about to see is the one
Wei just created" — so the marker cannot miss it.

---

## Setup before anyone records

**All three must point at the same backend.** Use the deployed ALB
(`http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com`, the app's
default — no `--dart-define` needed). A local `uvicorn` on one laptop is not
reachable by the other two, and the chain silently breaks.

**Seed exactly once, before segment 1.**

```bash
cd backend && .venv/bin/python seed.py
```

> ⚠️ `seed.py` **wipes** all 11 tables before reloading. If anyone re-runs it
> between segments, the chain is destroyed and earlier footage no longer matches
> the database. Seed once, then leave it alone until all three segments are shot.

**Screen layout** — phone mirror on the left, database window on the right,
webcam picture-in-picture in a corner:

- Mirror the handset with `scrcpy` (`brew install scrcpy`, then `scrcpy`) — adb
  is already working on Wei's machine. A real device beats an emulator on camera.
- Record with OBS (free, does webcam PiP + window capture in one scene) or
  QuickTime + a separate webcam recording if OBS is too much setup.

**Database window — the live counter dashboard.**

Open this next to the phone mirror:

```
http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com/demo/live
```

It is served by the deployed backend, so **all three members just open the URL** —
nothing to install, no database credentials to pass around, and everyone sees the
same numbers.

It polls row counts once per second and **flashes a counter green with a `+1`
badge the moment it changes**. That is the whole point: you never stop talking to
go and click Refresh. You tap *Send request* on the phone and, in the same shot,
`collab_requests` ticks 6 → 7 by itself.

Counts only — no row contents, no user data, read-only.

> Why not a SQL client: AWS RDS (unlike Supabase or Firebase) gives you **no**
> table browser in its console — the Query Editor is Aurora-only — so the
> alternative was installing a desktop client on three machines and clicking
> refresh on camera. The dashboard is both easier and far more convincing.

**On camera, say what it is once**, early: *"On the right is a live view of the
production database — row counts, refreshing every second."* Then let it speak
for itself for the rest of the video.

**Quit Tailscale on every machine before recording.** Its MagicDNS resolver
(`100.100.100.100`) sits in front of the system resolver and intermittently fails
to resolve the ALB hostname — `dig` succeeds while `getaddrinfo` returns nothing,
so the app reports *"Cannot reach backend"* and browsers show
`ERR_NAME_NOT_RESOLVED`. It looks exactly like a broken backend and it is not.
This bit us mid-session; assume it will happen on camera if Tailscale is running.

**Open the dashboard in a desktop browser, not on a phone.** The ALB has no TLS
(no domain, no ACM certificate — a known limitation recorded in
`docs/DEPLOYMENT.md`), and mobile Chrome's HTTPS-first mode upgrades the URL and
then fails the handshake with `ERR_SSL_PROTOCOL_ERROR`. The Flutter app is
unaffected: it uses Dio, not a browser, and `network_security_config.xml`
already permits cleartext to this host.

**Signing in against the deployed backend needs `ALLOW_DEV_LOGIN`.** It is set on
the current deployment (`builder-plaza-backend:5`). Without it there is no way in
at all: `Connect GitHub` returns 409 for any account that has finished
onboarding, and the real OAuth callback redirects to a *web* frontend, so it
cannot complete on Android. Turn the flag off after the assessment.

### How each of you signs in — read this before recording

The landing screen offers only **Connect GitHub**, and that call returns 409 for
any account that has already completed onboarding. Every one of our accounts is
in that state, so *do not start by tapping Connect GitHub.* The app has not been
redesigned for the assessment; we work around it instead.

**Wei (segment 1) — do the full onboarding, on purpose.** Use a real GitHub
username that is **not yet in the database**. Connect then succeeds and you get
the Trust Gateway pulling live repos, languages and stars on camera, which is the
single most persuasive thing in the app. Check the username is unused first:

```bash
curl -s "http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com/users?q=<login>"
```

**Gao Xing and Ti Huai (segments 2 and 3) — sign in, don't connect.** Your
accounts already exist, so:

> tap the small **`dev · system check`** link at the bottom of the landing screen
> → **CONTINUE → LOGIN** → replace `demo-builder` with your own GitHub login →
> pick your role → **DEV LOGIN**

Practise that tap sequence once. The footer link is small and easy to miss, and
fumbling for it on camera is the kind of thing a marker notices.

If someone taps Connect GitHub by mistake and gets the 409, the error card now
carries a **Sign in instead →** button that takes them to the same screen with
the username already filled in — recover with that rather than restarting.

**Rehearse the two slow calls.** In testing today, `/auth/github/connect` hit a
10-second timeout because the GitHub API was slow, and `Refresh growth` posts
nothing when the linked repo has no new events. Run both once before recording
so you know they respond, and have a fallback line ready ("GitHub's API is rate
limiting — here's the same call succeeding a moment ago").

---

## Segment 1 — Liu Wei · Builder (~5 min)

**The line you are selling:** *a builder's credibility should come from evidence,
not from self-description.*

| # | Show | Say | Database proof |
|---|---|---|---|
| 1 | Fresh app → Step 1, enter a real GitHub username **that is not already in the database** (see the sign-in note above) → Connect | "Nothing here is self-reported — these repos, languages and stars are pulled live from GitHub." | `users` +1 — show the new row's `github_login` and `created_at` |
| 2 | Step 2, LinkedIn | Point at the **SIMULATED FOR DEMO** watermark: "labelled because it's a class project; the real OIDC path exists behind the same interface." | — (say it, don't dwell) |
| 3 | Step 3 → Builder → Builder Home | "The role picks the lens, not a separate app." | — |
| 4 | ＋ New project → title, stage, needs, link a real `owner/repo` | "This card is the thing collaborators will actually judge me on." | `project_cards` +1 — show `title` and `repo_full_names` |
| 5 | **＋ Add screenshot → pick an image** | "Screenshots upload straight to object storage, not into the database." | `project_cards.screenshot_s3_keys` goes from `{}` to one key — **this is your binary/image-data marking criterion, do not skip it** |
| 6 | Project detail → **Refresh growth** | "It polls my linked repo for new activity and writes a neutral summary — I don't write my own progress reports." | `growth_posts` +1 — show the `summary` text matches what's on the phone |
| 7 | Profile → completeness bar, Verified activity & evidence | "The 12-week continuity chart and repository roles come from public events." | — |

**Close your segment on the handoff:** "That card is now live in the Plaza —
Gao Xing, over to you."

---

## Segment 2 — Gao Xing · Collaborator (~5 min)

**The line you are selling:** *finding someone credible, and reaching them
without spamming.*

| # | Show | Say | Database proof |
|---|---|---|---|
| 1 | Plaza → PROJECTS, filter by stage, search | **"This is the card Wei created a few minutes ago, from a different machine."** | The card's existence *is* the proof — say so explicitly |
| 2 | Plaza → GROWTH | "And this is the AI summary his repo activity generated." | Same `growth_posts` row from segment 1 |
| 3 | Match tab | "Every match explains **WHY** it was suggested. The mustard **EXPLORE** badge is the exploration pick — pull to refresh and that slot changes." | `matches` rows for your user |
| 4 | Credibility → plain-language summary | "I'm not a deep backend person — this translates the technical signals for me." | — |
| 5 | **Request collaboration** → pick intent, write a pitch (try <20 chars first to show validation, then a real one) → Send | "First contact is always structured. There's no way to just DM someone out of nowhere, and no email or phone number is ever exposed." | `collab_requests` +1, `state = 'pending'` — show the row |
| 6 | Turn the network off → Plaza | "Offline it still renders the last sync, clearly marked." | — |

**Close your segment on the handoff:** "That request is now sitting in the
founder's inbox — Ti Huai."

---

## Segment 3 — Choong Ti Huai · Founder (~5 min)

**The line you are selling:** *evaluating and recruiting, with the trust signals
doing the work.*

| # | Show | Say | Database proof |
|---|---|---|---|
| 1 | Requests & messages → inbox | **"This is Gao Xing's request from a minute ago."** | The `collab_requests` row from segment 2 |
| 2 | **Accept** | "Accepting is the *only* way a conversation can exist — that's the anti-spam rule, enforced server-side." | `collab_requests.state` pending → accepted **and** `conversations` +1 in the same refresh. This causal pair is the single most convincing DB moment in the whole video — linger on it |
| 3 | Conversation → exchange a few messages | "Messages poll every 10 seconds." | `messages` +N |
| 4 | Peer review the counterpart | "Peer review feeds back into their trust score." | `peer_reviews` +1, then show the trust score change on screen |
| 5 | Profile → Trust score | "Component bars with their own weights. The payment badge is **simulated and labelled**, and by design it can never carry the score on its own." | — |
| 6 | Request market → new team-role posting; **submit it empty first** to show the three-mandatory validation, then fill it in | "Stage, tech stack and commitment are always present — that's enforced, so the market can't fill with vague posts." | `role_postings` +1 |

**Close:** hand back to the group for the joint outro.

---

## Opening and closing (all three on camera, ~40s each)

**Open** — all three visible: group number, names, one sentence on what Builder
Plaza is ("a mobile app that unifies proof of work, professional identity, and
current collaboration intent so builders can decide who to contact"), and who is
demoing which role. State up front: *"Each of us demos the role we owned, and
you'll see the same records move through the shared database across all three
segments."*

**Close** — one sentence each on what your role's part of the system does, then
one line that the app runs against a deployed backend on AWS with the automated
test suites green. Keep it under a minute.

---

## Things that will cost you marks if you get them wrong

- **Camera off, or one person doing all the talking.** The grading criteria say
  demonstration "by all group members", and the brief warns that inability to
  explain your own work is treated as *plausible academic dishonesty*. Each
  person must demo the role they actually built.
- **Re-seeding mid-recording.** It wipes the chain. Seed once.
- **Different backends.** If anyone runs a local backend, their segment won't
  show the others' data and the whole causal chain collapses.
- **Skipping the screenshot upload.** "Intuitive usage of both textual and image
  based binary data" is an explicit line in the 37-mark rubric.
- **Explaining code.** Agreed constraint, and it also eats your five minutes.
  Show behaviour; if asked *how*, that's the live viva, not this video.
- **Silent SIMULATED components.** Always name them out loud when they appear.
  Labelling them is a credibility gain, not an admission.

## Still to decide

- Recording tool (OBS vs QuickTime) and who edits the three segments together.
- Whether to record in one live chain on the same afternoon (simplest — the DB
  state stays consistent) or separately across three days (works too, because
  the data persists in RDS, but nobody may re-seed).
- Where it gets hosted — the brief accepts a YouTube public link or a Moodle
  upload.
