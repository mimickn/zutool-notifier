# 気圧情報の Google カレンダー連携（調査結果）

## 目的

現状、頭痛ーるの気圧情報は Slack/LINE への毎朝通知のみに使われている。
これに加え、気圧情報（時間別の気圧・気圧レベル）を Google カレンダーに登録し、
「サブカレンダー」として Google カレンダー上で表示・確認できるようにする。

## 実現方式の比較

| 方式 | 概要 | 長所 | 短所 |
|------|------|------|------|
| A. Google Calendar API | バッチから Calendar API で予定を登録 | 本物のサブカレンダー。即時反映、時間単位の予定・色・説明文を柔軟に指定できる。既存の GCP 基盤と親和性が高い | サービスアカウント/権限設定が必要。API 有効化とクォータ確認が必要 |
| B. iCalendar（.ics）配信 | .ics ファイルを公開 URL で配信し、Google カレンダーで「URL から追加」 | OAuth/API 不要で最も単純 | 同期間隔が Google 側任せ（最大 ~24h 程度）で即時反映されない。読み取り専用の購読カレンダー |
| C. Google Apps Script | Apps Script の Web アプリでカレンダーに書き込み | Google アカウント側で完結 | 既存の GCP バッチ構成と別管理になり、シークレット/監視の分断が生じる |

**推奨: A（Google Calendar API + サービスアカウント）**

本アプリはすでに GCP（Cloud Run Jobs / Secret Manager / Terraform）上で動いており、
サービスアカウント・シークレット管理の仕組みが揃っているため、方式 A が最も自然に統合できる。
また「前夜 21:00 に翌日分を登録し、その夜のうちに確認する」ユースケースでは即時反映が重要なため、
同期遅延のある方式 B より適している。

## 確定した仕様（v1）

- 登録タイミング: **前夜 21:00（Asia/Tokyo）** に実行する。
- 登録対象: **翌日（`tommorow`）** の時間別データのうち、**アラート時間帯のみ**を **1 時間単位**で登録する。
  - アラート判定は `pressure_level >= PRESSURE_LEVEL_THRESHOLD`（既存の Slack 通知ロジックと同一）。
- イベント内容:
  - **Lv3 / Lv4 でタイトルと色を変える**。説明文は付けない。
    - タイトル例: Lv3=`気圧アラート Lv3` / Lv4=`気圧アラート Lv4`
    - 色: Lv3=`colorId 6`（オレンジ系）/ Lv4=`colorId 11`（レッド系）※実装時に微調整可
- 過去イベントの扱い: **残す**（サブカレンダーとして使うため、過去日のイベントは削除しない）。
- 失敗時の挙動: カレンダー登録に失敗したら**ジョブ全体を失敗**させる（詳細は実装時に調整）。
- 認証スコープ: `https://www.googleapis.com/auth/calendar.events`（イベント操作に必要な最小権限）。
- 実行方式: **別 Cloud Run Job** として分離する（共通 Docker イメージ・別エントリポイント）。
- 通知（Slack / LINE）: **現状維持**。今回のカレンダー連携では変更しない。
  - 既存の毎朝 7:00 の通知実行と、今回追加する前夜 21:00 のカレンダー登録実行は独立させる。

## 推奨方式の詳細（Google Calendar API）

### 認証・権限の方針

- Google 公式ドキュメントでは、サービスアカウントをカレンダーの「データ所有者」にするのは非推奨
  （`calendars.insert` で SA が作成すると所有権の移譲ができない、等の理由）。
- 個人の Google アカウント（Workspace 以外）では domain-wide delegation は使えない。
- そのため**ユーザー側でカレンダーを作成し、サービスアカウントに編集権限を共有する**方式を採る：
  1. ユーザーが Google カレンダーでサブカレンダー（例: 「気圧」）を新規作成する。
  2. そのカレンダーの設定 →「特定のユーザーと共有」で、
     Cloud Run Job 用（または専用の）サービスアカウントのメールアドレスを追加し、
     権限を「予定の変更」にする。
  3. バッチはそのカレンダー ID に対して、サービスアカウント資格情報でイベントを登録する。

- 必要な OAuth スコープ: `https://www.googleapis.com/auth/calendar.events`
  （イベントの読み書きのみで十分。カレンダーの作成・削除・共有設定変更は不要なため最小権限を選択）。
- 資格情報はサービスアカウントの JSON キーを Secret Manager に保存して利用する
  （既存の `SLACK_WEBHOOK_URL` と同様のパターン）。

### 登録するデータ設計（確定）

- 対象日: **翌日（`tommorow`）**。zutool API のレスポンスから `tommorow` 配列を参照する。
- 対象時間帯: **アラート時間帯のみ**（`pressure_level >= PRESSURE_LEVEL_THRESHOLD`）。
- 粒度: **1 時間単位**で 1 イベント（`time` 時〜`time+1` 時）。
  - タイトル: `pressure_level` で分ける（例: Lv3=`気圧アラート Lv3` / Lv4=`気圧アラート Lv4`）。
  - 時刻: `time` 時〜`time+1` 時（`Asia/Tokyo`）
  - 説明: **なし**。
  - 色: Lv3=`colorId 6` / Lv4=`colorId 11`（`colorId` は Google の定義色 0〜11 に限定）。
