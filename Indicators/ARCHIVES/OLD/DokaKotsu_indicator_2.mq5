//+------------------------------------------------------------------+
//|                              DokaKotsu_indicator_2.mq5            |
//|   ベースMA主役版：選んだMA(10種)の傾きでグレーゾーン判定し、     |
//|   矢印を出す。M1スパイク/圧縮/オーバーシュートは「任意フィルター」|
//|   として個別にON/OFF。全OFFならベースMAだけでシグナル。          |
//|   (表示のみ・発注はしない)                                       |
//|                                                                  |
//|   ベースMA(InpWmaType): SMA/WMA/SMMA/TMA/VWMA/KAMA/VIDYA/        |
//|     FRAMA/ATR Adaptive/ATR Trend から1つ選択。                   |
//|     その傾き(slope)が +しきい値→上(緑)/ -しきい値→下(オレンジ)/  |
//|     間→平行(グレー=待機)。色がついた方向に矢印を出す。           |
//|                                                                  |
//|   任意フィルター(初期は全OFF。1つずつONで差異を検証):            |
//|     ①InpFilM1Spike   : M1スパイク点灯を要求(だまし対策)          |
//|     ②InpFilSqueeze   : 圧縮(スクイーズ)中は弾く                 |
//|     ③InpFilOvershoot : オーバーシュート(急変飛び乗り)を弾く     |
//|                                                                  |
//|   ※M5チャートに入れて使う前提(_Period=M5想定)。               |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "3.00"

//=== バージョン情報(最新版か確認用) ==============================
#define DK_VERSION   "v2.5"
#define DK_BUILD     "2026-06-06 05:00"
#property indicator_chart_window
#property indicator_buffers 11
#property indicator_plots   10

//--- EMA10 非点灯(グレー)
#property indicator_label1  "EMA10_NORM"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGray
#property indicator_width1  2
//--- EMA10 点灯(マゼンタ)
#property indicator_label2  "EMA10_SPIKE"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMagenta
#property indicator_width2  3
//--- WMA14 上昇(緑)
#property indicator_label3  "WMA_UP"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLime
#property indicator_width3  2
//--- WMA14 下降(オレンジ)
#property indicator_label4  "WMA_DOWN"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_width4  2
//--- WMA14 平行(灰)
#property indicator_label5  "WMA_FLAT"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrDimGray
#property indicator_width5  2
//--- SMA20 センターライン
#property indicator_label6  "SMA20_CENTER"
#property indicator_type6   DRAW_COLOR_LINE
#property indicator_color6  clrAqua,clrLightSkyBlue,clrGray,clrPlum,clrMagenta
#property indicator_width6  3
//--- BUYエントリー矢印
#property indicator_label7  "ENTRY_BUY"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrAqua
#property indicator_width7  4
//--- SELLエントリー矢印
#property indicator_label8  "ENTRY_SELL"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrRed
#property indicator_width8  4
//--- 終了マーカー(×)
#property indicator_label9  "EXIT"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  clrOrange
#property indicator_width9  5

#property indicator_label10 "OVERSHOOT"
#property indicator_type10  DRAW_ARROW
#property indicator_color10 clrMagenta
#property indicator_width10 2

