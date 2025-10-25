//+------------------------------------------------------------------+
//|                                    ProfitChart_Graphic_MT4.mq4 |
//|                          CCanvasを使った独立損益チャート (MT4版) |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""
#property version   "1.00"
#property indicator_chart_window
#property strict

//--- 共通ヘッダーファイルをインクルード
#include "ProfitChart_Common.mqh"
#include "ProfitChart_HistoryLoader_MT4.mqh"
#include "ProfitChart_Canvas_MT4.mqh"

//--- 入力パラメータ
input string InpSymbol = "";                    // 対象シンボル（空欄=現在のシンボル）
input long   InpMagicNumber = -1;               // マジックナンバー（-1=全て）
input ENUM_PERIOD_FILTER InpPeriod = PERIOD_ALL; // 表示期間
input double InpCashbackPer001Lot = 10.0;       // 0.01ロットあたりのキャッシュバック（円）
input int    InpChartWidth = 1200;              // チャート幅（ピクセル）
input int    InpChartHeight = 800;              // チャート高さ（ピクセル）
input int    InpChartX = 50;                    // チャートX位置（左からのピクセル）
input int    InpChartY = 80;                    // チャートY位置（上からのピクセル）
input bool   InpShowCumulative = true;          // 累積損益を表示
input bool   InpShowIndividual = true;          // 個別損益を表示
input bool   InpShowCashback = false;           // キャッシュバック込みで表示

//--- グローバル変数
CProfitChartCanvas g_chart;
string g_symbol;
datetime g_lastUpdate = 0;
int g_lastDealCount = 0;
TradeData g_trades[];
ENUM_PERIOD_FILTER g_currentPeriod = PERIOD_ALL;
long g_currentMagicNumber = -1;
long g_magicNumbers[];

//--- ボタン名の定数（期間）
#define BTN_1D    "ProfitChart_Btn_1D"
#define BTN_1W    "ProfitChart_Btn_1W"
#define BTN_1M    "ProfitChart_Btn_1M"
#define BTN_3M    "ProfitChart_Btn_3M"
#define BTN_6M    "ProfitChart_Btn_6M"
#define BTN_1Y    "ProfitChart_Btn_1Y"
#define BTN_ALL   "ProfitChart_Btn_ALL"

//--- ボタン名の定数（マジックナンバー）
#define BTN_MN_PREFIX  "ProfitChart_Btn_MN_"

//--- 統計テーブルのラベル名
#define LBL_STATS_BASE "ProfitChart_Stats_"
#define LBL_STATS_BG "ProfitChart_Stats_BG"

