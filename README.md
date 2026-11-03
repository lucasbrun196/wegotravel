# WeGoTravel

Aplicativo de viagem compartilhada: roteiro, gastos, comprovantes e mural de
fotos em um só lugar. Flutter para Web (Vercel) e Android/iOS a partir da
mesma base de código.

## Rodando localmente

```bash
flutter pub get
flutter run -d chrome
```

Ou usando o servidor de desenvolvimento na porta 5173:

```bash
flutter run -d web-server --web-port 5173
```

## Estrutura

```
lib/
├── app/          Router, tema da aplicação e destinos de navegação
├── core/         Design system, responsividade, formatadores, extensões
├── data/         Models, repositories e services do Firebase
├── features/     Uma pasta por funcionalidade (screens/widgets/controllers)
└── shared/       Widgets reutilizáveis entre features
```

Regra de dependência: `features` usa `shared`, `data` e `core`.
`shared` usa apenas `core`. `core` não depende de ninguém.

## Autenticação e acesso

Entra-se por **e-mail e senha** ou pela **conta Google**, ambos do Firebase
Auth (os dois provedores precisam estar ativados no console) — não há acesso
anônimo nem convidado. Na web o Google abre numa janela pop-up; no Android e
no iOS o próprio `firebase_auth` cuida do fluxo, sem o pacote `google_sign_in`.
Quem entrou só pelo Google não tem senha: a tela de conta esconde "Trocar
senha" e confirma a exclusão pedindo a conta Google de novo.

| Ação | Quem pode |
|---|---|
| Criar viagem | Qualquer pessoa com conta (vira admin dela) |
| Gerenciar roteiro, contas e cotas | Todo participante, sem restrição |
| Ver o mural e postar foto ou vídeo | Todo participante |
| Mudar a legenda de uma foto | Quem postou |
| Excluir foto ou vídeo do mural | Quem postou e o admin |
| Adicionar / remover participantes | Só o admin |
| Excluir a viagem | Só o admin |
| Sair da viagem | Qualquer participante |

Participantes são adicionados **pelo e-mail**, e a pessoa precisa já ter
conta. O SDK cliente do Firebase Auth não permite buscar alguém por
e-mail, então cada conta é espelhada em `users/{uid}` no login — é essa
coleção que a busca consulta.

### Esqueci minha senha

O e-mail de redefinição é o do próprio Firebase, mas o link dele abre uma
tela do app (`/redefinir-senha`), e não a página genérica do Firebase. A tela
confere o link, pede a senha nova e já entra com ela. Duas configurações no
console, em **Authentication → Templates → Redefinição de senha**:

1. **Texto do e-mail.** Editar (lápis), colar o conteúdo de
   `firebase/email_templates/redefinir_senha.html` no campo **Mensagem** e
   usar como assunto `Redefina sua senha do WeGoTravel`. Em **Nome do
   remetente**, `WeGoTravel`. O idioma do modelo fica em Português (Brasil).
2. **URL de ação.** No mesmo modelo, "Personalizar URL de ação" → a **raiz**
   do app, sem caminho nem `#`: `https://seu-app.vercel.app/` (para testar
   local, `http://localhost:5173/`). O Firebase acrescenta
   `?mode=resetPassword&oobCode=...`, e o app lê isso ao abrir
   (`AuthActionLink`).

A URL de ação vale para todos os modelos. Links de outros tipos (confirmar
ou desfazer troca de e-mail) seguem para a página padrão do Firebase.

## Firebase

Os arquivos de configuração ficam em `firebase/`:

| Arquivo | Conteúdo |
|---|---|
| `firestore.rules` | Regras de acesso ao banco, baseadas em participação na viagem |
| `firestore.indexes.json` | Índices compostos necessários para as queries |
| `storage.rules` | Regras de arquivos: participação na viagem, tipo e tamanho |

Publicar as regras:

```bash
firebase deploy --only firestore:rules,firestore:indexes,storage
```

As regras do Storage consultam o documento da viagem no Firestore para saber
quem participa dela (regra entre serviços). No primeiro deploy delas o CLI
pergunta se pode dar ao Storage acesso de leitura ao Firestore: é preciso
aceitar. Sem essa permissão, nenhum arquivo de viagem abre.

### CORS do Storage

