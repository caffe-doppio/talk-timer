#!/usr/bin/env bash
# Échoue si une déclaration de premier niveau de Sources/ ou App/ est absente de docs/GLOSSARY.md.
# ponytail: repère les déclarations en colonne 0 sur une seule ligne ; un attribut à parenthèses
# sur la même ligne (`@available(...) struct X`) passe inaperçu, à traiter s'il apparaît.
set -euo pipefail
cd "$(dirname "$0")/.."

glossary=docs/GLOSSARY.md
modifiers='public|package|internal|fileprivate|private|open|final|nonisolated|@[A-Za-z]+'
kinds='struct|enum|class|actor|protocol|typealias|func|extension|let|var'
missing=0

while read -r kind name; do
    case $kind in
        extension) needle="\`extension $name\`" ;;
        func) needle="\`$name(" ;;
        *) needle="\`$name\`" ;;
    esac
    if ! grep -qF -- "$needle" "$glossary"; then
        echo "absent de $glossary : $kind $name"
        missing=1
    fi
done < <(find Sources App -name '*.swift' -exec sed -nE \
    "s/^(($modifiers) +)*($kinds) +([A-Za-z_][A-Za-z0-9_.]*).*/\3 \4/p" {} +)

exit $missing
