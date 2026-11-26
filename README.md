# Bash et Conky sous Linux

- **Bash** affiche les icônes et le statut Git dans `ls` et `ll`. **Ctrl+R** ouvre la recherche dans l’historique. Le prompt est en couleur et affiche la branche Git dans un dépôt.
- **Conky** affiche le processeur, la mémoire, les disques et le réseau sur chaque écran détecté.

## Installer le terminal

Fonctionne avec les familles Fedora, Red Hat et Debian, dont Ubuntu. Depuis ton terminal Bash, avec ton compte utilisateur :

```bash
git clone https://github.com/HoareauD/scripts-fedora.git
cd scripts-fedora
./installer-terminal-fedora.sh
```

Ouvre un nouveau terminal pour essayer `ls` et **Ctrl+R**. Si les icônes s’affichent en carrés, sélectionne une police **Nerd Font** dans ton terminal.

## Installer Conky (facultatif)

Cette configuration utilise X11 ou XWayland. Elle place un panneau en haut à droite de chaque écran listé par `xrandr`, y compris les écrans en portrait ou décalés verticalement.

Installe les paquets correspondant à ta distribution.

- **Fedora** — `sudo dnf install conky /usr/bin/xrandr wmctrl iproute dejavu-sans-fonts`
- **Debian / Ubuntu** — `sudo apt update && sudo apt install conky-all x11-xserver-utils wmctrl iproute2 fonts-dejavu-core`
- **RHEL et dérivés** — `sudo dnf install /usr/bin/xrandr iproute dejavu-sans-fonts`, active [EPEL](https://docs.fedoraproject.org/en-US/epel/getting-started/), puis installe `wmctrl` et `conky` s’ils sont disponibles pour ta version. Sinon, place un exécutable Conky compatible X11 dans `~/.local/bin/conky`. [Installation de Conky](https://github.com/brndnmtthws/conky#install--run)

Depuis le dossier `scripts-fedora`, copie la configuration. Sauvegarde d’abord tes fichiers Conky si tu en as déjà.

```bash
install -d ~/.config/conky ~/.config/autostart
install -m 755 conky/{start,battery}.sh ~/.config/conky/
install -m 644 conky/conky.conf ~/.config/conky/
install -m 644 autostart/conky.desktop ~/.config/autostart/
```

Ferme puis rouvre ta session graphique. Si un panneau manque ou est mal placé, vérifie que `xrandr --listmonitors` liste tous les écrans attendus et consulte `~/.config/conky/runtime/conky.log`.

Si `fzf` est introuvable sur RHEL et ses dérivés, vérifie que le dépôt [EPEL](https://docs.fedoraproject.org/en-US/epel/getting-started/) est activé.
