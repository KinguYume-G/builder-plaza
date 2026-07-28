# Segment 1 — Liu Wei · Builder — final script

~5½ minutes — the real LinkedIn round-trip costs about a minute of it. Read the **Say** column close to verbatim. The **Do** column is what
your hands are doing while you say it.

The spine of this segment: **the app claims your profile is not self-reported —
so prove it on screen by putting the real GitHub next to it, twice.**

---

## Recording setup

Two OBS scenes, same phone and face in both — only the right-hand panel swaps.
Bind a hotkey to switch; you use it three times.

```
Scene A — "PROOF"                      Scene B — "DB"
┌──────┬────────────────────┐          ┌──────┬────────────────────┐
│      │  github.com/you    │          │      │  Grafana dashboard │
│phone │  (browser)         │          │phone │  (browser)         │
│      │                    │          │      │                    │
│      │            ┌─────┐ │          │      │            ┌─────┐ │
│      │            │face │ │          │      │            │face │ │
└──────┴────────────┴─────┘ │          └──────┴────────────┴─────┘ │
```

**Sources**
1. Window capture → the `phone` window from `.tools/phone` — left, ~430px wide
2. Window capture → browser — right (a *different* browser window per scene:
   one on your GitHub profile, one on the dashboard)
3. Video capture → webcam — bottom right, ~400×225, not covering the tables

Record 1920×1080, 30fps. Use a headset mic, not the laptop's.

**Drive the phone with the mouse through scrcpy** — no hand in frame, no shake,
and this segment has no fold/rotate step so you never need to touch the handset.

## Before you hit record

