//+------------------------------------------------------------------+
//|                                           ProfitChart_Common.mqh |
//|                          MQL4/MQL5共通データ構造とユーティリティ   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      ""

//--- 期間列挙型
enum ENUM_PERIOD_FILTER
{
   PERIOD_1D,      // 1日
   PERIOD_1W,      // 1週間
   PERIOD_1M,      // 1ヶ月
   PERIOD_3M,      // 3ヶ月
   PERIOD_6M,      // 6ヶ月
   PERIOD_12M,     // 12ヶ月
   PERIOD_ALL      // 全期間
};

//--- トレードデータ構造体
struct TradeData
{
   datetime time;
   double profit;
   double cashback;
   double cumulative;
   int trade_number;
};

//+------------------------------------------------------------------+
//| 期間から開始日時を取得                                               |
//+------------------------------------------------------------------+
datetime GetStartDateFromPeriod(ENUM_PERIOD_FILTER period)
{
   datetime current = TimeCurrent();

   switch(period)
   {
      case PERIOD_1D:   return current - 1*24*60*60;        // 1日前
      case PERIOD_1W:   return current - 7*24*60*60;        // 1週間前
      case PERIOD_1M:   return current - 30*24*60*60;       // 1ヶ月前
      case PERIOD_3M:   return current - 90*24*60*60;       // 3ヶ月前
      case PERIOD_6M:   return current - 180*24*60*60;      // 6ヶ月前
      case PERIOD_12M:  return current - 365*24*60*60;      // 12ヶ月前
      case PERIOD_ALL:  return 0;                           // 全期間
      default:          return current - 365*24*60*60;
   }
}

//+------------------------------------------------------------------+
//| 期間から集計間隔を取得（秒単位）                                      |
//+------------------------------------------------------------------+
int GetAggregationInterval(ENUM_PERIOD_FILTER period)
{
   switch(period)
   {
      case PERIOD_1D:   return 3600;           // 1時間 = 3600秒
      case PERIOD_1W:   return 4*3600;         // 4時間 = 14400秒
      case PERIOD_1M:   return 24*3600;        // 1日 = 86400秒
      case PERIOD_3M:   return 24*3600;        // 1日
      case PERIOD_6M:   return 24*3600;        // 1日
      case PERIOD_12M:  return 24*3600;        // 1日
      case PERIOD_ALL:  return 24*3600;        // 1日
      default:          return 24*3600;
   }
}

//+------------------------------------------------------------------+
//| 時間を指定間隔に丸める                                               |
//+------------------------------------------------------------------+
datetime RoundTimeToInterval(datetime time, int interval)
{
   return (time / interval) * interval;
}

//+------------------------------------------------------------------+
//| トレードデータを時間ごとに集計                                        |
//+------------------------------------------------------------------+
void AggregateTradesByTime(
   const TradeData &source_trades[],
   TradeData &aggregated_trades[],
   ENUM_PERIOD_FILTER period
)
{
   int source_count = ArraySize(source_trades);
   if(source_count == 0)
   {
      ArrayResize(aggregated_trades, 0);
      return;
   }

   //--- 集計間隔を取得
   int interval = GetAggregationInterval(period);

   //--- 一時的なマップ（時間バケット -> 利益の合計）
   datetime time_buckets[];
   double profit_sums[];
   double cashback_sums[];
   int bucket_count = 0;

   //--- トレードを時間バケットに集計
   for(int i = 0; i < source_count; i++)
   {
      datetime bucket_time = RoundTimeToInterval(source_trades[i].time, interval);

      //--- このバケットが既に存在するか確認
      int bucket_index = -1;
      for(int j = 0; j < bucket_count; j++)
      {
         if(time_buckets[j] == bucket_time)
         {
            bucket_index = j;
            break;
         }
      }

      //--- 新しいバケットを作成
      if(bucket_index == -1)
      {
         bucket_index = bucket_count;
         ArrayResize(time_buckets, bucket_count + 1);
         ArrayResize(profit_sums, bucket_count + 1);
         ArrayResize(cashback_sums, bucket_count + 1);
         time_buckets[bucket_index] = bucket_time;
         profit_sums[bucket_index] = 0;
         cashback_sums[bucket_index] = 0;
         bucket_count++;
      }

      //--- 利益を集計
      profit_sums[bucket_index] += source_trades[i].profit;
      cashback_sums[bucket_index] += source_trades[i].cashback;
   }

   //--- 時系列順にソート（バブルソート）
   for(int i = 0; i < bucket_count - 1; i++)
   {
      for(int j = i + 1; j < bucket_count; j++)
      {
         if(time_buckets[i] > time_buckets[j])
         {
            datetime temp_time = time_buckets[i];
            double temp_profit = profit_sums[i];
            double temp_cashback = cashback_sums[i];

            time_buckets[i] = time_buckets[j];
            profit_sums[i] = profit_sums[j];
            cashback_sums[i] = cashback_sums[j];

            time_buckets[j] = temp_time;
            profit_sums[j] = temp_profit;
            cashback_sums[j] = temp_cashback;
         }
      }
   }

   //--- 集計結果をTradeData配列に変換
   ArrayResize(aggregated_trades, bucket_count);
   double cumulative = 0.0;

   for(int i = 0; i < bucket_count; i++)
   {
      aggregated_trades[i].time = time_buckets[i];
      aggregated_trades[i].profit = profit_sums[i];
      aggregated_trades[i].cashback = cashback_sums[i];
      cumulative += profit_sums[i];
      aggregated_trades[i].cumulative = cumulative;
      aggregated_trades[i].trade_number = i + 1;
   }
}
//+------------------------------------------------------------------+
