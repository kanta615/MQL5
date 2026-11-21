//+------------------------------------------------------------------+
//|                                                 DokaKotsu_MA.mq5  |
//|   Multi-method MA + 5-stage gray-zone coloring (comparison build) |
//|   バージョン : V3.0 (MA種別17種=本家インジと同一ロジックに統一)    |
//|   更新       : 2026-06-23                                          |
//|                                                                   |
//|   MA種別を1つのenumで切替できる比較用インジ。                     |
//|   17種(SMA/WMA/SMMA/TMA/VWMA/KAMA/VIDYA/FRAMA/ATR Adaptive/        |
//|   ATR Trend/EMA/HMA/DEMA/ZLEMA/MAMA/LSMA/VWAP)を同じ土俵で比較。   |
//|   ※追加MAの計算式は DokaKotsu_indicator_8 と完全一致(移植)。      |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "3.00"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   1

//--- 5段階カラーのライン (青=上昇 / グレー=中立 / 黄=下降)
#property indicator_label1  "DokaKotsu_MA"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrRoyalBlue, clrDeepSkyBlue, clrGray, clrGold, clrOrange
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- MA種別の選択肢(本家 DokaKotsu_indicator_8 の ENUM_WMATYPE と同一順・同一ラベル)
enum ENUM_GZ_MA
  {
   GZ_SMA,         // SMA
   GZ_WMA,         // WMA
   GZ_SMMA,        // SMMA (Smoothed)
   GZ_TMA,         // TMA (Triangular)
   GZ_VWMA,        // VWMA (Volume Weighted)
   GZ_KAMA,        // KAMA (Kaufman Adaptive)
   GZ_VIDYA,       // VIDYA (Variable Index Dynamic)
   GZ_FRAMA,       // FRAMA (Fractal Adaptive)
   GZ_ATR_ADAPT,   // ATR Adaptive (ATR水準で可変)
   GZ_ATR_TREND,   // ATR Trend (ATR傾きで可変)
   GZ_EMA,         // EMA (指数平滑)
   GZ_HMA,         // HMA (Hull)
   GZ_DEMA,        // DEMA (Double EMA)
   GZ_ZLEMA,       // ZLEMA (Zero Lag EMA)
   GZ_MAMA,        // MAMA (MESA Adaptive)
   GZ_LSMA,        // LSMA (Least Squares)
   GZ_VWAP         // VWAP (直近N本ローリング)
  };

input group             "=== MA selection ==="
input ENUM_GZ_MA         InpMaType   = GZ_SMA;         // MA種別
input int                InpPeriod   = 240;            // 基本期間
input ENUM_APPLIED_PRICE InpPrice    = PRICE_CLOSE;    // 適用価格(標準/適応ハンドル型のみ。自前計算型はCloseで本家と一致)
input int                InpShift    = 0;              // シフト

input group             "=== KAMA / VIDYA ==="
input int                InpKamaFast = 2;              // KAMA 速いEMA期間(本家=2)
input int                InpKamaSlow = 30;             // KAMA 遅いEMA期間(本家=30)
input int                InpVidyaCmo = 9;              // VIDYA CMO期間(本家=9)
input int                InpVidyaEma = 12;             // VIDYA EMA期間(本家=12)

input group             "=== MAMA (MESA Adaptive) ==="
input double             InpMamaFast = 0.5;            // MAMA FastLimit(速さ上限)
input double             InpMamaSlow = 0.05;           // MAMA SlowLimit(速さ下限)

input group             "=== ATR Adaptive / ATR Trend (本家と同一式) ==="
input int                InpAtrPeriod    = 14;         // ATR期間(適応の素材)
input int                InpAtrRefPeriod = 50;         // ATR参照期間(水準/傾きの基準)
input double             InpAtrFastA     = 0.6;        // 適応α 速い側(大=追従)
input double             InpAtrSlowA     = 0.05;       // 適応α 遅い側(小=なめらか)
input bool               InpHighVolFaster = false;     // ATR Adaptive:高ボラで速くする?(既定=遅く)

