#!/usr/bin/env bash
set -euo pipefail

# Stages an Android/ARM64 AAPT2 executable and its non-system shared libraries
# as APK native libraries. This keeps executable code inside the installed APK
# instead of app-writable private storage on Android 10+.
BASE="${TERMUX_REPO_BASE:-https://packages.termux.dev/apt/termux-main}"
ARCH="${TERMUX_ARCH:-aarch64}"
OUT="${1:-app13/src/main/jniLibs/arm64-v8a}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

PACKAGES_URL="$BASE/dists/stable/main/binary-$ARCH/Packages"
curl -fsSL "$PACKAGES_URL" -o "$WORK/Packages"

python3 - "$WORK/Packages" "$WORK/selection.tsv" <<'PY'
import re,sys
src,out=sys.argv[1:3]
wanted=["aapt2","fmt","libc++","libexpat","libpng","libzopfli","zlib","abseil-cpp","libprotobuf","protobuf"]
blocks=open(src,encoding="utf-8").read().split("\n\n")
found={}
for b in blocks:
    m=re.search(r"^Package: (.+)$",b,re.M)
    if not m: continue
    name=m.group(1).strip()
    if name not in wanted: continue
    fn=re.search(r"^Filename: (.+)$",b,re.M)
    sh=re.search(r"^SHA256: ([0-9a-fA-F]{64})$",b,re.M)
    if fn and sh: found[name]=(fn.group(1).strip(),sh.group(1).lower())
missing=[x for x in wanted if x not in found]
if missing: raise SystemExit("Missing Termux packages: "+", ".join(missing))
with open(out,"w",encoding="utf-8") as f:
    for name in wanted:
        fn,sh=found[name]
        f.write(f"{name}\t{fn}\t{sh}\n")
PY

mkdir -p "$WORK/root"
while IFS=$'\t' read -r name file sha; do
  deb="$WORK/$name.deb"
  curl -fsSL "$BASE/$file" -o "$deb"
  echo "$sha  $deb" | sha256sum -c -
  dpkg-deb -x "$deb" "$WORK/root"
done < "$WORK/selection.tsv"

AAPT2="$(find "$WORK/root" -type f -path '*/bin/aapt2' | head -1)"
if [ -z "$AAPT2" ]; then
  echo "aapt2 executable not found in package payload" >&2
  exit 2
fi
file "$AAPT2" | tee "$WORK/aapt2.file"
grep -Eqi 'ELF 64-bit.*(ARM aarch64|aarch64)' "$WORK/aapt2.file"

rm -rf "$OUT"
mkdir -p "$OUT"
cp "$AAPT2" "$OUT/libanamika_aapt2.so"
chmod 755 "$OUT/libanamika_aapt2.so"

if ! command -v patchelf >/dev/null 2>&1; then
  sudo apt-get update -qq
  sudo apt-get install -y -qq patchelf
fi

# Materialize unversioned .so symlinks as real files because APK packaging does
# not preserve Termux's filesystem symlink layout.
while IFS= read -r lib; do
  base="$(basename "$lib")"
  case "$base" in
    *.so)
      cp -L "$lib" "$OUT/$base"
      ;;
  esac
done < <(find "$WORK/root" \( -type f -o -type l \) -path '*/lib/*.so' | sort -u)

# Rewrite versioned Termux SONAME requests (for example libz.so.1) to the
# unversioned library names that Android reliably packages under jniLibs.
for elf in "$OUT"/*.so; do
  while IFS= read -r need; do
    case "$need" in
      *.so.*)
        plain="${need%%.so.*}.so"
        if [ -f "$OUT/$plain" ]; then
          patchelf --replace-needed "$need" "$plain" "$elf"
        fi
        ;;
    esac
  done < <(patchelf --print-needed "$elf" 2>/dev/null || true)
done

# Verify every DT_NEEDED dependency is either packaged next to AAPT2 or is a
# stable Android system library. Fail closed if the Termux package set changes.
python3 - "$OUT" <<'PY'
import os,re,subprocess,sys
out=sys.argv[1]
system={
 "libc.so","libm.so","libdl.so","liblog.so","libandroid.so","libz.so",
 "libEGL.so","libGLESv2.so","libGLESv3.so","libjnigraphics.so"
}
present=set(os.listdir(out))
queue=[os.path.join(out,"libanamika_aapt2.so")]
seen=set()
missing=set()
while queue:
    p=queue.pop()
    if p in seen: continue
    seen.add(p)
    text=subprocess.check_output(["readelf","-d",p],text=True,stderr=subprocess.STDOUT)
    for need in re.findall(r"Shared library: \[([^\]]+)\]",text):
        if need in system: continue
        if need not in present:
            missing.add(need)
        else:
            q=os.path.join(out,need)
            if os.path.isfile(q): queue.append(q)
if missing:
    raise SystemExit("Unpackaged AAPT2 dependencies: "+", ".join(sorted(missing)))
PY

echo "Embedded AAPT2 staged at $OUT"
readelf -d "$OUT/libanamika_aapt2.so" | grep NEEDED || true
sha256sum "$OUT"/*.so | sort
