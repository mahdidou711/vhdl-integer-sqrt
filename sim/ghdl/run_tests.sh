#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(CDPATH= cd -- "${script_dir}/../.." && pwd)"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/vhdl-integer-sqrt-ghdl.XXXXXX")"

cleanup() {
    rm -rf -- "${work_dir}"
}
trap cleanup EXIT INT TERM

cd "${work_dir}"

echo "[GHDL] Analyze RTL (VHDL-93)"
ghdl -a --std=93 "${repo_root}/rtl/sqrt16.vhd"

echo "[GHDL] Analyze testbench (VHDL-93)"
ghdl -a --std=93 "${repo_root}/tb/tb_sqrt16.vhd"

echo "[GHDL] Elaborate tb_sqrt16"
ghdl -e --std=93 tb_sqrt16

echo "[GHDL] Run complete verification suite"
ghdl -r --std=93 tb_sqrt16 --assert-level=error
