# TP INF 3611 - Partie 2 : Playbook Ansible

## 📋 Description

Playbook Ansible pour automatiser la création et la configuration d'utilisateurs sur un serveur Linux (VPS), avec envoi automatique d'emails de notification. Cette solution industrialise les opérations de la Partie 1 et les rend réutilisables sur plusieurs serveurs.

**TP INF 3611 : Administration Systèmes et Réseaux**  
Université de Yaoundé I - Faculté des Sciences

## 📁 Structure du projet

```
partie2/
├── README.md                    # Ce fichier
├── ansible.cfg                  # Configuration Ansible
├── inventory.ini                # Inventaire des serveurs
├── create_users.yml            # Playbook principal
├── users.yml                   # Données des utilisateurs (YAML)
```

## 🎯 Fonctionnalités implémentées

### ✅ Toutes les fonctionnalités de la Partie 1

Le playbook reproduit **exactement** toutes les opérations du script Bash :

1. ✓ Création du groupe personnalisé
2. ✓ Création automatique des utilisateurs avec toutes leurs informations
3. ✓ Vérification et installation automatique des shells
4. ✓ Configuration des mots de passe (SHA-512)
5. ✓ Changement forcé du mot de passe à la première connexion
6. ✓ Ajout au groupe sudo
7. ✓ Restriction de la commande `su` (via PAM)
8. ✓ Message de bienvenue personnalisé avec affichage automatique
9. ✓ Quotas disque (15 Go par utilisateur)
10. ✓ Limitation mémoire (20% de la RAM par processus)
11. ✓ Traçabilité complète avec fichier de log

### ✨ Fonctionnalités supplémentaires Ansible

12. ✅ **Envoi automatique d'emails personnalisés** à chaque utilisateur
13. ✅ Gestion multi-serveurs (inventaire)
14. ✅ Templates Jinja2 pour la personnalisation
15. ✅ Ansible Vault pour sécuriser les credentials
16. ✅ Idempotence (exécution multiple sans effets secondaires)
17. ✅ Gestion d'erreurs robuste avec `ignore_errors`

## 📧 Contenu des emails envoyés

Chaque utilisateur reçoit un email HTML professionnel contenant :

- ✉️ Formule de politesse personnalisée
- 🌐 Adresse IP du serveur
- 🔌 Port SSH du serveur
- 👤 Nom d'utilisateur
- 🔐 Mot de passe initial
- 💻 Commande SSH de connexion
- 🔑 Commandes pour transmettre la clé publique SSH (Linux, macOS, Windows)
- 💾 Informations sur les ressources allouées
- ⚠️ Consignes de sécurité et première connexion

## 🚀 Installation et prérequis

### 1. Installer Ansible

#### Sur Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y ansible python3-pip
```

### 2. Vérifier l'installation

```bash
ansible --version
# Devrait afficher: ansible [core 2.x.x]
```

### 3. Installer les dépendances Python

```bash
pip3 install secure-smtplib
```

### 4. Préparer le serveur cible

Sur votre VPS, assurez-vous d'avoir :

```bash
# Connexion SSH configurée
ssh root@37.60.250.220

# Python3 installé
sudo apt install -y python3

# Activer les quotas (voir README Partie 1)
sudo quotacheck -cugm /
sudo quotaon -v /
```

## 📝 Configuration

### Étape 1 : Configurer l'inventaire

Éditez `inventory.ini` et remplacez par vos informations :

```ini
[vps_servers]
vps1 ansible_host=37.60.250.220 ansible_user=root ansible_port=22
```

**Testez la connexion** :
```bash
ansible -i inventory.ini vps_servers -m ping
```

### Étape 2 : Configurer les utilisateurs

Éditez `users.yml` et ajoutez vos utilisateurs :

```yaml
users:
  - username: fitzgerald_ngue
    password: 01/08/2003
    full_name: fitzgerald Ngue
    phone: "+237693338107"
    email: fitzgerald.ngue@facsciences-uy1.cm
    shell: /bin/bash
```

### Étape 3 : Configurer les emails (SMTP)

#### Option A : Utiliser Gmail

1. **Créer un mot de passe d'application Gmail** :
   - Aller sur https://myaccount.google.com/apppasswords
   - Activer la validation en deux étapes si nécessaire
   - Générer un mot de passe d'application
   - Copier le mot de passe (16 caractères)

2. **Configurer le vault** :

```bash
# Éditer vault.yml
nano vault.yml
```

Ajouter vos credentials :
```yaml
vault_smtp_user: "votre-email@gmail.com"
vault_smtp_password: "votre-mot-de-passe-app-16-caracteres"
```

3. **Crypter le vault** :

```bash
ansible-vault encrypt vault.yml
# Entrer un mot de passe maître
```

#### Option B : Utiliser un autre service SMTP

Modifiez les variables dans `create_users.yml` :

```yaml
smtp_host: "smtp.mailgun.org"  # ou autre
smtp_port: 587
```

### Étape 4 : Tester la configuration

```bash
# Test de connexion
ansible -i inventory.ini vps_servers -m ping

# Test de collecte d'informations
ansible -i inventory.ini vps_servers -m setup

# Vérifier la syntaxe du playbook
ansible-playbook create_users.yml --syntax-check

