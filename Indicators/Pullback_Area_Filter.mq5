//+------------------------------------------------------------------+
//| Pullback_Area_Filter.mq5                                          |
//| 押し目の値幅×期間(面積)フィルター                                 |
//|                                                                    |
//| 面積 = スイング区間の値幅 × 継続バー数                            |
//| 直近InpAvgLookback件のスイング面積の平均に対し、                   |
//| InpAreaRatio未満の面積しかない区間は「ノイズ的な押し目」として      |
//| 除外(グレー表示)、それ以外は「本物の押し目候補」として              |
//| 緑で表示する。                                                     |
//|                                                                    |
//| ※スイング検出はZigZag_ATR.mq5と同じATR連動ロジックを内蔵している。 |
//| ※「押し目」と「トレンド継続脚」の区別はしておらず、                 |
//|   確定した全スイング区間を対象に面積評価している点に注意            |
//|   (トレンド方向判定を組み合わせたい場合は要調整、田島さんと          |
//|   相談しながら次のイテレーションで絞り込み可能)。                   |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

#property indicator_label1  "押し目面積(合格)"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrLime
#property indicator_width1  3

#property indicator_label2  "押し目面積(除外)"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrSilver
#property indicator_width2  3

//--- 入力パラメータ
input int    InpATRPeriod     = 14;    // ATR期間(スイング検出用)
input double InpATRMultiplier = 2.0;   // ATR倍数(最小スイング幅の係数)
input int    InpAvgLookback   = 10;    // 平均面積を計算する直近スイング数
input double InpAreaRatio     = 0.5;   // 平均面積に対する合格の下限比率
input int    InpMaxBarsBack   = 2000;  // 再計算する過去バー数の上限

//--- バッファ
double BufPass[];     // 合格した押し目の面積
double BufFail[];     // 除外された押し目の面積
double BufAreaRaw[];  // 内部計算用(非表示):全スイングの面積

int hATR = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufPass,    INDICATOR_DATA);
   SetIndexBuffer(1, BufFail,    INDICATOR_DATA);
   SetIndexBuffer(2, BufAreaRaw, INDICATOR_CALCULATIONS);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);

   hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(hATR == INVALID_HANDLE)
     {
      Print("Pullback_Area_Filter: ATRハンドルの作成に失敗しました");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("押し目面積フィルター(比率%.2f)", InpAreaRatio));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
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
   if(rates_total < InpATRPeriod + 5)
      return(0);

   double atrArr[];
   ArraySetAsSeries(atrArr, false);
   if(CopyBuffer(hATR, 0, 0, rates_total, atrArr) <= 0)
      return(0);

   int start = 0;
   if(rates_total > InpMaxBarsBack)
      start = rates_total - InpMaxBarsBack;

   for(int i = start; i < rates_total; i++)
     {
      BufPass[i]    = 0.0;
      BufFail[i]    = 0.0;
      BufAreaRaw[i] = 0.0;
     }

   int    direction = 0;
   int    curIdx  = start;
   double curPrice = close[start];

   int    swingIdx[];
   double swingPrice[];
   ArrayResize(swingIdx, 0);
   ArrayResize(swingPrice, 0);

   double areaHist[];
   ArrayResize(areaHist, 0);

   for(int i = start + 1; i < rates_total; i++)
     {
      double threshold = atrArr[i] * InpATRMultiplier;
      if(threshold <= 0.0)
         continue;

      bool flipped = false;

      if(direction == 0)
        {
         if(high[i] - curPrice >= threshold)
           {
            direction = 1;
            PushSwing(swingIdx, swingPrice, curIdx, curPrice);
            curPrice = high[i]; curIdx = i;
           }
         else if(curPrice - low[i] >= threshold)
           {
            direction = -1;
            PushSwing(swingIdx, swingPrice, curIdx, curPrice);
            curPrice = low[i]; curIdx = i;
           }
         continue;
        }

      if(direction == 1)
        {
         if(high[i] > curPrice)
           {
            curPrice = high[i]; curIdx = i;
           }
         else if(curPrice - low[i] >= threshold)
           {
            flipped = true;
            PushSwing(swingIdx, swingPrice, curIdx, curPrice); // 高値を確定
            direction = -1;
            curPrice = low[i]; curIdx = i;
           }
        }
      else // direction == -1
        {
         if(low[i] < curPrice)
           {
            curPrice = low[i]; curIdx = i;
           }
         else if(high[i] - curPrice >= threshold)
           {
            flipped = true;
            PushSwing(swingIdx, swingPrice, curIdx, curPrice); // 安値を確定
            direction = 1;
            curPrice = high[i]; curIdx = i;
           }
        }

      if(flipped)
        {
         int n = ArraySize(swingIdx);
         if(n >= 2)
           {
            double range    = MathAbs(swingPrice[n-1] - swingPrice[n-2]);
            int    duration = swingIdx[n-1] - swingIdx[n-2];
            double area     = range * (double)MathMax(duration, 1);

            double avgArea  = CalcAvgArea(areaHist, InpAvgLookback);

            int plotIdx = swingIdx[n-1];
            if(avgArea > 0.0 && area < avgArea * InpAreaRatio)
               BufFail[plotIdx] = area;
            else
               BufPass[plotIdx] = area;
            BufAreaRaw[plotIdx] = area;

            int hc = ArraySize(areaHist);
            ArrayResize(areaHist, hc + 1);
            areaHist[hc] = area;
           }
        }
     }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| 確定スイング点を履歴配列に追加する                                 |
//+------------------------------------------------------------------+
void PushSwing(int &idxArr[], double &priceArr[], int idx, double price)
{
   int n = ArraySize(idxArr);
   ArrayResize(idxArr, n + 1);
   ArrayResize(priceArr, n + 1);
   idxArr[n]   = idx;
   priceArr[n] = price;
}

//+------------------------------------------------------------------+
//| 直近lookback件の面積平均を計算する(新規分は含めない)               |
//+------------------------------------------------------------------+
double CalcAvgArea(const double &areaHist[], int lookback)
{
   int histCount = ArraySize(areaHist);
   int useCount  = MathMin(histCount, lookback);
   if(useCount <= 0)
      return(0.0);

   double sum = 0.0;
   for(int k = histCount - useCount; k < histCount; k++)
      sum += areaHist[k];

   return(sum / useCount);
}
//+------------------------------------------------------------------+
