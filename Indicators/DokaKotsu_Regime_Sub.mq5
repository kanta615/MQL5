//+------------------------------------------------------------------+
//| DokaKotsu_Regime_Sub.mq5                                         |
//| ★2026-07-12新規作成: BB×KCレジーム(圧縮/解放)のサブウィンドウ表示専用。|
//|   DokaKotsu_indicator_14のbuf53(BufRegime: 0=トレンド/1=スクイーズ)|
//|   とbuf58(BufRegimeRatio: BB/KC圧縮比率。1.0未満=圧縮/1.0以上=解放)|
//|   をiCustomで参照し、                                             |
//|     ①上段: 色分け帯(■)でレンジ(圧縮)がどこからどこまで続いたかを |
//|       一目で表示(Gray=圧縮中/RGB(34,116,128)=解放=トレンド側)。 |
//|     ②下段: 圧縮比率の折れ線+基準線1.0(この線を上に抜けた瞬間が   |
//|       解放=トレンドへの切り替わり点)。                           |
//|   判定ロジックは一切持たない表示専用インジケーター(WYSIWYG原則:  |
//|   ロジックは全てindicator_14側。ここは色と線を付けるだけ)。      |
//|                                                                   |
//|   ★注意: iCustom呼び出しはメイン指標の既定input値を使用する。     |
//|   チャート上のDokaKotsu_indicator_14を既定値から変更して運用して  |
//|   いる場合、このサブ表示とは判定がズレる可能性がある(既存の       |
//|   MarketState_Sub/Wave_Subと同じ「自己計算/既定値参照」の         |
//|   トレードオフを踏襲)。                                          |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.00"
#property description "BB×KCレジーム(圧縮/解放)のサブウィンドウ表示。DokaKotsu_indicator_14のbuf53/buf58を参照する表示専用インジ。"

#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2

#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_width1  5
#property indicator_color1  clrGray, C'34,116,128'   // 色インデックス0=圧縮(SQ)/1=解放(TR)

#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_width2  1
#property indicator_label2  "BB/KC圧縮比率"

input string InpIndicatorName = "DokaKotsu_indicator_14"; // 参照する親指標のファイル名(拡張子なし)

double BufVal[];     // ヒストグラムの値(常に1固定=帯の高さを揃えるだけ)
double BufColor[];   // 色インデックス(0=圧縮/1=解放)
double BufRatio[];   // BB/KC圧縮比率(1.0=基準線。これを上に抜けた瞬間が解放)

int hMain = INVALID_HANDLE;

int OnInit()
{
   SetIndexBuffer(0, BufVal,   INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, BufRatio, INDICATOR_DATA);
   ArraySetAsSeries(BufVal,   false);
   ArraySetAsSeries(BufColor, false);
   ArraySetAsSeries(BufRatio, false);

   PlotIndexSetString(0, PLOT_LABEL, "BB×KCレジーム(圧縮/解放)");
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu_Regime");
   IndicatorSetInteger(INDICATOR_DIGITS, 3);

   // ★基準線1.0を明示する水平線レベル(この線を上に抜けた瞬間が圧縮解除=トレンド)
   IndicatorSetInteger(INDICATOR_LEVELS, 1);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, 1.0);
   IndicatorSetString(INDICATOR_LEVELTEXT, 0, "解放ライン(1.0)");
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrDimGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);

   // ★親指標(DokaKotsu_indicator_14)をiCustomで参照。既定input値を使用(注意書き参照)。
   hMain = iCustom(_Symbol, _Period, InpIndicatorName);
   if(hMain == INVALID_HANDLE)
   {
      Print("[Regime_Sub] iCustomハンドル作成失敗。InpIndicatorName=", InpIndicatorName, " を確認してください。");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   if(hMain != INVALID_HANDLE) IndicatorRelease(hMain);
}

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
   if(BarsCalculated(hMain) < rates_total) return(prev_calculated); // 親指標がまだ計算中

   double regime[];
   double ratio[];
   ArraySetAsSeries(regime, false);
   ArraySetAsSeries(ratio,  false);
   if(CopyBuffer(hMain, 53, 0, rates_total, regime) <= 0) return(prev_calculated); // buf53=レジーム0/1
   if(CopyBuffer(hMain, 58, 0, rates_total, ratio)  <= 0) return(prev_calculated); // buf58=圧縮比率

   int start = (prev_calculated > 1) ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++)
   {
      bool isSqueeze = (regime[i] >= 0.5);
      BufVal[i]   = 1.0;                          // 帯の高さは常に一定(色だけで状態を表す)
      BufColor[i] = isSqueeze ? 0.0 : 1.0;         // 0=圧縮(Gray)/1=解放(RGB(34,116,128))
      BufRatio[i] = ratio[i];                      // 1.0未満=圧縮/1.0以上=解放
   }
   return(rates_total);
}
