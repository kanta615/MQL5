//+------------------------------------------------------------------+
//|                                  DokaKotsu_T21F_Signal.mq5        |
//|   T2.1F : EMA10 のスパイク(収束度の跳ね)が点いた瞬間に矢印を      |
//|           1本出す参考用インジケーター（表示のみ・発注はしない）    |
//|                                                                  |
//|   ・EMA10 を収束度で色分け（跳ね=マゼンタ / 通常=グレー）         |
//|     ※収束度 = max(|price-EMA10|,|price-SMA20|,|EMA10-SMA20|)/ATR |
//|       (T2.1のスクイーズ判定と同じ。大きいほど価格が走った)       |
//|   ・矢印は線(マゼンタ=InpSpikeTh)より早い閾値 InpTriggerTh で出す。|
//|     さらに InpRequireRising=true なら conv上昇中の足だけに限定。   |
//|     → 線がマゼンタになる少し前に矢印が出る（早出し）。           |
//|     向きは価格とEMA10の位置で決める:                            |
//|       price > EMA10 = 上 → BUY                                  |
//|       price < EMA10 = 下 → SELL                                 |
//|                                                                  |
//|   【追撃なし・1回目だけ／再武装トグルあり】                     |
//|     1本のマゼンタ帯につき矢印は先頭1本だけ（帯の中での追撃なし）。|
//|     InpResetOnGray=true(既定): マゼンタが一度グレーに切れてから    |
//|       再点灯したら新しいスパイク帯として再武装。同方向の連続でも  |
//|       その都度1本出る（マゼンタが出ているのに矢印が無い、を解消）。|
//|     InpResetOnGray=false: BUY/SELLが交互に出るまで同方向は出ない  |
//|       （旧T2.1Fの厳格モード）。                                  |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   4

//--- EMA10 通常(グレー)
#property indicator_label1  "EMA10_NORM"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGray
#property indicator_width1  2
//--- EMA10 跳ね(マゼンタ)
#property indicator_label2  "EMA10_SPIKE"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMagenta
#property indicator_width2  3
//--- BUYシグナル（上向き矢印・安値の下）
#property indicator_label3  "T21F_BUY"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_width3  3
//--- SELLシグナル（下向き矢印・高値の上）
#property indicator_label4  "T21F_SELL"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  3

//=== 入力パラメータ ==============================================
input double InpSpikeTh      = 2.0;   // 線がマゼンタになる収束度（確認の目安・表示用）
input double InpTriggerTh    = 1.5;   // ★矢印を出す収束度（小さいほど早く出る。=InpSpikeThで旧来の遅いタイミング）
input bool   InpRequireRising= true;  // ★convが上昇中(前足より大)のときだけ矢印を出す（早出しのダマシ抑制）
input bool   InpResetOnGray  = true;  // true:帯が切れる度に再武装(1帯=矢印1本/同方向の連続もOK)
                                       // false:BUY・SELL交互のみ(厳格な追撃無し)
input int    InpRearmGapBars = 1;     // 再武装に必要な「矢印しきい値未満」の本数（多いほど矢印が減る）
input bool   InpAlert        = false; // シグナルが出た時にアラート

//=== バッファ ====================================================
double BufNorm[];   // 通常区間のEMA10（グレー）
double BufSpike[];  // 跳ね区間のEMA10（マゼンタ）
double BufBuy[];    // BUY矢印
double BufSell[];   // SELL矢印
double BufEma[];    // EMA10生値（内部計算用）
double BufSma[];    // SMA20生値（内部計算用）
double BufConv[];   // 収束度conv（前足比較・内部計算用）

//=== アラート重複防止 ============================================
datetime g_lastAlertTime = 0;

