#!/bin/sh

#===== システム情報収集レポート =====
echo "===== システム情報収集レポート ====="
echo

# OS情報
echo "【OS情報】"
uname -a
[ -f /etc/os-release ] && cat /etc/os-release
[ -f /usr/lib/os-release ] && cat /usr/lib/os-release
[ "$(uname)" = "Darwin" ] && sw_vers
[ "$(uname)" = "FreeBSD" ] && freebsd-version
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
grep -m 1 "model name" /proc/cpuinfo 2>/dev/null
nproc --all 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo "CPUコア数情報取得不可"
echo

# メモリ情報
echo "【メモリ情報】"
free -h 2>/dev/null || vm_stat 2>/dev/null || top -l 1 | grep PhysMem
echo

# ディスク使用状況
echo "【ディスク情報】"
df -h --total 2>/dev/null || df -h
echo

# マウントポイント
echo "【マウント状況】"
mount | grep "^/dev" || echo "（情報取得できません）"
echo

# ネットワークインタフェース
echo "【ネットワーク】"
ip a 2>/dev/null || ifconfig -a
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
fi
echo

# ストレージ情報
if command -v lsblk >/dev/null 2>&1; then
  echo "【ストレージ構成】"
  lsblk
else
  echo "【ストレージ構成】（lsblk未使用）"
fi
echo

# PCIデバイス情報（GPUなど）
if command -v lspci >/dev/null 2>&1; then
  echo "【PCIデバイス情報（GPUなど）】"
  lspci | grep -Ei 'vga|3d|display'
else
  echo "【PCIデバイス情報】（lspci未使用）"
fi
echo

# CPU詳細（lscpu）
if command -v lscpu >/dev/null 2>&1; then
  echo "【CPU詳細情報（lscpu）】"
  lscpu
else
  echo "【CPU詳細情報】（lscpu未使用）"
fi
echo

# ハードウェア詳細（lshw）
if command -v lshw >/dev/null 2>&1; then
  echo "【ハードウェア詳細情報（lshw）】"
  lshw -short
else
  echo "【ハードウェア詳細情報】（lshw未使用）"
fi
echo

# 統合システム情報（inxi）
if command -v inxi >/dev/null 2>&1; then
  echo "【統合システム情報（inxi）】"
  inxi -Fxz
else
  echo "【統合システム情報】（inxi未使用）"
fi
echo

# GUI関連情報取得関数
get_gui_info() {
  echo "【GUI関連情報】"
  OS_NAME=$(uname)

  echo "■ 基本環境変数:"
  echo "XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-不明}"
  echo "DESKTOP_SESSION=${DESKTOP_SESSION:-不明}"
  echo "XDG_SESSION_TYPE=${XDG_SESSION_TYPE:-不明}"
  echo "DISPLAY=${DISPLAY:-未設定}"
  echo "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-未設定}"
  echo

  echo "■ リモートセッション判定:"
  if [ -n "$SSH_CONNECTION" ] || [ -n "$SSH_CLIENT" ]; then
    echo "→ 現在のセッションは SSH 経由です"
    if echo "$DISPLAY" | grep -q '^localhost:'; then
      echo "→ X11 フォワーディング有効（DISPLAY=$DISPLAY）"
    else
      echo "→ X11 フォワーディングは無効または未使用"
    fi
  else
    echo "→ SSHセッションではありません（ローカルログイン）"
  fi
  echo

  echo "■ Wayland / X11 判定:"
  if [ -n "$WAYLAND_DISPLAY" ] && [ -n "$DISPLAY" ]; then
    echo "→ Wayland と X11 の混在環境"
  elif [ -n "$WAYLAND_DISPLAY" ]; then
    echo "→ Wayland セッション"
  elif [ -n "$DISPLAY" ]; then
    echo "→ X11 セッション"
  else
    echo "→ GUIセッションが検出できません（またはCLI環境）"
  fi
  echo

  echo "■ ウィンドウマネージャー / GUIプロセス候補:"
  case "$OS_NAME" in
    Linux)
      wm_procs="gnome-shell kwin kwin_wayland xfwm4 openbox i3 sway mutter marco compiz awesome"
      for proc in $wm_procs; do
        if ps -e | grep -w "$proc" >/dev/null 2>&1; then
          echo "  - $proc"
        fi
      done
      ;;
    FreeBSD)
      for proc in gnome-shell kwin xfwm4 openbox i3 sway mutter; do
        if ps ax | grep -w "$proc" | grep -v grep >/dev/null 2>&1; then
          echo "  - $proc"
        fi
      done
      ;;
    Darwin)
      for proc in WindowServer Dock Finder; do
        if ps ax | grep -w "$proc" | grep -v grep >/dev/null 2>&1; then
          echo "  - $proc"
        fi
      done
      ;;
  esac
  echo

  echo "■ ディスプレイ / 解像度情報:"
  case "$OS_NAME" in
    Linux|FreeBSD)
      command -v xrandr >/dev/null 2>&1 && xrandr --query || echo "xrandr 未インストール"
      command -v xdpyinfo >/dev/null 2>&1 && xdpyinfo | grep dimensions || echo "xdpyinfo 未インストール"
      ;;
    Darwin)
      system_profiler SPDisplaysDataType 2>/dev/null | grep -E 'Display Type|Resolution|Main Display'
      ;;
  esac
  echo

  echo "■ ウィンドウ一覧:"
  command -v wmctrl >/dev/null 2>&1 && wmctrl -l || echo "wmctrl 不在。インストールで取得可能（Linux向け）"
  echo
}

# 呼び出し
get_gui_info

echo "===== 終了 ====="
echo 更にハードウェアの詳細な情報が欲しい場合は以下のコマンドを実行して下さい
echo "command -v lshw >/dev/null && sudo lshw"
echo 更にBIOS/ファームウェアに関する情報が欲しい場合は以下のコマンドを実行して下さい
echo "command -v dmidecode >/dev/null && sudo dmidecode | grep -A3 'System Information'"
