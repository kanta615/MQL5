//+------------------------------------------------------------------+
//|                                       DokaKotsu_backend_1.mq5     |
//|   DokaKotsu_indicator_4 と同じ方向判定で背景色を塗るインジ。     |
//|   (旧 TrendBackground4MA_KAMA_V4 の後継・改名)                  |
//|                                                                  |
//|   作成日時 : 2026.06.11 (JST)  / バージョン: 6.00                 |
//|                                                                  |
//|   ── 方針(indicator_4 と完全一致) ──                            |
//|     ・MAの種類・順番を indicator_4 と同一(全17種)。              |
//|       SMA/WMA/SMMA/TMA/VWMA/KAMA/VIDYA/FRAMA/ATR ADAPTIVE/      |
//|       ATR TREND/EMA/HMA/DEMA/ZLEMA/MAMA/LSMA/VWAP (この順)。     |
//|     ・追加6種(HMA/DEMA/ZLEMA/MAMA/LSMA/VWAP)の計算式は           |
//|       indicator_4 と同じヘルパー関数(完全一致)。               |
//|     ・方向判定も同じ: slope=(MA[i]-MA[i-1])/ATR[i]、              |
//|       +しきい値→上昇 / −しきい値→下降 / 間→中立(グレー)。       |
//|     ・その判定結果を「背景色」で表示する。                       |
//|                                                                  |
//|   ※M5チャートに貼って使う前提(チャート足で計算)。               |
//|   ※VWAPは直近N本のローリング(典型価格×tick出来高)。            |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "6.00"
#property description "indicator_4と同一判定の背景色(MA17種・色変更可)"
#property indicator_chart_window
#property indicator_plots 0

//=== MAの種類(indicator_4 と同一・同順・全17種) =================
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
   WT_ATR_TREND,  // ATR Trend(ATR傾きでα可変)
   WT_EMA,        // EMA(指数平滑)
   WT_HMA,        // HMA(Hull)
   WT_DEMA,       // DEMA(Double EMA)
   WT_ZLEMA,      // ZLEMA(Zero Lag EMA)
   WT_MAMA,       // MAMA(MESA Adaptive)
   WT_LSMA,       // LSMA(Least Squares)
   WT_VWAP        // VWAP(直近N本ローリング)
};

//=== 入力: 方向判定MA(indicator_4と同じ既定値) ==================
input ENUM_WMATYPE InpWmaType    = WT_FRAMA;  // ★方向判定のMA(種類)
input int          InpWmaPeriod  = 20;        // 方向判定MAの期間
input int          InpAtrPeriod  = 14;        // 傾き正規化用ATRの期間
input double       InpWmaSlopeTh = 0.10;      // 点灯(上昇/下降)のslopeしきい値 ※上げるとグレー増
input int          InpColorConfirmBars = 1;   // 色がこの本数連続で初めて切替(1=indicator_4と同じ / 2以上で背景の単発を消す)
//--- ATR適応MA(WT_ATR_ADAPT / WT_ATR_TREND)用。indicator_4と同じ既定 ---
input double InpAtrFastA      = 0.6;   // ATR適応:速い時のα
input double InpAtrSlowA      = 0.05;  // ATR適応:遅い時のα
input int    InpAtrRefPeriod  = 50;    // ATR適応:参照期間
input bool   InpHighVolFaster = true;  // ATR Adaptive:高ボラで速くするか
//--- MAMA用。indicator_4と同じ既定 ---
input double InpMamaFast      = 0.5;   // MAMA:FastLimit
input double InpMamaSlow      = 0.05;  // MAMA:SlowLimit

//=== 入力: 背景色(自由に変更可) ================================
input bool   InpShowBG    = true;            // 背景色を表示する
input color  InpColorBull = clrKhaki;        // ★上昇の背景色
input color  InpColorRange= clrSilver;       // ★中立(グレー)の背景色
input color  InpColorBear = clrLightBlue;    // ★下降の背景色
input int    InpLookback  = 800;             // 背景を塗る本数(直近)

enum DirState { DIR_FLAT=0, DIR_UP=1, DIR_DOWN=-1 };

const string PREFIX_BG = "BG_";
const double BG_TOP = 10000000.0;
const double BG_BOT = 0.0;

int  hBase = -1;
int  hATR  = -1;
bool g_selfCalc = false;   // 自前計算型(ハンドルを使わない)か

