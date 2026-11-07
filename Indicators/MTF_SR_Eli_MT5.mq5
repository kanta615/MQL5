//+------------------------------------------------------------------+
//|                                           MTF_SR_Eli_MT5.mq5     |
//|              #MTF SR (MT4) のMT5移植版: 複数時間足のフラクタルS/R   |
//+------------------------------------------------------------------+
//| ■ 修正日: 2026-11-01  新規(MT4「#MTF SR.mq4」(Eli Hayun, 2006)の移植)|
//|   田島さんご指示「そのままMT5に移植。4時間足を加え、M30は無視」。     |
//|   【元の動き】複数の時間足それぞれで、ウィリアムズのフラクタル        |
//|     (前後2本より高い高値=抵抗/低い安値=支持)の「直近の1本ずつ」を、   |
//|     新しいフラクタルが出るまで引き継いで階段状に表示する。            |
//|   【移植での変更】                                                  |
//|    ・既定の時間足を H4 / H1 / M15 / M5 にした(元は H1/M30/M15/M5。M30は|
//|      使わない)。時間足は4つとも設定で変えられる。                     |
//|    ・元は display_Period_x(表示する/しない)が効かず、全て記号で描画    |
//|      されていた(変数に代入するだけで使われていない)。移植版は効く。    |
//|      線/記号(元の見た目)も選べる。                                   |
//|    ・元のバッファ名(1D/4H/1H/30M)は実際の時間足とずれていたので整理。 |
//|    ・元は、履歴ではフラクタルの足の位置に線が出る(確定の2本前から見える)|
//|      ため、過去の表示が「後から分かる情報」を含んでいた。移植版は既定で |
//|      確定した時点から表示する(InpNoLookAhead=true)。falseで元の動き。  |
//|    ・元のPlay_Soundは使われていなかったため、移植していない。          |
//|    ・チャートの時間足より短い時間足も指定できる(元は丸められていた)。  |
//|    ・右端に「H4 抵抗 4210.50」のように時間足と価格の文字を出せる。      |
//|   【田島さんの現在のプロパティ(スクリーンショット)の再現】              |
//|     元(MT4): H1=赤/青(上下とも) / M30=シエナ(抵抗だけ) / M15=コーン      |
//|     フラワーブルー(支持だけ) / M5=スカイブルー(支持だけ)。他はNone(非表示)|
//|     で、幅は全て0(細線)。入力はPeriod_1〜4=60/30/15/5、表示は全てtrue。 |
//|     →移植版の既定: H1=赤/青 / M15=支持だけ / M5=支持だけ、色なし=非表示。|
//|       M30は使わないので、M30のシエナ(抵抗)の席に、新しく加えたH4を      |
//|       シエナ(抵抗)/ロイヤルブルー(支持)で入れた。幅は全て細線(1)。        |
//|       描画は元のとおり記号(Wingdings 172〜169、時間足ごとに違う記号)。 |
//|       色の入力を clrNONE にすると、その線は表示しない。                 |
//| 元の著作権: Copyright (c) 2006, Eli hayun http://www.elihayun.com        |
//+------------------------------------------------------------------+
#property copyright "Port of #MTF SR.mq4, Copyright 2006 Eli hayun"
#property link      "http://www.elihayun.com"
#property version   "1.01"
#property description "複数の時間足のフラクタル(直近の高値/安値)を階段状に表示するMT4「#MTF SR」のMT5移植版"
#property indicator_chart_window
#property indicator_buffers 8
#property indicator_plots   8

enum ENUM_MSR_STYLE
{
   MSR_LINE = 0,   // 線(階段状)
   MSR_DOTS = 1    // 記号(元のMT4版の見た目)
};

