# 🦌 CariMediaScan

**Toutes les infos techniques de vos fichiers vidéo, audio et Blackmagic RAW — directement dans le clic droit du Finder de macOS.**

*Read this in [English](README.md).*

CariMediaScan est une **Action rapide Automator** pour macOS. Un clic droit sur n'importe quel fichier média dans le Finder affiche instantanément sa fiche technique complète dans une fenêtre native et épurée — aucune application à installer, aucun logiciel à ouvrir. On peut même lui attribuer un raccourci clavier.

Réalisé par [Caribou Labs](https://carrillat.fr) · par Nathan Carrillat.

---

## Pourquoi

Il existe plein d'outils pour analyser des fichiers vidéo. Je cherchais quelque chose de simple, directement dans le Finder : pas d'application à installer, juste une « action rapide » au clic droit, assignable à un raccourci clavier. Comme ça n'existait pas vraiment, je l'ai construit.

---

## Fonctionnalités

### 🎬 Vidéo
Résolution (avec label : 4K UHD, Full HD…), fréquence d'images précise, codec (H.264, HEVC, ProRes, AV1…), pixel format, espace colorimétrique avec détection **HDR10 / HLG / Dolby Vision / HDR10+**, débit, **timecode de départ** et driver — ainsi qu'une ligne par **piste audio** et par **piste de sous-titres** (langue, format, drapeaux `default` / `forced` / `SDH`).

### 🎵 Audio
Codec, format, débit, fréquence d'échantillonnage, **profondeur de bits** (16/24 bits), canaux, **tags musicaux** complets (titre, artiste, album, année, piste, genre) et affichage de la **pochette intégrée** avec sa résolution.

### 🎥 Blackmagic RAW
Une vraie fiche caméra de tournage : résolution, fps, compression et débit, gamma/gamut, LUT embarquée, modèle de caméra et firmware, objectif, réglages de prise (ISO, ouverture, focale, vitesse, balance des blancs), métadonnées de production (réalisateur, scène, prise, reel, date) et durée estimée.

### ➕ En plus
- **Navigation dans le dossier** aux flèches (↑ ↓ ← →), avec boucle aux extrémités
- **Mise à jour en direct** : cliquez sur un autre fichier dans le Finder, la fenêtre s'actualise toute seule
- **Mode comparaison** : sélectionnez deux fichiers pour voir les deux rapports côte à côte
- **Fenêtre redimensionnable** avec contenu défilant
- **Copie** de tout le rapport dans le presse-papiers en un clic

---

## Prérequis

- **macOS**
- **[ffmpeg](https://ffmpeg.org/)** (qui fournit `ffprobe`) pour le détail complet :
  ```sh
  brew install ffmpeg
  ```
  Sans ffmpeg, le script bascule sur les métadonnées Spotlight de macOS — fonctionnel mais moins détaillé.
- Le support **Blackmagic RAW** repose sur le plugin Spotlight installé avec **DaVinci Resolve**.

---

## Installation

1. Téléchargez `CariMediaScan.workflow` (voir [Releases](../../releases), ou construisez-le vous-même — voir plus bas).
2. Double-cliquez dessus, ou glissez-le dans `~/Library/Services/`.
3. macOS peut demander l'autorisation de contrôler le Finder (pour la mise à jour au clic) : cliquez **Autoriser**.

### Le construire soi-même depuis le script

Si vous n'avez que `CariMediaScan.sh` :

1. Ouvrez **Automator** → **Nouveau document** → **Action rapide**.
2. Réglez *« Le processus reçoit l'élément actuel »* sur **fichiers ou dossiers** dans **Finder**.
3. Ajoutez une action **Exécuter un script Shell**.
4. Réglez **Shell : `/bin/zsh`** et **Transmettre l'entrée : comme arguments** (important).
5. Collez tout le contenu de [`CariMediaScan.sh`](CariMediaScan.sh).
6. Enregistrez (⌘S) sous le nom **CariMediaScan**.

---

## Utilisation

Clic droit sur un fichier média dans le Finder → **Actions rapides → CariMediaScan**.

| Commande | Action |
| --- | --- |
| `← →` ou `↑ ↓` | Fichier précédent / suivant du dossier |
| Clic dans le Finder | Sélectionner un fichier met la fenêtre à jour |
| Redimensionner | Tirez les bords ; le contenu défile |
| **Copy** | Copie le rapport dans le presse-papiers |
| `Entrée` / `OK` / `Échap` | Ferme la fenêtre |

### Facultatif : raccourci clavier

**Réglages Système → Clavier → Raccourcis clavier → Services** (section *Fichiers et dossiers*) → repérez **CariMediaScan** et attribuez une combinaison (par ex. `⌃⌥⌘I`). Il suffit ensuite de sélectionner un fichier dans le Finder et de la presser.

---

## Formats reconnus

**Vidéo** — MP4 · MOV · M4V · MKV · AVI · WebM · MTS / M2TS · TS · WMV · FLV · MPG / MPEG · 3GP · OGV · VOB · MXF · BRAW (Blackmagic RAW)

**Audio** — MP3 · FLAC · WAV · M4A · AAC · OGG · Opus · AIFF · WMA · ALAC · APE · WV

---

## Documentation

Une fiche explicative d'une page est disponible en [français](docs/CariMediaScan-Fiche-FR.pdf) et en [anglais](docs/CariMediaScan-Guide-EN.pdf).

---

## Licence

Distribué sous [licence MIT](LICENSE).

---

<sub>CariMediaScan — by Caribou Labs 🦌</sub>
