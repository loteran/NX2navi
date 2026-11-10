#!/bin/bash
# Builds the Linux AppImage of an upstream NX2navi release with this fork's Linux branches applied, and publishes it
# as a release of this fork (GitHub marks the newest version Latest). Run by .github/workflows/linux-appimage.yml; needs GH_TOKEN, git, uv and the .NET SDK.
#
#   build-linux-appimage.sh <upstream tag or "latest"> <force: true|false> [publish: true|false]
#
# With publish false the AppImage is only built into $RUNNER_TEMP/nx2navi-appimage/dist (the workflow keeps it as an
# artifact): nothing is pushed or released, and an existing release does not stop the build.
#
# No game files are involved: the AppImage holds the build kit only, and each player builds the game from their dump.
set -euo pipefail

UPSTREAM=tangerineturtle1/NX2navi
FORK="${GITHUB_REPOSITORY:-loteran/NX2navi}"
# Branches of this fork whose own commits (those not in upstream main) are cherry-picked onto the upstream tag, in
# order. Upstream 0.7.0 took the release workflow, the DLSS download and the window in; what is left is
# appimage-linux: AMD FSR 3.1 upscaling and frame generation on Linux (tools/ffx_linux) and the toolchain the AppImage
# carries (tools/make_linux_toolchain.py), so nothing has to be installed. A commit the tag already has is skipped.
BRANCHES=(appimage-linux)
WORK="${RUNNER_TEMP:-/tmp}/nx2navi-appimage"

want="${1:-latest}"
force="${2:-false}"
publish="${3:-true}"
if [ "$want" = latest ] || [ -z "$want" ]; then
    tag=$(gh release view -R "$UPSTREAM" --json tagName --jq .tagName)
else
    tag="$want"
fi
version="${tag#v}"
release="linux-appimage-$version"
echo "upstream $tag -> $FORK release $release"

# Upstream releases carry an AppImage of their own since 0.7.0; this fork's adds what appimage-linux holds, and stops
# once upstream has all of it (below).

if [ "$publish" = true ] && gh release view "$release" -R "$FORK" >/dev/null 2>&1; then
    if [ "$force" != true ]; then
        echo "$release already exists: nothing to do"
        exit 0
    fi
    echo "$release exists; force: building it again"
fi

