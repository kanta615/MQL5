//+------------------------------------------------------------------+
//|                              DokaKotsu_indicator_4.mq5            |
//|                                                                  |
//|  ■■ 最重要・絶対ルール(EAと共通) ■■                            |
//|    売買ロジックは すべてこのインジ側 に持たせる。               |
//|    EA(DokaKotsu_EA)はロジックを一切持たず、ここが出す           |
//|    シグナル(BUY=buf7 / SELL=buf8 / EXIT=buf9)を実行するだけ。  |
//|    EAが持つのは固定概念・リスク管理のみ(時間/ロット/SL/建値)。 |
//|    → 両方にロジックを置かない。長期使用でぶつかり、バグが       |
//|       消えなくなるため厳禁。変更時は必ずこの分担を守ること。    |
//|                                                                  |
//|  ■ Ver3 = 基本版(まず素直に動かす)                              |
//|    エントリー: KAMA10 の色だけで判断。                           |
//|      ・グレー(平行)= レンジ → 取引しない(徹底)                |
//|      ・緑(上昇点灯) → BUY / オレンジ(下降点灯) → SELL          |
//|    決済: 平均足(SmoothedHA)が逆色に転換、またはベースMAが逆転。  |
//|    任意フィルター(M1スパイク/圧縮/オーバーシュート/EMA同時点灯)  |
//|    は 基本版では全てOFF。慣れたら1つずつONで検証する。           |
//|    (表示のみ・発注はEAが行う)                                   |
//|                                                                  |
//|  ベースMA(InpWmaType): 既定 FRAMA(期間20)。傾き(slope)が          |
//|    +しきい値→上(緑)/ -しきい値→下(オレンジ)/ 間→平行(グレー)。   |
//|    グレーの間はエントリー禁止(=レンジは触らない)。              |
//|                                                                  |
//|  任意フィルター(基本版OFF):                                     |
//|    ①InpFilM1Spike     : M1スパイク点灯を要求                    |
//|    ②InpFilSqueeze     : 圧縮(スクイーズ)中は弾く               |
//|    ③InpFilOvershoot   : オーバーシュート(急変)を弾く           |
//|    ⑤InpRequireEmaColit: 方向MAとEMA点灯の同時点灯を要求          |
//|                                                                  |
//|  ※M5チャートに入れて使う前提(_Period=M5想定)。                |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "4.00"

//=== バージョン情報(最新版か確認用) ==============================
#define DK_VERSION   "V4.0"
#define DK_BUILD     "2026-06-11 MA17種対応/引き金線も全対応/EMA修正(indicator_4)"
#property indicator_chart_window
#property indicator_buffers 12
#property indicator_plots   10

