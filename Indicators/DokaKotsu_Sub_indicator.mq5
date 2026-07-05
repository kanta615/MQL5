//+------------------------------------------------------------------+
//|                          DokaKotsu_Sub_indicator.mq5            |
//|   ATRベースのスパイク極値を サブウィンドウに ZigZag型ヒストグラム |
//|   で表示。色なし／太さと高さで Major・Minor を判別／ゼロ線あり    |
//|   （表示のみ・発注はしない）                                     |
//|                                                                  |
//|   ZigZag挙動: 交互に登録。同方向の連続は最極値1本。             |
//|   さらに 最小間隔(MinGapBars)以内の重複は スイング幅が大きい方   |
//|   だけ残す（決済に効く本物のスパイクだけを残す）。             |
//|                                                                  |
//|   出力: +2 Major Top / +1 Minor Top（上向き=天井）             |
//|         -1 Minor Bottom / -2 Major Bottom（下向き=大底）        |
//|         太くて高い棒=Major / 細くて低い棒=Minor                |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "5.00"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   3
#property indicator_minimum -2.5
#property indicator_maximum 2.5

//--- ゼロ・センターライン
#property indicator_label1  "Zero"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGray
#property indicator_width1  3
//--- Major（太6・高さ±2）
#property indicator_label2  "Major"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrSilver
#property indicator_width2  6
//--- Minor（細3・高さ±1）
#property indicator_label3  "Minor"
#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrSilver
#property indicator_width3  3

//=== 入力パラメータ ==============================================
input bool   InpNoRepaint        = true; // 確定足のみ表示(右側Width本待ち・後で動かない)
input bool   InpZigZag           = true; // ZigZag挙動＋最小間隔で重複除去
input int    InpMinGapBars       = 4;    // この本数以内の重複はスイング幅が大きい方だけ残す
input double InpMinorHeightATRs  = 1.5;  // Minorと見なすスイング幅(ATR倍)。下げると拾う数が増える
input double InpMajorRatio       = 2.5;  // Major昇格比率(理想形 MajorToMinorHeightRatio=2.5)
input int    InpMinorWidth       = 2;    // 前後の判定本数(理想形 MinorMinExtremeWidth=2)
input int    InpMajorWidth       = 2;    // Major判定の前後本数(理想形 MajorMinExtremeWidth=2)
input int    InpAtrPeriod        = 14;   // ATR期間
input bool   InpShowMinor        = true; // Minor(細=±1)も表示。falseでMajor(太=±2)だけ
input bool   InpAlert            = false;// 最新の確定極値でアラート

//=== バッファ ====================================================
double BufZero[];
double BufMajor[];
double BufMinor[];

