#!/bin/bash

# === Whiptail color scheme: white background, black text ===
export NEWT_COLORS='
root=white,black
border=black,white
window=white,black
shadow=black,black
title=black,white
textbox=black,white
button=black,white
entry=black,white
checkbox=black,white
'

# === Require root ===
if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run as root (sudo)."
    exit 1
fi

REAL_USER=$(logname)
USER_HOME="/home/$REAL_USER"
USER_DESKTOP="$USER_HOME/Desktop"

# === Ensure we’re starting from Desktop ===
if [ ! -d "$USER_DESKTOP" ]; then
    echo "[!] Could not find Desktop at $USER_DESKTOP"
    exit 1
fi

cd "$USER_DESKTOP" || {
    echo "[!] Failed to cd into Desktop"
    exit 1
}

# === Prompt for project folder name ===
FOLDER=$(whiptail --inputbox "Enter project folder name:" 10 60 3>&1 1>&2 2>&3)
TARGET_DIR="$USER_DESKTOP/$FOLDER"

mkdir -p "$TARGET_DIR"
chown -R "$REAL_USER:$REAL_USER" "$TARGET_DIR"
cd "$TARGET_DIR" || exit 1

# === Menu Loop ===
while true; do
    OPTION=$(whiptail --title "Recon Menu" --menu "Choose an option:" 15 60 6 \
    "1" "Copy wordlists to Desktop" \
    "2" "Run arp-scan and log results" \
    "3" "Run Nmap scans on discovered IPs" \
    "4" "Show shell upgrade commands" \
    "5" "Exit" 3>&1 1>&2 2>&3)

    case $OPTION in
        1)
            WORDLIST_SRC="/usr/share/wordlists"
            ROCKYOU_TXT="$WORDLIST_SRC/rockyou.txt"
            ROCKYOU_GZ="$WORDLIST_SRC/rockyou.txt.gz"
            DEST="$USER_DESKTOP/wordlists"

            if [ ! -f "$ROCKYOU_TXT" ] && [ -f "$ROCKYOU_GZ" ]; then
                gunzip "$ROCKYOU_GZ"
            fi

            cp -r "$WORDLIST_SRC" "$DEST"
            chown -R "$REAL_USER:$REAL_USER" "$DEST"
            whiptail --msgbox "Wordlists copied to $DEST" 10 60
            ;;
        2)
            arp-scan --localnet | tee -a network_scan.log
            chown "$REAL_USER:$REAL_USER" network_scan.log
            whiptail --msgbox "ARP scan complete.\nLog saved to: network_scan.log" 10 60
            ;;
        3)
            if [ ! -f network_scan.log ]; then
                whiptail --msgbox "No network_scan.log found. Run Option 2 first." 10 60
            else
                grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' network_scan.log | sort -u > ip_list.txt
                chown "$REAL_USER:$REAL_USER" ip_list.txt
                while IFS= read -r ip; do
                    nmap -Pn -p- -sC -sV "$ip" -vvv -oA "nmap_full_$ip"
                    chown "$REAL_USER:$REAL_USER" nmap_full_"$ip".*
                done < ip_list.txt
                whiptail --msgbox "Nmap scans completed.\nResults saved as nmap_full_<IP>.*" 10 60
            fi
            ;;
        4)
            whiptail --msgbox "Shell Escape Examples:\n\n\
python -c 'import pty; pty.spawn(\"/bin/bash\")'\n\
python3 -c 'import pty; pty.spawn(\"/bin/bash\")'\n\
/bin/bash -i\n\
/bin/sh -i\n\
echo os.system('/bin/bash')\n\
perl -e 'exec \"/bin/sh\"'\n\
ruby -e 'exec \"/bin/sh\"'\n\
awk 'BEGIN {system(\"/bin/sh\")}'" 20 70
            ;;
        5)
            break
            ;;
        *)
            whiptail --msgbox "Invalid selection." 10 60
            ;;
    esac
done
