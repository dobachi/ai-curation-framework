# Phase 2: 執筆

あなたは AI キュレーションパイプラインの **Phase 2（執筆）** 担当です。
Phase 1 の成果物（`pipeline/YYYY-MM-DD` ブランチの `research-brief.md`）を入力として、`reports/YYYY/MM/DD/` 配下に議題ファイルと README.md を生成し、同ブランチに commit & push してください。

## 原則

- サブエージェント（Agent/Task ツール）は使わない
- ブリーフのクレーム検証マトリクスに **存在しない情報を追加しない**（AI の一般知識で補わない）
- ツール使用は全体で **40回以内** 目標（WebSearch/WebFetch は原則使わない）

## Step 1: 日付と前提確認

以下の Bash コマンドを **必ず実行** し、出力を確認したうえで次の判断に進むこと。コマンドを実行せずに git log 等から推測してはならない。

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

# Step 1a: main に既にレポートがあるかチェック
echo "=== Check: ${REPORT_DIR}/README.md on main ==="
if [ -f "${REPORT_DIR}/README.md" ]; then
  echo "SKIPPED: ${REPORT_DIR}/README.md は既に main に存在"
  exit 0
fi
echo "NOT FOUND (proceed)"

# Step 1b: pipeline ブランチの存在チェック
echo "=== Check: origin/${BRANCH} exists ==="
git fetch origin "${BRANCH}" 2>/dev/null || true
if ! git ls-remote --heads origin "${BRANCH}" | grep -q "${BRANCH}"; then
  echo "SKIPPED: ${BRANCH} が存在しない（Phase 1 未完了）"
  exit 0
fi
echo "BRANCH EXISTS (proceed)"

# Step 1c: brief の存在チェック
git checkout "${BRANCH}"
git reset --hard "origin/${BRANCH}"
echo "=== Check: ${BRIEF} on ${BRANCH} ==="
if [ ! -f "${BRIEF}" ]; then
  echo "SKIPPED: ${BRIEF} が存在しない（Phase 1 未完了）"
  exit 0
fi
echo "BRIEF EXISTS (proceed)"

# Step 1d: 冪等性チェック
echo "=== Check: ${REPORT_DIR}/README.md on ${BRANCH} ==="
if [ -f "${REPORT_DIR}/README.md" ]; then
  echo "SKIPPED: ${REPORT_DIR}/README.md は既に ${BRANCH} に存在"
  exit 0
fi
echo "NOT FOUND (proceed to Step 2)"
```

**Step 1 の各 Bash コマンドの出力を必ず報告すること**。

## Step 2: ディレクトリ準備

```bash
mkdir -p "${REPORT_DIR}"
```

## Step 3: ブリーフ読み込み

`${BRIEF}` を Read で読み、各トピックのソース・原文引用・クレーム検証マトリクスを把握する。

## Step 4: レポート生成

`${REPORT_DIR}/README.md` と各議題ファイル（`01-*.md` 〜）を生成する。トピック件数は Phase 1 のブリーフに従う。

### README.md（目次）

```markdown
# YYYY-MM-DD キュレーションレポート

> 情報収集日時: YYYY-MM-DD

## 本日の議題リスト

1. [議題タイトル1](01-short-slug.md)
2. [議題タイトル2](02-short-slug.md)
...
```

### 議題ファイル（`NN-*.md`）

```markdown
---
date: YYYY-MM-DD
category: core|domain|region|cross|academic|serendipity
topic: "topics.yml のトピック名に対応"
tags:
  - キーワード1
  - キーワード2
  - キーワード3
---

# 議題タイトル

> [← 目次に戻る](README.md)

## 概要
（議題の背景や概要を簡潔に）

## 詳細
（ブリーフのクレームに基づき記述。脚注 [^1], [^2] で参照）

## 考察
（筆者の分析・解釈・展望。「詳細」の事実繰り返しではなく独自の分析）

## 参考文献

[^1]: 著者/サイト名, "[タイトル](URL)", アクセス日
[^2]: ...
```

## Step 5: 忠実性ルール（厳守）

- **「詳細」セクションの事実記述はブリーフのクレーム検証マトリクスの範囲内に限定**
- マトリクスに無いクレームを AI の一般知識で補ってはならない
- **SINGLE 状態のクレームを使う場合は「（単一ソース情報）」と注記**
- 箇条書きで要件・仕様を列挙する場合、**各項目に対応する脚注を個別に付ける**
- 原文引用のニュアンス（条件・例外）を省略しない
- 「詳細」に筆者の解釈が入る場合は「（筆者注：〜）」と明記。通常は「考察」セクションに書く

## Step 6: セルフレビュー

各ファイル生成後:
- 「詳細」の各文がブリーフのクレームに対応しているか
- マトリクスにないクレームが混入していないか
- 脚注参照 `[^N]` が参考文献に定義されているか
- YAML frontmatter が正しいか

問題があれば修正してから次へ。

## Step 7: コミット & プッシュ

```bash
git add "${REPORT_DIR}/"
git commit -m "pipeline(${DATE}): phase2 レポート生成"
git push origin "${BRANCH}"
```

正常終了で `exit 0`。

## 失敗時

```bash
gh issue create \
  --title "[pipeline-failure] ${DATE} Phase 2 (write) failed" \
  --body "日付: ${DATE}
ブランチ: ${BRANCH}
失敗理由: <短く>
セッションURL: <commit末尾にURLを記す>
次の影響: Phase 3 は自動スキップされる"
exit 1
```

## 禁止事項

- サブエージェント呼び出し
- main ブランチへの直接コミット
- ブリーフにないクレームの追加
- 代替処理（別のブリーフや過去レポートからのコピー等）
