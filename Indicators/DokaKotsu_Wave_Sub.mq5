//+------------------------------------------------------------------+
//|                              DokaKotsu_Wave_Sub.mq5              |
//|   波オシレーター(Wave) ※サブ窓・単独計算版                       |
//|                                                                  |
//|  ■■ 2026-07-02 単独化 ■■                                        |
//|    本体インジを参照せず、このインジ自身が波(早い/遅い/シグナル)  |
//|    とレジーム(方向MAの傾き)を自分の入力で計算して描画する。      |
//|    ・早い波/遅い波/シグナルの期間を変えると即このサブ窓に反映。  |
//|    ・MA計算は DokaKotsu_Core.mqh を共用(全17種のMA対応)。        |
//|    ※注意: 本体インジ/EAが実際に使う波は本体の既定値。           |
//|      ここで変えた値は表示だけで、売買には反映されない(単独)。    |
//|      値が決まったら本体(コア)側の既定値を変更すること。          |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "3.00"
#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   7

#include "DokaKotsu_Core.mqh"

#property indicator_label1  "Wave上昇"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_width1  2
#property indicator_label2  "Waveレンジ"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGray
#property indicator_width2  2
#property indicator_label3  "Wave下降"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_width3  2
#property indicator_label4  "Wave単色"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGreen
#property indicator_width4  2
#property indicator_label5  "Signal"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrCadetBlue
#property indicator_width5  2
#property indicator_label6  "UpCross"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrAqua
#property indicator_width6  1
#property indicator_label7  "DownCross"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrGold
#property indicator_width7  1

//=== 入力：波のパラメータ(このインジ自身が計算する) ===================
input group "波の作り(単独計算)"
input ENUM_WMATYPE InpWaveMaType = WT_KAMA;                 // 波:MAの種類
input int    InpWaveFast   = 6;                             // 波:早い線の期間
input int    InpWaveSlow   = 24;                            // 波:遅い線EMA期間
input int    InpWaveSignal = 9;                             // 波:シグナル平滑
//=== 入力：レジーム色に使う方向MA(本体WMA34と同じ作り) ================
input group "レジーム色の方向MA"
input ENUM_WMATYPE InpWmaType   = WT_WMA;                   // 方向判定MAの種類(レジーム色用)
input int    InpWmaPeriod       = 34;                       // 方向判定MAの期間
input double InpWmaSlopeTh       = 0.10;                    // 点灯しきい値(slope÷ATR)
input double InpWmaStickyMult    = 0.3;                     // 色の粘り(消灯=点灯×本値)
//=== 入力：全MA種で計算するための共有パラメータ ========================
input group "共有MAパラメータ(全MA種用)"
input double InpMamaFast   = 0.5;                           // MAMA: FastLimit
input double InpMamaSlow   = 0.05;                          // MAMA: SlowLimit
input int    InpAtrRefPeriod = 50;                          // ATR適応: 参照期間
input double InpAtrFastA   = 0.6;                           // ATR適応: 速い時のα
input double InpAtrSlowA   = 0.05;                          // ATR適応: 遅い時のα
input bool   InpHighVolFaster = true;                       // ATR Adaptive: 高ボラで速く
//=== 入力：表示 ========================================================
input group "表示"
input bool   InpShowRegime   = true;       // 波線を背景色(上昇/レンジ/下降)で塗る
input bool   InpDrawDots     = true;       // サブ窓に●を表示
input bool   InpDrawOnChart  = true;       // メインチャートにも●を表示
input int    InpDotCode      = 159;        // ●のWingdingsコード(159=丸ドット)
input int    InpDotSize      = 1;          // ●のサイズ(1=小 … 5=大)
input double InpChartOffsetATR = 0.6;      // メイン●のローソクからの離し(ATR倍)
input int    InpMaxBars      = 3000;       // 描画する最大バー数(負荷上限)

//--- バッファ
double WaveUp[];      // plot0 波(上昇)
double WaveRange[];   // plot1 波(レンジ)
double WaveDown[];    // plot2 波(下降)
double WavePlain[];   // plot3 波(単色：レジームOFF時)
double SignalBuf[];   // plot4 シグナル
double UpDotBuf[];    // plot5 上抜け●
double DownDotBuf[];  // plot6 下抜け●

