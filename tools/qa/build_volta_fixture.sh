#!/bin/bash
# Grave tools/qa/fixtures/volta_score.ly avec LilyPond et copie le PDF dans
# build/qa/volta_score.pdf. Fixture OMR réaliste (docs/18), vérité terrain :
# tools/qa/fixtures/volta_ground_truth.json.
set -e
cd "$(dirname "$0")/../.."
mkdir -p build/qa
# Chemin absolu pour l'entrée : LilyPond change de répertoire courant vers le
# répertoire de sortie, ce qui casse les chemins relatifs.
lilypond -o "build/qa/volta_score" "$(pwd)/tools/qa/fixtures/volta_score.ly"
echo "PDF généré : build/qa/volta_score.pdf"
