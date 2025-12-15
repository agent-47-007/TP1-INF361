#!/bin/bash
# ==========================================
# Script : create_users.sh
# TP INF 3611 – Partie 1
# Auteur : NGUE MBONG André Fitzgerald
# Version : 2.0 (Optimisée et Corrigée)
# ==========================================

# ---------- Vérifications ----------
if [ "$EUID" -ne 0 ]; then
  echo "❌ Ce script doit être exécuté en tant que root"
  exit 1
fi

if [ $# -ne 2 ]; then
  echo "Usage: $0 <nom_du_groupe> <fichier_users>"
  exit 1
fi

GROUP=$1
USERS_FILE=$2
LOGFILE="/var/log/create_users_$(date +%Y%m%d_%H%M%S).log"

if [ ! -f "$USERS_FILE" ]; then
  echo "❌ Fichier $USERS_FILE introuvable"
  exit 1
fi

# Fonction de logging
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

log "===== DÉBUT DU SCRIPT ====="
log "Groupe cible: $GROUP"
log "Fichier source: $USERS_FILE"

# ---------- Création du groupe principal ----------
if ! getent group "$GROUP" > /dev/null; then
  groupadd "$GROUP"
  log "✓ Groupe $GROUP créé"
else
  log "⚠ Groupe $GROUP existe déjà"
fi

# ---------- Configuration de la restriction su ----------
# Méthode PAM (plus robuste que dpkg-statoverride)
if ! grep -q "pam_succeed_if.so.*notingroup.*$GROUP" /etc/pam.d/su 2>/dev/null; then
  log "Configuration de la restriction su pour le groupe $GROUP..."
  
  # Sauvegarde
  cp /etc/pam.d/su /etc/pam.d/su.backup_$(date +%Y%m%d) 2>/dev/null
  
  # Ajouter la restriction PAM
  cat >> /etc/pam.d/su << EOF

# Restriction su pour $GROUP (ajouté le $(date))
auth required pam_succeed_if.so user notingroup $GROUP
EOF
  log "✓ Restriction su configurée via PAM"
else
  log "⚠ Restriction su déjà configurée"
fi

# ---------- Vérification et installation des outils ----------
# Installation de quota si nécessaire
if ! command -v setquota &> /dev/null; then
  log "Installation de quota..."
  apt-get update -qq && apt-get install -y quota >> "$LOGFILE" 2>&1
fi

# ---------- Calcul de la limite mémoire (20% RAM) ----------
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
RAM_LIMIT_KB=$((TOTAL_RAM_KB / 5))  # 20%
log "Limite mémoire calculée: $((RAM_LIMIT_KB/1024)) Mo (20% de $((TOTAL_RAM_KB/1024)) Mo RAM totale)"

# ---------- Lecture du fichier users ----------
line_num=0
success_count=0
error_count=0

while IFS=';' read -r username password fullname phone email shell || [ -n "$username" ]; do
  line_num=$((line_num + 1))
  
  # Ignorer lignes vides et commentaires
  [[ -z "$username" || "$username" =~ ^# ]] && continue
  
  log "----------------------------------------"
  log "Ligne $line_num: Traitement de $username"
  
  # Vérification existence utilisateur
  if id "$username" &>/dev/null; then
    log "⚠ Utilisateur $username existe déjà – ignoré"
    continue
  fi
  
  # Vérification et installation du shell
  if [ ! -x "$shell" ]; then
    log "  Shell $shell absent, tentative d'installation..."
    shell_name=$(basename "$shell")
    
    apt-get update -qq >> "$LOGFILE" 2>&1
    if apt-get install -y "$shell_name" >> "$LOGFILE" 2>&1 && [ -x "$shell" ]; then
      log "  ✓ Shell $shell installé"
    else
      log "  ✗ Installation échouée, fallback vers /bin/bash"
      shell="/bin/bash"
    fi
  fi
  
  # Création de l'utilisateur
  if useradd -m \
    -s "$shell" \
    -c "$fullname | Tel:$phone | Email:$email" \
    -G "$GROUP,sudo" \
    "$username" 2>> "$LOGFILE"; then
    
    log "  ✓ Utilisateur $username créé"
  else
    log "  ✗ Échec création de $username"
    error_count=$((error_count + 1))
    continue
  fi
  
  # Mot de passe SHA-512
  echo "$username:$password" | chpasswd -c SHA512 2>> "$LOGFILE"
  log "  ✓ Mot de passe configuré (SHA-512)"
  
  # Forcer changement du mot de passe
  chage -d 0 "$username" 2>> "$LOGFILE"
  log "  ✓ Changement de mot de passe forcé à la première connexion"
  
  # Message de bienvenue personnalisé
  WELCOME="/home/$username/WELCOME.txt"
  cat > "$WELCOME" << 'EOFWELCOME'
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║        Bienvenue sur le serveur INF 3611 👋              ║
║        Université de Yaoundé I                            ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝

EOFWELCOME
  
  cat >> "$WELCOME" << EOF
Bonjour $fullname !

Informations de votre compte :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  👤 Utilisateur : $username
  📧 Email       : $email
  📞 WhatsApp    : $phone
  🖥️  Shell       : $shell
  📅 Connexion   : \$(date '+%A %d %B %Y à %H:%M:%S')

Ressources allouées :
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  💾 Quota disque : 15 Go
  🧠 Limite RAM   : 20% par processus
  📂 Répertoire   : /home/$username

⚠️  IMPORTANT :
  • Vous devez changer votre mot de passe à cette première connexion
  • Respectez les quotas de ressources
  • Lisez la charte d'utilisation du serveur

Pour toute assistance : support@inf361.uy1.cm

═══════════════════════════════════════════════════════════
EOF
  
  # Ajouter l'affichage dans .bashrc (sans duplication)
  if ! grep -q "WELCOME.txt" "/home/$username/.bashrc" 2>/dev/null; then
    cat >> "/home/$username/.bashrc" << 'EOFBASH'

# Message de bienvenue
if [ -f ~/WELCOME.txt ]; then
    cat ~/WELCOME.txt
fi
EOFBASH
  fi
  
  # Corriger les permissions
  chown -R "$username:$username" "/home/$username"
  chmod 644 "$WELCOME"
  log "  ✓ Message de bienvenue créé"
  
  # Quota disque 15 Go (15360 Mo = 15728640 Ko)
  # Soft limit: 14 Go, Hard limit: 15 Go
  if setquota -u "$username" 14680064 15728640 0 0 -a 2>> "$LOGFILE"; then
    log "  ✓ Quota disque configuré: 15 Go"
  else
    log "  ⚠ Quota non configuré (vérifiez que les quotas sont activés sur le système)"
  fi
  
  # Limite mémoire 20% (via limits.d - meilleure pratique)
  LIMITS_FILE="/etc/security/limits.d/${username}.conf"
  cat > "$LIMITS_FILE" << EOF
# Limites pour $username (créé le $(date '+%Y-%m-%d'))
# Limite mémoire virtuelle à 20% de la RAM totale
$username        hard    as              $RAM_LIMIT_KB
$username        soft    as              $RAM_LIMIT_KB

# Limites additionnelles de sécurité
$username        hard    nproc           100
$username        soft    nproc           80
$username        hard    nofile          1024
$username        soft    nofile          512
EOF
  log "  ✓ Limite mémoire configurée: $((RAM_LIMIT_KB/1024)) Mo"
  
  success_count=$((success_count + 1))
  log "  ✅ Utilisateur $username créé avec succès"
  
done < "$USERS_FILE"

# ---------- Résumé final ----------
log "=========================================="
log "===== FIN DU SCRIPT ====="
log "Statistiques:"
log "  ✓ Utilisateurs créés avec succès : $success_count"
log "  ✗ Erreurs                        : $error_count"
log "  📁 Fichier de log                : $LOGFILE"
log "=========================================="

echo ""
echo "✅ Script terminé !"
echo "   Utilisateurs créés : $success_count"
echo "   Erreurs            : $error_count"
echo "   Log complet        : $LOGFILE"
echo ""