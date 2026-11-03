# phpMatsuri Reboot 2026 ハンズオン 環境構築方針

対象セッション: 「モダンLaravelを体験しよう！ — いつからLaravelがサーバサイドフレームワークだと錯覚していた？」（武田 憲太郎さん）
日時: 2026/11/07（土）13:00〜 ／ わいわいエリア（ワークショップ）
出典: https://fortee.jp/phpmatsuri-reboot-2026/proposal/1bb88df0-8fb7-42df-b8ed-f49fdae75b58

改訂: 2026/11/03 v3（構築完了。テストは PHPUnit、Docker 固有設定の実績を反映）

## 1. ハンズオンで扱う内容（=環境に必要なもの）

| テーマ | 使う技術 | 環境として必要なもの |
| --- | --- | --- |
| モダンフロントエンド | Inertia.js + Wayfinder（APIレス＆型安全SPA） | PHP / Composer / Node.js + npm（Vite・TypeScript） |
| AI統合 | Laravel AI SDK（`laravel/ai`） | PHP 8.3以上 / Anthropic API キー |
| デプロイ（時間があれば） | Laravel Cloud | Laravel Cloud アカウント / GitHub（`mt-satak`） |

※ ページ上に事前準備や推奨バージョンの記載はありません。以下は公開情報から判断したものです。

## 2. 採用バージョン（2026/11/03 時点の最新パッチ）

PHP と Laravel には LTS がないため「最新の安定版の最新パッチ」、MySQL と Node.js は「LTS 系列の最新パッチ」を採用します。
すべて **パッチバージョンまでイメージタグ／パッケージで固定**します（`latest` や `9.7` のような浮動タグは使わない）。

| ソフトウェア | 採用バージョン | リリース日 | 確認元 |
| --- | --- | --- | --- |
| PHP | **8.5.12** | 2026/10/21 | php.net releases API / Docker Hub `php:8.5.12-cli-trixie` |
| MySQL | **9.7.4**（LTS） | 2026/10/28 | Docker Hub `mysql:9.7.4` |
| Node.js | **26.13.0**（LTS "Lithium"） | 2026/10/28 | nodejs.org dist index（LTS 移行リリース。直前の 26.12.1 のセキュリティ修正を含む） |
| Composer | **2.11.1** | — | getcomposer.org/versions（stable） |
| Laravel Framework | **13.39.0** | 2026/10/27 | Packagist `laravel/framework` |
| Laravel AI SDK | **1.3.0** | 2026/10/19 | Packagist `laravel/ai` |

補足:
- PHP 8.6 は RC 段階（GA 予定 2026/11/19）のため使いません。Laravel 13 の対応 PHP は 8.3〜8.5 です。
- 当日までに新しいパッチが出た場合は、タグを書き換えて再ビルドするだけで更新できます。

## 3. 構成方針：すべて Docker（Sail は使わない）

Laravel Sail は使わず、**自前の `Dockerfile` + `compose.yaml`** で PHP・Node・MySQL をすべてコンテナで動かします。
Mac 側に必要なのは Docker（Rancher Desktop、導入済み）とエディタだけです。

```
Mac (host)  ─ ソースコードは bind mount で共有（エディタは Mac 側で編集）
└─ Docker (Rancher Desktop)
   ├─ app   : PHP 8.5.12 + Composer 2.11.1 + Node.js 26.13.0
   │          php artisan serve → http://localhost:8000
   │          Vite dev server   → http://localhost:5173 (HMR)
   └─ mysql : MySQL 9.7.4      → localhost:3306（名前付きボリュームで永続化）
```

### なぜ PHP と Node を同じ `app` コンテナに入れるのか

- **Wayfinder の Vite プラグインはビルド時に `php artisan wayfinder:generate` を実行**します。Node と PHP が別コンテナだと、Vite から PHP を呼べず型生成が失敗します。
- Laravel 公式の `composer run dev` は、サーバ・キュー・ログ・Vite を 1 コマンドで同時起動する前提です。1 コンテナにまとめると、講師の手順と同じコマンドで操作できます。

### Sail を使わない理由／自前構成のメリット

- バージョンをパッチ単位で明示的に固定できます。Sail はランタイムを Ubuntu + ppa から入れるため、パッチ版を固定しにくいです。
- 構成ファイル 2 つだけなので、中身を把握しやすいです。
- コマンドは `docker compose exec app php artisan ...` の形になります。長いので Makefile かシェルエイリアスで短縮します（例: `make artisan c=migrate`）。

### `app` イメージの作り方

- ベース: `php:8.5.12-cli-trixie`（Debian 13）
- PHP 拡張: `pdo_mysql` `intl` `zip` `bcmath` `pcntl`（`mbstring` 等はベースに同梱）
- Composer: 公式イメージ `composer:2.11.1` から `COPY --from` でバイナリだけ取り込みます
- Node.js: 公式イメージ `node:26.13.0-trixie-slim` から `COPY --from` で取り込みます
- 実行ユーザー: 非 root ユーザーで実行し、生成ファイルの所有者問題を避けます

### Docker 特有の設定

- `php artisan serve`: compose.yaml の環境変数 `SERVER_HOST=0.0.0.0` で、Mac から接続できるようにしています。Laravel 13 の `composer run dev`（＝`php artisan dev`）は `serve` に引数を渡せないため、環境変数で指定します。
- Vite（`src/vite.config.ts`）: `server.host = '0.0.0.0'`、`origin` と `hmr.host` は `localhost` です。ブラウザが Mac 側の localhost:5173 に接続するようにするためです。
- Vite のファイル監視は **ポーリング（`usePolling: true`）** です。Rancher Desktop（vz + virtiofs）では、Mac 側でファイルを変更しても inotify がコンテナに届かないことを確認したためです。
- `.env`: `DB_HOST=mysql`（コンテナ名）、`DB_PORT=3306`
- `vendor/` と `node_modules/` は bind mount 上に置きます。エディタの補完を効かせるためです。

