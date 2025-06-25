#!/bin/sh

OS=$(uname)

echo "===== システム情報収集レポート ====="
echo

# 共通：OS情報
echo "【OS情報】"
uname -a
[ -f /etc/os-release ] && cat /etc/os-release
[ "$OS" = "FreeBSD" ] && freebsd-version
[ "$OS" = "Darwin" ] && sw_vers

echo

# 共通：カーネルバージョン
echo "【カーネル】"
uname -r
echo

# 共通：ホスト名と稼働時間
echo "【ホスト名と稼働時間】"
hostname
uptime
echo

# 共通：CPU情報
echo "【CPU情報】"
if [ "$OS" = "Linux" ]; then
  grep -m 1 "model name" /proc/cpuinfo
  nproc --all
elif [ "$OS" = "FreeBSD" ]; then
  sysctl -n hw.model
  sysctl -n hw.ncpu
elif [ "$OS" = "Darwin" ]; then
  sysctl -n machdep.cpu.brand_string
  sysctl -n hw.ncpu
fi
echo

# 共通：メモリ情報
echo "【メモリ情報】"
if [ "$OS" = "Linux" ]; then
  free -h
elif [ "$OS" = "FreeBSD" ]; then
  sysctl -n hw.physmem
elif [ "$OS" = "Darwin" ]; then
  sysctl -n hw.memsize
fi
echo

# 共通：ディスク使用状況
echo "【ディスク情報】"
df -h --total 2>/dev/null || df -h
echo

# 共通：マウントポイント
echo "【マウント状況】"
mount | grep "^/dev" || echo "（情報取得できません）"
echo

# 共通：ネットワーク
echo "【ネットワーク】"
if command -v ip >/dev/null 2>&1; then
  ip a
else
  ifconfig
fi
echo

# 共通：ログインユーザーと履歴
echo "【ユーザーとログイン情報】"
who
echo

if command -v last >/dev/null 2>&1; then
  echo "【ログイン履歴】"
  last -n 3
else
  echo "【ログイン履歴】（lastコマンド未使用）"
  echo "この情報を取得するには util-linux パッケージのインストールを推奨します"
fi
echo

# 共通：GUI情報（簡易）
echo "【GUIセッション情報】"
echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-不明}"
echo "DESKTOP_SESSION=${DESKTOP_SESSION:-不明}"
echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-不明}"
echo

# Linux専用ハードウェア情報補完
if [ "$OS" = "Linux" ]; then
  echo "【CPU詳細情報（lscpu）】"
  command -v lscpu >/dev/null && lscpu || echo "lscpuがありません"
  echo

  echo "【ストレージ構成（lsblk）】"
  command -v lsblk >/dev/null && lsblk || echo "lsblkがありません"
  echo

  echo "【PCIデバイス（GPUなど）】"
  command -v lspci >/dev/null && lspci | grep -Ei 'vga|3d|display' || echo "lspciがありません"
  echo

  echo "【ハードウェア情報（lshw）】"
  command -v lshw >/dev/null && sudo lshw -short || echo "lshwがありません"
  echo

  echo "【統合システム情報（inxi）】"
  command -v inxi >/dev/null && inxi -Fxz || echo "inxiがありません"
  echo

  echo "【GUI関連情報】"
  wm_procs="gnome-shell kwin xfwm4 openbox i3 sway mutter kwin_x11"
  found_wms=""
  for proc in $wm_procs; do
    if ps -e | grep -w "$proc" >/dev/null 2>&1; then
      found_wms="$found_wms $proc"
    fi
  done
  [ -n "$found_wms" ] && echo "検出されたWM/DE:$found_wms" || echo "WMプロセス検出不能"

  echo
  echo "ウィンドウ情報 (wmctrl):"
  command -v wmctrl >/dev/null && wmctrl -l || echo "wmctrl未インストール"

  echo
  echo "ディスプレイ情報 (xrandr):"
  command -v xrandr >/dev/null && xrandr --query || echo "xrandr未インストール"

  echo
  echo "画面寸法 (xdpyinfo):"
  command -v xdpyinfo >/dev/null && xdpyinfo | grep dimensions || echo "xdpyinfo未インストール"
fi

# FreeBSD向け
if [ "$OS" = "FreeBSD" ]; then
  echo "【CPU詳細】"
  sysctl -a | grep machdep.cpu

  echo
  echo "【ストレージ構成】"
  gpart show

  echo
  echo "【PCIデバイス】"
  pciconf -lv

  echo
  echo "【USBデバイス】"
  usbconfig
fi

# macOS向け
if [ "$OS" = "Darwin" ]; then
  echo "【ハードウェア概要】"
  system_profiler SPHardwareDataType

  echo
  echo "【GPU情報】"
  system_profiler SPDisplaysDataType

  echo
  echo "【ストレージ情報】"
  system_profiler SPStorageDataType

  echo
  echo "【USB/PCIデバイス】"
  system_profiler SPUSBDataType
  system_profiler SPPciDataType
fi

echo "===== 終了 ====="
