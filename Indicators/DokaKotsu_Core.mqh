//+------------------------------------------------------------------+
//|                              DokaKotsu_Core.mqh                   |
//|   ロジックの単一ソース（コア）。インジ/EA/各表示が #include して  |
//|   同一コードで判定・系列を得る（WYSIWYG保証）。                   |
//|                                                                  |
//|   ★この段階は「器（スケルトン）」です。                          |
//|     ・構造体（DKParams/DKState）と既定値は本物。                  |
//|     ・各計算/判定関数は空（次段で本体インジから1つずつ移植）。     |
//|     ・まだ誰も include しません（表示・取引に影響ゼロ）。         |
//|                                                                  |
//|   設計3層:                                                       |
//|     A層 MAエンジン（17種・Calc_*/MakeMA。MT4はここだけ#ifdef）    |
//|     B層 派生系列（方向/長期/15分/平均足/波/決済基準）            |
//|     C層 判定（DK_StepEntry/DK_StepExit。純粋・状態は構造体で持越）|
//+------------------------------------------------------------------+
#ifndef __DOKAKOTSU_CORE_MQH__
#define __DOKAKOTSU_CORE_MQH__

//==================================================================
//  ★公開バッファ凍結表（不変の契約）
//  EA / Wave_Sub / HeikinAshi が以下の番号・意味に依存する。
//  コアをいくら変更しても、この割当ては絶対に動かさない。
//------------------------------------------------------------------
//   7 = BUY     8 = SELL    9 = EXIT
//  12 = 理由コード
//  13 = 15分状態(1/0/-1)    14 = 平均足色(1/-1)    15 = 長期状態(1/0/-1)
//  16 = 平均足始値  17 = 高値  18 = 安値  19 = 終値（いずれも後平滑後）
//  20 = 波   21 = シグナル   22 = レジーム(1/0/-1)   23 = 上抜け   24 = 下抜け
//  25 = 5分背景方向 wmaDir(1=上/0=グレー/-1=下)  ※EAの段階決済(グレー/反転)用に公開
//==================================================================

//--- MA種（本体インジ ENUM_WMATYPE と同一順。最終的にこの定義へ一本化）
enum ENUM_WMATYPE
{
   WT_SMA, WT_WMA, WT_SMMA, WT_TMA, WT_VWMA, WT_KAMA, WT_VIDYA, WT_FRAMA,
   WT_ATR_ADAPT, WT_ATR_TREND, WT_EMA, WT_HMA, WT_DEMA, WT_ZLEMA, WT_MAMA,
   WT_LSMA, WT_VWAP
};

//--- 理由コード（参考。テキストは DK_ReasonText で）
//  1=BUY 2=SELL 10=グレー 11=M1スパイク無 12=圧縮 13=オーバーシュート
//  14=再入ロック 15=クールダウン 16=EMA未点灯 17=色確認待ち 18=平均足逆
//  19=M15ライブ不一致 20=保有中 21=出来高薄 22=長期不一致 23=M15確定逆
//  24=フラッシュ回避 25=長期が後発 26=Wave未反転
//  30=平均足反転決済 31=MA反転決済 32=MAグレー決済

//==================================================================
//  DKParams … ロジック入力を1つに集約（将来の正本＝EA入力）
//  値は本体インジ DokaKotsu_indicator_9 の現行“既定値”。
//==================================================================
struct DKParams
{
   // ─ ④ 5分MA（方向＝背景の基準）
   ENUM_WMATYPE WmaType;        int WmaPeriod;
   double WmaSlopeTh;           double WmaStickyMult;
   int    ColorConfirmBars;     bool ConfirmClosedBar;
   // ─ ① 長期足
   ENUM_WMATYPE LongType;       int LongPeriod;
   int    LongSlopeStep;        int LongSlopeSmooth;
   double LongGrayThresh;       double LongHystRatio;
   bool   UseLongFilter;        bool UseLongFirst;
   // ─ ② 15分足
   ENUM_WMATYPE M15Type;        int M15Period;
   double M15SlopeTh;           bool UseM15Filter;
   bool   M15ConfirmClosed;     int  M15EntryConfirm;
   // ─ ③ 平均足（作り）
   int HaPrePeriod;   ENUM_MA_METHOD HaPreMethod;
   int HaPostPeriod;  ENUM_MA_METHOD HaPostMethod;
   // ─ ⑤ 波
   ENUM_WMATYPE WaveMaType;     int WaveFast;
   int    WaveSlow;             int WaveSignal;
   bool   UseWaveTrigger;       double WaveNeutralBand;
   // ─ ⑥ 決済
   int    SmaPeriod;            int Sma2ndPeriod;
   bool   HaPriorityExit;       int ExitGrayConfirmBars;
   bool   ExitHybridC;          bool AlsoTakePullback;
   // ─ ⑦ エントリー制御
   int    CooldownBars;
   // ─ 任意フィルター（実験用に保持）
   bool   FilM1Spike;  bool FilSqueeze;  bool FilOvershoot;  bool RequireEmaColit;
   bool   UseVolFilter; int VolMaPeriod;  double VolMinRatio;
   double SpikeTh;     double M1SpikeTh;  int M1Bars;
   double BBMult;      double KCMult;     bool LightFromM1;
   ENUM_WMATYPE EmaType; int EmaPeriod;   // 旧・引き金線（保持）
   // ─ 共有MAパラメータ（全MA種用）
   double AtrFastA;   double AtrSlowA;   int AtrRefPeriod;  bool HighVolFaster;
   double MamaFast;   double MamaSlow;
};

