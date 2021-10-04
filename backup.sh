#!/bin/bash

if [ -z ${MYSQL_ROOT_PASSWORD_FILE+x} ]; then echo "MYSQL_ROOT_PASSWORD_FILE is recommended"; else MYSQL_PASSWORD=$(cat ${MYSQL_ROOT_PASSWORD_FILE}); fi

[ -z "${MYSQL_USER}" ] && { echo "=> MYSQL_USER cannot be empty" && exit 1; }
[ -z "${MYSQL_PASS:=$MYSQL_PASSWORD}" ] && { echo "=> MYSQL_PASS cannot be empty" && exit 1; }
[ -z "${GZIP_LEVEL}" ] && { GZIP_LEVEL=6; }

DATE=$(date +%Y%m%d%H%M)
echo "=> Backup started at $(date "+%Y-%m-%d %H:%M:%S")"
DATABASES=${MYSQL_DATABASE:-${MYSQL_DB:-$(mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" | tr -d "| " | grep -v Database)}}
DB_COUNTER=0
for db in ${DATABASES}
do
  if [[ "$db" != "information_schema" ]] && [[ "$db" != "performance_schema" ]] && [[ "$db" != "mysql" ]] && [[ "$db" != "sys" ]] && [[ "$db" != _* ]]
  then
    echo "==> Dumping database: $db"
    FILENAME=/backup/$DATE.$db.sql
    LATEST=/backup/latest.$db.sql.gz
    if mysqldump --single-transaction -h "$MYSQL_HOST" -P "$MYSQL_PORT" -u "$MYSQL_USER" -p"$MYSQL_PASS" "$db" $MYSQLDUMP_OPTS > "$FILENAME"
    then
      gzip "-$GZIP_LEVEL" -f "$FILENAME"
      echo "==> Creating symlink to latest backup: $(basename "$FILENAME".gz)"
      rm "$LATEST" 2> /dev/null
      cd /backup || exit && ln -s "$(basename "$FILENAME".gz)" "$(basename "$LATEST")"
      DB_COUNTER=$(( DB_COUNTER + 1 ))
      scp -o StrictHostKeyChecking=no -i ${SCP_ID_RSA} ${FILENAME}.gz ${SCP_HOST}/${FILENAME}.gz
    else
      rm -rf "$FILENAME"
    fi
  fi
done

if [ -n "$MAX_BACKUPS" ]
then
  MAX_FILES=$(( MAX_BACKUPS * DB_COUNTER ))
  while [ "$(find /backup -maxdepth 1 -name "*.sql.gz" -type f | wc -l)" -gt "$MAX_FILES" ]
  do
    TARGET=$(find /backup -maxdepth 1 -name "*.sql.gz" -type f | sort | head -n 1)
    echo "==> Max number of backups ($MAX_BACKUPS) reached. Deleting ${TARGET} ..."
    rm -rf "${TARGET}"
    echo "==> Backup ${TARGET} deleted"
  done
fi

echo "=> Backup process finished at $(date "+%Y-%m-%d %H:%M:%S")"
