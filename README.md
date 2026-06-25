# AIS Ship Map

AISStream.io の無料 WebSocket API から船舶の位置情報（AIS PositionReport）を
受信して DB に蓄積し、Google Maps 上にリアルタイム表示する Rails アプリです。

## 構成

```
AISStream.io (wss) --> rake ais:ingest (常駐) --> DB(vessels)
ブラウザ(Google Maps) --5秒ごと--> GET /api/vessels.json --> DB
```

- API キーをブラウザに出さないため、AISStream はサーバ側で受信します
  （AISStream は仕様上ブラウザからの直接接続不可）。
- ブラウザは Rails の JSON API (`/api/vessels.json`) を 5 秒ごとにポーリングして
  マーカーを更新します。

## 必要なもの

- Ruby 3.3 / Rails 8
- AISStream.io の API キー（無料・GitHub 等でサインインして発行）
- Google Maps JavaScript API キー

## セットアップ

```bash
bundle install
bin/rails db:prepare

# 環境変数を設定
cp .env.example .env
# .env を編集して AISSTREAM_API_KEY と GOOGLE_MAPS_API_KEY を設定
```

### 表示エリア（任意）

既定の受信エリアは東京湾です。変更する場合は `.env` の `AIS_BBOX` に
JSON 形式でバウンディングボックスを指定します。

```
AIS_BBOX=[[[34.5,138.9],[35.8,140.3]]]
```

## 起動（2 プロセス）

Web サーバと AIS 受信プロセスは別物です。ターミナルを 2 つ使います。

ターミナル 1（Web サーバ）:

```bash
bin/rails server
```

ターミナル 2（AIS 受信）:

```bash
bundle exec rake ais:ingest
```

ブラウザで http://localhost:3000 を開くと、地図上に船舶マーカーが表示され、
数秒ごとに更新されます。マーカーをクリックすると船名・速力・針路を確認できます。

## 主なファイル

- `app/services/ais_stream_client.rb` … AISStream への接続・購読・保存
- `lib/tasks/ais.rake` … `rake ais:ingest` 常駐タスク
- `app/models/vessel.rb` … 船舶モデル（MMSI で upsert）
- `app/controllers/api/vessels_controller.rb` … 直近データの JSON API
- `app/controllers/map_controller.rb` / `app/views/map/index.html.erb` … 地図表示

## 補足

- 夜間や閑散時はエリア内に船舶が少ない場合があります。表示が無いときは
  `AIS_BBOX` を広域に変更して確認してください。
- API は既定で直近 10 分以内のデータを返します（`?minutes=` で変更可）。