//--- 既定値で DKParams を埋める（入力既定の単一ソース）
DKParams DK_DefaultParams()
{
   DKParams p;
   p.WmaType=WT_WMA;            p.WmaPeriod=34;
   p.WmaSlopeTh=0.10;           p.WmaStickyMult=0.3;
   p.ColorConfirmBars=1;        p.ConfirmClosedBar=true;
   p.LongType=WT_KAMA;          p.LongPeriod=380;
   p.LongSlopeStep=5;           p.LongSlopeSmooth=4;
   p.LongGrayThresh=0.05;       p.LongHystRatio=1.5;
   p.UseLongFilter=true;        p.UseLongFirst=true;
   p.M15Type=WT_KAMA;           p.M15Period=15;
   p.M15SlopeTh=0.05;           p.UseM15Filter=true;
   p.M15ConfirmClosed=false;    p.M15EntryConfirm=2;
   p.HaPrePeriod=4;             p.HaPreMethod=MODE_SMMA;   // 2026-06-28 既定3→4
   p.HaPostPeriod=5;            p.HaPostMethod=MODE_SMMA;
   p.WaveMaType=WT_KAMA;        p.WaveFast=14;
   p.WaveSlow=34;               p.WaveSignal=10;
   p.UseWaveTrigger=true;       p.WaveNeutralBand=0.03;
   p.SmaPeriod=10;              p.Sma2ndPeriod=1;   // ★実運用既定は1（=二重平滑なし）
   p.HaPriorityExit=true;       p.ExitGrayConfirmBars=2;
   p.ExitHybridC=true;          p.AlsoTakePullback=false;
   p.CooldownBars=5;
   p.FilM1Spike=false; p.FilSqueeze=false; p.FilOvershoot=false; p.RequireEmaColit=false;
   p.UseVolFilter=false; p.VolMaPeriod=20; p.VolMinRatio=0.5;
   p.SpikeTh=2.0; p.M1SpikeTh=2.0; p.M1Bars=30000;
   p.BBMult=2.0; p.KCMult=1.5; p.LightFromM1=true;
   p.EmaType=WT_KAMA; p.EmaPeriod=10;
   p.AtrFastA=0.6; p.AtrSlowA=0.05; p.AtrRefPeriod=50; p.HighVolFaster=true;
   p.MamaFast=0.5; p.MamaSlow=0.05;
   return p;
}

//==================================================================
//  DKState … 足をまたいで持ち越す状態（呼び手が保持）
//  本体インジ＝ループ先頭でReset→各足Step。EA＝形成足で保持。
//==================================================================
struct DKState
{
   int  pos;            // 0=無 / 1=買 / -1=売（判定上のポジ）
   bool justExited;     // 同足ドテン防止
   int  cdLeft;         // 残りクールダウン本数
   bool segHadEntry;    // 現トレンドで既にエントリー済み
   int  trendDir;       // 現セグメントの方向
   // 連続点灯本数（長期が先頭か判定用）
   int  colorRun;       // 5分MA(方向)
   int  longRun, m15Run, haRun;
   int  grayRun;        // 決済のMAグレー継続
   // 1本前の各方向（連続/フリップ判定）
   int  prevDirRun;     // 1本前wmaDir（色連続）
   int  prevWmaDir;     // 1本前wmaDir（生・フリップ判定）
   int  prevLongD, prevM15L, prevHaD;
};

