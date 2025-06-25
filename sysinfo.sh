#!/bin/sh

echo "===== システム情報収集レポート ====="
echo

# OS情報
echo "【OS情報】"
uname -a
[ -f /etc/os-release ] && cat /etc/os-release
echo

# カーネルバージョン
echo "【カーネル】"
uname -r
echo

# ホスト名と稼働時間
echo "【ホスト名と稼働時間】"
hostname
uptime
echo

# CPU情報
echo "【CPU情報】"
grep -m 1 "model name" /proc/cpuinfo
nproc --all
echo

# メモリ情報
echo "【メモリ情報】"
free -h
echo

# ディスク使用状況
echo "【ディスク情報】"
df -h --total
echo

# マウントポイント
echo "【マウント状況】"
mount | grep "^/dev" || echo "（情報取得できません）"
echo

# ネットワークインタフェース
echo "【ネットワーク】"
ip a
echo

# ログインユーザーとログ履歴
echo "【ユーザーとログイン情報】"
who
echo

# ログイン履歴
if command -v last >/dev/null 2>&1; then
  echo "【ログイン履歴】"
  last -n 3
else
  echo "【ログイン履歴】（lastコマンド未使用）"
  echo "この情報を取得するには util-linux パッケージのインストールを推奨します"
fi
echo

# ストレージ情報
if command -v lsblk >/dev/null 2>&1; then
  echo "【ストレージ構成】"
  lsblk
else
  echo "【ストレージ構成】（lsblk未使用）"
  echo "この情報を取得するには util-linux パッケージのインストールを推奨します"
fi
echo

# PCIデバイス情報（GPUなど）
if command -v lspci >/dev/null 2>&1; then
  echo "【PCIデバイス情報（GPUなど）】"
  lspci | grep -Ei 'vga|3d|display'
else
  echo "【PCIデバイス情報】（lspci未使用）"
  echo "GPU情報などを取得するには pciutils パッケージのインストールを推奨します"
fi
echo

# 追加詳細情報：lscpu
if command -v lscpu >/dev/null 2>&1; then
  echo "【CPU詳細情報（lscpu）】"
  lscpu
else
  echo "【CPU詳細情報】（lscpu未使用）"
  echo "CPUの詳細を知るには util-linux パッケージのインストールを推奨します"
fi
echo

# 追加詳細情報：lshw
if command -v lshw >/dev/null 2>&1; then
  echo "【ハードウェア詳細情報（lshw）】"
  lshw -short
else
  echo "【ハードウェア詳細情報】（lshw未使用）"
  echo "全体のハードウェア構成を知るには lshw パッケージのインストールを推奨します"
fi
echo

# 追加詳細情報：inxi
if command -v inxi >/dev/null 2>&1; then
  echo "【統合システム情報（inxi）】"
  inxi -Fxz
else
  echo "【統合システム情報】（inxi未使用）"
  echo "総合的なシステム情報を得るには inxi パッケージのインストールを推奨します"
fi
echo