## 4. 構築手順（2026/11/03 実施済み）

作業ディレクトリ: `/Users/satak/dev/phpmatsuri`

1. **Docker 構成ファイル作成**: `Dockerfile` / `compose.yaml` / `Makefile`
2. **イメージビルド**: `docker compose build`
3. **Laravel プロジェクト作成（コンテナ内）**
   `laravel new app --react --database=mysql --phpunit --no-node --no-boost` をコンテナ内の `/tmp` で実行し、`src/` にコピーしました。
   ※ インストーラは `.` を指定すると「すでに存在する」エラーになり、`--force` と `.` の併用もできないためです。
   ※ テストフレームワークは **PHPUnit**（12.5）です。
4. **`.env` を MySQL 向けに変更** → `php artisan migrate`
5. **Vite 設定を Docker 向けに調整**（§3 の host/HMR 設定）
6. **起動**: `make up` → `make dev`（コンテナ内で `composer run dev`。serve / queue / pail / Vite を同時に起動）
7. **Laravel AI SDK 導入（実施済み・API キー未設定）**
   - `composer require laravel/ai:^1.3`（v1.3.0）→ `php artisan vendor:publish --provider="Laravel\Ai\AiServiceProvider"` → `php artisan migrate`（`agent_conversations` / `agent_conversation_messages`）
   - `src/config/ai.php`: 既定プロバイダを `anthropic` に変更。モデルは `.env` の `ANTHROPIC_MODEL` 等で差し替え可能（未設定時はパッケージ既定の `claude-sonnet-5-5`）
   - `src/.env` に `ANTHROPIC_API_KEY=` の空行を用意。キーはご自身で入力（`src/.gitignore` で除外済み）
   - 疎通確認: `make ai-check`（キー未設定時に Anthropic から 401 が返ることまで確認済み）
8. **動作確認**
   - 各バージョン確認: `php -v` / `php artisan --version` / `node -v` / `composer -V` / `SELECT VERSION();`
   - http://localhost:8000 でユーザー登録 → MySQL にレコードが入ること
   - React 画面の編集が HMR で即時反映されること
   - Wayfinder の型ファイルが `resources/js/` 配下に自動生成されること
   - 結果: すべて確認済み。PHPUnit 40件成功、HTTP 経由のユーザー登録で MySQL に保存、Mac 側の編集で HMR の更新通知を受信
9. **GitHub リポジトリ化（実施済み）**: https://github.com/mt-satak/phpmatsuri-2026-handson （Public）。Laravel Cloud ではルートディレクトリに `src` を指定してデプロイします。

## 5. 事前にご自身で行うこと

### 5-1. Anthropic API キーの確認・発行

1. https://platform.claude.com （旧 console.anthropic.com。旧 URL からもリダイレクトされます）にログインします。
2. 左メニュー **Settings → API keys** を開きます。
   - 既存キーは名前と先頭数文字（`sk-ant-api03-…`）しか表示されません。**キー本体は作成時に一度しか表示されません。**
   - 手元に値が残っていなければ **Create Key** で新規発行します（名前の例: `phpmatsuri-2026`）。表示された値をパスワードマネージャ等に保存してください。
3. **Settings → Billing** でクレジット残高を確認します。残高 0 だと API 呼び出しがエラーになります。
4. （任意）キーが有効か、ターミナルで確認します:

   ```sh
   curl -s https://api.anthropic.com/v1/models \
     -H "x-api-key: $ANTHROPIC_API_KEY" \
     -H "anthropic-version: 2023-06-01" | head -c 300
   ```

   モデル一覧の JSON が返れば有効です。`authentication_error` が返る場合は、キーが誤っているか無効化されています。
   ※ キーはシェル履歴に残らないよう、`read -s ANTHROPIC_API_KEY && export ANTHROPIC_API_KEY` などで入力してください。

### 5-2. Laravel Cloud アカウント作成（デプロイまで進む場合）

1. https://cloud.laravel.com で **GitHub アカウント（mt-satak）で Sign up** します。
2. GitHub App の連携を許可します。対象リポジトリはハンズオン用のものだけに絞ることを推奨します。
3. 料金プランと支払い情報の要否は、登録画面で確認してください（時期により変わるため、ここでは断定しません）。

### 5-3. 当日の持ち物・前日までの準備

- ノートPC・電源
- 会場 Wi‑Fi が不安定な場合に備え、**イメージのビルド、`composer install`、`npm install` は事前に済ませておきます**。

## 6. 注意点・リスク

- 講師が別の手順（Sail、SQLite のままなど）を指示した場合は、当日それに合わせます。Laravel のデフォルト DB は SQLite なので、`.env` を戻せばすぐ切り替えられます。
- Mac の bind mount はネイティブ実行より I/O が遅いです。Rancher Desktop の VirtioFS を使えば、ハンズオン規模なら実用上問題ありません。
- コンテナには Xdebug を入れません（速度優先）。
- 既存コンテナ `teket-system-manage`（18018 番）とはポートが重複しません。ホスト側の 8000 / 5173 / 3306 番も空いています。
- `.env`（API キー入り）は `.gitignore` 済みであることを push 前に必ず確認します。
