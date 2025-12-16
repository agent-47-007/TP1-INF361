#!/bin/bash

###############################################################################
# Script helper pour exécuter le playbook Ansible
# TP INF 3611 - Partie 2
###############################################################################

set -e

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║                                                                    ║"
echo "║   🎓 TP INF 3611 - Partie 2 : Playbook Ansible                    ║"
echo "║   Université de Yaoundé I - Faculté des Sciences                  ║"
echo "║                                                                    ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo ""

# Vérifier qu'Ansible est installé
if ! command -v ansible-playbook &> /dev/null; then
    echo "❌ Ansible n'est pas installé !"
    echo ""
    echo "Pour installer Ansible :"
    echo "  Ubuntu/Debian: sudo apt install ansible"
    echo "  macOS: brew install ansible"
    echo ""
    exit 1
fi

echo "✅ Ansible $(ansible --version | head -1 | awk '{print $2}') détecté"
echo ""

# Menu interactif
echo "Que souhaitez-vous faire ?"
echo ""
echo "  1) Tester la connexion aux serveurs (ping)"
echo "  2) Vérifier la configuration (dry-run)"
echo "  3) Exécuter le playbook complet"
echo "  4) Exécuter sans envoi d'emails"
echo "  5) Voir les logs du dernier déploiement"
echo "  6) Configurer le vault SMTP"
echo "  7) Afficher l'aide"
echo "  0) Quitter"
echo ""
read -p "Votre choix [1-7]: " choice

case $choice in
    1)
        echo ""
        echo "🔍 Test de connexion aux serveurs..."
        ansible -i inventory.ini vps_servers -m ping
        ;;
    
    2)
        echo ""
        echo "🧪 Vérification de la configuration (mode dry-run)..."
        echo ""
        echo "Cette commande simule l'exécution sans modifier le serveur."
        echo ""
        if [ -f ".vault_pass" ]; then
            ansible-playbook -i inventory.ini create_users.yml --check --vault-password-file=.vault_pass
        else
            ansible-playbook -i inventory.ini create_users.yml --check --ask-vault-pass
        fi
        ;;
    
    3)
        echo ""
        echo "🚀 Exécution du playbook complet..."
        echo ""
        echo "⚠️  ATTENTION : Cette opération va :"
        echo "   - Créer les utilisateurs sur le serveur"
        echo "   - Configurer les quotas et limites"
        echo "   - Envoyer des emails à tous les utilisateurs"
        echo ""
        read -p "Confirmer l'exécution ? (oui/non): " confirm
        
        if [ "$confirm" = "oui" ] || [ "$confirm" = "o" ] || [ "$confirm" = "y" ] || [ "$confirm" = "yes" ]; then
            echo ""
            if [ -f ".vault_pass" ]; then
                ansible-playbook -i inventory.ini create_users.yml --vault-password-file=.vault_pass
            else
                ansible-playbook -i inventory.ini create_users.yml --ask-vault-pass
            fi
        else
            echo "❌ Exécution annulée"
            exit 0
        fi
        ;;
    
    4)
        echo ""
        echo "📧 Exécution sans envoi d'emails..."
        echo ""
        echo "Pour désactiver l'envoi d'emails, modifiez vault.yml:"
        echo "  vault_smtp_user: \"votre-email@gmail.com\""
        echo ""
        echo "Le playbook ignorera l'envoi si smtp_user = votre-email@gmail.com"
        echo ""
        if [ -f ".vault_pass" ]; then
            ansible-playbook -i inventory.ini create_users.yml --vault-password-file=.vault_pass
        else
            ansible-playbook -i inventory.ini create_users.yml --ask-vault-pass
        fi
        ;;
    
    5)
        echo ""
        echo "📋 Logs du dernier déploiement..."
        echo ""
        if [ -f "ansible.log" ]; then
            tail -100 ansible.log
        else
            echo "❌ Aucun fichier de log trouvé (ansible.log)"
            echo ""
            echo "Les logs sur le serveur se trouvent dans:"
            echo "  /var/log/ansible_create_users_*.log"
        fi
        ;;
    
    6)
        echo ""
        echo "🔐 Configuration du vault SMTP..."
        echo ""
        
        if [ -f "vault.yml" ]; then
            echo "Le fichier vault.yml existe."
            echo ""
            read -p "Voulez-vous l'éditer ? (oui/non): " edit_vault
            
            if [ "$edit_vault" = "oui" ] || [ "$edit_vault" = "o" ]; then
                # Vérifier si le vault est crypté
                if head -1 vault.yml | grep -q "ANSIBLE_VAULT"; then
                    echo ""
                    echo "Le vault est crypté. Édition sécurisée..."
                    ansible-vault edit vault.yml
                else
                    echo ""
                    echo "Le vault n'est pas crypté. Édition normale..."
                    nano vault.yml
                    echo ""
                    read -p "Voulez-vous crypter le vault maintenant ? (oui/non): " encrypt
                    if [ "$encrypt" = "oui" ] || [ "$encrypt" = "o" ]; then
                        ansible-vault encrypt vault.yml
                        echo "✅ Vault crypté avec succès"
                    fi
                fi
            fi
        else
            echo "❌ Le fichier vault.yml n'existe pas."
            echo ""
            read -p "Voulez-vous le créer ? (oui/non): " create_vault
            
            if [ "$create_vault" = "oui" ] || [ "$create_vault" = "o" ]; then
                cat > vault.yml << 'EOF'