# 追加：GUI関連情報（Linux向け）
get_gui_info_linux() {
  echo "【GUI関連情報】"

  echo "デスクトップ環境・セッション情報:"
  echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-不明}"
  echo "DESKTOP_SESSION=${DESKTOP_SESSION:-不明}"
  echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-不明}"
  echo "GDMSESSION=${GDMSESSION:-不明}"
  echo "XDG_SESSION_DESKTOP=${XDG_SESSION_DESKTOP:-不明}"
  echo

  # Wayland or X11判別
  session_type="${XDG_SESSION_TYPE:-unknown}"
  echo "セッションタイプ判別: $session_type"
  echo

  echo "ウィンドウマネージャー候補プロセス検出:"
  wm_procs="gnome-shell kwin xfwm4 openbox i3 sway mutter kwin_x11"
  found_wms=""
  for proc in $wm_procs; do
    if ps -e | grep -w "$proc" >/dev/null 2>&1; then
      found_wms="$found_wms $proc"
    fi
  done
  if [ -n "$found_wms" ]; then
    echo "検出されたウィンドウマネージャー・デスクトップ環境プロセス:$found_wms"
  else
    echo "ウィンドウマネージャー・デスクトップ環境プロセスは検出できませんでした"
  fi
  echo

  if [ "$session_type" = "x11" ]; then
    echo "X11関連情報取得中..."

    echo
    echo "ウィンドウリスト (wmctrl -l):"
    if command -v wmctrl >/dev/null 2>&1; then
      wmctrl -l
    else
      echo "wmctrlコマンドがありません。インストールすると詳細なウィンドウ情報が得られます。"
    fi

    echo
    echo "最前面ウィンドウの詳細情報 (xprop -root _NET_ACTIVE_WINDOW):"
    if command -v xprop >/dev/null 2>&1; then
      active_win_id=$(xprop -root _NET_ACTIVE_WINDOW | awk -F ' ' '{print $5}')
      if [ "$active_win_id" != "0x0" ]; then
        xprop -id "$active_win_id"
      else
        echo "アクティブなウィンドウが検出できません"
      fi
    else
      echo "xpropコマンドがありません。インストールを推奨します。"
    fi

    echo
    echo "ウィンドウ寸法・位置 (xwininfo -root):"
    if command -v xwininfo >/dev/null 2>&1; then
      xwininfo -root
    else
      echo "xwininfoコマンドがありません。インストールを推奨します。"
    fi

    echo
    echo "画面解像度・ディスプレイ情報 (xrandr --query):"
    if command -v xrandr >/dev/null 2>&1; then
      xrandr --query
    else
      echo "xrandrコマンドがありません。ディスプレイ情報が取得できません。"
    fi

    echo
    echo "画面寸法 (xdpyinfo):"
    if command -v xdpyinfo >/dev/null 2>&1; then
      xdpyinfo | grep dimensions
    else
      echo "xdpyinfoコマンドがありません。画面寸法情報が取得できません。"
    fi

  elif [ "$session_type" = "wayland" ]; then
    echo "Wayland関連情報取得中..."

    echo
    echo "WAYLAND_DISPLAY環境変数: ${WAYLAND_DISPLAY:-不明}"

    echo
    if command -v weston-info >/dev/null 2>&1; then
      echo "weston-infoコマンドの出力:"
      weston-info
    else
      echo "weston-infoコマンドがありません。Waylandの詳細情報取得に便利です。"
    fi

    echo
    if command -v wayland-info >/dev/null 2>&1; then
      echo "wayland-infoコマンドの出力:"
      wayland-info
    else
      echo "wayland-infoコマンドがありません。Waylandの詳細情報取得に便利です。"
    fi

    echo
    echo "ウィンドウマネージャーのプロセスやWaylandコンポジターの検出:"
    comp_procs="sway wayland Weston weston"
    found_comps=""
    for proc in $comp_procs; do
      if ps -e | grep -w "$proc" >/dev/null 2>&1; then
        found_comps="$found_comps $proc"
      fi
    done
    if [ -n "$found_comps" ]; then
      echo "検出されたWaylandコンポジター・ウィンドウマネージャー:$found_comps"
    else
      echo "Waylandコンポジター・ウィンドウマネージャーは検出できませんでした"
    fi

  else
    echo "不明なセッションタイプです。環境変数XDG_SESSION_TYPEを確認してください。"
  fi

  echo

  echo "複数ディスプレイ・物理ディスプレイ情報取得（/sys/class/drm/）:"
  if [ -d /sys/class/drm ]; then
    ls -l /sys/class/drm/ | grep card
  else
    echo "/sys/class/drmディレクトリが存在しません。"
  fi
  echo
}

# Linuxの場合はGUI情報収集を実行
if [ "$(uname)" = "Linux" ]; then
  get_gui_info_linux
fi

