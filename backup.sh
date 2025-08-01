#!/bin/bash

# WordPress Backup Script
# ----------------------------------------------------------------
#
# 使い方:
# ./backup.sh [SITE_NAME]
#
# 例:
# ./backup.sh hm-labo
#
# 概要:
# 指定されたサイトのWordPressファイルとデータベースをバックアップし、
# ローカルの `backups` ディレクトリにダウンロードします。
# 実行する前に `.env` ファイルにサイトの設定を正しく記述してください。

set -e

# --- 引数のチェック ---
if [ -z "$1" ]; then
  echo "エラー: サイト識別名を指定してください。"
  echo "使い方: ./backup.sh [SITE_NAME]"
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
    
    # .envファイルから値を取得
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
DB_NAME=$(load_config "$SITE_NAME" "DB_NAME")
DB_USER=$(load_config "$SITE_NAME" "DB_USER")
DB_PASSWORD=$(load_config "$SITE_NAME" "DB_PASSWORD")
DB_HOST=$(load_config "$SITE_NAME" "DB_HOST")

LOCAL_BACKUP_DIR=$(grep "^LOCAL_BACKUP_DIR=" "$ENV_FILE" | cut -d'=' -f2- | sed 's/"//g')

# --- ローカルバックアップディレクトリの作成 ---
mkdir -p "${LOCAL_BACKUP_DIR}/${SITE_NAME}"

# --- 変数定義 ---
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
REMOTE_BACKUP_DIR="/tmp/wp_backup_${SITE_NAME}_${TIMESTAMP}"
DB_BACKUP_FILE="db_${SITE_NAME}_${TIMESTAMP}.sql"
FILES_BACKUP_FILE="files_${SITE_NAME}_${TIMESTAMP}.tar.gz"

SSH_CMD="ssh -p ${SSH_PORT} -i ${SSH_KEY_PATH} ${SSH_USER}@${SSH_HOST}"
SCP_CMD="scp -P ${SSH_PORT} -i ${SSH_KEY_PATH}"

# --- バックアップ処理開始 ---
echo "----------------------------------------------------------------"
echo "バックアップを開始します: ${SITE_NAME}"
echo "タイムスタンプ: ${TIMESTAMP}"
echo "----------------------------------------------------------------"

# --- リモートサーバーでの処理 ---
$SSH_CMD << EOF
  set -e
  echo "[1/4] リモートサーバーにバックアップディレクトリを作成します..."
  mkdir -p ${REMOTE_BACKUP_DIR}
  echo "  => ${REMOTE_BACKUP_DIR}"

  echo "\n[2/4] データベースをエクスポートします..."
  mysqldump -h "${DB_HOST}" -u "${DB_USER}" -p"${DB_PASSWORD}" "${DB_NAME}" > "${REMOTE_BACKUP_DIR}/${DB_BACKUP_FILE}"
  echo "  => ${DB_BACKUP_FILE}"

  echo "\n[3/4] WordPressファイルを圧縮します..."
  tar -czf "${REMOTE_BACKUP_DIR}/${FILES_BACKUP_FILE}" -C "$(dirname ${WP_PATH})" "$(basename ${WP_PATH})"
  echo "  => ${FILES_BACKUP_FILE}"
  echo "  圧縮が完了しました。"
EOF

# --- ローカルへのダウンロード ---
echo "\n[4/4] バックアップファイルをローカルにダウンロードします..."
${SCP_CMD} "${SSH_USER}@${SSH_HOST}:${REMOTE_BACKUP_DIR}/*" "${LOCAL_BACKUP_DIR}/${SITE_NAME}/"
echo "  => ${LOCAL_BACKUP_DIR}/${SITE_NAME}/"

# --- リモートサーバーのクリーンアップ ---
echo "\n[+] リモートサーバー上の一時ファイルをクリーンアップします..."
$SSH_CMD "rm -rf ${REMOTE_BACKUP_DIR}"
echo "  => ${REMOTE_BACKUP_DIR} を削除しました。"


echo "\n----------------------------------------------------------------"
echo "バックアップが正常に完了しました！"
echo "保存先: ${LOCAL_BACKUP_DIR}/${SITE_NAME}/"
echo "----------------------------------------------------------------"
