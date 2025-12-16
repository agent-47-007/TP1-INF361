# TP INF 3611 - Partie 1 : Script Bash d'automatisation

## 📋 Description

Script Bash pour automatiser la création et la configuration d'utilisateurs sur un serveur Linux (VPS), dans le cadre du cours **INF 3611 : Administration Systèmes et Réseaux** de l'Université de Yaoundé I.

## 📁 Structure du projet

```
partie1/
├── README.md                 # Ce fichier
├── create_users.sh          # Script principal
└── users.txt                # Fichier source des utilisateurs
```

## 🎯 Fonctionnalités implémentées

Le script `create_users.sh` implémente toutes les exigences du TP :

### ✅ 1. Création du groupe
- Création d'un groupe personnalisé (passé en paramètre)
- Exemple: `students-inf-361`

### ✅ 2. Création automatique des utilisateurs
Le script crée chaque utilisateur avec :
- ✓ Nom d'utilisateur
- ✓ Nom complet, numéro WhatsApp et adresse email
- ✓ Shell préféré (avec vérification et installation automatique)
- ✓ Répertoire personnel (`/home/username`)

### ✅ 3. Ajout au groupe principal
Tous les utilisateurs sont ajoutés au groupe spécifié (ex: `students-inf-361`)

### ✅ 4. Configuration du mot de passe
- Mot de passe haché en **SHA-512**
- Utilisation de `chpasswd -c SHA512`

### ✅ 5. Changement forcé du mot de passe
- Forcer le changement à la première connexion via `chage -d 0`

### ✅ 6. Privilèges sudo et restriction de `su`
- ✓ Ajout de chaque utilisateur au groupe `sudo`
- ✓ Configuration PAM pour **interdire l'usage de `su`** aux membres du groupe
- ✓ Seul le groupe `wheel` peut utiliser `su`

### ✅ 7. Message de bienvenue personnalisé
- Création d'un fichier `~/WELCOME.txt` personnalisé
- Affichage automatique à chaque connexion via `~/.bashrc`
- Contient: nom, email, téléphone, quotas, consignes

### ✅ 8. Quota disque
- Limitation à **15 Go** par utilisateur
- Soft limit: 14 Go, Hard limit: 15 Go
- Configuration via `setquota`

### ✅ 9. Limitation mémoire
- Limitation à **20% de la RAM totale** par processus
- Configuration via `/etc/security/limits.d/<username>.conf`
- Utilisation de `rss` (RAM physique) et `as` (mémoire virtuelle)

### ✅ 10. Traçabilité complète
- Fichier de log horodaté: `/var/log/create_users_YYYYMMDD_HHMMSS.log`
- Enregistrement de chaque opération avec date/heure
- Statistiques finales (succès, erreurs, utilisateurs ignorés)

## 🚀 Installation et prérequis

### 1. Prérequis système

```bash
# Installer les outils nécessaires
sudo apt-get update
sudo apt-get install -y quota quotatool
```

### 2. Activer les quotas sur le système de fichiers

Éditer `/etc/fstab` et ajouter `usrquota,grpquota` à la partition racine :

```bash
# Exemple de ligne dans /etc/fstab
UUID=xxxx-xxxx / ext4 defaults,usrquota,grpquota 0 1
```

Puis remonter et initialiser les quotas :

```bash
sudo mount -o remount /
sudo quotacheck -cugm /
sudo quotaon -v /
```

### 3. Préparer le fichier users.txt

Format attendu (séparé par des points-virgules) :

```
username;password;full_name;phone;email;shell
```

## 📝 Utilisation

### Syntaxe

```bash
sudo ./create_users.sh <nom_du_groupe> <fichier_users>
```

'''Exemple: 
sudo ./create_users.sh students-inf-361 users.txt
'''

**Note** : Ce script est conçu pour Ubuntu/Debian. Des adaptations mineures peuvent être nécessaires pour d'autres distributions Linux.