//+------------------------------------------------------------------+
//| DokaKotsu_SwingPosition.mq5                                       |
//| スイング内ポジション率(0〜100%)オシレーター                       |
//|                                                                    |
//| DokaKotsu_ZigZag_ATRと同じ「ATR×倍数」でスイングを検出するが、    |
//| 値幅(pips)そのものではなく、直前の確定スイング(A→B)に対して        |
//| 「今どこまで戻したか」を0〜100%の比率に変換してRSIのように         |
//| サブウィンドウ(0〜100スケール)へ折れ線で描画する。                 |
//|                                                                    |
//|   100% = 直前スイング点(B)そのまま(まだ戻していない)              |
//|    50% = A→Bの値幅の半分まで戻した                                |
//|     0% = 反対側(A)まで完全に戻った(=反転完了)                     |
//|                                                                    |
//| 値が50%を下回っているか等、RSIと同じ感覚で判断できる。            |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1  50
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT

#property indicator_label1  "SwingPosition%"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrAqua
#property indicator_width1  2

//--- 入力パラメータ(ZigZag_ATRと同じ考え方)
input int    InpATRPeriod     = 14;    // ATR期間
input double InpATRMultiplier = 2.0;   // ATR倍数(最小スイング幅の係数)
input int    InpMaxBarsBack   = 2000;  // 再計算する過去バー数の上限

//--- バッファ
double BufPct[];   // スイング内ポジション率(0〜100)

int hATR = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufPct, INDICATOR_DATA);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(hATR == INVALID_HANDLE)
     {
      Print("DokaKotsu_SwingPosition: ATRハンドルの作成に失敗しました");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu_SwingPosition");
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
      BufPct[i] = EMPTY_VALUE;

   int    direction   = 0;      // 0=方向未確定 1=高値を追跡中 -1=安値を追跡中
   int    curIdx      = start;
   double curPrice     = close[start];

   double confirmedB   = 0.0;   // 直前に確定したスイング点(B) = 現在の戻しの基準
   double confirmedA   = 0.0;   // Bの1つ前に確定したスイング点(A) = 反対側の到達目標
   bool   haveLeg      = false; // A・Bが両方揃って「A→B」の値幅が定義できているか

   for(int i = start + 1; i < rates_total; i++)
     {
      double threshold = atrArr[i] * InpATRMultiplier;
      if(threshold <= 0.0) { BufPct[i] = BufPct[i-1]; continue; }

      if(direction == 0)
        {
         if(high[i] - curPrice >= threshold)      { direction=1;  curPrice=high[i]; curIdx=i; }
         else if(curPrice - low[i] >= threshold)   { direction=-1; curPrice=low[i];  curIdx=i; }
        }
      else if(direction == 1) // 高値を更新しながら追跡中
        {
         if(high[i] > curPrice) { curPrice=high[i]; curIdx=i; }
         else if(curPrice - low[i] >= threshold)
           {
            // 高値(curPrice)を確定 → A・Bを1つずつ繰り上げる
            confirmedA = confirmedB;
            confirmedB = curPrice;
            haveLeg    = (confirmedA != confirmedB) && (confirmedA != 0.0 || confirmedB != 0.0);
            direction  = -1;
            curPrice   = low[i];
            curIdx     = i;
           }
        }
      else // direction == -1 : 安値を更新しながら追跡中
        {
         if(low[i] < curPrice) { curPrice=low[i]; curIdx=i; }
         else if(high[i] - curPrice >= threshold)
           {
            confirmedA = confirmedB;
            confirmedB = curPrice;
            haveLeg    = (confirmedA != confirmedB) && (confirmedA != 0.0 || confirmedB != 0.0);
            direction  = 1;
            curPrice   = high[i];
            curIdx     = i;
           }
        }

      // ★このバーの「今どこまで戻したか」を計算(A→Bの値幅に対する比率)
      if(haveLeg)
        {
         double legRange = MathAbs(confirmedB - confirmedA);
         if(legRange > 0.0)
           {
            double retraced = MathAbs(close[i] - confirmedB);
            double pct = 100.0 - 100.0 * (retraced / legRange);
            if(pct < 0.0)   pct = 0.0;    // Aを超えて反対側まで行った場合は0%で頭打ち
            if(pct > 100.0) pct = 100.0;  // Bをさらに更新中の場合は100%で頭打ち
            BufPct[i] = pct;
           }
         else
            BufPct[i] = BufPct[i-1];
        }
      else
         BufPct[i] = EMPTY_VALUE;   // まだA→Bが揃っていない(データ初期のみ)
     }

   return(rates_total);
}
//+------------------------------------------------------------------+