int hEMA10, hSMA20, hATR;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufNorm,  INDICATOR_DATA);
   SetIndexBuffer(1, BufSpike, INDICATOR_DATA);
   SetIndexBuffer(2, BufBuy,   INDICATOR_DATA);
   SetIndexBuffer(3, BufSell,  INDICATOR_DATA);
   SetIndexBuffer(4, BufEma,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufSma,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufConv,  INDICATOR_CALCULATIONS);

   // 線はEMPTYを空に（色の途切れを線でつなぐ）
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   // 矢印は0.0を空に
   PlotIndexSetInteger(2, PLOT_ARROW, 233); // 上矢印
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // 下矢印
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, 0.0);

   hEMA10 = iMA(_Symbol, _Period, 10, 0, MODE_EMA, PRICE_CLOSE);
   hSMA20 = iMA(_Symbol, _Period, 20, 0, MODE_SMA, PRICE_CLOSE);
   hATR   = iATR(_Symbol, _Period, 14);
   if(hEMA10==INVALID_HANDLE || hSMA20==INVALID_HANDLE || hATR==INVALID_HANDLE)
   {
      Print("ハンドル作成失敗");
      return(INIT_FAILED);
   }
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu T2.1F Signal");
   return(INIT_SUCCEEDED);
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
   int need = 40;
   if(rates_total < need) return(0);

   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   double ema[], sma[], atr[];
   if(CopyBuffer(hEMA10,0,0,rates_total,ema)<=0) return(prev_calculated);
   if(CopyBuffer(hSMA20,0,0,rates_total,sma)<=0) return(prev_calculated);
   if(CopyBuffer(hATR,0,0,rates_total,atr)<=0)   return(prev_calculated);
   ArraySetAsSeries(ema,false);
   ArraySetAsSeries(sma,false);
   ArraySetAsSeries(atr,false);

   // シグナルは「スパイクがどちらに点いたか」を先頭から追って lastSig を
   // 確定させるため、毎回 need から全再計算する。
   // ※再武装: InpResetOnGray=true ならマゼンタが切れる度に lastSig をリセット
   //   して同方向の連続スパイクでも1本ずつ出す。falseなら反対方向が出るまで
   //   同方向の矢印は出さない（旧モード）。いずれも帯の中での追撃は出さない。
   int lastSig = 0;   // 直前に出した矢印方向（1=BUY, -1=SELL）
   int grayCount = 1000000;  // 直近の連続グレー(非スパイク)本数。再武装の判定に使う

   // ウォームアップ区間（左端）を空にしておく（ゴミ描画防止）
   for(int j=0; j<need && j<rates_total; j++)
   {
      BufNorm[j]=EMPTY_VALUE; BufSpike[j]=EMPTY_VALUE;
      BufBuy[j]=0.0;          BufSell[j]=0.0;
      BufEma[j]=ema[j];       BufSma[j]=sma[j];
      BufConv[j]=0.0;
   }

   for(int i=need; i<rates_total; i++)
   {
      BufNorm[i]=EMPTY_VALUE; BufSpike[i]=EMPTY_VALUE;
      BufBuy[i]=0.0;          BufSell[i]=0.0;
      BufEma[i]=ema[i];       BufSma[i]=sma[i];
      BufConv[i]=0.0;
      if(atr[i]<=0) continue;

      double price = close[i];
      // 収束度（T2.1と同じ・方向を持たない大きさ）
      double sp = MathMax(MathMax(MathAbs(price-ema[i]),
                                  MathAbs(price-sma[i])),
                                  MathAbs(ema[i]-sma[i]));
      double conv = sp/atr[i];
      BufConv[i] = conv;
      bool rising = (conv > BufConv[i-1]);   // convが前足より伸びている＝勢い増加中

      bool isLastBar = (i==rates_total-1);

      // --- 線の色（確認の目安・表示用。マゼンタ=conv>InpSpikeTh）---
      if(conv > InpSpikeTh) { BufSpike[i]=ema[i]; BufSpike[i-1]=ema[i-1]; }
      else                  { BufNorm[i] =ema[i]; BufNorm[i-1] =ema[i-1]; }

      // --- 矢印トリガー（早出し閾値 InpTriggerTh。線より先に出る）---
      bool active = (conv >= InpTriggerTh);
      if(active)
      {
         // 帯がいったん切れて(しきい値未満が InpRearmGapBars 本以上)再点灯したら
         // 「新しい帯」とみなして再武装。同方向の連続でもその都度1本出る。
         if(InpResetOnGray && grayCount >= InpRearmGapBars) lastSig = 0;
         grayCount = 0;

         // 向きは価格とEMA10の位置で決める
         int dir = 0;
         if(price > ema[i]) dir = 1;        // 上 → BUY
         else if(price < ema[i]) dir = -1;  // 下 → SELL

         // 早出しのダマシ抑制: convが上昇中の足でだけ出す（任意）
         bool okRise = (!InpRequireRising || rising);
         if(okRise)
         {
            if(dir==1 && lastSig != 1)
            {
               BufBuy[i] = low[i] - atr[i]*0.5;
               lastSig = 1;
               if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
               {
                  Alert(_Symbol," T2.1F BUYシグナル");
                  g_lastAlertTime = time[i];
               }
            }
            else if(dir==-1 && lastSig != -1)
            {
               BufSell[i] = high[i] + atr[i]*0.5;
               lastSig = -1;
               if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
               {
                  Alert(_Symbol," T2.1F SELLシグナル");
                  g_lastAlertTime = time[i];
               }
            }
         }
      }
      else
      {
         grayCount++;   // 矢印しきい値未満が続いた本数（再武装の判定用）
      }
   }
   return(rates_total);
}
//+------------------------------------------------------------------+
