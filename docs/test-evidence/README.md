# Real-device test evidence (AWS Device Farm)

Pulled by `.github/scripts/device-farm.sh`. Devices are physical Samsung
handsets in `us-west-2`; the app under test talks to the deployed ALB.

Device Farm deletes run artefacts after 30 days, so they are committed here
rather than left to expire behind a console link.

| Run | Name | Result | Total | Passed | Failed | Device-min |
|---|---|---|---|---|---|---|
| Fuzz crawl | `fuzz-2` | PASSED | 3 | 3 | 0 | 2.05 |

Each folder holds that run's per-device video (`.mp4`), logcat, TCP dump and
screenshot series.

**Instrumentation reports SKIPPED** — Device Farm fails to re-sign the test
package (root cause and the experiments that ruled out the usual causes are
documented in the script). The E2E flows are covered on the emulator tier in
`ci.yml`; this job's real-device value is the fuzz crawl and the offline
network profile.
