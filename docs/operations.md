# 運用・デプロイガイド

## 前提条件

- GCP プロジェクトが作成済みであること。
- 以下のサービスが有効化されていること。
  - Cloud Run
  - Cloud Scheduler
  - Secret Manager
- LINE 構成を利用する場合:
  - LINE Developers コンソールで、Messaging API 対応のチャネル（公式アカウント）が作成されていること。
  - チャネルアクセストークンを取得済みであること。
- Slack 通知を利用する場合:
  - 通知を送りたいワークスペースにアクセス可能であること。
  - Slack App を作成できる権限があること（Incoming Webhook を使う想定）。

## 初期セットアップ手順（概要）

1. LINE 側の設定
   - LINE Developers コンソールで、以下を実施する。
     - プロバイダの作成（個人利用なら自分用プロバイダでよい）。
     - Messaging API チャネルの作成。
     - Messaging API 設定画面からチャネルアクセストークン（長期）を発行し、後続手順で使用できるよう控えておく。
   - 作成した公式アカウント（Bot）を、自分のLINEから友だち追加しておく。

2. シークレットの登録
   - GCP Secret Manager に、以下のシークレットを登録する。
     - `LINE_CHANNEL_ACCESS_TOKEN`: LINE Messaging API のチャネルアクセストークン

3. Cloud Run Jobs の作成
   - 本リポジトリのソースから Docker イメージをビルドし、Container Registry / Artifact Registry にプッシュする。
   - Cloud Run Jobs を作成し、以下を設定する。
     - 使用イメージ: 上記でプッシュしたイメージ
     - タスク数: 1
     - タイムアウト: 5分程度
     - サービスアカウント: Secret Manager 読み取り権限のみ付与した専用アカウント
     - 環境変数:
       - ZUTOOL_PLACE_ID: 対象地点ID
       - PRESSURE_LEVEL_THRESHOLD: しきい値（未設定可、未設定時は3）
       - LINE_USER_ID: 通知対象ユーザーの userId
     - シークレットのマッピング:
       - Secret Manager の `LINE_CHANNEL_ACCESS_TOKEN` を環境変数として注入

4. Cloud Scheduler の作成
   - 毎日7:00（Asia/Tokyo）に Cloud Run Job を起動する Cloud Scheduler ジョブを作成する。
   - 設定例:
     - スケジュール: `0 7 * * *`
     - タイムゾーン: Asia/Tokyo
     - ターゲット: Cloud Run Jobs 実行エンドポイント
     - リトライ: 初期は無効とする（重複通知防止のため）

## 日常運用

### ログの確認

- Cloud Logging で、Cloud Run Jobs のログを確認する。
- 主に以下の情報を確認する。
  - ジョブ開始・終了ログ
  - 頭痛ーるAPI呼び出し結果
  - 通知判定結果（通知した／しなかった理由）
  - 通知API呼び出し結果（Slack/LINE、成功／失敗）

### ジョブ失敗時の対応

1. Cloud Run Jobs の履歴画面で、失敗した実行のログを確認する。
2. 失敗要因を特定する。
   - ネットワークエラー / タイムアウト
   - 頭痛ーるAPIの不調
  - 通知API（Slack/LINE）のエラー（認証エラー、レートリミットなど）
3. 一時的なエラーであれば、手動で Cloud Run Job を再実行する。
4. 認証エラー等の設定ミスが原因の場合は、設定値やシークレットを修正した上で再実行する。

## 設定変更手順

### しきい値の変更

1. Cloud Run Jobs の設定画面を開く。
2. 環境変数 `PRESSURE_LEVEL_THRESHOLD` の値を変更する（例: 3 → 4）。
3. 設定を保存し、次回以降の実行から新しいしきい値が適用されることを確認する。

### 対象地点の変更

1. 頭痛ーるで使用する新しい地点IDを調べる。
2. Cloud Run Jobs の環境変数 `ZUTOOL_PLACE_ID` を新しいIDに変更する。
3. 設定を保存する。

### 通知先ユーザーの変更

1. 新しいユーザーの LINE userId を取得する（Webhook などの方法で取得する想定）。
2. Cloud Run Jobs の環境変数 `LINE_USER_ID` を新しい userId に変更する。
3. 設定を保存する。

## トラブルシューティング（例）

- 症状: 通知が届かない
  - 確認事項:
    - Cloud Scheduler が正常に実行されているか
    - Cloud Run Jobs が成功終了しているか
    - LINE API 呼び出しでエラーになっていないか（ログを確認）
    - `PRESSURE_LEVEL_THRESHOLD` が高すぎて通知条件を満たしていない可能性

- 症状: 同じ日に複数回通知が来る
  - 確認事項:
    - Cloud Scheduler や Cloud Run Jobs にリトライ設定が有効になっていないか
    - 手動で何度もJobを実行していないか
  - 初期構成では冪等性のための永続ストレージを持たないため、プラットフォーム側リトライは無効とする。

  ## Slack 通知を利用する場合の設定手順（オプション）

  LINE の代わりに Slack へ通知する構成をとる場合の、Slack 側および GCP 側の追加/変更手順をまとめる。

  ### Slack App / Incoming Webhook の設定

  1. Slack App の作成
    - ブラウザで Slack API（https://api.slack.com/apps）にアクセスする。
    - 「Create New App」から新しいアプリを作成し、通知を送りたいワークスペースを選択する。
  2. Incoming Webhooks 機能の有効化
    - 作成したアプリの設定画面で「Incoming Webhooks」を有効にする。
    - 「Add New Webhook to Workspace」から、通知を流したいチャンネル（自分専用のプライベートチャンネルなど）を選択し、Webhook URL を発行する。
  3. Webhook URL の保存
    - 発行された Webhook URL（`https://hooks.slack.com/services/...`）をコピーし、GCP Secret Manager に `SLACK_WEBHOOK_URL` などの名前で保存する。

  ### Cloud Run Jobs 側の設定変更

  1. シークレットのマッピング
    - Cloud Run Jobs の設定画面で、Secret Manager の `SLACK_WEBHOOK_URL` を環境変数として注入する。
  2. アプリ側の設定
    - 環境変数名（例: `SLACK_WEBHOOK_URL`）を、アプリケーションの設定読み込み処理（env.ts 等）で扱えるようにする。
    - 通知ロジックで、Slack を利用する場合は `SLACK_WEBHOOK_URL` に対して `POST` するよう実装する（JSON でメッセージ本文を送信）。
  3. LINE 通知との組み合わせ方針（例）
    - Slack のみ設定されている場合は Slack のみ通知される。
    - LINE 関連の設定も行った場合は、spec.md に記載の通り Slack と LINE の両方へ同一内容の通知が送信される。
    - 必要に応じて、環境変数 `NOTIFICATION_TARGET=slack|line` のようなモードを追加し、コード側で送信先を制御する拡張も検討する。

## 今後の運用拡張アイデア

- Cloud Monitoring で、Cloud Run Jobs の失敗回数に対するアラートポリシーを追加する。
- 通知履歴を外部ストレージに保存し、Webダッシュボードやスプレッドシートで可視化する。
- 複数ユーザー対応時のユーザー管理・アクセス権限管理ポリシーを定義する。
