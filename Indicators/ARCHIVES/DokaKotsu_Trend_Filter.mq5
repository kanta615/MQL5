//+------------------------------------------------------------------+
//| DokaKotsu_Trend_Filter.mq5                                         |
//| トレンド環境フィルター                                             |
//|                                                                    |
//| ロング許可: EMA slope > 0  かつ  ADX >= 閾値                       |
//| ショート許可: EMA slope < 0  かつ  ADX >= 閾値                     |
//| どちらも満たさない場合はニュートラル(取引環境として弱い)            |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

#property indicator_label1  "ADX"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLightSeaGreen
#property indicator_width1  1

#property indicator_label2  "TrendState"
#property indicator_type2   DRAW_COLOR_HISTOGRAM
#property indicator_color2  clrGray,clrLime,clrRed
#property indicator_width2  3

//--- 入力パラメータ
input int InpEMAPeriod     = 50;   // EMA期間
input int InpSlopeLookback = 3;    // EMAスロープ計算の遡り本数
input int InpADXPeriod     = 12;   // ADX期間
input double InpADXThreshold = 25.0; // ADX閾値(これ未満はトレンド環境として弱いと判定)

//--- バッファ
double BufADX[];
double BufState[];      // -1=ショート許可 0=ニュートラル 1=ロング許可
double BufStateColor[]; // 0=灰(ニュートラル) 1=緑(ロング) 2=赤(ショート)

int hEMA = INVALID_HANDLE;
int hADX = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufADX,        INDICATOR_DATA);
   SetIndexBuffer(1, BufState,      INDICATOR_DATA);
   SetIndexBuffer(2, BufStateColor, INDICATOR_COLOR_INDEX);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   hEMA = iMA(_Symbol, _Period, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hADX = iADX(_Symbol, _Period, InpADXPeriod);

   if(hEMA == INVALID_HANDLE || hADX == INVALID_HANDLE)
     {
      Print("DokaKotsu_Trend_Filter: ハンドルの作成に失敗しました");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("トレンド環境(EMA%d,ADX%d,閾値%.0f)",
                       InpEMAPeriod, InpADXPeriod, InpADXThreshold));

   IndicatorSetInteger(INDICATOR_LEVELS, 1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpADXThreshold);
   IndicatorSetString(INDICATOR_LEVELTEXT, 0, "ADX閾値");
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, clrGray);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hEMA != INVALID_HANDLE) IndicatorRelease(hEMA);
   if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
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
   int minBars = InpEMAPeriod + InpSlopeLookback + 2;
   if(rates_total < minBars)
      return(0);

   double emaArr[], adxArr[];
   ArraySetAsSeries(emaArr, false);
   ArraySetAsSeries(adxArr, false);

   if(CopyBuffer(hEMA, 0, 0, rates_total, emaArr) <= 0) return(0);
   if(CopyBuffer(hADX, MAIN_LINE, 0, rates_total, adxArr) <= 0) return(0);

   int start = MathMax(InpEMAPeriod + InpSlopeLookback, 1);

   // 計算範囲外のバーは明示的に空値にしておく(初回のみ)
   if(prev_calculated <= 0)
     {
      for(int i = 0; i < start && i < rates_total; i++)
        {
         BufADX[i]        = EMPTY_VALUE;
         BufState[i]       = EMPTY_VALUE;
         BufStateColor[i]  = 0.0;
        }
     }

   int from  = (prev_calculated <= 0) ? start : MathMax(prev_calculated - 1, start);

   for(int i = from; i < rates_total; i++)
     {
      if(i - InpSlopeLookback < 0 || i >= ArraySize(emaArr) || i >= ArraySize(adxArr))
         continue;

      double slope = emaArr[i] - emaArr[i - InpSlopeLookback];
      double adx   = adxArr[i];

      BufADX[i] = adx;

      if(slope > 0.0 && adx >= InpADXThreshold)
        {
         BufState[i]      = 1.0;
         BufStateColor[i] = 1.0; // 緑=ロング許可
        }
      else if(slope < 0.0 && adx >= InpADXThreshold)
        {
         BufState[i]      = -1.0;
         BufStateColor[i] = 2.0; // 赤=ショート許可
        }
      else
        {
         BufState[i]      = 0.0;
         BufStateColor[i] = 0.0; // 灰=ニュートラル
        }
     }

   return(rates_total);
}
//+------------------------------------------------------------------+
