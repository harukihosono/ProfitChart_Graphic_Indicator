//+------------------------------------------------------------------+
//|                                    ProfitChart_HistoryLoader.mqh |
//|                          取引履歴読み込みロジック（MQL5版）         |
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

      //--- マジックナンバーチェック
      if(magic_number != 0)
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
   for(int i = 0; i < deal_count - 1; i++)
   {
      for(int j = i + 1; j < deal_count; j++)
      {
         if(temp_deals[i].time > temp_deals[j].time)
         {
            TempDeal temp = temp_deals[i];
            temp_deals[i] = temp_deals[j];
            temp_deals[j] = temp;
         }
      }
   }

   //--- 累積計算してトレードデータ配列に格納
   ArrayResize(trades, deal_count);
   double cumulative = 0.0;

   for(int i = 0; i < deal_count; i++)
   {
      double profit_with_cb = show_cashback ?
         (temp_deals[i].profit + temp_deals[i].cashback) :
         temp_deals[i].profit;

      cumulative += profit_with_cb;

      trades[i].time = temp_deals[i].time;
      trades[i].profit = temp_deals[i].profit;
      trades[i].cashback = temp_deals[i].cashback;
      trades[i].cumulative = cumulative;
      trades[i].trade_number = i + 1;
   }

   last_deal_count = deal_count;
   Print("取引データ読み込み完了: ", deal_count, "件");
   return true;
}
//+------------------------------------------------------------------+
