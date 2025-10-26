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
input long   InpMagicNumber = -1;               // マジックナンバー（-1=全て）
input ENUM_PERIOD_FILTER InpPeriod = PERIOD_ALL; // 表示期間
input double InpCashbackPer001Lot = 10.0;       // 0.01ロットあたりのキャッシュバック（円）
input int    InpChartWidth = 1200;              // チャート幅（ピクセル）
input int    InpChartHeight = 800;              // チャート高さ（ピクセル）
input int    InpChartX = 50;                    // チャートX位置（右からのピクセル）
input int    InpChartY = 180;                   // チャートY位置（上からのピクセル）
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
long g_currentMagicNumber = -1;  // 現在選択中のマジックナンバー（-1=全て）
long g_magicNumbers[];  // 利用可能なマジックナンバーのリスト

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

//--- HTML出力ボタン
#define BTN_HTML  "ProfitChart_Btn_HTML"
#define BTN_OPEN_FOLDER  "ProfitChart_Btn_OpenFolder"

//--- 統計テーブルのラベル名
#define LBL_STATS_BASE "ProfitChart_Stats_"
#define LBL_STATS_BG "ProfitChart_Stats_BG"

//--- Windows API for opening files
#import "shell32.dll"
   int ShellExecuteW(int hwnd, string lpOperation, string lpFile, string lpParameters, string lpDirectory, int nShowCmd);
#import