int      hWave = INVALID_HANDLE;  // 波:早い線MAハンドル(標準型のみ)
int      hDir  = INVALID_HANDLE;  // レジーム色用:方向MAハンドル
int      hAtr  = INVALID_HANDLE;  // ATR
int      g_dotSize = 1;
datetime s_lastDone = 0;

//+------------------------------------------------------------------+
//| MA配列を埋める(標準型はハンドル、配列計算型はCalc_*)             |
//+------------------------------------------------------------------+
void FillMA(double &out[], const ENUM_WMATYPE t, const int period, const int handle,
            const double &close[], const double &high[], const double &low[],
            const long &tvol[], const double &atr[], const int rt)
{
   ArrayResize(out,rt);
   for(int i=0;i<rt;i++) out[i]=close[i];   // 既定=close(inf混入防止)
   if(handle!=INVALID_HANDLE)
   {
      ArraySetAsSeries(out,false);
      CopyBuffer(handle,0,0,rt,out);
      return;
   }
   switch(t)
   {
      case WT_TMA:       Calc_TMA   (out,close,period,rt);                 break;
      case WT_VWMA:      Calc_VWMA  (out,close,tvol,period,rt);            break;
      case WT_ATR_ADAPT: Calc_ATRADAPT(out,close,atr,InpAtrRefPeriod,InpAtrFastA,InpAtrSlowA,InpHighVolFaster,rt); break;
      case WT_ATR_TREND: Calc_ATRTREND(out,close,atr,InpAtrRefPeriod,InpAtrFastA,InpAtrSlowA,rt); break;
      case WT_HMA:       Calc_HMA   (out,close,period,rt);                 break;
      case WT_DEMA:      Calc_DEMA  (out,close,period,rt);                 break;
      case WT_ZLEMA:     Calc_ZLEMA (out,close,period,rt);                 break;
      case WT_MAMA:      Calc_MAMA  (out,close,InpMamaFast,InpMamaSlow,rt); break;
      case WT_LSMA:      Calc_LSMA  (out,close,period,rt);                 break;
      case WT_VWAP:      Calc_VWAP  (out,high,low,close,tvol,period,rt);   break;
      default: break;   // 既定close
   }
}