Na Web, o Flutter baixa as imagens por XHR, e o navegador só entrega a resposta
se o bucket disser que aceita outro domínio. Sem essa configuração o envio
funciona, o link sai, e a foto aparece como quadro quebrado, com
`No 'Access-Control-Allow-Origin' header` no console. O mesmo vale para
exportar (compartilhar e baixar). A configuração está em
`firebase/storage.cors.json` e não passa pelo `firebase deploy`: aplique uma
vez pelo Cloud Shell do console do Google Cloud (ou com o Google Cloud CLI
instalado):

```bash
gcloud storage buckets update gs://SEU-BUCKET --cors-file=firebase/storage.cors.json
```

A origem fica aberta (`*`) só para leitura, e isso não expõe nada: o CORS não é
a fechadura. O que protege o arquivo é o token do link, que só sai para quem
passa pelas regras do Storage.

### Gerar as credenciais

```bash
flutterfire configure
```

Isso cria `lib/firebase_options.dart`, `android/app/google-services.json`
e `ios/Runner/GoogleService-Info.plist`. **Os três estão no `.gitignore`** —
cada pessoa gera os seus apontando para o próprio projeto Firebase. Há um
modelo em `lib/firebase_options.dart.example` para quem preferir preencher
à mão.

Essas chaves identificam o app, não autorizam nada sozinhas: a proteção
real são as Security Rules em `firebase/`.

## Mural

As fotos e os vídeos da viagem, de todo mundo, separados pelo dia em que foram
feitos: "Dia 3", com os lugares que o roteiro tinha para aquele dia. A data
sai do EXIF da foto (`lib/core/utils/exif_date.dart`); sem EXIF, da data do
arquivo. Assim quem posta tudo na volta não joga a viagem inteira num dia só.

| Para | Como |
|---|---|
| Postar | **Importar** abre o seletor do aparelho: marque várias de uma vez ou uma só. Antes de postar, uma revisão deixa tirar arquivo, pôr mais e escrever legenda em cada |
| Tirar na hora | **Câmera** abre a câmera dentro do app (a do celular ou a webcam). Dá para tirar várias seguidas e postar todas juntas |
| Arrastar | No computador, arraste os arquivos para a janela do Mural |
| Ver | Toque na foto: tela cheia, deslizar para os lados, pinça e duplo toque para zoom, arrastar para baixo para fechar. No teclado, setas e Esc |
| Rever | O botão de apresentação passa as fotos sozinho, cinco segundos cada; o vídeo toca até o fim |
| Exportar | **Compartilhar** abre a folha do sistema: WhatsApp, Instagram, e-mail e, no iPhone, "Salvar imagem". **Baixar** guarda o arquivo original; no app de celular, vai direto para a galeria. **Selecionar** faz tudo isso com várias de uma vez |

Cada post sobe três arquivos: o original (até 150 MB), que é o que se exporta,
e duas versões em JPEG feitas no aparelho de quem postou: a miniatura da grade
e a de tela cheia. Na Web quem reduz é o próprio navegador
(`createImageBitmap` e canvas); o vídeo ganha uma capa tirada de um quadro do
começo. O upload sai direto do arquivo do navegador, sem passar pela memória
do Dart.

### Quem vê as fotos

Só quem participa da viagem, conferido em dois lugares:

- **Firestore**: o post (`trips/{tripId}/posts/{postId}`) só é lido por
  participante, e só pode apontar para arquivos da pasta dele.
- **Storage**: cada arquivo sob `trips/{tripId}` só é lido, enviado ou apagado
  por quem está na lista `memberIds` da viagem. Quem sai da viagem perde o
  acesso aos arquivos no mesmo instante.

O post guarda o **caminho** do arquivo, nunca o link de download. O link do
Firebase carrega um token que abre o arquivo para qualquer pessoa que o tiver,
sem passar pelas regras; por isso ele é pedido na hora, só vive na sessão, e
só sai para quem o Storage reconhece. O limite é o de sempre: alguém da viagem
pode compartilhar a foto, e é para isso que o botão existe.

## Mapa

Cada atividade do roteiro pode ter um ponto marcado no mapa. A coordenada
(`lat`/`lng`) fica **só no banco** — é ela que alimenta a previsão do tempo,
que precisa de posição exata e não de nome. Na tela aparece sempre o nome do
lugar: "Praia da Joaquina", "Rua Bocaiúva".