//=== 入力パラメータ ==============================================
enum ENUM_WMATYPE
{
   WT_SMA,        // SMA
   WT_WMA,        // WMA
   WT_SMMA,       // SMMA(Smoothed)
   WT_TMA,        // TMA(Triangular)
   WT_VWMA,       // VWMA(Volume Weighted)
   WT_KAMA,       // KAMA(Kaufman Adaptive)
   WT_VIDYA,      // VIDYA(Variable Index Dynamic)
   WT_FRAMA,      // FRAMA(Fractal Adaptive)
   WT_ATR_ADAPT,  // ATR Adaptive(ATR水準でα可変)
   WT_ATR_TREND   // ATR Trend(ATR傾きでα可変)
};
input string InpVersionInfo = "v2.5 / 2026-06-06 05:00"; // ★バージョン(最新確認用・変更不要)
input ENUM_WMATYPE InpWmaType   = WT_KAMA; // ★WMA(方向判定線)の種類
input int          InpWmaPeriod = 14; // WMA期間
//--- 追加フィルター(初期は全部OFF=ベースMAだけでシグナル。1つずつONで検証) ---
input bool   InpFilM1Spike     = false;// ①M1スパイク要求(だまし対策・タイミング)
input bool   InpFilSqueeze     = false;// ②圧縮中は弾く(スクイーズのダマシ対策)
input bool   InpFilOvershoot   = false;// ③オーバーシュートを弾く(急変飛び乗り対策)
input double InpAtrFastA      = 0.6;  // ATR適応:速い時のα(0〜1・大きいほど速い)
input double InpAtrSlowA      = 0.05; // ATR適応:遅い時のα(0〜1・小さいほど滑らか)
input int    InpAtrRefPeriod  = 50;   // ATR適応:ATR平均/変化率の参照期間
input bool   InpHighVolFaster = true; // ATR Adaptive:高ボラで速くするか(既定false=高ボラで遅く)
input int    InpEmaPeriod    = 10;    // EMA期間
input int    InpSmaPeriod    = 5;     // SMA期間(=BBセンターライン)
input int    InpSma2ndPeriod = 20;    // ★二重平滑の期間(1=平滑なし。変えて×の出方を見る)
input double InpSpikeTh       = 2.0;  // M5でEMA10が点灯(マゼンタ)する収束度
input double InpWmaSlopeTh    = 0.10; // WMA点灯(緑/オレンジ)のslopeしきい値
input double InpM1SpikeTh      = 2.0; // M1スパイクの収束度しきい値(フィルター①ON時)
input int    InpM1Bars         = 30000;// 取得するM1本数(フィルター①ON時)
input double InpBBMult          = 2.0; // スクイーズ判定用 ボリンジャー偏差(フィルター②ON時)
input double InpKCMult          = 1.5; // スクイーズ判定用 ケルトナー幅(フィルター②ON時)
input bool   InpLightFromM1    = true;// M1スパイクの足もEMA10をマゼンタにする(点灯と矢印を一致)
input bool   InpAlert          = true; // エントリー/終了でアラート


//=== バッファ ====================================================
double BufEmaNorm[];
double BufEmaSpike[];
double BufWmaUp[];
double BufWmaDown[];
double BufWmaFlat[];
double BufSma20[];
double BufSma20Col[];    // SMA20の5段階カラーインデックス
double BufBuy[];
double BufSell[];
double BufExit[];
double BufOvershoot[];   // オーバーシュート(急変・行き過ぎ)印

//=== アラート重複防止 ============================================
datetime g_lastAlertTime = 0;

int hEMA, hSMA, hWMA, hATR;          // M5(チャート足)
int hKAMA=-1, hVIDYA=-1, hFRAMA=-1;  // 適応型MA(標準関数)
int hEMA1, hSMA1, hATR1;             // M1



