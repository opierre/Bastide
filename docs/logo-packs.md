# Building and sharing a logo pack

A rule pack can give each rule a logo, shown in place of the merchant's monogram. Bastide's
repository hosts no third-party logo files, so logos reach users through packs other people
build. This guide covers the `logo` field of a pack entry.

The normative format is [`docs/schemas/rule-pack.v1.schema.json`](schemas/rule-pack.v1.schema.json);
the backend enforces it in `backend/app/features/rules/packs/schema.py`.

## Your responsibility

Whoever builds and shares a pack with embedded logos is responsible for the rights to them.
Brand logos are usually copyrighted and almost always trademarks. Only embed a logo in a pack
you share when its licence allows it. A linked logo is different: the pack carries only a link
to a file on Wikimedia Commons, which the user downloads onto their own machine if they choose.

## The two forms

`logo` is optional on every rule. It takes one of two forms, told apart by their keys.

### Embedded: `{ "data": ... }`

The picture travels inside the pack. Use it for packs you share as files.

- `data` is the picture's bytes in standard, padded base64 (RFC 4648 section 4), on one line.
- The picture must be a PNG, JPEG or WebP. SVG is not accepted.
- At most 10 MiB per logo, decoded, and at most 20 MiB of logos per pack.

An export with logos (`GET /rules/packs/export?include_logos=true`) produces this form, embedding
each rule's stored 256x256 PNG. If those logos would exceed the 20 MiB per-pack cap, the export
returns every rule without logos and sets `logos_too_large`.

### Linked: `{ "url", "license", "source" }`

The pack points at a file on Wikimedia Commons, and the importer downloads it only if the user
asks. Any Commons file may be linked, whatever its free licence.

- `url` is a direct link to the file, starting with
  `https://upload.wikimedia.org/wikipedia/commons/`: no other host or path, no port, no user
  info. Files under other paths, such as `/wikipedia/en/`, are non-free fair-use uploads to a
  single wiki and are refused.
- `license` is the file's actual licence as its Commons page shows it (`Public domain`, `CC0`,
  `CC BY-SA 4.0`, ...).
- `source` is the file's Commons page, for attribution. It is shown, never fetched.

**Why only Wikimedia Commons.** A pack comes from someone else. If it could name any URL,
importing it would make your machine contact a server its author chose, and tell them your IP
address and when you imported. With a single allowed host and path, a pack can do no more than ask for a
freely licensed file from Commons. Any other link fails validation, before anything is imported.

Commons logos are often SVG files, which Bastide does not read. Link to the PNG rendering
Commons generates instead: on the file's page, pick a size under "Other resolutions"; its URL
looks like `https://upload.wikimedia.org/wikipedia/commons/thumb/x/xy/Name.svg/512px-Name.svg.png`.

## What happens at import

- **Validation.** The whole pack is checked first: base64, sizes, the link's host and path. A pack that
  fails is refused, and nothing is imported.
- **Downloads are opt-in.** Linked logos are fetched only when the import is asked to
  (`download_logos: true` on `POST /rules/packs/import`). Otherwise they are counted in
  `logo_skipped_count`, and their rules are imported without them.
- **Each download** has a timeout, is held to the size caps, follows at most a few redirects
  (each one checked against the allowed host and path again), and sends only a fixed `User-Agent`
  naming the app: no cookies, nothing about the user. Two run at a time; one Wikimedia throttles
  (429, 503) is retried with backoff, within an overall deadline for the whole import.
- **Every logo** is decoded, fitted whole inside a square (aspect ratio kept, centred on a
  transparent background) and re-encoded as a 256x256 PNG, so a wide wordmark keeps its ends.
  PNG, JPEG and WebP files, Wikimedia's JPEG or PNG thumbnails included, all work.
- **Existing logos are kept.** A new rule gets its logo; a rule the user already has gets it
  only if it has none.
- **A logo that fails** (`invalid_image`, `too_large`, `download_failed`) is listed in
  `logo_failures` with its rule's index and pattern; the rule is imported without it.
  `logo_count` says how many logos were stored.

## Example

The merchants, picture and links below are invented. The base64 string is truncated to the
8-byte PNG signature, so the pack passes validation but its first logo is reported as
`invalid_image` at import: put a real picture's full base64 there.

```json
{
  "format_version": 1,
  "name": "Example shops",
  "description": "Two invented merchants, one embedded logo and one linked logo.",
  "locale": "en",
  "rules": [
    {
      "field": "merchant",
      "type": "contains",
      "pattern": "EXAMPLE GROCER",
      "category_key": "category.food.groceries",
      "logo": { "data": "iVBORw0KGgo=" }
    },
    {
      "field": "merchant",
      "type": "contains",
      "pattern": "SAMPLE TRAMWAYS",
      "category_key": "category.transport.public_transit",
      "logo": {
        "url": "https://upload.wikimedia.org/wikipedia/commons/thumb/0/0a/Sample_Tramways_logo.svg/512px-Sample_Tramways_logo.svg.png",
        "license": "Public domain",
        "source": "https://commons.wikimedia.org/wiki/File:Sample_Tramways_logo.svg"
      }
    }
  ]
}
```

To embed a picture, encode it on one line: `base64 -w0 logo.png` (Linux),
`base64 -i logo.png` (macOS), or `[Convert]::ToBase64String([IO.File]::ReadAllBytes("logo.png"))`
(PowerShell).

## Adding a logo link to `fr-common`

The bundled pack `backend/app/features/rules/packs/builtin/fr-common.v1.json` may carry linked
logos, never embedded ones: the repo ships no logo files. To add one for a brand:

1. Find the brand's logo on [Wikimedia Commons](https://commons.wikimedia.org/).
2. Read its licence on the file's Commons page. Any free licence Commons accepts will do.
3. Add a `logo` to the brand's rule with the file's PNG rendering as `url`, that licence as
   `license`, and the Commons page as `source`.
4. Run the rule pack tests from `backend/` (`uv run pytest tests/features/rules/packs`), which
   load the bundled pack, and link the Commons page in the PR.