1. Uninstall the old app; install `app-arm64-v8a-release.apk` from
   [`manual-b8712a4`](https://github.com/KinguYume-G/builder-plaza/releases/tag/manual-b8712a4).
   The old build still holds a token for the account that was deleted.
2. **Quit Tailscale.**
3. Browser window 1 → your GitHub profile, already scrolled to show repositories.
4. Browser window 2 → the dashboard, **`http://`** not `https://` (the ALB has no
   TLS, and `https` fails the handshake):
   `http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com:8080`
   Open it 30s early; first load takes ~20s.
5. `cd` to the repo, run `.tools/phone`, check the window is legible at 1080p.
6. Have a photo ready in the gallery (avatar) and a screenshot ready (project).
7. Dry-run **Connect GitHub** and **Refresh growth** once — GitHub's API has
   timed out at 10s before, and growth posts nothing if the repo has no new
   events.

Your account was deleted from the database, so Connect GitHub will succeed with
your real username and the profile starts genuinely empty. **Do not run
`seed.py`.**

---

## Values to type

Decided in advance so you are never composing text on camera. Copy them exactly
— the narration below refers to them.

| Field | Value |
|---|---|
| GitHub username | `SunflowersLwtech` |
| Intent | **Seeking co-founder** |
| Intent note | `Looking for a Flutter partner on Builder Plaza` |
| Project title | `Builder Plaza mobile app` |
| Stage | **BUILDING** |
| Needs | `A Flutter developer to pair on the matching engine` |
| Team division | `I own backend and mobile. Looking to split frontend` |
| Linked repo | `SunflowersLwtech/sunkit` |

> The repo **must be public** — `sunkit` is. A private one shows
> *Activity unavailable* and Refresh growth posts nothing, because the app only
> reads public GitHub events. That is correct behaviour, but it is not what you
> want to demo.

---

## Script

| Time | Scene | Do | Say |
|---|---|---|---|
| 0:00 | B | To camera | "Hi, I'm Liu Wei, TP085412. I built the Builder side of Builder Plaza, so I'll demo the journey of someone who has a project and needs collaborators." |
| 0:12 | B | Point at the dashboard, top row then the tables | "Before I start — the panel on the right is our **production database**, not a mock. The top row is a live row count for each of the eleven tables, and underneath are the actual newest rows: project cards, collaboration requests, messages, AI summaries. It refreshes every five seconds, so when I tap something on the phone you'll see the row appear here, on the other side of the network, in AWS." |
| 0:20 | **→ A** | GitHub profile in the browser, scroll the repo list | "And on the left, before I touch the app at all — this is my actual GitHub account. My repositories, my languages, my activity. Keep an eye on those numbers." |
| 0:40 | A | Phone: type your username → **Connect GitHub** | "Step one of the Trust Gateway is to verify that work. I type that same username, and the app calls GitHub's API directly." |
| 1:00 | A | Point between the app summary and the browser | "Same repositories. Same languages. Same counts. I never typed any of this into the app — it fetched it. That's the whole premise: your credibility comes from your work, not from what you claim about yourself." |
| 1:20 | **→ B** | Step 2 → tap **Sign in with LinkedIn**; the browser opens on `linkedin.com` | "Step two, professional identity — and this is the **real** LinkedIn OpenID Connect flow, not a mock. That's the genuine LinkedIn consent screen, requesting `openid`, `profile` and `email`." |
| 1:40 | B | Consent on LinkedIn; the browser lands on our **LinkedIn connected** page | "LinkedIn redirects to our callback, which verifies a signed state token, exchanges the code and binds the identity server-side — so an interrupted sign-in can't leave a half-bound account." |
| 2:00 | B | Close the browser tab; the app **advances to step 3 on its own** | "Close the tab, come back, and the app has already picked it up." |
| 2:10 | B | Step 3 → **Builder** | "Step three picks my lens. Builder. Same app for every role — the role decides what you lead with." |
| 2:20 | B | Profile tab → completeness bar | "Now look at my profile. Completeness is starting from almost nothing, because this account is minutes old — and those forty and seventy marks are gates. At forty people can contact me, at seventy I enter matching. You can't lurk with an empty profile and still get access to everyone else." |
| 2:40 | B | Tap avatar → pick a photo | "Let me finish it off with a photo. That image never touches the database — it goes straight to S3, and the row keeps only the key." |
| 2:55 | B | Home → **edit** intent → *Seeking co-founder*, add the note, **Save** | "GitHub says what I've built. LinkedIn says who I am. Neither of them says whether I'm actually free to start something this month — so that's the third signal we add. I'll set mine to *seeking co-founder*, and as I save, `intents` on the right ticks up." |
| 3:10 | B | ＋ **New project** → fill the five fields from the values table → **+ ADD** the repo | "Now, intent on its own is just availability. What a collaborator actually needs is something concrete to judge — so let me post a project. Title, what stage it's at, who I'm looking for, how the work splits. And this one matters: I link a real repository." |
| 3:30 | B | **Create project** | "There it is. `project_cards` goes up by one, and the newest row on the right is mine — my title, my repo, timestamped just now." |
| 3:40 | B | **＋ Add screenshot** → pick an image | "A card with no picture is still just a claim, so I'll add a screenshot — same route as the avatar, uploaded straight to S3 through a pre-signed URL. Watch the shots column go from zero to one." |
| 3:55 | B | **View project** → scroll to repo activity | "Here's the card as a collaborator sees it. Everything I typed — and one thing I didn't: this is live activity from the repository I linked, fetched from GitHub as the page loads." |
| 4:10 | B | Tap **Refresh growth** | "And this is my favourite part of what I built. I never write my own progress updates. This polls the repo for new events and asks a model on AWS Bedrock to summarise them neutrally. Which means the feed can't be gamed by self-promotion — it only moves when the code moves." |
| 4:30 | B | Point at `growth_posts` → Plaza → **GROWTH** | "One new row, and the same text is already public in the Plaza feed. I didn't publish that — my commits did." |
| 4:45 | B | Profile → **Verified activity & evidence** | "Last piece: the receipts. Twelve weeks of contribution continuity, the roles I actually hold on my own repositories, and a typed timeline of what I've been doing." |
| 4:55 | **→ A** | GitHub profile → contribution graph, beside the app's chart | "Which brings us back to where we started. Same public events, same shape. And that's the whole argument: this profile isn't something I wrote about myself — it's derived from what I actually did." |
| 5:10 | A | To camera | "So that's the builder's side — verified work, a live project card, and progress that reports itself. The card is in the Plaza now, and Gao Xing takes it from there." |

---

## The three sentences that carry the marks

Everything else is navigation. These are the design arguments:

1. **1:00** — "Same repositories, same languages, same counts. I never typed any
   of this into the app."
2. **2:20** — "Forty and seventy are gates. You can't lurk with an empty profile
   and still get access to people."
3. **4:10** — "I don't write my own progress updates… the feed can't be gamed by
   self-promotion, it only moves when the code moves."

## If something breaks

- **Connect GitHub hangs or errors** — "GitHub is rate-limiting us for a moment"
  — wait, tap again. Twice failing: carry on and show the pulled data from the
  Profile tab instead.
- **Refresh growth posts nothing** — correct behaviour, narrate it as design:
  "no new events in the repo since the last poll, so it posts nothing rather
  than inventing an update."
- **"Cannot reach backend"** — Tailscale is running. Quit it.
- **Screenshot rejected** — you picked a GIF or HEIC. Use a JPG or PNG.
- **Dashboard blank** — you opened `https`. It is `http`.
- **The app doesn't advance after you consented** — it re-reads `/me` when it
  comes back to the foreground, so give it a second. If it still sits there, the
  bind is already done server-side: force-close and reopen, and startup's `/me`
  call moves you to step three.
- **LinkedIn asks for credentials you don't want on camera** — sign in to
  LinkedIn in that browser *before* you start recording, so the consent screen
  is all that appears.

## Do not skip

The avatar (2:40) and the screenshot (3:40) are the only two places this video
shows image binary data — an explicit line in the 37-mark rubric. Refresh growth
(4:10) is the only third-party AI API. The two GitHub cutaways (0:20, 4:55) are
what make "not self-reported" a demonstration instead of a claim.

**Third-party APIs actually demonstrated:** GitHub REST (0:40), **LinkedIn
OpenID Connect — live, not mocked** (1:20), AWS S3 (2:40, 3:40), AWS Bedrock
(4:10). Name them in the closing.
