//+------------------------------------------------------------------+
//|                                   ProfitChart_HistoryLoader_MT4.mqh |
//|                          MT4用取引履歴ローダー                      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""

//+------------------------------------------------------------------+
//| MT4の取引履歴を読み込む                                             |
//+------------------------------------------------------------------+
bool LoadTradeHistoryMT4(
   TradeData &trades[],
   const string symbol,
   const long magic_number,
   ENUM_PERIOD_FILTER period,
   const double cashback_per_001lot,
   const bool include_cashback,
   int &last_deal_count
)
{
   //--- 期間の開始時刻を取得
   datetime start_time = GetStartDateFromPeriod(period);
   datetime end_time = TimeCurrent();

   //--- 一時配列（集計前の生データ）
   TradeData raw_trades[];
   ArrayResize(raw_trades, 0);

   int total_orders = OrdersHistoryTotal();
   int deal_count = 0;

   //--- 取引履歴を読み込む
   for(int i = 0; i < total_orders; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      //--- シンボルチェック
      if(OrderSymbol() != symbol)
         continue;

      //--- マジックナンバーチェック（-1=全て表示）
      if(magic_number != -1)
      {
         if(OrderMagicNumber() != magic_number)
            continue;
      }

      //--- 決済注文のみ（OP_BUY, OP_SELLの決済済み）
      int order_type = OrderType();
      if(order_type != OP_BUY && order_type != OP_SELL)
         continue;

      //--- 決済時刻を取得
      datetime close_time = OrderCloseTime();
      if(close_time == 0)  // まだ決済されていない
         continue;

      //--- 期間フィルタ
      if(close_time < start_time || close_time > end_time)
         continue;

      //--- 損益を取得
      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      //--- キャッシュバックを計算（0.01ロット = 1標準ロット/100）
      double volume = OrderLots();
      double cashback = (volume / 0.01) * cashback_per_001lot;

      //--- 配列に追加
      int size = ArraySize(raw_trades);
      ArrayResize(raw_trades, size + 1);

      raw_trades[size].time = close_time;
      raw_trades[size].profit = profit;
      raw_trades[size].cashback = cashback;
      raw_trades[size].trade_number = deal_count + 1;

      deal_count++;
   }

   //--- 取引がない場合
   if(deal_count == 0)
   {
      ArrayResize(trades, 0);
      last_deal_count = 0;
      Print("取引履歴が見つかりませんでした");
      return true;
   }

   //--- 時系列順にソート（古い順）
   for(int i = 0; i < deal_count - 1; i++)
   {
      for(int j = i + 1; j < deal_count; j++)
      {
         if(raw_trades[i].time > raw_trades[j].time)
         {
            TradeData temp = raw_trades[i];
            raw_trades[i] = raw_trades[j];
            raw_trades[j] = temp;
         }
      }
   }

   //--- 累積損益を計算
   double cumulative = 0.0;
   for(int i = 0; i < deal_count; i++)
   {
      if(include_cashback)
         cumulative += raw_trades[i].profit + raw_trades[i].cashback;
      else
         cumulative += raw_trades[i].profit;

      raw_trades[i].cumulative = cumulative;
      raw_trades[i].trade_number = i + 1;
   }

   //--- 時間ごとに集計
   AggregateTradesByTime(raw_trades, trades, period);

   last_deal_count = ArraySize(trades);
   return true;
}
//+------------------------------------------------------------------+
