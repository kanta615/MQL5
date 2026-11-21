//+------------------------------------------------------------------+
//|                          DokaKotsu_GrayZone_MA.mq5              |
//|   グレーゾーン(レンジ)可視化用 5段階カラーMA                    |
//|                                                                  |
//|   MAの傾き(slope, ATR正規化)を2つの閾値で5段階に色分け:          |
//|     ドジャーブルー : 上昇トレンド (slope >= +InpTrendTh)         |
//|     サックス(水色) : 上昇         (+InpRangeTh <= slope < +Trend)|
//|     グレー         : レンジ       (|slope| < InpRangeTh)         |
//|     ピンク         : 下降         (-Trend < slope <= -InpRangeTh)|
//|     赤             : 下降トレンド (slope <= -InpTrendTh)         |
//|                                                                  |
//|   MA種類・期間・2つの閾値を入力で変更可能。                      |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   1

#property indicator_label1  "GrayZone MA"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrGray, clrDodgerBlue, clrLightSkyBlue, clrHotPink, clrRed
#property indicator_width1  3

//=== MA種類 =======================================================
enum ENUM_MATYPE
{
   MA_SMA,       // SMA
   MA_EMA,       // EMA
   MA_WMA,       // WMA
   MA_SMOOTHED,  // Smoothed(SMMA)
   MA_HMA,       // HMA (Hull)
   MA_DEMA,      // DEMA
   MA_TEMA,      // TEMA
   MA_ZLEMA,     // ZLEMA (Zero Lag)
   MA_TMA,       // TMA (Triangular)
   MA_LSMA,      // LSMA (Least Squares)
   MA_ALMA,      // ALMA
   MA_VWMA       // VWMA (Volume Weighted)
};

//=== 入力 =========================================================
input ENUM_MATYPE InpMaType    = MA_WMA;   // MAの種類
input int         InpPeriod    = 14;       // 期間
input double      InpRangeTh   = 0.10;     // レンジ/通常の境界(ATR比slope)
input double      InpTrendTh   = 0.25;     // 通常/トレンドの境界(ATR比slope)
input int         InpAtrPeriod = 14;       // slope正規化用ATR期間
input int         InpAlmaWin   = 9;        // ALMA用ウィンドウ
input double      InpAlmaOffset= 0.85;     // ALMA用オフセット
input double      InpAlmaSigma = 6.0;      // ALMA用シグマ

//=== バッファ =====================================================
double BufMA[];
double BufColor[];   // 0=グレー 1=ドジャーブルー 2=サックス 3=ピンク 4=赤

double Price[];      // 作業用: 終値
double maRaw[];      // 作業用: MA生値

int hATR;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufMA,    INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);
   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 5);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, clrGray);        // レンジ
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, clrDodgerBlue);  // 上昇トレンド
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 2, clrLightSkyBlue);// 上昇(サックス)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 3, clrHotPink);     // 下降(ピンク)
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 4, clrRed);         // 下降トレンド

   hATR = iATR(_Symbol, _Period, InpAtrPeriod);

   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("GrayZone MA (%s %d, R%.2f/T%.2f)",
        MaTypeName(InpMaType), InpPeriod, InpRangeTh, InpTrendTh));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
}

string MaTypeName(ENUM_MATYPE t)
{
   switch(t)
   {
      case MA_SMA:return "SMA"; case MA_EMA:return "EMA"; case MA_WMA:return "WMA";
      case MA_SMOOTHED:return "SMMA"; case MA_HMA:return "HMA"; case MA_DEMA:return "DEMA";
      case MA_TEMA:return "TEMA"; case MA_ZLEMA:return "ZLEMA"; case MA_TMA:return "TMA";
      case MA_LSMA:return "LSMA"; case MA_ALMA:return "ALMA"; case MA_VWMA:return "VWMA";
   }
   return "?";
}