- アラート時間帯が 1 つも無い日は、イベントを登録しない（Slack 通知と同様にスキップ）。

### 冪等性（重複登録の防止）

- バッチ再実行や手動再実行で同一予定が重複しないよう、**イベントに一意な `iCalUID` を固定**し、
  `events.insert` の代わりに `events.import` を使う（同一 `iCalUID` なら上書き扱いになる）。
  - `iCalUID` 例: `zutool-pressure-{YYYY-MM-DD}-{HH}@zutool-notifier`
- これにより「同じ日時・時間帯」は何度実行しても 1 イベントに保たれる。

## 変更点（既存アプリへの統合イメージ）

### コード

- 依存追加: `googleapis`（Calendar API クライアント）。
- 新規 `src/services/googleCalendarClient.ts`:
  - サービスアカウントキー JSON（環境変数/シークレットから読み込み）で JWT クライアントを生成。
  - `upsertPressureEvents(calendarId, date, entries)` を提供。
- 新規 `src/domain/calendarEvent.ts`（任意）: `ZutoolTimeEntry[]` → イベント配列への変換ロジック。
  - 判定は既存の `decideNotification` 相当（`pressure_level >= PRESSURE_LEVEL_THRESHOLD`）を再利用し、
    対象を `tommorow` 配列にして、アラート時間帯だけをイベント化する。
- `src/config/env.ts`: 以下を追加。
  - `GOOGLE_CALENDAR_ID`（必須・カレンダー ID、通常は `{メールアドレス}` 形式）
  - `GOOGLE_CALENDAR_SERVICE_ACCOUNT_KEY`（必須・SA キー JSON 文字列）
  - 設定が無い場合はカレンダー登録をスキップ（Slack/LINE と同様の「設定時のみ実行」方式）。
- 実行方式（確定）: **別 Cloud Run Job として分離**する。
  - 通知ジョブ（既存）: 当日分・毎朝 7:00・Slack/LINE シークレットのみ保持。
  - カレンダージョブ（新規）: 翌日分・前夜 21:00・カレンダー関連の環境変数/シークレットのみ保持。
  - 同じ Docker イメージを共有し、別エントリポイント（例: `dist/index.js` / `dist/index.calendar.js`）で挙動を分ける。

### インフラ（Terraform）

- Secret Manager に `GOOGLE_CALENDAR_SERVICE_ACCOUNT_KEY` を追加
  （既存 `secret_manager` モジュールを再利用）。
- **カレンダー登録用の Cloud Run Job を新規追加**し、その `env` / `value_source` に
  `GOOGLE_CALENDAR_ID`（平文）と `GOOGLE_CALENDAR_SERVICE_ACCOUNT_KEY`（シークレット）を設定。
  既存の通知ジョブには変更を加えない。
- カレンダー登録用の Cloud Scheduler ジョブを追加（**毎日 21:00 / Asia/Tokyo**）。
  既存の 7:00 通知スケジュールは変更しない。
- サービスアカウントは既存の `cloud_run_job` SA をそのまま利用可能
  （カレンダー共有も同 SA のメールアドレスに対して行う）。

### 手動設定（1 回だけ）

1. GCP で Calendar API を有効化。
2. サービスアカウントの JSON キーを作成し、Secret Manager に登録。
3. ユーザーの Google カレンダーでサブカレンダーを作成し、SA メールへ「予定の変更」権限を共有。

## 代替案メモ（方式 B: iCalendar）

- バッチで `.ics`（`VCALENDAR`/`VEVENT`）を生成し、公開 GCS バケット等の安定 URL にアップロード。
- ユーザーは Google カレンダー → 他のカレンダー →「URL から追加」で URL を登録。
- OAuth/API キーが不要で実装は最小。ただし Google 側の再取得間隔が制御できず、
  「毎朝 7:00 に更新した当日データ」が反映されるまで最大 ~24h 遅れ得る。
- 「当日の気圧を毎朝すぐ見たい」用途には不向きだが、遅延を許容できるなら最も手軽。

## 注意点・検討事項

- Calendar API の利用クォータ（イベント挿入数など）は 1 日 24 件程度なら問題にならない。
- `colorId` は自由な色指定ではなく Google が定義する ID（0〜11）のみ。任意色が要るなら方式 B の
  `COLOR` プロパティや説明文での表現を検討。
- タイムゾーンは `Asia/Tokyo` を明示し、頭痛ーるの時刻（JST）とずれないようにする。
- 既存の Slack/LINE 通知とカレンダー登録は**別ジョブ**のため、失敗は互いに影響しない
  （カレンダージョブの失敗はカレンダージョブ全体の失敗として扱う）。
