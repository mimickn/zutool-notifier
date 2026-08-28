# 技術アーキテクチャ

## 全体構成

- 本プロジェクトは、以下のコンポーネントで構成される最小限のバッチアーキテクチャとする。
  - Cloud Scheduler
  - Cloud Run Jobs（TypeScriptバッチを含むDockerコンテナ）
  - Secret Manager
  - 外部API: 頭痛ーるAPI, Slack Incoming Webhook（初期リリース）, LINE Messaging API（将来拡張）

## コンポーネント概要

### Cloud Scheduler

- 役割:
  - 毎日 7:00（Asia/Tokyo）に Cloud Run Job を起動する。
- 主な設定項目:
  - スケジュール: `0 7 * * *`（JST想定）
  - ターゲット: Cloud Run Jobs 実行エンドポイント
  - リトライ: 初期構成では無効とし、失敗時は手動で再実行する。

### Cloud Run Jobs

- 役割:
  - 指定されたDockerイメージを用いて、TypeScript製バッチアプリケーションを単発実行する。
- 主な設定項目:
  - コンテナイメージ: 本リポジトリからビルドされたイメージ
  - タスク数: 1
  - タイムアウト: 5分程度（通常は数十秒以内に終了）
  - サービスアカウント: Secret Manager 読み取り権限のみ付与した専用アカウント
  - 環境変数 / シークレットマッピング: docs/spec.md で定義した値を設定

### Secret Manager

- 役割:
  - 通知先サービスに関するシークレット（Slack Webhook URL / LINEチャネルアクセストークンなど）を安全に保存する。
- 想定するシークレット:
  - SLACK_WEBHOOK_URL（初期リリースで利用）
  - LINE_CHANNEL_ACCESS_TOKEN（LINE構成で利用）

## TypeScript バッチアプリケーション構造（論理）

### 概要

- Node.js (LTS) 上で動作する単発バッチ。
- エントリポイントで `main()` を実行し、エラー発生時には非0の終了コードを設定する。

### 想定ディレクトリ構成（論理）

- src/
  - index.ts（エントリポイント）
  - config/
    - env.ts: 環境変数/シークレットの読み込みと検証
  - services/
    - zutoolClient.ts: 頭痛ーるAPIクライアント
    - slackClient.ts: Slack Incoming Webhook クライアント
    - lineClient.ts: LINE Messaging APIクライアント（将来拡張）
  - domain/
    - pressureNotification.ts: 気圧データから通知要否を判定するドメインロジック
  - utils/
    - logger.ts: ログ出力ユーティリティ

### 処理フロー

1. プロセス起動
   - Cloud Run Job によりコンテナが起動し、Node.js プロセスが `src/index.js` を実行する。
2. 設定・シークレットの読み込み
   - `config/env.ts` で、環境変数から以下を読み込む。
     - ZUTOOL_PLACE_ID
     - PRESSURE_LEVEL_THRESHOLD（未設定時は3にフォールバック）
     - LINE_USER_ID（LINE構成で利用）
     - SLACK_WEBHOOK_URL（Slack構成で利用）
     - LINE_CHANNEL_ACCESS_TOKEN（LINE構成で利用、Secret Manager 経由で環境変数に注入されている想定）
3. 頭痛ーるAPIからのデータ取得
  - `services/zutoolClient.ts` で GET リクエストを行い、指定地点の当日データ（today配列）を取得する。
   - 取得結果をドメイン層に渡せる形（地点名、時間帯ごとの pressure_level 等）に変換する。
4. 通知要否の判定
   - `domain/pressureNotification.ts` で、当日0〜23時の `pressure_level` を走査する。
   - `PRESSURE_LEVEL_THRESHOLD` 以上の時間帯が1つでもあれば「通知すべき」と判断する。
5. 通知送信
   - 「通知すべき」の場合のみ、設定された通知先に対してメッセージ送信を行う。
     - Slack 関連の設定（`SLACK_WEBHOOK_URL`）が有効な場合は、`services/slackClient.ts` を用いて Slack Incoming Webhook に POST する。
     - LINE 関連の設定（`LINE_USER_ID` および `LINE_CHANNEL_ACCESS_TOKEN`）が有効な場合は、`services/lineClient.ts` を用いてプッシュメッセージAPIを呼び出す。
     - 両方の設定が有効な場合は、Slack と LINE の両方へ同一内容の通知を送信する。
   - 成功時はログを出力し、処理を続行。
   - 失敗時はエラーをログ出力し、プロセスをエラー終了とする。
6. 正常終了
   - 通知が不要または通知が成功した場合、プロセスを終了コード0で終了する。

## 設定・シークレットの扱い

### 環境変数

- Cloud Run Jobs の設定画面で、docs/spec.md に定義した環境変数を設定する。
- 値の種類:
  - 構成値（地点ID、しきい値、ユーザーIDなど）
  - 動作モードやログレベル（必要になったら追加）

### シークレット

- Secret Manager に保存されたシークレットを、Cloud Run Jobs の設定で環境変数にマッピングする。
- 初期リリースで利用する主なシークレット:
  - `SLACK_WEBHOOK_URL`: Slack Incoming Webhook の URL。
- LINE 構成で利用するシークレット:
  - `LINE_CHANNEL_ACCESS_TOKEN`: LINE Messaging API のチャネルアクセストークン。

## エラーハンドリング・リトライ

- アプリケーション内リトライ:
  - 頭痛ーるAPIおよび通知API（Slack/LINE）呼び出し時に、一時的なエラー（タイムアウト/5xxなど）の場合には数回の簡易リトライを行うことを検討する。
  - 初期実装では、必要最低限の簡単なバックオフ（例: 最大3回、固定待機）を想定。
- Cloud Scheduler/Cloud Run Jobs のリトライ:
  - 初期構成では、重複通知を避けるためにリトライ設定は無効とする。
  - 安定運用後に必要であれば、冪等性ロジック（同一日付の重複通知抑止）を追加した上で、プラットフォーム側のリトライを有効化する。

## セキュリティと権限

- サービスアカウント:
  - 本バッチ専用のサービスアカウントを作成し、以下の権限のみを付与する。
    - Secret Manager のシークレット参照権限（`roles/secretmanager.secretAccessor`）
  - 他のGCPリソースへの不要な権限は付与しない。
- シークレット管理:
  - チャネルアクセストークンなどの機密情報をソースコードや Git に含めない。

## 今後のアーキテクチャ拡張の余地

- データストアの導入（通知履歴やユーザー設定の保存）。
- 複数ユーザー対応に向けたユーザー管理レイヤーの追加。
- WebhookによるインタラクティブなLINEボット機能の追加。
