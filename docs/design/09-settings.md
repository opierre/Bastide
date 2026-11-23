# 09 — Paramètres

Mockup: `#panel=settings&variant=A` (Profil), `B` (Préférences), `C` (Données), `D` (À propos).
Ticket #216. Read `00-design-system.md` first.

## Title bar
Title « Paramètres ». No control.

## Layout
Flush panel, two panes:
- **Section nav** (200 px, right hairline, padding 16 8): four nav items with an icon:
  « Profil » (`user`), « Préférences » (`sliders-horizontal`), « Données » (`database`),
  « À propos » (`info`). Selected item per the nav recipe.
- **Section body** (padding 24 40, max width 900, scrolls on its own).

### Setting row (the only building block)
A row with a top hairline, padding 14 0, 24 px gap:
- left, 300 px: name 13/500 over a description 12 `textTertiary`;
- right, flexible: the control(s), stacked 8 px apart, left-aligned.

Rows are grouped under a **section title** 16/600 (12 px below it, 28 px above when not
first). No card, no tinted callout, no coloured border.

## Profil
| Group | Row | Right side |
|---|---|---|
| Profil | Avatar · « Un monogramme, une pastille de couleur ou une photo. La photo reste sur cet ordinateur. » | The current avatar at 48 px with a 2 px `accent` ring, then the six colour presets as 32 px discs (category slots), then secondary « Choisir une photo » (`image`); with a photo set, ghost « Retirer la photo ». |
| | Nom d’utilisateur · « Vous pouvez vous connecter avec ce nom ou avec votre e-mail. » | The name + secondary « Modifier » (modal 420 px). |
| | Adresse e-mail · « Sert uniquement à vous connecter. Bastide n’envoie aucun message. » | The address, `textSecondary` + secondary « Modifier » (modal 420 px). |
| Sécurité | Mot de passe · « Au moins 12 caractères. Il protège l’accès à vos données sur cet ordinateur. » | Secondary « Changer le mot de passe » (modal 420 px: current, new, confirm). |
| | Code de récupération · « Permet de réinitialiser votre mot de passe si vous l’oubliez. En générer un nouveau invalide l’ancien. » | Secondary « Générer un nouveau code » (modal 480 px: asks the password, then shows the code once, `00` §7 single way out: focus on « Copier », secondary « Enregistrer dans un fichier »). |
| Session | Se déconnecter · « Vos données restent sur cet ordinateur, protégées par votre mot de passe. » | Secondary « Se déconnecter » (`log-out`). |

Avatar picking opens the crop modal (420 px): the square crop with the avatar's circle drawn and the corners veiled (`00` §7).

Neither row shows a date: nothing records when the password or the code last changed.

**Username modal** (420 px): title « Changer de nom d’utilisateur », lead « Le nouveau nom
remplace l’ancien pour vous connecter. »; one field « Nom d’utilisateur » with the helper
« Sert aussi à vous connecter. 3 à 32 caractères : lettres, chiffres, espaces, « . », « _ » ou
« - ». »; footer « Annuler » · primary « Enregistrer ». The rule is the one of `03-register.md`:
spaces are allowed, so a name such as « Camille Dubois » passes. A name already in use gives
« Ce nom d’utilisateur est déjà pris. » under the field.

**Email modal** (420 px): title « Changer d’adresse e-mail », lead « La nouvelle adresse
remplace l’ancienne pour vous connecter. »; fields « Nouvelle adresse e-mail » (prefilled with
the current one) and « Mot de passe actuel », asked because the address signs in; footer
« Annuler » · primary « Enregistrer », enabled once the address is well formed and different
and the password is filled in. A malformed address gives « Saisissez une adresse e-mail
valide. » and one already in use « Cette adresse e-mail est déjà utilisée. » under the address;
a wrong password gives « Mot de passe incorrect. » under its field. Success closes the modal and
the row shows the new address; every session stays open.

**Password modal** (420 px): title « Changer le mot de passe », lead « Votre code de récupération
reste valable. »; fields « Mot de passe actuel », « Nouveau mot de passe » (with the new-password
helper of `03-register.md`) and « Confirmer le mot de passe »; footer « Annuler » · primary
« Changer le mot de passe », enabled once the current password is filled in, the new one meets the
12-character rule and the confirmation matches. A wrong current password gives « Mot de passe
incorrect. » under its field. Success closes the modal and toasts « Mot de passe modifié. »; the
session stays open and every other session of the user is signed out.

