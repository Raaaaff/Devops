#!/bin/bash
CONTAINER_NAME="tp-mongo"

export $(grep -v '^#' .env | xargs)

# 1. Vérification utilisateur non-root
echo "Vérif utilisateur"
USER_RESULT=$(docker exec "$CONTAINER_NAME" whoami)
if [ "$USER_RESULT" = "root" ]; then
  echo "Err : l'utilisateur est root"
  exit 1
fi
echo "Utilisateur OK : $USER_RESULT"

echo "Vérif bdd blog_db"
DB_RESULT=$(docker exec "$CONTAINER_NAME" mongosh \
  "mongodb://${MONGO_INITDB_ROOT_USERNAME}:${MONGO_INITDB_ROOT_PASSWORD}@localhost:27017/blog_db?authSource=admin" \
  --quiet --eval "db.posts.countDocuments()")

if [ "$DB_RESULT" -ge 5 ]; then
  echo "BDD : $DB_RESULT documents trouvés"
else
  echo "BDD inaccessible ou moins de 5 documents ($DB_RESULT)"
  exit 1
fi

echo "Vérifications terminées huston"