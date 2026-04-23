FROM mongodb/mongodb-community-server:8.0-ubi8-slim
ENV MONGO_INITDB_DATABASE=blog_db
COPY --chown=mongodb:mongodb init.js /docker-entrypoint-initdb.d/
EXPOSE 27017