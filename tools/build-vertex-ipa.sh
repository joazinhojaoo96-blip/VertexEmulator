#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MADEIRA="$ROOT/Vendor/Madeira"
SOURCE_IPA="$MADEIRA/dist/Madeira.ipa"
OUTPUT_IPA="$ROOT/dist/Vertex.ipa"

[[ "$(uname -s)" == "Darwin" ]] || { echo "ERROR: compile o runtime iOS em macOS com Xcode." >&2; exit 1; }
command -v python3 >/dev/null || { echo "ERROR: Python 3 não encontrado." >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "ERROR: Xcode não encontrado." >&2; exit 1; }

echo "==> Validando e aplicando a identidade Vertex"
python3 "$ROOT/tools/brand-madeira-for-vertex.py" --dry-run
python3 "$ROOT/tools/brand-madeira-for-vertex.py"

echo "==> Aplicando correção Metal protegida do DXMT"
(cd "$ROOT" && python3 tools/patch-dxmt-metal-atomic.py)

echo "==> Compilando o runtime Windows nativo"
(
  cd "$MADEIRA"
  export MADEIRA_RUNTIME_REUSE="${MADEIRA_RUNTIME_REUSE:-1}"
  JOBS="${JOBS:-4}" ./tools/build-ipa.sh
)

test -s "$SOURCE_IPA" || { echo "ERROR: o runtime não gerou o IPA esperado." >&2; exit 1; }
unzip -tq "$SOURCE_IPA"

echo "==> Validando e exportando dist/Vertex.ipa"
python3 - "$SOURCE_IPA" "$OUTPUT_IPA" <<'PY'
import plistlib, sys, zipfile
from pathlib import Path
source, output = map(Path, sys.argv[1:])
with zipfile.ZipFile(source) as archive:
    apps = [n for n in archive.namelist()
            if n.startswith("Payload/") and n.endswith(".app/Info.plist")]
    if len(apps) != 1:
        raise SystemExit(f"Esperado um app no IPA; encontrados: {apps}")
    info = plistlib.loads(archive.read(apps[0]))
    for key, expected in (("CFBundleIdentifier", "com.vertex.emulator"),
                          ("CFBundleDisplayName", "Vertex")):
        if info.get(key) != expected:
            raise SystemExit(f"{key} inválido: {info.get(key)!r}")
    print("PASS: identidade Vertex confirmada; runtime Madeira está no app")
output.parent.mkdir(parents=True, exist_ok=True)
output.write_bytes(source.read_bytes())
if output.stat().st_size == 0:
    raise SystemExit("IPA exportado vazio")
print(f"IPA exportado: {output} ({output.stat().st_size} bytes)")
PY
