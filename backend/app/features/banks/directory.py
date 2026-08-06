"""French bank codes (`code banque` / CIB) mapped to the bank they belong to.

A French IBAN is `FR76` + a 5-digit bank code + a 5-digit branch code + the
account number, and an OFX statement from a French bank puts that bank code in
`BANKID`. On its own it is a number the user has never seen — `13306` means
nothing, `Crédit Agricole` means everything — so this directory turns it into a
name we can propose as the account's institution.

Codes come from the Banque de France interbank directory (CIB). Names are the
*brand* rather than the legal entity: a user opening an account at the Caisse
d'Épargne Côte d'Azur types "Caisse d'Épargne", and that is also what the
statement matcher compares against and what the monogram chip is coloured from.

The mapping is a proposal, never a fact: everything it produces lands in an
editable form field.
"""

# Exact codes, most specific first. Regional banks of a mutualist network all
# resolve to the network's brand — the regional entity is not what the user
# calls their bank.
FRENCH_BANK_CODES: dict[str, str] = {
    # National and online banks
    "10057": "CIC",
    "10096": "CIC",
    "10107": "BRED Banque Populaire",
    "10278": "Crédit Mutuel",
    "11808": "Crédit Mutuel",
    "11899": "Crédit Mutuel",
    "12240": "Allianz Banque",
    "12280": "Socram Banque",
    "12548": "AXA Banque",
    "12579": "Banque BCP",
    "12619": "Caixa Geral de Depósitos",
    "12869": "Oney",
    "12933": "CaixaBank",
    "14518": "Arkéa Direct Bank",
    "14628": "FLOA",
    "14940": "Cofidis",
    "15900": "Federal Finance",
    "16188": "BPCE",
    "16218": "BforBank",
    "16839": "Financo",
    "17510": "Créatis",
    "17789": "Deutsche Bank",
    "18059": "HSBC",
    "18129": "CACEIS Bank",
    "18359": "Bpifrance",
    "18370": "Orange Bank",
    "18829": "Arkéa Banque Entreprises et Institutionnels",
    "18869": "Banque Française Mutualiste",
    "19870": "Carrefour Banque",
    "20041": "La Banque Postale",
    "22040": "Crédit Mutuel",
    "24599": "Milleis Banque",
    "30001": "Banque de France",
    "30002": "LCL",
    "30003": "Société Générale",
    "30004": "BNP Paribas",
    "30006": "Crédit Agricole",
    "30007": "Natixis",
    "30027": "CIC",
    "30047": "CIC",
    "30056": "HSBC",
    "30066": "CIC",
    "30076": "Crédit du Nord",
    "30087": "CIC",
    "30438": "ING",
    "30568": "Banque Transatlantique",
    "30588": "Barclays",
    "30758": "UBS",
    "30788": "Neuflize OBC",
    "31489": "Crédit Agricole CIB",
    "39996": "Crédit Agricole",
    "40031": "Caisse des Dépôts",
    "40618": "Boursorama",
    "40978": "Banque Palatine",
    "41189": "BBVA",
    "41539": "CA Consumer Finance",
    "42529": "Edmond de Rothschild",
    "42559": "Crédit Coopératif",
    "42799": "My Money Bank",
    "43199": "Crédit Foncier",
    "43799": "CA Indosuez",
    "44319": "Louvre Banque Privée",
    "44729": "Banco Santander",
    "45129": "Agence Française de Développement",
    "45850": "Oddo BHF",
    # Banque Populaire — the network's regional banks, whose codes end in 07.
    "10207": "Banque Populaire",
    "10807": "Banque Populaire",
    "10907": "Banque Populaire",
    "11307": "Banque Populaire",
    "13507": "Banque Populaire",
    "13807": "Banque Populaire",
    "14607": "Banque Populaire",
    "14707": "Banque Populaire",
    "16607": "Banque Populaire",
    "16807": "Banque Populaire",
    "17807": "Banque Populaire",
    "18707": "Banque Populaire",
    # Caisse d'Épargne — the network's regional banks.
    "11315": "Caisse d'Épargne",
    "11425": "Caisse d'Épargne",
    "12135": "Caisse d'Épargne",
    "13135": "Caisse d'Épargne",
    "13335": "Caisse d'Épargne",
    "13485": "Caisse d'Épargne",
    "13825": "Caisse d'Épargne",
    "14265": "Caisse d'Épargne",
    "14445": "Caisse d'Épargne",
    "14505": "Caisse d'Épargne",
    "15135": "Caisse d'Épargne",
    "16275": "Caisse d'Épargne",
    "17515": "Caisse d'Épargne",
    "18315": "Caisse d'Épargne",
    "18715": "Caisse d'Épargne",
}

CREDIT_AGRICOLE = "Crédit Agricole"


def normalize_bank_code(raw: str) -> str | None:
    """The 5-digit bank code inside [raw], or `None` when there isn't one.

    `BANKID` is not reliably just the bank code: banks emit it as the bank code
    alone, as bank code + branch code, or as a whole RIB, sometimes spaced. The
    bank code is always the leading five digits, so that is what we take.
    """
    digits = "".join(char for char in raw if char.isdigit())
    return digits[:5] if len(digits) >= 5 else None


def resolve_bank_name(raw_code: str) -> str | None:
    """The bank a French bank code belongs to, or `None` when we can't tell.

    Falls back to one network rule after the exact table misses: the ~39
    regional banks of the Crédit Agricole all carry a 1xxxx code ending in 06
    (13306 Alpes Provence, 18206 Île-de-France, 16806 Nord de France…). Listing
    them one by one would go stale as they merge; the pattern does not.
    """
    code = normalize_bank_code(raw_code)
    if code is None:
        return None

    known = FRENCH_BANK_CODES.get(code)
    if known is not None:
        return known

    if code.startswith("1") and code.endswith("06"):
        return CREDIT_AGRICOLE

    return None
