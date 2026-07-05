//+------------------------------------------------------------------+
//|                                          DokaKotsu_Wave_Sub.mq5   |
//|   ★描画専用★（ロジックは持たない）                              |
//|   本体 DokaKotsu_indicator_9 が計算した波の数値を iCustom で読み、|
//|   サブ窓に描くだけ。色はすべて「カラー」タブで管理。             |
//|     buf20=波 / buf21=シグナル / buf22=レジーム(1/0/-1)            |
//|     buf23=上抜け位置 / buf24=下抜け位置                          |
//|   波線は 上昇/レンジ/下降/単色 ＋ シグナル の5色、●はクロス。   |
//|   メイン●はサブ窓 UpCross/DownCross と同色（カラータブ連動）。   |
//|   ※本体は iCustom 無パラメータ（=コンパイル時の既定値）で読む。 |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "2.00"
#property indicator_separate_window
#property indicator_buffers 7
#property indicator_plots   7

//--- カラータブに出る色（ここが唯一の色設定）
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
#property indicator_color3  clrOrange
#property indicator_width3  2
#property indicator_label4  "Wave単色"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrGreen
#property indicator_width4  2
#property indicator_label5  "Signal"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrMagenta
#property indicator_width5  2
#property indicator_label6  "UpCross"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrLime
#property indicator_label7  "DownCross"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrMagenta

//--- 入力（色は無し。表示のみ。ロジックは本体側）
input bool   InpShowRegime   = true;       // 波線を背景色(上昇/レンジ/下降)で塗る
input bool   InpDrawDots     = true;       // サブ窓に●を表示
input bool   InpDrawOnChart  = true;       // メインチャートにも●を表示
input int    InpDotCode      = 159;        // ●のWingdingsコード（159=丸ドット）
input int    InpDotSize      = 1;          // ●のサイズ（1=小 … 5=大）
input double InpChartOffsetATR = 0.6;      // メイン●のローソクからの離し（ATR倍）
input int    InpMaxBars      = 3000;       // 描画する最大バー数（負荷上限）

//--- バッファ
double WaveUp[];      // plot0 波(上昇)
double WaveRange[];   // plot1 波(レンジ)
double WaveDown[];    // plot2 波(下降)
double WavePlain[];   // plot3 波(単色：レジームOFF時)
double SignalBuf[];   // plot4 シグナル
double UpDotBuf[];    // plot5 上抜け●
double DownDotBuf[];  // plot6 下抜け●

int      hMain  = INVALID_HANDLE;  // 本体インジ（iCustom）
int      hAtr   = INVALID_HANDLE;  // メイン●の離し用ATR
int      g_dotSize = 1;
datetime s_lastDone = 0;

