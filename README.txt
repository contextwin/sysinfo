git clone https://github.com/contextwin/sysinfo

このリポジトリには、UbuntuシステムのハードウェアとOS情報を詳細に取得するシェルスクリプト sysinfo.sh が含まれています。

2025/06/25 更にGUIやディスプレイに関する情報を詳細に取得する機能を追加しました。
2025/06/25 更にLinux,FreeBSD,macOS(Darwin),で動作するように改良しました(Ubuntuでしか動作確認できてませんが,,,,,,)。

実行権を付与して実行して下さい。
chomod +x sysinfo.sh
./sysinfo

BIOS/ファームウェアに関する情報が欲しい場合は以下のコマンドを実行して下さい
command -v dmidecode >/dev/null && sudo dmidecode | grep -A3 'System Information'
