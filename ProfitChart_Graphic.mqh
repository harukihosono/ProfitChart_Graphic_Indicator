//+------------------------------------------------------------------+
//|                                        ProfitChart_Graphic.mqh   |
//|                          グラフィック表示ロジック（MT4/MT5共通）    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""

#include "ProfitChart_Common.mqh"

#ifdef __MQL5__
   #include "Graphic.mqh"
#else
   #include "ProfitChart_Canvas_MT4.mqh"
#endif

#ifdef __MQL5__
//+------------------------------------------------------------------+
//| グラフィック初期化（MT5版）                                        |
//+------------------------------------------------------------------+
bool InitializeGraphic(
   CGraphic &graphic,
   const int chart_x,
   const int chart_y,
   const int chart_width,
   const int chart_height
)
{
   //--- グラフィックオブジェクトの作成
   if(!graphic.Create(0, "ProfitChart", 0, chart_x, chart_y, chart_width, chart_height))
   {
      Print("グラフィックオブジェクトの作成に失敗");
      return false;
   }

   //--- グラフの余白を調整（Y軸を右側に表示するため）
   graphic.IndentLeft(30);    // 左余白を小さく
   graphic.IndentRight(200);  // 右余白を大きく（Y軸用）
   graphic.IndentUp(50);
   graphic.IndentDown(100);   // 下余白を大きく（X軸の回転した文字用）

   //--- グラフの初期設定（背景黒、文字白）
   graphic.BackgroundMain("");  // タイトルは後で設定
   graphic.BackgroundColor(ColorToARGB(clrBlack, 255));
   graphic.BackgroundMainSize(24);  // タイトル文字サイズ
   graphic.BackgroundMainColor(ColorToARGB(clrWhite, 255));  // タイトル文字色を白に

   //--- プロット領域（グリッド）の背景を黒に設定
   graphic.GridBackgroundColor(ColorToARGB(clrBlack, 255));

   //--- グリッド線を暗いグレーに設定（目立たなくする）
   graphic.GridLineColor(ColorToARGB(clrDarkSlateGray, 100));  // 半透明の暗いグレー
   graphic.GridAxisLineColor(ColorToARGB(clrWhite, 255));  // 軸線は白

   //--- 目盛りマーク（■-）を非表示
   graphic.MajorMarkSize(0);

   //--- 軸の設定（Color()が軸線・数値・名前すべての色を制御）
   CAxis *x_axis = graphic.XAxis();
   CAxis *y_axis = graphic.YAxis();

   x_axis.Color(ColorToARGB(clrWhite, 255));  // X軸全体の色を白に
   y_axis.Color(ColorToARGB(clrWhite, 255));  // Y軸全体の色を白に
   x_axis.ValuesSize(20);  // X軸目盛り文字サイズ
   y_axis.ValuesSize(20);  // Y軸目盛り文字サイズ
   x_axis.NameSize(22);    // X軸名文字サイズ
   y_axis.NameSize(22);    // Y軸名文字サイズ

   //--- X軸の目盛りを270度回転（縦向き）
   x_axis.ValuesFontAngle(2700);  // 270度 = 縦書き

   //--- Y軸の目盛り幅を広げる（省略されないように）
   y_axis.ValuesWidth(100);  // デフォルト30から100に拡大

   //--- X軸を日時表示に設定
   x_axis.Type(AXIS_TYPE_DATETIME);
   x_axis.ValuesDateTimeMode(TIME_DATE);  // 日付のみ表示（時刻なし）
   x_axis.DefaultStep(604800);  // 1週間間隔でラベル表示（秒単位：7日×24時間×60分×60秒）

   return true;
}

//+------------------------------------------------------------------+
//| チャートを更新                                                      |
//+------------------------------------------------------------------+
void UpdateGraphicChart(
   CGraphic &graphic,
   const TradeData &trades[],
   const string symbol,
   const long magic_number,
   const bool show_cumulative,
   const bool show_individual,
   const bool show_cashback,
   ENUM_PERIOD_FILTER period
)
{
   int trade_count = ArraySize(trades);
   if(trade_count == 0)
   {
      //--- データがない場合は空のチャートを表示
      graphic.CurvePlotAll();
      graphic.Update();
      return;
   }

   //--- X軸用配列（時間）
   double x_data[];
   ArrayResize(x_data, trade_count);

   //--- Y軸用配列
   double y_cumulative[];
   double y_individual[];
   ArrayResize(y_cumulative, trade_count);
   ArrayResize(y_individual, trade_count);

   //--- データを配列にコピー（X軸は時間）
   for(int i = 0; i < trade_count; i++)
   {
      x_data[i] = (double)trades[i].time;  // 時間を使用
      y_cumulative[i] = trades[i].cumulative;

      double profit_val = show_cashback ?
         (trades[i].profit + trades[i].cashback) :
         trades[i].profit;
      y_individual[i] = profit_val;
   }

   //--- 既存の曲線を削除
   int curve_total = graphic.CurvesTotal();
   for(int i = curve_total - 1; i >= 0; i--)
      graphic.CurveRemoveByIndex(i);

   //--- 個別損益（棒グラフ）を追加
   if(show_individual)
   {
      CCurve *curve_bars = graphic.CurveAdd(x_data, y_individual, ColorToARGB(clrDarkGray), CURVE_HISTOGRAM, "個別損益");
      if(curve_bars != NULL)
      {
         curve_bars.HistogramWidth(8);
      }
   }

   //--- 累積損益（折れ線グラフ）を追加 - 黄色
   if(show_cumulative)
   {
      CCurve *curve_line = graphic.CurveAdd(x_data, y_cumulative, ColorToARGB(clrYellow), CURVE_LINES, "累積損益");
      if(curve_line != NULL)
      {
         curve_line.LinesWidth(3);  // 線を太く
      }
   }

   //--- グラフタイトル
   string title = "損益チャート: " + symbol;
   if(magic_number == -1)
      title += " (ALL)";
   else
      title += " (MN:" + IntegerToString(magic_number) + ")";
   if(show_cashback)
      title += " [CB込]";

   graphic.BackgroundMain(title);  // タイトルを設定

   //--- X軸とY軸のラベル
   graphic.XAxis().Name("");        // X軸の名前を非表示
   graphic.YAxis().Name("");        // Y軸の名前を非表示

   //--- チャートを描画
   graphic.CurvePlotAll();
   graphic.Update();
}
#endif // __MQL5__

#ifdef __MQL4__
//+------------------------------------------------------------------+
//| グラフィック初期化（MT4版）                                        |
//+------------------------------------------------------------------+
bool InitializeGraphic(
   CProfitChartCanvas &canvas,
   const int chart_x,
   const int chart_y,
   const int chart_width,
   const int chart_height
)
{
   if(!canvas.Create("ProfitChart", chart_x, chart_y, chart_width, chart_height))
   {
      Print("Canvasオブジェクトの作成に失敗");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| チャートを更新（MT4版）                                             |
//+------------------------------------------------------------------+
void UpdateGraphicChart(
   CProfitChartCanvas &canvas,
   const TradeData &trades[],
   const string symbol,
   const long magic_number,
   const bool show_cumulative,
   const bool show_individual,
   const bool show_cashback,
   ENUM_PERIOD_FILTER period
)
{
   canvas.DrawChart(trades, symbol, magic_number, show_cumulative, show_individual, show_cashback);
}
#endif // __MQL4__
//+------------------------------------------------------------------+
