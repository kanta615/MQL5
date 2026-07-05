//+------------------------------------------------------------------+
//|                              DokaKotsu_HeikinAshi.mq5            |
//|   平滑化平均足(Smoothed Heikin Ashi) ※表示専用                   |
//|                                                                  |
//|  ■■ 設計方針(2026-06-25) ■■                                    |
//|    平均足の数値は このインジでは一切計算しない。                 |
//|    本体インジ DokaKotsu_indicator_9 が後平滑化まで済ませた        |
//|    平均足OHLC(buf16-19)を iCustom で参照して描画するだけ。       |
//|    → 「見ている平均足」=「決済判定に使う平均足」が完全一致する。  |
//|       前/後平滑の期間・方式は本体インジ側が唯一の真実(単一の値)。 |
//|    変更できるのは 陽線・陰線の色 のみ。                          |
//|                                                                  |
//|  参照バッファ(本体インジ DokaKotsu_indicator_9):               |
//|    16=平均足 始値 / 17=高値 / 18=安値 / 19=終値(いずれも後平滑後) |
//|    色は (終値>=始値)?陽:陰 で判定(本体の haColor と同一規則)。   |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "2.10"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1

//--- 平均足キャンドル(4値: Open High Low Close)＋色
#property indicator_label1  "DokaKotsu HA"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrMediumSeaGreen, clrOrange
#property indicator_width1  1

//=== 入力(色だけ。数値は本体インジが保持) =========================
input string InpSourceIndicator = "DokaKotsu_indicator_10"; // 参照する本体インジ名(既定_10。_9を使うなら変更。サブフォルダは "フォルダ\\名")
input color  InpBullColor       = clrMediumSeaGreen;       // 陽線(上昇)の色
input color  InpBearColor       = clrOrange;               // 陰線(下降)の色

//=== バッファ(本体インジの値を受けるだけ) =========================
double BufOpen[];
double BufHigh[];
double BufLow[];
double BufClose[];
double BufColor[];   // 0=陽線 / 1=陰線

//=== 本体インジのハンドル =========================================
int g_src = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufOpen,  INDICATOR_DATA);
   SetIndexBuffer(1, BufHigh,  INDICATOR_DATA);
   SetIndexBuffer(2, BufLow,   INDICATOR_DATA);
   SetIndexBuffer(3, BufClose, INDICATOR_DATA);
   SetIndexBuffer(4, BufColor, INDICATOR_COLOR_INDEX);

   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpBullColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpBearColor);
   PlotIndexSetDouble (0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // 本体インジ(既定設定=前3/後5 SMMA)の平均足OHLCを参照するハンドル。
   //   ※パラメータを渡さない=本体インジの既定値を使用。
   //     本体側で前/後平滑を既定から変えた場合は表示もズレるので、変えるなら両方そろえること。
   g_src = iCustom(_Symbol, _Period, InpSourceIndicator);
   if(g_src == INVALID_HANDLE)
   {
      Print("DokaKotsu_HeikinAshi: 本体インジのハンドル取得に失敗 -> ", InpSourceIndicator,
            " (同じIndicatorsフォルダに置くか、入力でパスを指定してください)");
      return(INIT_FAILED);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu HA (本体参照)");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_src != INVALID_HANDLE) IndicatorRelease(g_src);
   g_src = INVALID_HANDLE;
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
   if(rates_total < 5) return(0);

   if(g_src == INVALID_HANDLE)
   {
      g_src = iCustom(_Symbol, _Period, InpSourceIndicator);
      if(g_src == INVALID_HANDLE) return(0);
   }

   // 本体インジの計算が追いつくまで待つ(まだなら次ティックで再試行)
   static int s_warn = -1;
   int calc = BarsCalculated(g_src);
   if(calc < rates_total)
   {
      if(s_warn != 1){ Print("DokaKotsu_HeikinAshi: 本体[",InpSourceIndicator,"]計算待ち BarsCalculated=",calc," / ",rates_total); s_warn=1; }
      return(prev_calculated);
   }

   // 本体インジの平均足OHLC(buf16-19)をそのまま受け取る(計算はしない)
   int r16=CopyBuffer(g_src,16,0,rates_total,BufOpen);
   int r17=CopyBuffer(g_src,17,0,rates_total,BufHigh);
   int r18=CopyBuffer(g_src,18,0,rates_total,BufLow);
   int r19=CopyBuffer(g_src,19,0,rates_total,BufClose);
   if(r16<=0||r17<=0||r18<=0||r19<=0)
   {
      if(s_warn != 2){ Print("DokaKotsu_HeikinAshi: buf16-19読取失敗 r16=",r16," r17=",r17," r18=",r18," r19=",r19," → 本体[",InpSourceIndicator,"]が平均足バッファ付きでコンパイル済みか確認"); s_warn=2; }
      return(prev_calculated);
   }
   if(s_warn != 0){ Print("DokaKotsu_HeikinAshi: 描画OK 本体[",InpSourceIndicator,"] BarsCalculated=",calc); s_warn=0; }

   // 色だけ判定(本体インジの haColor と同一規則: 終値>=始値 で陽線)
   for(int i=0; i<rates_total; i++)
      BufColor[i] = (BufClose[i] >= BufOpen[i]) ? 0.0 : 1.0; // 0=陽線 / 1=陰線

   return(rates_total);
}
//+------------------------------------------------------------------+
