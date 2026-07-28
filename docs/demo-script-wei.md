# Segment 1 — Liu Wei · Builder — final script

~5 minutes. Read the **Say** column close to verbatim. The **Do** column is what
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

## Script

| Time | Scene | Do | Say |
|---|---|---|---|
| 0:00 | B | To camera | "Hi, I'm Liu Wei, TP085412. I built the Builder side of Builder Plaza, so I'll demo the journey of someone who has a project and needs collaborators. On the right is a live view of our production database — refreshing every five seconds, so you can watch it change as I go." |
| 0:20 | **→ A** | GitHub profile in the browser, scroll the repo list | "Before I touch the app: this is my actual GitHub account. These are my repositories, these are the languages, this is the activity. Remember what you're seeing." |
| 0:40 | A | Phone: type your username → **Connect GitHub** | "Now step one of the Trust Gateway. I type that same username, and the app calls GitHub's API directly." |
| 1:00 | A | Point between the app summary and the browser | "Same repositories. Same languages. Same counts. I never typed any of this into the app — it fetched it. That's the whole premise: your credibility comes from your work, not from what you claim about yourself." |
| 1:20 | **→ B** | Step 2, LinkedIn | "Step two, professional identity. This screen is **simulated** and watermarked, deliberately, because this is a class project — the real OpenID Connect flow sits behind the same interface." |
| 1:35 | B | Step 3 → **Builder** | "Step three picks my lens. Builder. Same app for every role — the role decides what you lead with." |
| 1:45 | B | Profile tab → completeness bar | "Profile completeness, and notice it's starting from empty — this account is brand new. Forty and seventy are gates: at forty I can be contacted, at seventy I enter matching. You can't lurk with an empty profile and still get access to people." |
| 2:05 | B | Tap avatar → pick a photo | "Avatar upload. The image goes straight to S3 object storage — it never sits in the database — and the row stores only the key." |
| 2:25 | B | Home → **edit** intent → save | "And this is the piece no other tool has. GitHub shows what I built, LinkedIn shows who I am — neither says whether I'm open to collaborate *right now*. Watch `intents` on the right." |
| 2:45 | B | ＋ **New project** — title, stage, needs, team division, link a real repo | "My first project card. Title, stage, what I need, how the work splits, and I link a real repository. This card is what a collaborator will actually judge me on." |
| 3:10 | B | **Create project**; point at `project_cards` | "`project_cards` just went up by one, and there's the row — my title, my repo." |
| 3:20 | B | **＋ Add screenshot** → pick an image | "Screenshots go to S3 the same way, through a pre-signed upload. Watch the shots column — binary image data landing against this project." |
| 3:40 | B | View project → repo activity | "On the project page: live commits and issues from the repository I linked." |
| 3:55 | B | Tap **Refresh growth** | "And the part I'm proudest of. I don't write my own progress updates. It polls the repo for new events and an AI model on AWS Bedrock writes a neutral summary. The feed can't be gamed by self-promotion — it only moves when the code moves." |
| 4:15 | B | Point at `growth_posts`, then Plaza → **GROWTH** | "`growth_posts` plus one, and here it is publicly in the Plaza. Same text." |
| 4:30 | B | Profile → **Verified activity & evidence** | "Last thing. A twelve-week continuity chart, the roles I hold on my own repositories, a typed event timeline." |
| 4:40 | **→ A** | GitHub profile → contribution graph, next to the app's chart | "And back to the real GitHub. Same public events, same shape. Nothing on that profile is self-reported — it's derived from this." |
| 4:55 | A | To camera | "That's the builder's side: verified work, a live project card, and progress that reports itself. The card is now in the Plaza — Gao Xing picks it up from there." |

---

## The three sentences that carry the marks

Everything else is navigation. These are the design arguments:

1. **1:00** — "Same repositories, same languages, same counts. I never typed any
   of this into the app."
2. **1:45** — "Forty and seventy are gates. You can't lurk with an empty profile
   and still get access to people."
3. **3:55** — "I don't write my own progress updates… the feed can't be gamed by
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

## Do not skip

The avatar (2:05) and the screenshot (3:20) are the only two places this video
shows image binary data — an explicit line in the 37-mark rubric. Refresh growth
(3:55) is the only third-party AI API. The two GitHub cutaways (0:20, 4:40) are
what make "not self-reported" a demonstration instead of a claim.
