# Legal posture

## What this repo contains and doesn't contain

This repo contains infrastructure-as-code only: a Dockerfile, a startup script, a Wolf app-config snippet, a compose file, and documentation. It does **not** contain:

- Any Grand Theft Auto: Vice City game data (audio, models, textures, scripts, executables).
- Any compiled reVC binary.
- Any Rockstar / Take-Two property of any kind.

The Dockerfile **builds** the reVC engine from source at image build time. It does not redistribute it.

## Grand Theft Auto: Vice City

To run anything here, you must supply your own legitimately-acquired copy of GTA: Vice City — for example, by purchasing it on Steam and pointing the build at `~/.steam/steam/steamapps/common/Grand Theft Auto Vice City`. The game data files are copyright Take-Two Interactive / Rockstar Games and are licensed to you under whichever EULA you accepted when buying the game. Nothing in this repo grants any rights to that content.

## reVC and re3

reVC is the Vice City branch of the [re3](https://en.wikipedia.org/wiki/Re3_\(GTA\)) project — a clean-room reverse-engineering of the original game engine, published as open source. The original GitHub repo was taken down via DMCA by Take-Two in February 2021. Numerous public mirrors of the pre-takedown source code exist; the Dockerfile in this repo fetches one of them from `archive.org`.

The legal status of reverse-engineered game engines is a long-standing grey area. The original re3 contributors maintained that the code was a clean-room reimplementation. Take-Two disagreed. There has been no court ruling on the merits. Use this repo at your own risk, in your own jurisdiction.

If you are uncomfortable with the bundled URL, the Dockerfile is short enough to read and re-target at any alternative mirror or local source tarball.

## Wolf

[Wolf](https://github.com/games-on-whales/wolf) (`games-on-whales/wolf`) is a Moonlight-protocol streaming server licensed under the MIT License. This repo uses Wolf's prebuilt images and follows their public base-app contract for custom app integration. No Wolf source code is included here.

## This repo's license

The Dockerfile, startup.sh, TOML snippet, compose file, README, and other infrastructure files in this repository are released under the MIT License — see [LICENSE](LICENSE). That license applies only to those files.
