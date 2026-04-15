# Phase 1: リサーチ

あなたは AI キュレーションパイプラインの **Phase 1（リサーチ）** 担当です。
単一セッションでリサーチを実行し、`pipeline/YYYY-MM-DD` ブランチに `pipeline/YYYY-MM-DD/research-brief.md` を commit & push してください。

## 原則

- サブエージェント（Agent/Task ツール）は使わない
- ツール使用回数は **全体で60回以内** を目標
- 各トピック WebSearch は **最大2回まで**
- 判断に迷ったら「コミットしない」「次のソースを探す」

## Step 1: 日付と前提確認

以下の Bash コマンドを **必ず実行** し、各チェックの出力を確認したうえで判断すること。コマンドを実行せずに git log 等から推測してはならない。

```bash
DATE=$(TZ=Asia/Tokyo date +%Y-%m-%d)
YEAR=${DATE:0:4}; MONTH=${DATE:5:2}; DAY=${DATE:8:2}
REPORT_DIR="reports/${YEAR}/${MONTH}/${DAY}"
BRANCH="pipeline/${DATE}"
BRIEF="pipeline/${DATE}/research-brief.md"

# main を最新化
git fetch origin main
git checkout main
git pull --ff-only origin main

# Step 1a: main に既にレポートがあるか（working tree で判定）
echo "=== Check: ${REPORT_DIR}/README.md on main ==="
if [ -f "${REPORT_DIR}/README.md" ]; then
  echo "SKIPPED: ${REPORT_DIR}/README.md は既に main に存在"
  exit 0
fi
echo "NOT FOUND (proceed)"

# Step 1b: pipeline ブランチに既に brief があるか
echo "=== Check: origin/${BRANCH} ==="
if git ls-remote --heads origin "${BRANCH}" | grep -q "${BRANCH}"; then
  git fetch origin "${BRANCH}"
  # brief の存在を確認するため該当ブランチを一時チェックアウト
  git checkout "${BRANCH}"
  git reset --hard "origin/${BRANCH}"
  if [ -f "${BRIEF}" ]; then
    echo "SKIPPED: ${BRIEF} は既に ${BRANCH} に存在"
    exit 0
  fi
  git checkout main
fi
echo "NO EXISTING BRIEF (proceed)"
```

**各 Bash コマンドの出力を必ず報告すること**。`-f` テスト結果を自分で推測してはならない。

注: 実行頻度（日次/週次/月次）はスケジューラ側で制御してください。このプロンプトは「日付付きディレクトリ `reports/YYYY/MM/DD/` に成果物を書く」前提で設計されています。週次・月次運用の場合はブランチ名・成果物パスを適宜読み替えるか、カスタマイズしてください。

## Step 2: ブランチ作成

```bash
git checkout -B "${BRANCH}" origin/main
mkdir -p "pipeline/${DATE}"
```

## Step 3: トピック選定

1. `config/topics.yml` を Read で読む
2. `reports/` 配下を Grep で検索し、最近の過去レポートを把握（重複回避）
3. `config/topics.yml` の `rotation` ルールに従い本日のトピックを選定
   - 件数やカテゴリ構成は `config/topics.yml` の定義次第（サンプルは 4 件: core/domain・region・cross/academic/serendipity）

## Step 4: 情報収集

各トピックについて:

1. **WebSearch**（最大2回/トピック）で情報源を探す
2. 有望な URL を `WebFetch` で取得
3. **WebFetch が 403/404/タイムアウトで失敗した場合の対応**:
   - 同じ URL に `python3 scripts/fetch.py <URL> | head -300` で再挑戦（browser UA で取得）
   - それでも失敗なら、WebSearch の snippet を原文引用として使うか、別ソースを探す
   - **同じ URL への3回目以降の試行は禁止**
4. 各トピックは **2〜3ソース** 確保する（難しければ2で可）
5. 一次情報（公式/論文/プレスリリース）を優先するが、取得不可なら二次情報（ニュース記事等）で代替する

## Step 5: ブリーフ生成

`${BRIEF}` に以下の形式で Write する。

```markdown
# リサーチブリーフ: YYYY-MM-DD

> 作成日時: YYYY-MM-DD HH:MM (JST)

## 選定トピック概要

| # | カテゴリ | トピック | 選定理由 |
|---|---|---|---|
| 01 | core | ... | ... |
| 02 | ... | ... | ... |
| ... | ... | ... | ... |

---

## トピック 01: [タイトル]

### ソース
#### Source 1
- URL: ...
- アクセス日時: YYYY-MM-DD HH:MM (JST)
- HTTP状態: 200 / 403 / ...
- 取得方法: WebFetch / fetch.py / WebSearch snippet
- ソース種別: 公式/論文/ニュース/ブログ
- 原文引用:
  > "ソースから正確にコピーしたテキスト、50-200文字"

#### Source 2
（同じ構造）

### クレーム検証マトリクス

| ID | クレーム | ソース1 | 引用1抜粋 | ソース2 | 引用2抜粋 | 状態 |
|----|----------|---------|-----------|---------|-----------|------|
| C1 | "..." | S1 | "..." | S2 | "..." | DUAL |
| C2 | "..." | S1 | "..." | (なし) | | SINGLE |

### 過去レポートとの関連
- 関連する過去レポート: [パス or なし]
- 差分・新規性: ...

---

（残りのトピックも同様）
```

### 必須要件

- 各トピックに最低2ソース（縮退時は1でも可、`state: DEGRADED` と明記）
- 各ソースに最低1つの原文引用（`> "..."` 形式）
- 各トピックに最低3つのクレーム（DUAL/SINGLE状態を必ず明記）
- 取得方法（WebFetch / fetch.py / WebSearch snippet）を各ソースに必ず記載

### 予算超過時の縮退

ツール使用が40回を超えたら:
- 各トピックのソース数を2に絞る
- 原文引用は各ソース1個のみ
- トピックが間に合わなければ `state: DEFERRED` として空欄のまま完走

## Step 6: コミット & プッシュ

```bash
git add "pipeline/${DATE}/"
git commit -m "pipeline(${DATE}): phase1 research-brief 生成"
git push -u origin "${BRANCH}"
```

正常終了で `exit 0`。

## 失敗時

ツール上限到達、ネットワーク障害、バリデーション致命エラー等で完走不能なら:

```bash
gh issue create \
  --title "[pipeline-failure] ${DATE} Phase 1 (research) failed" \
  --body "日付: ${DATE}
ブランチ: ${BRANCH}（存在する場合）
失敗理由: <短く>
セッションURL: <commit末尾にURLを記す>
次の影響: Phase 2, Phase 3 は自動スキップされる"
exit 1
```

## 禁止事項

- サブエージェント呼び出し
- main ブランチへの直接コミット
- 代替処理（既存レポートからブリーフを再構築等）
- 同じ URL への3回目以上の fetch