input group "=== 時間足(上から順に太く表示) ==="
input ENUM_TIMEFRAMES InpTf1 = PERIOD_H4;    // 時間足1
input ENUM_TIMEFRAMES InpTf2 = PERIOD_H1;    // 時間足2
input ENUM_TIMEFRAMES InpTf3 = PERIOD_M15;   // 時間足3
input ENUM_TIMEFRAMES InpTf4 = PERIOD_M5;    // 時間足4
input bool InpShow1 = true;                  // 時間足1を表示
input bool InpShow2 = true;                  // 時間足2を表示
input bool InpShow3 = true;                  // 時間足3を表示
input bool InpShow4 = true;                  // 時間足4を表示

input group "=== 色(clrNONE=その線を表示しない)。田島さんの現在の設定を再現 ==="
input color InpColHi1 = clrSienna;          // 時間足1(H4) 抵抗(高値)  ※元のM30の席
input color InpColLo1 = clrRoyalBlue;       // 時間足1(H4) 支持(安値)
input color InpColHi2 = clrRed;             // 時間足2(H1) 抵抗(高値)
input color InpColLo2 = clrBlue;            // 時間足2(H1) 支持(安値)
input color InpColHi3 = clrNONE;            // 時間足3(M15) 抵抗(高値)=非表示
input color InpColLo3 = clrCornflowerBlue;  // 時間足3(M15) 支持(安値)
input color InpColHi4 = clrNONE;            // 時間足4(M5) 抵抗(高値)=非表示
input color InpColLo4 = clrSkyBlue;         // 時間足4(M5) 支持(安値)
input int   InpWidth  = 1;                  // 線の太さ(元は全て0=細線)

input group "=== フラクタル・表示 ==="
input int            InpFractalSide = 2;     // フラクタルの左右の本数(ウィリアムズ標準=2)
input bool           InpNoLookAhead = true;  // true=確定した時点から表示 / false=元の動き(フラクタルの足から)
input ENUM_MSR_STYLE InpStyle       = MSR_DOTS; // 描画: 記号(元のMT4版の見た目) / 線(階段状)
input bool           InpShowLabels  = true;  // 右端に時間足と価格の文字を出す
input int            InpMaxBars     = 5000;  // 計算するチャートの足の本数
input int            InpMaxTfBars   = 20000; // 時間足ごとに読み込む本数の上限

#define MSR_PFX "MSR_"

//--- バッファ(時間足ごとに 高値側=抵抗 / 安値側=支持)
double B0[], B1[], B2[], B3[], B4[], B5[], B6[], B7[];

ENUM_TIMEFRAMES g_tf[4];
bool            g_show[4];
color           g_colHi[4];
color           g_colLo[4];
int             g_width[4];
datetime        g_lastBar = 0;

string TfName(const ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);
   if(StringFind(s, "PERIOD_") == 0) s = StringSubstr(s, 7);
   return s;
}

