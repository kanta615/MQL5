//+------------------------------------------------------------------+
//|                              DokaKotsu_HeikinAshi.mq5            |
//|   平滑化平均足(Smoothed Heikin Ashi)                             |
//|   ローソク足を平均足に置き換えて表示する。                       |
//|                                                                  |
//|   設定可能:                                                      |
//|     ① 前平滑化(平均足を計算する前の価格を平滑化)期間＋方式      |
//|     ② 後平滑化(平均足を計算した後をさらに平滑化)期間＋方式      |
//|     ③ 陽線・陰線の色                                            |
//|                                                                  |
//|   ・期間=1にすると平滑化なし(素の平均足)になる。                |
//|   ・方式は SMA / EMA / SMMA / LWMA から選択。                    |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.10"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1

//--- 平均足キャンドル(4値: Open High Low Close)＋色
#property indicator_label1  "DokaKotsu HA"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrMediumSeaGreen, clrOrange
#property indicator_width1  1

//=== 入力 =========================================================
input int                InpPrePeriod   = 5;        // 前平滑化の期間(1=なし)
input ENUM_MA_METHOD     InpPreMethod   = MODE_SMMA;// 前平滑化の方式
input int                InpPostPeriod  = 5;        // 後平滑化の期間(1=なし)
input ENUM_MA_METHOD     InpPostMethod  = MODE_SMMA;// 後平滑化の方式
input color              InpBullColor   = clrMediumSeaGreen; // 陽線(上昇)の色
input color              InpBearColor   = clrOrange;         // 陰線(下降)の色

//=== バッファ =====================================================
double BufOpen[];
double BufHigh[];
double BufLow[];
double BufClose[];
double BufColor[];   // 0=陽線 / 1=陰線

//--- 前平滑化した価格の作業用
double PreO[], PreH[], PreL[], PreC[];
//--- 平均足の生値(後平滑化の入力)作業用
double HaO[], HaH[], HaL[], HaC[];

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

   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("DokaKotsu HA (pre %d/%s, post %d/%s)",
        InpPrePeriod, MethodName(InpPreMethod),
        InpPostPeriod, MethodName(InpPostMethod)));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 方式名(短縮名表示用)                                            |
//+------------------------------------------------------------------+
string MethodName(ENUM_MA_METHOD m)
{
   switch(m)
   {
      case MODE_SMA:  return "SMA";
      case MODE_EMA:  return "EMA";
      case MODE_SMMA: return "SMMA";
      case MODE_LWMA: return "LWMA";
   }
   return "?";
}

//+------------------------------------------------------------------+
//| 1本の移動平均値を計算(配列srcのpos位置・period本・方式method)    |
//|   ※価格平滑化用の汎用MA。配列は時系列昇順(0=古い)。            |
//+------------------------------------------------------------------+
double MAValue(const double &src[], int pos, int period, ENUM_MA_METHOD method, int total)
{
   if(period <= 1) return src[pos];
   if(pos < period-1) return src[pos];   // データ不足時はそのまま

   double res = 0.0;
   switch(method)
   {
      case MODE_SMA:
      {
         double sum=0;
         for(int k=0; k<period; k++) sum += src[pos-k];
         res = sum/period;
         break;
      }
      case MODE_EMA:
      {
         double pr = 2.0/(period+1.0);
         // posまでを順に積む(簡易: period*2区間から立ち上げ)
         int start = MathMax(0, pos-period*3);
         double ema = src[start];
         for(int k=start+1; k<=pos; k++)
            ema = src[k]*pr + ema*(1.0-pr);
         res = ema;
         break;
      }
      case MODE_SMMA:
      {
         int start = MathMax(0, pos-period*3);
         double smma = src[start];
         for(int k=start+1; k<=pos; k++)
            smma = (smma*(period-1) + src[k])/period;
         res = smma;
         break;
      }
      case MODE_LWMA:
      {
         double sum=0, wsum=0;
         for(int k=0; k<period; k++)
         {
            int w = period-k;
            sum  += src[pos-k]*w;
            wsum += w;
         }
         res = (wsum>0)? sum/wsum : src[pos];
         break;
      }
      default: res = src[pos];
   }
   return res;
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

   // 作業配列を確保
   ArrayResize(PreO, rates_total); ArrayResize(PreH, rates_total);
   ArrayResize(PreL, rates_total); ArrayResize(PreC, rates_total);
   ArrayResize(HaO, rates_total);  ArrayResize(HaH, rates_total);
   ArrayResize(HaL, rates_total);  ArrayResize(HaC, rates_total);

   // ── ① 前平滑化: OHLCをそれぞれ平滑化 ──
   for(int i=0; i<rates_total; i++)
   {
      PreO[i] = MAValue(open,  i, InpPrePeriod, InpPreMethod, rates_total);
      PreH[i] = MAValue(high,  i, InpPrePeriod, InpPreMethod, rates_total);
      PreL[i] = MAValue(low,   i, InpPrePeriod, InpPreMethod, rates_total);
      PreC[i] = MAValue(close, i, InpPrePeriod, InpPreMethod, rates_total);
   }

   // ── ② 平均足の計算(前平滑化したOHLCから) ──
   for(int i=0; i<rates_total; i++)
   {
      double haClose = (PreO[i]+PreH[i]+PreL[i]+PreC[i])/4.0;
      double haOpen;
      if(i==0) haOpen = (PreO[i]+PreC[i])/2.0;
      else     haOpen = (HaO[i-1]+HaC[i-1])/2.0;
      double haHigh = MathMax(PreH[i], MathMax(haOpen, haClose));
      double haLow  = MathMin(PreL[i], MathMin(haOpen, haClose));
      HaO[i]=haOpen; HaH[i]=haHigh; HaL[i]=haLow; HaC[i]=haClose;
   }

   // ── ③ 後平滑化: 平均足の値をさらに平滑化して最終表示 ──
   for(int i=0; i<rates_total; i++)
   {
      double o = MAValue(HaO, i, InpPostPeriod, InpPostMethod, rates_total);
      double h = MAValue(HaH, i, InpPostPeriod, InpPostMethod, rates_total);
      double l = MAValue(HaL, i, InpPostPeriod, InpPostMethod, rates_total);
      double c = MAValue(HaC, i, InpPostPeriod, InpPostMethod, rates_total);

      // 高値/安値が前後関係を保つよう補正
      double hi = MathMax(h, MathMax(o, c));
      double lo = MathMin(l, MathMin(o, c));

      BufOpen[i]  = o;
      BufHigh[i]  = hi;
      BufLow[i]   = lo;
      BufClose[i] = c;
      BufColor[i] = (c >= o) ? 0 : 1;   // 0=陽線 / 1=陰線
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