# Mode dry-run (simulation)
ansible-playbook -i inventory.ini create_users.yml --check
```

## 🎮 Exécution du playbook

### Commande de base

```bash
ansible-playbook -i inventory.ini create_users.yml --ask-vault-pass
```

### Options utiles

```bash
# Avec fichier de mot de passe vault
echo "votre_mot_de_passe_vault" > .vault_pass
chmod 600 .vault_pass
ansible-playbook -i inventory.ini create_users.yml --vault-password-file=.vault_pass

# Mode verbeux (débogage)
ansible-playbook -i inventory.ini create_users.yml -vvv

# Exécuter sur un serveur spécifique
ansible-playbook -i inventory.ini create_users.yml --limit vps1

# Exécuter à partir d'une tâche spécifique
ansible-playbook -i inventory.ini create_users.yml --start-at-task="[5/12] Créer et configurer les utilisateurs"

# Mode dry-run (simulation sans modifications)
ansible-playbook -i inventory.ini create_users.yml --check

# Avec tags (si vous en ajoutez)
ansible-playbook -i inventory.ini create_users.yml --tags "users,emails"
```

## 📊 Résultats et vérifications

### Fichiers générés sur le serveur

1. **Fichier de log principal** :
   ```bash
   /var/log/ansible_create_users_[timestamp].log
   ```

2. **Messages de bienvenue** :
   ```bash
   /home/<username>/WELCOME.txt
   ```

3. **Fichiers de limites** :
   ```bash
   /etc/security/limits.d/<username>.conf
   ```

4. **Résumé d'exécution** :
   ```bash
   /root/users_creation_summary_[timestamp].txt
   ```

### Vérifications post-exécution

```bash
# Vérifier les utilisateurs créés
ansible -i inventory.ini vps_servers -m command -a "getent group students-inf-361"

# Vérifier les quotas
ansible -i inventory.ini vps_servers -m command -a "repquota -a"

# Consulter le log
ansible -i inventory.ini vps_servers -m command -a "tail -50 /var/log/ansible_create_users_*.log"

# Vérifier la restriction su
ansible -i inventory.ini vps_servers -m command -a "grep pam_wheel /etc/pam.d/su"
```

## 🔄 Idempotence

Le playbook est **idempotent** : vous pouvez l'exécuter plusieurs fois sans problème.

- Les utilisateurs existants sont ignorés
- Les configurations ne sont appliquées que si nécessaires
- Les emails ne sont envoyés qu'une seule fois (lors de la création)

```bash
# Première exécution : crée tout
ansible-playbook -i inventory.ini create_users.yml --ask-vault-pass

# Deuxième exécution : aucun changement
ansible-playbook -i inventory.ini create_users.yml --ask-vault-pass
# Résultat: "changed=0" pour les utilisateurs existants
```

## 🎨 Personnalisation des templates

### Modifier le message de bienvenue

Éditez `templates/welcome.j2` :

```jinja2
Bonjour {{ item.full_name }} ! 👋

Votre message personnalisé ici...
Serveur: {{ server_ip }}
```

### Modifier les limites système

Éditez `templates/limits.j2` :

```jinja2
# Augmenter le nombre de processus
{{ item.username }}        soft    nproc           200
{{ item.username }}        hard    nproc           300
```

## 🐛 Dépannage

### Problème : Connexion SSH échoue

**Erreur** : `Failed to connect to the host via ssh`

**Solutions** :
```bash
# Vérifier la connexion manuelle
ssh root@votre-serveur-ip

# Vérifier l'inventaire
ansible-inventory -i inventory.ini --list

# Tester avec ping
ansible -i inventory.ini all -m ping
```

### Problème : Erreur d'envoi d'emails

**Erreur** : `Failed to send email`

**Solutions** :
```bash
# Vérifier les credentials SMTP
ansible-vault view vault.yml

# Tester avec un seul utilisateur
# (modifier users.yml pour n'avoir qu'un utilisateur)

# Ignorer les erreurs d'email (ajouté dans le playbook)
# ignore_errors: yes est déjà configuré
```

### Problème : Quotas non configurés

**Erreur** : `setquota: Quota not found`

**Solution** :
```bash
# Sur le serveur cible
ssh root@37.60.250.220
quotacheck -cugm /
quotaon -v /
```

### Problème : Vault password incorrect

**Erreur** : `Decryption failed`

**Solutions** :
```bash
# Recréer le vault
ansible-vault decrypt vault.yml
# Modifier le contenu
ansible-vault encrypt vault.yml

# Ou éditer directement
ansible-vault edit vault.yml
```

## 📚 Commandes utiles Ansible

```bash
# Lister les hôtes
ansible -i inventory.ini --list-hosts all

# Collecter les facts d'un serveur
ansible -i inventory.ini vps_servers -m setup

# Exécuter une commande ad-hoc
ansible -i inventory.ini vps_servers -m command -a "uptime"

# Copier un fichier
ansible -i inventory.ini vps_servers -m copy -a "src=file.txt dest=/tmp/"

# Vérifier la syntaxe
ansible-playbook create_users.yml --syntax-check

# Lister les tâches
ansible-playbook create_users.yml --list-tasks

# Voir les variables
ansible -i inventory.ini vps_servers -m debug -a "var=hostvars"
```