//+------------------------------------------------------------------+
//| 追加MA(HMA/DEMA/ZLEMA/MAMA/LSMA/VWAP)の計算。配列は非時系列(0=古)|
//|   ※indicator_4 と完全に同じ式。                                |
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
   switch(InpWmaType)
   {
      case WT_SMA:   hBase=iMA  (_Symbol,_Period,InpWmaPeriod,0,MODE_SMA ,PRICE_CLOSE); break;
      case WT_WMA:   hBase=iMA  (_Symbol,_Period,InpWmaPeriod,0,MODE_LWMA,PRICE_CLOSE); break;
      case WT_SMMA:  hBase=iMA  (_Symbol,_Period,InpWmaPeriod,0,MODE_SMMA,PRICE_CLOSE); break;
      case WT_EMA:   hBase=iMA  (_Symbol,_Period,InpWmaPeriod,0,MODE_EMA ,PRICE_CLOSE); break;
      case WT_KAMA:  hBase=iAMA (_Symbol,_Period,InpWmaPeriod,2,30,0,PRICE_CLOSE); break;
      case WT_VIDYA: hBase=iVIDyA(_Symbol,_Period,9,12,0,PRICE_CLOSE); break;  // indicator_4と同じ cmo=9,ema=12
      case WT_FRAMA: hBase=iFrAMA(_Symbol,_Period,InpWmaPeriod,0,PRICE_CLOSE); break;
      default:       hBase=-1; g_selfCalc=true; break; // TMA/VWMA/ATR/HMA/DEMA/ZLEMA/MAMA/LSMA/VWAP
   }
   hATR = iATR(_Symbol,_Period,InpAtrPeriod);

   bool handleBad = (hATR==INVALID_HANDLE) || (!g_selfCalc && hBase==INVALID_HANDLE);
   if(handleBad){ Print("ハンドル作成に失敗しました。"); return(INIT_FAILED); }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void DeleteByPrefix(const string pre)
{
   int total=ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--)
   {
      string nm=ObjectName(0,i,-1,-1);
      if(StringFind(nm,pre)==0) ObjectDelete(0,nm);
   }
}
void OnDeinit(const int reason){ DeleteByPrefix(PREFIX_BG); ChartRedraw(0); }

//+------------------------------------------------------------------+
void DrawBG(const datetime t1,const datetime t2,const color c)
{
   string obj=PREFIX_BG+IntegerToString((int)t1);
   if(ObjectFind(0,obj)<0)
   {
      ObjectCreate(0,obj,OBJ_RECTANGLE,0,t1,BG_TOP,t2,BG_BOT);
      ObjectSetInteger(0,obj,OBJPROP_BACK,true);
      ObjectSetInteger(0,obj,OBJPROP_FILL,true);
      ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,obj,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,obj,OBJPROP_COLOR,c);
}

