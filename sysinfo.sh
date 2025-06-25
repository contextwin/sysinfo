#!/bin/sh

# シンプルな POSIX 準拠 JSON エスケープ関数
json_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/\"/\\"/g; s/\n/\\n/g; s/\r/\\r/g'
}

# HTML エスケープ関数
html_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

# usage 表示関数
print_usage() {
  echo "使用法: $0 [--text|--json|--html]"
  echo "  --text   テキスト出力（デフォルト）"
  echo "  --json   JSON 出力"
  echo "  --html   HTML テーブル出力"
  exit 1
}

# 出力モード設定
MODE=text
case "$1" in
  ""|--text) MODE=text ;;
  --json) MODE=json ;;
  --html) MODE=html ;;
  *) print_usage ;;
esac

# 必要コマンドのチェック
MISSING_CMDS=""
check_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    MISSING_CMDS="$MISSING_CMDS $1"
    return 1
  }
}

# JSON バッファ
JSON_BUFFER=""

# 情報収集関数
collect_info() {
  SECTION="$1"
  CONTENT="$2"
  case "$MODE" in
    text)
      echo "【$SECTION】"
      printf '%s\n\n' "$CONTENT"
      ;;
    json)
      CONTENT_ESC=$(json_escape "$CONTENT")
      JSON_BUFFER="$JSON_BUFFER\"$SECTION\": \"$CONTENT_ESC\",\n"
      ;;
    html)
      printf '<tr><th>%s</th><td><pre>%s</pre></td></tr>\n' "$(html_escape "$SECTION")" "$(html_escape "$CONTENT")"
      ;;
  esac
}

# HTML/JSONヘッダ
[ "$MODE" = html ] && echo "<html><head><meta charset=\"UTF-8\"><title>System Info</title></head><body><table border=1>"
[ "$MODE" = json ] && echo "{"

# 各情報の収集
collect_info "OS情報" "$(uname -a)
$(cat /etc/os-release 2>/dev/null)"
collect_info "カーネル" "$(uname -r)"
collect_info "ホスト名と稼働時間" "$(hostname)
$(uptime)"
collect_info "CPU情報" "$(grep -m 1 'model name' /proc/cpuinfo)
$(nproc --all 2>/dev/null || getconf _NPROCESSORS_ONLN)"
collect_info "メモリ情報" "$(free -h 2>/dev/null || vm_stat 2>/dev/null)"
collect_info "ディスク情報" "$(df -h --total 2>/dev/null || df -h)"
collect_info "マウント状況" "$(mount | grep '^/dev' || echo '（情報取得できません）')"
collect_info "ネットワーク" "$(ip a 2>/dev/null || ifconfig)"
collect_info "ログインユーザーとログイン情報" "$(who)"
check_cmd lsblk
collect_info "ストレージ構成" "$(lsblk 2>/dev/null || echo 'lsblk 不使用')"
check_cmd lspci
collect_info "GPU/PCIデバイス" "$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' || echo 'lspci 不使用')"
check_cmd lscpu
collect_info "lscpu 情報" "$(lscpu 2>/dev/null || echo 'lscpu 不使用')"
check_cmd lshw
collect_info "lshw 情報" "$(lshw -short 2>/dev/null || echo 'lshw 不使用')"
check_cmd inxi
collect_info "inxi 情報" "$(inxi -Fxz 2>/dev/null || echo 'inxi 不使用')"

# smartctl 情報（sudo は使わず直接実行）
if check_cmd smartctl; then
  SMART_INFO=""
  for dev in /dev/sd? /dev/nvme?n1; do
    [ -e "$dev" ] || continue
    INFO="$(smartctl -H -i -A "$dev" 2>/dev/null || echo '取得不可（権限不足の可能性あり）')"
    SMART_INFO="$SMART_INFO\n=== $dev ===\n$INFO\n"
  done
  collect_info "S.M.A.R.T.情報（smartctl）" "$SMART_INFO"
else
  collect_info "S.M.A.R.T.情報（smartctl）" "smartctl 未インストール"
  MISSING_CMDS="$MISSING_CMDS smartmontools"
fi

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
collect_info "GUI 関連情報" "$GUI_INFO"

# ウィンドウマネージャー検出
WMS="gnome-shell kwin xfwm4 openbox i3 sway mutter kwin_x11"
FOUND_WM=""
for wm in $WMS; do
  ps -e | grep -w "$wm" >/dev/null 2>&1 && FOUND_WM="$FOUND_WM $wm"
done
collect_info "ウィンドウマネージャー・DE" "${FOUND_WM:-検出できませんでした}"

# ディスプレイ情報
check_cmd xrandr
check_cmd xdpyinfo
XRANDR_OUT="$(xrandr --query 2>/dev/null || echo 'xrandr 不使用')"
XDPYINFO_OUT="$(xdpyinfo 2>/dev/null | grep dimensions || echo 'xdpyinfo 不使用')"
collect_info "ディスプレイ情報" "$XRANDR_OUT\n$XDPYINFO_OUT"

# JSON 出力を終了
if [ "$MODE" = json ]; then
  echo "$JSON_BUFFER" | sed '$ s/,$//'
  echo "}"
fi

[ "$MODE" = html ] && echo "</table></body></html>"

# 未インストールコマンドの案内（stderr 出力）
if [ -n "$MISSING_CMDS" ]; then
{
  echo
  echo "[!] この補足は stderr に出力されています"
  echo
  echo "【補足】一部の情報は以下のコマンドが未インストールのため取得できませんでした："
  for cmd in $(echo "$MISSING_CMDS" | tr ' ' '\n' | sort -u); do
    echo " - $cmd"
  done
  echo
  echo "以下のようにインストールしてください（例）："
  echo "■ Debian/Ubuntu 系: sudo apt install パッケージ名"
  echo "■ RedHat/Fedora 系: sudo dnf install パッケージ名"
  echo "■ Arch Linux 系:     sudo pacman -S パッケージ名"
  echo "■ macOS (Homebrew):  brew install パッケージ名"
  echo
  echo "[!] 補足情報の出力はここまでです"
} >&2
fi
