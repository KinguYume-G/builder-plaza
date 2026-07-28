# Segment 1 — Liu Wei · Builder — speaking script

~5 minutes. Read the **Say** column close to verbatim; it is written to be
spoken. The **Do** column is what your hands are doing while you say it.

## Before you hit record

1. Uninstall the old app; install `app-arm64-v8a-release.apk` from
   [`manual-b8712a4`](https://github.com/KinguYume-G/builder-plaza/releases/tag/manual-b8712a4).
2. **Quit Tailscale.**
3. Open the dashboard on the laptop and let it finish loading (~20s):
   `http://builder-plaza-alb-270417897.ap-southeast-1.elb.amazonaws.com:8080`
4. Reset your own onboarding flag so Connect GitHub works with your real
   account instead of returning 409:

   ```bash
   cd backend && .venv/bin/python -c "
   from app.core.config import settings
   from sqlalchemy import create_engine, text
   e = create_engine(settings.database_url)
   with e.begin() as c:
       print('reset:', c.execute(text(\"update users set onboarding_complete = false where github_login = 'SunflowersLwtech'\")).rowcount)
   "
   ```

   This keeps all your existing data — it only sends you back through
   onboarding so the Trust Gateway pulls **your** repos live on camera.
5. Have a photo ready in the gallery for the avatar, and a screenshot ready for
   the project card.
6. Dry-run steps 1 and 10 once. GitHub's API has timed out at 10s before, and
   Refresh growth posts nothing if the linked repo has no new events.

**Do not run `seed.py`.**

---

## Script

| Time | Do | Say |
|---|---|---|
| 0:00 | Face to camera | "Hi, I'm Liu Wei, TP085412. I built the Builder side of Builder Plaza, so I'll demo the journey of someone who has a project and needs collaborators. On the right is a live view of our production database — row counts and the actual rows, refreshing every five seconds." |
| 0:20 | App open at Step 1, type your GitHub username, tap **Connect GitHub** | "Step one of the Trust Gateway. I type my GitHub username, and everything you're about to see is fetched live from GitHub's API — my repositories, my languages, my stars. Nothing on this profile is typed in by me." |
| 0:45 | Point at the summary; then at `users` on the dashboard | "There's my footprint. And on the right, `users` just went up by one — that's this account being written to the database as I speak." |
| 1:00 | Step 2, LinkedIn | "Step two is professional identity. This is our **simulated** LinkedIn screen — it's watermarked, deliberately, because this is a class project. The real OpenID Connect flow sits behind the same interface." |
| 1:15 | Step 3 → **Builder** | "Step three picks my lens. Builder. It's the same app for every role — the role decides what you lead with." |
| 1:30 | Profile tab → completeness bar | "This is profile completeness. The forty and seventy marks are gates: at forty I can be contacted, at seventy I enter matching. That's deliberate — you can't lurk with an empty profile and still get access to people." |
| 1:50 | Tap avatar → pick a photo | "Avatar upload. The image goes straight to object storage on S3 — it never sits in the database — and the profile stores only the key." |
| 2:10 | Home → **edit** intent → save | "And this is the piece that no other tool has. GitHub shows what I built, LinkedIn shows who I am — neither says whether I'm open to collaborate *right now*. `intents` on the right just changed." |
| 2:30 | ＋ **New project** — title, stage, needs, team division, link a real `owner/repo` | "Now the project card. Title, stage, what I need, how the work is split, and I link a real repository. This card is what a collaborator will actually judge me on." |
| 3:00 | Tap **Create project**; point at `project_cards` | "`project_cards` just went from N to N plus one, and the row is right there — my title, my repo." |
| 3:10 | **＋ Add screenshot** → pick an image | "Screenshots go to S3 the same way as the avatar, through a pre-signed upload. Watch the shots column — that's binary image data landing against this project." |
| 3:30 | View project → scroll to repo activity | "On the project page, this is live activity from the repository I linked — commits and issues, straight from GitHub." |
| 3:50 | Tap **Refresh growth** | "And this is the part I'm proudest of. I don't write my own progress updates. It polls my repo for new events and an AI model on AWS Bedrock writes a neutral summary. That means the feed can't be gamed by self-promotion — it only moves when the code moves." |
| 4:15 | Point at `growth_posts`, then Plaza → **GROWTH** | "`growth_posts` plus one, and here it is publicly in the Plaza growth feed. Same text." |
| 4:35 | Profile → **Verified activity & evidence** | "Last thing. A twelve-week continuity chart, the roles I hold on my own repositories, and a typed event timeline — all derived from public GitHub events. Again: none of it self-reported." |
| 4:55 | Face to camera | "That's the builder's side: verified work, a live project card, and progress that reports itself. That card is now in the Plaza — Gao Xing picks it up from there." |

---

## If something breaks

- **Connect GitHub hangs or errors** — "GitHub's API is rate-limiting us for a
  moment" — wait, tap again. If it fails twice, carry on to the LinkedIn step
  and mention you'll show the profile data from the Profile tab instead.
- **Refresh growth posts nothing** — that's correct behaviour when the repo has
  no new events. Say so: "nothing new in the repo since the last poll, so it
  posts nothing rather than inventing an update" — that is a design point, not
  a failure.
- **App says "Cannot reach backend"** — Tailscale is running. Quit it.
- **Screenshot upload rejected** — you picked a GIF or HEIC; pick a JPG or PNG.

## Do not skip

The avatar (1:50) and the screenshot (3:10) are the only two places the video
shows image binary data, which is an explicit line in the 37-mark rubric.
Refresh growth (3:50) is the only place a third-party AI API appears.