conflict_issue() {   # $1: branch, $2: conflicting files
    local title="Linux AppImage $version: $1 does not apply on upstream $tag"
    if gh issue list -R "$FORK" --state open --search "\"$title\" in:title" --json number --jq '.[0].number' | grep -q .; then
        echo "an issue for this conflict is already open"
        return
    fi
    gh issue create -R "$FORK" --title "$title" --body "$(cat <<EOF
The scheduled AppImage build stopped: the branch \`$1\` conflicts with upstream \`$tag\` in:

\`\`\`
$2
\`\`\`

Rebase \`$1\` on \`$tag\` (or drop it if upstream merged it), push it, then run the *Linux AppImage* workflow again
(Actions tab, *Run workflow*, with *force* if needed). Run: ${GITHUB_SERVER_URL:-https://github.com}/$FORK/actions/runs/${GITHUB_RUN_ID:-}
EOF
)"
}

rm -rf "$WORK"
git clone -q --filter=blob:none "https://github.com/$UPSTREAM.git" "$WORK/src"
cd "$WORK/src"
git -c advice.detachedHead=false checkout -q "$tag"
git switch -q -c "appimage-$version"
git remote add fork "https://x-access-token:${GH_TOKEN}@github.com/$FORK.git"
git fetch -q fork "${BRANCHES[@]}"
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

applied=()
for b in "${BRANCHES[@]}"; do
    # the branch's commits that upstream main lacks, minus those the tag has as an equivalent patch
    picks=$(git log --reverse --format=%H "origin/main..fork/$b")
    picks=$(for c in $picks; do git cherry HEAD "$c" "$c^" | awk '$1 == "+" {print $2}'; done)
    if [ -z "$picks" ]; then
        echo "$b: already in $tag"
        continue
    fi
    if ! git cherry-pick -x $picks >/dev/null; then
        files=$(git diff --name-only --diff-filter=U)
        git cherry-pick --abort
        [ "$publish" = true ] && conflict_issue "$b" "$files"
        echo "::error::$b conflicts with $tag: $files"
        exit 1
    fi
    applied+=("$b $(git rev-parse --short "fork/$b")")
done
if [ ${#applied[@]} -eq 0 ]; then
    echo "every branch is upstream already: upstream's own AppImage is the same, nothing to publish here"
    exit 0
fi

# The shader translator (NativeAOT, .NET 10), the pinned VMA header, a relocatable CPython 3.14, appimagetool.
uv venv -q --python 3.12 .venv
uv pip install -q --python .venv/bin/python pillow
.venv/bin/python tools/build_xlate.py
.venv/bin/python -c 'import sys; sys.path.insert(0, "tools"); import build_game; print("VMA:", build_game.vma_include())'
uv python install -q 3.14
python314=$(find "$(uv python dir)" -maxdepth 1 -type d -name 'cpython-3.14.*-linux-x86_64-gnu' | sort -V | tail -1)
[ -x "$python314/bin/python3" ] || { echo "::error::no relocatable CPython 3.14 from uv"; exit 1; }
# the button art make_game.py's prompts step draws from: the release's own app zip carries it
art=()
if gh release download "$tag" -R "$UPSTREAM" -p 'NX2navi-app-*.zip' -D "$WORK/app" 2>/dev/null &&
   unzip -q "$WORK"/app/NX2navi-app-*.zip 'prompt-art/*' -d "$WORK/app" 2>/dev/null; then
    art=(--prompt-art "$WORK/app/prompt-art")
else
    echo "::warning::no prompt-art in upstream $tag's app zip: builds keep the Switch prompts"
fi
curl -fsSL -o "$WORK/appimagetool" \
    https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x "$WORK/appimagetool"
export APPIMAGE_EXTRACT_AND_RUN=1   # no FUSE on the runner

# The toolchain the AppImage carries (LLVM, the Steam Runtime sysroot, its libraries), then AMD FSR 3.1 for Linux
# built with it, so that both need no newer glibc than 2.31
sudo apt-get install -y -qq glslc spirv-tools glslang-tools meson nasm ninja-build cmake libvulkan-dev >/dev/null
.venv/bin/python tools/make_linux_toolchain.py --out "$WORK/linux-toolchain"
NX2NAVI_LINUX_TOOLCHAIN="$WORK/linux-toolchain" tools/ffx_linux/build.sh "$WORK/ffx" "$WORK/dl"
.venv/bin/python tools/make_appimage.py --python "$python314" --appimagetool "$WORK/appimagetool" --out "$WORK/dist" \
    "${art[@]+"${art[@]}"}" --ffx "$WORK/ffx" --linux-toolchain "$WORK/linux-toolchain"
appimage="$WORK/dist/NX2navi-Linux-$version-x86_64.AppImage"
"$appimage" --help | head -3   # the AppImage starts
(cd "$WORK/dist" && sha256sum "$(basename "$appimage")" > SHA256SUMS && cat SHA256SUMS)

if [ "$publish" != true ]; then
    echo "publish false: built $appimage, nothing pushed or released"
    exit 0
fi

# What the AppImage was built from: a branch and a tag on this fork.
git push -q -f fork "HEAD:refs/heads/appimage-$version"
git tag -f "$release" >/dev/null
git push -q -f fork "refs/tags/$release"

sum=$(cut -d' ' -f1 "$WORK/dist/SHA256SUMS")
list=""
for a in "${applied[@]+"${applied[@]}"}"; do list+="- \`${a%% *}\` (${a##* })"$'\n'; done
[ -n "$list" ] || list="- none: upstream $tag already has them"$'\n'
notes=$(cat <<EOF
An unofficial Linux build kit for **NX2navi $version**, built automatically from upstream [\`$tag\`](https://github.com/$UPSTREAM/releases/tag/$tag): it builds *The Legend of Zelda: Ocarina of Time* (Nintendo Switch 2, game 1.1.1) as a native Linux program **on your PC, from your own dump**. **No game files are included.**

Branches of this fork applied on top of \`$tag\`:
$list
What this AppImage adds to upstream's own (\`NX2navi-Linux-$version-x86_64.AppImage\` on [upstream's release](https://github.com/$UPSTREAM/releases/tag/$tag)):

- **AMD FSR 3.1 upscaling and frame generation on Linux**, on every GPU: Screen tab → *Upscaling* AMD FSR 3.1, then *Frame generation* AMD FSR 3.1.
- **Nothing to install**: the AppImage carries its compiler (LLVM 23) and libraries (Steam Runtime 3), so it builds on SteamOS, Linux Mint and any distribution with glibc 2.31 or later, without packages or developer mode.

## Use

1. Make the AppImage executable and start it (double-click, or from a terminal):
   \`\`\`sh
   chmod +x NX2navi-Linux-$version-x86_64.AppImage
   ./NX2navi-Linux-$version-x86_64.AppImage
   \`\`\`
   A window asks for your \`.nup\` dump and the game folder, builds the game (10 to 25 minutes, once) and plays it; later versions update it. From a terminal: \`./NX2navi-Linux-$version-x86_64.AppImage "/path/to/your game.nup" [game folder]\` (default \`~/Games/Ocarina\`). If it stops, run it again: finished steps are skipped.
2. Play: from the window, or \`~/Games/Ocarina/play.sh\`. **F1** opens the settings.

The first run installs \`zbic\` (GPL-2.0) with pip, so it needs the internet once. Requirements: x86-64 Linux 6.7+, 16 GB of RAM, about 30 GB free, a Vulkan 1.3 GPU with \`VK_EXT_external_memory_host\` and \`VK_EXT_mesh_shader\`.

Everything the build writes comes from your game: keep it to yourself. NX2navi is an independent, non-commercial fan project, not affiliated with or endorsed by Nintendo.

\`SHA256SUMS\`: \`$sum  NX2navi-Linux-$version-x86_64.AppImage\`
EOF
)
if gh release view "$release" -R "$FORK" >/dev/null 2>&1; then
    gh release upload "$release" -R "$FORK" --clobber "$appimage" "$WORK/dist/SHA256SUMS"
    gh release edit "$release" -R "$FORK" --notes "$notes"
else
    gh release create "$release" -R "$FORK" --verify-tag \
        --title "NX2navi $version – Linux AppImage (unofficial, automatic)" --notes "$notes" \
        "$appimage" "$WORK/dist/SHA256SUMS"
fi
echo "published $release"