---
# Configuration SMTP pour l'envoi d'emails
vault_smtp_user: "votre-email@gmail.com"
vault_smtp_password: "votre-mot-de-passe-application-gmail"

# Instructions:
# 1. Remplacer par vos vraies informations
# 2. Crypter ce fichier: ansible-vault encrypt vault.yml
EOF
                echo "✅ Fichier vault.yml créé"
                echo ""
                nano vault.yml
                echo ""
                read -p "Voulez-vous crypter le vault maintenant ? (oui/non): " encrypt
                if [ "$encrypt" = "oui" ] || [ "$encrypt" = "o" ]; then
                    ansible-vault encrypt vault.yml
                    echo "✅ Vault crypté avec succès"
                fi
            fi
        fi
        ;;
    
    7)
        echo ""
        echo "📚 AIDE - Commandes Ansible utiles"
        echo ""
        echo "Configuration initiale:"
        echo "  1. Éditer inventory.ini avec l'IP de votre serveur"
        echo "  2. Éditer users.yml avec vos utilisateurs"
        echo "  3. Configurer vault.yml avec vos identifiants SMTP"
        echo "  4. Crypter le vault: ansible-vault encrypt vault.yml"
        echo ""
        echo "Commandes de test:"
        echo "  ansible -i inventory.ini vps_servers -m ping"
        echo "  ansible-playbook create_users.yml --syntax-check"
        echo "  ansible-playbook -i inventory.ini create_users.yml --check"
        echo ""
        echo "Exécution:"
        echo "  ansible-playbook -i inventory.ini create_users.yml --ask-vault-pass"
        echo ""
        echo "Avec fichier de mot de passe:"
        echo "  echo 'votre_password' > .vault_pass"
        echo "  chmod 600 .vault_pass"
        echo "  ansible-playbook -i inventory.ini create_users.yml --vault-password-file=.vault_pass"
        echo ""
        echo "Gestion du vault:"
        echo "  ansible-vault edit vault.yml        # Éditer"
        echo "  ansible-vault view vault.yml        # Voir"
        echo "  ansible-vault encrypt vault.yml     # Crypter"
        echo "  ansible-vault decrypt vault.yml     # Décrypter"
        echo ""
        echo "Debug:"
        echo "  ansible-playbook -i inventory.ini create_users.yml -vvv"
        echo ""
        ;;
    
    0)
        echo ""
        echo "👋 Au revoir !"
        exit 0
        ;;
    
    *)
        echo ""
        echo "❌ Choix invalide"
        exit 1
        ;;
esac

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "✅ Terminé !"
echo "════════════════════════════════════════════════════════════════════"
echo ""