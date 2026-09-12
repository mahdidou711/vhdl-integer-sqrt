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

echo "[GHDL] Analyze DE1 wrapper (VHDL-93)"
ghdl -a --std=93 "${repo_root}/fpga/de1/sqrt16_de1_top.vhd"

echo "[GHDL] Elaborate sqrt16_de1_top"
ghdl -e --std=93 sqrt16_de1_top

echo "[GHDL] Synthesize DE1 wrapper and core"
ghdl --synth --std=93 \
    "${repo_root}/rtl/sqrt16.vhd" \
    "${repo_root}/fpga/de1/sqrt16_de1_top.vhd" \
    -e sqrt16_de1_top >/dev/null