//+------------------------------------------------------------------+
//| 基本MA: SMA/EMA/WMA/SMMA を pos位置・period本で計算             |
//|   src=入力配列(昇順) vol=出来高(VWMA用、無ければNULL)          |
//+------------------------------------------------------------------+
double BaseMA(const double &src[], const long &vol[], int pos, int period,
              ENUM_MATYPE method, bool useVol=false)
{
   if(pos < period-1 || period < 1) return src[pos];
   switch(method)
   {
      case MA_SMA:
      {
         double s=0; for(int k=0;k<period;k++) s+=src[pos-k];
         return s/period;
      }
      case MA_EMA:
      {
         double pr=2.0/(period+1.0);
         int st=MathMax(0,pos-period*3); double e=src[st];
         for(int k=st+1;k<=pos;k++) e=src[k]*pr+e*(1-pr);
         return e;
      }
      case MA_SMOOTHED:
      {
         int st=MathMax(0,pos-period*3); double sm=src[st];
         for(int k=st+1;k<=pos;k++) sm=(sm*(period-1)+src[k])/period;
         return sm;
      }
      case MA_WMA:
      {
         double s=0,w=0; for(int k=0;k<period;k++){int ww=period-k; s+=src[pos-k]*ww; w+=ww;}
         return (w>0)?s/w:src[pos];
      }
      case MA_VWMA:
      {
         double s=0,w=0;
         for(int k=0;k<period;k++){ double vv=(double)vol[pos-k]; s+=src[pos-k]*vv; w+=vv; }
         return (w>0)?s/w:src[pos];
      }
   }
   // それ以外はSMAで代用(呼び出し側で別途処理)
   double s2=0; for(int k=0;k<period;k++) s2+=src[pos-k];
   return s2/period;
}

//+------------------------------------------------------------------+
//| WMA(配列の任意位置・任意期間) HMA用ヘルパ                       |
//+------------------------------------------------------------------+
double WMAat(const double &src[], int pos, int period)
{
   if(pos<period-1||period<1) return src[pos];
   double s=0,w=0; for(int k=0;k<period;k++){int ww=period-k; s+=src[pos-k]*ww; w+=ww;}
   return (w>0)?s/w:src[pos];
}
double EMAat(const double &src[], int pos, int period)
{
   if(period<1) return src[pos];
   double pr=2.0/(period+1.0);
   int st=MathMax(0,pos-period*3); double e=src[st];
   for(int k=st+1;k<=pos;k++) e=src[k]*pr+e*(1-pr);
   return e;
}

