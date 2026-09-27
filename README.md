# open-factory

ソフトウェアファクトリーを、実際に作る場所。

- 要点。open-factory は、人間が何を想定しているかを正しく伝えるための仕組みである。アセットとパイプラインは、その伝達の経路として作る。
- 目的。要求を伝え、体系化された仕様と設計をレビューし、実装中に出た仕様判断に的確に答え、それ以外を自動化するパイプラインを、速く、低コストで回す。
- 形。Claude Code の plugin `opfx`(marketplace は `open-factory`)。OpenSpec 1.13.2 からテンプレートと tools を借り、ナレッジ、eval、エージェント、trace、パイプラインを自前で作る。
- ロール。supervisor は人と向き合う session。handler は supervisor の sub agent。worker と reviewer は handler の sub agent。ハンドオフは sub agent の起動、hand-back、SendMessage で行い、記録は GitHub の Issue と PR のコメントに残す。

## 使い方

1. Claude Code で marketplace と plugin を入れる。`/plugin marketplace add ito-p/open-factory`、`/plugin install opfx@open-factory`。手元の checkout から使うなら `claude --plugin-dir <path>/open-factory/plugins/opfx`。
2. 製品 repo の root で `/opfx:init`。前提(gh、Node 20.19、jq)を確かめ、rubric や並列数や model を聞き、`openspec/`、`.factory/`、`AGENTS.md`、GitHub の label とテンプレートを作る。
3. `/opfx:supervisor`。要求を話すと Issue を書く。「run #12」と名指すと handler が worker を起こし、propose → レビュー → apply → archive → PR → マージまで回す。仕様判断は supervisor が人に問い、答えは Issue のコメントに残る。

## 借りるものと作るもの

| アセット | 借りる(OpenSpec と GitHub) | 作る(opfx) |
|---|---|---|
| テンプレート | schema `spec-driven`、artifact の雛形、delta の 4 操作 | Issue と PR の雛形 |
| アーティファクト | `changes/`、`specs/`(source of truth)、`archive/` | Issue、PR |
| ナレッジ | `openspec/config.yaml` の context と rules の注入 | その中身、`AGENTS.md`、`.factory/config.json` |
| eval | `openspec validate` | ゲート 1〜3 の script、reviewer(R1、R2)、`.factory/evals/` の拡張点 |
| エージェント | OpenSpec の生成 skill(`/opsx:*`) | supervisor、handler、worker、reviewer、`/opfx:init` |
| tools | `openspec` CLI、`gh`、`git`、Claude Code の sub agent | `plugins/opfx/scripts/*.sh` |
| trace | `archive/` の日付つき保存、git log | Issue と PR のコメント(フェーズ、ゲート、レビュー、rubric の判定、人の答え、token と見積りコスト) |

## 開発

- script の試験: `bash plugins/opfx/scripts/tests/run.sh`(一時 dir に `openspec init` した fixture を使う。`gh` は stub)。
- 手順書の検査: `bash plugins/opfx/tests/checklist.sh`(手順書が名指す script と openspec の動詞の実在)。
- CI は `.github/workflows/test.yml` で同じ 2 つを走らせる。

2026-09-26 に作成。

## 設計の道具

opfx は設計の道具を名指さない。`.factory/config.json` の `design.docs_dir`(既定 `docs/design`)と製品 repo の `AGENTS.md` に、道具(たとえば Figma)、その file、配置と命名の規則、読み戻し方を書く。UI を変える change は rubric の `[ui] … => design:required` で design.md を持ち、worker はその規則で描いて記録し、R1 の reviewer は読み戻して照合する。
