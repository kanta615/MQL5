//+------------------------------------------------------------------+
//| ZigZag_ATR.mq5                                                    |
//| ATR倍数フィルター型ZigZag                                         |
//|                                                                    |
//| 標準ZigZagの%/固定pips方式の代わりに、                             |
//|   最小スイング幅 = ATR(InpATRPeriod) × InpATRMultiplier            |
//| をスイング認定の閾値として使う。閾値未満の戻りは                   |
//| そもそも「押し目」として認識しない。                               |
//|                                                                    |
//| ※サブウィンドウ表示。価格スケールそのままの折れ線として描画。      |
//| ※簡易的な全期間再計算方式(重い戻り確定ロジックのため)。            |
//|   ダマシを避けるため、確定していない最新の仮ポイントも              |
//|   同じ色で表示している(直近足で動く可能性あり)。                   |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

#property indicator_label1  "ZigZag(ATR)"
#property indicator_type1   DRAW_ZIGZAG
#property indicator_color1  clrYellow
#property indicator_width1  2

//--- 入力パラメータ
input int    InpATRPeriod     = 14;    // ATR期間
input double InpATRMultiplier = 2.0;   // ATR倍数(最小スイング幅の係数)
input int    InpMaxBarsBack   = 2000;  // 再計算する過去バー数の上限(重い場合は減らす)

//--- バッファ
// DRAW_ZIGZAGは1プロットに対して2バッファ(高値側/安値側)を要求するため分けて持つ
double BufPeak[];     // 確定/仮の高値スイング。それ以外は0
double BufBottom[];   // 確定/仮の安値スイング。それ以外は0

int hATR = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufPeak,   INDICATOR_DATA);
   SetIndexBuffer(1, BufBottom, INDICATOR_DATA);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

   hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(hATR == INVALID_HANDLE)
     {
      Print("ZigZag_ATR: ATRハンドルの作成に失敗しました");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ZigZag_ATR(%d, x%.1f)", InpATRPeriod, InpATRMultiplier));
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

   // high/low/close はデフォルトで非シリーズ(index0=最古) → ATRも同じ並びで取得する
   double atrArr[];
   ArraySetAsSeries(atrArr, false);
   if(CopyBuffer(hATR, 0, 0, rates_total, atrArr) <= 0)
      return(0);

   int start = 0;
   if(rates_total > InpMaxBarsBack)
      start = rates_total - InpMaxBarsBack;

   for(int i = start; i < rates_total; i++)
     {
      BufPeak[i]   = 0.0;
      BufBottom[i] = 0.0;
     }

   int    direction  = 0;            // 0=方向未確定 1=高値を追跡中 -1=安値を追跡中
   int    curIdx     = start;
   double curPrice   = close[start];
   bool   curIsPeak  = false;        // 現在追跡中の仮ポイントが高値か安値か

   for(int i = start + 1; i < rates_total; i++)
     {
      double threshold = atrArr[i] * InpATRMultiplier;
      if(threshold <= 0.0)
         continue;

      if(direction == 0)
        {
         if(high[i] - curPrice >= threshold)
           {
            direction = 1;
            curPrice  = high[i];
            curIdx    = i;
            curIsPeak = true;
           }
         else if(curPrice - low[i] >= threshold)
           {
            direction = -1;
            curPrice  = low[i];
            curIdx    = i;
            curIsPeak = false;
           }
         continue;
        }

      if(direction == 1) // 高値を更新しながら追跡中
        {
         if(high[i] > curPrice)
           {
            curPrice = high[i];
            curIdx   = i;
           }
         else if(curPrice - low[i] >= threshold)
           {
            // 高値を確定してPeakバッファに記録し、下降追跡に反転
            BufPeak[curIdx] = curPrice;
            direction = -1;
            curPrice  = low[i];
            curIdx    = i;
            curIsPeak = false;
           }
        }
      else // direction == -1 : 安値を更新しながら追跡中
        {
         if(low[i] < curPrice)
           {
            curPrice = low[i];
            curIdx   = i;
           }
         else if(high[i] - curPrice >= threshold)
           {
            // 安値を確定してBottomバッファに記録し、上昇追跡に反転
            BufBottom[curIdx] = curPrice;
            direction = 1;
            curPrice  = high[i];
            curIdx    = i;
            curIsPeak = true;
           }
        }
     }

   // 未確定の最新スイング(反転待ち)も仮表示する。以後の足で更新される可能性あり
   if(curIsPeak)
      BufPeak[curIdx] = curPrice;
   else
      BufBottom[curIdx] = curPrice;

   return(rates_total);
}
//+------------------------------------------------------------------+
