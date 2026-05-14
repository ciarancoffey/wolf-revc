# syntax=docker/dockerfile:1
ARG BASE_APP_IMAGE=ghcr.io/games-on-whales/base-app:edge

# --- builder: librw + reVC from upstream sources ---
FROM ubuntu:25.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git ca-certificates curl \
      libglfw3-dev libopenal-dev libmpg123-dev libsdl2-dev \
 && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/aap/librw /src/librw \
 && cmake -B /src/librw/build -S /src/librw \
      -DBUILD_SHARED_LIBS=ON \
      -DCMAKE_INSTALL_PREFIX=/usr \
      -DLIBRW_GL3_GFXLIB=GLFW \
      -DLIBRW_PLATFORM=GL3 \
      -DLIBRW_TOOLS=OFF \
 && cmake --build /src/librw/build -j"$(nproc)" \
 && cmake --install /src/librw/build

# Pre-DMCA archive.org snapshot — same source the revc-git AUR package uses.
RUN curl -fsSL -o /tmp/re3.bundle \
      https://archive.org/download/github.com-GTAmodding-re3_-_2021-09-06_14-11-00/GTAmodding-re3_-_2021-09-06_14-11-00.bundle \
 && git init /src/re3 \
 && git -C /src/re3 pull --rebase /tmp/re3.bundle refs/remotes/origin/miami \
 && sed -i 's/glfwGetX11Display/glfwGetX11DisplayglfwGetX11Display/' \
      /src/re3/src/CMakeLists.txt \
 && cmake -DREVC_VENDORED_LIBRW= -B /src/re3/build -S /src/re3 \
 && cmake --build /src/re3/build -j"$(nproc)"

# --- runtime: thin layer over base-app ---
FROM ${BASE_APP_IMAGE}

RUN apt-get update && apt-get install -y --no-install-recommends \
      libglfw3 libopenal1 libmpg123-0 libpulse0 \
 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/lib/x86_64-linux-gnu/librw.so* /usr/lib/x86_64-linux-gnu/
COPY --from=builder /src/re3/build/src/reVC             /opt/revc/reVC
COPY --from=builder /src/re3/gamefiles                  /opt/revc/gamefiles

COPY startup.sh /opt/gow/startup-app.sh
RUN chmod 755 /opt/gow/startup-app.sh
