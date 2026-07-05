//+------------------------------------------------------------------+
//|                                       DokaKotsu_Pullback_Sub.mq5  |
//|   ノーベース指数（押しの浅さ × 伸び）をサブ窓に表示              |
//|     ヒストグラム：ノーベース度 = legATR ×(1 − min(deepestPull/θ,1))|
//|     ライン      ：barsNoPull（無調整の経過バー数, 正規化）        |
//|     θ（深い押し）= ATR × InpDeepATR                               |
//|                                                                  |
//|   ★計算は素の関数 PB_Step()／状態は struct PBState のみ。         |
//|     配列・series 非依存なので MQL4 や EA へそのまま移植できる。    |
//|     両値（NoBase度・barsNoPull生値）をバッファ保持＝EA直読み可。   |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   3

//--- 入力
input double InpDeepATR    = 1.5;        // 深い押し閾値 θ（ATR倍）※お任せ初期値
input int    InpAtrPeriod  = 14;         // ATR期間
input double InpWarnLevel  = 2.0;        // 警戒ライン（ノーベース度）
input bool   InpShowNoBase = true;       // ノーベース度（ヒストグラム）を表示
input bool   InpShowBars   = true;       // barsNoPull（ライン）を表示
input double InpBarsScale   = 0.1;       // barsNoPull → ライン正規化係数
input bool   InpColorByDir  = true;      // レグ方向で色分け（上伸び/下伸び）
input int    InpMaxBars     = 4000;      // 計算する最大バー数（負荷上限）
input color  InpColUp    = clrSeaGreen;  // 上伸びノーベース色
input color  InpColDown  = clrSteelBlue; // 下伸びノーベース色
input color  InpColWarn  = clrTomato;    // 警戒色（WarnLevel超）
input color  InpColBars  = clrSilver;    // barsライン色

//--- バッファ
double NoBaseBuf[];     // plot0 data : ノーベース度
double ColorBuf[];      // plot0 color: 0=上 1=下 2=警戒
double BarsLineBuf[];   // plot1 data : barsNoPull（正規化）
double BarsRawBuf[];    // plot2 data : barsNoPull 生値（非表示・EA読み取り用）

int hAtr = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| 状態（この struct と関数だけで MQL4/EA へ移植可能）              |
//+------------------------------------------------------------------+
struct PBState
{
   int    dir;       // +1=上レグ / -1=下レグ / 0=未確定
   double pivot;     // レグ起点価格（上=起点安値, 下=起点高値）
   double runExt;    // レグ内の到達極値（上=最高値, 下=最安値）
   double deepest;   // レグ内の最大逆行（価格）
   int    bars;      // 起点からの経過バー（= barsNoPull）
   double bHigh;     // 未確定時の暫定高値
   double bLow;      // 未確定時の暫定安値
   bool   inited;
};

void PB_Reset(PBState &s)
{
   s.dir=0; s.pivot=0.0; s.runExt=0.0; s.deepest=0.0; s.bars=0;
   s.bHigh=0.0; s.bLow=0.0; s.inited=false;
}