void PutBuf(const int idx, const double &src[], const int count)
{
   switch(idx)
   {
      case 0: ArrayCopy(B0, src, 0, 0, count); break;
      case 1: ArrayCopy(B1, src, 0, 0, count); break;
      case 2: ArrayCopy(B2, src, 0, 0, count); break;
      case 3: ArrayCopy(B3, src, 0, 0, count); break;
      case 4: ArrayCopy(B4, src, 0, 0, count); break;
      case 5: ArrayCopy(B5, src, 0, 0, count); break;
      case 6: ArrayCopy(B6, src, 0, 0, count); break;
      case 7: ArrayCopy(B7, src, 0, 0, count); break;
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, B0, INDICATOR_DATA);  SetIndexBuffer(1, B1, INDICATOR_DATA);
   SetIndexBuffer(2, B2, INDICATOR_DATA);  SetIndexBuffer(3, B3, INDICATOR_DATA);
   SetIndexBuffer(4, B4, INDICATOR_DATA);  SetIndexBuffer(5, B5, INDICATOR_DATA);
   SetIndexBuffer(6, B6, INDICATOR_DATA);  SetIndexBuffer(7, B7, INDICATOR_DATA);

   g_tf[0] = InpTf1;  g_tf[1] = InpTf2;  g_tf[2] = InpTf3;  g_tf[3] = InpTf4;
   g_show[0] = InpShow1; g_show[1] = InpShow2; g_show[2] = InpShow3; g_show[3] = InpShow4;
   // 色は入力から(田島さんの現在の設定を既定にしている)。clrNONEの線は表示しない
   g_colHi[0] = InpColHi1; g_colLo[0] = InpColLo1;
   g_colHi[1] = InpColHi2; g_colLo[1] = InpColLo2;
   g_colHi[2] = InpColHi3; g_colLo[2] = InpColLo3;
   g_colHi[3] = InpColHi4; g_colLo[3] = InpColLo4;
   for(int w = 0; w < 4; w++) g_width[w] = MathMax(1, InpWidth);

   for(int k = 0; k < 4; k++)
   {
      for(int s = 0; s < 2; s++)
      {
         int p = 2 * k + s;
         string nm = TfName(g_tf[k]) + (s == 0 ? " 抵抗(高値)" : " 支持(安値)");
         PlotIndexSetString(p, PLOT_LABEL, nm);
         PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);
         color lc = (s == 0) ? g_colHi[k] : g_colLo[k];
         PlotIndexSetInteger(p, PLOT_LINE_COLOR, lc);
         PlotIndexSetInteger(p, PLOT_LINE_WIDTH, g_width[k]);
         if(!g_show[k] || lc == clrNONE)
            PlotIndexSetInteger(p, PLOT_DRAW_TYPE, DRAW_NONE);
         else if(InpStyle == MSR_DOTS)
         {
            PlotIndexSetInteger(p, PLOT_DRAW_TYPE, DRAW_ARROW);
            PlotIndexSetInteger(p, PLOT_ARROW, 172 - k);     // 元のMT4版: 時間足ごとに記号172〜169
         }
         else
            PlotIndexSetInteger(p, PLOT_DRAW_TYPE, DRAW_LINE);
      }
   }
   IndicatorSetString(INDICATOR_SHORTNAME, "MTF_SR_Eli_MT5");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, MSR_PFX);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 1つの時間足: フラクタルを探し、チャートの足ごとに「直近の高値/安値」を決める |
//+------------------------------------------------------------------+
bool CalcTf(const int k, const int rates_total, const datetime &time[], const int first,
            double &outH[], double &outL[], double &lastH, double &lastL)
{
   ENUM_TIMEFRAMES tf = g_tf[k];
   int tfSec    = PeriodSeconds(tf);
   int chartSec = PeriodSeconds(_Period);
   if(tfSec <= 0 || chartSec <= 0) return false;
   int side = MathMax(1, InpFractalSide);

   // チャートの表示範囲をカバーするのに必要な、その時間足の本数
   double spanSec = (double)(time[rates_total - 1] - time[first]) + chartSec;
   int want = (int)(spanSec / tfSec) + 2 * side + 40;
   want = MathMin(want, MathMax(100, InpMaxTfBars));
   int avail = Bars(_Symbol, tf);
   if(avail < 2 * side + 10) return false;
   if(want > avail) want = avail;

   MqlRates rr[];
   ArraySetAsSeries(rr, false);
   int got = CopyRates(_Symbol, tf, 0, want, rr);
   if(got < 2 * side + 10) return false;

   // フラクタル(最後の足は形成中なので、j+side が最後の確定足(got-2)以下のものだけ)
   datetime evHT[]; double evHP[]; int nh = 0;
   datetime evLT[]; double evLP[]; int nl = 0;
   for(int j = side; j <= got - 2 - side; j++)
   {
      bool isH = true, isL = true;
      for(int t = 1; t <= side; t++)
      {
         if(!(rr[j].high > rr[j - t].high && rr[j].high > rr[j + t].high)) isH = false;
         if(!(rr[j].low  < rr[j - t].low  && rr[j].low  < rr[j + t].low))  isL = false;
      }
      if(!isH && !isL) continue;
      // 表示を始める時刻: 確定した足が閉じた時(既定) / フラクタルの足の時刻(元のMT4の動き)
      datetime act = InpNoLookAhead ? (rr[j + side].time + (datetime)tfSec) : rr[j].time;
      if(isH) { ArrayResize(evHT, nh + 1); ArrayResize(evHP, nh + 1); evHT[nh] = act; evHP[nh] = rr[j].high; nh++; }
      if(isL) { ArrayResize(evLT, nl + 1); ArrayResize(evLP, nl + 1); evLT[nl] = act; evLP[nl] = rr[j].low;  nl++; }
   }

   // チャートの足を古い方から進め、その足が閉じる時点までに有効になった最新のフラクタルを引き継ぐ
   int ph = 0, pl = 0;
   double curH = EMPTY_VALUE, curL = EMPTY_VALUE;
   for(int i = 0; i < first; i++) { outH[i] = EMPTY_VALUE; outL[i] = EMPTY_VALUE; }
   // first より前に有効になっていた分を先に消化
   datetime t0 = time[first] + (datetime)chartSec;
   for(int i = first; i < rates_total; i++)
   {
      datetime closeT = time[i] + (datetime)chartSec;
      while(ph < nh && evHT[ph] <= closeT) { curH = evHP[ph]; ph++; }
      while(pl < nl && evLT[pl] <= closeT) { curL = evLP[pl]; pl++; }
      outH[i] = curH;
      outL[i] = curL;
   }
   lastH = curH;
   lastL = curL;
   return true;
}