## Préférences
| Group | Row | Right side |
|---|---|---|
| Affichage | Thème · « Sombre, clair, ou celui de votre système. » | Segmented « Système · Sombre · Clair ». Default « Sombre ». Applies at once. |
| | Taille du texte · « Agrandit tout le texte de l’application. » | Segmented « Normal · Grand · Très grand ». Default « Normal ». Applies at once to every text of the app (`00` §3 « Text size »). |
| | Langue · « S’applique immédiatement à toute l’interface. » | Segmented « Français · English ». |
| | Formats · « Dates et montants suivent la langue choisie. » | Key/value list: Date « 14 mai 2026 · 14/05/2026 »; Montant « −1 234,56 € ». |
| Argent | Devise · « Choisie à l’inscription et appliquée à tous vos comptes. Elle ne peut pas être modifiée dans cette version. » | Read-only value: `lock` + « EUR, euro (€) ». |
| | Objectif de taux d’épargne · « Le repère affiché sur le tableau de bord. » | Slider 1–50 %, step 1, value printed (« 20 % »). |
| | Revenu déclaré · « Sert au taux d’endettement des panneaux Crédits et Simulateur. Sans lui, Bastide prend le revenu médian constaté. » | Amount field 140 px + « par mois »; empty means "not declared". |

Three rows change what exists today and need more than a restyle:
- « Objectif de taux d’épargne » is a stored per-user value (`savings_rate_goal_percent`,
  1–50 %, default 20). The Dashboard summary carries it, so the repère's mark and the goal status
  follow it.
- « Taille du texte » is a stored per-user value (`text_size`: `normal`, `large`, `xlarge`;
  default `normal`), like the theme; the app applies it before the save answers.
- « Revenu déclaré » is edited only here. Every « Déclarer un revenu » action in Crédits and
  Simulateur opens Préférences (`/settings?focus=income`), scrolls this row into view and focuses
  its field; both panels re-read the value once it is saved.

## Données
| Group | Row | Right side |
|---|---|---|
| IA locale | Catégorisation par IA · « Les libellés de vos opérations sont envoyés à un modèle qui s’exécute sur cet ordinateur. Rien ne quitte votre machine. » | Toggle. The rows below are disabled when it is off. |
| | Moteur · « Adresse locale uniquement : 127.0.0.1 ou localhost. » | One line: address field (Geist Mono, flex 1.3) · model select (Geist Mono, flex 1) · secondary « Tester ». Under it, status text: `check` `positive` « Connecté » + « · 3 modèles disponibles »; or `triangle-alert` `warning` « Aucun moteur détecté à cette adresse. » + link « En savoir plus ». Without an engine the model select is disabled with « Moteur injoignable : aucun modèle à proposer. » |
| | Seuil de confiance · « En dessous, l’opération vous est proposée pour vérification au lieu d’être classée. » | Slider 320 px, value printed (« 80 % »). |
| Sauvegarde | Exporter toutes les données · « Un fichier .bastide, non chiffré, avec tout votre historique. Conservez-le en lieu sûr. » | Primary « Exporter » (`download`) + « Dernière sauvegarde le {date} à {heure} », long date (« Dernière sauvegarde le 11 mai 2026 à 14:32 ») or « Aucune sauvegarde. » |
| | Restaurer une sauvegarde · « Remplace toutes les données actuelles, après confirmation. » | Secondary « Importer un fichier » (`upload`). |
| Réinitialisation | Réinitialiser la base de données · « Supprime opérations, comptes, règles, catégories personnalisées, objectifs, abonnements, crédits, biens, placements et simulations de ce profil. Les sauvegardes exportées ne sont pas touchées. » | Danger button « Réinitialiser… » (`trash-2`). |

In Sauvegarde and Réinitialisation the controls sit against the row's right edge, the
line « Dernière sauvegarde… » under « Exporter » included; banners keep the full width.

