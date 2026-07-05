//+------------------------------------------------------------------+
//|                              DokaKotsu_HeikinAshi_2.mq5           |
//|   平滑化平均足(Smoothed Heikin Ashi) ※表示専用・単独計算版       |
//|                                                                  |
//|  ■■ 2026-07-02 単独化 ■■                                        |
//|    本体インジを参照せず、このインジ自身が前平滑→平均足→後平滑を  |
//|    自分の入力で計算して描画する(開発・探索用に単独で動く)。      |
//|    ・数値を変えると即このチャートに反映される。                  |
//|    ・MA計算は DokaKotsu_Core.mqh の MAValue を共用。              |
//|    ※注意: 本体インジ/EAが実際に使う平均足は本体の既定値。       |
//|      ここで変えた値は表示だけで、売買には反映されない(単独)。    |
//|      値が決まったら本体(コア)側の既定値を変更すること。          |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1

#include "DokaKotsu_Core.mqh"

//--- 平滑化平均足キャンドル(4値: Open High Low Close)＋色
#property indicator_label1  "DokaKotsu HA"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrMediumSeaGreen, clrOrange
#property indicator_width1  1

//=== 入力(このインジ自身の平均足パラメータ。単独で計算する) ============
input group "平均足の作り(単独計算)"
input int            InpHaPrePeriod  = 4;                   // 前平滑化の期間(既定4)
input ENUM_MA_METHOD InpHaPreMethod  = MODE_SMMA;           // 前平滑化の方式(Smoothed)
input int            InpHaPostPeriod = 5;                   // 後平滑化の期間(既定5)
input ENUM_MA_METHOD InpHaPostMethod = MODE_SMMA;           // 後平滑化の方式(Smoothed)
input group "表示(色)"
input color          InpBullColor    = clrMediumSeaGreen;   // 陽線(上昇)の色
input color          InpBearColor    = clrOrange;           // 陰線(下降)の色

//=== バッファ(このインジが計算して描く) ===============================
double BufOpen[];
double BufHigh[];
double BufLow[];
double BufClose[];
double BufColor[];   // 0=陽線 / 1=陰線

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufOpen,  INDICATOR_DATA);
   SetIndexBuffer(1, BufHigh,  INDICATOR_DATA);
   SetIndexBuffer(2, BufLow,   INDICATOR_DATA);
   SetIndexBuffer(3, BufClose, INDICATOR_DATA);
   SetIndexBuffer(4, BufColor, INDICATOR_COLOR_INDEX);

   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpBullColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpBearColor);
   PlotIndexSetDouble (0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu HA (単独計算)");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

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
   if(rates_total < 5) return(0);

   //--- ①前平滑化(本体と同じ作り) ---
   double prO[],prH[],prL[],prC[];
   ArrayResize(prO,rates_total); ArrayResize(prH,rates_total);
   ArrayResize(prL,rates_total); ArrayResize(prC,rates_total);
   for(int i=0;i<rates_total;i++)
   {
      prO[i]=MAValue(open ,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
      prH[i]=MAValue(high ,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
      prL[i]=MAValue(low  ,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
      prC[i]=MAValue(close,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
   }

   //--- ②平均足の生値 ---
   double hO[],hH[],hL[],hC[];
   ArrayResize(hO,rates_total); ArrayResize(hH,rates_total);
   ArrayResize(hL,rates_total); ArrayResize(hC,rates_total);
   for(int i=0;i<rates_total;i++)
   {
      double hac=(prO[i]+prH[i]+prL[i]+prC[i])/4.0;
      double hao=(i==0)?(prO[i]+prC[i])/2.0:(hO[i-1]+hC[i-1])/2.0;
      hO[i]=hao; hC[i]=hac;
      hH[i]=MathMax(prH[i],MathMax(hao,hac));
      hL[i]=MathMin(prL[i],MathMin(hao,hac));
   }

   //--- ③後平滑化 → OHLC出力＋色 ---
   for(int i=0;i<rates_total;i++)
   {
      double o=MAValue(hO,i,InpHaPostPeriod,InpHaPostMethod,rates_total);
      double h=MAValue(hH,i,InpHaPostPeriod,InpHaPostMethod,rates_total);
      double l=MAValue(hL,i,InpHaPostPeriod,InpHaPostMethod,rates_total);
      double c=MAValue(hC,i,InpHaPostPeriod,InpHaPostMethod,rates_total);
      double hi=MathMax(h,MathMax(o,c));
      double lo=MathMin(l,MathMin(o,c));
      BufOpen[i]=o; BufHigh[i]=hi; BufLow[i]=lo; BufClose[i]=c;
      BufColor[i]=(c>=o)?0.0:1.0;   // 0=陽線 / 1=陰線
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
