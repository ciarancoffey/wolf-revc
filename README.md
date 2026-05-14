# wolf-revc

Stream **Grand Theft Auto: Vice City** (via the open-source [reVC](https://en.wikipedia.org/wiki/Re3_\(GTA\)) engine) from a Linux host to any [Moonlight](https://moonlight-stream.org/) client — phone, tablet, Steam Deck, Nvidia Shield, etc. — using [Wolf](https://github.com/games-on-whales/wolf) as the streaming server.

Everything runs in containers. The streaming host needs Docker, an Intel/AMD/NVIDIA GPU with `/dev/dri`, and a copy of GTA: Vice City you already own.

This is a worked example of integrating a single-binary native Linux game into Wolf's custom-app system. The pattern (`base-app` → bake-the-binary → drop `startup-app.sh`) generalises to other games with light edits.

> [!IMPORTANT]
> No game data, soundtrack, or compiled binaries are shipped in this repo. You provide your own legitimate copy of GTA: VC. See [LEGAL.md](LEGAL.md) for the full posture, including the reVC DMCA history and the archive.org bundle used at build time.

## Topology

```
build host                              streaming host                                client
─────────────                           ──────────────────────────────                ──────────────
                                                                                       
  ./wolf-revc/                          docker compose: wolf
    Dockerfile          docker save     ┌──────────────────────────┐
    startup.sh    ──────────────────▶   │ Wolf (Moonlight server,  │      Moonlight
    docker-compose.wolf.yml             │  VAAPI/NVENC encoder,    │ ◀══ protocol ══▶  Moonlight app
    revc-app.toml.snippet               │  gstreamer, mDNS, pairs) │   47984/47989,    on phone /
                                        └────────────┬─────────────┘   47999, 48010,   tablet / Shield
                                                     │ docker exec      48100, 48200    + a gamepad
  GTA:VC Steam install   ───tar|ssh──▶   $HOME/.reVC ├─► WolfReVC_<sess>  spawned       
  (Audio/, models/,                                  │     per stream:                  
   anim/, data/, …)                                  │   - base-app:edge                
                                                     │     (Sway, Xwayland, Mesa)       
                                                     │   - /opt/revc/reVC + librw       
                                                     │   - /assets ◀ bind $HOME/.reVC   
                                                     │   - startup-app.sh syncs         
                                                     │     reVC.ini Width/Height to     
                                                     │     GAMESCOPE_WIDTH/HEIGHT       
                                                     │                                  
                                                     └─► WolfPulseAudio sidecar (audio)
```

## Requirements

**Build host** (where you `docker build`):
- Docker (with BuildKit, which is on by default in recent Docker versions)
- ~2 GB free for the build (librw + reVC compile)

**Streaming host** (where Wolf and the spawned app containers run):
- Linux, kernel 5.x+
- Docker
- A GPU with `/dev/dri` (Intel iGPU, AMD, or NVIDIA — Wolf handles all three; this repo's recipe is Intel/AMD-flavoured, NVIDIA users adapt the Wolf compose per Wolf's docs)
- The `uinput` and `uhid` kernel modules (built-in on most distros)
- Network reachability to your Moonlight client(s)

**Client**: any current Moonlight build. Tested on Moonlight Android (Nvidia Shield).

**Game**: a copy of GTA: Vice City you legitimately own — Steam version recommended. Pre-2012 Steam purchases retain the full original soundtrack (Michael Jackson, Iron Maiden, etc.) which the licence cull removed from later versions.

## Quick start

Throughout, `STREAM_HOST` is the IP/hostname of the box that will run Wolf, and `STREAM_USER` is the Linux user there (must match a real local account; UID 1000 is assumed throughout to match the `retro` user inside Wolf's containers).

```bash
# 1. clone this repo on your build host
git clone https://github.com/ciarancoffey/wolf-revc && cd wolf-revc

# 2. build the wolf-revc image (compiles librw + reVC from source — a few minutes)
docker build -t wolf-revc:local .

# 3. ship the image to the streaming host
docker save wolf-revc:local | ssh $STREAM_USER@$STREAM_HOST 'docker load'

# 4. send your game data to the streaming host
#    (point at wherever Steam installed Vice City)
GAME=~/.steam/steam/steamapps/common/Grand\ Theft\ Auto\ Vice\ City
ssh $STREAM_USER@$STREAM_HOST 'mkdir -p ~/.reVC'
tar -C "$GAME" -cf - . | ssh $STREAM_USER@$STREAM_HOST 'tar -C ~/.reVC -xf -'

# 5. drop Wolf's udev rule on the streaming host
scp 85-wolf.rules $STREAM_USER@$STREAM_HOST:/tmp/    # fetch from games-on-whales/wolf
ssh $STREAM_USER@$STREAM_HOST 'sudo install -m 644 /tmp/85-wolf.rules /etc/udev/rules.d/85-wolf.rules \
    && sudo udevadm control --reload-rules && sudo udevadm trigger'

# 6. stand up Wolf
scp docker-compose.wolf.yml $STREAM_USER@$STREAM_HOST:~/wolf/docker-compose.yml
ssh $STREAM_USER@$STREAM_HOST 'sudo mkdir -p /etc/wolf && sudo chown $(id -u):$(id -g) /etc/wolf \
    && cd ~/wolf && docker compose up -d'

# 7. wire the GTA:VC app into Wolf's config
#    edit revc-app.toml.snippet first: replace <HOME> with /home/$STREAM_USER
sed "s|<HOME>|/home/$STREAM_USER|g" revc-app.toml.snippet | \
    ssh $STREAM_USER@$STREAM_HOST 'sudo tee -a /etc/wolf/cfg/config.toml > /dev/null'
ssh $STREAM_USER@$STREAM_HOST 'docker restart wolf'

# 8. pair Moonlight (on the client): add server $STREAM_HOST, follow PIN flow,
#    URL is in `docker logs wolf` after you initiate pairing from the client.
```

After pairing, "GTA: Vice City" shows up in Moonlight alongside Wolf UI and the default demo apps.

## Alternative: build in place, fold into an existing Docker stack

If you already run a monolithic `docker-compose.yml` for your homelab, you can skip the `docker save | ssh | docker load` step entirely and build the image directly on the streaming host. Add two services to your existing compose:

```yaml
services:
  # ... your existing services ...

  wolf:
    image: ghcr.io/games-on-whales/wolf:stable
    container_name: wolf
    restart: unless-stopped
    network_mode: host
    volumes:
      - /mnt/docker_volumes/wolf:/etc/wolf          # or wherever you keep service config
      - /var/run/docker.sock:/var/run/docker.sock:rw
      - /dev/:/dev/:rw
      - /run/udev:/run/udev:rw
    device_cgroup_rules:
      - "c 13:* rmw"
    devices:
      - /dev/dri
      - /dev/uinput
      - /dev/uhid

  wolf-revc:
    build: ./wolf-revc
    image: wolf-revc:local
    profiles: ["build"]   # never started by `compose up`; only built explicitly
```

Place the build inputs next to that compose file:

```
<your-compose-dir>/
├── docker-compose.yml
└── wolf-revc/
    ├── Dockerfile
    └── startup.sh
```

Build the image: `docker compose build wolf-revc`. The `profiles: ["build"]` keeps it out of `up`/`start` (Wolf launches a fresh container per stream session via the Docker socket — there's no long-running `wolf-revc` container).

For the asset mount, pick whatever location matches your stack's convention (e.g. `/mnt/docker_volumes/wolf-revc/`), point the Wolf TOML's `mounts` at it (`/mnt/docker_volumes/wolf-revc:/assets:rw`), and copy your GTA:VC Steam install there.

Tradeoffs vs the standalone Quickstart:
- (+) No `docker save | ssh | docker load`; the streaming host is the only host.
- (+) Build artifacts live alongside your other Docker images.
- (−) ~1.5 GB of intermediate build layers stay on the streaming host (run `docker builder prune` to reclaim).
- (−) If you don't already have a monolithic compose, the standalone path is simpler.

## How a stream session actually works

1. Moonlight client tells Wolf to launch "GTA: Vice City" over HTTPS (47984).
2. Wolf negotiates resolution / FPS / codec / bitrate with the client.
3. Wolf creates an in-memory Wayland compositor sized to the negotiated stream resolution.
4. Wolf `docker run`s `wolf-revc:local`, injecting env vars like `GAMESCOPE_WIDTH`, `GAMESCOPE_HEIGHT`, `GAMESCOPE_REFRESH`, `WAYLAND_DISPLAY`, `PULSE_SERVER`.
5. Inside the container, `ghcr.io/games-on-whales/base-app` runs its entrypoint chain (`/etc/cont-init.d/*`) and execs `gosu retro /opt/gow/startup.sh`.
6. base-app's `startup.sh` waits for X, then execs `/opt/gow/startup-app.sh` — which is **our** script, baked in by the Dockerfile.
7. Our script syncs `reVC.ini`'s `[VideoMode] Width=/Height=` to the gamescope size, sources `launch-comp.sh`, `cd /assets`, and runs `launcher /opt/revc/reVC` — wrapping reVC in a Sway session.
8. Wolf captures the compositor's framebuffer via DMA-BUF, encodes HEVC (or H.264 / AV1 depending on negotiation) using the host GPU, packetises into the Moonlight protocol, ships to the client over UDP (48100 video / 48200 audio).
9. Gamepad input from the client comes back as UDP control messages (47999); Wolf injects them into the app container via `/dev/uinput`.
10. App exits → `launcher` does `killall sway` → container stops → Wolf tears down the session.

## Resolution

Stream resolution is set by Moonlight on the client (gear → Resolution). Wolf passes the negotiated size into the container as `GAMESCOPE_WIDTH/HEIGHT`. `startup.sh` then rewrites `reVC.ini`'s `[VideoMode]` so reVC's configured mode matches what gamescope offers — without this sync, reVC bails with "Cannot find desired video mode" because it can't find its configured 2560×1440 mode inside a 3840×2160 surface.

**Practical ceiling depends on your GPU.** On an Intel UHD 770 (Raptor Lake iGPU), 1440p60 is comfortable but 4K maxes out the iGPU (render + compositor + HEVC encode all share the same silicon). Pick the lowest resolution that looks good to you — Vice City's PS2-era assets don't benefit much above 1440p anyway.

## Controller

Pair your controller **directly to the Moonlight client** over Bluetooth, not via a 2.4 GHz dongle plugged into the streaming host. Moonlight reads input through the client OS's standard gamepad APIs; it doesn't forward host-side inputs. A controller plugged into the streaming host won't be visible to the game without extra setup.

On Android (Shield), Moonlight Android also can't claim raw USB devices the way Steam Link does, so 2.4 GHz dongles plugged into the Shield often don't work — Bluetooth pairing is the reliable path.

## Common operations

### Rebuild the image after editing the Dockerfile or startup.sh

**Standalone (build on a separate host, ship to streaming host):**
```bash
docker build -t wolf-revc:local .
docker save wolf-revc:local | ssh $STREAM_USER@$STREAM_HOST 'docker load'
```

**Build in place** (Dockerfile + startup.sh at `<compose-dir>/wolf-revc/` on the streaming host):
```bash
ssh $STREAM_USER@$STREAM_HOST 'cd ~/docker && docker compose build wolf-revc'
```
The `profiles: ["build"]` directive on the `wolf-revc` service keeps it out of `up`/`start`; `compose build` targets it explicitly.

### Iterate on startup.sh without rebuilding

Uncomment the optional bind-mount line in `revc-app.toml.snippet` (or in `/etc/wolf/cfg/config.toml` on the streaming host) so the host's `startup.sh` overrides the baked-in copy. Then `scp` changes whenever you edit — no Wolf restart, no image rebuild. Re-comment when you're done iterating.

### Inspect a failed launch

Spawned per-session app containers are named `WolfReVC_<session-uuid>` and Wolf removes them almost immediately on exit, which makes `docker logs WolfReVC_*` impractical. The included `startup.sh` tees its output to `/assets/wolf-revc-runtime.log` inside the container — which is `<your-asset-dir>/wolf-revc-runtime.log` on the streaming host (e.g. `$HOME/.reVC/wolf-revc-runtime.log` for the standalone pattern, or `/mnt/docker_volumes/wolf-revc/wolf-revc-runtime.log` for the in-place pattern). It survives the container being torn down. That log shows reVC's stderr, GLFW errors, the synced resolution, etc.

For Wolf-server-side issues:
```bash
ssh $STREAM_USER@$STREAM_HOST 'docker logs wolf --tail 100'
```

### Re-pair a Moonlight client

Tap the server in Moonlight, get a 4-digit PIN, then watch Wolf logs for the URL:
```bash
ssh $STREAM_USER@$STREAM_HOST 'docker logs wolf 2>&1 | grep "Insert pin"'
```
Open the printed URL in any browser, enter the PIN.

## Known gotchas

Documented for the next person who runs into them:

- **Don't use `set -e` in `startup.sh`.** `launcher` returns non-zero because it `killall sway`s on app exit. With `set -e`, that aborts the script and Wolf logs only a generic "Stopped container" with no clue why.
- **reVC.ini's `[VideoMode]` must match the stream resolution.** Handled by the `sed` line in `startup.sh`. If reVC mysteriously dies on launch with no game window, check the runtime log for "Cannot find desired video mode".
- **4K can max out an integrated GPU.** Render + Sway/gamescope + HEVC encode all compete for the same silicon. If 4K hitches, drop to 1440p in Moonlight's settings — `startup.sh` will follow.
- **The `gamecontrollerdb.txt` shipped in `/opt/revc/gamefiles/` is whatever the archive.org bundle had (often outdated).** The container `cd`s to `/assets` before running, so reVC reads `$HOME/.reVC/gamecontrollerdb.txt` on the host instead — keep that one updated from the upstream [SDL_GameControllerDB](https://github.com/mdqinc/SDL_GameControllerDB).
- **Wolf wants UID 1000 to own the asset dir on the host.** Inside the spawned container, the app runs as user `retro` (UID 1000). If your host user isn't UID 1000, either `chown -R 1000:1000` the asset dir or pass `PUID/PGID` env vars in the Wolf TOML.

## Files

| File | Purpose |
|---|---|
| `Dockerfile` | Multi-stage: stage 1 builds `librw` and `reVC` from source; stage 2 lays them on top of `base-app:edge` with the runtime libs. Uses `COPY` + `RUN chmod` (not `COPY --chmod`) so it works on both BuildKit and the legacy builder. |
| `startup.sh` | Baked into the image as `/opt/gow/startup-app.sh`. Syncs resolution, tees log, runs reVC under Sway. Can also be bind-mounted for fast iteration without a rebuild. |
| `docker-compose.wolf.yml` | Standalone Wolf server compose file — use this if you don't already run a monolithic compose. Deploy as e.g. `~/wolf/docker-compose.yml` on the streaming host. |
| `revc-app.toml.snippet` | The `[[profiles.apps]]` block to append to Wolf's `config.toml` on the streaming host. Contains `<HOME>` placeholders to replace with your asset path. |
| `LEGAL.md` | The legal posture — see this before deciding whether to use the repo. |
| `LICENSE` | MIT, covering only the files in this repo (not Wolf, not reVC, not GTA:VC). |

## Credits & related projects

- [games-on-whales/wolf](https://github.com/games-on-whales/wolf) — the streaming server doing all the heavy lifting.
- [games-on-whales/gow](https://github.com/games-on-whales/gow) — the `base-app` image and reference apps (Steam, RetroArch, Firefox, …) that this recipe follows.
- [aap/librw](https://github.com/aap/librw) — RenderWare reimplementation.
- The original re3 / reVC contributors. [LEGAL.md](LEGAL.md) has the history.