datetime g_lastAlertTime = 0;
int hATR;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufZero,  INDICATOR_DATA);
   SetIndexBuffer(1, BufMajor, INDICATOR_DATA);
   SetIndexBuffer(2, BufMinor, INDICATOR_DATA);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, 0.0);

   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   IndicatorSetInteger(INDICATOR_LEVELS, 4);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0,  2.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1,  1.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, -1.0);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 3, -2.0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, STYLE_DOT);

   hATR = iATR(_Symbol, _Period, InpAtrPeriod);
   if(hATR==INVALID_HANDLE) { Print("ATRハンドル作成失敗"); return(INIT_FAILED); }

   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu Sub indicator");
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
   int Wmax = MathMax(InpMinorWidth, InpMajorWidth);
   int need = Wmax + InpAtrPeriod + 2;
   if(rates_total < need + 2) return(0);

   ArraySetAsSeries(time, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low,  false);

   double atr[];
   if(CopyBuffer(hATR,0,0,rates_total,atr)<=0) return(prev_calculated);
   ArraySetAsSeries(atr,false);

   for(int i=0; i<rates_total; i++)
   { BufZero[i]=0.0; BufMajor[i]=0.0; BufMinor[i]=0.0; }

   int last = rates_total-1;
   int end  = InpNoRepaint ? (last - Wmax) : last;

   // ZigZag状態
   int    zzType=0, zzIdx=-1, zzGrade=0;
   double zzPrice=0.0, zzHeight=0.0;

   for(int i=need; i<=end; i++)
   {
      if(atr[i]<=0) continue;
      double minorTh = atr[i]*InpMinorHeightATRs;
      double majorTh = minorTh*InpMajorRatio;

      // --- Top候補 ---
      double hi=high[i], swLow=low[i];
      bool tlmMin=true, tlmMaj=true;
      for(int k=1; k<=InpMinorWidth; k++)
      {
         double hl=high[i-k], hr=(i+k<=last)?high[i+k]:-DBL_MAX;
         if(hl>hi||hr>hi) tlmMin=false;
         double ll=low[i-k]; if(ll<swLow) swLow=ll;
         if(i+k<=last){ double lr=low[i+k]; if(lr<swLow) swLow=lr; }
      }
      for(int k=1; k<=InpMajorWidth; k++)
      { double hl=high[i-k], hr=(i+k<=last)?high[i+k]:-DBL_MAX; if(hl>hi||hr>hi) tlmMaj=false; }
      double tHeight=hi-swLow;
      bool isTop=(tlmMin && tHeight>=minorTh);
      int  tGrade=(tlmMaj && tHeight>=majorTh)?2:1;

      // --- Bottom候補 ---
      double lo=low[i], swHigh=high[i];
      bool blmMin=true, blmMaj=true;
      for(int k=1; k<=InpMinorWidth; k++)
      {
         double ll=low[i-k], lr=(i+k<=last)?low[i+k]:DBL_MAX;
         if(ll<lo||lr<lo) blmMin=false;
         double hl=high[i-k]; if(hl>swHigh) swHigh=hl;
         if(i+k<=last){ double hr=high[i+k]; if(hr>swHigh) swHigh=hr; }
      }
      for(int k=1; k<=InpMajorWidth; k++)
      { double ll=low[i-k], lr=(i+k<=last)?low[i+k]:DBL_MAX; if(ll<lo||lr<lo) blmMaj=false; }
      double bHeight=swHigh-lo;
      bool isBot=(blmMin && bHeight>=minorTh);
      int  bGrade=(blmMaj && bHeight>=majorTh)?2:1;

      // --- 表示対象の選別 ---
      bool topOK=isTop && (tGrade==2 || InpShowMinor);
      bool botOK=isBot && (bGrade==2 || InpShowMinor);
      int t=0, grade=0; double price=0.0, height=0.0;
      if(topOK && botOK)
      { if(tHeight>=bHeight){ t=1; grade=tGrade; price=hi; height=tHeight; }
        else                { t=-1; grade=bGrade; price=lo; height=bHeight; } }
      else if(topOK) { t=1;  grade=tGrade; price=hi; height=tHeight; }
      else if(botOK) { t=-1; grade=bGrade; price=lo; height=bHeight; }
      else continue;

      // --- 登録判定 ---
      bool doReg=false, clearOld=false;
      if(!InpZigZag) { doReg=true; clearOld=false; }
      else if(zzIdx<0) { doReg=true; }
      else if((i-zzIdx) < InpMinGapBars)
      {
         // 最小間隔以内の重複 → スイング幅が大きい方だけ残す
         if(height > zzHeight) { doReg=true; clearOld=true; }
      }
      else
      {
         if(t==zzType)
         {
            bool moreEx = (t==1)? (price>zzPrice) : (price<zzPrice);
            if(moreEx) { doReg=true; clearOld=true; }   // 同方向の連続は最極値へ
         }
         else { doReg=true; }                            // 反対方向 → 交互に登録
      }

      if(doReg)
      {
         if(clearOld && zzIdx>=0) { BufMajor[zzIdx]=0.0; BufMinor[zzIdx]=0.0; }
         if(grade==2) BufMajor[i]=t*2.0; else BufMinor[i]=t*1.0;
         zzIdx=i; zzType=t; zzPrice=price; zzHeight=height; zzGrade=grade;
      }

      if(InpAlert && i==end && time[i]!=g_lastAlertTime)
      {
         double v=(BufMajor[i]!=0.0)?BufMajor[i]:BufMinor[i];
         if(v== 2.0)      Alert(_Symbol," Major Top検出");
         else if(v== 1.0) Alert(_Symbol," Minor Top検出");
         else if(v==-1.0) Alert(_Symbol," Minor Bottom検出");
         else if(v==-2.0) Alert(_Symbol," Major Bottom検出");
         if(v!=0.0) g_lastAlertTime=time[i];
      }
   }
   return(rates_total);
}
//+------------------------------------------------------------------+
