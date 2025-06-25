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

# シンプルな POSIX 準拠 JSON エスケープ関数
json_escape() {
  # \ \ " 改行・復帰コードをエスケープ
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/\"/\\"/g; s/\n/\\n/g; s/\r/\\r/g'
}

# HTML エスケープ関数
html_escape() {
  printf '%s' "$1" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g; s/"/\&quot;/g'
}

# オプション判定
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

# 情報収集関数（JSONは値の中身をエスケープのみ。カンマは呼び出し側で制御）
collect_info() {
  SECTION="$1"
  CONTENT="$2"
  case "$MODE" in
    text)
      echo "【$SECTION】"
      printf '%s\n\n' "$CONTENT"
      ;;
    json)
      # JSONの値はエスケープする
      CONTENT_ESC=$(json_escape "$CONTENT")
      # 戻り値は "key":"value"
      printf '  "%s": "%s"' "$SECTION" "$CONTENT_ESC"
      ;;
    html)
      printf '<tr><th>%s</th><td><pre>%s</pre></td></tr>\n' "$(html_escape "$SECTION")" "$(html_escape "$CONTENT")"
      ;;
  esac
}

# テキスト/HTML は単純に順に出力
if [ "$MODE" = html ]; then
  echo "<html><head><meta charset=\"UTF-8\"><title>System Info</title></head><body><table border=1>"
fi

if [ "$MODE" = json ]; then
  echo "{"
fi

# JSON用に情報を配列に格納（POSIXシェルは配列ないので、一時ファイルに保存）
if [ "$MODE" = json ]; then
  TMPFILE=$(mktemp) || exit 1
fi

output_info() {
  if [ "$MODE" = json ]; then
    # JSON用は一時ファイルに "key":"value" 行を保存
    SECTION="$1"
    CONTENT="$2"
    CONTENT_ESC=$(json_escape "$CONTENT")
    printf '  "%s": "%s"\n' "$SECTION" "$CONTENT_ESC" >> "$TMPFILE"
  else
    # text/htmlは即時出力
    collect_info "$1" "$2"
  fi
}

# 収集したい情報を変数に入れてまとめて出す形に
add_info() {
  SECTION="$1"
  CONTENT="$2"
  output_info "$SECTION" "$CONTENT"
}

# --- ここから情報収集 ---

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
add_info "ストレージ構成" "$(lsblk 2>/dev/null || echo 'lsblk 不使用')"
add_info "GPU/PCIデバイス" "$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' || echo 'lspci 不使用')"
add_info "lscpu 情報" "$(lscpu 2>/dev/null || echo 'lscpu 不使用')"
add_info "lshw 情報" "$(lshw -short 2>/dev/null || echo 'lshw 不使用')"
add_info "inxi 情報" "$(inxi -Fxz 2>/dev/null || echo 'inxi 不使用')"

# GUI 情報
GUI_INFO="XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-不明}
DESKTOP_SESSION=${DESKTOP_SESSION:-不明}
XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-不明}
WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-未設定}
DISPLAY=${DISPLAY:-未設定}
SSH_CONNECTION=${SSH_CONNECTION:-ローカル}"
if [ -n "$SSH_CONNECTION" ]; then
  GUI_INFO="$GUI_INFO\n※ SSH 経由のリモートセッションです"
fi
if [ -n "$DISPLAY" ] && [ -n "$WAYLAND_DISPLAY" ]; then
  GUI_INFO="$GUI_INFO\n※ X11 と Wayland の両方が使用されています（混在）"
elif [ -n "$WAYLAND_DISPLAY" ]; then
  GUI_INFO="$GUI_INFO\nWayland セッションです"
elif [ -n "$DISPLAY" ]; then
  GUI_INFO="$GUI_INFO\nX11 セッションです"
else
  GUI_INFO="$GUI_INFO\nGUI セッション情報は取得できませんでした"
fi
add_info "GUI 関連情報" "$GUI_INFO"

# ウィンドウマネージャー検出
WMS="gnome-shell kwin xfwm4 openbox i3 sway mutter kwin_x11"
FOUND_WM=""
for wm in $WMS; do
  if ps -e | grep -w "$wm" >/dev/null 2>&1; then
    FOUND_WM="$FOUND_WM $wm"
  fi
done
[ -z "$FOUND_WM" ] && FOUND_WM="検出できませんでした"
add_info "ウィンドウマネージャー・DE" "$FOUND_WM"

# xrandr, xdpyinfo
XRANDR_OUT="$(xrandr --query 2>/dev/null || echo 'xrandr 不使用')"
XDPYINFO_OUT="$(xdpyinfo 2>/dev/null | grep dimensions || echo 'xdpyinfo 不使用')"
add_info "ディスプレイ情報" "$XRANDR_OUT
$XDPYINFO_OUT"

# --- ここまで情報収集 ---

# JSONの場合は最後に一時ファイルから読み込んでカンマ区切りで出力
if [ "$MODE" = json ]; then
  # 行数取得
  LINECNT=$(wc -l < "$TMPFILE" | tr -d ' ')
  COUNT=0
  while IFS= read -r line; do
    COUNT=$((COUNT + 1))
    # 最終行以外はカンマ付ける
    if [ "$COUNT" -lt "$LINECNT" ]; then
      printf '%s,\n' "$line"
    else
      printf '%s\n' "$line"
    fi
  done < "$TMPFILE"

  # EOFフィールドを追加（カンマつけていい）
  echo '  ,"EOF": "true"'
  echo "}"
  rm -f "$TMPFILE"
fi

if [ "$MODE" = html ]; then
  echo "</table></body></html>"
fi
