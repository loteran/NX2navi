# NX2navi – Linux AppImage (unofficial fork)

This fork of [tangerineturtle1/NX2navi](https://github.com/tangerineturtle1/NX2navi) publishes a **Linux AppImage of
the build kit** for each upstream release: one file that builds *Ocarina of Time* (Switch 2, game 1.1.1) natively on
Linux from your own dump. **No game files are in it.**

**Download:** [Releases](../../releases) → `NX2navi-Linux-<version>-x86_64.AppImage`. The release notes say how to
install the packages, build and play.

## What it adds to upstream

| Branch | What | Upstream pull request |
|---|---|---|
| `linux-make-game` | the Linux build (`tools/make_game.py`, the AppImage packer, the #72 runtime fix) | [#108](https://github.com/tangerineturtle1/NX2navi/pull/108) |
| `playstation-prompts` | PlayStation and Steam Deck button prompts | [#107](https://github.com/tangerineturtle1/NX2navi/pull/107) |
| `xlate-sm86-fixes` | every shader translated (20 failures to 0) | [#106](https://github.com/tangerineturtle1/NX2navi/pull/106) |

Once upstream merges them, the AppImage is simply upstream's kit.

## How it is kept up to date

`.github/workflows/linux-appimage.yml` runs every day. When upstream has a release this fork has no
`linux-appimage-<version>` release for, it checks out the upstream tag, merges the three branches, builds the shader
translator and the AppImage, and publishes it as a **pre-release** (it is built without the game, so nothing runs the
game until someone tries it). The source it was built from is the `appimage-<version>` branch and the
`linux-appimage-<version>` tag.

If a branch no longer applies on the new release, the workflow stops and opens an issue here: rebase that branch on the
upstream tag, push it, and run the workflow again from the Actions tab (*Run workflow*, *force* to rebuild).

The `main` branch stays a copy of upstream; this branch (`linux-appimage`) is the fork's default branch only so that
GitHub runs the schedule.
