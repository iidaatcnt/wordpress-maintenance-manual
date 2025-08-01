#!/bin/bash

# WordPress Update Script (using WP-CLI)
# ----------------------------------------------------------------
#
# 使い方:
# ./update.sh [SITE_NAME]
#
# 例:
# ./update.sh hm-labo
#
# 概要:
# 指定されたサイトのWordPressコア、プラグイン、テーマをすべて更新します。
#
# *** 注意 ***
# このスクリプトを実行する前に、必ずバックアップを取得してください。
# サーバーに WP-CLI がインストールされている必要があります。
# 実行する前に `.env` ファイルにサイトの設定を正しく記述してください。

set -e

# --- 引数のチェック ---
if [ -z "$1" ]; then
  echo "エラー: サイト識別名を指定してください。"
  echo "使い方: ./update.sh [SITE_NAME]"
  exit 1
fi

SITE_NAME=$1

# --- .env ファイルの読み込み ---
ENV_FILE=".env"
if [ ! -f "$ENV_FILE" ]; then
  echo "エラー: .env ファイルが見つかりません。 .env.template をコピーして作成してください。"
  exit 1
fi

# 指定されたサイトの設定を .env から読み込む関数
load_config() {
    local site_prefix=$(echo "$1" | tr '[:lower:]' '[:upper:]' | tr '-' '_')
    local var_name_suffix=$2
    local var_name="SITE_${site_prefix}_${var_name_suffix}"
    
    local value=$(grep "^${var_name}=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/"//g')
    
    if [ -z "$value" ]; then
        echo "エラー: .env ファイルに ${var_name} の設定が見つかりません。"
        exit 1
    fi
    echo "$value"
}

SSH_HOST=$(load_config "$SITE_NAME" "SSH_HOST")
SSH_USER=$(load_config "$SITE_NAME" "SSH_USER")
SSH_PORT=$(load_config "$SITE_NAME" "SSH_PORT")
SSH_KEY_PATH=$(load_config "$SITE_NAME" "SSH_KEY_PATH")
WP_PATH=$(load_config "$SITE_NAME" "WP_PATH")

SSH_CMD="ssh -p ${SSH_PORT} -i ${SSH_KEY_PATH} ${SSH_USER}@${SSH_HOST}"

# --- アップデート処理開始 ---
echo "----------------------------------------------------------------"
echo "アップデートを開始します: ${SITE_NAME}"
echo "対象ディレクトリ: ${WP_PATH}"
echo "----------------------------------------------------------------"

# --- リモートサーバーでの処理 ---
$SSH_CMD << EOF
  set -e
  echo "[1/4] WP-CLIの存在を確認します..."
  if ! command -v wp &> /dev/null
  then
      echo "エラー: サーバーに WP-CLI がインストールされていません。"
      echo "インストール方法はこちらを参照してください: https://wp-cli.org/"
      exit 1
  fi
  echo "  => WP-CLIが見つかりました。"

  echo "\n[2/4] WordPressコアをアップデートします..."
  wp core update --path=${WP_PATH}

  echo "\n[3/4] プラグインをすべてアップデートします..."
  wp plugin update --all --path=${WP_PATH}

  echo "\n[4/4] テーマをすべてアップデートします..."
  wp theme update --all --path=${WP_PATH}

EOF

echo "\n----------------------------------------------------------------"
echo "アップデートが正常に完了しました！"
echo "サイトの動作をブラウザで確認してください。"
echo "----------------------------------------------------------------"
