//+------------------------------------------------------------------+
//|                            DokaKotsu_RSI_Volume_Divergence.mq5  |
//|  RSIダイバージェンス と 出来高ダイバージェンス を同時検出        |
//|                                                                  |
//|  【表示内容】                                                    |
//|   ・RSIライン (0-100)                                            |
//|   ・出来高ヒストグラム (直近100本の最大値を100として正規化)       |
//|   ・強気/弱気 RSIダイバージェンス矢印 (緑/赤)                     |
//|   ・強気/弱気 出来高のみダイバージェンス矢印 (水色/オレンジ)       |
//|   ・RSI+出来高が一致した「複合ダイバージェンス」矢印 (黄/マゼンタ) |
//|                                                                  |
//|  【判定ロジック】                                                 |
//|   直近の価格ピボット(高値/安値)を1つ前のピボットと比較:            |
//|    ・弱気RSI乖離 : 価格が高値更新 かつ RSIが切り下げ              |
//|    ・強気RSI乖離 : 価格が安値更新 かつ RSIが切り上げ              |
//|    ・弱気Vol乖離 : 価格が高値更新 かつ 出来高が減少               |
//|    ・強気Vol乖離 : 価格が安値更新 かつ 出来高が減少               |
//|   両方同時成立 → 複合ダイバージェンス(信頼度が高いシグナル)        |
//|                                                                  |
//|  【注意】                                                         |
//|   矢印はピボット確定後(InpPivotLeftRight本後)に表示されるため、    |
//|   直近 InpPivotLeftRight 本は未確定(リペイントではなく、単に      |
//|   まだピボットとして確定していないだけ)。                          |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   8

#property indicator_label1  "RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  1

#property indicator_label2  "出来高(正規化)"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrSilver
#property indicator_width2  2

#property indicator_label3  "強気RSIダイバージェンス"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_width3  2

#property indicator_label4  "弱気RSIダイバージェンス"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrRed
#property indicator_width4  2

#property indicator_label5  "強気複合ダイバージェンス(RSI+出来高)"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrYellow
#property indicator_width5  3

#property indicator_label6  "弱気複合ダイバージェンス(RSI+出来高)"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrMagenta
#property indicator_width6  3

#property indicator_label7  "強気 出来高のみダイバージェンス"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrAqua
#property indicator_width7  1

#property indicator_label8  "弱気 出来高のみダイバージェンス"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrOrange
#property indicator_width8  1

#property indicator_level1  30
#property indicator_level2  70
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT
#property indicator_minimum 0
#property indicator_maximum 100

//--- 入力パラメータ
input int                 InpRSIPeriod            = 14;          // RSI期間
input ENUM_APPLIED_PRICE  InpRSIPrice             = PRICE_CLOSE; // RSI適用価格
input int                 InpPivotLeftRight       = 3;           // ピボット判定用 左右バー数(フラクタル)
input int                 InpMinPivotGap          = 4;           // 比較する2つのピボット間の最小バー数
input int                 InpMaxPivotBars         = 100;         // 比較する2つのピボット間の最大バー数
input ENUM_APPLIED_VOLUME InpVolumeType           = VOLUME_TICK; // 出来高種別(Tick/Real)
input int                 InpVolumeNormWindow     = 100;         // 出来高正規化の参照本数
input bool                InpShowVolumeOnlyDivergence = true;    // 出来高単独ダイバージェンスも表示するか

//--- インジケーターバッファ
double BufRSI[];
double BufVolume[];
double BufBullRSI[];
double BufBearRSI[];
double BufBullCombo[];
double BufBearCombo[];
double BufBullVolOnly[];
double BufBearVolOnly[];

int rsiHandle = INVALID_HANDLE;

//--- ピボット情報構造体
struct PivotInfo
{
   int    bar;
   double price;
   double rsiVal;
   double volVal;
};

