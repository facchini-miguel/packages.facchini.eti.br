#!/bin/bash
# Run on your machine: copies compose.yml and setup.sh to the VPS (~/packages) and runs setup.sh
# there, which creates or updates the packages repositories in Dokploy, deploys it and checks it.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ssh vps 'mkdir -p ~/packages'
scp -q "$HERE/compose.yml" "$HERE/setup.sh" vps:packages/
ssh vps 'bash ~/packages/setup.sh'
