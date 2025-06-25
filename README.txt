git clone https://github.com/contextwin/sysinfo

このリポジトリには、UbuntuシステムのハードウェアとOS情報を詳細に取得するシェルスクリプト sysinfo.sh が含まれています。

2025/06/25 更にGUIやディスプレイに関する情報を詳細に取得する機能を追加しました。
2025/06/25 更にLinux,FreeBSD,macOS(Darwin),で動作するように改良しました(Ubuntuでしか動作確認できてませんが,,,,,,)。
2025/06/25 更にオプション指定でhtml形式,json形式で出力可能になりました

実行権を付与して実行して下さい。
chomod +x sysinfo.sh
./sysinfo

使用法: ./sysinfo.sh [--text|--json|--html]
  --text   テキスト出力（デフォルト）
  --json   JSON 出力
  --html   HTML テーブル出力
何も指定しない場合はテキスト形式で出力します

モードの説明：
    --simple（簡易モード）:
    最低限の情報（OS、カーネル、CPU、メモリ、ディスク、ネットワーク、ログインユーザー）だけを表示
    高速に概要を確認したいときに便利です

    --detail（詳細モード）:
    簡易モードの情報に加えて、S.M.A.R.T. 情報、ストレージ構成、GPU、GUI セッション情報、ディスプレイ設定などの追加情報も含みます
    システム調査や報告用途に最適です

どちらのモードでも出力形式（--text / --json / --html）を組み合わせて利用できます。例：
./sysinfo.sh --json --simple
./sysinfo.sh --html --detail

#root権限が必要なコマンドについて
BIOS/ファームウェアに関する情報が欲しい場合は以下のコマンドを実行して下さい
command -v dmidecode >/dev/null && sudo dmidecode | grep -A3 'System Information'
