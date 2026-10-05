#!/usr/bin/env bash
# discover.sh — dev-tooling probe
#
# Reports, in 3-4 lines, which dev tools are ACTUALLY present in this
# environment. Run it once per session and trust the result for the rest of the
# session. It is read-only and idempotent: it installs nothing and mutates
# nothing, so it is safe to run in any state.
#
# Output:
#   PRESENT:  tools invocable by bare name (on PATH) — the zero-friction set
#   jdkbin:   Java tools installed under $JAVA_HOME/bin but NOT on PATH
#             (call as $JAVA_HOME/bin/<tool>); shown only when such tools exist
#   runtime:  versions of the major runtimes (java / cargo / node / py)
#   env:      OS / user / JAVA_HOME / network reachability
#
# Detection is TYPE-AWARE — a flat `command -v` list silently misses these:
#   bin     -> `command -v X`                (ordinary binary)
#   cargo   -> `command -v cargo-X`          (cargo subcommand, used as `cargo X`)
#   py      -> `python3 -c "import X"`       (Python library, not a CLI)
#
# JDK tools get one more fallback: a row marked `JDK` that is not on PATH is also
# checked under $JAVA_HOME/bin, because the JDK ships more tools than this
# container symlinks onto PATH (e.g. jdeps, jshell, jlink).
#
# SINGLE SOURCE OF TRUTH: the TOOLS table below is the authoritative list of
# what to look for. If you add a tool to the catalog in SKILL.md, add its row
# here (and only here). Presence is decided by this probe, never asserted by
# the catalog.
#
# Row format:  <name>  <kind>  <target>  [home]
#   name    display name shown on the PRESENT / jdkbin line
#   kind    bin | cargo | py
#   target  the thing to test (binary / cargo subcommand / python module)
#   home    optional; `JDK` = also check $JAVA_HOME/bin when not on PATH

set -u

probe() { # $1 = kind, $2 = target ; returns 0 (present) or non-zero (absent)
  case "$1" in
    bin)   command -v "$2"          >/dev/null 2>&1 ;;
    cargo) command -v "cargo-$2"    >/dev/null 2>&1 ;;
    py)    python3   -c "import $2" >/dev/null 2>&1 ;;
  esac
}

present=""
jdkbin=""
while read -r name kind target home _; do
  [ -z "$name" ] && continue
  case "$name" in \#*) continue ;; esac   # skip comment/blank lines in the table
  if probe "$kind" "$target"; then
    present="$present $name"
  elif [ "${home:-}" = "JDK" ] && [ -n "${JAVA_HOME:-}" ] && [ -x "$JAVA_HOME/bin/$target" ]; then
    jdkbin="$jdkbin $name"                  # installed under $JAVA_HOME/bin, not on PATH
  fi
done <<'TOOLS'
# Java / Maven  (JDK tools also checked under $JAVA_HOME/bin when off-PATH)
java      bin   java      JDK
javac     bin   javac     JDK
mvn       bin   mvn
cfr       bin   cfr
javap     bin   javap     JDK
jdeps     bin   jdeps     JDK
jshell    bin   jshell    JDK
jar       bin   jar       JDK
javadoc   bin   javadoc   JDK
jlink     bin   jlink     JDK
# Rust
rustc         bin   rustc
cargo         bin   cargo
clippy        cargo clippy
rustfmt       bin   rustfmt
nextest       cargo nextest
taplo         bin   taplo
audit         cargo audit
deny          cargo deny
udeps         cargo udeps
wasm-pack     bin   wasm-pack
wasm-bindgen  bin   wasm-bindgen
wasm-tools    bin   wasm-tools
dx            bin   dx
rust-analyzer bin   rust-analyzer
# TypeScript / JavaScript
tsc      bin tsc
prettier bin prettier
biome    bin biome
eslint   bin eslint
esbuild  bin esbuild
ts-node  bin ts-node
node     bin node
npm      bin npm
# Config validation (XML / YAML / JSON)
yamllint   bin yamllint
yq         bin yq
xmlstarlet bin xmlstarlet
xmllint    bin xmllint
jq         bin jq
# General
git        bin git
rg         bin rg
fd         bin fd
shellcheck bin shellcheck
just       bin just
python3    bin python3
uv         bin uv
pypdf      py  pypdf
gcc        bin gcc
make       bin make
magick     bin magick
godot      bin godot
TOOLS
present=${present# }
jdkbin=${jdkbin# }

# --- runtime versions (each guarded; a missing runtime just prints "?") ---
java_v=$(java -version 2>&1 | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
cargo_v=$(cargo --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
node_v=$(node --version 2>/dev/null | cut -d- -f1)
py_v=$(python3 --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+')

# --- env facts ---
os=$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")
if command -v curl >/dev/null 2>&1; then
  net=$(timeout 3 curl -sI https://crates.io >/dev/null 2>&1 && echo up || echo down)
else
  net=unknown
fi

echo "PRESENT: ${present:-none}"
if [ -n "$jdkbin" ]; then
  echo "jdkbin:  ${jdkbin}   (in \$JAVA_HOME/bin, not on PATH -> call as \$JAVA_HOME/bin/<tool>)"
fi
echo "runtime: java ${java_v:-?} cargo ${cargo_v:-?} node ${node_v:-?} py ${py_v:-?}"
echo "env: ${os} user=$(whoami 2>/dev/null || echo ?) JAVA_HOME=${JAVA_HOME:-none} net=${net}"
