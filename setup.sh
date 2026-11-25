#!/usr/bin/env bash
# Passo 2 do fluxo: instala e testa HyperFrames, FFmpeg, Whisper e yt-dlp.
# Uso: bash setup.sh   (macOS com Homebrew ou Linux com apt)
set -u
ok(){ printf "  \033[32mOK\033[0m   %s\n" "$1"; }
bad(){ printf "  \033[31mFALHA\033[0m %s\n" "$1"; FAIL=1; }
FAIL=0

echo "==> Instalando"
if command -v brew >/dev/null; then
  brew install ffmpeg node python yt-dlp
elif command -v apt-get >/dev/null; then
  sudo apt-get update -y && sudo apt-get install -y ffmpeg nodejs npm python3-pip
fi
python3 -m pip install -U yt-dlp openai-whisper || python3 -m pip install --user -U yt-dlp openai-whisper
npm install -g hyperframes
# Skill teardown (simulador 3D de máquinas): dependências locais + Chromium.
# Na nuvem do Claude Code o Chromium já existe em /opt/pw-browsers; no Mac, baixa.
TD="$(cd "$(dirname "$0")" && pwd)/.claude/skills/teardown"
if [ -d "$TD" ]; then
  (cd "$TD" && npm install --no-audit --no-fund \
    && { [ -x /opt/pw-browsers/chromium ] || npx playwright install chromium; })
fi

echo "==> Testando"
TMP=$(mktemp -d)
ffmpeg -v error -f lavfi -i testsrc=d=1:s=320x240 -f lavfi -i sine=d=1 -shortest "$TMP/t.mp4" -y \
  && ok "FFmpeg $(ffmpeg -version | head -1 | awk '{print $3}')" || bad "FFmpeg"
yt-dlp --version >/dev/null && ok "yt-dlp $(yt-dlp --version)" || bad "yt-dlp"
# Whisper baixa o modelo na primeira execução (precisa de internet)
whisper "$TMP/t.mp4" --model tiny --language pt --output_dir "$TMP" --output_format txt >/dev/null 2>&1 \
  && ok "Whisper (modelo tiny baixado)" || bad "Whisper — modelo não baixou (rede?)"
(cd "$TMP" && hyperframes init hf --example blank --non-interactive --skip-transcribe >/dev/null 2>&1 \
  && cd hf && hyperframes render -o t.mp4 >/dev/null 2>&1 && test -s t.mp4) \
  && ok "HyperFrames $(hyperframes --version)" || bad "HyperFrames"
rm -rf "$TMP"
[ $FAIL = 0 ] && echo "==> Tudo pronto." || { echo "==> Algo falhou, veja acima."; exit 1; }
