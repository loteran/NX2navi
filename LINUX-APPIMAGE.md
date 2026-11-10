# NX2navi – Linux AppImage (unofficial fork)

This fork of [tangerineturtle1/NX2navi](https://github.com/tangerineturtle1/NX2navi) publishes a **Linux AppImage of
the build kit** for each upstream release: one file that builds *Ocarina of Time* (Switch 2, game 1.1.1) natively on
Linux from your own dump. **No game files are in it.**

**Download:** [Releases](../../releases) → `NX2navi-Linux-<version>-x86_64.AppImage`. The release notes say how to
install the packages, build and play.

## What it adds to upstream

Upstream 0.7.0 took this fork's AppImage work in: its releases carry an AppImage of their own, which downloads DLSS on
NVIDIA systems and has a window to install, update and play. This fork's AppImage adds what the `appimage-linux`
branch holds:

- **AMD FSR 3.1 upscaling and frame generation on Linux**, on every GPU (`tools/ffx_linux`: AMD's FidelityFX library
  built for Linux, which AMD ships for Windows only);
- **a toolchain of its own** (`tools/make_linux_toolchain.py`: LLVM, a Steam Runtime 3 sysroot and its libraries), so
  nothing has to be installed: it builds on SteamOS and on distributions whose clang or Vulkan headers are too old.

Once upstream merges them, this fork stops publishing an AppImage.

## How it is kept up to date

`.github/workflows/linux-appimage.yml` runs every day. When upstream has a release this fork has no
`linux-appimage-<version>` release for, it checks out the upstream tag, applies the branch above, takes the button art from the release's app zip, builds the shader
translator and the AppImage, and publishes it as a release. The source it was built from is the `appimage-<version>` branch and the
`linux-appimage-<version>` tag.

If the branch no longer applies on the new release, the workflow stops and opens an issue here: rebase it on the
upstream tag, push it, and run the workflow again from the Actions tab (*Run workflow*, *force* to rebuild).

The `main` branch stays a copy of upstream; this branch (`linux-appimage`) is the fork's default branch only so that
GitHub runs the schedule.
