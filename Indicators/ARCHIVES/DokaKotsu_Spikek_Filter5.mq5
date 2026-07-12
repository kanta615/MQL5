//+------------------------------------------------------------------+
//| DokaKotsu_Spikek_Filter.mq5                                      |
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
//|                                                                    |
//|  ■ 2026-07-08 変更点(元 Pullback_Area_Filter.mq5 からリネーム)   |
//|    ①ファイル名/インジケーター名を DokaKotsu_Pullback_Filter へ統一 |
//|    ②インジケーターリスト表示から比率(旧:押し目面積フィルター       |
//|      比率0.50)を削除し、名称のみのシンプル表示に変更               |
//|    ③押し目面積合格(BufPass)が出た足の1本上(次の行)に、             |
//|      面積の実数値をテキストラベルで表示(サブウィンドウ内)。         |
//|      決済判断に数値そのものを使う想定のため、視認性を優先。         |
//|  ■ 2026-07-08 追加変更(DokaKotsu_Pullback_Filter からリネーム)   |
//|    ④ファイル名/インジケーター名を DokaKotsu_Spikek_Filter へ変更   |
//|      (ロジック・パラメータは無変更)                               |
//|  ■ 2026-07-11 変更点                                              |
//|    ⑤表示判定を「直近平均比(avgArea*InpAreaRatio)」から             |
//|      「絶対閾値InpSpikeAbsThresh(既定300)以上」に変更。             |
//|      田島さんの定義する「スパイク」=面積300以上、という絶対基準に   |
//|      統一するため。閾値未満の面積はBufPass/BufFailとも0のまま=      |
//|      チャート上に一切表示しない(以前の除外グレー表示も廃止)。       |
//|  ■ 2026-07-11d 変更点                                             |
//|    ⑥一旦シンプルにするため、絶対閾値による絞り込みを外し、          |
//|      確定した全スイングを表示するよう変更(後日改めて絞り込み予定)。 |
//|  ■ 2026-07-11e 変更点                                             |
//|    ⑦絞り込みを再適用。面積300以上(InpSpikeAbsThresh)のみ表示、        |
//|      それ未満はノイズとして一切表示しない。                         |
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
input int    InpLabelBars     = 300;   // ★2026-07-08追加: 直近何本分まで合格数値ラベルを表示するか(古い分は非表示=チャート負荷/煩雑さ対策)
input double InpSpikeAbsThresh = 300.0; // ★2026-07-11追加: 「スパイク」と呼ぶ絶対的な面積の閾値。これ以上のみ表示する(直近平均比の相対判定は表示には使わない)

//--- バッファ
double BufPass[];     // 合格した押し目の面積
double BufFail[];     // 除外された押し目の面積
double BufAreaRaw[];  // 内部計算用(非表示):全スイングの面積

int hATR = INVALID_HANDLE;
const string LABEL_PREFIX = "DKPF_area_";  // ★合格時の数値ラベル用オブジェクト名プレフィックス

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
      Print("DokaKotsu_Spikek_Filter: ATRハンドルの作成に失敗しました");
      return(INIT_FAILED);
     }

   // ★2026-07-08: インジケーターリストは名称のみ(比率表示は削除)
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu_Spikek_Filter");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   ObjectsDeleteAll(0, LABEL_PREFIX, -1, OBJ_TEXT);  // ★数値ラベルを後片付け
}

//+------------------------------------------------------------------+
//| ★2026-07-08追加: 押し目面積合格の足の1本上(次の行)に面積の実数値を  |
//|   テキストラベルで表示する(サブウィンドウ内、決済判断用の可視化)。  |
//+------------------------------------------------------------------+
void PlotAreaLabel(datetime t, double area)
{
   int win = ChartWindowFind();   // このインジケーター自身のサブウィンドウ番号
   if(win < 0) return;

   string name = LABEL_PREFIX + (string)(long)t;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, win, t, area);

   ObjectSetInteger(0, name, OBJPROP_TIME,     t);
   ObjectSetDouble (0, name, OBJPROP_PRICE,    area);          // サブウィンドウの価格軸=面積スケール上に配置
   ObjectSetString (0, name, OBJPROP_TEXT,     DoubleToString(area, 1));
   ObjectSetInteger(0, name, OBJPROP_ANCHOR,   ANCHOR_LOWER);  // 基準点の真上にテキスト=バーの1行上に表示
   ObjectSetInteger(0, name, OBJPROP_COLOR,    clrLime);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,   true);
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

   int labelFrom = (rates_total > InpLabelBars) ? (rates_total - InpLabelBars) : 0;  // ★直近InpLabelBars本だけラベル対象

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

            double avgArea  = CalcAvgArea(areaHist, InpAvgLookback); // ★内部履歴の更新用に計算は維持(表示判定には未使用)

            int plotIdx = swingIdx[n-1];
            // ★2026-07-11e変更: 絞り込みを再適用。「スパイク」は面積300以上(絶対値・InpSpikeAbsThresh)のみ表示する。
            //   小さいスイングはノイズとして扱い、チャート上には一切表示しない(BufPass/BufFailとも0のまま)。
            if(area >= InpSpikeAbsThresh)
              {
               BufPass[plotIdx] = area;
               if(plotIdx >= labelFrom)
                  PlotAreaLabel(time[plotIdx], area);
              }
            BufAreaRaw[plotIdx] = area; // ★閾値に関わらず生値は常に保持(indicator_13等の外部参照用)

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
