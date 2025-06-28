#!/bin/bash

set -e
set -u

#chmod +x run_all.sql.sh
#./run_all.sql.sh

# Cấu hình
DB_NAME="shhh"
DB_USER="postgres"
DB_HOST="localhost"
DB_PORT="5432"

# Lệnh kết nối
PSQL="psql -X --set ON_ERROR_STOP=on -U $DB_USER -h $DB_HOST -p $DB_PORT -d $DB_NAME"

# Mảng chứa thứ tự thư mục
FOLDERS=(
  "1_enums"
  "2_tables"
  "3_constraints"
  "4_indexs"
  "5_function"
  "6_triggers"
  "7_views"
  "8_data"
)

echo ">> Bắt đầu chạy migration..."

for DIR in "${FOLDERS[@]}"; do
  echo ">> Đang chạy thư mục: $DIR"
  for FILE in sql/$DIR/*.sql; do
    if [ -f "$FILE" ]; then
      echo ">>>> Chạy file: $FILE"
      $PSQL -f "$FILE"
    fi
  done
done

echo ">> Đã hoàn tất migration 🎉"