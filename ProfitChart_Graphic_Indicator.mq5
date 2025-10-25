//+------------------------------------------------------------------+
//|                                           ProfitChart_Graphic.mq5 |
//|                          CGraphicを使った独立損益チャート           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- 共通ヘッダーファイルをインクルード
#include "ProfitChart_Common.mqh"
#include "ProfitChart_HistoryLoader.mqh"
#include "ProfitChart_Graphic.mqh"

//--- 入力パラメータ
input string InpSymbol = "";                    // 対象シンボル（空欄=現在のシンボル）
input long   InpMagicNumber = 0;                // マジックナンバー（0=全て）
input ENUM_PERIOD_FILTER InpPeriod = PERIOD_ALL; // 表示期間
input double InpCashbackPer001Lot = 10.0;       // 0.01ロットあたりのキャッシュバック（円）
input int    InpChartWidth = 1200;              // チャート幅（ピクセル）
input int    InpChartHeight = 800;              // チャート高さ（ピクセル）
input int    InpChartX = 50;                    // チャートX位置（右からのピクセル）
input int    InpChartY = 50;                    // チャートY位置（上からのピクセル）
input bool   InpShowCumulative = true;          // 累積損益を表示
input bool   InpShowIndividual = true;          // 個別損益を表示
input bool   InpShowCashback = false;           // キャッシュバック込みで表示

//--- グローバル変数
CGraphic g_graphic;
string g_symbol;
datetime g_lastUpdate = 0;
int g_lastDealCount = 0;
TradeData g_trades[];

//+------------------------------------------------------------------+
//| カスタムインジケーター初期化関数                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- シンボル名の設定
   g_symbol = (InpSymbol == "") ? _Symbol : InpSymbol;

   //--- グラフィックオブジェクトの初期化
   if(!InitializeGraphic(g_graphic, InpChartX, InpChartY, InpChartWidth, InpChartHeight))
   {
      return(INIT_FAILED);
   }

   //--- 初期データ読み込み
   LoadTradeHistory();
   UpdateChart();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| カスタムインジケーター終了関数                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- グラフィックオブジェクトの削除
   g_graphic.Destroy();
}

//+------------------------------------------------------------------+
//| カスタムインジケーター計算関数                                        |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //--- 定期的に更新（5秒ごと）
   datetime current_time = TimeCurrent();
   if(current_time - g_lastUpdate >= 5)
   {
      LoadTradeHistory();
      UpdateChart();
      g_lastUpdate = current_time;
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| 取引履歴を読み込む                                                   |
//+------------------------------------------------------------------+
void LoadTradeHistory()
{
   LoadTradeHistoryMT5(
      g_trades,
      g_symbol,
      InpMagicNumber,
      InpPeriod,
      InpCashbackPer001Lot,
      InpShowCashback,
      g_lastDealCount
   );
}

//+------------------------------------------------------------------+
//| チャートを更新                                                      |
//+------------------------------------------------------------------+
void UpdateChart()
{
   UpdateGraphicChart(
      g_graphic,
      g_trades,
      g_symbol,
      InpMagicNumber,
      InpShowCumulative,
      InpShowIndividual,
      InpShowCashback
   );
}
//+------------------------------------------------------------------+
