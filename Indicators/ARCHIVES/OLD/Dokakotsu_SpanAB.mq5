//+------------------------------------------------------------------+
//|                                             Dokakotsu_SpanAB.mq5 |
//|              一目均衡表の「先行スパンA」と「先行スパンB」だけを表示 |
//+------------------------------------------------------------------+
//| ■ 修正日: 2026-11-02(2回目)  v1.10  スパンAを追加・色を指定           |
//|   田島さんご要望「スパンAも出せますか。色はスパンBが白、スパンAが      |
//|   ダークグレー」。                                                 |
//|   ・先行スパンA = (転換線 + 基準線) ÷ 2 を先へずらして表示。            |
//|       転換線 = 期間内の(最高値+最安値)÷2(標準9本)                   |
//|       基準線 = 同(標準26本)                                         |
//|   ・先行スパンB = 期間内(標準52本)の(最高値+最安値)÷2 を先へずらす。  |
//|   ・5分足で見る前提で、1分足の数値を ×5 にしてある:                   |
//|       転換線 9→45本 / 基準線 26→130本 / スパンB 52→260本 / 先行 26→130本|
//|       (いずれも設定で変更できる。5分足の足の切れ目では5分足の値と一致)|
//|   ・色: スパンB=白(clrWhite) / スパンA=ダークグレー(clrDarkGray)。      |
//|       ※MT5の「DarkGray」は 169,169,169。もっと暗くしたい時は          |
//|         clrDimGray(105,105,105)などに変える。                         |
//|   ・基準線・転換線・遅行線・雲の塗りつぶしは出さない(スパンA・Bの線のみ)。|
//|   ・スパンAを消したい時は InpShowSpanA=false。                         |
//| ■ 修正日: 2026-11-02  v1.00  新規作成(Dokakotsu_SpanB.mq5=スパンBのみ)  |
//|   先行スパンBだけを表示(期間52→260・先行26→130の×5)。                |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.10"
#property description "一目均衡表の先行スパンA・Bだけを表示(1分足で、5分足で見る前提に数値を5倍。B=白/A=ダークグレー)"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2
#property indicator_label1  "先行スパンA"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDarkGray
#property indicator_width1  2
#property indicator_label2  "先行スパンB"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrWhite
#property indicator_width2  2

input group "=== 期間(標準=転換9・基準26・スパンB52・先行26。5分足で見る前提で×5に拡大) ==="
input int   InpTenkan  = 45;            // 転換線の期間(本)。標準9 → ×5=45
input int   InpKijun   = 130;           // 基準線の期間(本)。標準26 → ×5=130
input int   InpSpanB   = 260;           // スパンBの期間(本)。標準52 → ×5=260
input int   InpShift   = 130;           // 先に表示する本数。標準26 → ×5=130
input group "=== 表示 ==="
input bool  InpShowSpanA = true;        // 先行スパンAを表示する
input color InpColorA  = clrDarkGray;   // スパンAの色(ダークグレー)
input color InpColorB  = clrWhite;      // スパンBの色(白)
input int   InpWidthA  = 2;             // スパンAの太さ
input int   InpWidthB  = 2;             // スパンBの太さ
input ENUM_LINE_STYLE InpStyleA = STYLE_SOLID; // スパンAの線の種類
input ENUM_LINE_STYLE InpStyleB = STYLE_SOLID; // スパンBの線の種類
input bool  InpShowLabel = true;        // 線の右端に現在値の文字を出す

#define SPAB_LBL_A "DKSPAB_LabelA"
#define SPAB_LBL_B "DKSPAB_LabelB"

double BufA[];
double BufB[];

//+------------------------------------------------------------------+
int OnInit()
{
   if(InpTenkan < 2 || InpKijun < 2 || InpSpanB < 2)
   {
      Print("[SpanAB] 期間(InpTenkan/InpKijun/InpSpanB)は2以上にしてください");
      return(INIT_PARAMETERS_INCORRECT);
   }
   SetIndexBuffer(0, BufA, INDICATOR_DATA);
   SetIndexBuffer(1, BufB, INDICATOR_DATA);
   int sh = MathMax(0, InpShift);
   for(int p = 0; p < 2; p++)
   {
      PlotIndexSetInteger(p, PLOT_SHIFT, sh);
      PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   }
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, MathMax(InpKijun, InpTenkan) - 1);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, InpSpanB - 1);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorA);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorB);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, MathMax(1, InpWidthA));
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, MathMax(1, InpWidthB));
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleA);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleB);
   if(!InpShowSpanA) PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
   PlotIndexSetString(0, PLOT_LABEL, "先行スパンA(" + IntegerToString(InpTenkan) + "/" + IntegerToString(InpKijun) + ")");
   PlotIndexSetString(1, PLOT_LABEL, "先行スパンB(" + IntegerToString(InpSpanB) + ")");
   IndicatorSetString(INDICATOR_SHORTNAME, "Dokakotsu_SpanAB(" + IntegerToString(InpTenkan) + "," + IntegerToString(InpKijun) + "," +
                      IntegerToString(InpSpanB) + "," + IntegerToString(InpShift) + ")");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectDelete(0, SPAB_LBL_A);
   ObjectDelete(0, SPAB_LBL_B);
}

// 現在の足を含めて period 本の (最高値+最安値)/2
double MidPrice(const int i, const int period, const double &high[], const double &low[])
{
   double hh = high[i];
   double ll = low[i];
   for(int k = 1; k < period; k++)
   {
      if(high[i - k] > hh) hh = high[i - k];
      if(low[i - k]  < ll) ll = low[i - k];
   }
   return (hh + ll) / 2.0;
}

void PutLbl(const string name, const datetime t, const double v, const string text, const color col)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TEXT, 0, t, v);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, "Meiryo");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   }
   ObjectSetInteger(0, name, OBJPROP_TIME, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE, v);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
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
   int need = MathMax(InpSpanB, MathMax(InpKijun, InpTenkan));
   if(rates_total < need) return(0);
   int firstA = MathMax(InpKijun, InpTenkan) - 1;   // スパンAが計算できる最初の足
   int firstB = InpSpanB - 1;                        // スパンBが計算できる最初の足

   // 初回は全部、2回目以降は最後の足だけ計算し直す(足の途中で高値・安値が動くため)
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++)
   {
      if(i >= firstA)
      {
         double tenkan = MidPrice(i, InpTenkan, high, low);
         double kijun  = MidPrice(i, InpKijun,  high, low);
         BufA[i] = (tenkan + kijun) / 2.0;
      }
      else BufA[i] = EMPTY_VALUE;
      BufB[i] = (i >= firstB) ? MidPrice(i, InpSpanB, high, low) : EMPTY_VALUE;
   }

   if(InpShowLabel)
   {
      datetime t = time[rates_total - 1] + (datetime)((MathMax(0, InpShift) + 3) * PeriodSeconds(_Period));
      double a = BufA[rates_total - 1], b = BufB[rates_total - 1];
      if(InpShowSpanA && a != EMPTY_VALUE) PutLbl(SPAB_LBL_A, t, a, "スパンA " + DoubleToString(a, _Digits), InpColorA);
      if(b != EMPTY_VALUE)                 PutLbl(SPAB_LBL_B, t, b, "スパンB " + DoubleToString(b, _Digits), InpColorB);
   }
   return(rates_total);
}
//+------------------------------------------------------------------+
