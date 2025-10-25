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
ENUM_PERIOD_FILTER g_currentPeriod = PERIOD_ALL;  // 現在の表示期間

//--- ボタン名の定数
#define BTN_1D    "ProfitChart_Btn_1D"
#define BTN_1W    "ProfitChart_Btn_1W"
#define BTN_1M    "ProfitChart_Btn_1M"
#define BTN_3M    "ProfitChart_Btn_3M"
#define BTN_6M    "ProfitChart_Btn_6M"
#define BTN_1Y    "ProfitChart_Btn_1Y"
#define BTN_ALL   "ProfitChart_Btn_ALL"

//+------------------------------------------------------------------+
//| カスタムインジケーター初期化関数                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- シンボル名の設定
   g_symbol = (InpSymbol == "") ? _Symbol : InpSymbol;

   //--- 現在の期間を初期化
   g_currentPeriod = InpPeriod;

   //--- グラフィックオブジェクトの初期化
   if(!InitializeGraphic(g_graphic, InpChartX, InpChartY, InpChartWidth, InpChartHeight))
   {
      return(INIT_FAILED);
   }

   //--- ボタンを作成
   CreatePeriodButtons();

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
   //--- ボタンを削除
   DeletePeriodButtons();

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
      g_currentPeriod,  // 現在の期間を使用
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
//| チャートイベントハンドラ                                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   //--- ボタンクリックイベント
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      ENUM_PERIOD_FILTER new_period = g_currentPeriod;

      if(sparam == BTN_1D)       new_period = PERIOD_1D;
      else if(sparam == BTN_1W)  new_period = PERIOD_1W;
      else if(sparam == BTN_1M)  new_period = PERIOD_1M;
      else if(sparam == BTN_3M)  new_period = PERIOD_3M;
      else if(sparam == BTN_6M)  new_period = PERIOD_6M;
      else if(sparam == BTN_1Y)  new_period = PERIOD_12M;
      else if(sparam == BTN_ALL) new_period = PERIOD_ALL;

      //--- 期間が変更された場合
      if(new_period != g_currentPeriod)
      {
         g_currentPeriod = new_period;
         UpdateButtonStates();
         LoadTradeHistory();
         UpdateChart();
      }

      //--- ボタンの選択状態をリセット
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| 期間切り替えボタンを作成                                            |
//+------------------------------------------------------------------+
void CreatePeriodButtons()
{
   int btn_width = 60;
   int btn_height = 25;
   int btn_spacing = 5;
   int start_x = InpChartX;
   int start_y = InpChartY - 35;

   CreateButton(BTN_1D,   "1D",   start_x + (btn_width + btn_spacing) * 0, start_y, btn_width, btn_height);
   CreateButton(BTN_1W,   "1W",   start_x + (btn_width + btn_spacing) * 1, start_y, btn_width, btn_height);
   CreateButton(BTN_1M,   "1M",   start_x + (btn_width + btn_spacing) * 2, start_y, btn_width, btn_height);
   CreateButton(BTN_3M,   "3M",   start_x + (btn_width + btn_spacing) * 3, start_y, btn_width, btn_height);
   CreateButton(BTN_6M,   "6M",   start_x + (btn_width + btn_spacing) * 4, start_y, btn_width, btn_height);
   CreateButton(BTN_1Y,   "1Y",   start_x + (btn_width + btn_spacing) * 5, start_y, btn_width, btn_height);
   CreateButton(BTN_ALL,  "ALL",  start_x + (btn_width + btn_spacing) * 6, start_y, btn_width, btn_height);

   UpdateButtonStates();
}

//+------------------------------------------------------------------+
//| ボタンを作成                                                       |
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y, int width, int height)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrDarkSlateGray);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| ボタンの状態を更新                                                 |
//+------------------------------------------------------------------+
void UpdateButtonStates()
{
   string buttons[] = {BTN_1D, BTN_1W, BTN_1M, BTN_3M, BTN_6M, BTN_1Y, BTN_ALL};
   ENUM_PERIOD_FILTER periods[] = {PERIOD_1D, PERIOD_1W, PERIOD_1M, PERIOD_3M, PERIOD_6M, PERIOD_12M, PERIOD_ALL};

   for(int i = 0; i < ArraySize(buttons); i++)
   {
      color bg_color = (periods[i] == g_currentPeriod) ? clrGreen : clrDarkSlateGray;
      ObjectSetInteger(0, buttons[i], OBJPROP_BGCOLOR, bg_color);
   }
}

//+------------------------------------------------------------------+
//| ボタンを削除                                                       |
//+------------------------------------------------------------------+
void DeletePeriodButtons()
{
   ObjectDelete(0, BTN_1D);
   ObjectDelete(0, BTN_1W);
   ObjectDelete(0, BTN_1M);
   ObjectDelete(0, BTN_3M);
   ObjectDelete(0, BTN_6M);
   ObjectDelete(0, BTN_1Y);
   ObjectDelete(0, BTN_ALL);
}
//+------------------------------------------------------------------+
