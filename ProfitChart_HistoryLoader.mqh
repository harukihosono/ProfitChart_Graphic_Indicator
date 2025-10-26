//+------------------------------------------------------------------+
//|                                    ProfitChart_HistoryLoader.mqh |
//|                          取引履歴読み込みロジック（MT4/MT5共通）    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""

#include "ProfitChart_Common.mqh"

//--- 一時ディール構造体
struct TempDeal
{
   datetime time;
   double profit;
   double cashback;
};

#ifdef __MQL5__
//+------------------------------------------------------------------+
//| 取引履歴を読み込む（MQL5版）                                        |
//+------------------------------------------------------------------+
bool LoadTradeHistoryMT5(
   TradeData &trades[],
   const string symbol,
   const long magic_number,
   const ENUM_PERIOD_FILTER period,
   const double cashback_per_001_lot,
   const bool show_cashback,
   int &last_deal_count
)
{
   //--- 配列をクリア
   ArrayResize(trades, 0);

   //--- 取引履歴を要求（期間に応じて）
   datetime from = GetStartDateFromPeriod(period);
   datetime to = TimeCurrent();

   if(!HistorySelect(from, to))
   {
      Print("取引履歴の取得に失敗");
      return false;
   }

   //--- ディール数を取得
   int total_deals = HistoryDealsTotal();
   if(total_deals == 0)
   {
      Print("取引履歴がありません");
      return false;
   }

   //--- 一時配列
   TempDeal temp_deals[];
   ArrayResize(temp_deals, 0);

   //--- ディールを収集（決済のみ）
   for(int i = 0; i < total_deals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      //--- シンボルチェック
      string deal_symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(deal_symbol != symbol) continue;

      //--- マジックナンバーチェック（-1=全て表示）
      if(magic_number != -1)
      {
         long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         if(magic != magic_number) continue;
      }

      //--- エントリーチェック（OUT/INOUT = 決済のみ）
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;

      //--- 利益を取得
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double net_profit = profit + commission + swap;

      //--- ボリュームとキャッシュバック
      double vol = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      double cashback = (vol / 0.01) * cashback_per_001_lot;

      //--- 時刻
      datetime deal_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);

      //--- 配列に追加
      int idx = ArraySize(temp_deals);
      ArrayResize(temp_deals, idx + 1);
      temp_deals[idx].time = deal_time;
      temp_deals[idx].profit = net_profit;
      temp_deals[idx].cashback = cashback;
   }

   int deal_count = ArraySize(temp_deals);
   if(deal_count == 0)
   {
      Print("決済済みの取引がありません（対象シンボル: ", symbol, "）");
      return false;
   }

   //--- 時系列順にソート（古い順）
   int si, sj;
   for(si = 0; si < deal_count - 1; si++)
   {
      for(sj = si + 1; sj < deal_count; sj++)
      {
         if(temp_deals[si].time > temp_deals[sj].time)
         {
            TempDeal temp = temp_deals[si];
            temp_deals[si] = temp_deals[sj];
            temp_deals[sj] = temp;
         }
      }
   }

   //--- 累積計算してトレードデータ配列に格納
   TradeData raw_trades[];
   ArrayResize(raw_trades, deal_count);
   double cumulative = 0.0;

   int ci;
   for(ci = 0; ci < deal_count; ci++)
   {
      double profit_with_cb = show_cashback ?
         (temp_deals[ci].profit + temp_deals[ci].cashback) :
         temp_deals[ci].profit;

      cumulative += profit_with_cb;

      raw_trades[ci].time = temp_deals[ci].time;
      raw_trades[ci].profit = temp_deals[ci].profit;
      raw_trades[ci].cashback = temp_deals[ci].cashback;
      raw_trades[ci].cumulative = cumulative;
      raw_trades[ci].trade_number = ci + 1;
   }

   //--- 期間に応じてデータを集計
   AggregateTradesByTime(raw_trades, trades, period);

   last_deal_count = ArraySize(trades);
   // Print("取引データ読み込み完了: ", deal_count, "件 → 集計後: ", last_deal_count, "件");
   return true;
}
#endif // __MQL5__

