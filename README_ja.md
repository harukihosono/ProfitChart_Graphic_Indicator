# ProfitChart Graphic Indicator

MetaTrader 5（MT5）およびMetaTrader 4（MT4）用の包括的な損益チャートインジケーター。HTML出力機能と詳細な取引統計を搭載。

![ProfitChart Graphic Indicator スクリーンショット](screenshot.png)

## 主な機能

### ビジュアルチャート表示
- **累積損益折れ線グラフ**: 黄色の線で総損益の推移を表示
- **個別取引棒グラフ**: ダークグレーのヒストグラムで各取引の損益を表示
- **時間ベース集計**: 選択期間に応じて自動的に取引を集計し、見やすく表示
- **ダークテーマ**: プロフェッショナルな黒背景に白文字、黄色アクセント

### 期間フィルター
取引履歴を時間で絞り込み：
- **1D**: 過去24時間（1時間単位で集計）
- **1W**: 過去7日間（4時間単位で集計）
- **1M**: 過去30日間（1日単位で集計）
- **3M**: 過去90日間（1日単位で集計）
- **6M**: 過去180日間（1日単位で集計）
- **12M**: 過去365日間（1日単位で集計）
- **ALL**: 全取引履歴（1日単位で集計）

### マジックナンバーフィルター
- 特定のEAのマジックナンバーで取引を絞り込み
- すべてのEAの取引を表示（マジックナンバー -1）
- よく使うマジックナンバー（0、100、200など）のクイックトグルボタン

### 統計パネル
チャート上に包括的な取引指標を表示：
- **Profit Factor (PF)**: 総利益と総損失の比率
- **Max Drawdown (DD)**: 最大ドローダウン
- **Total Lots**: 総ロット数
- **Trade Count**: 決済済み取引回数
- **Total Profit**: 総利益（プラス取引の合計）
- **Total Loss**: 総損失（マイナス取引の合計）
- **Net Profit**: トータル損益（総利益 - 総損失）
- **Total Commission**: 総手数料
- **Total Swap**: 総スワップ

### HTML出力
インタラクティブなチャート付きプロフェッショナルなHTMLレポートを生成：
- **自動ブラウザ起動**: レポートがデフォルトブラウザで自動的に開く
- **インタラクティブチャート**: Chart.jsによるズーム・パン機能
- **レスポンシブレイアウト**: スクリーンショット用に最適化（横幅1600px）
- **取引履歴テーブル**: 全取引の詳細リスト
- **期間表示**: レポートが対象とする正確な期間を表示
- **フォルダを開くボタン**: Reportsディレクトリへ素早くアクセス

### キャッシュバック計算
- 0.01ロットあたりのキャッシュバック追跡（オプション）
- キャッシュバック表示のオン/オフ切り替え
- 有効時は累積計算にキャッシュバックを含める

## インストール方法

### MT5の場合：
1. すべてのファイルをMT5データフォルダにコピー：
   ```
   [MT5 Data Folder]/MQL5/Indicators/ProfitChart_Graphic_Indicator/
   ```
2. 必要なファイル：
   - `ProfitChart_Graphic_Indicator.mq5`
   - `ProfitChart_Common.mqh`
   - `ProfitChart_Graphic.mqh`
   - `ProfitChart_HistoryLoader.mqh`
   - `Graphic.mqh`（MT5標準ライブラリ）

3. MetaEditorでコンパイルするか、MT5を再起動して自動コンパイル
4. ナビゲーターウィンドウから任意のチャートにアタッチ

### MT4の場合：
1. すべてのファイルをMT4データフォルダにコピー：
   ```
   [MT4 Data Folder]/MQL4/Indicators/ProfitChart_Graphic_Indicator/
   ```
2. 必要なファイル：
   - `ProfitChart_Graphic_Indicator.mq4`
   - `ProfitChart_Common.mqh`
   - `ProfitChart_Graphic.mqh`
   - `ProfitChart_HistoryLoader.mqh`
   - `ProfitChart_Canvas_MT4.mqh`

3. MetaEditorでコンパイルするか、MT4を再起動して自動コンパイル
4. ナビゲーターウィンドウから任意のチャートにアタッチ

## 使い方

### 入力パラメーター

| パラメーター | デフォルト | 説明 |
|-------------|----------|------|
| `InpSymbol` | 現在のシンボル | 分析対象のシンボル（例：「BTCUSDm」「EURUSD」） |
| `InpMagicNumber` | -1 | マジックナンバーフィルター（-1 = 全取引） |
| `InpCashbackPer001Lot` | 0.0 | 0.01ロットあたりのキャッシュバック金額 |
| `InpChartX` | 10 | チャート横位置（ピクセル） |
| `InpChartY` | 180 | チャート縦位置（ピクセル） |
| `InpChartWidth` | 1200 | チャート幅（ピクセル） |
| `InpChartHeight` | 600 | チャート高さ（ピクセル） |

### コントロールボタン

