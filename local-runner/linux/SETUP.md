# Ubuntu（物理/VM）セットアップ

Ubuntu / Debian / 他の systemd ベースの Linux で daily curation パイプラインをローカル実行する手順です。

## 事前確認

親ディレクトリの [README.md](../README.md) の「前提条件」を先に確認してください。

```bash
# 依存コマンド確認
command -v git claude gh python3 || echo "missing"

# git push 権限確認（SSH）
ssh -T git@github.com

# 認証確認
gh auth status
claude --version
```

## セットアップ手順

### 1. リポジトリ clone と環境変数

```bash
git clone git@github.com:<YOUR_USERNAME>/<YOUR_REPORTS_REPO>.git ~/Sources/curation-reports
cd ~/Sources/curation-reports

mkdir -p ~/.config/curation
cp local-runner/env.example ~/.config/curation/runner.env
$EDITOR ~/.config/curation/runner.env
```

### 2. 手動テスト（スケジューラ登録前に動作確認）

```bash
bash local-runner/run-phase.sh 1
# → pipeline/YYYY-MM-DD ブランチが push される
# → ~/.local/share/curation/logs/phase1-YYYY-MM-DD.log に出力
```

2回目は `SKIPPED` で終わることを確認:

```bash
bash local-runner/run-phase.sh 1
```

### 3. スケジューラ登録

以下の2方式から選択。

#### 方式A: systemd timer（推奨）

ユーザーサービスとしてインストール。ログは journalctl で参照可能。

```bash
bash local-runner/linux/install-systemd.sh
```

ログアウト後もジョブが走るようにする（任意、サーバー運用時は推奨）:

```bash
sudo loginctl enable-linger $USER
```

確認:

```bash
systemctl --user list-timers | grep curation
journalctl --user -u curation-phase1 -b
```

停止:

```bash
bash local-runner/linux/uninstall.sh
```

#### 方式B: cron

```bash
bash local-runner/linux/install-cron.sh
```

確認:

```bash
crontab -l | grep curation
```

停止:

```bash
bash local-runner/linux/uninstall.sh
```

## スケジュール

| Phase | 時刻（JST） | 備考 |
|---|---|---|
| 1 | 03:30 | リサーチ |
| 2 | 04:30 | 執筆 |
| 3 | 05:30 | ファクトチェック + main へ cherry-pick |

クラウド Routine（04:00 / 05:00 / 06:00 JST）より 30 分早い設定。ローカルが成功すると冪等性チェックでクラウドは SKIPPED になる。

## トラブルシューティング

### systemd timer が走らない

```bash
# timer 状態確認
systemctl --user status curation-phase1.timer

# 次回実行時刻確認
systemctl --user list-timers

# loginctl linger が有効か
loginctl show-user $USER | grep Linger
```

### タイムゾーン問題

`OnCalendar=*-*-* 03:30:00 Asia/Tokyo` でタイムゾーン指定しているが、環境によっては動かない場合がある。その場合は UTC で指定し直す:

```bash
systemctl --user edit curation-phase1.timer
```

`OnCalendar=*-*-* 18:30:00 UTC` のように UTC で記述。

### cron の環境変数

cron は最小の環境変数で実行されるため、`PATH` に `claude` が含まれない場合がある。問題が出たら cron エントリを修正:

```
30 3 * * * PATH=/usr/local/bin:/usr/bin:/bin:$HOME/.local/bin /bin/bash /path/to/run-phase.sh 1
```

もしくは `run-phase.sh` の冒頭で `PATH` を明示。