//+------------------------------------------------------------------+
//| カスタムインジケーター初期化関数                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- シンボル名の設定
   g_symbol = (InpSymbol == "") ? Symbol() : InpSymbol;

   //--- 現在の期間を初期化
   g_currentPeriod = InpPeriod;

   //--- 現在のマジックナンバーを初期化
   g_currentMagicNumber = InpMagicNumber;

   //--- Canvasチャートの初期化
   if(!g_chart.Create("ProfitChart_Canvas", InpChartX, InpChartY, InpChartWidth, InpChartHeight))
   {
      Print("Canvasの作成に失敗しました");
      return(INIT_FAILED);
   }

   //--- 初期データ読み込み
   LoadTradeHistory();

   //--- マジックナンバー一覧を取得
   GetUniqueMagicNumbers();

   //--- ボタンを作成
   CreatePeriodButtons();
   CreateMagicNumberButtons();

   //--- チャート更新
   UpdateChart();

   //--- 統計テーブル作成
   CreateStatsTable();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| カスタムインジケーター終了関数                                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- ボタンを削除
   DeletePeriodButtons();
   DeleteMagicNumberButtons();

   //--- 統計テーブルを削除
   DeleteStatsTable();

   //--- Canvasチャートの削除
   g_chart.Destroy();
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

      //--- マジックナンバーボタンのクリック処理
      if(StringFind(sparam, BTN_MN_PREFIX) == 0)
      {
         string mn_str = StringSubstr(sparam, StringLen(BTN_MN_PREFIX));
         long new_magic_number = StringToInteger(mn_str);

         if(new_magic_number != g_currentMagicNumber)
         {
            g_currentMagicNumber = new_magic_number;
            UpdateMagicNumberButtonStates();
            LoadTradeHistory();
            UpdateChart();
         }
      }

      //--- ボタンの選択状態をリセット
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| 取引履歴を読み込む                                                   |
//+------------------------------------------------------------------+
void LoadTradeHistory()
{
   LoadTradeHistoryMT4(
      g_trades,
      g_symbol,
      g_currentMagicNumber,
      g_currentPeriod,
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
   g_chart.DrawChart(
      g_trades,
      g_symbol,
      g_currentMagicNumber,
      InpShowCumulative,
      InpShowIndividual,
      InpShowCashback
   );

   //--- 統計テーブル更新
   CreateStatsTable();
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
//| 取引履歴から一意のマジックナンバーを取得                              |
//+------------------------------------------------------------------+
void GetUniqueMagicNumbers()
{
   ArrayResize(g_magicNumbers, 0);

   // 常に「ALL (-1)」を最初に追加
   ArrayResize(g_magicNumbers, 1);
   g_magicNumbers[0] = -1;

   int total_orders = OrdersHistoryTotal();

   // 全ての取引からマジックナンバーを抽出
   for(int i = 0; i < total_orders; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      // シンボルチェック
      if(OrderSymbol() != g_symbol)
         continue;

      // 決済注文のみ
      if(OrderCloseTime() == 0)
         continue;

      // マジックナンバーを取得
      long mn = OrderMagicNumber();

      // すでにリストにあるかチェック
      bool exists = false;
      for(int j = 0; j < ArraySize(g_magicNumbers); j++)
      {
         if(g_magicNumbers[j] == mn)
         {
            exists = true;
            break;
         }
      }

      if(!exists)
      {
         int size = ArraySize(g_magicNumbers);
         ArrayResize(g_magicNumbers, size + 1);
         g_magicNumbers[size] = mn;
      }
   }
}

//+------------------------------------------------------------------+
//| マジックナンバー選択ボタンを作成                                     |
//+------------------------------------------------------------------+
void CreateMagicNumberButtons()
{
   int btn_width = 120;
   int btn_height = 25;
   int btn_spacing = 5;
   int start_x = InpChartX + 540;
   int start_y = InpChartY - 35;

   int count = ArraySize(g_magicNumbers);
   for(int i = 0; i < count; i++)
   {
      string btn_name = BTN_MN_PREFIX + IntegerToString(g_magicNumbers[i]);
      string btn_text = (g_magicNumbers[i] == -1) ? "ALL" : "MN:" + IntegerToString(g_magicNumbers[i]);
      int x = start_x + (btn_width + btn_spacing) * i;

      CreateButton(btn_name, btn_text, x, start_y, btn_width, btn_height);
   }

   UpdateMagicNumberButtonStates();
}

//+------------------------------------------------------------------+
//| マジックナンバーボタンの状態を更新                                   |
//+------------------------------------------------------------------+
void UpdateMagicNumberButtonStates()
{
   int count = ArraySize(g_magicNumbers);
   for(int i = 0; i < count; i++)
   {
      string btn_name = BTN_MN_PREFIX + IntegerToString(g_magicNumbers[i]);
      color bg_color = (g_magicNumbers[i] == g_currentMagicNumber) ? clrBlue : clrDarkSlateGray;
      ObjectSetInteger(0, btn_name, OBJPROP_BGCOLOR, bg_color);
   }
}

//+------------------------------------------------------------------+
//| マジックナンバーボタンを削除                                         |
//+------------------------------------------------------------------+
void DeleteMagicNumberButtons()
{
   int count = ArraySize(g_magicNumbers);
   for(int i = 0; i < count; i++)
   {
      string btn_name = BTN_MN_PREFIX + IntegerToString(g_magicNumbers[i]);
      ObjectDelete(0, btn_name);
   }
}

//+------------------------------------------------------------------+
//| 統計情報テーブルを作成                                              |
//+------------------------------------------------------------------+
void CreateStatsTable()
{
   // 統計情報を計算
   TradeStatistics stats;
   CalculateTradeStatistics(g_trades, stats, g_symbol, g_currentMagicNumber, g_currentPeriod);

   // チャートの右側に配置
   int x = InpChartX + InpChartWidth + 30;
   int y = InpChartY + 50;
   int line_height = 30;
   int font_size = 11;
   int padding = 10;
   color text_color = clrWhite;
   string font_name = "Arial";

   // 背景パネルを作成
   int panel_width = 350;
   int panel_height = 230;
   ObjectDelete(0, LBL_STATS_BG);
   ObjectCreate(0, LBL_STATS_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_XDISTANCE, x - padding);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_YDISTANCE, y - padding);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_XSIZE, panel_width);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_YSIZE, panel_height);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_BACK, false);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_HIDDEN, true);

   // テーブルヘッダー
   CreateLabel(LBL_STATS_BASE + "Header", "=== 統計情報 ===", x, y, font_size + 3, clrYellow, font_name);
   y += line_height + 5;

   // PF (Profit Factor)
   string pf_text = StringFormat("Profit Factor: %.2f", stats.profit_factor);
   CreateLabel(LBL_STATS_BASE + "PF", pf_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // 最大DD（マイナス表示、カンマ区切り）
   string dd_text = "Max Drawdown: -" + FormatNumberWithCommas(stats.max_drawdown);
   CreateLabel(LBL_STATS_BASE + "DD", dd_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // 総ロット数
   string lots_text = StringFormat("Total Lots: %.2f", stats.total_lots);
   CreateLabel(LBL_STATS_BASE + "Lots", lots_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // 取引回数（カンマ区切り）
   string trades_text = "Trade Count: " + FormatNumberWithCommas((double)stats.trade_count);
   CreateLabel(LBL_STATS_BASE + "Trades", trades_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // 総利益（カンマ区切り）
   string profit_text = "Total Profit: " + FormatNumberWithCommas(stats.total_profit);
   CreateLabel(LBL_STATS_BASE + "Profit", profit_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // 総損失（マイナス表示、カンマ区切り）
   string loss_text = "Total Loss: -" + FormatNumberWithCommas(stats.total_loss);
   CreateLabel(LBL_STATS_BASE + "Loss", loss_text, x, y, font_size, text_color, font_name);
}

//+------------------------------------------------------------------+
//| ラベルオブジェクトを作成                                            |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, int font_size, color clr, string font)
{
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| 統計情報テーブルを削除                                              |
//+------------------------------------------------------------------+
void DeleteStatsTable()
{
   ObjectDelete(0, LBL_STATS_BG);
   ObjectDelete(0, LBL_STATS_BASE + "Header");
   ObjectDelete(0, LBL_STATS_BASE + "PF");
   ObjectDelete(0, LBL_STATS_BASE + "DD");
   ObjectDelete(0, LBL_STATS_BASE + "Lots");
   ObjectDelete(0, LBL_STATS_BASE + "Trades");
   ObjectDelete(0, LBL_STATS_BASE + "Profit");
   ObjectDelete(0, LBL_STATS_BASE + "Loss");
}
//+------------------------------------------------------------------+
