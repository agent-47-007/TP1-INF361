#!/bin/bash

###########################################
# Script de création automatique d'utilisateurs
# INF 3611 - Administration Systèmes et Réseaux
# Université de Yaoundé I
###########################################

# Vérification des privilèges root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root (sudo)" 
   exit 1
fi

# Vérification des paramètres
if [ $# -ne 2 ]; then
    echo "Usage: $0 <fichier_utilisateurs> <nom_groupe>"
    echo "Exemple: $0 users.txt students-inf-361"
    exit 1
fi

USER_FILE="$1"
GROUP_NAME="$2"
LOG_FILE="user_creation_$(date +%Y%m%d_%H%M%S).log"

# Fonction de logging
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Vérification de l'existence du fichier
if [ ! -f "$USER_FILE" ]; then
    log_message "ERREUR: Le fichier $USER_FILE n'existe pas"
    exit 1
fi

log_message "=========================================="
log_message "Début de l'exécution du script"
log_message "Fichier source: $USER_FILE"
log_message "Groupe principal: $GROUP_NAME"
log_message "=========================================="

# 1. Créer le groupe students-inf-361
if getent group "$GROUP_NAME" > /dev/null 2>&1; then
    log_message "Le groupe $GROUP_NAME existe déjà"
else
    groupadd "$GROUP_NAME"
    if [ $? -eq 0 ]; then
        log_message "✓ Groupe $GROUP_NAME créé avec succès"
    else
        log_message "✗ Échec de création du groupe $GROUP_NAME"
        exit 1
    fi
fi

# Fonction pour vérifier et installer un shell
check_and_install_shell() {
    local shell_path="$1"
    local username="$2"
    
    # Vérifier si le shell existe
    if [ -x "$shell_path" ]; then
        log_message "  Shell $shell_path disponible pour $username"
        echo "$shell_path"
        return 0
    fi
    
    # Extraire le nom du shell
    local shell_name=$(basename "$shell_path")
    log_message "  Shell $shell_path non trouvé, tentative d'installation..."
    
    # Tentative d'installation
    if command -v apt-get &> /dev/null; then
        apt-get update -qq && apt-get install -y "$shell_name" &>> "$LOG_FILE"
    elif command -v yum &> /dev/null; then
        yum install -y "$shell_name" &>> "$LOG_FILE"
    elif command -v dnf &> /dev/null; then
        dnf install -y "$shell_name" &>> "$LOG_FILE"
    fi
    
    # Vérifier si l'installation a réussi
    if [ -x "$shell_path" ]; then
        log_message "  ✓ Shell $shell_path installé avec succès"
        echo "$shell_path"
        return 0
    else
        log_message "  ✗ Installation de $shell_path échouée, utilisation de /bin/bash"
        echo "/bin/bash"
        return 1
    fi
}

# Configurer les quotas disque (si non configurés)
setup_quota() {
    log_message "Configuration des quotas disque..."
    
    # Vérifier si quotatools est installé
    if ! command -v setquota &> /dev/null; then
        log_message "  Installation de quota..."
        if command -v apt-get &> /dev/null; then
            apt-get install -y quota &>> "$LOG_FILE"
        elif command -v yum &> /dev/null; then
            yum install -y quota &>> "$LOG_FILE"
        fi
    fi
    
    # Activer les quotas sur la partition /home (si nécessaire)
    if ! grep -q "usrquota" /etc/fstab; then
        log_message "  Note: Les quotas doivent être activés manuellement dans /etc/fstab"
        log_message "  Ajoutez 'usrquota,grpquota' aux options de montage de /home"
    fi
}

# Configuration initiale
setup_quota

# Configurer les restrictions su pour le groupe
configure_su_restriction() {
    local group="$1"
    
    # Modifier /etc/pam.d/su pour restreindre l'accès
    if ! grep -q "pam_wheel.so.*group=$group" /etc/pam.d/su; then
        log_message "Configuration de la restriction su pour le groupe $group..."
        
        # Créer une sauvegarde
        cp /etc/pam.d/su /etc/pam.d/su.backup_$(date +%Y%m%d)
        
        # Ajouter la restriction
        echo "# Restriction su pour $group" >> /etc/pam.d/su
        echo "auth required pam_succeed_if.so user notingroup $group" >> /etc/pam.d/su
        
        log_message "✓ Restriction su configurée pour $group"
    fi
}

configure_su_restriction "$GROUP_NAME"

# Lecture et traitement du fichier utilisateurs
line_number=0
while IFS=';' read -r username password fullname phone email shell || [ -n "$username" ]; do
    line_number=$((line_number + 1))
    
    # Ignorer les lignes vides et les commentaires
    [[ -z "$username" || "$username" =~ ^# ]] && continue
    
    log_message "----------------------------------------"
    log_message "Traitement de l'utilisateur: $username (ligne $line_number)"
    
    # Vérifier si l'utilisateur existe déjà
    if id "$username" &>/dev/null; then
        log_message "  ⚠ L'utilisateur $username existe déjà, passage au suivant"
        continue
    fi
    
    # 2c. Vérifier et installer le shell si nécessaire
    final_shell=$(check_and_install_shell "$shell" "$username")
    
    # 2. Créer l'utilisateur avec toutes ses informations
    useradd -m \
            -s "$final_shell" \
            -c "$fullname,$phone,$email" \
            -G "$GROUP_NAME",sudo \
            "$username"
    
    if [ $? -ne 0 ]; then
        log_message "  ✗ Échec de création de l'utilisateur $username"
        continue
    fi
    
    log_message "  ✓ Utilisateur $username créé avec succès"
    log_message "    - Nom complet: $fullname"
    log_message "    - Téléphone: $phone"
    log_message "    - Email: $email"
    log_message "    - Shell: $final_shell"
    log_message "    - Groupes: $GROUP_NAME, sudo"
    
    # 4. Configurer le mot de passe (haché en SHA-512)
    echo "$username:$password" | chpasswd -c SHA512
    log_message "  ✓ Mot de passe configuré (SHA-512)"
    
    # 5. Forcer le changement de mot de passe à la première connexion
    chage -d 0 "$username"
    log_message "  ✓ Changement de mot de passe forcé à la première connexion"
    
    # 7. Créer le message de bienvenue personnalisé
    user_home=$(eval echo ~$username)
    
    cat > "$user_home/WELCOME.txt" << EOF
╔════════════════════════════════════════════════════════════╗
║                                                            ║
║          Bienvenue sur le serveur INF 3611                 ║
║          Université de Yaoundé I                           ║
║                                                            ║
╚════════════════════════════════════════════════════════════╝

Bonjour $fullname !

Vous êtes connecté en tant que: $username
Date de connexion: \$(date '+%A %d %B %Y à %H:%M:%S')

Informations système:
- Nom d'hôte: \$(hostname)
- Système: \$(uname -s) \$(uname -r)
- Espace disque disponible: \$(df -h ~ | tail -1 | awk '{print \$4}')

⚠️  IMPORTANT:
- Vous devez changer votre mot de passe à la première connexion
- Votre quota disque est limité à 15 Go
- Votre utilisation mémoire par processus est limitée à 20% de la RAM

Pour toute assistance: support@inf361.cm

════════════════════════════════════════════════════════════
EOF
    
    # Ajouter l'affichage dans .bashrc
    if ! grep -q "WELCOME.txt" "$user_home/.bashrc"; then
        echo "" >> "$user_home/.bashrc"
        echo "# Message de bienvenue" >> "$user_home/.bashrc"
        echo "if [ -f ~/WELCOME.txt ]; then" >> "$user_home/.bashrc"
        echo "    cat ~/WELCOME.txt" >> "$user_home/.bashrc"
        echo "fi" >> "$user_home/.bashrc"
    fi
    
    chown "$username:$username" "$user_home/WELCOME.txt"
    chmod 644 "$user_home/WELCOME.txt"
    log_message "  ✓ Message de bienvenue créé"
    
    # 8. Configurer la limite d'espace disque (15 Go)
    if command -v setquota &> /dev/null; then
        # 15 Go = 15360 Mo (soft limit = hard limit)
        setquota -u "$username" 14680064 15728640 0 0 -a 2>/dev/null
        if [ $? -eq 0 ]; then
            log_message "  ✓ Quota disque configuré: 15 Go"
        else
            log_message "  ⚠ Quota non configuré (quotas peut-être non activés sur le système)"
        fi
    else
        log_message "  ⚠ Commande setquota non disponible"
    fi
    
    # 9. Limiter l'utilisation mémoire à 20% de la RAM
    total_ram_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    ram_limit_kb=$((total_ram_kb / 5))  # 20% de la RAM
    
    # Créer un fichier de limites pour cet utilisateur
    limits_file="/etc/security/limits.d/${username}.conf"
    cat > "$limits_file" << EOF
# Limites pour l'utilisateur $username
# Créé le $(date '+%Y-%m-%d %H:%M:%S')

# Limite mémoire virtuelle à 20% de la RAM totale
$username        hard    as              $ram_limit_kb
$username        soft    as              $ram_limit_kb

# Autres limites de sécurité
$username        hard    nproc           100
$username        soft    nproc           80
EOF
    
    log_message "  ✓ Limite mémoire configurée: 20% RAM (~$((ram_limit_kb/1024)) Mo)"
    
done < "$USER_FILE"

log_message "=========================================="
log_message "Fin de l'exécution du script"
log_message "Résumé:"
log_message "  - Groupe créé: $GROUP_NAME"
log_message "  - Fichier de log: $LOG_FILE"
log_message "=========================================="

echo ""
echo "✓ Script terminé avec succès!"
echo "  Consultez le fichier $LOG_FILE pour les détails"
echo ""