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
