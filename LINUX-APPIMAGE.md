# NX2navi – Linux AppImage (unofficial fork)

This fork of [tangerineturtle1/NX2navi](https://github.com/tangerineturtle1/NX2navi) publishes a **Linux AppImage of
the build kit** for each upstream release: one file that builds *Ocarina of Time* (Switch 2, game 1.1.1) natively on
Linux from your own dump. **No game files are in it.**

**Download:** [Releases](../../releases) → `NX2navi-Linux-<version>-x86_64.AppImage`. The release notes say how to
install the packages, build and play.

## What it adds to upstream

Upstream 0.6.0 took this fork's work in: the Linux build and `tools/make_appimage.py`, every shader translated, and
button prompts. What is left is publishing the AppImage itself, which upstream releases do not do yet:

| Branch | What | Upstream pull request |
|---|---|---|
| `appimage-release` | a workflow that attaches the AppImage to each release, and the button art in the AppImage | [#273](https://github.com/tangerineturtle1/NX2navi/pull/273) |
| `appimage-dlss` | on NVIDIA systems, the AppImage downloads NVIDIA's DLSS for Linux beside the game (DLSS upscaling) | not yet |

Once upstream merges it, its own releases carry the AppImage and this fork stops publishing one.

## How it is kept up to date

`.github/workflows/linux-appimage.yml` runs every day. When upstream has a release this fork has no
`linux-appimage-<version>` release for, it checks out the upstream tag, applies the branch above, takes the button art from the release's app zip, builds the shader
translator and the AppImage, and publishes it as a **pre-release** (it is built without the game, so nothing runs the
game until someone tries it). The source it was built from is the `appimage-<version>` branch and the
`linux-appimage-<version>` tag.

If the branch no longer applies on the new release, the workflow stops and opens an issue here: rebase it on the
upstream tag, push it, and run the workflow again from the Actions tab (*Run workflow*, *force* to rebuild).

The `main` branch stays a copy of upstream; this branch (`linux-appimage`) is the fork's default branch only so that
GitHub runs the schedule.
