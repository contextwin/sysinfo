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
  echo "使用法: $0 [--text|--json|--html] [--simple|--detail]"
  echo "  --text     テキスト出力（デフォルト）"
  echo "  --json     JSON 出力"
  echo "  --html     HTML テーブル出力"
  echo "  --simple   簡易モード（主要な情報のみ）"
  echo "  --detail   詳細モード（全情報を表示）"
  exit 1
}

# デフォルトモード
MODE=text
LEVEL=detail

# 引数処理
for arg in "$@"; do
  case "$arg" in
    --text) MODE=text ;;
    --json) MODE=json ;;
    --html) MODE=html ;;
    --simple) LEVEL=simple ;;
    --detail) LEVEL=detail ;;
    *) print_usage ;;
  esac
done

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
      printf '  "%s": "%s",\n' "$SECTION" "$CONTENT_ESC"
      ;;
    html)
      printf '<tr><th>%s</th><td><pre>%s</pre></td></tr>\n' "$(html_escape "$SECTION")" "$(html_escape "$CONTENT")"
      ;;
  esac
}

# HTML/JSONヘッダ
[ "$MODE" = html ] && echo "<html><head><meta charset=\"UTF-8\"><title>System Info</title></head><body><table border=1>"
[ "$MODE" = json ] && echo "{"

MISSING_CMDS=""
check_cmd() {
  command -v "$1" >/dev/null 2>&1 || MISSING_CMDS="$MISSING_CMDS $1"
}

# OS種別取得
OSNAME="$(uname)"

# 共通情報（simple/detail 両対応）
case "$OSNAME" in
  Linux)
    OS_INFO="$(uname -a)
$(cat /etc/os-release 2>/dev/null)"
    ;;
  FreeBSD)
    OS_INFO="$(uname -a)
$(cat /etc/os-release 2>/dev/null || echo 'FreeBSD (os-release not found)')"
    ;;
  Darwin)
    OS_INFO="$(uname -a)
sw_vers"
    ;;
  *)
    OS_INFO="$(uname -a)"
    ;;
esac

collect_info "OS情報" "$OS_INFO"

case "$OSNAME" in
  Linux|FreeBSD|Darwin)
    KERNEL_VER="$(uname -r)"
    ;;
  *)
    KERNEL_VER="$(uname -r)"
    ;;
esac

collect_info "カーネル" "$KERNEL_VER"
collect_info "ホスト名と稼働時間" "$(hostname)
$(uptime 2>/dev/null || echo 'uptime 不使用')"

# CPU情報
case "$OSNAME" in
  Linux)
    CPU_INFO="$(grep -m 1 'model name' /proc/cpuinfo 2>/dev/null)
$(nproc --all 2>/dev/null || getconf _NPROCESSORS_ONLN)"
    ;;
  FreeBSD)
    CPU_INFO="$(sysctl -n hw.model 2>/dev/null)
$(sysctl -n hw.ncpu 2>/dev/null)"
    ;;
  Darwin)
    CPU_INFO="$(sysctl -n machdep.cpu.brand_string 2>/dev/null)
$(sysctl -n hw.ncpu 2>/dev/null)"
    ;;
  *)
    CPU_INFO="CPU情報 取得不可"
    ;;
esac

collect_info "CPU情報" "$CPU_INFO"

# メモリ情報
case "$OSNAME" in
  Linux)
    MEM_INFO="$(free -h 2>/dev/null)"
    ;;
  FreeBSD)
    MEM_INFO="$(sysctl hw.physmem hw.usermem 2>/dev/null | awk '{print $1 ": " $2}')"
    ;;
  Darwin)
    MEM_INFO="$(vm_stat 2>/dev/null)"
    ;;
  *)
    MEM_INFO="メモリ情報 取得不可"
    ;;
esac
collect_info "メモリ情報" "$MEM_INFO"

# ディスク情報
case "$OSNAME" in
  Linux)
    DISK_INFO="$(df -h --total 2>/dev/null || df -h)"
    ;;
  FreeBSD|Darwin)
    DISK_INFO="$(df -h)"
    ;;
  *)
    DISK_INFO="ディスク情報 取得不可"
    ;;
esac
collect_info "ディスク情報" "$DISK_INFO"

if [ "$LEVEL" = simple ]; then
  # 簡易モード
  case "$OSNAME" in
    Linux)
      NET_INFO="$(ip a 2>/dev/null || ifconfig)"
      ;;
    FreeBSD|Darwin)
      NET_INFO="$(ifconfig)"
      ;;
    *)
      NET_INFO="ネットワーク情報 取得不可"
      ;;
  esac
  collect_info "ネットワーク" "$NET_INFO"

  LOGIN_INFO="$(who)"
  collect_info "ログインユーザー" "$LOGIN_INFO"