| Peça | Serviço | Plano gratuito |
|---|---|---|
| Tiles do mapa | Mapbox Raster Tiles | 750 mil requisições/mês |
| Nome ⇄ coordenada | Nominatim (OpenStreetMap) | grátis, 1 requisição/s |
| Previsão do tempo | [Open-Meteo](https://open-meteo.com) | grátis, sem chave |

### Previsão do tempo

O card da atividade ganha um chip com a máxima, a mínima e o ícone da
condição do dia. **Tocar no chip abre o painel do dia**: se vai chover e com
que chance, quanto deve cair em milímetros, sensação térmica, vento, índice
UV, nascer e pôr do sol, e a curva hora a hora — com a hora da atividade
destacada, quando ela tem horário marcado.

O chip só aparece quando as duas coisas valem:

- a atividade tem um **lugar fixado no mapa** (sem coordenada não há o que
  consultar);
- falta **no máximo uma semana** para a viagem começar, e ela ainda não
  acabou. Antes disso a previsão é chute, e um número na tela vira promessa.

A Open-Meteo não pede chave nem cadastro: nada entra no `--dart-define`. Ela
cobre 16 dias à frente, então dias mais distantes de uma viagem longa ficam
sem chip até chegarem à janela. Falha de rede não mostra erro — o chip
simplesmente não aparece. Dados de previsão por Open-Meteo.eu (CC BY 4.0).

A geocodificação **não** é a do Mapbox de propósito: o plano gratuito de lá é o
*temporary geocoding*, cujos termos não permitem guardar o resultado — e aqui o
nome do lugar é gravado no Firestore.

### Token do Mapbox

1. Criar conta em <https://account.mapbox.com> e copiar o **token público**
   (começa com `pk.`). A conta gratuita não pede cartão.
2. Rodar passando o token:

```bash
flutter run -d web-server --web-port 5173 --dart-define=MAPBOX_TOKEN=pk.SEU_TOKEN
```

3. Recomendado: em <https://account.mapbox.com/access-tokens>, restringir o
   token por **URL** (`localhost:5173` e o domínio da Vercel). O token vai
   dentro do bundle web — ele é público por natureza, e a restrição de URL é a
   proteção de verdade.

Na Vercel, criar a variável de ambiente `MAPBOX_TOKEN` e trocar o
`buildCommand` do `vercel.json` para:

```
flutter/bin/flutter build web --release --dart-define=MAPBOX_TOKEN=$MAPBOX_TOKEN
```

Sem token nada quebra: o botão "Escolher no mapa" fica desabilitado explicando
o que falta, e os campos "Lugar" e "Endereço" seguem sendo digitados à mão.

## Funcionar sem rede

Viagem é justamente onde o 4G falha, então o app abre e continua útil offline.
São duas peças independentes:

| Peça | O que guarda | Onde |
|---|---|---|
| `web/sw.js` | A casca: HTML, bundle, fontes, ícones | Cache do navegador |
| Cache do Firestore | O dado: viagens, roteiro, contas, cotas | IndexedDB / disco |

Sem a primeira o app nem abre; sem a segunda ele abre vazio. Offline dá para
ler tudo que já tinha sido carregado e **continuar lançando gasto e editando o
roteiro** — as escritas ficam na fila e sobem sozinhas quando a rede volta.

Uma faixa no topo diz em qual dos dois estados você está: "Sem conexão —
mostrando o que já estava salvo" ou "Enviando as alterações…". Ela só aparece
depois de três segundos sem resposta do servidor, porque o primeiro dado que o
Firestore entrega vem do cache mesmo quando há rede — avisar na hora faria a
faixa piscar em toda abertura.

O que **não** funciona offline: entrar pela primeira vez (o Firebase Auth
precisa da rede — uma sessão já aberta continua valendo), o mapa, a previsão do
tempo, enviar comprovante e o mural. As fotos não abrem sem rede de propósito:
o link de cada uma é pedido ao Storage na hora, para ele conferir quem está
pedindo (ver "Mural").

### Por que um service worker à mão

Desde o Flutter 3.41 o `flutter_service_worker.js` gerado pelo build é um
worker que **se desregistra** ao ativar — a estratégia `offline-first` do
Flutter foi depreciada e não guarda mais nada. Por isso o build roda com
`--pwa-strategy=none` e o registro aponta para o nosso `web/sw.js`: dois
workers no mesmo escopo são um registro só, e o do Flutter apagaria o nosso.

O cache nunca fica na frente de um deploy: a rede tem sempre a primeira
palavra, e o cache responde quando ela falha.

### Testar o offline

O service worker não é registrado no `localhost` — em desenvolvimento ele
serviria código velho a cada edição. Para exercitá-lo, sirva o build de release
por um nome qualquer de host:

```bash
flutter build web --release --pwa-strategy=none --dart-define=MAPBOX_TOKEN=pk.SEU_TOKEN
python3 -m http.server 8787 --directory build/web
```

Abra <http://app.localhost:8787>, carregue uma vez, **desligue o servidor** e
recarregue: o app precisa abrir igual. A configuração `web-release` em
`.claude/launch.json` faz os dois passos.

## Deploy na Vercel

O build roda por `scripts/vercel_build.sh`, que baixa o Flutter, gera as
credenciais a partir das variáveis de ambiente e compila `build/web`. O
`vercel.json` já aponta para ele.

### 1. Variáveis de ambiente do projeto na Vercel

| Variável | Onde achar |
|---|---|
| `MAPBOX_TOKEN` | <https://account.mapbox.com/access-tokens> (token público, `pk.`) |
| `FIREBASE_API_KEY` | Console do Firebase → ⚙ → Configurações do projeto → Seus apps → Web |
| `FIREBASE_APP_ID` | idem |
| `FIREBASE_MESSAGING_SENDER_ID` | idem |
| `FIREBASE_PROJECT_ID` | idem |
| `FIREBASE_AUTH_DOMAIN` | idem |
| `FIREBASE_STORAGE_BUCKET` | idem |

Os mesmos valores estão no `lib/firebase_options.dart` local. Para listar:

```bash
sed -n '/static const FirebaseOptions web/,/);/p' lib/firebase_options.dart
```

`lib/firebase_options.dart` continua fora do git: na Vercel ele é **gerado no
build**, só com o bloco web.

### 2. Autorizar o domínio no Firebase Auth

Console do Firebase → **Authentication** → **Settings** → **Domínios
autorizados** → adicionar o domínio da Vercel (`seu-app.vercel.app` e o
domínio próprio, se houver).

Sem isso o login falha com `auth/unauthorized-domain` — e o app parece quebrado
sem dizer o porquê.

### 3. Restringir o token do Mapbox

Em <https://account.mapbox.com/access-tokens>, limitar o token às URLs
`http://localhost:5173` e ao domínio da Vercel. O token vai dentro do bundle:
a restrição por URL é a proteção de verdade.

### 4. Deploy

```bash
vercel --prod
```

Ou conectar o repositório no painel da Vercel — o `vercel.json` cuida do resto.
O primeiro build demora uns minutos porque baixa o SDK do Flutter.

### Build local igual ao da Vercel

```bash
flutter build web --release --dart-define=MAPBOX_TOKEN=pk.SEU_TOKEN
```

O `flutter run` na web usa o compilador de debug e é **muito** mais lento que o
release — não julgue o desempenho do app por ele.

## Correção temporária de dependência

`third_party/firebase_core_web` é uma cópia local com um patch de duas
linhas — veja `third_party/firebase_core_web/PATCH.md`. Deve ser removida
quando o FlutterFire publicar uma versão compatível com o Dart 3.11.

## Modelo de contas

Uma **conta** (`bills`) cobre os dois comportamentos reais de uma viagem:

| Tipo | Comportamento | Exemplo |
|---|---|---|
| `fixed` | Total conhecido, pode ser parcelada | Aluguel do Airbnb em 6x |
| `accumulating` | Soma lançamentos, divide no fechamento | Gasolina |

Cada conta gera **cotas** (`shares`): uma por pessoa por parcela. É a
unidade que carrega valor, vencimento, marcação de pago e comprovante
do PIX. Ids determinísticos (`parcela_pessoa`) preservam os pagamentos
quando a conta é editada.

Valores são guardados em **centavos inteiros**. `double` acumula erro em
divisões e conta entre amigos precisa fechar no centavo — ver
`lib/core/utils/money.dart` e os testes em `test/bill_split_test.dart`.

## Etapas

- [x] **1** — Estrutura base, design system, navegação responsiva
- [x] **2** — Firebase conectado, autenticação, multi-viagem, participantes
- [x] **3** — Roteiro (timeline por dia, transporte, vínculo com contas)
- [x] **4** — Contas compartilhadas (parcelamento, divisão, cotas, pagamentos)
- [x] **5** — Comprovantes (upload, visualização, exclusão)
- [x] **6** — Mural (fotos e vídeos, câmera, exportação)
- [ ] **7** — Dashboard completo, polimento e PWA (offline e service worker prontos)
- [ ] **8** — Deploy na Vercel
- [ ] **9** — Android (APK) e iOS
