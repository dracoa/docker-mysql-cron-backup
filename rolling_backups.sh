#!/bin/bash

DIR_PATH="/mnt/nfs/db-backup/backup"
MAX_BACKUPS=3
DB_COUNTER=1

if [ -n "$MAX_BACKUPS" ]
then
  MAX_FILES=$(( MAX_BACKUPS * DB_COUNTER ))
  while [ "$(find ${DIR_PATH} -maxdepth 1 -name "*.sql.gz" -type f | wc -l)" -gt "$MAX_FILES" ]
  do
    TARGET=$(find ${DIR_PATH} -maxdepth 1 -name "*.sql.gz" -type f | sort | head -n 1)
    echo "==> Max number of backups ($MAX_BACKUPS) reached. Deleting ${TARGET} ..."
    rm -rf "${TARGET}"
    echo "==> Backup ${TARGET} deleted"
  done
fi