#!/usr/bin/env bash
set -euo pipefail

COMPOSE_FILE=".devcontainer/docker-compose.yml"
CONTAINER_HOME="/home/dev"

mkdir -p "${HOME}/.codex" "${HOME}/.claude" "${HOME}/.ssh"

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "ERROR: $COMPOSE_FILE not found. Did setup_host.sh run first?" >&2
    exit 1
fi

if grep -q "${CONTAINER_HOME}/.codex" "$COMPOSE_FILE"; then
    exit 0
fi

python3 - "$COMPOSE_FILE" "$HOME" "$CONTAINER_HOME" <<'PY'
import sys

compose_path, host_home, container_home = sys.argv[1], sys.argv[2], sys.argv[3]

with open(compose_path) as f:
    lines = f.readlines()

extra = [
    f"      - {host_home}/.codex:{container_home}/.codex:z\n",
    f"      - {host_home}/.claude:{container_home}/.claude:z\n",
    f"      - {host_home}/.ssh:{container_home}/.ssh:z\n",
]

out = []
inserted = False
in_volumes = False
for line in lines:
    if not inserted:
        stripped = line.strip()
        if stripped == "volumes:" and line.startswith("    "):
            in_volumes = True
            out.append(line)
            continue
        if in_volumes:
            if line.startswith("      - "):
                out.append(line)
                continue
            out.extend(extra)
            inserted = True
            in_volumes = False
    out.append(line)

if in_volumes and not inserted:
    out.extend(extra)
    inserted = True

if not inserted:
    sys.exit("ERROR: could not find volumes block in docker-compose.yml")

with open(compose_path, "w") as f:
    f.writelines(out)
PY