//--- 状態を初期化（ループ先頭/起動時に呼ぶ）
void DK_ResetState(DKState &s)
{
   s.pos=0; s.justExited=false; s.cdLeft=0; s.segHadEntry=false; s.trendDir=0;
   s.colorRun=0; s.longRun=0; s.m15Run=0; s.haRun=0; s.grayRun=0;
   s.prevDirRun=0; s.prevWmaDir=0; s.prevLongD=0; s.prevM15L=0; s.prevHaD=0;
}

//==================================================================
//  A層：MAエンジン（★次段で本体インジから移植。今は空宣言）
//  ・MT5は組込みハンドル/配列計算。MT4対応はこの層のみ #ifdef。
//==================================================================
//--- A層実体（本体インジから移管。挙動不変。ATR適応のみ引数化）
double MAValue(const double &src[], int pos, int period, ENUM_MA_METHOD method, int total)
{
   if(period <= 1)      return src[pos];
   if(pos < period-1)   return src[pos];
   double res = src[pos];
   switch(method)
   {
      case MODE_SMA:
      {
         double sum=0; for(int k=0;k<period;k++) sum+=src[pos-k];
         res = sum/period; break;
      }
      case MODE_EMA:
      {
         double pr=2.0/(period+1.0); int st=MathMax(0,pos-period*3);
         double e=src[st]; for(int k=st+1;k<=pos;k++) e=src[k]*pr+e*(1.0-pr);
         res=e; break;
      }
      case MODE_SMMA:
      {
         int st=MathMax(0,pos-period*3); double sm=src[st];
         for(int k=st+1;k<=pos;k++) sm=(sm*(period-1)+src[k])/period;
         res=sm; break;
      }
      case MODE_LWMA:
      {
         double sum=0,ws=0; for(int k=0;k<period;k++){int w=period-k; sum+=src[pos-k]*w; ws+=w;}
         res=(ws>0)?sum/ws:src[pos]; break;
      }
      default: res=src[pos];
   }
   return res;
}

//+------------------------------------------------------------------+
int MakeMA(ENUM_WMATYPE t, int period, ENUM_TIMEFRAMES tf)
{
   switch(t)
   {
      case WT_SMA:   return iMA   (_Symbol, tf, period, 0, MODE_SMA,  PRICE_CLOSE);
      case WT_WMA:   return iMA   (_Symbol, tf, period, 0, MODE_LWMA, PRICE_CLOSE);
      case WT_SMMA:  return iMA   (_Symbol, tf, period, 0, MODE_SMMA, PRICE_CLOSE);
      case WT_KAMA:  return iAMA  (_Symbol, tf, period, 2, 30, 0, PRICE_CLOSE);
      case WT_VIDYA: return iVIDyA(_Symbol, tf, period, 12, 0, PRICE_CLOSE);
      case WT_FRAMA: return iFrAMA(_Symbol, tf, period, 0, PRICE_CLOSE);
      case WT_EMA:   return iMA   (_Symbol, tf, period, 0, MODE_EMA,  PRICE_CLOSE);
      default:       return iMA   (_Symbol, tf, period, 0, MODE_EMA,  PRICE_CLOSE); // TMA/VWMA/ATR系は当面EMA代替
   }
}