//--- EMA10 非点灯(グレー)
#property indicator_label1  "EMA10_NORM"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGray
#property indicator_width1  2
//--- EMA10 点灯(マゼンタ)
#property indicator_label2  "EMA10_SPIKE"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrAqua
#property indicator_width2  3
//--- 方向MA 上昇(緑)
#property indicator_label3  "MA_UP"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLime
#property indicator_width3  5
//--- 方向MA 下降(オレンジ)
#property indicator_label4  "MA_DOWN"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrange
#property indicator_width4  5
//--- 方向MA 平行(灰=グレーゾーン)
#property indicator_label5  "MA_FLAT"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrDimGray
#property indicator_width5  5
//--- SMA20 センターライン(5段階カラー)
#property indicator_label6  "SMA20_CENTER"
#property indicator_type6   DRAW_COLOR_LINE
#property indicator_color6  clrLightGray,clrLightSkyBlue,clrGray,clrPlum,clrMagenta
#property indicator_width6  1
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
   WT_ATR_TREND,  // ATR Trend(ATR傾きでα可変)
   WT_EMA,        // EMA(指数平滑)
   WT_HMA,        // HMA(Hull)
   WT_DEMA,       // DEMA(Double EMA)
   WT_ZLEMA,      // ZLEMA(Zero Lag EMA)
   WT_MAMA,       // MAMA(MESA Adaptive)
   WT_LSMA,       // LSMA(Least Squares)
   WT_VWAP        // VWAP(直近N本ローリング)
};
input string InpVersionInfo = "V4.0 / 2026-06-11 引き金線も全MA対応・EMA修正"; // ★バージョン(最新確認用・変更不要)
input ENUM_WMATYPE InpWmaType   = WT_FRAMA; // ★方向判定のMA(種類)
input int          InpWmaPeriod = 20; // 方向判定のMAの期間
//--- 追加フィルター(初期は全部OFF=ベースMAだけでシグナル。1つずつONで検証) ---
input bool   InpFilM1Spike     = false;// ①M1スパイク要求(だまし対策・タイミング)※基本版はOFF
input bool   InpFilSqueeze     = false;// ②圧縮中は弾く(スクイーズのダマシ対策)
input bool   InpFilOvershoot   = false;// ③オーバーシュートを弾く(急変飛び乗り対策)
input bool   InpRequireEmaColit = false;// ④方向MAとEMA同時点灯
input bool   InpAlsoTakePullback = true; // ⑤調整波も狙う(OFF=平均足と方向一致時だけ入る=調整波回避)
input double InpAtrFastA      = 0.6;  // ATR適応:速い時のα(0〜1・大きいほど速い)
input double InpAtrSlowA      = 0.05; // ATR適応:遅い時のα(0〜1・小さいほど滑らか)
input int    InpAtrRefPeriod  = 50;   // ATR適応:ATR平均/変化率の参照期間
input bool   InpHighVolFaster = true; // ATR Adaptive:高ボラで速くするか(既定false=高ボラで遅く)
input double InpMamaFast      = 0.5;  // MAMA:FastLimit(速さ上限)
input double InpMamaSlow      = 0.05; // MAMA:SlowLimit(速さ下限)
input int    InpCooldownBars  = 5;    // ★決済後この本数は新規エントリーを出さない(調整波回避・EAから移管)
input ENUM_WMATYPE InpEmaType   = WT_KAMA; // ★引き金/スパイク線のMA(種類)。選択肢は方向判定MAと同じ
input int    InpEmaPeriod    = 10;    // 引き金/スパイク線のMAの期間
input int    InpSmaPeriod    = 10;    // SMA期間(決済の基準線=SMA10)
input int    InpSma2ndPeriod = 1;     // ★二重平滑の期間(1=平滑なし → 素のSMA10)

//--- 決済用 平均足(Smoothed Heikin Ashi)。決済は平均足が逆色に転換した時。
input int            InpHaPrePeriod  = 3;        // 決済用平均足:前平滑化の期間(1=なし)
input ENUM_MA_METHOD InpHaPreMethod  = MODE_SMMA;// 決済用平均足:前平滑化の方式(Smoothed)
input int            InpHaPostPeriod = 1;        // 決済用平均足:後平滑化の期間(1=なし)
input ENUM_MA_METHOD InpHaPostMethod = MODE_SMA; // 決済用平均足:後平滑化の方式(Simple)
input bool   InpHaPriorityExit = true; // ⑥方向MAより平均足優先(ON=平均足の色反転まで耐える / OFF=FRAMA転換でも決済)
input double InpSpikeTh       = 2.0;  // M5でEMA10が点灯(マゼンタ)する収束度
input double InpWmaSlopeTh    = 0.10; // WMA点灯(緑/オレンジ)のslopeしきい値 ※守備つまみ①(上げるとグレー増)
input int    InpColorConfirmBars = 1; // ★色がこの本数“連続”して初めてエントリー許可 ※守備つまみ②(1=確認なし。2,3..でレンジの単発を消す)
input double InpM1SpikeTh      = 2.0; // ⑥M1スパイクの収束本数
input int    InpM1Bars         = 30000;// 取得するM1本数(フィルター①ON時)
input double InpBBMult          = 2.0; // スクイーズ判定用 ボリンジャー偏差(フィルター②ON時)
input double InpKCMult          = 1.5; // ⑦圧縮ケルトナー幅
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
double BufReason[];      // ★エントリー理由コード(描画なし・EAがCopyBuffer(11)で読む)
                         //   1=BUY発生 2=SELL発生 10=グレー 11=M1無し 12=圧縮
                         //   13=オーバーシュート 14=再エントリーロック 20=保有中 30=EXIT