input group             "=== 5段階カラー(傾きはATRで正規化) ==="
input int                InpSlopeBars    = 5;          // 傾きを測る本数(遅いMAは5〜10推奨)
input double             InpGrayTh       = 0.03;       // グレー閾値:これ未満=ほぼ水平=グレー
input double             InpColorTh      = 0.06;       // 色閾値:これ以上=しっかり角度=フル色(必ず Gray < Color)
input int                InpAtrColPeriod = 14;         // 正規化に使うATR期間
input double             InpStickyMult   = 1.7;        // ヒステリシス:グレーから出るのに必要な角度=GrayTh×この倍率

input group             "=== 5色(自由に選択可) ==="
input color              InpColUp       = clrRoyalBlue;   // ①上昇(角度あり)
input color              InpColUpEdge   = clrDeepSkyBlue; // ②上昇の境目(中間色)
input color              InpColGray     = clrGray;        // ③グレー(ほぼ水平=レンジ)
input color              InpColDownEdge = clrGold;        // ④下降の境目(中間色)
input color              InpColDown     = clrOrange;      // ⑤下降(角度あり)

//--- バッファ
double MaBuffer[];      // 表示するMA本体
double ColorBuffer[];   // 0..4 のカラーインデックス
double AtrBuffer[];     // ATR系/色正規化の計算用(非表示)

int    g_handle    = INVALID_HANDLE;   // 標準/適応(組込み)MAのハンドル
int    g_atrHandle = INVALID_HANDLE;   // ATRハンドル(ATR Adaptive/Trend用)
int    g_colAtr    = INVALID_HANDLE;   // ATRハンドル(色の傾き正規化用・常時)
bool   g_selfCalc  = false;            // 自前計算型(TMA/VWMA/ATR×2/HMA/DEMA/ZLEMA/MAMA/LSMA/VWAP)=true

//+------------------------------------------------------------------+
//| 追加MA(HMA/DEMA/ZLEMA/MAMA/LSMA/VWAP)の計算。配列は非時系列(0=古)|
//|   ※本家 DokaKotsu_indicator_8 と完全一致。                       |
//+------------------------------------------------------------------+
double LWMAat(const double &src[], const int i, int n)
  {
   if(n<1) n=1;
   if(i < n-1) n = i+1;
   double s=0.0, w=0.0;
   for(int k=0;k<n;k++){ int ww=n-k; s+=src[i-k]*ww; w+=ww; }
   return (w>0.0)? s/w : src[i];
  }
void Calc_HMA(double &out[], const double &close[], const int period, const int rt)
  {
   ArrayResize(out, rt);
   int half=MathMax(1, period/2);
   int sq  =MathMax(1, (int)MathRound(MathSqrt((double)period)));
   double raw[]; ArrayResize(raw, rt);
   for(int i=0;i<rt;i++){ double w1=LWMAat(close,i,half), w2=LWMAat(close,i,period); raw[i]=2.0*w1-w2; }
   for(int i=0;i<rt;i++) out[i]=LWMAat(raw,i,sq);
  }
void Calc_DEMA(double &out[], const double &close[], const int period, const int rt)
  {
   ArrayResize(out, rt);
   double pr=2.0/(period+1.0);
   double e1[],e2[]; ArrayResize(e1,rt); ArrayResize(e2,rt);
   for(int i=0;i<rt;i++) e1[i]=(i==0)?close[i]:close[i]*pr+e1[i-1]*(1.0-pr);
   for(int i=0;i<rt;i++) e2[i]=(i==0)?e1[i]   :e1[i] *pr+e2[i-1]*(1.0-pr);
   for(int i=0;i<rt;i++) out[i]=2.0*e1[i]-e2[i];
  }