#ifdef __MQL4__
//+------------------------------------------------------------------+
//| 取引履歴を読み込む（MQL4版）                                        |
//+------------------------------------------------------------------+
bool LoadTradeHistoryMT4(
   TradeData &trades[],
   const string symbol,
   const long magic_number,
   const ENUM_PERIOD_FILTER period,
   const double cashback_per_001_lot,
   const bool show_cashback,
   int &last_deal_count
)
{
   //--- 配列をクリア
   ArrayResize(trades, 0);

   //--- 一時配列
   TempDeal temp_deals[];
   ArrayResize(temp_deals, 0);

   //--- MT4の履歴オーダーを取得
   int total_orders = OrdersHistoryTotal();
   if(total_orders == 0)
   {
      Print("取引履歴がありません");
      return false;
   }

   //--- 期間フィルター用の開始時刻
   datetime from = GetStartDateFromPeriod(period);
   datetime to = TimeCurrent();

   //--- オーダーを収集（決済済みのみ）
   for(int i = 0; i < total_orders; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;

      //--- 決済済みチェック（CloseTimeが0より大きい）
      datetime close_time = OrderCloseTime();
      if(close_time == 0) continue;

      //--- 期間チェック
      if(close_time < from || close_time > to) continue;

      //--- シンボルチェック
      string order_symbol = OrderSymbol();
      if(order_symbol != symbol) continue;

      //--- マジックナンバーチェック（-1=全て表示）
      if(magic_number != -1)
      {
         long magic = OrderMagicNumber();
         if(magic != magic_number) continue;
      }

      //--- オーダータイプチェック（売買のみ、ペンディングオーダーを除外）
      int order_type = OrderType();
      if(order_type != OP_BUY && order_type != OP_SELL) continue;

      //--- 利益を取得
      double profit = OrderProfit();
      double commission = OrderCommission();
      double swap = OrderSwap();
      double net_profit = profit + commission + swap;

      //--- ボリュームとキャッシュバック
      double vol = OrderLots();
      double cashback = (vol / 0.01) * cashback_per_001_lot;

      //--- 配列に追加
      int idx = ArraySize(temp_deals);
      ArrayResize(temp_deals, idx + 1);
      temp_deals[idx].time = close_time;
      temp_deals[idx].profit = net_profit;
      temp_deals[idx].cashback = cashback;
   }

   int deal_count = ArraySize(temp_deals);
   if(deal_count == 0)
   {
      Print("決済済みの取引がありません（対象シンボル: ", symbol, "）");
      return false;
   }

   //--- 時系列順にソート（古い順）
   int si, sj;
   for(si = 0; si < deal_count - 1; si++)
   {
      for(sj = si + 1; sj < deal_count; sj++)
      {
         if(temp_deals[si].time > temp_deals[sj].time)
         {
            TempDeal temp = temp_deals[si];
            temp_deals[si] = temp_deals[sj];
            temp_deals[sj] = temp;
         }
      }
   }

   //--- 累積計算してトレードデータ配列に格納
   TradeData raw_trades[];
   ArrayResize(raw_trades, deal_count);
   double cumulative = 0.0;

   int ci;
   for(ci = 0; ci < deal_count; ci++)
   {
      double profit_with_cb = show_cashback ?
         (temp_deals[ci].profit + temp_deals[ci].cashback) :
         temp_deals[ci].profit;

      cumulative += profit_with_cb;

      raw_trades[ci].time = temp_deals[ci].time;
      raw_trades[ci].profit = temp_deals[ci].profit;
      raw_trades[ci].cashback = temp_deals[ci].cashback;
      raw_trades[ci].cumulative = cumulative;
      raw_trades[ci].trade_number = ci + 1;
   }

   //--- 期間に応じてデータを集計
   AggregateTradesByTime(raw_trades, trades, period);

   last_deal_count = ArraySize(trades);
   // Print("取引データ読み込み完了: ", deal_count, "件 → 集計後: ", last_deal_count, "件");
   return true;
}
#endif // __MQL4__

//+------------------------------------------------------------------+
//| 取引履歴を読み込む（MT4/MT5共通インターフェース）                   |
//+------------------------------------------------------------------+
bool LoadTradeHistory(
   TradeData &trades[],
   const string symbol,
   const long magic_number,
   const ENUM_PERIOD_FILTER period,
   const double cashback_per_001_lot,
   const bool show_cashback,
   int &last_deal_count
)
{
#ifdef __MQL5__
   return LoadTradeHistoryMT5(trades, symbol, magic_number, period, cashback_per_001_lot, show_cashback, last_deal_count);
#else
   return LoadTradeHistoryMT4(trades, symbol, magic_number, period, cashback_per_001_lot, show_cashback, last_deal_count);
#endif
}
//+------------------------------------------------------------------+
