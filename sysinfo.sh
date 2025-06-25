#!/bin/sh

usage() {
  cat <<EOF
Usage: $0 [--json|--html]
  --json    JSON形式で出力します
  --html    HTML形式で出力します
  何も指定しない場合はテキスト形式で出力します
EOF
  exit 1
}

json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/\"/\\"/g; s/\n/\\n/g; s/\r/\\r/g'
}

html_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

MODE=text
if [ "$#" -gt 1 ]; then
  usage
elif [ "$#" -eq 1 ]; then
  case "$1" in
    --json) MODE=json ;;
    --html) MODE=html ;;
    *) usage ;;
  esac
fi

if [ "$MODE" = html ]; then
  echo "<html><head><meta charset=\"UTF-8\"><title>System Info</title></head><body><table border=1>"
elif [ "$MODE" = json ]; then
  echo "{"
fi

if [ "$MODE" = json ]; then
  TMPFILE=$(mktemp) || exit 1
fi

collect_info() {
  SECTION="$1"
  CONTENT="$2"
  case "$MODE" in
    text)
      echo "【$SECTION】"
      printf '%s\n\n' "$CONTENT"
      ;;
    json)
      printf '  "%s": "%s"' "$SECTION" "$(json_escape "$CONTENT")"
      ;;
    html)
      printf '<tr><th>%s</th><td><pre>%s</pre></td></tr>\n' "$(html_escape "$SECTION")" "$(html_escape "$CONTENT")"
      ;;
  esac
}

output_info() {
  SECTION="$1"
  CONTENT="$2"
  if [ "$MODE" = json ]; then
    printf '  "%s": "%s"\n' "$SECTION" "$(json_escape "$CONTENT")" >> "$TMPFILE"
  else
    collect_info "$SECTION" "$CONTENT"
  fi
}

add_info() {
  output_info "$1" "$2"
}

check_cmd() {
  CMD="$1"
  if ! command -v "$CMD" >/dev/null 2>&1; then
    MISSING_CMDS="$MISSING_CMDS $CMD"
  fi
}

MISSING_CMDS=""

add_info "OS情報" "$(uname -a)
$(cat /etc/os-release 2>/dev/null || echo '（/etc/os-release 不明）')"
add_info "カーネル" "$(uname -r)"
add_info "ホスト名と稼働時間" "$(hostname)
$(uptime)"
add_info "CPU情報" "$(grep -m 1 'model name' /proc/cpuinfo 2>/dev/null || echo '不明')
$(nproc --all 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo '不明')"
add_info "メモリ情報" "$(free -h 2>/dev/null || vm_stat 2>/dev/null || echo '不明')"
add_info "ディスク情報" "$(df -h --total 2>/dev/null || df -h || echo '不明')"
add_info "マウント状況" "$(mount | grep '^/dev' || echo '（情報取得できません）')"
add_info "ネットワーク" "$(ip a 2>/dev/null || ifconfig || echo '不明')"
add_info "ログインユーザーとログイン情報" "$(who || echo '不明')"

check_cmd lsblk
add_info "ストレージ構成" "$(lsblk 2>/dev/null || echo 'lsblk 不使用')"

check_cmd lspci
add_info "GPU/PCIデバイス" "$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' || echo 'lspci 不使用')"

check_cmd lscpu
add_info "lscpu 情報" "$(lscpu 2>/dev/null || echo 'lscpu 不使用')"

check_cmd lshw
add_info "lshw 情報" "$(lshw -short 2>/dev/null || echo 'lshw 不使用')"

check_cmd inxi
add_info "inxi 情報" "$(inxi -Fxz 2>/dev/null || echo 'inxi 不使用')"

# GUI 情報
GUI_INFO="XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-不明}
DESKTOP_SESSION=${DESKTOP_SESSION:-不明}
XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-不明}
WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-未設定}
DISPLAY=${DISPLAY:-未設定}
SSH_CONNECTION=${SSH_CONNECTION:-ローカル}"
[ -n "$SSH_CONNECTION" ] && GUI_INFO="$GUI_INFO\n※ SSH 経由のリモートセッションです"
[ -n "$DISPLAY" ] && [ -n "$WAYLAND_DISPLAY" ] && GUI_INFO="$GUI_INFO\n※ X11 と Wayland の両方が使用されています（混在）"
[ -n "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ] && GUI_INFO="$GUI_INFO\nWayland セッションです"
[ -n "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && GUI_INFO="$GUI_INFO\nX11 セッションです"
[ -z "$DISPLAY" ] && [ -z "$WAYLAND_DISPLAY" ] && GUI_INFO="$GUI_INFO\nGUI セッション情報は取得できませんでした"
add_info "GUI 関連情報" "$GUI_INFO"

# ウィンドウマネージャー検出
WMS="gnome-shell kwin xfwm4 openbox i3 sway mutter kwin_x11"
FOUND_WM=""
for wm in $WMS; do
  ps -e | grep -w "$wm" >/dev/null 2>&1 && FOUND_WM="$FOUND_WM $wm"
done
[ -z "$FOUND_WM" ] && FOUND_WM="検出できませんでした"
add_info "ウィンドウマネージャー・DE" "$FOUND_WM"

check_cmd xrandr
check_cmd xdpyinfo
XRANDR_OUT="$(xrandr --query 2>/dev/null || echo 'xrandr 不使用')"
XDPYINFO_OUT="$(xdpyinfo 2>/dev/null | grep dimensions || echo 'xdpyinfo 不使用')"
add_info "ディスプレイ情報" "$XRANDR_OUT
$XDPYINFO_OUT"

# 未インストールコマンドの案内
if [ -n "$MISSING_CMDS" ]; then
  INFO="以下のコマンドが見つかりませんでした:$MISSING_CMDS\n\n導入方法（root 権限が必要な場合があります）:\n\n"

  for CMD in $MISSING_CMDS; do
    INFO="$INFO【$CMD】
  Debian/Ubuntu系: sudo apt install $CMD
  RedHat/Fedora系: sudo dnf install $CMD
  Arch Linux系:    sudo pacman -S $CMD
  macOS (brew):    brew install $CMD

"
  done

  add_info "補足：未インストールコマンドと導入案内" "$INFO"
fi

# JSON出力の最終処理
if [ "$MODE" = json ]; then
  LINECNT=$(wc -l < "$TMPFILE" | tr -d ' ')
  COUNT=0
  while IFS= read -r line; do
    COUNT=$((COUNT + 1))
    if [ "$COUNT" -lt "$LINECNT" ]; then
      printf '%s,\n' "$line"
    else
      printf '%s\n' "$line"
    fi
  done < "$TMPFILE"
  echo '  ,"EOF": "true"'
  echo "}"
  rm -f "$TMPFILE"
elif [ "$MODE" = html ]; then
  echo "</table></body></html>"
fi