//+------------------------------------------------------------------+
void DrawChartDot(const datetime t,const double price,const color c,const bool isUp)
{
   string nm=StringFormat("DKWave_%I64d_%s",(long)t,(isUp?"U":"D"));
   if(ObjectFind(0,nm)>=0) return;
   if(!ObjectCreate(0,nm,OBJ_ARROW,0,t,price)) return;
   ObjectSetInteger(0,nm,OBJPROP_ARROWCODE,InpDotCode);
   ObjectSetInteger(0,nm,OBJPROP_COLOR,c);
   ObjectSetInteger(0,nm,OBJPROP_ANCHOR,(isUp?ANCHOR_TOP:ANCHOR_BOTTOM));
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,g_dotSize);
   ObjectSetInteger(0,nm,OBJPROP_BACK,false);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,nm,OBJPROP_HIDDEN,true);
}

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0,WaveUp,    INDICATOR_DATA);
   SetIndexBuffer(1,WaveRange, INDICATOR_DATA);
   SetIndexBuffer(2,WaveDown,  INDICATOR_DATA);
   SetIndexBuffer(3,WavePlain, INDICATOR_DATA);
   SetIndexBuffer(4,SignalBuf, INDICATOR_DATA);
   SetIndexBuffer(5,UpDotBuf,  INDICATOR_DATA);
   SetIndexBuffer(6,DownDotBuf,INDICATOR_DATA);

   g_dotSize = (InpDotSize<1 ? 1 : (InpDotSize>5 ? 5 : InpDotSize));

   PlotIndexSetInteger(0,PLOT_DRAW_TYPE,InpShowRegime?DRAW_LINE:DRAW_NONE);
   PlotIndexSetInteger(1,PLOT_DRAW_TYPE,InpShowRegime?DRAW_LINE:DRAW_NONE);
   PlotIndexSetInteger(2,PLOT_DRAW_TYPE,InpShowRegime?DRAW_LINE:DRAW_NONE);
   PlotIndexSetInteger(3,PLOT_DRAW_TYPE,InpShowRegime?DRAW_NONE:DRAW_LINE);
   PlotIndexSetInteger(4,PLOT_DRAW_TYPE,DRAW_LINE);
   for(int p=0;p<=4;p++) PlotIndexSetDouble(p,PLOT_EMPTY_VALUE,EMPTY_VALUE);

   PlotIndexSetInteger(5,PLOT_DRAW_TYPE,InpDrawDots?DRAW_ARROW:DRAW_NONE);
   PlotIndexSetInteger(5,PLOT_ARROW,InpDotCode);
   PlotIndexSetInteger(5,PLOT_LINE_WIDTH,g_dotSize);
   PlotIndexSetDouble(5,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   PlotIndexSetInteger(6,PLOT_DRAW_TYPE,InpDrawDots?DRAW_ARROW:DRAW_NONE);
   PlotIndexSetInteger(6,PLOT_ARROW,InpDotCode);
   PlotIndexSetInteger(6,PLOT_LINE_WIDTH,g_dotSize);
   PlotIndexSetDouble(6,PLOT_EMPTY_VALUE,EMPTY_VALUE);

   IndicatorSetInteger(INDICATOR_LEVELS,1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE,0,0.0);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR,0,clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE,0,STYLE_DOT);
   IndicatorSetInteger(INDICATOR_DIGITS,3);
   IndicatorSetString(INDICATOR_SHORTNAME,"DokaKotsu_Wave_Sub (単独計算)");

   //--- 自前計算用ハンドル(本体は参照しない)
   hWave = MakeWaveHandle(InpWaveMaType, InpWaveFast);   // 波:早い線MA(標準型のみ有効)
   hDir  = MakeMA(InpWmaType, InpWmaPeriod, _Period);    // レジーム色用:方向MA
   hAtr  = iATR(_Symbol,_Period,14);
   if(hAtr==INVALID_HANDLE){ Print("[Wave] iATR 失敗"); return INIT_FAILED; }

   s_lastDone=0;
   ObjectsDeleteAll(0,"DKWave_");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hWave!=INVALID_HANDLE) IndicatorRelease(hWave);
   if(hDir !=INVALID_HANDLE) IndicatorRelease(hDir);
   if(hAtr !=INVALID_HANDLE) IndicatorRelease(hAtr);
   ObjectsDeleteAll(0,"DKWave_");
   Comment("");
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
   if(rates_total<10) return 0;

   //--- ATR取得
   static double atrW[];
   ArrayResize(atrW,rates_total); ArraySetAsSeries(atrW,false);
   if(CopyBuffer(hAtr,0,0,rates_total,atrW)<=0) return prev_calculated;

   //--- 波の早い線MA・レジーム用の方向MA を自前計算
   static double wvMA[], wma[];
   FillMA(wvMA, InpWaveMaType, InpWaveFast,  hWave, close,high,low,tick_volume,atrW,rates_total);
   FillMA(wma,  InpWmaType,    InpWmaPeriod, hDir,  close,high,low,tick_volume,atrW,rates_total);

   //--- 遅い線(wvMAのEMA)
   static double wvSlow[]; ArrayResize(wvSlow,rates_total);
   double wps=2.0/(InpWaveSlow+1.0);
   for(int i=0;i<rates_total;i++) wvSlow[i]=(i==0)?wvMA[i]:wvMA[i]*wps+wvSlow[i-1]*(1.0-wps);

   //--- 波値・シグナル・レジーム・クロス を計算(本体と同じ作り)
   static double vWave[],vSig[],vReg[],vUp[],vDn[];
   ArrayResize(vWave,rates_total); ArrayResize(vSig,rates_total); ArrayResize(vReg,rates_total);
   ArrayResize(vUp,rates_total);   ArrayResize(vDn,rates_total);
   double wpg=2.0/(InpWaveSignal+1.0);
   double wPrevSig=0.0; int wPrevDir=0;
   double wThOn=InpWmaSlopeTh, wThOff=InpWmaSlopeTh*InpWmaStickyMult;
   for(int i=0;i<rates_total;i++)
   {
      double a=atrW[i];
      double wv=(a>0.0)?((wvMA[i]-wvSlow[i])/a):0.0;
      if(!MathIsValidNumber(wv)) wv=0.0;
      double sg=(i==0)?wv:(wv*wpg+wPrevSig*(1.0-wpg));
      if(!MathIsValidNumber(sg)) sg=0.0;
      wPrevSig=sg;
      vWave[i]=wv; vSig[i]=sg;
      double slope=(i>0 && a>0.0)?((wma[i]-wma[i-1])/a):0.0;
      int d;
      if(wPrevDir==1)       d=(slope<-wThOn)?-1:(slope< wThOff?0: 1);
      else if(wPrevDir==-1) d=(slope> wThOn)? 1:(slope>-wThOff?0:-1);
      else                  d=(slope> wThOn)? 1:(slope<-wThOn ?-1: 0);
      wPrevDir=d; vReg[i]=d;
      vUp[i]=EMPTY_VALUE; vDn[i]=EMPTY_VALUE;
   }
   for(int i=1;i<=rates_total-2;i++)
   {
      if(vWave[i]>vSig[i] && vWave[i-1]<=vSig[i-1]) vUp[i]=vWave[i];
      if(vWave[i]<vSig[i] && vWave[i-1]>=vSig[i-1]) vDn[i]=vWave[i];
   }

   int start=0;
   if(rates_total>InpMaxBars) start=rates_total-InpMaxBars;

   for(int i=0;i<start;i++)
   {
      WaveUp[i]=EMPTY_VALUE; WaveRange[i]=EMPTY_VALUE; WaveDown[i]=EMPTY_VALUE; WavePlain[i]=EMPTY_VALUE;
      SignalBuf[i]=EMPTY_VALUE; UpDotBuf[i]=EMPTY_VALUE; DownDotBuf[i]=EMPTY_VALUE;
   }

   //--- 波・シグナル・●(色分けはレジーム vReg)
   for(int i=start;i<rates_total;i++)
   {
      double w=vWave[i];                 if(!MathIsValidNumber(w)) w=0.0;
      SignalBuf[i]=MathIsValidNumber(vSig[i])?vSig[i]:EMPTY_VALUE;
      WaveUp[i]=EMPTY_VALUE; WaveRange[i]=EMPTY_VALUE; WaveDown[i]=EMPTY_VALUE; WavePlain[i]=EMPTY_VALUE;
      UpDotBuf[i]=EMPTY_VALUE; DownDotBuf[i]=EMPTY_VALUE;

      if(!InpShowRegime)
      {
         WavePlain[i]=w; if(i>start) WavePlain[i-1]=vWave[i-1];
      }
      else
      {
         int d=(int)MathRound(vReg[i]);
         if(d==1)      { WaveUp[i]=w;    if(i>start) WaveUp[i-1]=vWave[i-1]; }
         else if(d==0) { WaveRange[i]=w; if(i>start) WaveRange[i-1]=vWave[i-1]; }
         else          { WaveDown[i]=w;  if(i>start) WaveDown[i-1]=vWave[i-1]; }
      }
      if(vUp[i]!=EMPTY_VALUE && vUp[i]!=0.0) UpDotBuf[i]=vUp[i];
      if(vDn[i]!=EMPTY_VALUE && vDn[i]!=0.0) DownDotBuf[i]=vDn[i];
   }

   //--- メイン●
   if(InpDrawOnChart)
   {
      color cUp=(color)PlotIndexGetInteger(5,PLOT_LINE_COLOR,0);
      color cDn=(color)PlotIndexGetInteger(6,PLOT_LINE_COLOR,0);
      int lastConf=rates_total-2;
      for(int i=MathMax(start,1);i<=lastConf;i++)
      {
         if(time[i]<=s_lastDone) continue;
         double off=atrW[i]*InpChartOffsetATR;
         if(UpDotBuf[i]!=EMPTY_VALUE)   DrawChartDot(time[i], low[i]-off,  cUp, true);
         if(DownDotBuf[i]!=EMPTY_VALUE) DrawChartDot(time[i], high[i]+off, cDn, false);
      }
      if(lastConf>=0) s_lastDone=time[lastConf];
      ChartRedraw();
   }

   int cur=rates_total-1;
   Comment("DokaKotsu_Wave_Sub(単独計算): OK",
           "\n波[現在]=",DoubleToString(vWave[cur],3),
           "  シグナル=",DoubleToString(vSig[cur],3),
           "  レジーム=",(int)MathRound(vReg[cur]));
   return rates_total;
}
//+------------------------------------------------------------------+