//--- 1バー進めて nobase度 と bars を返す（pandas非依存・配列非依存）
//    high/low : 当該バーの高値安値
//    atr      : 当該バーのATR
//    thetaATR : 深い押し閾値（ATR倍）
void PB_Step(PBState &s,const double high,const double low,const double atr,
             const double thetaATR,double &outNoBase,int &outBars)
{
   if(atr<=0.0){ outNoBase=0.0; outBars=s.bars; return; }
   double theta = thetaATR*atr;   // 価格での深い押し閾値

   if(!s.inited)
   {
      s.inited=true; s.dir=0;
      s.bHigh=high; s.bLow=low;
      s.runExt=0.0; s.pivot=0.0; s.deepest=0.0; s.bars=0;
   }

   if(s.dir==0)
   {
      //--- 方向未確定：θ動いた向きでレグ確定
      if(high>s.bHigh) s.bHigh=high;
      if(low <s.bLow ) s.bLow =low;
      if(high-s.bLow>=theta)       { s.dir=1;  s.pivot=s.bLow;  s.runExt=high; s.deepest=0.0; s.bars=0; }
      else if(s.bHigh-low>=theta)  { s.dir=-1; s.pivot=s.bHigh; s.runExt=low;  s.deepest=0.0; s.bars=0; }
   }
   else if(s.dir==1)
   {
      //--- 上レグ
      if(high>s.runExt) s.runExt=high;
      double pull=s.runExt-low;            // 走高値からの逆行
      if(pull>s.deepest) s.deepest=pull;
      if(pull>=theta)                       // 深い押し＝土台形成 → 下レグへ転換
      { s.dir=-1; s.pivot=s.runExt; s.runExt=low; s.deepest=0.0; s.bars=0; }
      else
      { s.bars++; }
   }
   else
   {
      //--- 下レグ（dir==-1）
      if(low<s.runExt) s.runExt=low;
      double pull=high-s.runExt;            // 走安値からの逆行
      if(pull>s.deepest) s.deepest=pull;
      if(pull>=theta)                       // 深い戻し＝土台形成 → 上レグへ転換
      { s.dir=1; s.pivot=s.runExt; s.runExt=high; s.deepest=0.0; s.bars=0; }
      else
      { s.bars++; }
   }

   double legATR=(s.dir==0)?0.0:(MathAbs(s.runExt-s.pivot)/atr);   // 伸び幅（ATR）
   double ratio =(theta>0.0)?MathMin(s.deepest/theta,1.0):0.0;     // 押しの深さ比（0=浅い…1=θ相当）
   outNoBase=legATR*(1.0-ratio);   // 大きく伸びて押しが浅いほど大
   outBars  =s.bars;
}

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0,NoBaseBuf,  INDICATOR_DATA);
   SetIndexBuffer(1,ColorBuf,   INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2,BarsLineBuf,INDICATOR_DATA);
   SetIndexBuffer(3,BarsRawBuf, INDICATOR_DATA);

   //--- plot0：ノーベース度（色付きヒストグラム）
   PlotIndexSetInteger(0,PLOT_DRAW_TYPE,InpShowNoBase?DRAW_COLOR_HISTOGRAM:DRAW_NONE);
   PlotIndexSetInteger(0,PLOT_LINE_WIDTH,2);
   PlotIndexSetInteger(0,PLOT_COLOR_INDEXES,3);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,0,InpColUp);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,1,InpColDown);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,2,InpColWarn);
   PlotIndexSetString(0,PLOT_LABEL,"NoBase度");
   PlotIndexSetDouble(0,PLOT_EMPTY_VALUE,EMPTY_VALUE);

   //--- plot1：barsNoPull（正規化ライン）
   PlotIndexSetInteger(1,PLOT_DRAW_TYPE,InpShowBars?DRAW_LINE:DRAW_NONE);
   PlotIndexSetInteger(1,PLOT_LINE_COLOR,0,InpColBars);
   PlotIndexSetInteger(1,PLOT_LINE_WIDTH,1);
   PlotIndexSetString(1,PLOT_LABEL,"bars(norm)");
   PlotIndexSetDouble(1,PLOT_EMPTY_VALUE,EMPTY_VALUE);

   //--- plot2：barsNoPull 生値（非表示・データウィンドウ/EA用）
   PlotIndexSetInteger(2,PLOT_DRAW_TYPE,DRAW_NONE);
   PlotIndexSetString(2,PLOT_LABEL,"bars(raw)");

   //--- 警戒ライン
   IndicatorSetInteger(INDICATOR_LEVELS,1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,0,InpWarnLevel);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,0,clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE,0,STYLE_DOT);

   IndicatorSetInteger(INDICATOR_DIGITS,3);
   IndicatorSetString(INDICATOR_SHORTNAME,
      StringFormat("Pullback(θ=ATR×%.2f, warn=%.2f)",InpDeepATR,InpWarnLevel));

   hAtr=iATR(_Symbol,_Period,InpAtrPeriod);
   if(hAtr==INVALID_HANDLE){ Print("[Pullback] iATR ハンドル作成失敗"); return INIT_FAILED; }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hAtr!=INVALID_HANDLE) IndicatorRelease(hAtr);
}

//+------------------------------------------------------------------+
//| 末尾 InpMaxBars 本を毎回ゼロから再計算（ライブ足の汚染を防ぐ）   |
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
   if(rates_total<InpAtrPeriod+2) return 0;

   int start=0;
   if(rates_total>InpMaxBars) start=rates_total-InpMaxBars;

   int need=rates_total-start;
   static double atr[];
   ArraySetAsSeries(atr,false);
   if(CopyBuffer(hAtr,0,0,need,atr)<need) return prev_calculated; // atr[k] = バー(start+k)

   //--- start より前は空に
   for(int i=0;i<start;i++)
   {
      NoBaseBuf[i]=EMPTY_VALUE; ColorBuf[i]=0.0;
      BarsLineBuf[i]=EMPTY_VALUE; BarsRawBuf[i]=0.0;
   }

   PBState st; PB_Reset(st);
   for(int i=start;i<rates_total;i++)
   {
      double a=atr[i-start];
      double nb; int br;
      PB_Step(st,high[i],low[i],a,InpDeepATR,nb,br);

      NoBaseBuf[i]=nb;
      BarsRawBuf[i]=(double)br;
      BarsLineBuf[i]=br*InpBarsScale;

      int ci=0;
      if(nb>=InpWarnLevel)                 ci=2;   // 警戒
      else if(InpColorByDir && st.dir<0)   ci=1;   // 下伸び
      else                                 ci=0;   // 上伸び/通常
      ColorBuf[i]=(double)ci;
   }

   return rates_total;
}
//+------------------------------------------------------------------+
