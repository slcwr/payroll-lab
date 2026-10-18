# 給与計算ラボ（payroll-lab）

従業員情報（労務管理）と勤怠集計を入力に、支給・社会保険・雇用保険・源泉所得税・住民税までを自動で計算し、
明細を画面で確認・確定できます。

| 層 | 技術 |
|---|---|
| バックエンド | Ruby 3.3 / Ruby on Rails 8（API モード）/ graphql-ruby / PostgreSQL 16 / RSpec |
| フロントエンド | Next.js 16（App Router）/ TypeScript / Apollo Client / SmartHR UI / MSW |
| インフラ | Docker / Google Cloud（Cloud Run・Cloud Run Jobs・Cloud SQL・Secret Manager）/ Terraform / GitHub Actions |

> ⚠️ 料率・税額表は学習用のサンプルです（令和7〜8年度の公表値をもとにしています）。実務には使わないでください。

---

## 動かし方

### 1. 画面だけ見る（API 不要・いちばん手軽）

```sh
cd frontend
npm install
npm run dev:mock      # http://localhost:3001
```

MSW がブラウザ内で GraphQL API の代わりをします。
モックの明細データは、バックエンドの**本物の計算ロジック**で生成したものです（`backend/script/export_mock_payslips.rb`）。

### 2. 給与計算ロジックのテストだけ動かす（DB 不要）

```sh
cd backend
bundle install
bundle exec rspec spec/lib   # 55 examples、1秒かからない
```

### 3. 一式を動かす

```sh
docker compose up --build
docker compose exec api bin/rails db:seed                     # 従業員300人
# SEED_EMPLOYEES=10000 で件数を変えられる
docker compose exec api bin/rails "payroll:benchmark[10000]"  # 1万人の計算時間を測る
```

画面 http://localhost:3001 、GraphQL http://localhost:3000/graphql

---

## ディレクトリ構成

```
backend/
  lib/payroll/              ← 給与計算のドメイン層（Rails に依存しない純粋な Ruby）
    calculator.rb             計算の入口。ステップを順に実行する
    steps/earnings.rb         基本給・手当・割増賃金・欠勤控除・通勤手当
    steps/social_insurance.rb 健康保険・介護保険・子ども子育て支援金・厚生年金
    steps/employment_insurance.rb
    steps/income_tax.rb       源泉所得税（電算機計算の特例）
    eligibility.rb            年齢到達・資格取得／喪失の判定
    rate_table.rb             料率表（適用開始日つき）
    rounding.rb               端数処理
  config/payroll/*.yml      ← 法改正で変わる料率・税額表（データとして管理）
  app/services/payroll_runs/calculate.rb ← 数万人分を回すバッチ
  app/graphql/              ← GraphQL スキーマ
frontend/src/
  app/                      ← 画面（一覧・計算結果のチェック・明細）
  mocks/                    ← MSW のモック
infra/terraform/            ← Google Cloud 構成
```

---

## 設計で意識したこと（面談で話せるポイント）

SmartHR の求人票にある3つの課題に対応させています。

### 1. 複雑なルールを「正確で拡張しやすい仕組み」に落とし込む

- **計算ロジックを Rails から切り離した**
  `lib/payroll` は DB にもフレームワークにも触れない純粋関数です。ActiveRecord のモデルはそのまま渡さず、
  `EmployeeSnapshot` などの値オブジェクトに詰め替えて渡します。テストが速く書け、計算時点の入力が明確になります。
- **法改正をコードではなくデータで表現した**
  料率・税額表は `config/payroll/*.yml` に「適用開始日つき」で持っています。
  令和8年度の改正（協会けんぽ料率・介護保険料率・雇用保険料率の変更、**子ども・子育て支援金の新設**、
  基礎控除の見直しによる源泉徴収税額の変更）は、どれも YAML に行を足すだけで反映しています。
- **「いつの料率を使うか」を正しく扱う**
  社会保険は「保険料の対象月」、雇用保険は「賃金締切日」、源泉所得税は「支払日」で決まります。
  翌月徴収の会社では4月支給の給与に3月分の料率を使う、といった違いをテストで固定しています。
- **計算根拠（basis）を明細の全行に残す**
  「時間単価2,000円 × 12時間30分 × 1.25」のように残すので、担当者のチェック・問い合わせ対応・監査に使えます。

### 2. 計算の正しさを継続的に担保するテスト戦略