else
  # 詳細モード
  case "$OSNAME" in
    Linux)
      MOUNT_INFO="$(mount | grep '^/dev' || echo '（情報取得できません）')"
      ;;
    FreeBSD)
      MOUNT_INFO="$(mount | grep -E '^/' || echo '（情報取得できません）')"
      ;;
    Darwin)
      MOUNT_INFO="$(mount)"
      ;;
    *)
      MOUNT_INFO="マウント状況 取得不可"
      ;;
  esac
  collect_info "マウント状況" "$MOUNT_INFO"

  case "$OSNAME" in
    Linux)
      NET_INFO="$(ip a 2>/dev/null || ifconfig)"
      ;;
    FreeBSD|Darwin)
      NET_INFO="$(ifconfig)"
      ;;
    *)
      NET_INFO="ネットワーク情報 取得不可"
      ;;
  esac
  collect_info "ネットワーク" "$NET_INFO"

  LOGIN_INFO="$(who)"
  collect_info "ログインユーザーとログイン情報" "$LOGIN_INFO"

  case "$OSNAME" in
    Linux)
      STORAGE_INFO="$(lsblk 2>/dev/null || echo 'lsblk 不使用')"
      ;;
    FreeBSD)
      STORAGE_INFO="$(geom disk list 2>/dev/null || echo 'geom 不使用')"
      ;;
    Darwin)
      STORAGE_INFO="$(diskutil list 2>/dev/null || echo 'diskutil 不使用')"
      ;;
    *)
      STORAGE_INFO="ストレージ構成 取得不可"
      ;;
  esac
  collect_info "ストレージ構成" "$STORAGE_INFO"

  case "$OSNAME" in
    Linux)
      GPU_INFO="$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' || echo 'lspci 不使用')"
      ;;
    FreeBSD)
      GPU_INFO="$(pciconf -lv 2>/dev/null | grep -Ei 'vga|3d|display' || echo 'pciconf 不使用')"
      ;;
    Darwin)
      GPU_INFO="$(system_profiler SPDisplaysDataType 2>/dev/null || echo 'system_profiler 不使用')"
      ;;
    *)
      GPU_INFO="GPU情報 取得不可"
      ;;
  esac
  collect_info "GPU/PCIデバイス" "$GPU_INFO"

  case "$OSNAME" in
    Linux)
      LSCU_INFO="$(lscpu 2>/dev/null || echo 'lscpu 不使用')"
      ;;
    FreeBSD)
      LSCU_INFO="lscpu 不使用（FreeBSDでは sysctl 等で代替可）"
      ;;
    Darwin)
      LSCU_INFO="lscpu 不使用（macOSでは sysctl 等で代替可）"
      ;;
    *)
      LSCU_INFO="lscpu 情報 取得不可"
      ;;
  esac
  collect_info "lscpu 情報" "$LSCU_INFO"

  case "$OSNAME" in
    Linux)
      LSHW_INFO="$(lshw -short 2>/dev/null || echo 'lshw 不使用')"
      ;;
    FreeBSD|Darwin)
      LSHW_INFO="lshw 不使用"
      ;;
    *)
      LSHW_INFO="lshw 情報 取得不可"
      ;;
  esac
  collect_info "lshw 情報" "$LSHW_INFO"

  case "$OSNAME" in
    Linux)
      INXI_INFO="$(inxi -Fxz 2>/dev/null || echo 'inxi 不使用')"
      ;;
    FreeBSD|Darwin)
      INXI_INFO="inxi 不使用"
      ;;
    *)
      INXI_INFO="inxi 情報 取得不可"
      ;;
  esac
  collect_info "inxi 情報" "$INXI_INFO"

  # smartctl 情報（sudo 不要な範囲）
  if command -v smartctl >/dev/null 2>&1; then
    SMART_INFO=""
    DEVICES=""
    case "$OSNAME" in
      Linux)
        DEVICES="/dev/sd? /dev/nvme?n1"
        ;;
      FreeBSD)
        DEVICES="/dev/ada? /dev/nvd? /dev/da?"
        ;;
      Darwin)
        DEVICES="/dev/disk?"
        ;;
      *)
        DEVICES=""
        ;;
    esac

    for dev in $DEVICES; do
      [ -e "$dev" ] || continue
      INFO=$(smartctl -H -i -A "$dev" 2>/dev/null | grep -E 'Model|Serial|SMART overall|Temperature|Reallocated' || echo '取得不可')
      SMART_INFO="$SMART_INFO\n=== $dev ===\n$INFO\n"
    done
    collect_info "S.M.A.R.T.情報（smartctl）" "$SMART_INFO"
  else
    collect_info "S.M.A.R.T.情報（smartctl）" "smartctl 未インストール"
    MISSING_CMDS="$MISSING_CMDS smartmontools"
  fi

  # GUI 関連
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

  # ウィンドウマネージャー
  WMS="gnome-shell kwin xfwm4 openbox i3 sway mutter kwin_x11"
  FOUND_WM=""
  for wm in $WMS; do
    ps -e | grep -w "$wm" >/dev/null 2>&1 && FOUND_WM="$FOUND_WM $wm"
  done
  collect_info "ウィンドウマネージャー・DE" "${FOUND_WM:-検出できませんでした}"

  # ディスプレイ情報
  XRANDR_OUT="$(xrandr --query 2>/dev/null || echo 'xrandr 不使用')"
  XDPYINFO_OUT="$(xdpyinfo 2>/dev/null | grep dimensions || echo 'xdpyinfo 不使用')"
  collect_info "ディスプレイ情報" "$XRANDR_OUT\n$XDPYINFO_OUT"
fi

# JSON/HTML フッター
[ "$MODE" = json ] && echo '  "EOF": "true"' && echo "}"
[ "$MODE" = html ] && echo "</table></body></html>"

# 未インストールコマンドの案内
if [ -n "$MISSING_CMDS" ]; then
{
  echo
  echo "[!] この補足はstderrに出力されています"
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
  echo "■ FreeBSD:           sudo pkg install パッケージ名"
  echo "■ macOS (Homebrew):  brew install パッケージ名"
  echo
  echo "[!] 補足情報の出力はここまでです"

} >&2
fi
