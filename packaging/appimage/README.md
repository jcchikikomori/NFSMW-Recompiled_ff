# NFS Most Wanted ARM64 AppImage

The AppImage contains the native launcher, recompiled game executable,
ReXGlue runtime/GPU libraries, Qt 6 and an ARM64 `extract-xiso`. It never
contains copyrighted game files.

## Build dependencies

- AArch64 Linux host
- CMake 3.25+, Clang and Qt 6.4 development packages
- `linuxdeploy`, `linuxdeploy-plugin-qt` and `appimagetool` for AArch64
- Git and an internet connection for the pinned `extract-xiso` source

Build the game (see project docs), then the launcher:

```bash
cd app
cmake --preset linux-arm64-release -DNFSMW_BUILD_LAUNCHER=ON
cmake --build --preset linux-arm64-release --target nfsmw nfsmw_launcher
```

Or, if you already configured into `app/build`:

```bash
cmake -S app -B app/build -DNFSMW_BUILD_LAUNCHER=ON
cmake --build app/build --parallel --target nfsmw_launcher
```

Create the AppImage from the repository root:

```bash
LINUXDEPLOY=/path/to/linuxdeploy-aarch64.AppImage \
APPIMAGETOOL=/path/to/appimagetool-aarch64.AppImage \
PATH="/path/to/linuxdeploy-plugin-qt:$PATH" \
packaging/appimage/build-appimage-arm64.sh
```

Artifact: `app/build/NFSMW-aarch64.AppImage`.

Override `NFSMW_BIN`, `LAUNCHER_BIN`, `RUNTIME_LIB`, `GPU_LIB` or
`EXTRACT_XISO_BIN` if the artifacts are in other locations.

## GitHub Actions (CI)

The workflow `.github/workflows/linux-appimage.yml` builds a **launcher-only**
x86_64 AppImage on `ubuntu-24.04`:

```bash
cmake -S app -B app/build -DNFSMW_BUILD_GAME=OFF -DNFSMW_BUILD_LAUNCHER=ON
cmake --build app/build --target nfsmw_launcher
packaging/appimage/build-appimage-launcher.sh
```

Artifact: `app/build/NFSMW-Launcher-x86_64.AppImage`. It contains the Qt 6
launcher, the Qt runtime, `extract-xiso`, the desktop file and the icon.
`NFSMW_BUILD_GAME=OFF` skips the `generated/rexglue.cmake` include, the game
target and the `rexglue_setup_target` call, so no ReXGlue SDK is needed.

The full game AppImage (`build-appimage-arm64.sh`) needs the recompiled game
executable. That executable embeds the translated game code, which the ReXGlue
codegen can only produce from the copyrighted Xbox 360 XEX, so it cannot be
built in public CI. The launcher AppImage therefore ships without the game
binary; build it locally with the game enabled (the default) as described
above.

## Runtime

On first launch, choose a writable root folder. The launcher creates:

```text
root/
  game/       # Imported Xbox 360 files, including default.xex
  config/     # Launcher settings
  saves/
  cache/
  logs/
```

The game can be imported from an original Xbox 360 ISO or pointed at an
already extracted directory containing `default.xex` (for example
`assets/game_root` from a local build).

If FUSE is unavailable:

```bash
APPIMAGE_EXTRACT_AND_RUN=1 ./NFSMW-aarch64.AppImage
```

The host must provide a working Vulkan driver. Turnip/Mesa is intentionally
not bundled.
