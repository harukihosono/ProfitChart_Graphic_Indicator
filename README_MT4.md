# ProfitChart Graphic Indicator - MT4版

MT4用の損益チャートインジケーターです。CCanvasを使用してグラフィカルなチャートを表示します。

## ファイル構成

### MT4版
- `ProfitChart_Graphic_Indicator_MT4.mq4` - メインインジケーターファイル
- `ProfitChart_Canvas_MT4.mqh` - Canvas描画ロジック
- `ProfitChart_HistoryLoader_MT4.mqh` - MT4用履歴ローダー
- `ProfitChart_Common.mqh` - 共通データ構造（MT4/MT5共通）

## インストール方法

### 1. MT4のデータフォルダを開く
MT4で「ファイル」→「データフォルダを開く」をクリック

### 2. ファイルをコピー
以下のファイルを `MQL4\Indicators\` フォルダにコピー：
- `ProfitChart_Graphic_Indicator_MT4.mq4`
- `ProfitChart_Canvas_MT4.mqh`
- `ProfitChart_HistoryLoader_MT4.mqh`
- `ProfitChart_Common.mqh`

### 3. コンパイル
- MT4のMetaEditorを開く
- `ProfitChart_Graphic_Indicator_MT4.mq4` を開く
- F7キーを押してコンパイル

### 4. チャートに適用
- MT4のナビゲーターから「インジケーター」→「カスタム」→「ProfitChart_Graphic_Indicator_MT4」を選択
- チャートにドラッグ&ドロップ

## 機能

### グラフィカルチャート
- CCanvasを使用した高品質なチャート描画
- 累積損益ライン（緑）
- 個別損益バー（青/赤）
- グリッドと軸ラベル

### 統計情報パネル
- Profit Factor
- Max Drawdown
- Total Lots
- Trade Count
- Total Profit / Loss

### フィルター機能
- **期間フィルター**: 1D, 1W, 1M, 3M, 6M, 1Y, ALL
- **マジックナンバーフィルター**: 取引履歴から自動検出

## パラメータ

| パラメータ | 説明 | デフォルト値 |
|-----------|------|-------------|
| InpSymbol | 対象シンボル（空欄=現在のシンボル） | "" |
| InpMagicNumber | マジックナンバー（-1=全て） | -1 |
| InpPeriod | 表示期間 | PERIOD_ALL |
| InpCashbackPer001Lot | 0.01ロットあたりのキャッシュバック（円） | 10.0 |
| InpChartWidth | チャート幅（ピクセル） | 1200 |
| InpChartHeight | チャート高さ（ピクセル） | 800 |
| InpChartX | チャートX位置（左からのピクセル） | 50 |
| InpChartY | チャートY位置（上からのピクセル） | 80 |
| InpShowCumulative | 累積損益を表示 | true |
| InpShowIndividual | 個別損益を表示 | true |
| InpShowCashback | キャッシュバック込みで表示 | false |

## MT5版との違い

- MT5版はCGraphicライブラリを使用
- MT4版はCCanvasライブラリを使用（カスタム描画）
- 基本機能は同じですが、描画の実装が異なります

## 注意事項

- MT4ではCanvas機能が必要です
- 大量の取引履歴がある場合、初回読み込みに時間がかかる場合があります
- チャート更新は5秒ごとに自動実行されます

## トラブルシューティング

### コンパイルエラーが出る場合
- MT4のビルド番号を確認（最新版を推奨）
- `#include <Canvas\Canvas.mqh>` が見つからない場合、MT4を最新版にアップデート

### チャートが表示されない場合
- インジケーターのパラメータを確認
- 取引履歴が存在するか確認
- Expertsタブでエラーメッセージを確認

## ライセンス

Copyright 2025