//+------------------------------------------------------------------+
//| 高度MAを計算してmaRaw[]全体を埋める                            |
//+------------------------------------------------------------------+
void FillMA(const double &close[], const long &vol[], int rates_total)
{
   ArrayResize(maRaw, rates_total);
   int p = InpPeriod;

   switch(InpMaType)
   {
      case MA_SMA: case MA_EMA: case MA_WMA: case MA_SMOOTHED: case MA_VWMA:
      {
         bool uv = (InpMaType==MA_VWMA);
         for(int i=0;i<rates_total;i++) maRaw[i]=BaseMA(close,vol,i,p,InpMaType,uv);
         break;
      }
      case MA_TMA:   // 三角=SMAを2回
      {
         int h=(p+1)/2;
         double tmp[]; ArrayResize(tmp,rates_total);
         for(int i=0;i<rates_total;i++){ double s=0;int c=0;for(int k=0;k<h&&i-k>=0;k++){s+=close[i-k];c++;} tmp[i]=s/c; }
         for(int i=0;i<rates_total;i++){ double s=0;int c=0;for(int k=0;k<h&&i-k>=0;k++){s+=tmp[i-k];c++;} maRaw[i]=s/c; }
         break;
      }
      case MA_DEMA:  // 2*EMA - EMA(EMA)
      {
         double e1[]; ArrayResize(e1,rates_total);
         for(int i=0;i<rates_total;i++) e1[i]=EMAat(close,i,p);
         for(int i=0;i<rates_total;i++) maRaw[i]=2*e1[i]-EMAat(e1,i,p);
         break;
      }
      case MA_TEMA:  // 3*EMA -3*EMA(EMA) + EMA(EMA(EMA))
      {
         double e1[],e2[]; ArrayResize(e1,rates_total);ArrayResize(e2,rates_total);
         for(int i=0;i<rates_total;i++) e1[i]=EMAat(close,i,p);
         for(int i=0;i<rates_total;i++) e2[i]=EMAat(e1,i,p);
         for(int i=0;i<rates_total;i++) maRaw[i]=3*e1[i]-3*e2[i]+EMAat(e2,i,p);
         break;
      }
      case MA_ZLEMA: // EMA(price + (price - price[lag]))
      {
         int lag=(p-1)/2;
         double adj[]; ArrayResize(adj,rates_total);
         for(int i=0;i<rates_total;i++){ int j=MathMax(0,i-lag); adj[i]=close[i]+(close[i]-close[j]); }
         for(int i=0;i<rates_total;i++) maRaw[i]=EMAat(adj,i,p);
         break;
      }
      case MA_HMA:   // WMA(2*WMA(p/2) - WMA(p), sqrt(p))
      {
         int half=MathMax(1,p/2); int sq=MathMax(1,(int)MathSqrt(p));
         double raw[]; ArrayResize(raw,rates_total);
         for(int i=0;i<rates_total;i++) raw[i]=2*WMAat(close,i,half)-WMAat(close,i,p);
         for(int i=0;i<rates_total;i++) maRaw[i]=WMAat(raw,i,sq);
         break;
      }
      case MA_LSMA:  // 最小二乗(線形回帰)の最終値
      {
         for(int i=0;i<rates_total;i++)
         {
            if(i<p-1){ maRaw[i]=close[i]; continue; }
            double sx=0,sy=0,sxx=0,sxy=0;
            for(int k=0;k<p;k++){ double x=k; double y=close[i-(p-1)+k]; sx+=x;sy+=y;sxx+=x*x;sxy+=x*y; }
            double den=p*sxx-sx*sx;
            double a=(den!=0)?(p*sxy-sx*sy)/den:0;
            double b=(sy-a*sx)/p;
            maRaw[i]=a*(p-1)+b;   // 最新点の回帰値
         }
         break;
      }
      case MA_ALMA:  // Arnaud Legoux
      {
         int win=MathMax(2,InpAlmaWin);
         double m=InpAlmaOffset*(win-1);
         double s=win/InpAlmaSigma;
         for(int i=0;i<rates_total;i++)
         {
            if(i<win-1){ maRaw[i]=close[i]; continue; }
            double wsum=0,sum=0;
            for(int k=0;k<win;k++){
               double w=MathExp(-((k-m)*(k-m))/(2*s*s));
               sum += close[i-(win-1)+k]*w; wsum+=w;
            }
            maRaw[i]=(wsum>0)?sum/wsum:close[i];
         }
         break;
      }
      default:
         for(int i=0;i<rates_total;i++) maRaw[i]=BaseMA(close,vol,i,p,MA_SMA);
   }
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
   if(rates_total < InpPeriod+InpAtrPeriod+5) return(0);

   double atr[]; ArrayResize(atr,rates_total); ArraySetAsSeries(atr,false);
   if(CopyBuffer(hATR,0,0,rates_total,atr) <= 0) return(0);

   // MA本体を計算
   FillMA(close, tick_volume, rates_total);

   for(int i=0;i<rates_total;i++)
   {
      BufMA[i]=maRaw[i];
      if(i<1 || atr[i]<=0){ BufColor[i]=0; continue; }

      // slope = (MA[i]-MA[i-1]) / ATR  (ATR正規化で価格水準に依存しない)
      double slope=(maRaw[i]-maRaw[i-1])/atr[i];

      int col;
      if(slope >=  InpTrendTh)      col=1; // 上昇トレンド ドジャーブルー
      else if(slope >=  InpRangeTh) col=2; // 上昇        サックス
      else if(slope <= -InpTrendTh) col=4; // 下降トレンド 赤
      else if(slope <= -InpRangeTh) col=3; // 下降        ピンク
      else                          col=0; // レンジ      グレー
      BufColor[i]=col;
   }
   return(rates_total);
}
//+------------------------------------------------------------------+
