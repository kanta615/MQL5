//+------------------------------------------------------------------+
//|                                               DokaKotsu_SpanB_1M_18.mq5 |
//|     一目均衡表のスパンA・スパンBの表示専用(値は本体インジから引用)      |
//+------------------------------------------------------------------+
//| ■ 修正日: 2026-11-09  v2.02  短縮名を DokaKotsu_SpanB_1M_18(ファイル名と同じ)に|
//|   変更。ナビゲーターの「(Dokakotsu_SpanB)」を消した。計算・描画の変更なし。   |
//| ■ 修正日: 2026-11-09  v2.01  世代を揃えた(1M_18)                         |
//|   ファイル名を DokaKotsu_SpanB_1M_18.mq5 に、引用元の既定名を             |
//|   DokaKotsu_indicator_1M_18 に変更(田島さんご指示「SpanBも加えて」)。     |
//|   計算・描画の変更なし。                                                  |
//| ■ 修正日: 2026-11-03  v2.00  数値を持たない表示専用に変更             |
//|   田島さんご指示「一目の値はインジで保管し、このインジは色を変えられる   |
//|   だけで数値は持たず、インジから引用する」。                           |
//|   ・スパンA・スパンBの値と先行させる本数は、チャート上の本体インジ        |
//|     (既定 DokaKotsu_indicator_1M_7)が計算して保管している(バッファ64〜66)。|
//|     このインジはそれを読んで線を描くだけ。期間・先行本数の設定は持たない。|
//|   ・設定できるのは、色・太さ・線の種類・表示/非表示・引用元の名前だけ。   |
//|     スパンB=白(clrWhite) / スパンA=ダークグレー(clrDarkGray)が既定。      |
//|   ・本体インジを入れ替えた時(例 1M_7→1M_8)は、引用元の名前を変える。     |
//|   ・本体インジが同じチャートに無い間は、線を出さず、左上にその旨を出す。   |
//|   (旧 Dokakotsu_SpanAB.mq5 v1.10 は期間を自分で持っていたため廃止)        |
//| ■ 修正日: 2026-11-02  v1.x  スパンBのみ→スパンA・Bを自前計算(廃止)       |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "2.02"
#property description "一目スパンA・Bの表示専用。値は本体インジ(DokaKotsu_indicator)から引用し、色・太さだけ設定する(B=白/A=ダークグレー)"
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

input group "=== 引用元(値を持っている本体インジ。チャートの同じ窓に貼ってあること) ==="
input string InpSourceName = "DokaKotsu_indicator_1M_18";   // 本体インジのチャート上の名前
input group "=== 表示(色・太さ・線の種類だけ。期間・先行本数は本体インジが持つ) ==="
input bool   InpShowSpanA  = true;          // スパンAを表示する
input color  InpColorA     = clrDarkGray;   // スパンAの色(ダークグレー)
input color  InpColorB     = clrWhite;      // スパンBの色(白)
input int    InpWidthA     = 2;             // スパンAの太さ
input int    InpWidthB     = 2;             // スパンBの太さ
input ENUM_LINE_STYLE InpStyleA = STYLE_SOLID;   // スパンAの線の種類
input ENUM_LINE_STYLE InpStyleB = STYLE_SOLID;   // スパンBの線の種類
input bool   InpShowLabel  = true;          // 線の右端に現在値の文字を出す

// 本体インジ(DokaKotsu_indicator)のバッファ番号
#define SRC_BUF_SPAN_A     64
#define SRC_BUF_SPAN_B     65
#define SRC_BUF_SPAN_SHIFT 66

#define SPB_LBL_A "DKSPB_LabelA"
#define SPB_LBL_B "DKSPB_LabelB"
#define SPB_MSG   "DKSPB_Msg"

