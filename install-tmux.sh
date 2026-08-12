#!/usr/bin/env bash
# =====================================================================
# tmux catppuccin 설정 포터블 설치 스크립트 (S25 폰 핑 제외판)
# 회장님 ~/.tmux.conf 를 다른 서버에 그대로 재현한다.
#
#   실행:  bash <(curl -fsSL https://raw.githubusercontent.com/happy4ed/tmux-setup/main/install-tmux.sh)
#   또는:  bash install-tmux.sh
#
# 전제: git·tmux(3.x 권장). 없으면 apt/yum 으로 먼저 설치.
# 무인 설치(질문 없이): 환경변수로 지정 →  YAZI=1 NERDFONT=1 bash install-tmux.sh
#   (YAZI/NERDFONT = 1 강제설치 · 0 건너뜀 · 미지정=대화형 질문)
# =====================================================================
set -e

echo "==> tmux 설정 설치 시작"

# --- 대화형 질문 헬퍼 (curl|bash 에서도 /dev/tty 로 입력) ---------------
ask() {
  [ -e /dev/tty ] || return 1        # 비대화(파이프·CI)면 질문 없이 no
  local a; read -r -p "$1 [y/N] " a < /dev/tty || return 1
  case "$a" in [Yy]*) return 0 ;; *) return 1 ;; esac
}
_dl() { # _dl <url> <out>  (curl 우선, 없으면 wget)
  if command -v curl >/dev/null; then curl -fsSL "$1" -o "$2"
  else wget -qO "$2" "$1"; fi
}

# --- yazi 설치 (cargo 우선, 없으면 GitHub release 바이너리) -------------
install_yazi() {
  echo "==> yazi 설치"
  if command -v cargo >/dev/null; then
    cargo install --locked yazi-fm yazi-cli && { echo "    yazi(cargo) 설치 완료"; return 0; }
  fi
  local arch a; arch=$(uname -m)
  case "$arch" in
    x86_64) a=x86_64 ;; aarch64|arm64) a=aarch64 ;;
    *) echo "    미지원 arch($arch) — yazi 수동 설치 필요"; return 1 ;;
  esac
  command -v unzip >/dev/null || { echo "    unzip 필요(apt install unzip) — yazi 건너뜀"; return 1; }
  local url="https://github.com/sxyazi/yazi/releases/latest/download/yazi-${a}-unknown-linux-gnu.zip"
  local tmp; tmp=$(mktemp -d)
  _dl "$url" "$tmp/y.zip" || { echo "    yazi 다운로드 실패"; rm -rf "$tmp"; return 1; }
  unzip -q "$tmp/y.zip" -d "$tmp"
  mkdir -p "$HOME/.local/bin"
  find "$tmp" -type f \( -name yazi -o -name ya \) -exec cp {} "$HOME/.local/bin/" \;
  chmod +x "$HOME/.local/bin/yazi" "$HOME/.local/bin/ya" 2>/dev/null || true
  rm -rf "$tmp"
  echo "    yazi → ~/.local/bin"
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) echo "    ※ PATH 에 ~/.local/bin 추가 필요 (예: echo 'export PATH=\$HOME/.local/bin:\$PATH' >> ~/.bashrc)";; esac
}

# --- Nerd Font 설치 (JetBrainsMono, ~/.local/share/fonts) ---------------
install_nerdfont() {
  echo "==> Nerd Font(JetBrainsMono) 설치"
  command -v unzip >/dev/null || { echo "    unzip 필요 — 폰트 건너뜀"; return 1; }
  local dir="$HOME/.local/share/fonts"; mkdir -p "$dir"
  local tmp; tmp=$(mktemp -d)
  _dl "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" "$tmp/f.zip" \
    || { echo "    폰트 다운로드 실패"; rm -rf "$tmp"; return 1; }
  unzip -qo "$tmp/f.zip" -d "$dir" '*.ttf' 2>/dev/null || unzip -qo "$tmp/f.zip" -d "$dir"
  rm -rf "$tmp"
  command -v fc-cache >/dev/null && fc-cache -f "$dir" >/dev/null 2>&1 || true
  echo "    JetBrainsMono Nerd Font → $dir"
  [ -n "$SSH_CONNECTION" ] && echo "    ※ SSH 접속 중 — 아이콘은 '접속하는 로컬 터미널' 폰트로 렌더됩니다. 서버 설치는 서버 로컬 콘솔에서만 유효하니, 로컬 PC 터미널에도 Nerd Font 지정을 권장합니다."
}

# 1) 기존 설정 백업(있으면)
if [ -f "$HOME/.tmux.conf" ]; then
  bak="$HOME/.tmux.conf.bak.$(date +%Y%m%d-%H%M%S)"
  cp "$HOME/.tmux.conf" "$bak"
  echo "    기존 ~/.tmux.conf → $bak 로 백업"
fi

# 2) tpm(플러그인 매니저) 설치
mkdir -p "$HOME/.tmux/plugins"
if [ -d "$HOME/.tmux/plugins/tpm" ]; then
  echo "    tpm 이미 설치됨 (건너뜀)"
else
  git clone --depth 1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
  echo "    tpm 설치 완료"
fi

# 3) ~/.tmux.conf 작성 (S25 폰 핑 라인만 제거, 나머지 원본 동일)
cat > "$HOME/.tmux.conf" <<'TMUXCONF'
# === Prefix 변경 (Ctrl+Space, Ctrl+b도 유지) ===
set -g prefix C-Space
set -g prefix2 C-b
bind C-Space send-prefix