//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufEmaNorm,  INDICATOR_DATA);
   SetIndexBuffer(1, BufEmaSpike, INDICATOR_DATA);
   SetIndexBuffer(2, BufWmaUp,    INDICATOR_DATA);
   SetIndexBuffer(3, BufWmaDown,  INDICATOR_DATA);
   SetIndexBuffer(4, BufWmaFlat,  INDICATOR_DATA);
   SetIndexBuffer(5, BufSma20,    INDICATOR_DATA);
   SetIndexBuffer(6, BufSma20Col, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(7, BufBuy,      INDICATOR_DATA);
   SetIndexBuffer(8, BufSell,     INDICATOR_DATA);
   SetIndexBuffer(9, BufExit,     INDICATOR_DATA);
   SetIndexBuffer(10, BufOvershoot, INDICATOR_DATA);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   // SMA20(plot5)を5段階カラーに
   PlotIndexSetInteger(5, PLOT_COLOR_INDEXES, 5);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 0, clrAqua);          // 強い上昇
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 1, clrLightSkyBlue);  // 上昇
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 2, clrGray);          // レンジ
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 3, clrPlum);          // 下降(薄マゼンタ)
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 4, clrMagenta);       // 強い下降
   PlotIndexSetInteger(6, PLOT_ARROW, 233);
   PlotIndexSetInteger(7, PLOT_ARROW, 234);
   PlotIndexSetInteger(8, PLOT_ARROW, 251);            // EXIT(×印)
   PlotIndexSetInteger(8, PLOT_LINE_WIDTH, 5);         // 決済マークを大きく
   PlotIndexSetInteger(9, PLOT_ARROW, 251);            // オーバーシュート印
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, clrMagenta);
   PlotIndexSetInteger(9, PLOT_LINE_WIDTH, 2);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(9, PLOT_EMPTY_VALUE, 0.0);

   // チャート足(M5想定)
   hEMA = iMA(_Symbol, _Period, InpEmaPeriod, 0, MODE_EMA,  PRICE_CLOSE);
   hSMA = iMA(_Symbol, _Period, InpSmaPeriod, 0, MODE_SMA,  PRICE_CLOSE);
   // WMA(方向判定線)は種類選択。SMA/WMA/SMMAはiMA、TMA/VWMAは自前計算。
   ENUM_MA_METHOD wmode = MODE_LWMA;
   if(InpWmaType==WT_SMA)       wmode = MODE_SMA;
   else if(InpWmaType==WT_WMA)  wmode = MODE_LWMA;
   else if(InpWmaType==WT_SMMA) wmode = MODE_SMMA;
   else                         wmode = MODE_SMA;  // TMA/VWMAは仮(後で上書き計算)
   hWMA = iMA(_Symbol, _Period, InpWmaPeriod, 0, wmode, PRICE_CLOSE);
   // 適応型MA(標準関数)。選択時のみ実際に使う
   if(InpWmaType==WT_KAMA)
      hKAMA = iAMA(_Symbol, _Period, InpWmaPeriod, 2, 30, 0, PRICE_CLOSE);
   if(InpWmaType==WT_VIDYA)
      hVIDYA = iVIDyA(_Symbol, _Period, 9, 12, 0, PRICE_CLOSE);
   if(InpWmaType==WT_FRAMA)
      hFRAMA = iFrAMA(_Symbol, _Period, InpWmaPeriod, 0, PRICE_CLOSE);
   hATR = iATR(_Symbol, _Period, 14);
   // M1(引き金用)
   hEMA1 = iMA(_Symbol, PERIOD_M1, InpEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hSMA1 = iMA(_Symbol, PERIOD_M1, InpSmaPeriod, 0, MODE_SMA, PRICE_CLOSE);
   hATR1 = iATR(_Symbol, PERIOD_M1, 14);

   if(hEMA==INVALID_HANDLE || hSMA==INVALID_HANDLE || hWMA==INVALID_HANDLE ||
      hATR==INVALID_HANDLE || hEMA1==INVALID_HANDLE || hSMA1==INVALID_HANDLE ||
      hATR1==INVALID_HANDLE)
   {
      Print("ハンドル作成失敗");
      return(INIT_FAILED);
   }
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("DokaKotsu indicator_2 [%s %s]", DK_VERSION, DK_BUILD));

   // チャート左上にバージョンと日時のラベルを出す(最新版か一目で確認)
   string vname = "DK2_version_label";
   if(ObjectFind(0, vname) < 0)
      ObjectCreate(0, vname, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, vname, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, vname, OBJPROP_XDISTANCE, 5);
   ObjectSetInteger(0, vname, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, vname, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, vname, OBJPROP_FONTSIZE, 9);
   ObjectSetString (0, vname, OBJPROP_TEXT,
      StringFormat("DokaKotsu indicator_2  %s  (build %s)", DK_VERSION, DK_BUILD));
   ObjectSetInteger(0, vname, OBJPROP_SELECTABLE, false);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, "DK2_version_label");
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
   int need = MathMax(MathMax(InpEmaPeriod, InpSmaPeriod), InpWmaPeriod) + 5;
   if(rates_total < need + 2) return(0);

   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);

   // --- チャート足(M5)の値 ---
   double ema[], sma[], wma[], atr[];
   if(CopyBuffer(hEMA,0,0,rates_total,ema)<=0) return(prev_calculated);
   if(CopyBuffer(hSMA,0,0,rates_total,sma)<=0) return(prev_calculated);
   if(CopyBuffer(hWMA,0,0,rates_total,wma)<=0) return(prev_calculated);
   if(CopyBuffer(hATR,0,0,rates_total,atr)<=0) return(prev_calculated);
   ArraySetAsSeries(ema,false); ArraySetAsSeries(sma,false);

   // SMA20を二重平滑(さらに期間Nで平均)して滑らかにする。
   //   カクつき軽減。グレー判定のタイミングも滑らかになる。
   double sma2[]; ArrayResize(sma2, rates_total);
   int smN = MathMax(1, InpSma2ndPeriod);   // 二次平滑の期間(入力で調整。1=平滑なし)
   for(int i=0;i<rates_total;i++)
   {
      if(i < smN-1){ sma2[i]=sma[i]; continue; }
      double s=0; for(int k=0;k<smN;k++) s+=sma[i-k];
      sma2[i]=s/smN;
   }
   ArraySetAsSeries(wma,false); ArraySetAsSeries(atr,false);

   // TMA/VWMA は iMA に無いので自前計算で wma[] を上書き
   if(InpWmaType==WT_TMA)
   {
      // 三角移動平均 = SMAを2回かける
      int h=(InpWmaPeriod+1)/2;
      double tmp[]; ArrayResize(tmp,rates_total);
      for(int i=0;i<rates_total;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=close[i-k];c++;} tmp[i]=(c>0)?s/c:close[i]; }
      for(int i=0;i<rates_total;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=tmp[i-k];c++;} wma[i]=(c>0)?s/c:close[i]; }
   }
   else if(InpWmaType==WT_VWMA)
   {
      // 出来高加重移動平均
      for(int i=0;i<rates_total;i++)
      {
         if(i<InpWmaPeriod-1){ wma[i]=close[i]; continue; }
         double sp=0,sv=0;
         for(int k=0;k<InpWmaPeriod;k++){ double v=(double)tick_volume[i-k]; sp+=close[i-k]*v; sv+=v; }
         wma[i]=(sv>0)?sp/sv:close[i];
      }
   }
   else if(InpWmaType==WT_KAMA && hKAMA!=INVALID_HANDLE && hKAMA>=0)
   {
      double buf[];
      if(CopyBuffer(hKAMA,0,0,rates_total,buf)>0)
      { ArraySetAsSeries(buf,false); for(int i=0;i<rates_total;i++) wma[i]=buf[i]; }
   }
   else if(InpWmaType==WT_VIDYA && hVIDYA!=INVALID_HANDLE && hVIDYA>=0)
   {
      double buf[];
      if(CopyBuffer(hVIDYA,0,0,rates_total,buf)>0)
      { ArraySetAsSeries(buf,false); for(int i=0;i<rates_total;i++) wma[i]=buf[i]; }
   }
   else if(InpWmaType==WT_FRAMA && hFRAMA!=INVALID_HANDLE && hFRAMA>=0)
   {
      double buf[];
      if(CopyBuffer(hFRAMA,0,0,rates_total,buf)>0)
      { ArraySetAsSeries(buf,false); for(int i=0;i<rates_total;i++) wma[i]=buf[i]; }
   }
   else if(InpWmaType==WT_ATR_ADAPT)
   {
      // ATR Adaptive: ATRの「水準」(ATR / ATR平均)でαを変える適応EMA
      //   既定(InpHighVolFaster=false): 高ボラで遅く(なめらか)
      //   true: 高ボラで速く
      for(int i=0;i<rates_total;i++)
      {
         if(i<1){ wma[i]=close[i]; continue; }
         // ATR平均(参照期間)
         double am=0; int ac=0;
         for(int k=0;k<InpAtrRefPeriod && i-k>=0;k++){ am+=atr[i-k]; ac++; }
         am=(ac>0)?am/ac:atr[i];
         double ratio=(am>0)?atr[i]/am:1.0;       // ATR水準(1で平均並み)
         // ratioを0〜1に写像してαを決める(高ratio=高ボラ)
         double t=MathMin(2.0,MathMax(0.0,ratio))/2.0; // 0〜1
         double a;
         if(InpHighVolFaster) a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t;       // 高ボラで速い
         else                 a=InpAtrFastA-(InpAtrFastA-InpAtrSlowA)*t;       // 高ボラで遅い
         wma[i]=close[i]*a + wma[i-1]*(1.0-a);
      }
   }
   else if(InpWmaType==WT_ATR_TREND)
   {
      // ATR Trend: ATRの「傾き」(過去N本との変化率)でαを変える適応EMA
      //   ATR拡大局面で速く追従。
      for(int i=0;i<rates_total;i++)
      {
         if(i<1){ wma[i]=close[i]; continue; }
         int j=MathMax(0,i-InpAtrRefPeriod);
         double base=atr[j];
         double chg=(base>0)?(atr[i]-base)/base:0.0;  // ATR変化率(+で拡大)
         double t=MathMin(1.0,MathMax(0.0,chg));       // 0〜1(拡大ほど1)
         double a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t; // 拡大で速い
         wma[i]=close[i]*a + wma[i-1]*(1.0-a);
      }
   }

   // --- M1の値（引き金用・直近 InpM1Bars 本）---
   datetime t1[]; double c1[], e1[], s1[], a1[], conv1[];
   int m1count = 0;
   if(InpFilM1Spike && PeriodSeconds(_Period) > PeriodSeconds(PERIOD_M1))
   {
      int want = InpM1Bars;
      int nT = CopyTime(_Symbol, PERIOD_M1, 0, want, t1);
      int nC = CopyClose(_Symbol, PERIOD_M1, 0, want, c1);
      int nE = CopyBuffer(hEMA1, 0, 0, want, e1);
      int nS = CopyBuffer(hSMA1, 0, 0, want, s1);
      int nA = CopyBuffer(hATR1, 0, 0, want, a1);
      if(nT>0 && nC>0 && nE>0 && nS>0 && nA>0)
      {
         ArraySetAsSeries(t1,false); ArraySetAsSeries(c1,false);
         ArraySetAsSeries(e1,false); ArraySetAsSeries(s1,false);
         ArraySetAsSeries(a1,false);
         m1count = MathMin(MathMin(nT,nC), MathMin(MathMin(nE,nS),nA));
         ArrayResize(conv1, m1count);
         for(int k=0; k<m1count; k++)
         {
            if(a1[k] > 0)
            {
               double sp1 = MathMax(MathMax(MathAbs(c1[k]-e1[k]),
                                            MathAbs(c1[k]-s1[k])),
                                            MathAbs(e1[k]-s1[k]));
               conv1[k] = sp1/a1[k];
            }
            else conv1[k] = 0.0;
         }
      }
   }

   int barSecs = PeriodSeconds(_Period);

   // ポジション状態は先頭から順に追うため毎回 need から全再計算。
   int  pos        = 0;
   int  trendDir   = 0;     // 確立中のWMAトレンド方向(灰を挟んでも継続・反対色で更新)
   bool segHadEntry= false; // 現トレンドで既に1回エントリーしたか
   bool prevSpike5 = false;
   int  p1         = 0;   // M1配列を前進させるポインタ

   // ウォームアップ区間を空に
   for(int j=0; j<need && j<rates_total; j++)
   {
      BufEmaNorm[j]=EMPTY_VALUE; BufEmaSpike[j]=EMPTY_VALUE;
      BufWmaUp[j]=EMPTY_VALUE;   BufWmaDown[j]=EMPTY_VALUE; BufWmaFlat[j]=EMPTY_VALUE;
      BufSma20[j]=EMPTY_VALUE; BufSma20Col[j]=2;
      BufBuy[j]=0.0; BufSell[j]=0.0; BufExit[j]=0.0; BufOvershoot[j]=0.0;
   }

   for(int i=need; i<rates_total; i++)
   {
      BufEmaNorm[i]=EMPTY_VALUE; BufEmaSpike[i]=EMPTY_VALUE;
      BufWmaUp[i]=EMPTY_VALUE;   BufWmaDown[i]=EMPTY_VALUE; BufWmaFlat[i]=EMPTY_VALUE;
      BufSma20[i]=sma2[i];
      // SMA20(二重平滑)の傾きで5段階カラー(アクア→水色→グレー→薄マゼンタ→マゼンタ)
      if(i>=1 && atr[i]>0)
      {
         double sl = (sma2[i]-sma2[i-1])/atr[i];
         int sc;
         if(sl >=  InpWmaSlopeTh*1.5)      sc=0; // 強い上昇 アクア
         else if(sl >=  InpWmaSlopeTh*0.5) sc=1; // 上昇     水色
         else if(sl <= -InpWmaSlopeTh*1.5) sc=4; // 強い下降 マゼンタ
         else if(sl <= -InpWmaSlopeTh*0.5) sc=3; // 下降     薄マゼンタ
         else                              sc=2; // レンジ   グレー
         BufSma20Col[i]=sc;
      }
      else BufSma20Col[i]=2;
      BufBuy[i]=0.0; BufSell[i]=0.0; BufExit[i]=0.0; BufOvershoot[i]=0.0;
      if(atr[i]<=0) continue;

      double price = close[i];

      // --- M5 EMA10スパイク（表示＆代替トリガー）---
      double sp5 = MathMax(MathMax(MathAbs(price-ema[i]),
                                   MathAbs(price-sma[i])),
                                   MathAbs(ema[i]-sma[i]));
      double conv5 = sp5/atr[i];
      bool spike5 = (conv5 > InpSpikeTh);
      int emaDir5 = 0;
      if(price > ema[i]) emaDir5 = 1; else if(price < ema[i]) emaDir5 = -1;

      // --- M1の引き金（このM5足の中で最初のM1スパイク点灯を探す）---
      int  m1Dir = 0;
      bool m1Onset = false;
      if(m1count > 0)
      {
         datetime t0 = time[i];
         datetime te = time[i] + barSecs;
         while(p1 < m1count && t1[p1] < t0) p1++;     // この足の先頭まで前進
         int q = p1;
         while(q < m1count && t1[q] < te)             // この足の中を走査
         {
            bool onsetq = (conv1[q] > InpM1SpikeTh) &&
                          (q==0 || conv1[q-1] <= InpM1SpikeTh);
            if(onsetq)
            {
               m1Onset = true;
               if(c1[q] > e1[q]) m1Dir = 1; else if(c1[q] < e1[q]) m1Dir = -1;
               break;
            }
            q++;
         }
      }

      // --- EMA10の色（M1点灯も反映するオプション）---
      bool lit = spike5 || (InpLightFromM1 && m1Onset);
      if(lit) { BufEmaSpike[i]=ema[i]; BufEmaSpike[i-1]=ema[i-1]; }
      else    { BufEmaNorm[i] =ema[i]; BufEmaNorm[i-1] =ema[i-1]; }

      // --- WMAの色 ---
      double slope = (wma[i]-wma[i-1])/atr[i];
      int wmaDir = 0;
      if(slope >  InpWmaSlopeTh) wmaDir = 1;
      else if(slope < -InpWmaSlopeTh) wmaDir = -1;
      if(wmaDir==1)      { BufWmaUp[i]=wma[i];   BufWmaUp[i-1]=wma[i-1]; }
      else if(wmaDir==-1){ BufWmaDown[i]=wma[i]; BufWmaDown[i-1]=wma[i-1]; }
      else               { BufWmaFlat[i]=wma[i]; BufWmaFlat[i-1]=wma[i-1]; }

      // --- WMAトレンドの更新（灰は継続扱い・反対色の点灯で新トレンド）---
      if(wmaDir==1 && trendDir!=1)        { trendDir=1;  segHadEntry=false; }
      else if(wmaDir==-1 && trendDir!=-1) { trendDir=-1; segHadEntry=false; }

      // --- 圧縮(スクイーズ)判定（BBがKCの内側=圧縮）M5基準 ---
      bool sqzOn = false;
      if(InpFilSqueeze)
      {
         double basis = sma[i];
         double var = 0.0, rsum = 0.0;
         for(int k=0; k<InpSmaPeriod; k++)
         {
            double dd = close[i-k]-basis; var += dd*dd;
            int jj = i-k;
            double rng;
            if(jj>0)
            {
               double aa = high[jj]-low[jj];
               double bb = MathAbs(high[jj]-close[jj-1]);
               double cc = MathAbs(low[jj]-close[jj-1]);
               rng = MathMax(aa, MathMax(bb,cc));
            }
            else rng = high[jj]-low[jj];
            rsum += rng;
         }
         double sd      = MathSqrt(var/InpSmaPeriod);
         double rangema = rsum/InpSmaPeriod;
         double upBB = basis + InpBBMult*sd,      loBB = basis - InpBBMult*sd;
         double upKC = basis + InpKCMult*rangema, loKC = basis - InpKCMult*rangema;
         sqzOn = (loBB > loKC) && (upBB < upKC);   // BBがKC内 = 圧縮
      }

      bool isLastBar = (i==rates_total-1);

      // ── オーバーシュート判定(大きな波の最終局面の急変) ──
      //   条件1: BB拡大中(圧縮でない=波が進行) 条件2: 直近3本の変化がATR2.5倍超
      //   Python(analyzer)と同じ条件。両方成立で印を出す。
      if(i >= 3 && atr[i] > 0 && !sqzOn)
      {
         double mv = MathAbs(close[i] - close[i-3]);
         if(mv >= atr[i]*2.5)
            BufOvershoot[i] = high[i] + atr[i]*1.2;   // ローソク上にマゼンタ印
      }

      // --- ② 終了（考え方A: 保有中の決済）---
      //   決済1: 終値がSMA20(二重平滑)を逆方向に抜けた(ヒゲでなく終値で判定)
      //   決済2: ベースMAの色が保有と逆方向に転換した(トレンド終了の手仕舞い)
      bool justExited = false;   // この足で決済したか(同足ドテン防止)
      if(pos==1)
      {
         bool exitCross = (close[i] < sma2[i]);   // 終値がSMA20を下抜け
         bool exitTrend = (wmaDir == -1);         // ベースMAが下降に転換
         if(exitCross || exitTrend)
         {
            BufExit[i]=sma2[i]; pos=0; justExited=true;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
            { Alert(_Symbol," 終了(ロング)"); g_lastAlertTime=time[i]; }
         }
      }
      else if(pos==-1)
      {
         bool exitCross = (close[i] > sma2[i]);   // 終値がSMA20を上抜け
         bool exitTrend = (wmaDir == 1);          // ベースMAが上昇に転換
         if(exitCross || exitTrend)
         {
            BufExit[i]=sma2[i]; pos=0; justExited=true;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
            { Alert(_Symbol," 終了(ショート)"); g_lastAlertTime=time[i]; }
         }
      }

      // --- ① エントリー（ノーポジ時。ただし決済と同じ足ではドテンしない）---
      if(pos==0 && !justExited)
      {
         // ── 新方式: ベースMA(選択したMAのslope方向)が主役 ──
         //   方向 d は wmaDir(=ベースMAの傾き) で決める。
         //   M1スパイク/圧縮/オーバーシュートは「任意フィルター」。
         //   全フィルターOFFなら、ベースMAの傾きだけで矢印を出す。
         int d = wmaDir;   // ベースMAの傾き方向(1=上/-1=下/0=平行グレー)

         if(d != 0)
         {
            bool allow = true;

            // ①M1スパイク要求(ONの時だけ)：引き金が同方向に点灯していること
            if(InpFilM1Spike)
            {
               bool m1ok = (m1Onset && m1Dir==d);
               bool m5ok = (spike5 && !prevSpike5 && emaDir5==d);
               if(!(m1ok || m5ok)) allow = false;
            }

            // ②圧縮フィルター(ONの時だけ)：スクイーズ中は弾く
            if(InpFilSqueeze && sqzOn) allow = false;

            // ③オーバーシュートフィルター(ONの時だけ)：急変・行き過ぎは弾く
            if(InpFilOvershoot && BufOvershoot[i] != 0.0) allow = false;

            // 既に同方向で1回出していたら、平行(グレー)に戻るまで再度出さない
            //   (レンジでの連続矢印を防ぐ。trendDirが変わればまた出せる)
            if(segHadEntry && d==trendDir) allow = false;

            if(allow)
            {
               if(d==1)
               {
                  BufBuy[i] = low[i] - atr[i]*0.5;
                  pos = 1; segHadEntry = true; trendDir = 1;
                  if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
                  { Alert(_Symbol," BUYシグナル(ベースMA)"); g_lastAlertTime=time[i]; }
               }
               else
               {
                  BufSell[i] = high[i] + atr[i]*0.5;
                  pos = -1; segHadEntry = true; trendDir = -1;
                  if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
                  { Alert(_Symbol," SELLシグナル(ベースMA)"); g_lastAlertTime=time[i]; }
               }
            }
         }
      }

      prevSpike5 = spike5;
   }
   return(rates_total);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
