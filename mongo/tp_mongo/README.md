# TP MongoDB Docker

Image MongoDB avec base `blog_db` pré-configurée.

## Prérequis
- Docker installé
- Fichier `.env` basé sur `.env.example`

## Installation

```bash
docker pull raaffff/tp-mongo:1.0
```

## Configuration

Crée un fichier `.env` et y insérer vos identifiants :
```bash
cp .env.example .env
```

## Lancement

```bash
docker run -d --name tp-mongo --env-file .env -p 27017:27017 raaffff/tp-mongo:1.0
```

## Script de vérification

```bash
chmod +x check-status.sh
./check-status.sh
```

Le script vérifie :
- L'utilisateur exécutant le service est non-root
- La base `blog_db` est accessible avec au moins 5 documents