void Calc_ZLEMA(double &out[], const double &close[], const int period, const int rt)
  {
   ArrayResize(out, rt);
   int lag=(period-1)/2;
   double pr=2.0/(period+1.0);
   double adj[]; ArrayResize(adj,rt);
   for(int i=0;i<rt;i++) adj[i]=(i>=lag)? 2.0*close[i]-close[i-lag] : close[i];
   for(int i=0;i<rt;i++) out[i]=(i==0)?adj[i]:adj[i]*pr+out[i-1]*(1.0-pr);
  }
void Calc_LSMA(double &out[], const double &close[], const int period, const int rt)
  {
   ArrayResize(out, rt);
   int n=MathMax(2, period);
   for(int i=0;i<rt;i++)
     {
      int m=(i+1<n)? i+1 : n;
      if(m<2){ out[i]=close[i]; continue; }
      double sx=0,sy=0,sxx=0,sxy=0;
      for(int k=0;k<m;k++){ double x=(double)k; double y=close[i-(m-1-k)]; sx+=x; sy+=y; sxx+=x*x; sxy+=x*y; }
      double den=m*sxx - sx*sx;
      if(den==0){ out[i]=close[i]; continue; }
      double a=(m*sxy - sx*sy)/den;
      double b=(sy - a*sx)/m;
      out[i]=a*(m-1)+b;   // 回帰直線の最新点の値
     }
  }
void Calc_VWAP(double &out[], const double &high[], const double &low[], const double &close[], const long &tvol[], const int period, const int rt)
  {
   // 直近period本のローリングVWAP。典型価格(H+L+C)/3 × 出来高(tick)で加重。
   ArrayResize(out, rt);
   for(int i=0;i<rt;i++)
     {
      int m=(i+1<period)? i+1 : period;
      double sp=0,sv=0;
      for(int k=0;k<m;k++){ double tp=(high[i-k]+low[i-k]+close[i-k])/3.0; double v=(double)tvol[i-k]; sp+=tp*v; sv+=v; }
      out[i]=(sv>0)? sp/sv : close[i];
     }
  }