**期間選択（上段）：**
- 任意の期間ボタン（1D、1W、1M、3M、6M、12M、ALL）をクリックして期間を絞り込み
- 現在選択中の期間がハイライト表示

**マジックナンバー選択（下段）：**
- マジックナンバーボタンをクリックして特定のEAで絞り込み
- 「ALL」ボタンで全マジックナンバーの取引を表示
- 「+CB」ボタンでキャッシュバックの表示/非表示を切り替え

**出力ボタン：**
- **HTML**: HTMLレポートを生成してブラウザで開く
- **Open Folder**: Reportsディレクトリをエクスプローラーで開く

### HTMLレポート

HTMLレポートは自動的に以下のディレクトリに保存されます：
```
[ターミナルデータフォルダ]/MQL5/Files/Reports/
```

レポートファイル名形式：
```
ProfitReport_[シンボル]_MN[マジック]_[タイムスタンプ].html
```

例：`ProfitReport_BTCUSDm_MN-1_2025.10.26_00.04.09.html`

### 効果的な使い方のヒント

1. **スクリーンショット最適化**：
   - レポートは高品質なスクリーンショット用に横幅1600pxで設計
   - 統計は3カラムグリッドでコンパクトに配置

2. **短期分析**：
   - 1Dまたは1W期間を使用して時間/4時間単位の詳細を確認
   - ツールチップに取引タイムスタンプを表示

3. **長期分析**：
   - 3M、6M、12M、またはALLで全体像を把握
   - 日次集計でノイズを削減

4. **複数EA口座**：
   - マジックナンバーフィルターで各EAを個別に分析
   - 異なる戦略間でパフォーマンスを比較

## 技術仕様

- **プラットフォーム**: MetaTrader 5 / MetaTrader 4
- **言語**: MQL5 / MQL4
- **チャートライブラリ（MT5）**: CGraphic（標準ライブラリ）
- **チャートライブラリ（MT4）**: カスタムCanvas実装
- **HTMLチャート**: Chart.js v3.9.1
- **ファイル操作**: MQL5 File API
- **Windows統合**: Shell32.dllでブラウザ/フォルダ起動

## ファイル構成

```
ProfitChart_Graphic_Indicator/
├── ProfitChart_Graphic_Indicator.mq5     # MT5メインインジケーター
├── ProfitChart_Graphic_Indicator.mq4     # MT4メインインジケーター
├── ProfitChart_Common.mqh                # 共通データ構造とユーティリティ
├── ProfitChart_Graphic.mqh               # チャート描画ロジック
├── ProfitChart_HistoryLoader.mqh         # 取引履歴ローダー
├── ProfitChart_Canvas_MT4.mqh            # MT4 Canvas実装
├── README.md                             # 英語版ドキュメント
└── README_ja.md                          # 日本語版ドキュメント（このファイル）
```

## 統計指標の説明

### Profit Factor（PF）
```
PF = 総利益 / 総損失
```
- 1.0より大きい値は利益が出ている取引を示す
- 1.0より小さい値は損失が出ている取引を示す
- 例：PF = 2.0は、1ドル失うごとに2ドル稼いでいることを意味する

### Max Drawdown（DD）
累積利益のピークからトラフまでの最大下落幅：
```
DD = 累積利益のピーク - その後の最低値
```
- リスクエクスポージャーを測定
- 値が低いほど安定した資産曲線を示す

### Net Profit（トータル損益）
```
Net Profit = 総利益 - 総損失
```
- 全取引後の実際の損益
- 手数料とスワップを含む

## 互換性

- **MT5**: 完全対応（ビルド3400以降）
- **MT4**: 完全対応（ビルド1220以降）
- **Windows**: 必須（HTML起動にShellExecuteWを使用）
- **ブラウザ**: 最新のブラウザ（Chrome、Firefox、Edge、Safari）

## バージョン履歴

### v1.0.0（2025-10-26）
- 初回リリース
- MT5およびMT4対応
- 期間ベースフィルタリング（1DからALL）
- マジックナンバーフィルタリング
- Chart.js統合のHTML出力
- 自動ブラウザ起動
- 9指標を含む統計パネル
- キャッシュバック計算
- 時間ベース取引集計
- ダークテーマデザイン
- フォルダアクセスボタン

## クレジット

- **チャートライブラリ（MT5）**: MQL5標準ライブラリ `Graphic.mqh`
- **HTMLチャート**: Chart.js（https://www.chartjs.org/）
- **開発**: Luke H.
- **ライセンス**: Copyright 2025

## サポート

問題、質問、機能リクエストについては、開発者にお問い合わせいただくか、MQL5/MQL4ドキュメントをご参照ください：
- MT5ドキュメント: https://www.mql5.com/ja/docs
- MT4ドキュメント: https://docs.mql4.com/

---

**Generated with Claude Code**（https://claude.com/claude-code）

Co-Authored-By: Claude <noreply@anthropic.com>
