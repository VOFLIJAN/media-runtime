# media-runtime

Build scripts for a set of media libraries (macOS, arm64).

Components, built from unmodified upstream sources unless a patch is listed in `patches/` or `download.sh`:

- mpv 0.41.0 (GPL-2.0-or-later) - https://github.com/mpv-player/mpv
- libplacebo (LGPL-2.1-or-later) - https://code.videolan.org/videolan/libplacebo
- libdovi (MIT) - https://github.com/quietvoid/dovi_tool
- FFmpeg (GPL-2.0-or-later as configured) - https://ffmpeg.org
- dav1d (BSD-2-Clause) - https://code.videolan.org/videolan/dav1d
- MoltenVK (Apache-2.0) - https://github.com/KhronosGroup/MoltenVK
- other dependencies via vcpkg, see `vcpkg-ports/`

Released archives are built by the workflow in `.github/workflows/`. The complete corresponding source is these scripts and patches together with the upstream sources at the versions pinned in them. This repository is distributed under GPL-3.0, see `LICENSE`.

Build locally:

```bash
bash ./install-vcpkg-deps.sh && bash ./download.sh && bash ./build-libdovi.sh && bash ./build-libplacebo.sh && bash ./build-macos.sh
bash ./package-macos-runtime.sh --pkg-name runtime-local-macos
```
