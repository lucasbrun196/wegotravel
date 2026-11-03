'use strict';

// Service worker do app — escrito à mão, de propósito.
//
// O `flutter_service_worker.js` que o build gera desde o Flutter 3.41 é
// um worker que **se desregistra** ao ativar: a estratégia
// `offline-first` do Flutter foi depreciada e não guarda mais recurso
// nenhum. Sem este arquivo o app simplesmente não abre sem rede.
//
// Por isso o build roda com `--pwa-strategy=none`: dois workers no
// mesmo escopo são um só registro, e o do Flutter apagaria este.
//
// A estratégia aqui é conservadora: a rede sempre tem a primeira
// palavra, e o cache responde quando ela falha. Assim um deploy novo
// nunca fica preso atrás de cache velho.

const VERSION = 'v1';
const SHELL = `viagem-casca-${VERSION}`;
const ASSETS = `viagem-recursos-${VERSION}`;
const CURRENT = [SHELL, ASSETS];

/// A casca é sempre guardada nesta chave: a Vercel reescreve qualquer
/// rota para o index.html, então um link fundo offline abre o mesmo
/// arquivo e o go_router resolve o caminho.
const INDEX = './';

/// O básico para a primeira tela existir sem rede. O resto (canvaskit,
/// fontes, ícones) entra sozinho na primeira visita, conforme é pedido.
/// `allSettled` porque um arquivo a menos não pode impedir a instalação.
const PRECACHE = [
  INDEX,
  'flutter_bootstrap.js',
  'flutter.js',
  'main.dart.js',
  'manifest.json',
  'favicon.svg',
  'favicon.png',
  'icons/Icon-192.png',
];

/// Fontes do Google: outro domínio, mas parte da identidade do app.
/// Sem elas offline a tipografia cai para a fonte do sistema.
const FONT_HOSTS = new Set(['fonts.googleapis.com', 'fonts.gstatic.com']);

self.addEventListener('install', (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(SHELL);
      await Promise.allSettled(PRECACHE.map((path) => cache.add(path)));
      await self.skipWaiting();
    })()
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    (async () => {
      const names = await caches.keys();
      await Promise.all(
        names
          .filter((name) => name.startsWith('viagem-') && !CURRENT.includes(name))
          .map((name) => caches.delete(name))
      );
      await self.clients.claim();
    })()
  );
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;

  const url = new URL(request.url);
  const mine = url.origin === self.location.origin || FONT_HOSTS.has(url.host);

  // Firestore, Auth, Storage, Mapbox e Open-Meteo passam direto: o
  // Firestore tem o cache dele, e guardar resposta de API aqui faria o
  // app mostrar dado velho sem nenhum controle.
  if (!mine) return;

  if (request.mode === 'navigate') {
    event.respondWith(shellFirst(event));
    return;
  }

  event.respondWith(cacheThenNetwork(event));
});

/// Abrir o app: tenta a rede e guarda a casca; sem rede, serve a última
/// que funcionou.
async function shellFirst(event) {
  const cache = await caches.open(SHELL);

  try {
    const response = await fetch(event.request);
    if (response.ok) {
      cache.put(INDEX, response.clone());
    }
    return response;
  } catch (_) {
    const cached = await cache.match(INDEX);
    return cached ?? Response.error();
  }
}

/// Recursos: responde com o cache na hora e atualiza por trás. Abrir o
/// app offline precisa ser instantâneo, e um bundle de release não muda
/// no meio da sessão.
async function cacheThenNetwork(event) {
  const cache = await caches.open(ASSETS);
  const cached = await cache.match(event.request);

  const fromNetwork = fetch(event.request)
    .then((response) => {
      if (storable(response)) {
        cache.put(event.request, response.clone());
      }
      return response;
    })
    .catch(() => null);

  if (cached) {
    // Sem isto o navegador pode encerrar o worker assim que a resposta
    // sai, e a revalidação nunca termina.
    event.waitUntil(fromNetwork);
    return cached;
  }

  const response = await fromNetwork;
  return response ?? Response.error();
}

function storable(response) {
  if (!response) return false;

  // Resposta opaca (fonte de outro domínio) não deixa ler status nem
  // cabeçalho: é guardar às cegas ou não guardar. Fonte é imutável, e
  // vale a pena.
  if (response.type === 'opaque') return true;
  if (!response.ok) return false;

  // A Vercel reescreve toda rota desconhecida para o index.html, então
  // um recurso que sumiu volta como HTML com status 200. Guardar isso
  // envenenaria o cache com a página no lugar do script.
  const type = response.headers.get('content-type') ?? '';
  return !type.includes('text/html');
}