//=== アラート重複防止 ============================================
datetime g_lastAlertTime = 0;

int hEMA, hSMA, hWMA, hATR;          // M5(チャート足)
int hKAMA=-1, hVIDYA=-1, hFRAMA=-1;  // 適応型MA(標準関数)
int hEMA1, hSMA1, hATR1;             // M1



//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 指定した種類・期間のMAハンドルを返す(引き金/スパイク線用)       |
//|   標準関数で出せる型(EMA/SMA/WMA/SMMA/KAMA/VIDYA/FRAMA)に対応。   |
//|   TMA/VWMA/ATR系を選んだ時は当面EMAで代替(必要なら後日対応)。    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 1本の移動平均値(配列srcのpos位置・period本・方式)。平均足平滑用。 |
//|   配列は時系列昇順(0=古い)。period<=1 で平滑なし。               |
//+------------------------------------------------------------------+
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
//|   ※indicator_4 と DokaKotsu_backend_1 で完全に同じ式を使う。     |
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
   SetIndexBuffer(11, BufReason,  INDICATOR_CALCULATIONS); // ★描画しない・EA読み取り専用

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
   hEMA = MakeMA(InpEmaType, InpEmaPeriod, _Period);   // 引き金/スパイク線(種類選択)
   hSMA = iMA(_Symbol, _Period, InpSmaPeriod, 0, MODE_SMA,  PRICE_CLOSE);
   // WMA(方向判定線)は種類選択。SMA/WMA/SMMAはiMA、TMA/VWMAは自前計算。
   ENUM_MA_METHOD wmode = MODE_LWMA;
   if(InpWmaType==WT_SMA)       wmode = MODE_SMA;
   else if(InpWmaType==WT_WMA)  wmode = MODE_LWMA;
   else if(InpWmaType==WT_SMMA) wmode = MODE_SMMA;
   else if(InpWmaType==WT_EMA)  wmode = MODE_EMA;  // ★修正: 従来は下のelseでSMAになっていた
   else                         wmode = MODE_SMA;  // TMA/VWMA/KAMA/VIDYA/FRAMA/ATRは仮(後で上書き計算)
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
   hEMA1 = MakeMA(InpEmaType, InpEmaPeriod, PERIOD_M1); // M1引き金線(種類選択)
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
      StringFormat("DokaKotsu indicator_4 [%s %s]", DK_VERSION, DK_BUILD));

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
      StringFormat("DokaKotsu indicator_4  %s  (build %s)", DK_VERSION, DK_BUILD));
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

   // ── 決済用 平均足(Smoothed Heikin Ashi)の色を前計算 ──
   //   haColor[i]: 0=陽線(上昇) / 1=陰線(下降)。決済はこの色の転換で行う。
   double prO[],prH[],prL[],prC[],hO[],hH[],hL[],hC[];
   ArrayResize(prO,rates_total); ArrayResize(prH,rates_total);
   ArrayResize(prL,rates_total); ArrayResize(prC,rates_total);
   ArrayResize(hO,rates_total);  ArrayResize(hH,rates_total);
   ArrayResize(hL,rates_total);  ArrayResize(hC,rates_total);
   int haColor[]; ArrayResize(haColor, rates_total);
   for(int i=0;i<rates_total;i++)   // ①前平滑化
   {
      prO[i]=MAValue(open ,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
      prH[i]=MAValue(high ,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
      prL[i]=MAValue(low  ,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
      prC[i]=MAValue(close,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
   }
   for(int i=0;i<rates_total;i++)   // ②平均足の生値
   {
      double hac=(prO[i]+prH[i]+prL[i]+prC[i])/4.0;
      double hao=(i==0)?(prO[i]+prC[i])/2.0:(hO[i-1]+hC[i-1])/2.0;
      hO[i]=hao; hC[i]=hac;
      hH[i]=MathMax(prH[i],MathMax(hao,hac));
      hL[i]=MathMin(prL[i],MathMin(hao,hac));
   }
   for(int i=0;i<rates_total;i++)   // ③後平滑化 → 色
   {
      double o=MAValue(hO,i,InpHaPostPeriod,InpHaPostMethod,rates_total);
      double c=MAValue(hC,i,InpHaPostPeriod,InpHaPostMethod,rates_total);
      haColor[i]=(c>=o)?0:1;
   }

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
   else if(InpWmaType==WT_HMA)   Calc_HMA  (wma, close, InpWmaPeriod, rates_total);
   else if(InpWmaType==WT_DEMA)  Calc_DEMA (wma, close, InpWmaPeriod, rates_total);
   else if(InpWmaType==WT_ZLEMA) Calc_ZLEMA(wma, close, InpWmaPeriod, rates_total);
   else if(InpWmaType==WT_MAMA)  Calc_MAMA (wma, close, InpMamaFast, InpMamaSlow, rates_total);
   else if(InpWmaType==WT_LSMA)  Calc_LSMA (wma, close, InpWmaPeriod, rates_total);
   else if(InpWmaType==WT_VWAP)  Calc_VWAP (wma, high, low, close, tick_volume, InpWmaPeriod, rates_total);

   // ── 引き金/スパイク線(ema[])も TMA/VWMA/ATR系に対応(indicator_4で追加) ──
   //   SMA/WMA/SMMA/EMA/KAMA/VIDYA/FRAMA は MakeMA のハンドルで対応済み。
   //   ここでは iMA に無い4種だけ、wma[]と同じ式で ema[] を上書きする。
   //   ※M5(チャート足)の引き金線のみ。M1引き金(応用フィルター)はハンドルのまま。
   if(InpEmaType==WT_TMA)
   {
      int h=(InpEmaPeriod+1)/2;
      double tmp[]; ArrayResize(tmp,rates_total);
      for(int i=0;i<rates_total;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=close[i-k];c++;} tmp[i]=(c>0)?s/c:close[i]; }
      for(int i=0;i<rates_total;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=tmp[i-k];c++;} ema[i]=(c>0)?s/c:close[i]; }
   }
   else if(InpEmaType==WT_VWMA)
   {
      for(int i=0;i<rates_total;i++)
      {
         if(i<InpEmaPeriod-1){ ema[i]=close[i]; continue; }
         double sp=0,sv=0;
         for(int k=0;k<InpEmaPeriod;k++){ double v=(double)tick_volume[i-k]; sp+=close[i-k]*v; sv+=v; }
         ema[i]=(sv>0)?sp/sv:close[i];
      }
   }
   else if(InpEmaType==WT_ATR_ADAPT)
   {
      for(int i=0;i<rates_total;i++)
      {
         if(i<1){ ema[i]=close[i]; continue; }
         double am=0; int ac=0;
         for(int k=0;k<InpAtrRefPeriod && i-k>=0;k++){ am+=atr[i-k]; ac++; }
         am=(ac>0)?am/ac:atr[i];
         double ratio=(am>0)?atr[i]/am:1.0;
         double t=MathMin(2.0,MathMax(0.0,ratio))/2.0;
         double a;
         if(InpHighVolFaster) a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t;
         else                 a=InpAtrFastA-(InpAtrFastA-InpAtrSlowA)*t;
         ema[i]=close[i]*a + ema[i-1]*(1.0-a);
      }
   }
   else if(InpEmaType==WT_ATR_TREND)
   {
      for(int i=0;i<rates_total;i++)
      {
         if(i<1){ ema[i]=close[i]; continue; }
         int j=MathMax(0,i-InpAtrRefPeriod);
         double base=atr[j];
         double chg=(base>0)?(atr[i]-base)/base:0.0;
         double t=MathMin(1.0,MathMax(0.0,chg));
         double a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t;
         ema[i]=close[i]*a + ema[i-1]*(1.0-a);
      }
   }
   else if(InpEmaType==WT_HMA)   Calc_HMA  (ema, close, InpEmaPeriod, rates_total);
   else if(InpEmaType==WT_DEMA)  Calc_DEMA (ema, close, InpEmaPeriod, rates_total);
   else if(InpEmaType==WT_ZLEMA) Calc_ZLEMA(ema, close, InpEmaPeriod, rates_total);
   else if(InpEmaType==WT_MAMA)  Calc_MAMA (ema, close, InpMamaFast, InpMamaSlow, rates_total);
   else if(InpEmaType==WT_LSMA)  Calc_LSMA (ema, close, InpEmaPeriod, rates_total);
   else if(InpEmaType==WT_VWAP)  Calc_VWAP (ema, high, low, close, tick_volume, InpEmaPeriod, rates_total);

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
   int  cdLeft     = 0;   // 残りクールダウン本数(決済後 InpCooldownBars 本)
   int  colorRun   = 0;   // 同方向の色が連続している本数(0=グレー)。持続確認用
   int  prevDirRun = 0;   // 1本前のwmaDir(連続判定用)

   // ウォームアップ区間を空に
   for(int j=0; j<need && j<rates_total; j++)
   {
      BufEmaNorm[j]=EMPTY_VALUE; BufEmaSpike[j]=EMPTY_VALUE;
      BufWmaUp[j]=EMPTY_VALUE;   BufWmaDown[j]=EMPTY_VALUE; BufWmaFlat[j]=EMPTY_VALUE;
      BufSma20[j]=EMPTY_VALUE; BufSma20Col[j]=2;
      BufBuy[j]=0.0; BufSell[j]=0.0; BufExit[j]=0.0; BufOvershoot[j]=0.0;
      BufReason[j]=0.0;
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
      BufReason[i]=0.0;
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
      // 色の連続本数(同方向が何本続いたか)。グレーで0にリセット。
      if(wmaDir==0)                 colorRun = 0;
      else if(wmaDir==prevDirRun)   colorRun++;
      else                          colorRun = 1;
      prevDirRun = wmaDir;
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
      //   決済1: 平均足(SmoothedHA)が保有と逆の色に転換した
      //   決済2: ベースMAの色が保有と逆方向に転換した(トレンド終了の手仕舞い)
      bool justExited = false;   // この足で決済したか(同足ドテン防止)
      if(pos==1)
      {
         bool exitCross = (haColor[i] == 1);      // 平均足が陰線(下降)に転換
         bool exitTrend = (!InpHaPriorityExit) && (wmaDir == -1); // 平均足優先OFF時のみFRAMA下降で決済
         if(exitCross || exitTrend)
         {
            BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=30.0; cdLeft=InpCooldownBars;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
            { Alert(_Symbol," 終了(ロング)"); g_lastAlertTime=time[i]; }
         }
      }
      else if(pos==-1)
      {
         bool exitCross = (haColor[i] == 0);      // 平均足が陽線(上昇)に転換
         bool exitTrend = (!InpHaPriorityExit) && (wmaDir == 1);  // 平均足優先OFF時のみFRAMA上昇で決済
         if(exitCross || exitTrend)
         {
            BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=30.0; cdLeft=InpCooldownBars;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
            { Alert(_Symbol," 終了(ショート)"); g_lastAlertTime=time[i]; }
         }
      }

      // 決済が出ず保有継続中なら「保有中(新規対象外)」=20
      if(pos!=0) BufReason[i]=20.0;

      // クールダウン消化(ノーポジの足ごとに1本)
      if(pos==0 && !justExited && cdLeft>0) cdLeft--;

      // --- ① エントリー（ノーポジ時。ただし決済と同じ足ではドテンしない）---
      if(pos==0 && !justExited)
      {
         if(cdLeft>0)
         {
            BufReason[i]=15.0;   // クールダウン中=新規を出さない(調整波回避)
         }
         else
         {
         // ── 新方式: ベースMA(選択したMAのslope方向)が主役 ──
         //   方向 d は wmaDir(=ベースMAの傾き) で決める。
         //   M1スパイク/圧縮/オーバーシュートは「任意フィルター」。
         //   全フィルターOFFなら、ベースMAの傾きだけで矢印を出す。
         int d = wmaDir;   // ベースMAの傾き方向(1=上/-1=下/0=平行グレー)

         if(d == 0)
         {
            BufReason[i]=10.0;   // グレーゾーン(レンジ)=待機
         }
         else
         {
            bool allow = true;

            // ★守備つまみ②:色がInpColorConfirmBars本“連続”するまで入らない
            //   (レンジ内の1本だけの跳ね=単発を消す。1なら従来どおり即許可)
            if(colorRun < InpColorConfirmBars) { allow = false; BufReason[i]=17.0; } // 色の確認待ち

            // ★調整波回避(任意): 平均足の色がエントリー方向と一致していること
            //   (FRAMAが一瞬上向いても、平均足がまだ陰線=押し目/戻りなら入らない)
            if(allow && !InpAlsoTakePullback)
            {
               bool haAgree = (d==1 && haColor[i]==0) || (d==-1 && haColor[i]==1);
               if(!haAgree) { allow = false; BufReason[i]=18.0; } // 平均足が逆色=調整波回避
            }

            // ①M1スパイク要求(ONの時だけ)：引き金が同方向に点灯していること
            if(InpFilM1Spike)
            {
               bool m1ok = (m1Onset && m1Dir==d);
               bool m5ok = (spike5 && !prevSpike5 && emaDir5==d);
               if(!(m1ok || m5ok)) { allow = false; BufReason[i]=11.0; } // M1スパイク無し
            }

            // ②圧縮フィルター(ONの時だけ)：スクイーズ中は弾く
            if(allow && InpFilSqueeze && sqzOn) { allow = false; BufReason[i]=12.0; } // 圧縮

            // ③オーバーシュートフィルター(ONの時だけ)：急変・行き過ぎは弾く
            if(allow && InpFilOvershoot && BufOvershoot[i] != 0.0) { allow = false; BufReason[i]=13.0; } // オーバーシュート

            // ⑤方向MA(KAMA)とEMA点灯(スパイク)の同方向・同時点灯を要求(ONの時)
            //   d=KAMAの傾き方向, spike5=EMA収束スパイク点灯, emaDir5=EMAスパイクの向き
            if(allow && InpRequireEmaColit && !(spike5 && emaDir5==d)) { allow = false; BufReason[i]=16.0; } // EMA未点灯/方向不一致

            // 既に同方向で1回出していたら、平行(グレー)に戻るまで再度出さない
            //   (レンジでの連続矢印を防ぐ。trendDirが変わればまた出せる)
            if(allow && segHadEntry && d==trendDir) { allow = false; BufReason[i]=14.0; } // 再エントリーロック

            if(allow)
            {
               if(d==1)
               {
                  BufBuy[i] = low[i] - atr[i]*0.5; BufReason[i]=1.0;   // BUY発生
                  pos = 1; segHadEntry = true; trendDir = 1;
                  if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
                  { Alert(_Symbol," BUYシグナル(ベースMA)"); g_lastAlertTime=time[i]; }
               }
               else
               {
                  BufSell[i] = high[i] + atr[i]*0.5; BufReason[i]=2.0;  // SELL発生
                  pos = -1; segHadEntry = true; trendDir = -1;
                  if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
                  { Alert(_Symbol," SELLシグナル(ベースMA)"); g_lastAlertTime=time[i]; }
               }
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
