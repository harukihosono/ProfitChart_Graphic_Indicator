//+------------------------------------------------------------------+
//|                                       ProfitChart_Canvas_MT4.mqh |
//|                          MT4用CCanvasチャート描画                  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""

#include <Canvas\Canvas.mqh>

//+------------------------------------------------------------------+
//| カンマ区切りフォーマット関数                                        |
//+------------------------------------------------------------------+
string FormatNumberWithCommas(double value)
{
   string result = "";
   string num_str = DoubleToString(value, 0);
   int len = StringLen(num_str);
   int count = 0;

   // 負の数の処理
   bool is_negative = false;
   if(StringSubstr(num_str, 0, 1) == "-")
   {
      is_negative = true;
      num_str = StringSubstr(num_str, 1);
      len = StringLen(num_str);
   }

   // 右から左にカンマを挿入
   for(int i = len - 1; i >= 0; i--)
   {
      if(count == 3)
      {
         result = "," + result;
         count = 0;
      }
      result = StringSubstr(num_str, i, 1) + result;
      count++;
   }

   if(is_negative)
      result = "-" + result;

   return result;
}

//+------------------------------------------------------------------+
//| Canvasベースのチャートクラス                                        |
//+------------------------------------------------------------------+
class CProfitChartCanvas
{
private:
   CCanvas           m_canvas;
   int               m_x;
   int               m_y;
   int               m_width;
   int               m_height;

   // チャート領域のマージン
   int               m_margin_left;
   int               m_margin_right;
   int               m_margin_top;
   int               m_margin_bottom;

   // データ範囲
   double            m_min_value;
   double            m_max_value;
   datetime          m_min_time;
   datetime          m_max_time;

public:
   //--- コンストラクタ
   CProfitChartCanvas()
   {
      m_margin_left = 60;
      m_margin_right = 100;
      m_margin_top = 60;
      m_margin_bottom = 80;
   }

   //--- デストラクタ
   ~CProfitChartCanvas()
   {
      Destroy();
   }

   //--- 初期化
   bool Create(string name, int x, int y, int width, int height)
   {
      m_x = x;
      m_y = y;
      m_width = width;
      m_height = height;

      if(!m_canvas.CreateBitmapLabel(name, x, y, width, height, COLOR_FORMAT_ARGB_NORMALIZE))
         return false;

      return true;
   }

   //--- 破棄
   void Destroy()
   {
      m_canvas.Destroy();
   }

   //--- チャートを描画
   void DrawChart(
      const TradeData &trades[],
      const string symbol,
      const long magic_number,
      const bool show_cumulative,
      const bool show_individual,
      const bool show_cashback
   )
   {
      int trade_count = ArraySize(trades);
      if(trade_count == 0)
      {
         DrawEmptyChart();
         return;
      }

      // 背景をクリア
      m_canvas.Erase(ColorToARGB(clrBlack, 255));

      // データ範囲を計算
      CalculateDataRange(trades);

      // グリッドと軸を描画
      DrawGrid();
      DrawAxes();

      // データを描画
      if(show_cumulative)
         DrawCumulativeLine(trades, show_cashback);

      if(show_individual)
         DrawIndividualBars(trades, show_cashback);

      // タイトルを描画
      DrawTitle(symbol, magic_number, show_cashback);

      // 更新
      m_canvas.Update();
   }

private:
   //--- データ範囲を計算
   void CalculateDataRange(const TradeData &trades[])
   {
      int count = ArraySize(trades);
      if(count == 0) return;

      m_min_time = trades[0].time;
      m_max_time = trades[count-1].time;

      m_min_value = trades[0].cumulative;
      m_max_value = trades[0].cumulative;

      for(int i = 1; i < count; i++)
      {
         if(trades[i].cumulative < m_min_value)
            m_min_value = trades[i].cumulative;
         if(trades[i].cumulative > m_max_value)
            m_max_value = trades[i].cumulative;
      }

      // マージンを追加
      double range = m_max_value - m_min_value;
      if(range < 1.0) range = 1.0;
      m_min_value -= range * 0.1;
      m_max_value += range * 0.1;
   }

   //--- 座標変換（時間 -> X座標）
   int TimeToX(datetime time)
   {
      if(m_max_time == m_min_time) return m_margin_left;

      double ratio = (double)(time - m_min_time) / (double)(m_max_time - m_min_time);
      int chart_width = m_width - m_margin_left - m_margin_right;
      return m_margin_left + (int)(ratio * chart_width);
   }

   //--- 座標変換（値 -> Y座標）
   int ValueToY(double value)
   {
      if(m_max_value == m_min_value) return m_height / 2;

      double ratio = (value - m_min_value) / (m_max_value - m_min_value);
      int chart_height = m_height - m_margin_top - m_margin_bottom;
      return m_height - m_margin_bottom - (int)(ratio * chart_height);
   }