//+------------------------------------------------------------------+
//| カスタムインジケーター初期化関数                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- シンボル名の設定
   g_symbol = (InpSymbol == "") ? _Symbol : InpSymbol;

   //--- 現在の期間を初期化
   g_currentPeriod = InpPeriod;

   //--- 現在のマジックナンバーを初期化
   g_currentMagicNumber = InpMagicNumber;

   //--- グラフィックオブジェクトの初期化
   if(!InitializeGraphic(g_graphic, InpChartX, InpChartY, InpChartWidth, InpChartHeight))
   {
      return(INIT_FAILED);
   }

   //--- 初期データ読み込み
   LoadTradeHistory();

   //--- マジックナンバー一覧を取得
   GetUniqueMagicNumbers();

   //--- ボタンを作成
   CreatePeriodButtons();
   CreateMagicNumberButtons();
   CreateHTMLButton();
   CreateFolderButton();

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
   DeleteHTMLButton();
   DeleteFolderButton();

   //--- 統計テーブルを削除
   DeleteStatsTable();

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
      g_currentMagicNumber,  // 現在選択中のマジックナンバーを使用
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
      g_currentMagicNumber,  // 現在選択中のマジックナンバーを使用
      InpShowCumulative,
      InpShowIndividual,
      InpShowCashback,
      g_currentPeriod  // 現在の期間を使用
   );

   //--- 統計テーブル更新
   CreateStatsTable();
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

      //--- HTMLボタンのクリック処理
      if(sparam == BTN_HTML)
      {
         GenerateAndOpenHTML();
      }

      //--- フォルダを開くボタンのクリック処理
      if(sparam == BTN_OPEN_FOLDER)
      {
         OpenReportsFolder();
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
   int start_y = InpChartY - 70;  // 上の行に配置

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

   // 取引履歴を選択
   datetime start_time = 0;  // 全期間
   datetime end_time = TimeCurrent();

   if(!HistorySelect(start_time, end_time))
   {
      Print("履歴の取得に失敗しました");
      return;
   }

   int total_deals = HistoryDealsTotal();

   // 全ての取引からマジックナンバーを抽出（0を含む）
   for(int i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      // シンボルチェック
      string deal_symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(deal_symbol != g_symbol) continue;

      // 決済取引のみ
      long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue;

      // マジックナンバーを取得
      long mn = HistoryDealGetInteger(ticket, DEAL_MAGIC);

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
   int start_x = InpChartX;  // 左端から開始
   int start_y = InpChartY - 35;  // 下の行に配置

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
   int line_height = 28;
   int font_size = 11;
   int padding = 10;
   color text_color = clrWhite;
   string font_name = "Arial";

   // 背景パネルを作成
   int panel_width = 350;
   int panel_height = 290;  // 高さを増やして新しい項目を追加
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
   ObjectSetInteger(0, LBL_STATS_BG, OBJPROP_ZORDER, 0);

   // テーブルヘッダー
   CreateLabel(LBL_STATS_BASE + "Header", "=== Statistics ===", x, y, font_size + 3, clrYellow, font_name);
   y += line_height + 5;

   // Net Profit (トータル損益)
   color net_color = (stats.net_profit >= 0) ? clrLime : clrRed;
   string net_text = "Net Profit: " + FormatNumberWithCommas(stats.net_profit);
   CreateLabel(LBL_STATS_BASE + "NetProfit", net_text, x, y, font_size, net_color, font_name);
   y += line_height;

   // Profit Factor
   string pf_text = StringFormat("Profit Factor: %.2f", stats.profit_factor);
   CreateLabel(LBL_STATS_BASE + "PF", pf_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // Max Drawdown
   string dd_text = "Max Drawdown: -" + FormatNumberWithCommas(stats.max_drawdown);
   CreateLabel(LBL_STATS_BASE + "DD", dd_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // Total Profit
   string profit_text = "Total Profit: " + FormatNumberWithCommas(stats.total_profit);
   CreateLabel(LBL_STATS_BASE + "Profit", profit_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // Total Loss
   string loss_text = "Total Loss: -" + FormatNumberWithCommas(stats.total_loss);
   CreateLabel(LBL_STATS_BASE + "Loss", loss_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // Trade Count
   string trades_text = "Trade Count: " + FormatNumberWithCommas((double)stats.trade_count);
   CreateLabel(LBL_STATS_BASE + "Trades", trades_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // Total Lots
   string lots_text = StringFormat("Total Lots: %.2f", stats.total_lots);
   CreateLabel(LBL_STATS_BASE + "Lots", lots_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // Total Commission
   string commission_text = "Commission: " + FormatNumberWithCommas(stats.total_commission);
   CreateLabel(LBL_STATS_BASE + "Commission", commission_text, x, y, font_size, text_color, font_name);
   y += line_height;

   // Total Swap
   string swap_text = "Swap: " + FormatNumberWithCommas(stats.total_swap);
   CreateLabel(LBL_STATS_BASE + "Swap", swap_text, x, y, font_size, text_color, font_name);
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
   ObjectSetInteger(0, name, OBJPROP_BACK, false);  // 前面に表示
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);  // 背景パネルより前面
}

//+------------------------------------------------------------------+
//| 統計情報テーブルを削除                                              |
//+------------------------------------------------------------------+
void DeleteStatsTable()
{
   ObjectDelete(0, LBL_STATS_BG);
   ObjectDelete(0, LBL_STATS_BASE + "Header");
   ObjectDelete(0, LBL_STATS_BASE + "NetProfit");
   ObjectDelete(0, LBL_STATS_BASE + "PF");
   ObjectDelete(0, LBL_STATS_BASE + "DD");
   ObjectDelete(0, LBL_STATS_BASE + "Profit");
   ObjectDelete(0, LBL_STATS_BASE + "Loss");
   ObjectDelete(0, LBL_STATS_BASE + "Trades");
   ObjectDelete(0, LBL_STATS_BASE + "Lots");
   ObjectDelete(0, LBL_STATS_BASE + "Commission");
   ObjectDelete(0, LBL_STATS_BASE + "Swap");
}

//+------------------------------------------------------------------+
//| HTML出力ボタンを作成                                               |
//+------------------------------------------------------------------+
void CreateHTMLButton()
{
   int btn_width = 120;
   int btn_height = 25;
   int x = InpChartX + InpChartWidth - btn_width - 10;  // チャートの右上
   int y = InpChartY - 70;  // 期間ボタンと同じ高さ

   CreateButton(BTN_HTML, "HTML Report", x, y, btn_width, btn_height);
   ObjectSetInteger(0, BTN_HTML, OBJPROP_BGCOLOR, clrDarkGreen);
}

//+------------------------------------------------------------------+
//| HTML出力ボタンを削除                                               |
//+------------------------------------------------------------------+
void DeleteHTMLButton()
{
   ObjectDelete(0, BTN_HTML);
}

//+------------------------------------------------------------------+
//| フォルダを開くボタンを作成                                          |
//+------------------------------------------------------------------+
void CreateFolderButton()
{
   int btn_width = 120;
   int btn_height = 25;
   int x = InpChartX + InpChartWidth - (btn_width * 2) - 20;  // HTML出力ボタンの左側
   int y = InpChartY - 70;  // 期間ボタンと同じ高さ

   CreateButton(BTN_OPEN_FOLDER, "Open Folder", x, y, btn_width, btn_height);
   ObjectSetInteger(0, BTN_OPEN_FOLDER, OBJPROP_BGCOLOR, clrDarkBlue);
}

//+------------------------------------------------------------------+
//| フォルダを開くボタンを削除                                          |
//+------------------------------------------------------------------+
void DeleteFolderButton()
{
   ObjectDelete(0, BTN_OPEN_FOLDER);
}

//+------------------------------------------------------------------+
//| Reportsフォルダを開く                                              |
//+------------------------------------------------------------------+
void OpenReportsFolder()
{
   string folder_path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\Reports";

   // フォルダが存在しない場合は作成
   if(!FolderCreate("Reports", FILE_COMMON))
   {
      int error_code = GetLastError();
      if(error_code != 0 && error_code != 5003)
      {
         Alert("Failed to create Reports folder: ", error_code);
         return;
      }
   }

   // エクスプローラーでフォルダを開く
   int result = ShellExecuteW(0, "open", folder_path, "", "", 1);
   if(result <= 32)
   {
      Alert("Failed to open folder.\nPath: " + folder_path);
   }
}

//+------------------------------------------------------------------+
//| Generate HTML report and open in browser                         |
//+------------------------------------------------------------------+
void GenerateAndOpenHTML()
{
   // Calculate statistics
   TradeStatistics stats;
   CalculateTradeStatistics(g_trades, stats, g_symbol, g_currentMagicNumber, g_currentPeriod);

   // Create Reports folder
   string folder = "Reports";
   if(!FolderCreate(folder, FILE_COMMON))
   {
      // Error code 5003 means folder already exists - that's OK
      int error_code = GetLastError();
      if(error_code != 0 && error_code != 5003)
      {
         Print("Folder creation error: ", error_code);
      }
   }

   // Generate filename (save in Reports folder)
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   StringReplace(timestamp, ":", "");
   StringReplace(timestamp, " ", "_");
   string filename = folder + "\\ProfitChart_Report_" + timestamp + ".html";
   string filepath = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + filename;

   // Generate HTML content
   string html = GenerateHTMLContent(stats);

   // Write to file
   int file_handle = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(file_handle == INVALID_HANDLE)
   {
      Alert("Failed to create HTML file: ", GetLastError());
      return;
   }

   FileWriteString(file_handle, html);
   FileClose(file_handle);

   Print("HTML report generated: ", filepath);

   // Open HTML file automatically in browser
   int result = ShellExecuteW(0, "open", filepath, "", "", 1);
   if(result <= 32)
   {
      // If failed to open, show path in alert
      Alert("HTML report generated.\nPlease open manually:\n" + filepath);
   }
   else
   {
      Alert("HTML report generated and opened in browser!");
   }
}

//+------------------------------------------------------------------+
//| Generate HTML content                                            |
//+------------------------------------------------------------------+
string GenerateHTMLContent(const TradeStatistics &stats)
{
   string html = "";

   html += "<!DOCTYPE html>\n";
   html += "<html lang='en'>\n";
   html += "<head>\n";
   html += "<meta charset='UTF-8'>\n";
   html += "<meta name='viewport' content='width=device-width, initial-scale=1.0'>\n";
   html += "<title>Profit Report - " + g_symbol + "</title>\n";
   html += "<script src='https://cdn.jsdelivr.net/npm/chart.js'></script>\n";
   html += "<style>\n";
   html += "* { margin: 0; padding: 0; box-sizing: border-box; }\n";
   html += "body { font-family: Arial, sans-serif; background: #1a1a1a; color: #fff; padding: 30px 40px; }\n";
   html += "h1 { color: #ffcc00; border-bottom: 2px solid #ffcc00; padding-bottom: 15px; margin-bottom: 10px; font-size: 32px; }\n";
   html += "h2 { color: #ffcc00; margin-top: 35px; margin-bottom: 20px; font-size: 24px; }\n";
   html += ".container { max-width: 1600px; margin: 0 auto; }\n";
   html += ".header-info { margin-bottom: 10px; color: #aaa; font-size: 14px; }\n";
   html += ".period-info { margin-bottom: 30px; color: #fff; font-size: 22px; font-weight: 500; }\n";
   html += ".stats-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px; margin: 20px 0; }\n";
   html += ".stat-card { background: #2a2a2a; padding: 18px; border-radius: 8px; border: 1px solid #444; text-align: center; }\n";
   html += ".stat-label { font-size: 13px; color: #aaa; margin-bottom: 8px; }\n";
   html += ".stat-value { font-size: 22px; font-weight: bold; color: #ffcc00; }\n";
   html += ".chart-container { background: #2a2a2a; padding: 25px; border-radius: 8px; margin: 20px 0; border: 1px solid #444; height: 500px; }\n";
   html += "canvas { max-height: 450px; }\n";
   html += ".table-container { margin: 20px 0; }\n";
   html += "table { width: 100%; border-collapse: collapse; background: #2a2a2a; }\n";
   html += "th { background: #333; color: #ffcc00; padding: 12px; text-align: left; border: 1px solid #444; font-size: 14px; }\n";
   html += "td { padding: 10px 12px; border: 1px solid #444; font-size: 13px; }\n";
   html += "tr:nth-child(even) { background: #252525; }\n";
   html += "tr:hover { background: #2f2f2f; }\n";
   html += ".profit { color: #00ff00; font-weight: 500; }\n";
   html += ".loss { color: #ff4444; font-weight: 500; }\n";
   html += "td:first-child { text-align: center; color: #aaa; }\n";
   html += "td:nth-child(3), td:nth-child(4) { text-align: right; font-family: 'Courier New', monospace; }\n";
   html += "</style>\n";
   html += "</head>\n";
   html += "<body>\n";
   html += "<div class='container'>\n";

   // Title
   string title = "Profit Report: " + g_symbol;
   if(g_currentMagicNumber == -1)
      title += " (ALL)";
   else
      title += " (MN:" + IntegerToString(g_currentMagicNumber) + ")";
   html += "<h1>" + title + "</h1>\n";

   // Add period information
   int trade_count = ArraySize(g_trades);
   if(trade_count > 0)
   {
      string start_date = TimeToString(g_trades[0].time, TIME_DATE);
      string end_date = TimeToString(g_trades[trade_count - 1].time, TIME_DATE);
      html += "<div class='period-info'>Period: " + start_date + " - " + end_date + "</div>\n";
   }

   html += "<div class='header-info'>Generated: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "</div>\n";

   // Statistics Cards
   html += "<h2>Statistics</h2>\n";
   html += "<div class='stats-grid'>\n";

   // Row 1: Main metrics
   html += "<div class='stat-card'>\n";
   html += "<div class='stat-label'>Net Profit</div>\n";
   string net_profit_class = (stats.net_profit >= 0) ? "profit" : "loss";
   html += "<div class='stat-value " + net_profit_class + "'>" + FormatNumberWithCommas(stats.net_profit) + "</div>\n";
   html += "</div>\n";

   html += "<div class='stat-card'>\n";
   html += "<div class='stat-label'>Profit Factor</div>\n";
   html += "<div class='stat-value'>" + DoubleToString(stats.profit_factor, 2) + "</div>\n";
   html += "</div>\n";

   html += "<div class='stat-card'>\n";
   html += "<div class='stat-label'>Max Drawdown</div>\n";
   html += "<div class='stat-value loss'>-" + FormatNumberWithCommas(stats.max_drawdown) + "</div>\n";
   html += "</div>\n";

   // Row 2: Profit/Loss details
   html += "<div class='stat-card'>\n";
   html += "<div class='stat-label'>Total Profit</div>\n";
   html += "<div class='stat-value profit'>" + FormatNumberWithCommas(stats.total_profit) + "</div>\n";
   html += "</div>\n";

   html += "<div class='stat-card'>\n";
   html += "<div class='stat-label'>Total Loss</div>\n";
   html += "<div class='stat-value loss'>-" + FormatNumberWithCommas(stats.total_loss) + "</div>\n";
   html += "</div>\n";

   html += "<div class='stat-card'>\n";
   html += "<div class='stat-label'>Trade Count</div>\n";
   html += "<div class='stat-value'>" + IntegerToString(stats.trade_count) + "</div>\n";
   html += "</div>\n";

   // Row 3: Volume and costs
   html += "<div class='stat-card'>\n";
   html += "<div class='stat-label'>Total Lots</div>\n";
   html += "<div class='stat-value'>" + DoubleToString(stats.total_lots, 2) + "</div>\n";
   html += "</div>\n";

   html += "<div class='stat-card'>\n";
   html += "<div class='stat-label'>Total Commission</div>\n";
   string commission_class = (stats.total_commission >= 0) ? "" : "loss";
   html += "<div class='stat-value " + commission_class + "'>" + FormatNumberWithCommas(stats.total_commission) + "</div>\n";
   html += "</div>\n";

   html += "<div class='stat-card'>\n";
   html += "<div class='stat-label'>Total Swap</div>\n";
   html += "<div class='stat-value'>" + FormatNumberWithCommas(stats.total_swap) + "</div>\n";
   html += "</div>\n";

   html += "</div>\n";

   // Chart
   html += "<h2>Profit Chart</h2>\n";
   html += "<div class='chart-container'>\n";
   html += "<canvas id='profitChart'></canvas>\n";
   html += "</div>\n";

   // Trade History Table
   html += "<h2>Trade History</h2>\n";
   html += "<div class='table-container'>\n";
   html += "<table>\n";
   html += "<thead>\n";
   html += "<tr>\n";
   html += "<th>#</th>\n";
   html += "<th>Date/Time</th>\n";
   html += "<th>Individual P/L</th>\n";
   html += "<th>Cumulative P/L</th>\n";
   html += "</tr>\n";
   html += "</thead>\n";
   html += "<tbody>\n";

   // Determine if we should show time based on period
   bool show_time = (g_currentPeriod == PERIOD_1D || g_currentPeriod == PERIOD_1W);
   int time_format = show_time ? (TIME_DATE|TIME_SECONDS) : TIME_DATE;

   for(int i = 0; i < trade_count && i < 1000; i++)  // Display up to 1000 trades
   {
      string profit_class = (g_trades[i].profit >= 0) ? "profit" : "loss";
      html += "<tr>\n";
      html += "<td>" + IntegerToString(i + 1) + "</td>\n";
      html += "<td>" + TimeToString(g_trades[i].time, time_format) + "</td>\n";
      html += "<td class='" + profit_class + "'>" + FormatNumberWithCommas(g_trades[i].profit) + "</td>\n";
      html += "<td>" + FormatNumberWithCommas(g_trades[i].cumulative) + "</td>\n";
      html += "</tr>\n";
   }

   html += "</tbody>\n";
   html += "</table>\n";
   html += "</div>\n";

   // Chart.js script
   html += "<script>\n";
   html += "const ctx = document.getElementById('profitChart').getContext('2d');\n";
   html += "const chart = new Chart(ctx, {\n";
   html += "  type: 'line',\n";
   html += "  data: {\n";
   html += "    labels: [";

   // X-axis labels (trade index)
   for(int i = 0; i < trade_count; i++)
   {
      if(i > 0) html += ", ";
      html += "'" + IntegerToString(i + 1) + "'";
   }
   html += "],\n";

   html += "    datasets: [{\n";
   html += "      label: 'Cumulative P/L',\n";
   html += "      data: [";

   // Y-axis data (cumulative P/L)
   for(int i = 0; i < trade_count; i++)
   {
      if(i > 0) html += ", ";
      html += DoubleToString(g_trades[i].cumulative, 2);
   }
   html += "],\n";

   html += "      borderColor: '#ffcc00',\n";
   html += "      backgroundColor: 'rgba(255, 204, 0, 0.1)',\n";
   html += "      borderWidth: 2,\n";
   html += "      fill: true,\n";
   html += "      tension: 0.1\n";
   html += "    }]\n";
   html += "  },\n";
   html += "  options: {\n";
   html += "    responsive: true,\n";
   html += "    maintainAspectRatio: false,\n";
   html += "    plugins: {\n";
   html += "      legend: { labels: { color: '#fff' } },\n";
   html += "      title: { display: false },\n";
   html += "      tooltip: {\n";
   html += "        callbacks: {\n";
   html += "          title: function(context) {\n";
   html += "            const dates = [";

   // Add date/time array for tooltip
   for(int i = 0; i < trade_count; i++)
   {
      if(i > 0) html += ", ";
      html += "'" + TimeToString(g_trades[i].time, TIME_DATE|TIME_SECONDS) + "'";
   }

   html += "];\n";
   html += "            return 'Trade #' + context[0].label + ' - ' + dates[context[0].dataIndex];\n";
   html += "          },\n";
   html += "          label: function(context) {\n";
   html += "            return 'Cumulative P/L: ' + context.parsed.y.toLocaleString();\n";
   html += "          }\n";
   html += "        }\n";
   html += "      }\n";
   html += "    },\n";
   html += "    scales: {\n";
   html += "      x: {\n";
   html += "        title: { display: true, text: 'Trade Number', color: '#fff' },\n";
   html += "        ticks: { color: '#aaa', maxRotation: 45, minRotation: 45 },\n";
   html += "        grid: { color: '#333' }\n";
   html += "      },\n";
   html += "      y: {\n";
   html += "        title: { display: true, text: 'Profit/Loss', color: '#fff' },\n";
   html += "        ticks: { color: '#aaa' },\n";
   html += "        grid: { color: '#333' }\n";
   html += "      }\n";
   html += "    }\n";
   html += "  }\n";
   html += "});\n";
   html += "</script>\n";

   html += "</div>\n";
   html += "</body>\n";
   html += "</html>\n";

   return html;
}
//+------------------------------------------------------------------+
