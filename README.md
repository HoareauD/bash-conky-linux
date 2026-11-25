# Scripts Linux pour Bash et Conky

- `installer-terminal-fedora.sh` configure les alias Bash `ls` et `ll` avec eza, la recherche interactive de l’historique avec fzf et le prompt Git en couleur.
- `conky/` contient le lanceur, le modèle de configuration et le script de lecture de la batterie. Chaque écran détecté reçoit un panneau en haut à droite avec le processeur, la mémoire, les disques, le réseau et les processus. Le niveau de batterie s’affiche quand le noyau expose une batterie lisible.
- `autostart/conky.desktop` lance Conky à l’ouverture de la session graphique.

## Terminal Bash

Depuis la racine du dépôt, avec ton compte utilisateur :

```bash
./installer-terminal-fedora.sh
```

Le nom du script est conservé pour les installations existantes. Il détecte Fedora, RHEL et leurs dérivés via `/etc/os-release` et utilise DNF. Sur Debian, Ubuntu et leurs dérivés, il utilise APT. Sur RHEL, Rocky Linux, AlmaLinux et CentOS Stream, active EPEL pour ta version si `fzf` est absent de tes dépôts. Sur Ubuntu, `fzf` peut nécessiter le dépôt Universe. [Instructions EPEL](https://docs.fedoraproject.org/en-US/epel/getting-started/) · [Installation fzf](https://github.com/junegunn/fzf#installation)

L’installateur utilise les paquets de la distribution quand ils fournissent les options demandées. Si `eza` est indisponible ou trop ancien, il installe la version officielle 0.23.5 dans `~/.local/bin` après vérification SHA-256. Ce téléchargement est prévu pour x86-64 et ARM64. Sur une autre architecture, installe une version compatible d’eza avant de relancer. [Version officielle d’eza](https://github.com/eza-community/eza/releases/tag/v0.23.5)

Le script configure trois fichiers dans `~/.bashrc.d/` et ajoute leur chargement à `~/.bashrc` si nécessaire. Il utilise les raccourcis fournis par le paquet des anciennes versions de fzf, notamment sur Debian 12. Si un fichier de configuration généré existe déjà et diffère, le script affiche le chemin de sa sauvegarde. [Fichiers du paquet fzf sur Debian 12](https://packages.debian.org/bookworm/amd64/fzf/filelist)

Dans un nouveau terminal Bash, lance `ls` ou `ll` pour voir les en-têtes, les icônes et le suffixe `/` des dossiers et les colonnes Git. La colonne `Git` indique le statut des fichiers et `Git Repo` identifie les racines des dépôts. Sélectionne dans Konsole une police contenant les glyphes Nerd Fonts si certaines icônes apparaissent sous forme de carrés. Appuie sur **Ctrl+R**, saisis quelques caractères de recherche, puis valide une entrée pour la remettre sur la ligne de commande. Un second **Entrée** exécute la commande.

Le prompt affiche la machine et le chemin en couleur sur la première ligne. La branche apparaît dans un dépôt Git. La commande se tape sur la deuxième ligne.

```text
╭─ utilisateur@machine  ~/Projets/mon-depot  [git:main]
╰─❯
```

## Conky sous KDE Plasma

Sur Fedora, installe les dépendances :

```bash
sudo dnf install conky xrandr iproute gawk util-linux-core procps-ng dejavu-sans-fonts glibc-langpack-fr
```

Sur Debian, Ubuntu et leurs dérivés :

```bash
sudo apt update
sudo apt install conky-all x11-xserver-utils iproute2 gawk util-linux procps fonts-dejavu-core
```

Sur RHEL et ses dérivés, installe les outils RPM suivants. Installe aussi `conky` depuis EPEL lorsqu’il est proposé pour ta version. Si le paquet est absent, utilise une version officielle de Conky compatible avec ta machine. Le lanceur accepte notamment un exécutable ou un AppImage enregistré sous `~/.local/bin/conky`. Vérifie sa prise en charge de X11 avec `conky --version` ou `~/.local/bin/conky --version`. [Paquet Conky pour EPEL](https://packages.fedoraproject.org/pkgs/conky/conky/) · [Installation officielle de Conky](https://github.com/brndnmtthws/conky#install--run)

```bash
sudo dnf install /usr/bin/xrandr iproute gawk util-linux procps-ng dejavu-sans-fonts
```

Le lanceur utilise Bash, sed et les outils de base. Il applique la locale française si elle est disponible. Le script batterie lit `/sys/class/power_supply/`.

### Vérifier l’affichage

Dans Konsole, depuis la session KDE où les panneaux devront s’afficher :

```bash
printf 'Session %s, affichage X %s\n' "${XDG_SESSION_TYPE:-inconnue}" "${DISPLAY:-absent}"
xrandr --listmonitors
conky --version
```

La configuration utilise la sortie X11 et le lanceur transmet les indices de `xrandr --listmonitors` à `conky -m`, qui sélectionne un écran via Xinerama. Pour deux panneaux, il faut que RandR voie les deux écrans et que les indices correspondent aux écrans Xinerama. Si `xdpyinfo` est disponible, `xdpyinfo -ext XINERAMA` permet de comparer les positions des écrans.

Sous Plasma Wayland, cette configuration passe par XWayland (paquet Fedora `xorg-x11-server-Xwayland` ou Debian/Ubuntu `xwayland`). Elle dépend de ce que XWayland expose via `DISPLAY`, RandR et Xinerama. Si KDE voit deux écrans mais que `xrandr` n’en expose qu’un, le lanceur crée un seul panneau. Vérifie aussi visuellement la position et la transparence sur chaque écran, en particulier avec des facteurs d’échelle différents. [Documentation Conky](https://github.com/brndnmtthws/conky/wiki/FAQ) · [Paquet Fedora](https://packages.fedoraproject.org/pkgs/conky/conky/)

### Installer et lancer

Les commandes suivantes remplacent les fichiers de même nom dans `~/.config`. Sauvegarde tes versions locales si tu souhaites pouvoir les restaurer. Exécute les commandes depuis la racine du dépôt :

```bash
install -d "$HOME/.config/conky" "$HOME/.config/autostart"
install -m 755 conky/start.sh conky/battery.sh "$HOME/.config/conky/"
install -m 644 conky/conky.conf "$HOME/.config/conky/"
install -m 644 autostart/conky.desktop "$HOME/.config/autostart/"
```

Ferme puis rouvre la session KDE pour déclencher l’autodémarrage. Pour un essai immédiat dans une session sans lanceur actif, exécute `"$HOME/.config/conky/start.sh"` au premier plan, puis utilise **Ctrl+C** pour arrêter le lanceur et ses panneaux. Le verrou empêche de démarrer un second lanceur simultanément.

Le lanceur vérifie les écrans et l’interface réseau toutes les cinq secondes. Les moniteurs détectés et le journal sont consultables dans `~/.config/conky/runtime/moniteurs.txt` et `~/.config/conky/runtime/conky.log`. Le dossier `runtime/`, les journaux et le verrou sont ignorés par Git.

## Vérifications effectuées

Sous Fedora 45, l’installateur a été exécuté deux fois avec un dossier personnel temporaire. Les en-têtes, les icônes et le suffixe des dossiers ont été vérifiés avec eza 0.23.5. Le vrai menu de fzf 0.75.0 a retrouvé et rappelé une commande par **Ctrl+R** dans un Bash interactif isolé. Des profils Linux Mint et Rocky Linux simulés ont confirmé la sélection d’APT et de DNF. L’installation sur des systèmes Debian et RHEL réels reste à vérifier.

L’entrée d’autodémarrage a été validée puis lancée via GIO avec un script témoin. Un essai du lanceur avec deux écrans simulés a confirmé les indices `0` et `1`, la génération de la configuration avec le réseau et la batterie, et le verrou. L’affichage réel des deux panneaux reste à vérifier dans la session KDE, car l’environnement de test ne pouvait pas ouvrir son affichage X.
