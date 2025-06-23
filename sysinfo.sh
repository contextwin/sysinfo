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
  sudo lshw -short
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

echo "===== 補足：より詳細な情報を得るには ====="
echo "以下のコマンドを使えば、より詳細なハードウェア情報が得られます："
echo
echo " - lscpu       （CPU詳細）"
echo " - lshw        （全体のハードウェア構成）"
echo " - inxi        （統合システム情報）"
echo
echo "これらを安全に導入するには："
echo "  sudo apt update"
echo "  sudo apt install pciutils util-linux lshw inxi"
echo
echo "※すべて公式のAPT経由であり、安全性・信頼性が高い方法です。"
echo
echo "===== 終了 ====="