   //--- グリッドを描画
   void DrawGrid()
   {
      uint grid_color = ColorToARGB(clrDarkSlateGray, 100);

      // 横線（Y軸グリッド）
      int num_h_lines = 8;
      int hi;
      for(hi = 0; hi <= num_h_lines; hi++)
      {
         double value = m_min_value + (m_max_value - m_min_value) * hi / num_h_lines;
         int y = ValueToY(value);
         m_canvas.Line(m_margin_left, y, m_width - m_margin_right, y, grid_color);
      }

      // 縦線（X軸グリッド）
      int num_v_lines = 10;
      int vi;
      for(vi = 0; vi <= num_v_lines; vi++)
      {
         datetime time = m_min_time + (datetime)((m_max_time - m_min_time) * vi / num_v_lines);
         int x = TimeToX(time);
         m_canvas.Line(x, m_margin_top, x, m_height - m_margin_bottom, grid_color);
      }
   }

   //--- 軸を描画
   void DrawAxes()
   {
      uint axis_color = ColorToARGB(clrWhite, 255);
      uint text_color = ColorToARGB(clrWhite, 255);

      // X軸
      m_canvas.Line(m_margin_left, m_height - m_margin_bottom,
                    m_width - m_margin_right, m_height - m_margin_bottom, axis_color);

      // Y軸（右側）
      m_canvas.Line(m_width - m_margin_right, m_margin_top,
                    m_width - m_margin_right, m_height - m_margin_bottom, axis_color);

      // Y軸のラベル
      m_canvas.FontSet("Arial", 16);
      int num_labels = 8;
      int yi;
      for(yi = 0; yi <= num_labels; yi++)
      {
         double value = m_min_value + (m_max_value - m_min_value) * yi / num_labels;
         int y = ValueToY(value);

         string y_label = FormatNumberWithCommas(value);
         m_canvas.TextOut(m_width - m_margin_right + 10, y - 8, y_label, text_color);
      }

      // X軸のラベル（日付）
      int num_date_labels = 5;
      int xi;
      for(xi = 0; xi <= num_date_labels; xi++)
      {
         datetime time = m_min_time + (datetime)((m_max_time - m_min_time) * xi / num_date_labels);
         int x = TimeToX(time);

         string x_label = TimeToString(time, TIME_DATE);
         m_canvas.TextOut(x - 40, m_height - m_margin_bottom + 10, x_label, text_color);
      }
   }

   //--- 累積損益ラインを描画
   void DrawCumulativeLine(const TradeData &trades[], bool include_cashback)
   {
      int count = ArraySize(trades);
      if(count < 2) return;

      uint line_color = ColorToARGB(clrLimeGreen, 255);

      for(int i = 0; i < count - 1; i++)
      {
         int x1 = TimeToX(trades[i].time);
         int y1 = ValueToY(trades[i].cumulative);
         int x2 = TimeToX(trades[i+1].time);
         int y2 = ValueToY(trades[i+1].cumulative);

         m_canvas.Line(x1, y1, x2, y2, line_color);
      }
   }

   //--- 個別損益バーを描画
   void DrawIndividualBars(const TradeData &trades[], bool include_cashback)
   {
      int count = ArraySize(trades);
      int zero_y = ValueToY(0);

      for(int i = 0; i < count; i++)
      {
         double profit = include_cashback ? trades[i].profit + trades[i].cashback : trades[i].profit;

         int x = TimeToX(trades[i].time);
         int y = ValueToY(profit);

         uint bar_color = (profit >= 0) ? ColorToARGB(clrDodgerBlue, 180) : ColorToARGB(clrRed, 180);

         // 縦棒を描画
         if(profit >= 0)
            m_canvas.FillRectangle(x - 2, y, x + 2, zero_y, bar_color);
         else
            m_canvas.FillRectangle(x - 2, zero_y, x + 2, y, bar_color);
      }
   }

   //--- タイトルを描画
   void DrawTitle(const string symbol, const long magic_number, bool show_cashback)
   {
      string title = "損益チャート: " + symbol;
      if(magic_number == -1)
         title += " (ALL)";
      else
         title += " (MN:" + IntegerToString(magic_number) + ")";
      if(show_cashback)
         title += " [CB込]";

      m_canvas.FontSet("Arial", 20);
      m_canvas.TextOut(m_margin_left, 20, title, ColorToARGB(clrWhite, 255));
   }

   //--- 空のチャートを描画
   void DrawEmptyChart()
   {
      m_canvas.Erase(ColorToARGB(clrBlack, 255));
      m_canvas.FontSet("Arial", 20);
      m_canvas.TextOut(m_width/2 - 100, m_height/2, "データがありません", ColorToARGB(clrWhite, 255));
      m_canvas.Update();
   }
};
//+------------------------------------------------------------------+