void Calc_MAMA(double &out[], const double &close[], const double fastLimit, const double slowLimit, const int rt)
  {
   // John Ehlers の MESA Adaptive MA (close基準)。出力はMAMA線。
   ArrayResize(out, rt);
   double sm[],dt[],i1[],q1[],ji[],jq[],i2[],q2[],re[],im[],pd[],ph[],mama[];
   ArrayResize(sm,rt);ArrayResize(dt,rt);ArrayResize(i1,rt);ArrayResize(q1,rt);ArrayResize(ji,rt);
   ArrayResize(jq,rt);ArrayResize(i2,rt);ArrayResize(q2,rt);ArrayResize(re,rt);ArrayResize(im,rt);
   ArrayResize(pd,rt);ArrayResize(ph,rt);ArrayResize(mama,rt);
   ArrayInitialize(sm,0);ArrayInitialize(dt,0);ArrayInitialize(i1,0);ArrayInitialize(q1,0);ArrayInitialize(ji,0);
   ArrayInitialize(jq,0);ArrayInitialize(i2,0);ArrayInitialize(q2,0);ArrayInitialize(re,0);ArrayInitialize(im,0);
   ArrayInitialize(pd,0);ArrayInitialize(ph,0);ArrayInitialize(mama,0);
   double r2d=180.0/M_PI;
   for(int i=0;i<rt;i++)
     {
      if(i<6){ mama[i]=close[i]; pd[i]=0; ph[i]=0; continue; }
      double adj=0.075*pd[i-1]+0.54;
      sm[i]=(4.0*close[i]+3.0*close[i-1]+2.0*close[i-2]+close[i-3])/10.0;
      dt[i]=(0.0962*sm[i]+0.5769*sm[i-2]-0.5769*sm[i-4]-0.0962*sm[i-6])*adj;
      q1[i]=(0.0962*dt[i]+0.5769*dt[i-2]-0.5769*dt[i-4]-0.0962*dt[i-6])*adj;
      i1[i]=dt[i-3];
      ji[i]=(0.0962*i1[i]+0.5769*i1[i-2]-0.5769*i1[i-4]-0.0962*i1[i-6])*adj;
      jq[i]=(0.0962*q1[i]+0.5769*q1[i-2]-0.5769*q1[i-4]-0.0962*q1[i-6])*adj;
      double i2v=i1[i]-jq[i], q2v=q1[i]+ji[i];
      i2[i]=0.2*i2v+0.8*i2[i-1];
      q2[i]=0.2*q2v+0.8*q2[i-1];
      double rev=i2[i]*i2[i-1]+q2[i]*q2[i-1];
      double imv=i2[i]*q2[i-1]-q2[i]*i2[i-1];
      re[i]=0.2*rev+0.8*re[i-1];
      im[i]=0.2*imv+0.8*im[i-1];
      double period=pd[i-1];
      if(im[i]!=0.0 && re[i]!=0.0) period=360.0/(MathArctan(im[i]/re[i])*r2d);
      if(period>1.5*pd[i-1]) period=1.5*pd[i-1];
      if(period<0.67*pd[i-1]) period=0.67*pd[i-1];
      if(period<6.0)  period=6.0;
      if(period>50.0) period=50.0;
      pd[i]=0.2*period+0.8*pd[i-1];
      double phase=ph[i-1];
      if(i1[i]!=0.0) phase=MathArctan(q1[i]/i1[i])*r2d;
      ph[i]=phase;
      double dph=ph[i-1]-ph[i];
      if(dph<1.0) dph=1.0;
      double alpha=fastLimit/dph;
      if(alpha<slowLimit) alpha=slowLimit;
      if(alpha>fastLimit) alpha=fastLimit;
      mama[i]=alpha*close[i]+(1.0-alpha)*mama[i-1];
     }
   for(int i=0;i<rt;i++) out[i]=mama[i];
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, MaBuffer,    INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, AtrBuffer,   INDICATOR_CALCULATIONS);

   // ★本家と同じ非時系列(0=古)で計算する
   ArraySetAsSeries(MaBuffer,    false);
   ArraySetAsSeries(ColorBuffer, false);
   ArraySetAsSeries(AtrBuffer,   false);

   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, InpPeriod + InpSlopeBars);
   PlotIndexSetInteger(0, PLOT_SHIFT,      InpShift);
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu_MA");

   // 5色をプロットのカラーインデックス0..4へ反映(自由選択)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpColUp);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpColUpEdge);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, InpColGray);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 3, InpColDownEdge);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 4, InpColDown);

   // 自前計算型(iMA等に無い/独自式) … TMA/VWMA/ATR×2/HMA/DEMA/ZLEMA/MAMA/LSMA/VWAP
   g_selfCalc = (InpMaType==GZ_TMA  || InpMaType==GZ_VWMA      || InpMaType==GZ_ATR_ADAPT ||
                 InpMaType==GZ_ATR_TREND || InpMaType==GZ_HMA  || InpMaType==GZ_DEMA ||
                 InpMaType==GZ_ZLEMA || InpMaType==GZ_MAMA      || InpMaType==GZ_LSMA ||
                 InpMaType==GZ_VWAP);

   // 組込み/適応ハンドル(標準7種)。自前計算型では作らない。
   if(!g_selfCalc)
     {
      switch(InpMaType)
        {
         case GZ_SMA:   g_handle = iMA   (_Symbol,_Period,InpPeriod,0,MODE_SMA, InpPrice); break;
         case GZ_WMA:   g_handle = iMA   (_Symbol,_Period,InpPeriod,0,MODE_LWMA,InpPrice); break;
         case GZ_SMMA:  g_handle = iMA   (_Symbol,_Period,InpPeriod,0,MODE_SMMA,InpPrice); break;
         case GZ_EMA:   g_handle = iMA   (_Symbol,_Period,InpPeriod,0,MODE_EMA, InpPrice); break;
         case GZ_KAMA:  g_handle = iAMA  (_Symbol,_Period,InpPeriod,InpKamaFast,InpKamaSlow,0,InpPrice); break;
         case GZ_VIDYA: g_handle = iVIDyA(_Symbol,_Period,InpVidyaCmo,InpVidyaEma,0,InpPrice); break;
         case GZ_FRAMA: g_handle = iFrAMA(_Symbol,_Period,InpPeriod,0,InpPrice); break;
         default:       g_handle = INVALID_HANDLE; break;
        }
      if(g_handle == INVALID_HANDLE)
         return(INIT_FAILED);
     }

   // ATR Adaptive / ATR Trend 用のATR
   if(InpMaType==GZ_ATR_ADAPT || InpMaType==GZ_ATR_TREND)
     {
      g_atrHandle = iATR(_Symbol, _Period, InpAtrPeriod);
      if(g_atrHandle == INVALID_HANDLE)
         return(INIT_FAILED);
     }

   // 色の傾き正規化に使うATR(MA種別に関係なく常時作成)
   g_colAtr = iATR(_Symbol, _Period, InpAtrColPeriod);
   if(g_colAtr == INVALID_HANDLE)
      return(INIT_FAILED);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_handle    != INVALID_HANDLE) IndicatorRelease(g_handle);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_colAtr    != INVALID_HANDLE) IndicatorRelease(g_colAtr);
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
   const int rt = rates_total;
   if(rt < InpPeriod + InpSlopeBars + 8)
      return(0);

   // ★本家と同じ非時系列(0=古)
   ArraySetAsSeries(open,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(tick_volume, false);

   //--- 1) MaBuffer を埋める(種別ごと。本家ロジックを移植) -----------
   if(!g_selfCalc)
     {
      // 標準7種: 組込み/適応ハンドルからコピー(非時系列で0=古に揃う)
      if(CopyBuffer(g_handle, 0, 0, rt, MaBuffer) <= 0)
         return(prev_calculated);   // ハンドル未準備 → 次tickで再試行
     }
   else if(InpMaType==GZ_TMA)
     {
      // 三角移動平均 = SMAを2回かける
      int h=(InpPeriod+1)/2;
      double tmp[]; ArrayResize(tmp,rt);
      for(int i=0;i<rt;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=close[i-k];c++;} tmp[i]=(c>0)?s/c:close[i]; }
      for(int i=0;i<rt;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=tmp[i-k];c++;} MaBuffer[i]=(c>0)?s/c:close[i]; }
     }
   else if(InpMaType==GZ_VWMA)
     {
      // 出来高加重移動平均
      for(int i=0;i<rt;i++)
        {
         if(i<InpPeriod-1){ MaBuffer[i]=close[i]; continue; }
         double sp=0,sv=0;
         for(int k=0;k<InpPeriod;k++){ double v=(double)tick_volume[i-k]; sp+=close[i-k]*v; sv+=v; }
         MaBuffer[i]=(sv>0)?sp/sv:close[i];
        }
     }
   else if(InpMaType==GZ_ATR_ADAPT || InpMaType==GZ_ATR_TREND)
     {
      double atr[]; ArraySetAsSeries(atr,false);
      if(CopyBuffer(g_atrHandle,0,0,rt,atr) <= 0)
         return(prev_calculated);
      if(InpMaType==GZ_ATR_ADAPT)
        {
         // ATR Adaptive: ATRの「水準」(ATR/ATR平均)でαを変える適応EMA
         for(int i=0;i<rt;i++)
           {
            if(i<1){ MaBuffer[i]=close[i]; continue; }
            double am=0; int ac=0;
            for(int k=0;k<InpAtrRefPeriod && i-k>=0;k++){ am+=atr[i-k]; ac++; }
            am=(ac>0)?am/ac:atr[i];
            double ratio=(am>0)?atr[i]/am:1.0;
            double t=MathMin(2.0,MathMax(0.0,ratio))/2.0; // 0〜1
            double a;
            if(InpHighVolFaster) a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t; // 高ボラで速い
            else                 a=InpAtrFastA-(InpAtrFastA-InpAtrSlowA)*t; // 高ボラで遅い
            MaBuffer[i]=close[i]*a + MaBuffer[i-1]*(1.0-a);
           }
        }
      else // GZ_ATR_TREND
        {
         // ATR Trend: ATRの「傾き」(過去N本との変化率)でαを変える適応EMA
         for(int i=0;i<rt;i++)
           {
            if(i<1){ MaBuffer[i]=close[i]; continue; }
            int j=MathMax(0,i-InpAtrRefPeriod);
            double base=atr[j];
            double chg=(base>0)?(atr[i]-base)/base:0.0;
            double t=MathMin(1.0,MathMax(0.0,chg));
            double a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t; // 拡大で速い
            MaBuffer[i]=close[i]*a + MaBuffer[i-1]*(1.0-a);
           }
        }
     }
   else if(InpMaType==GZ_HMA)   Calc_HMA  (MaBuffer, close, InpPeriod, rt);
   else if(InpMaType==GZ_DEMA)  Calc_DEMA (MaBuffer, close, InpPeriod, rt);
   else if(InpMaType==GZ_ZLEMA) Calc_ZLEMA(MaBuffer, close, InpPeriod, rt);
   else if(InpMaType==GZ_MAMA)  Calc_MAMA (MaBuffer, close, InpMamaFast, InpMamaSlow, rt);
   else if(InpMaType==GZ_LSMA)  Calc_LSMA (MaBuffer, close, InpPeriod, rt);
   else if(InpMaType==GZ_VWAP)  Calc_VWAP (MaBuffer, high, low, close, tick_volume, InpPeriod, rt);

   //--- 2) 5段階カラー (傾きをATR正規化:色=広い/境目=薄い/グレー=ほぼ水平のみ) ---
   double colAtr[]; ArraySetAsSeries(colAtr,false);
   if(CopyBuffer(g_colAtr, 0, 0, rt, colAtr) <= 0)
      return(prev_calculated);

   double exitTh = InpGrayTh * InpStickyMult;  // グレーから出る(色がつく)のに必要な角度(高め)
   for(int i=0;i<rt;i++)
     {
      int ci = 2; // 既定=グレー(ほぼ水平)
      if(i - InpSlopeBars >= 0 && colAtr[i] > 0.0)
        {
         // ATRで正規化した傾き(=何ATR分動いたか)。期間/銘柄に依存しない。
         double sn = (MaBuffer[i] - MaBuffer[i - InpSlopeBars]) / colAtr[i];
         // 直前(1本古い)の色。ヒステリシス用。無ければグレーから開始。
         int prevCi = (i >= 1) ? (int)ColorBuffer[i - 1] : 2;

         if(prevCi == 2)
           {
            // 今グレー → 出る(色がつく)には exitTh 以上が必要 = 出にくい=居座る
            if(sn >=  exitTh)      ci = (sn >=  InpColorTh) ? 0 : 1;
            else if(sn <= -exitTh) ci = (sn <= -InpColorTh) ? 4 : 3;
            else                   ci = 2;
           }
         else
           {
            // 今は色つき → 通常しきい。水平(|傾き|<GrayTh)になって初めてグレーへ戻す
            double a = MathAbs(sn);
            if(a < InpGrayTh)          ci = 2;
            else if(sn >=  InpColorTh) ci = 0;
            else if(sn >   0.0)        ci = 1;
            else if(sn <= -InpColorTh) ci = 4;
            else                       ci = 3;
           }
        }
      ColorBuffer[i] = ci;
     }

   return(rates_total);
  }
//+------------------------------------------------------------------+
