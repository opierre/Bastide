# Installing Bastide

🇫🇷 [Version française](install.fr.md)

Bastide is a desktop app for Windows, macOS and Linux. Download it from the project's
[Releases page](https://github.com/opierre/Bastide/releases): pick the file for your system.

| System | File | Kind |
| --- | --- | --- |
| Windows 10 / 11 | `Bastide-Setup-<version>.exe` | Installer (recommended) |
| Windows 10 / 11 | `Bastide-<version>-windows.zip` | Portable: nothing to install |
| macOS (Apple Silicon) | `Bastide-<version>-macos.dmg` | Disk image |
| Linux | `Bastide-<version>-x86_64.AppImage` | One file to run |

## Why your computer warns you

Bastide isn't **signed**. Signing means buying a certificate from Microsoft's or Apple's
partners, every year, so the system recognises who published the app. Bastide is a free
project and doesn't pay for one. Because of that, Windows and macOS show a warning the first
time you open each new version. The warning doesn't mean anything was found in the app: it
means the system doesn't know who made it.

What you can do instead of trusting a certificate:

- The source code is public, and each release is built from it by GitHub's servers, not on
  someone's computer.
- You can check that your download is exactly the published file (see
  [Check your download](#check-your-download)).

## Windows

### Install

1. Run `Bastide-Setup-<version>.exe`.
2. Windows shows **"Windows protected your PC"**. Click **More info**, then **Run anyway**.
3. Follow the steps. No administrator password is needed: Bastide installs
   for your user only, in `%LOCALAPPDATA%\Programs\Bastide`.
4. Open Bastide from the Start menu.

Windows Defender may also stop the app. If it does, please
[open an issue](https://github.com/opierre/Bastide/issues): we report each false alarm to
Microsoft.

### Portable version

Unzip `Bastide-<version>-windows.zip` anywhere (a USB stick works), open the `Bastide` folder
and run `bastide.exe`. The same **More info → Run anyway** warning appears. Your data is not
stored in that folder but in your user folder, as with the installer (see
[Where your data lives](#where-your-data-lives)).

### Update

Close Bastide, then run the new version's installer. If Bastide is still open, the installer
asks you to close it first.

### Uninstall

**Settings → Apps → Installed apps → Bastide → Uninstall**. For the portable version, delete
its folder. Your data stays on your computer: see below to remove it too.

## macOS

### Install

1. Open `Bastide-<version>-macos.dmg`.
2. Drag **Bastide** onto the **Applications** folder.
3. Open Bastide from Applications. macOS says it can't check the app: click **Done** (or
   **OK**), **not** Move to Trash.
4. Open **System Settings → Privacy & Security**, scroll down to the message about Bastide and
   click **Open Anyway**. Confirm with your password.
5. Open Bastide again; macOS won't ask anymore for this version.

On macOS 15 (Sequoia) and later, right-click → Open no longer skips the warning: use step 4.

If you're comfortable with the Terminal, this does the same as steps 3 to 5:

```bash
xattr -dr com.apple.quarantine /Applications/Bastide.app
```

### Update

Quit Bastide, then drag the new version onto Applications and replace the old one. Each new
version needs **Open Anyway** once.

### Uninstall

Drag **Bastide** from Applications to the Trash. Your data stays on your computer.

## Linux

1. Make the file executable: right-click → **Properties → Permissions → Allow executing as a
   program**, or in a terminal:

   ```bash
   chmod +x Bastide-<version>-x86_64.AppImage
   ```

2. Double-click it, or run `./Bastide-<version>-x86_64.AppImage`.

Bastide needs two system libraries that standard desktops already have. If nothing happens
when you launch it, install the missing one:

- **FUSE**, which every AppImage needs: `sudo apt install libfuse2t64` on Ubuntu 24.04
  (`libfuse2` on Ubuntu 22.04).
- **libsecret**, through which Bastide keeps your login in the system keyring:
  `sudo apt install libsecret-1-0` (Fedora: `sudo dnf install libsecret`). A keyring service
  (GNOME Keyring or KWallet) must also be running.

To update, download the new AppImage and delete the old one. To uninstall, delete the file.

## Where your data lives

Your accounts, transactions and settings are on your computer only, in one folder for each
user account:

| System | Folder |
| --- | --- |
| Windows | `%LOCALAPPDATA%\Bastide` (paste it into the File Explorer address bar) |
| macOS | `~/Library/Application Support/Bastide` (Finder → Go → Go to Folder…) |
| Linux | `~/.local/share/Bastide` (or `$XDG_DATA_HOME/Bastide`) |

That folder holds:

- `bastide.db`: the database;
- `backups/`: a copy taken automatically before each update changes the database;
- `logs/`: technical logs, without your transactions.

Uninstalling Bastide never deletes this folder. To erase everything, delete it yourself after
uninstalling.

## Back up your data

In Bastide: **Settings → Data → Backup & restore → Export all data**. You get one `.bastide`
file with everything, which you can restore on any computer with **Restore a backup**. The file
isn't encrypted: keep it somewhere safe.

Copying the data folder while Bastide is closed works too.

## Going back to an older version

Each update may upgrade the database. An older version then refuses to open it and says so,
rather than damaging it. To go back anyway, restore a `.bastide` export made with that older
version, or put back the copy from `backups/` taken before the update.

## Check your download

Each release lists the SHA-256 fingerprint of every file in `SHA256SUMS`. Compute your file's
fingerprint and compare it with the line for that file; they must be identical.

- Windows (PowerShell): `Get-FileHash .\Bastide-Setup-<version>.exe -Algorithm SHA256`
- macOS: `shasum -a 256 Bastide-<version>-macos.dmg`
- Linux, in the download folder: `sha256sum --check --ignore-missing SHA256SUMS`