//+------------------------------------------------------------------+
//| 選択した種類のMA系列を wma[] に作る(indicator_4の計算式と一致)。|
//|   配列は非時系列(index0=古い)。                                 |
//+------------------------------------------------------------------+
bool BuildMA(double &wma[], const int rt,
             const double &high[], const double &low[], const double &close[],
             const long &tick_volume[], const double &atr[])
{
   ArrayResize(wma, rt);

   // --- ハンドルで出せる型(SMA/WMA/SMMA/EMA/KAMA/VIDYA/FRAMA) ---
   if(hBase>=0)
   {
      double buf[];
      if(CopyBuffer(hBase,0,0,rt,buf)<=0) return false;
      ArraySetAsSeries(buf,false);
      for(int i=0;i<rt;i++) wma[i]=buf[i];
      return true;
   }

   // --- 自前計算型 ---
   if(InpWmaType==WT_TMA)
   {
      int h=(InpWmaPeriod+1)/2;
      double tmp[]; ArrayResize(tmp,rt);
      for(int i=0;i<rt;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=close[i-k];c++;} tmp[i]=(c>0)?s/c:close[i]; }
      for(int i=0;i<rt;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=tmp[i-k];c++;} wma[i]=(c>0)?s/c:close[i]; }
      return true;
   }
   if(InpWmaType==WT_VWMA)
   {
      for(int i=0;i<rt;i++)
      {
         if(i<InpWmaPeriod-1){ wma[i]=close[i]; continue; }
         double sp=0,sv=0;
         for(int k=0;k<InpWmaPeriod;k++){ double v=(double)tick_volume[i-k]; sp+=close[i-k]*v; sv+=v; }
         wma[i]=(sv>0)?sp/sv:close[i];
      }
      return true;
   }
   if(InpWmaType==WT_ATR_ADAPT)
   {
      for(int i=0;i<rt;i++)
      {
         if(i<1){ wma[i]=close[i]; continue; }
         double am=0; int ac=0;
         for(int k=0;k<InpAtrRefPeriod && i-k>=0;k++){ am+=atr[i-k]; ac++; }
         am=(ac>0)?am/ac:atr[i];
         double ratio=(am>0)?atr[i]/am:1.0;
         double t=MathMin(2.0,MathMax(0.0,ratio))/2.0;
         double a;
         if(InpHighVolFaster) a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t;
         else                 a=InpAtrFastA-(InpAtrFastA-InpAtrSlowA)*t;
         wma[i]=close[i]*a + wma[i-1]*(1.0-a);
      }
      return true;
   }
   if(InpWmaType==WT_ATR_TREND)
   {
      for(int i=0;i<rt;i++)
      {
         if(i<1){ wma[i]=close[i]; continue; }
         int j=MathMax(0,i-InpAtrRefPeriod);
         double base=atr[j];
         double chg=(base>0)?(atr[i]-base)/base:0.0;
         double t=MathMin(1.0,MathMax(0.0,chg));
         double a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t;
         wma[i]=close[i]*a + wma[i-1]*(1.0-a);
      }
      return true;
   }
   // --- 追加6種(indicator_4と同じヘルパー) ---
   if(InpWmaType==WT_HMA)  { Calc_HMA  (wma, close, InpWmaPeriod, rt); return true; }
   if(InpWmaType==WT_DEMA) { Calc_DEMA (wma, close, InpWmaPeriod, rt); return true; }
   if(InpWmaType==WT_ZLEMA){ Calc_ZLEMA(wma, close, InpWmaPeriod, rt); return true; }
   if(InpWmaType==WT_MAMA) { Calc_MAMA (wma, close, InpMamaFast, InpMamaSlow, rt); return true; }
   if(InpWmaType==WT_LSMA) { Calc_LSMA (wma, close, InpWmaPeriod, rt); return true; }
   if(InpWmaType==WT_VWAP) { Calc_VWAP (wma, high, low, close, tick_volume, InpWmaPeriod, rt); return true; }

   return false;
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,const int prev_calculated,
                const datetime &time[],const double &open[],
                const double &high[],const double &low[],
                const double &close[],const long &tick_volume[],
                const long &volume[],const int &spread[])
{
   int need = MathMax(InpWmaPeriod, InpAtrRefPeriod) + 7;
   if(rates_total < need + 2) return(0);

   // indicator_4 と同じく非時系列(index0=古い)で扱う
   ArraySetAsSeries(time ,false);
   ArraySetAsSeries(open ,false);
   ArraySetAsSeries(high ,false);
   ArraySetAsSeries(low  ,false);
   ArraySetAsSeries(close,false);

   double atr[];
   if(CopyBuffer(hATR,0,0,rates_total,atr)<=0) return prev_calculated;
   ArraySetAsSeries(atr,false);

   double wma[];
   if(!BuildMA(wma, rates_total, high, low, close, tick_volume, atr)) return prev_calculated;

   int startIdx = MathMax(need+1, rates_total-InpLookback);

   int disp=DIR_FLAT, pend=DIR_FLAT, pendCnt=0;

   for(int i=startIdx; i<rates_total; i++)
   {
      double a = atr[i];
      double slope = (a>0.0) ? (wma[i]-wma[i-1])/a : 0.0;

      int raw = DIR_FLAT;
      if(slope >  InpWmaSlopeTh)      raw = DIR_UP;
      else if(slope < -InpWmaSlopeTh) raw = DIR_DOWN;

      int cb = MathMax(1, InpColorConfirmBars);
      if(raw==disp) { pend=disp; pendCnt=0; }
      else
      {
         if(raw==pend) pendCnt++; else { pend=raw; pendCnt=1; }
         if(pendCnt>=cb) { disp=raw; pendCnt=0; }
      }

      if(InpShowBG)
      {
         color c = (disp==DIR_UP)   ? InpColorBull :
                   (disp==DIR_DOWN) ? InpColorBear : InpColorRange;
         datetime tRight = (i+1<rates_total) ? time[i+1] : time[i]+PeriodSeconds(_Period);
         DrawBG(time[i], tRight, c);
      }
   }

   ChartRedraw(0);
   return(rates_total);
}
//+------------------------------------------------------------------+