//+------------------------------------------------------------------+
//| 追加MA(HMA/DEMA/ZLEMA/MAMA/LSMA/VWAP)の計算。配列は非時系列(0=古)|
//|   ※追加6種の計算式(backend_1と完全一致)。     |
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
//=== 波用：本体に無い4種を追加（Wave_Subと同一式） ===
void Calc_TMA(double &out[], const double &close[], const int period, const int rt)
{
   ArrayResize(out, rt);
   int h=(period+1)/2;
   double tmp[]; ArrayResize(tmp,rt);
   for(int i=0;i<rt;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=close[i-k];c++;} tmp[i]=(c>0)?s/c:close[i]; }
   for(int i=0;i<rt;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=tmp[i-k];c++;} out[i]=(c>0)?s/c:close[i]; }
}
void Calc_VWMA(double &out[], const double &close[], const long &tvol[], const int period, const int rt)
{
   ArrayResize(out, rt);
   for(int i=0;i<rt;i++)
   {
      if(i<period-1){ out[i]=close[i]; continue; }
      double sp=0,sv=0;
      for(int k=0;k<period;k++){ double v=(double)tvol[i-k]; sp+=close[i-k]*v; sv+=v; }
      out[i]=(sv>0)?sp/sv:close[i];
   }
}
void Calc_ATRADAPT(double &out[], const double &close[], const double &atr[], const int refPeriod, const double fastA, const double slowA, const bool highVolFaster, const int rt)
{
   ArrayResize(out, rt);
   for(int i=0;i<rt;i++)
   {
      if(i<1){ out[i]=close[i]; continue; }
      double am=0; int ac=0;
      for(int k=0;k<refPeriod && i-k>=0;k++){ am+=atr[i-k]; ac++; }
      am=(ac>0)?am/ac:atr[i];
      double ratio=(am>0)?atr[i]/am:1.0;
      double t=MathMin(2.0,MathMax(0.0,ratio))/2.0;
      double a;
      if(highVolFaster) a=slowA+(fastA-slowA)*t;
      else                 a=fastA-(fastA-slowA)*t;
      out[i]=close[i]*a + out[i-1]*(1.0-a);
   }
}
void Calc_ATRTREND(double &out[], const double &close[], const double &atr[], const int refPeriod, const double fastA, const double slowA, const int rt)
{
   ArrayResize(out, rt);
   for(int i=0;i<rt;i++)
   {
      if(i<1){ out[i]=close[i]; continue; }
      int j=MathMax(0,i-refPeriod);
      double base=atr[j];
      double chg=(base>0)?(atr[i]-base)/base:0.0;
      double t=MathMin(1.0,MathMax(0.0,chg));
      double a=slowA+(fastA-slowA)*t;
      out[i]=close[i]*a + out[i-1]*(1.0-a);
   }
}
int MakeWaveHandle(const ENUM_WMATYPE t,const int period)
{
   switch(t)
   {
      case WT_SMA:   return iMA   (_Symbol,_Period,period,0,MODE_SMA,  PRICE_CLOSE);
      case WT_WMA:   return iMA   (_Symbol,_Period,period,0,MODE_LWMA, PRICE_CLOSE);
      case WT_SMMA:  return iMA   (_Symbol,_Period,period,0,MODE_SMMA, PRICE_CLOSE);
      case WT_EMA:   return iMA   (_Symbol,_Period,period,0,MODE_EMA,  PRICE_CLOSE);
      case WT_KAMA:  return iAMA  (_Symbol,_Period,period,2,30,0,PRICE_CLOSE);
      case WT_VIDYA: return iVIDyA(_Symbol,_Period,9,12,0,PRICE_CLOSE);
      case WT_FRAMA: return iFrAMA(_Symbol,_Period,period,0,PRICE_CLOSE);
      default:       return INVALID_HANDLE;
   }
}
//--- A層ここまで

//==================================================================
//  B層：派生系列（★次段で移植。buf13-24/16-19 の元データ）
//==================================================================
// void DK_CalcDirMA     (const DKParams &p, ...);   // 方向MA + slope
// void DK_CalcRegime    (const DKParams &p, ...);   // wmaDir(buf22/背景)
// void DK_CalcLong      (const DKParams &p, ...);   // longDir(buf15)
// void DK_CalcM15       (const DKParams &p, ...);   // m15dir(buf13)
// void DK_CalcHeikinAshi(const DKParams &p, ...);   // HA OHLC/色(buf16-19/14)
// void DK_CalcWave      (const DKParams &p, ...);   // 波/シグナル/クロス(buf20/21/23/24)
// void DK_CalcExitBase  (const DKParams &p, ...);   // 決済基準線 sma2

//==================================================================
//  C層：判定（★次段で移植。純粋・状態は DKState で持越し）
//==================================================================
// int  DK_StepEntry(DKState &s, /*vals*/ const DKParams &p);  // →BUY/SELL/理由
// int  DK_StepExit (DKState &s, /*vals*/ const DKParams &p);  // →EXIT/理由(30/31/32)

//--- 理由コード→日本語（EA/監視で共用）。25/26を含む
string DK_ReasonText(const int code)
{
   switch(code)
   {
      case 1:  return "BUY発生";
      case 2:  return "SELL発生";
      case 10: return "グレーゾーン(待機)";
      case 14: return "再入ロック";
      case 15: return "クールダウン";
      case 17: return "色の確認待ち";
      case 18: return "平均足が逆色";
      case 19: return "M15ライブ不一致";
      case 20: return "保有中";
      case 21: return "出来高薄";
      case 22: return "長期足不一致";
      case 23: return "M15確定が逆";
      case 24: return "フラッシュ回避";
      case 25: return "長期が後発(最後に点灯)";   // ★新
      case 26: return "ウェーブ中立";
      case 27: return "ウェーブ上昇クロス";
      case 28: return "ウェーブ下降クロス";
      case 30: return "平均足反転で決済";
      case 31: return "MA反転で決済";
      case 32: return "MAグレーで決済";
   }
   return "";
}

#endif // __DOKAKOTSU_CORE_MQH__
//+------------------------------------------------------------------+