- ドメイン層の単体テスト（`spec/lib/payroll`）で、端数処理・年齢到達・資格の取得喪失・法改正の切り替え・
  入退社の日割り・月末退職の2か月分控除などの境界を押さえています。期待値は手計算（別実装）で出したものです。
- 「同じ入力なら同じ結果（冪等）」「支給 − 控除 = 差引」のような**性質のテスト**も入れています。
- サービス層のテストで、再計算しても明細が重複しないこと、**N+1 を起こさないこと（クエリ数が人数に比例しない）**を確認します。
- 計算結果に「入社者・退職者・40/65/70/75歳到達・差引マイナス・警告あり」の目印を付け、
  担当者が要確認の人だけを絞り込めるようにしています（プレスリリースの絞り込み機能を参考）。

### 3. 数万人 × 100項目を限られた時間で計算する性能設計

`PayrollRuns::Calculate` の工夫:

1. 従業員を500件ずつ読み込み、メモリを一定に保つ
2. 手当・勤怠はバッチ単位でまとめて読み込む（N+1 なし）
3. 明細は `insert_all` で一括書き込み（1人ずつ INSERT しない）
4. 再計算時は対象の明細を消してから書く（冪等。失敗したタスクはそのまま再実行できる）
5. `employees.id % shard_count` で従業員を分け、**Cloud Run Jobs の複数タスクで並列計算**。
   最後に終わったタスクが行ロックを取って集計し、状態を「計算済み」にする

API（Cloud Run サービス）は計算を依頼したらすぐ返し、画面は進捗をポーリングします。
数万人分の合計金額は GraphQL の Int（約21億）を超えうるので `BigInt` で返しています。

---

## Rails 未経験でも読むためのメモ（TypeScript との対応）

| やりたいこと | これまで（TypeScript） | このリポジトリ（Ruby / Rails） |
|---|---|---|
| ORM | Prisma / Drizzle | ActiveRecord（`app/models`） |
| N+1 回避 | `include` / DataLoader | `includes`（サービス層）・`GraphQL::Dataloader`（`app/graphql/sources`） |
| 一括 INSERT | `createMany` | `insert_all!` / `upsert_all` |
| GraphQL サーバー | Apollo Server / Nest.js | graphql-ruby（`app/graphql`） |
| 型付きの値 | `type` / `readonly` | `Data.define`（不変の値オブジェクト） |
| テスト | Jest | RSpec |
| マイグレーション | Prisma Migrate | `db/migrate` |
| ワーカースレッド並列化 | Piscina | Cloud Run Jobs のタスク分割（プロセス単位） |

---

## 簡略化していること（伸ばしどころ）

- 認証・テナント分離はしていない（最初の会社を操作対象にする）。実運用ではすべてのクエリをテナントで絞る
- 締め日は月末固定。会社ごとの締め日・支給日のパターンは未対応
- 標準報酬月額は登録済みの値を使う（算定基礎・月額変更の判定は未実装）
- 賞与・年末調整・定額減税・乙欄・日額表は未対応
- 明細一覧のページングは graphql-ruby 標準（オフセット方式）。数万件ならカーソルを id にした方式にしたい
- 監査ログ（誰がいつ確定・再計算したか）は未実装。`payroll_run_events` のようなテーブルを足すのが次の一歩
- フロントの型は手書き。graphql-codegen でスキーマから生成するとよい
- 本番のマイグレーションはサーバー起動時に流している。Cloud Run Jobs で別に流す方が安全

## 動作確認の状況

- ✅ 給与計算ドメイン層の RSpec（55件）: 通過
- ✅ フロントエンドの型チェック・Vitest・`next build`・モックモードでの画面表示: 確認済み
- ⚠️ Rails 層（モデル・GraphQL・バッチ）と Rails の RSpec: 作成環境で Ruby の gem を取得できなかったため**未実行**です。
  `docker compose up` で起動し、`docker compose exec api bundle exec rspec` で確認してください
- ⚠️ Terraform: `terraform validate` 未実施（CI で実行されます）

## 参考にした公表資料

- [令和8年分 源泉徴収税額表（国税庁）](https://www.nta.go.jp/publication/pamph/gensen/zeigakuhyo2026/01.htm)
- [令和8年度 協会けんぽの保険料率](https://www.kyoukaikenpo.or.jp/g7/cat330/sb3130/r08/)
- [令和8年度の雇用保険料率（山形労働局）](https://jsite.mhlw.go.jp/yamagata-roudoukyoku/koyouhoken-20260316.html)
- [SmartHR、データ入力レスな「給与計算」機能を提供開始](https://smarthr.co.jp/news/press/20250603_payroll/)