Modals (all 500 px):
- **Restore confirmation:** title « Restaurer cette sauvegarde ? », lead « Les données
  exportées le {date} remplacent toutes vos données actuelles. » (long date, « 11 mai 2026 »),
  the file name in Geist Mono, then a comparison key/value list (`00` §7) with two columns
  « Sauvegarde · Actuel »: Version de l’application, Dernier import (long date), then one
  count per kind of data. When the backup was exported before the latest import, status text
  `warning` `triangle-alert` under the list: « Cette sauvegarde est antérieure à votre dernier
  import du {date}. »; nothing otherwise. Footer: ghost « Exporter d’abord » (`download`) on
  the left · « Annuler » · solid `negative` button « Remplacer mes données ». « Exporter
  d’abord » runs the export and its save dialog without closing the modal; once the file is
  saved, status text `positive` `check` « Sauvegarde enregistrée » takes the button's place
  (`00` §7 « Modal », States).
- **Restore refused:** a Banner with a `negative` icon inside the Sauvegarde group, under the
  restore row: « Restauration impossible. Ce fichier provient d’une version plus récente de
  Bastide. Mettez l’application à jour pour le restaurer. »
- **Reset confirmation:** title « Réinitialiser la base de données ? », lead naming the
  profile, key/value list of live counts, note « Les catégories fournies, vos préférences et le
  réglage IA sont conservés. », field « Saisissez « supprimer » pour confirmer » (Geist Mono, any case matches, helper
  « Majuscules ou minuscules, peu importe. »),
  footer: ghost « Exporter d’abord » on the left, as in the restore · « Annuler » · solid
  `negative` « Tout supprimer », disabled until the field matches.
- Toasts: « Sauvegarde enregistrée · 1 284 opérations, 4 comptes. » · « Base de données
  réinitialisée. »

## À propos
- **Header row** on tomettes (`00` §12, place 5): 1 px `line`, radius 8, padding 20; Plan mark
  44 px · « Bastide » 16/600 over « Version {version} · {OS} » `textSecondary`.
- Rows:

| Row | Right side |
|---|---|
| Mises à jour · « Une fois par jour au plus, Bastide demande à GitHub le numéro de la dernière version publiée. Rien d’autre n’est envoyé, et rien n’est installé sans vous. » | Toggle + « Me prévenir d’une nouvelle version »; status text (« Vous utilisez la dernière version. » / `warning` « Bastide {version} est disponible » + secondary « Télécharger » / « GitHub n’a pas pu être joint. »); secondary « Vérifier maintenant ». |
| Confidentialité · « Ce que Bastide fait de vos données. » | The `settingsAboutPrivacy` sentence, 13 `text`. |
| Emplacement des données · « Le fichier qui contient tout votre historique. » | The path in Geist Mono `textSecondary` + secondary « Ouvrir le dossier » (`folder-open`). |
| Licence · « Bastide est un logiciel libre. Son nom et son logo ne sont pas couverts par la licence. » | « GNU Affero General Public License v3.0 » + secondary « Code source » (`external-link`), secondary « Guide d’installation ». |
| Crédits · « Les composants tiers fournis avec l’application. » | Key/value: Icônes « Lucide, licence ISC »; Police « Geist, licence SIL OFL ». Link « Toutes les licences » (Flutter's licence page). |

## States
Each section: populated · loading (row silhouettes). Données: AI on/connected, AI on/no engine,
AI off, export in progress (button spinner, « Préparation de l’archive… »), restore refused.
Restore confirmation: backup as recent as the latest import, backup older (warning), export
done (« Sauvegarde enregistrée »).
À propos: up to date, update available, offline, check disabled. English for all four.

## Behaviour (kept)
- The engine address accepts loopback only; anything else is rejected with the helper in
  `negative`.
- Export is disabled while an archive is being prepared. Restore always goes through its
  confirmation. A file from a newer version is refused before anything is touched.
- Reset covers the current profile only, runs in one transaction, re-seeds the system
  categories and keeps profile, preferences and AI settings.
- The update check is opt-in and sends nothing but the version request.
- In this panel the solid `negative` button appears only inside the two destructive confirmations (`00` §6 « Button, destructive »).

## Copy
Delete `navSettingsSubtitle`. `settingsAiSubtitle`, `settingsAiModelUnavailable`,
`settingsBackupPrivacy`, `settingsBackupNone` per `00` §14. Remove « IRRÉVERSIBLE » and « Zone
de danger ». New: theme, text size, session, licence and data-location strings above.
A refused text-size save toasts « La taille du texte n’a pas pu être enregistrée. Rien n’a été
modifié. Réessayez. » and puts the previous size back, as the theme does.

## Removed from v1
Grouped cards per setting, tinted privacy callouts, inset export plate with a tinted tile, the
red-bordered danger card and its pill, format preview plates, dashed read-only field.
