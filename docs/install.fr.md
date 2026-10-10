# Installer Bastide

🇬🇧 [English version](install.md)

Bastide est une application de bureau pour Windows, macOS et Linux. Téléchargez-la depuis la
[page des versions](https://github.com/opierre/Bastide/releases) du projet : choisissez le
fichier qui correspond à votre système.

| Système | Fichier | Type |
| --- | --- | --- |
| Windows 10 / 11 | `Bastide-Setup-<version>.exe` | Installateur (recommandé) |
| Windows 10 / 11 | `Bastide-<version>-windows.zip` | Portable : rien à installer |
| macOS (Apple Silicon) | `Bastide-<version>-macos.dmg` | Image disque |
| Linux | `Bastide-<version>-x86_64.AppImage` | Un seul fichier à lancer |

## Pourquoi votre ordinateur vous avertit

Bastide n'est pas **signée**. Signer une application, c'est acheter chaque année un
certificat auprès des partenaires de Microsoft ou d'Apple, pour que le système sache qui l'a
publiée. Bastide est un projet gratuit et n'en paie pas. Windows et macOS affichent donc un
avertissement la première fois que vous ouvrez chaque nouvelle version. Cet avertissement ne
signifie pas que quelque chose a été trouvé dans l'application : il signifie que le système ne
sait pas qui l'a faite.

Ce que vous pouvez vérifier à la place d'un certificat :

- Le code source est public, et chaque version est construite à partir de lui par les serveurs
  de GitHub, pas sur l'ordinateur de quelqu'un.
- Vous pouvez vérifier que votre téléchargement est exactement le fichier publié (voir
  [Vérifier votre téléchargement](#vérifier-votre-téléchargement)).

## Windows

### Installer

1. Lancez `Bastide-Setup-<version>.exe`.
2. Windows affiche **« Windows a protégé votre ordinateur »**. Cliquez sur **Informations
   complémentaires**, puis sur **Exécuter quand même**.
3. Suivez les étapes. Aucun mot de passe administrateur n'est demandé : Bastide s'installe pour
   votre utilisateur seulement, dans `%LOCALAPPDATA%\Programs\Bastide`.
4. Ouvrez Bastide depuis le menu Démarrer.

Il arrive que Windows Defender bloque aussi l'application. Dans ce cas,
[ouvrez un ticket](https://github.com/opierre/Bastide/issues) : nous signalons chaque fausse
alerte à Microsoft.

### Version portable

Décompressez `Bastide-<version>-windows.zip` où vous voulez (une clé USB convient), ouvrez le
dossier `Bastide` et lancez `bastide.exe`. Le même avertissement **Informations
complémentaires → Exécuter quand même** apparaît. Vos données ne sont pas enregistrées dans ce
dossier mais dans votre dossier utilisateur, comme avec l'installateur (voir
[Où sont vos données](#où-sont-vos-données)).

### Mettre à jour

Fermez Bastide, puis lancez l'installateur de la nouvelle version. Si Bastide est encore
ouverte, l'installateur vous demande de la fermer d'abord.

### Désinstaller

**Paramètres → Applications → Applications installées → Bastide → Désinstaller**. Pour la
version portable, supprimez son dossier. Vos données restent sur votre ordinateur : voir
plus bas pour les supprimer aussi.

## macOS

### Installer

1. Ouvrez `Bastide-<version>-macos.dmg`.
2. Faites glisser **Bastide** sur le dossier **Applications**.
3. Ouvrez Bastide depuis Applications. macOS indique qu'il ne peut pas vérifier l'application :
   cliquez sur **Terminé** (ou **OK**), **pas** sur Placer dans la corbeille.
4. Ouvrez **Réglages Système → Confidentialité et sécurité**, descendez jusqu'au message qui
   concerne Bastide et cliquez sur **Ouvrir quand même**. Confirmez avec votre mot de passe.
5. Rouvrez Bastide ; macOS ne posera plus la question pour cette version.

Depuis macOS 15 (Sequoia), clic droit → Ouvrir ne contourne plus l'avertissement : passez par
l'étape 4.

Si vous êtes à l'aise avec le Terminal, cette commande remplace les étapes 3 à 5 :

```bash
xattr -dr com.apple.quarantine /Applications/Bastide.app
```

### Mettre à jour

Quittez Bastide, puis faites glisser la nouvelle version sur Applications en remplaçant
l'ancienne. Chaque nouvelle version demande une fois **Ouvrir quand même**.

### Désinstaller

Faites glisser **Bastide** depuis Applications vers la Corbeille. Vos données restent sur votre
ordinateur.

## Linux

1. Rendez le fichier exécutable : clic droit → **Propriétés → Permissions → Autoriser
   l'exécution du fichier comme un programme**, ou dans un terminal :

   ```bash
   chmod +x Bastide-<version>-x86_64.AppImage
   ```

2. Double-cliquez dessus, ou lancez `./Bastide-<version>-x86_64.AppImage`.

Si rien ne se passe, il manque peut-être FUSE, dont les AppImage ont besoin. Sur Ubuntu 24.04 :
`sudo apt install libfuse2t64` (Ubuntu 22.04 : `libfuse2`). Bastide garde votre connexion dans
le trousseau du système : un service de trousseau (GNOME Keyring ou KWallet) doit tourner, ce
qui est le cas sur les bureaux courants.

Pour mettre à jour, téléchargez la nouvelle AppImage et supprimez l'ancienne. Pour désinstaller,
supprimez le fichier.

## Où sont vos données

Vos comptes, opérations et réglages sont uniquement sur votre ordinateur, dans un dossier
propre à chaque compte utilisateur :

| Système | Dossier |
| --- | --- |
| Windows | `%LOCALAPPDATA%\Bastide` (collez-le dans la barre d'adresse de l'Explorateur) |
| macOS | `~/Library/Application Support/Bastide` (Finder → Aller → Aller au dossier…) |
| Linux | `~/.local/share/Bastide` (ou `$XDG_DATA_HOME/Bastide`) |

Ce dossier contient :

- `bastide.db` : la base de données ;
- `backups/` : une copie faite automatiquement avant chaque mise à jour qui modifie la base ;
- `logs/` : des journaux techniques, sans vos opérations.

Désinstaller Bastide ne supprime jamais ce dossier. Pour tout effacer, supprimez-le vous-même
après la désinstallation.

## Sauvegarder vos données

Dans Bastide : **Paramètres → Données → Sauvegarde et restauration → Exporter toutes les
données**. Vous obtenez un fichier `.bastide` qui contient tout, et que vous pouvez restaurer
sur n'importe quel ordinateur avec **Restaurer une sauvegarde**. Le fichier n'est pas chiffré :
rangez-le en lieu sûr.

Copier le dossier de données pendant que Bastide est fermée fonctionne aussi.

## Revenir à une version précédente

Une mise à jour peut faire évoluer la base de données. Une version plus ancienne refuse alors
de l'ouvrir et l'indique, plutôt que de l'abîmer. Pour revenir en arrière quand même, restaurez
un export `.bastide` fait avec cette ancienne version, ou remettez en place la copie de
`backups/` faite avant la mise à jour.

## Vérifier votre téléchargement

Chaque version liste l'empreinte SHA-256 de chaque fichier dans `SHA256SUMS`. Calculez
l'empreinte de votre fichier et comparez-la à la ligne de ce fichier : elles doivent être
identiques.

- Windows (PowerShell) : `Get-FileHash .\Bastide-Setup-<version>.exe -Algorithm SHA256`
- macOS : `shasum -a 256 Bastide-<version>-macos.dmg`
- Linux, dans le dossier de téléchargement : `sha256sum --check --ignore-missing SHA256SUMS`
