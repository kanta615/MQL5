//+------------------------------------------------------------------+
//|                              DokaKotsu_EMA10_WMA_3.mq5            |
//|   _2の改良版：両方点灯(WMA同方向＋EMA10スパイク)を信頼し、        |
//|   圧縮フィルタを既定OFFにして「点灯と同時に」エントリー(早出し)。  |
//|   （表示のみ・発注はしない）                                     |
//|                                                                  |
//|   表示(すべてM5):                                                |
//|     ・EMA10  … 点灯=マゼンタ / 非点灯=グレー                      |
//|     ・WMA14  … 上昇=緑 / 下降=オレンジ / 平行=灰                  |
//|     ・SMA20  … BBセンターライン（決済の基準線）                  |
//|                                                                  |
//|   エントリー:                                                    |
//|   ・引き金 = M1のEMA10スパイク（M1なら急落も1〜2分で点灯）。      |
//|       M1が無い古い足はM5スパイクで代替（取りこぼし防止）。        |
//|   ・初回 = WMA同方向点灯(既定 GateMode=0)＋EMA10スパイクで即出す。|
//|       → 両方点灯した足で出る。圧縮フィルタは既定OFFなので、      |
//|         以前の「点灯から20分遅れ」を解消。                       |
//|   ・再エントリー = 同一トレンド継続中の決済後はトレンド方向の     |
//|       スパイクで即入り直し。                                     |
//|   ※ダマシ対策が必要なら InpUseSqueezeFilter=true で圧縮見送りを   |
//|     後から有効化できる（その分エントリーは遅くなる）。           |
//|                                                                  |
//|   決済(②④・仮):                                                |
//|   ・SMA20(M5)に接したら「終了(×)」。ロング:安値≤SMA20/         |
//|     ショート:高値≥SMA20。簡易な損切りはしない。                  |
//|                                                                  |
//|   ※M5チャートに入れて使う前提（_Period=M5想定）。              |
//|   ※M1の引き金で形成中のM5足に出る分は、その足確定まで生表示。    |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 9
#property indicator_plots   9

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
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrDodgerBlue
#property indicator_width6  1
#property indicator_style6  STYLE_DOT
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
#property indicator_color9  clrYellow
#property indicator_width9  3

//=== 入力パラメータ ==============================================
input int    InpEmaPeriod    = 10;    // EMA期間
input int    InpSmaPeriod    = 20;    // SMA期間(=BBセンターライン)
input int    InpWmaPeriod    = 14;    // WMA期間
input double InpSpikeTh       = 2.0;  // M5でEMA10が点灯(マゼンタ)する収束度
input double InpWmaSlopeTh    = 0.10; // WMA点灯(緑/オレンジ)のslopeしきい値
input bool   InpUseM1Trigger  = true; // 引き金にM1スパイクを使う(早出し)
input double InpM1SpikeTh      = 2.0; // M1スパイクの収束度しきい値(下げると更に早い)
input int    InpM1Bars         = 30000;// 取得するM1本数(直近・大きいほど過去も対応)
input int    InpWmaGateMode    = 0;   // WMAゲート 0:同方向必須(両方点灯/ダマシ減・既定) / 1:逆行でなければ許可(早い)
input bool   InpUseSqueezeFilter= false;// 圧縮フィルタ。既定OFF=両方点灯で即エントリー(早い)。ONでダマシ抑制
input double InpBBMult          = 2.0; // スクイーズ判定用 ボリンジャー偏差
input double InpKCMult          = 1.5; // スクイーズ判定用 ケルトナー幅(レンジ×)
input bool   InpSkipSqueezeOnReentry = true; // 同一トレンド継続中の決済後の再エントリーは圧縮フィルタを省く(早出し)
input bool   InpLightFromM1    = true;// M1スパイクの足もEMA10をマゼンタにする(点灯と矢印を一致)
input bool   InpAlert          = false;// エントリー/終了でアラート

//=== バッファ ====================================================
double BufEmaNorm[];
double BufEmaSpike[];
double BufWmaUp[];
double BufWmaDown[];
double BufWmaFlat[];
double BufSma20[];
double BufBuy[];
double BufSell[];
double BufExit[];

//=== アラート重複防止 ============================================
datetime g_lastAlertTime = 0;

