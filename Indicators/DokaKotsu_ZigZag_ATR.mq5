//+------------------------------------------------------------------+
//| DokaKotsu_ZigZag_ATR.mq5                                         |
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
//|                                                                    |
//|  ■ 2026-07-08 変更点(元 ZigZag_ATR.mq5 からリネーム)              |
//|    ①ファイル名/インジケーター名を DokaKotsu_ZigZag_ATR へ統一     |
//|    ②インジケーターリスト表示から期間×倍数(旧:ZigZag_ATR(14, x2.0))|
//|      を削除し、名称のみのシンプル表示に変更                       |
//|    ③スイングが確定(反転)した瞬間に、その確定点へ「直前スイングと   |
//|      の値幅(pips)」をテキストラベルで表示。決済判断に数値そのもの  |
//|      を使う想定のため視認性を優先(高値=文字を上/安値=文字を下に    |
//|      表示して折れ線と重ならないようにしている)。                   |
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
input double InpPipSize       = 0.1;   // ★2026-07-08追加: pips換算の基準(XAUUSD既定=0.1)
input int    InpLabelBars     = 300;   // ★2026-07-08追加: 直近何本分まで値幅ラベルを表示するか(古い分は非表示=チャート負荷/煩雑さ対策)

//--- バッファ
// DRAW_ZIGZAGは1プロットに対して2バッファ(高値側/安値側)を要求するため分けて持つ
double BufPeak[];     // 確定/仮の高値スイング。それ以外は0
double BufBottom[];   // 確定/仮の安値スイング。それ以外は0

int hATR = INVALID_HANDLE;
const string LABEL_PREFIX = "DKZZ_range_";  // ★確定スイングの値幅ラベル用オブジェクト名プレフィックス

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufPeak,   INDICATOR_DATA);
   SetIndexBuffer(1, BufBottom, INDICATOR_DATA);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);

   hATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(hATR == INVALID_HANDLE)
     {
      Print("DokaKotsu_ZigZag_ATR: ATRハンドルの作成に失敗しました");
      return(INIT_FAILED);
     }

   // ★2026-07-08: インジケーターリストは名称のみ(期間×倍数表示は削除)
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu_ZigZag_ATR");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   ObjectsDeleteAll(0, LABEL_PREFIX, -1, OBJ_TEXT);  // ★値幅ラベルを後片付け
}

//+------------------------------------------------------------------+
//| ★2026-07-08追加: 確定スイング点に「直前スイングとの値幅(pips)」を  |
//|   テキストラベルで表示する(サブウィンドウ内、決済判断用の可視化)。 |
//|   isPeak=true(高値確定)なら文字を点の上に、false(安値確定)なら    |
//|   点の下に配置し、ZigZagの折れ線と重ならないようにする。            |
//+------------------------------------------------------------------+
void PlotSwingRangeLabel(datetime t, double price, double pips, bool isPeak)
{
   int win = ChartWindowFind();   // このインジケーター自身のサブウィンドウ番号
   if(win < 0) return;

   string name = LABEL_PREFIX + (string)(long)t;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, win, t, price);

   ObjectSetInteger(0, name, OBJPROP_TIME,       t);
   ObjectSetDouble (0, name, OBJPROP_PRICE,      price);
   ObjectSetString (0, name, OBJPROP_TEXT,       DoubleToString(pips, 1) + "p");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,     isPeak ? ANCHOR_LOWER : ANCHOR_UPPER); // 高値=文字は上/安値=文字は下
   ObjectSetInteger(0, name, OBJPROP_COLOR,      isPeak ? clrYellow : clrOrange);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   8);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
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

   // ★2026-07-08: 確定スイングの履歴(値幅計算用)。Pullback_Filterと同じ考え方
   double swingPrice[];
   ArrayResize(swingPrice, 0);
   int labelFrom = (rates_total > InpLabelBars) ? (rates_total - InpLabelBars) : 0;  // 直近InpLabelBars本だけラベル対象

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
            ConfirmSwing(swingPrice, time[curIdx], curPrice, true, labelFrom, curIdx);
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
            ConfirmSwing(swingPrice, time[curIdx], curPrice, false, labelFrom, curIdx);
            direction = 1;
            curPrice  = high[i];
            curIdx    = i;
            curIsPeak = true;
           }
        }
     }

   // 未確定の最新スイング(反転待ち)も仮表示する。以後の足で更新される可能性あり
   // ★数値ラベルは「反転した時」だけの表示なので、未確定の仮ポイントには付けない
   if(curIsPeak)
      BufPeak[curIdx] = curPrice;
   else
      BufBottom[curIdx] = curPrice;

   return(rates_total);
}

//+------------------------------------------------------------------+
//| ★2026-07-08追加: スイング確定時の共通処理。                       |
//|   直前の確定スイングとの値幅(pips)を計算し、対象期間内ならラベル表示 |
//+------------------------------------------------------------------+
void ConfirmSwing(double &swingPrice[], datetime t, double price, bool isPeak, int labelFrom, int idx)
{
   int n = ArraySize(swingPrice);
   if(n >= 1)
     {
      double range = MathAbs(price - swingPrice[n-1]);
      double pips  = (InpPipSize > 0.0) ? range / InpPipSize : range;
      if(idx >= labelFrom)
         PlotSwingRangeLabel(t, price, pips, isPeak);
     }
   ArrayResize(swingPrice, n + 1);
   swingPrice[n] = price;
}
//+------------------------------------------------------------------+