double BufA[];
double BufB[];
int    g_src   = INVALID_HANDLE;
int    g_shift = -1;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufA, INDICATOR_DATA);
   SetIndexBuffer(1, BufB, INDICATOR_DATA);
   for(int p = 0; p < 2; p++) PlotIndexSetDouble(p, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpColorA);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpColorB);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, MathMax(1, InpWidthA));
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, MathMax(1, InpWidthB));
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, InpStyleA);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, InpStyleB);
   if(!InpShowSpanA) PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu_SpanB_1M_18");   // ★2026-11-09: 短縮名をファイル名と同じにした(ナビゲーターに「(Dokakotsu_SpanB)」が付かないように。田島さんご指示)
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(g_src != INVALID_HANDLE) IndicatorRelease(g_src);
   ObjectDelete(0, SPB_LBL_A);
   ObjectDelete(0, SPB_LBL_B);
   ObjectDelete(0, SPB_MSG);
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

void ShowMsg(const string text)
{
   if(ObjectFind(0, SPB_MSG) < 0)
   {
      ObjectCreate(0, SPB_MSG, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, SPB_MSG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, SPB_MSG, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, SPB_MSG, OBJPROP_YDISTANCE, 40);
      ObjectSetInteger(0, SPB_MSG, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, SPB_MSG, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, SPB_MSG, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, SPB_MSG, OBJPROP_HIDDEN, true);
      ObjectSetString(0, SPB_MSG, OBJPROP_FONT, "Meiryo");
   }
   ObjectSetString(0, SPB_MSG, OBJPROP_TEXT, text);
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
   if(rates_total < 10) return(0);

   // 本体インジ(チャート上のもの。隠れたコピーではない)を探す
   if(g_src == INVALID_HANDLE)
   {
      g_src = ChartIndicatorGet(0, 0, InpSourceName);
      if(g_src == INVALID_HANDLE)
      {
         ShowMsg("Dokakotsu_SpanB: 本体インジ(" + InpSourceName + ")が同じチャートに見つかりません。貼ってから再読込してください。");
         return(prev_calculated);
      }
   }
   ObjectDelete(0, SPB_MSG);

   double a[], b[], sh[];
   ArraySetAsSeries(a, false); ArraySetAsSeries(b, false); ArraySetAsSeries(sh, false);
   int na = CopyBuffer(g_src, SRC_BUF_SPAN_A,     0, rates_total, a);
   int nb = CopyBuffer(g_src, SRC_BUF_SPAN_B,     0, rates_total, b);
   int ns = CopyBuffer(g_src, SRC_BUF_SPAN_SHIFT, 0, rates_total, sh);
   if(na <= 0 || nb <= 0 || ns <= 0)
   {
      IndicatorRelease(g_src);          // 本体インジが再起動した等でハンドルが無効になった。次回また探す
      g_src = INVALID_HANDLE;
      return(prev_calculated);
   }
   int n = MathMin(MathMin(na, nb), MathMin(ns, rates_total));
   int off = rates_total - n;           // 取れた分を、新しい方へ寄せて並べる
   for(int i = 0; i < rates_total; i++)
   {
      if(i < off) { BufA[i] = EMPTY_VALUE; BufB[i] = EMPTY_VALUE; continue; }
      int k = i - off;
      BufA[i] = a[k];
      BufB[i] = b[k];
   }

   // 先へずらす本数も、本体インジから引用する(このインジは数値を持たない)
   int shift = (int)MathRound(sh[n - 1]);
   if(shift < 0) shift = 0;
   if(shift != g_shift)
   {
      PlotIndexSetInteger(0, PLOT_SHIFT, shift);
      PlotIndexSetInteger(1, PLOT_SHIFT, shift);
      g_shift = shift;
   }

   if(InpShowLabel)
   {
      datetime t = time[rates_total - 1] + (datetime)((shift + 3) * PeriodSeconds(_Period));
      double va = BufA[rates_total - 1], vb = BufB[rates_total - 1];
      if(InpShowSpanA && va != EMPTY_VALUE) PutLbl(SPB_LBL_A, t, va, "スパンA " + DoubleToString(va, _Digits), InpColorA);
      if(vb != EMPTY_VALUE)                 PutLbl(SPB_LBL_B, t, vb, "スパンB " + DoubleToString(vb, _Digits), InpColorB);
   }
   return(rates_total);
}
//+------------------------------------------------------------------+