# === 기본 설정 ===
set-option -g history-limit 50000
bind % split-window -h -c "#{pane_current_path}"
bind '"' split-window -v -c "#{pane_current_path}"
set -g default-terminal "tmux-256color"
set -ag terminal-overrides ",xterm-256color:RGB"
set -g automatic-rename off
set -g mouse on
set -g allow-passthrough on
# Linux/원격(SSH·헤드리스): 복사 시 OSC52 로 로컬 터미널 클립보드에 반영
set -g set-clipboard on
set -g pane-border-format " #{pane_index} #{pane_current_command} "
set -g pane-border-status top
set -g pane-border-lines double

# === 복사 모드 (vi) ===
setw -g mode-keys vi
bind-key -T copy-mode-vi v send-keys -X begin-selection
# macOS pbcopy → Linux/원격: set-clipboard(OSC52) 로 복사 (별도 클립보드 도구 불필요)
bind-key -T copy-mode-vi y send-keys -X copy-selection-and-cancel
bind-key -T copy-mode-vi Enter send-keys -X copy-selection-and-cancel
bind-key -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-selection-no-clear

# 마우스 스크롤 속도 (기본 3 → 5줄씩)
bind-key -T copy-mode-vi WheelUpPane send-keys -X -N 5 scroll-up
bind-key -T copy-mode-vi WheelDownPane send-keys -X -N 5 scroll-down

# === 플러그인 ===
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'catppuccin/tmux'
set -g @plugin 'tmux-plugins/tmux-cpu'
set -g @plugin 'tmux-plugins/tmux-battery'
set -g @plugin 'tmux-plugins/tmux-resurrect'
set -g @plugin 'tmux-plugins/tmux-continuum'

# yazi 파일 탐색기 (Prefix + Tab: 50% 분할)
bind Tab split-window -h -l 50% -c "#{pane_current_path}" "yazi"

# === Catppuccin 테마 ===
set -g @catppuccin_flavor 'mocha'
set -g @catppuccin_window_status_style 'rounded'

# 상태 바 왼쪽: 세션 이름
set -g status-left-length 40
set -g status-left "#{E:@catppuccin_status_session}"

# 상태 바 오른쪽: 디렉토리 + Git 브랜치 + CPU + 메모리 + 서버(호스트명) + 시간
#   ※ 원본의 "S25 폰 핑" 세그먼트는 이 포터블판에서 제거됨
set -g status-right-length 200
set -g @catppuccin_date_time_text " %m/%d %H:%M"
set -g status-right "#{E:@catppuccin_status_directory}"
set -ag status-right "#[bg=default] #[fg=#a6e3a1,bg=#313244]  #(cd #{pane_current_path}; git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '-') "
set -ag status-right "#[bg=default] #[fg=#89b4fa,bg=#313244]  #{cpu_percentage} "
set -ag status-right "#[bg=default] #[fg=#f9e2af,bg=#313244]  #{ram_percentage} "
set -ag status-right "#[bg=default] #[fg=#cba6f7,bg=#313244]  #H "
set -ag status-right "#{E:@catppuccin_status_date_time}"

# 윈도우 탭 (현재 선택 윈도우 강조)
set -g @catppuccin_window_text " #I:#{=10:window_name} "
set -g @catppuccin_window_current_text " #[bold] *#I:#W* "

# === Pane 이동 (Option + hjkl, prefix 없이) ===
bind -n M-h select-pane -L
bind -n M-j select-pane -D
bind -n M-k select-pane -U
bind -n M-l select-pane -R
bind L last-window
bind r source-file ~/.tmux.conf \; display "Reloaded!"

# === TPM 실행 ===
run '~/.tmux/plugins/tpm/tpm'
TMUXCONF
echo "    ~/.tmux.conf 작성 완료 (S25 폰 핑 제외)"

# 4) 플러그인 자동 설치(tpm)
if [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" || true
  echo "    tpm 플러그인 설치 완료"
fi

# 5) yazi (Prefix+Tab 파일탐색기)
if command -v yazi >/dev/null; then
  echo "==> yazi 이미 설치됨"
elif [ "${YAZI:-}" = "1" ]; then install_yazi || echo "    yazi 설치 실패"
elif [ "${YAZI:-}" = "0" ]; then echo "==> yazi 건너뜀(YAZI=0)"
elif ask "yazi(파일탐색기, Prefix+Tab)가 없습니다. 설치할까요?"; then
  install_yazi || echo "    yazi 설치 실패 — 수동 설치 필요"
else echo "==> yazi 건너뜀 (Prefix+Tab 만 비활성, 나머지 정상)"
fi

# 6) Nerd Font (상태바 아이콘)
if fc-list 2>/dev/null | grep -qi "nerd"; then
  echo "==> Nerd Font 이미 있음"
elif [ "${NERDFONT:-}" = "1" ]; then install_nerdfont || echo "    폰트 설치 실패"
elif [ "${NERDFONT:-}" = "0" ]; then echo "==> Nerd Font 건너뜀(NERDFONT=0)"
elif ask "Nerd Font(상태바 아이콘 표시용)가 없습니다. 설치할까요?"; then
  install_nerdfont || echo "    폰트 설치 실패"
else echo "==> Nerd Font 건너뜀 (아이콘이 깨져 보일 수 있음)"
fi

# 7) 적용
if [ -n "$TMUX" ]; then
  tmux source-file "$HOME/.tmux.conf" 2>/dev/null || true
  echo "==> 현재 tmux 세션에 적용됨"
else
  echo "==> 완료. tmux 를 새로 시작하면 적용됩니다 (또는 tmux 안에서 Prefix(Ctrl+Space) + r)"
fi
