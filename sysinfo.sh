#!/bin/sh

print_section() {
  echo
  echo "===== $1 ====="
}

print_item() {
  echo
  echo "【$1】"
}

get_os_info() {
  print_section "システム情報収集レポート"

  print_item "OS情報"
  uname -a
  if [ -f /etc/os-release ]; then
    cat /etc/os-release
  elif [ "$(uname)" = "FreeBSD" ]; then
    freebsd-version
  elif [ "$(uname)" = "Darwin" ]; then
    sw_vers
  fi

  print_item "カーネル"
  uname -r

  print_item "ホスト名と稼働時間"
  hostname
  uptime
}

get_cpu_info() {
  print_item "CPU情報"
  if [ -f /proc/cpuinfo ]; then
    grep -m 1 "model name" /proc/cpuinfo
  elif command -v sysctl >/dev/null 2>&1; then
    sysctl -n machdep.cpu.brand_string 2>/dev/null || sysctl -n hw.model
  fi
  command -v nproc >/dev/null 2>&1 && nproc --all || sysctl -n hw.ncpu
  command -v lscpu >/dev/null 2>&1 && lscpu || echo "lscpu が利用できません"
}

get_memory_info() {
  print_item "メモリ情報"
  command -v free >/dev/null 2>&1 && free -h || vm_stat
}

get_disk_info() {
  print_item "ディスク情報"
  df -h
}

get_mount_info() {
  print_item "マウント状況"
  mount | grep "^/dev" || echo "（情報取得できません）"
}

get_network_info() {
  print_item "ネットワーク"
  if command -v ip >/dev/null 2>&1; then
    ip a
  else
    ifconfig
  fi
}

get_user_info() {
  print_item "ユーザーとログイン情報"
  who

  if command -v last >/dev/null 2>&1; then
    print_item "ログイン履歴"
    last -n 3
  else
    echo "ログイン履歴取得には last コマンドが必要です"
  fi
}

get_storage_info() {
  print_item "ストレージ構成"
  if command -v lsblk >/dev/null 2>&1; then
    lsblk
  else
    echo "lsblk が利用できません（util-linux 推奨）"
  fi
}

get_pci_info() {
  print_item "PCIデバイス情報（GPUなど）"
  if command -v lspci >/dev/null 2>&1; then
    lspci | grep -Ei 'vga|3d|display'
  else
    echo "lspci が利用できません（pciutils 推奨）"
  fi
}

get_additional_info() {
  if command -v lshw >/dev/null 2>&1; then
    print_item "ハードウェア詳細情報（lshw）"
    lshw -short
  else
    echo "lshw が利用できません（lshw パッケージ推奨）"
  fi

  if command -v inxi >/dev/null 2>&1; then
    print_item "統合システム情報（inxi）"
    inxi -Fxz
  else
    echo "inxi が利用できません（inxi パッケージ推奨）"
  fi
}

get_gui_info() {
  print_item "GUI関連情報"

  echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-未設定}"
  echo "DESKTOP_SESSION=${DESKTOP_SESSION:-未設定}"
  echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-未設定}"
  echo "DISPLAY=${DISPLAY:-未設定}"
  echo "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-未設定}"
  echo "SSH_CONNECTION=${SSH_CONNECTION:-ローカル}" 

  if [ -n "$SSH_CONNECTION" ]; then
    echo "※ SSH 経由のリモートセッションです"
  fi

  if [ -n "$DISPLAY" ] && [ -n "$WAYLAND_DISPLAY" ]; then
    echo "※ X11 と Wayland の両方が使用されています（混在）"
  elif [ -n "$WAYLAND_DISPLAY" ]; then
    echo "Wayland セッションです"
  elif [ -n "$DISPLAY" ]; then
    echo "X11 セッションです"
  else
    echo "GUIセッション情報は取得できませんでした"
  fi

  print_item "ウィンドウマネージャー/DEのプロセス検出"
  WMS="gnome-shell kwin xfwm4 openbox i3 sway mutter kwin_x11"
  found=""
  for wm in $WMS; do
    if ps -e | grep -w "$wm" >/dev/null 2>&1; then
      found="$found $wm"
    fi
  done
  if [ -n "$found" ]; then
    echo "検出されたプロセス:$found"
  else
    echo "WM/DEプロセスは検出されませんでした"
  fi

  print_item "ウィンドウ情報（wmctrl）"
  if command -v wmctrl >/dev/null 2>&1; then
    wmctrl -l
  else
    echo "wmctrl が利用できません（インストールを推奨）"
  fi

  print_item "ディスプレイ情報（xrandr）"
  if command -v xrandr >/dev/null 2>&1; then
    xrandr --query
  else
    echo "xrandr が利用できません"
  fi

  print_item "画面寸法（xdpyinfo）"
  if command -v xdpyinfo >/dev/null 2>&1; then
    xdpyinfo | grep dimensions
  else
    echo "xdpyinfo が利用できません"
  fi
}

print_footer() {
  print_section "補足：詳細取得に便利なコマンド"
  echo " - lscpu       （CPU詳細）"
  echo " - lshw        （ハードウェア構成）"
  echo " - inxi        （統合システム情報）"
  echo " - xrandr      （ディスプレイ構成）"
  echo

  echo "推奨パッケージ導入例:"
  echo "■ Debian系 Linux:"
  echo "  sudo apt install pciutils util-linux lshw inxi wmctrl x11-utils"
  echo
  echo "■ FreeBSD:"
  echo "  sudo pkg install pciutils lshw inxi wmctrl xrandr xdpyinfo"
  echo
  echo "■ macOS (Homebrew):"
  echo "  brew install pciutils lshw inxi wmctrl xrandr xdpyinfo"
  echo
  echo "※ macOS では一部コマンドは制限される場合があります"
  echo
  echo "===== 終了 ====="
}

# 実行セクション
get_os_info
get_cpu_info
get_memory_info
get_disk_info
get_mount_info
get_network_info
get_user_info
get_storage_info
get_pci_info
get_additional_info
get_gui_info
print_footer