PivotInfo lastPivotHigh, prevPivotHigh;
PivotInfo lastPivotLow,  prevPivotLow;
bool hasPivotHigh=false;
bool hasPivotLow=false;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                        |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufRSI,         INDICATOR_DATA);
   SetIndexBuffer(1, BufVolume,      INDICATOR_DATA);
   SetIndexBuffer(2, BufBullRSI,     INDICATOR_DATA);
   SetIndexBuffer(3, BufBearRSI,     INDICATOR_DATA);
   SetIndexBuffer(4, BufBullCombo,   INDICATOR_DATA);
   SetIndexBuffer(5, BufBearCombo,   INDICATOR_DATA);
   SetIndexBuffer(6, BufBullVolOnly, INDICATOR_DATA);
   SetIndexBuffer(7, BufBearVolOnly, INDICATOR_DATA);

   ArraySetAsSeries(BufRSI,false);
   ArraySetAsSeries(BufVolume,false);
   ArraySetAsSeries(BufBullRSI,false);
   ArraySetAsSeries(BufBearRSI,false);
   ArraySetAsSeries(BufBullCombo,false);
   ArraySetAsSeries(BufBearCombo,false);
   ArraySetAsSeries(BufBullVolOnly,false);
   ArraySetAsSeries(BufBearVolOnly,false);

   PlotIndexSetInteger(2, PLOT_ARROW, 233); // 上矢印(Wingdings)
   PlotIndexSetInteger(3, PLOT_ARROW, 234); // 下矢印(Wingdings)
   PlotIndexSetInteger(4, PLOT_ARROW, 233);
   PlotIndexSetInteger(5, PLOT_ARROW, 234);
   PlotIndexSetInteger(6, PLOT_ARROW, 159); // 小さい丸(Wingdings)
   PlotIndexSetInteger(7, PLOT_ARROW, 159);

   for(int p=0; p<8; p++)
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   rsiHandle = iRSI(_Symbol, _Period, InpRSIPeriod, InpRSIPrice);
   if(rsiHandle==INVALID_HANDLE)
   {
      Print("DokaKotsu_RSI_Volume_Divergence: RSIハンドル作成失敗");
      return(INIT_FAILED);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu RSI+Vol Divergence(" + IntegerToString(InpRSIPeriod) + ")");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(rsiHandle!=INVALID_HANDLE)
      IndicatorRelease(rsiHandle);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   int minBars = InpPivotLeftRight*2 + InpMinPivotGap + 5;
   if(rates_total < minBars)
      return(0);

   //--- RSIを非時系列(index0=最古)でコピー
   double rsiArr[];
   ArraySetAsSeries(rsiArr,false);
   int copied = CopyBuffer(rsiHandle, 0, 0, rates_total, rsiArr);
   if(copied<=0)
      return(0);

   int start;
   if(prev_calculated<=0)
   {
      start = InpPivotLeftRight;
      ArrayInitialize(BufRSI, EMPTY_VALUE);
      ArrayInitialize(BufVolume, EMPTY_VALUE);
      ArrayInitialize(BufBullRSI, EMPTY_VALUE);
      ArrayInitialize(BufBearRSI, EMPTY_VALUE);
      ArrayInitialize(BufBullCombo, EMPTY_VALUE);
      ArrayInitialize(BufBearCombo, EMPTY_VALUE);
      ArrayInitialize(BufBullVolOnly, EMPTY_VALUE);
      ArrayInitialize(BufBearVolOnly, EMPTY_VALUE);
      hasPivotHigh=false;
      hasPivotLow=false;
   }
   else
   {
      // 直近確定分から少し巻き戻して再計算(ピボット確定の遅延分をカバー)
      start = prev_calculated - InpPivotLeftRight - 2;
   }
   if(start < InpPivotLeftRight)
      start = InpPivotLeftRight;

   for(int i=start; i<rates_total; i++)
   {
      BufRSI[i] = rsiArr[i];

      //--- 出来高を直近InpVolumeNormWindow本の最大値で正規化(0-100)
      int normStart = i - InpVolumeNormWindow;
      if(normStart<0) normStart=0;
      double maxVol = 0;
      for(int k=normStart; k<=i; k++)
      {
         double v = (InpVolumeType==VOLUME_TICK) ? (double)tick_volume[k] : (double)volume[k];
         if(v>maxVol) maxVol=v;
      }
      double curVol = (InpVolumeType==VOLUME_TICK) ? (double)tick_volume[i] : (double)volume[i];
      BufVolume[i] = (maxVol>0) ? (curVol/maxVol*100.0) : 0.0;

      BufBullRSI[i]     = EMPTY_VALUE;
      BufBearRSI[i]     = EMPTY_VALUE;
      BufBullCombo[i]   = EMPTY_VALUE;
      BufBearCombo[i]   = EMPTY_VALUE;
      BufBullVolOnly[i] = EMPTY_VALUE;
      BufBearVolOnly[i] = EMPTY_VALUE;

      //--- ピボット候補バー(左右InpPivotLeftRight本が揃っているか)
      int pivotIdx = i - InpPivotLeftRight;
      if(pivotIdx - InpPivotLeftRight < 0)
         continue;

      bool isPivotHigh=true, isPivotLow=true;
      double pivotHighPrice = high[pivotIdx];
      double pivotLowPrice  = low[pivotIdx];

      for(int j=pivotIdx-InpPivotLeftRight; j<=pivotIdx+InpPivotLeftRight; j++)
      {
         if(j==pivotIdx) continue;
         if(high[j] >= pivotHighPrice) isPivotHigh=false;
         if(low[j]  <= pivotLowPrice)  isPivotLow=false;
      }

      double pivotVolRaw = (InpVolumeType==VOLUME_TICK) ? (double)tick_volume[pivotIdx] : (double)volume[pivotIdx];
      double pivotRsi    = rsiArr[pivotIdx];
      double pivotVolNorm = BufVolume[pivotIdx];

      //--- 高値ピボット: 弱気ダイバージェンス判定
      if(isPivotHigh)
      {
         PivotInfo newPivot;
         newPivot.bar=pivotIdx; newPivot.price=pivotHighPrice; newPivot.rsiVal=pivotRsi; newPivot.volVal=pivotVolRaw;

         if(hasPivotHigh)
         {
            int gap = pivotIdx - lastPivotHigh.bar;
            if(gap>=InpMinPivotGap && gap<=InpMaxPivotBars)
            {
               bool priceHigherHigh = newPivot.price  > lastPivotHigh.price;
               bool rsiLowerHigh    = newPivot.rsiVal < lastPivotHigh.rsiVal;
               bool volLowerHigh    = newPivot.volVal < lastPivotHigh.volVal;

               bool rsiDiverge = priceHigherHigh && rsiLowerHigh;
               bool volDiverge = priceHigherHigh && volLowerHigh;

               if(rsiDiverge && volDiverge)
                  BufBearCombo[pivotIdx] = MathMin(100.0, pivotRsi+12.0);
               else if(rsiDiverge)
                  BufBearRSI[pivotIdx] = MathMin(100.0, pivotRsi+7.0);
               else if(volDiverge && InpShowVolumeOnlyDivergence)
                  BufBearVolOnly[pivotIdx] = MathMin(100.0, pivotVolNorm+7.0);
            }
         }
         prevPivotHigh = lastPivotHigh;
         lastPivotHigh = newPivot;
         hasPivotHigh = true;
      }

      //--- 安値ピボット: 強気ダイバージェンス判定
      if(isPivotLow)
      {
         PivotInfo newPivot;
         newPivot.bar=pivotIdx; newPivot.price=pivotLowPrice; newPivot.rsiVal=pivotRsi; newPivot.volVal=pivotVolRaw;

         if(hasPivotLow)
         {
            int gap = pivotIdx - lastPivotLow.bar;
            if(gap>=InpMinPivotGap && gap<=InpMaxPivotBars)
            {
               bool priceLowerLow = newPivot.price  < lastPivotLow.price;
               bool rsiHigherLow  = newPivot.rsiVal > lastPivotLow.rsiVal;
               bool volLowerLow   = newPivot.volVal < lastPivotLow.volVal;

               bool rsiDiverge = priceLowerLow && rsiHigherLow;
               bool volDiverge = priceLowerLow && volLowerLow;

               if(rsiDiverge && volDiverge)
                  BufBullCombo[pivotIdx] = MathMax(0.0, pivotRsi-12.0);
               else if(rsiDiverge)
                  BufBullRSI[pivotIdx] = MathMax(0.0, pivotRsi-7.0);
               else if(volDiverge && InpShowVolumeOnlyDivergence)
                  BufBullVolOnly[pivotIdx] = MathMax(0.0, pivotVolNorm-7.0);
            }
         }
         prevPivotLow = lastPivotLow;
         lastPivotLow = newPivot;
         hasPivotLow = true;
      }
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
