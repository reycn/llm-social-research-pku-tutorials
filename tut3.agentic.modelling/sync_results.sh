#!/usr/bin/env bash
# Sync R-generated figures and tables into the LaTeX paper project.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p "$ROOT/paper/fig" "$ROOT/paper/tex"

rsync -a --delete "$ROOT/output/fig/" "$ROOT/paper/fig/"
rsync -a --delete "$ROOT/output/tex/" "$ROOT/paper/tex/"

echo "Synced output/fig -> paper/fig and output/tex -> paper/tex."