string MainName = "DokaKotsu_indicator_9";  // 本体インジのファイル名（同じ階層に置くこと）

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

   //--- レジームON/OFFで波プロットの有効を切替（色はカラータブのまま）
   PlotIndexSetInteger(0,PLOT_DRAW_TYPE,InpShowRegime?DRAW_LINE:DRAW_NONE);
   PlotIndexSetInteger(1,PLOT_DRAW_TYPE,InpShowRegime?DRAW_LINE:DRAW_NONE);
   PlotIndexSetInteger(2,PLOT_DRAW_TYPE,InpShowRegime?DRAW_LINE:DRAW_NONE);
   PlotIndexSetInteger(3,PLOT_DRAW_TYPE,InpShowRegime?DRAW_NONE:DRAW_LINE);
   for(int p=0;p<4;p++) PlotIndexSetDouble(p,PLOT_EMPTY_VALUE,EMPTY_VALUE);

   //--- ●（コード・サイズはここで。色はカラータブ）
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
   IndicatorSetString(INDICATOR_SHORTNAME,"DokaKotsu_Wave_Sub");

   //--- 本体インジを iCustom で読む（無パラメータ＝本体の既定値）
   hMain=iCustom(_Symbol,_Period,MainName);
   if(hMain==INVALID_HANDLE){ Print("[Wave] 本体 iCustom 失敗: ",MainName); return INIT_FAILED; }
   hAtr =iATR(_Symbol,_Period,14);
   if(hAtr==INVALID_HANDLE){ Print("[Wave] iATR 失敗"); return INIT_FAILED; }

   s_lastDone=0;
   ObjectsDeleteAll(0,"DKWave_");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(hMain!=INVALID_HANDLE) IndicatorRelease(hMain);
   if(hAtr !=INVALID_HANDLE) IndicatorRelease(hAtr);
   ObjectsDeleteAll(0,"DKWave_");
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

   int start=0;
   if(rates_total>InpMaxBars) start=rates_total-InpMaxBars;
   int need=rates_total-start;

   //--- 本体の数値を読む（buf20-24）
   static double vWave[],vSig[],vReg[],vUp[],vDn[],atrW[];
   ArrayResize(vWave,need); ArrayResize(vSig,need); ArrayResize(vReg,need);
   ArrayResize(vUp,need);   ArrayResize(vDn,need);  ArrayResize(atrW,need);
   ArraySetAsSeries(vWave,false); ArraySetAsSeries(vSig,false); ArraySetAsSeries(vReg,false);
   ArraySetAsSeries(vUp,false);   ArraySetAsSeries(vDn,false);  ArraySetAsSeries(atrW,false);
   if(CopyBuffer(hMain,20,0,need,vWave)<need) return prev_calculated;
   if(CopyBuffer(hMain,21,0,need,vSig )<need) return prev_calculated;
   if(CopyBuffer(hMain,22,0,need,vReg )<need) return prev_calculated;
   if(CopyBuffer(hMain,23,0,need,vUp  )<need) return prev_calculated;
   if(CopyBuffer(hMain,24,0,need,vDn  )<need) return prev_calculated;
   if(CopyBuffer(hAtr, 0, 0,need,atrW )<need) return prev_calculated;

   //--- start より前は空
   for(int i=0;i<start;i++)
   {
      WaveUp[i]=EMPTY_VALUE; WaveRange[i]=EMPTY_VALUE; WaveDown[i]=EMPTY_VALUE; WavePlain[i]=EMPTY_VALUE;
      SignalBuf[i]=EMPTY_VALUE; UpDotBuf[i]=EMPTY_VALUE; DownDotBuf[i]=EMPTY_VALUE;
   }

   //--- 波・シグナルを描く（色分けは本体レジーム buf22）
   for(int k=0;k<need;k++)
   {
      int i=start+k;
      double w=vWave[k];
      SignalBuf[i]=vSig[k];

      WaveUp[i]=EMPTY_VALUE; WaveRange[i]=EMPTY_VALUE; WaveDown[i]=EMPTY_VALUE; WavePlain[i]=EMPTY_VALUE;
      UpDotBuf[i]=EMPTY_VALUE; DownDotBuf[i]=EMPTY_VALUE;

      if(!InpShowRegime)
      {
         WavePlain[i]=w; if(i>start) WavePlain[i-1]=vWave[k-1];
      }
      else
      {
         int d=(int)MathRound(vReg[k]);
         if(d==1)      { WaveUp[i]=w;    if(i>start) WaveUp[i-1]=vWave[k-1]; }
         else if(d==0) { WaveRange[i]=w; if(i>start) WaveRange[i-1]=vWave[k-1]; }
         else          { WaveDown[i]=w;  if(i>start) WaveDown[i-1]=vWave[k-1]; }
      }

      //--- ●（本体が出したクロス位置をそのまま採用：確定足のみ＝非リペイント）
      if(vUp[k]!=EMPTY_VALUE && vUp[k]!=0.0) UpDotBuf[i]=vUp[k];
      if(vDn[k]!=EMPTY_VALUE && vDn[k]!=0.0) DownDotBuf[i]=vDn[k];
   }

   //--- メイン●（色はサブ窓 UpCross/DownCross と同色＝カラータブ連動）
   if(InpDrawOnChart)
   {
      color cUp=(color)PlotIndexGetInteger(5,PLOT_LINE_COLOR,0);
      color cDn=(color)PlotIndexGetInteger(6,PLOT_LINE_COLOR,0);
      int lastConf=rates_total-2;
      for(int i=MathMax(start,1);i<=lastConf;i++)
      {
         if(time[i]<=s_lastDone) continue;
         double off=atrW[i-start]*InpChartOffsetATR;
         if(UpDotBuf[i]!=EMPTY_VALUE)   DrawChartDot(time[i], low[i]-off,  cUp, true);
         if(DownDotBuf[i]!=EMPTY_VALUE) DrawChartDot(time[i], high[i]+off, cDn, false);
      }
      if(lastConf>=0) s_lastDone=time[lastConf];
      ChartRedraw();
   }
   return rates_total;
}
//+------------------------------------------------------------------+
