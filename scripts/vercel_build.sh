#!/usr/bin/env bash
# Build da Vercel: instala o Flutter, gera as credenciais a partir das
# variáveis de ambiente e compila o app web.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.47.2}"
FLUTTER_DIR="$HOME/flutter"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "▸ baixando Flutter $FLUTTER_VERSION"
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
flutter --version

# lib/firebase_options.dart não é versionado (ver .gitignore). Na Vercel
# ele é gerado a partir das variáveis de ambiente do projeto.
if [ ! -f lib/firebase_options.dart ]; then
  echo "▸ gerando lib/firebase_options.dart"
  : "${FIREBASE_API_KEY:?falta a variável de ambiente FIREBASE_API_KEY}"
  : "${FIREBASE_APP_ID:?falta a variável de ambiente FIREBASE_APP_ID}"
  : "${FIREBASE_MESSAGING_SENDER_ID:?falta FIREBASE_MESSAGING_SENDER_ID}"
  : "${FIREBASE_PROJECT_ID:?falta a variável de ambiente FIREBASE_PROJECT_ID}"
  : "${FIREBASE_AUTH_DOMAIN:?falta a variável de ambiente FIREBASE_AUTH_DOMAIN}"
  : "${FIREBASE_STORAGE_BUCKET:?falta FIREBASE_STORAGE_BUCKET}"

  cat > lib/firebase_options.dart <<DART
// GERADO NO BUILD a partir das variáveis de ambiente — não versionar.
// A versão local é gerada por \`flutterfire configure\`.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: '$FIREBASE_API_KEY',
    appId: '$FIREBASE_APP_ID',
    messagingSenderId: '$FIREBASE_MESSAGING_SENDER_ID',
    projectId: '$FIREBASE_PROJECT_ID',
    authDomain: '$FIREBASE_AUTH_DOMAIN',
    storageBucket: '$FIREBASE_STORAGE_BUCKET',
  );
}
DART
fi

: "${MAPBOX_TOKEN:?falta a variável de ambiente MAPBOX_TOKEN}"

# --pwa-strategy=none: o service worker é o de web/sw.js. O que o
# Flutter gera desde a 3.41 se desregistra ao ativar, e os dois
# disputariam o mesmo escopo.
flutter build web --release \
  --pwa-strategy=none \
  --dart-define=MAPBOX_TOKEN="$MAPBOX_TOKEN"