void PutLabelText(const string name, const datetime t, const double p, const string text, const color col)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, "Meiryo");
   }
   ObjectSetInteger(0, name, OBJPROP_TIME, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE, p);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
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
   if(rates_total < 50) return(0);
   // チャートの足が新しくなった時だけ再計算(フラクタルは足が閉じた時にしか増えない)
   datetime lastBar = time[rates_total - 1];
   if(prev_calculated > 0 && lastBar == g_lastBar) return(rates_total);

   int first = MathMax(0, rates_total - MathMax(100, InpMaxBars));
   double tmpH[], tmpL[];
   ArrayResize(tmpH, rates_total);
   ArrayResize(tmpL, rates_total);

   // 全バッファを空にする
   double emptyArr[];
   ArrayResize(emptyArr, rates_total);
   ArrayInitialize(emptyArr, EMPTY_VALUE);
   for(int p = 0; p < 8; p++) PutBuf(p, emptyArr, rates_total);

   ObjectsDeleteAll(0, MSR_PFX);
   datetime tLabel = lastBar + (datetime)(2 * PeriodSeconds(_Period));
   for(int k = 0; k < 4; k++)
   {
      if(!g_show[k]) continue;
      double lh = EMPTY_VALUE, ll = EMPTY_VALUE;
      if(!CalcTf(k, rates_total, time, first, tmpH, tmpL, lh, ll)) continue;
      PutBuf(2 * k,     tmpH, rates_total);
      PutBuf(2 * k + 1, tmpL, rates_total);
      if(InpShowLabels)
      {
         string tf = TfName(g_tf[k]);
         if(lh != EMPTY_VALUE && g_colHi[k] != clrNONE) PutLabelText(MSR_PFX + "L" + IntegerToString(k) + "H", tLabel, lh, tf + " 抵抗 " + DoubleToString(lh, _Digits), g_colHi[k]);
         if(ll != EMPTY_VALUE && g_colLo[k] != clrNONE) PutLabelText(MSR_PFX + "L" + IntegerToString(k) + "L", tLabel, ll, tf + " 支持 " + DoubleToString(ll, _Digits), g_colLo[k]);
      }
   }
   g_lastBar = lastBar;
   ChartRedraw(0);
   return(rates_total);
}
//+------------------------------------------------------------------+
