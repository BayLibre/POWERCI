#!/bin/bash
pg_dump \
     --no-owner \
     --format=custom \
     --host=$dbserver \
     --port=$dbport \
     --username=$dbuser \
     --no-password $dbname \
     --schema=public \