int hEMA, hSMA, hWMA, hATR;          // M5(チャート足)
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
   SetIndexBuffer(6, BufBuy,      INDICATOR_DATA);
   SetIndexBuffer(7, BufSell,     INDICATOR_DATA);
   SetIndexBuffer(8, BufExit,     INDICATOR_DATA);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(6, PLOT_ARROW, 233);
   PlotIndexSetInteger(7, PLOT_ARROW, 234);
   PlotIndexSetInteger(8, PLOT_ARROW, 251);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, 0.0);

   // チャート足(M5想定)
   hEMA = iMA(_Symbol, _Period, InpEmaPeriod, 0, MODE_EMA,  PRICE_CLOSE);
   hSMA = iMA(_Symbol, _Period, InpSmaPeriod, 0, MODE_SMA,  PRICE_CLOSE);
   hWMA = iMA(_Symbol, _Period, InpWmaPeriod, 0, MODE_LWMA, PRICE_CLOSE);
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
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu EMA10+WMA v3");
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
   ArraySetAsSeries(wma,false); ArraySetAsSeries(atr,false);

   // --- M1の値（引き金用・直近 InpM1Bars 本）---
   datetime t1[]; double c1[], e1[], s1[], a1[], conv1[];
   int m1count = 0;
   if(InpUseM1Trigger && PeriodSeconds(_Period) > PeriodSeconds(PERIOD_M1))
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
      BufSma20[j]=EMPTY_VALUE;
      BufBuy[j]=0.0; BufSell[j]=0.0; BufExit[j]=0.0;
   }

   for(int i=need; i<rates_total; i++)
   {
      BufEmaNorm[i]=EMPTY_VALUE; BufEmaSpike[i]=EMPTY_VALUE;
      BufWmaUp[i]=EMPTY_VALUE;   BufWmaDown[i]=EMPTY_VALUE; BufWmaFlat[i]=EMPTY_VALUE;
      BufSma20[i]=sma[i];
      BufBuy[i]=0.0; BufSell[i]=0.0; BufExit[i]=0.0;
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
      if(InpUseSqueezeFilter)
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

      // --- ② 終了（保有中・SMA20接触）---
      if(pos==1)
      {
         if(low[i] <= sma[i])
         {
            BufExit[i]=sma[i]; pos=0;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
            { Alert(_Symbol," EMA10+WMA 終了(ロング)"); g_lastAlertTime=time[i]; }
         }
      }
      else if(pos==-1)
      {
         if(high[i] >= sma[i])
         {
            BufExit[i]=sma[i]; pos=0;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
            { Alert(_Symbol," EMA10+WMA 終了(ショート)"); g_lastAlertTime=time[i]; }
         }
      }

      // --- ① エントリー（ノーポジ時。決済後は同一トレンド継続でも再エントリー可）---
      if(pos==0)
      {
         int  d = 0;
         bool trig = false;
         if(InpUseM1Trigger && m1Onset)       // 早出し: M1の引き金優先
         {
            d = m1Dir; trig = (d!=0);
         }
         else if(spike5 && !prevSpike5)        // 代替: M5スパイクの点灯足
         {
            d = emaDir5; trig = (d!=0);
         }

         if(trig)
         {
            // 確立トレンドが続いていて既に1回入っている＝決済後の再エントリー
            bool reentry = (segHadEntry && d==trendDir);
            bool allow;
            if(reentry)
            {
               // 再エントリー: 方向は確立トレンドに一致。圧縮フィルタは(設定により)省いて速く出す
               allow = true;
               if(InpUseSqueezeFilter && !InpSkipSqueezeOnReentry && sqzOn) allow = false;
            }
            else
            {
               // 初回エントリー: WMA同方向必須＋圧縮中は見送り（ダマシ除去）
               if(InpWmaGateMode==0) allow = (wmaDir == d);   // 同方向必須(両方点灯)
               else                  allow = (wmaDir != -d);  // 逆行でなければ許可
               if(InpUseSqueezeFilter && sqzOn) allow = false; // 圧縮中は見送り
            }
            if(allow)
            {
               if(d==1)
               {
                  BufBuy[i] = low[i] - atr[i]*0.5;
                  pos = 1; segHadEntry = true; trendDir = 1;
                  if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
                  { Alert(_Symbol," EMA10+WMA BUYエントリー"); g_lastAlertTime=time[i]; }
               }
               else
               {
                  BufSell[i] = high[i] + atr[i]*0.5;
                  pos = -1; segHadEntry = true; trendDir = -1;
                  if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
                  { Alert(_Symbol," EMA10+WMA SELLエントリー"); g_lastAlertTime=time[i]; }
               }
            }
         }
      }

      prevSpike5 = spike5;
   }
   return(rates_total);
}
//+------------------------------------------------------------------+
