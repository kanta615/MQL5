//+------------------------------------------------------------------+
//| DokaKotsu_MarketState_Sub.mq5                                    |
//| ★2026-07-10e新規作成: 相場状態(SQ/TR/SP)のサブウィンドウ表示専用。 |
//|   DokaKotsu_indicator_13のbuf57(BufMarketState: 1=SQ/2=TR/3=SP)  |
//|   をiCustomで参照し、■(幅5のヒストグラム)で色分け表示するだけの   |
//|   表示専用インジケーター。判定ロジックは一切持たない(WYSIWYG原則: |
//|   ロジックは全てindicator_13側。ここは色を付けるだけ)。          |
//|                                                                   |
//|   色: SQ=Gray / TR=RGB(34,116,128) / SP=Lime                     |
//|                                                                   |
//|   ★注意: iCustom呼び出しはメイン指標の既定input値を使用する。     |
//|   チャート上のDokaKotsu_indicator_13を既定値から変更して運用して  |
//|   いる場合、このサブ表示とは判定がズレる可能性がある(既存の       |
//|   Wave_Sub/DokaKotsu_HeikinAshi_2と同じ「自己計算/既定値参照」の   |
//|   トレードオフを踏襲)。厳密に一致させたい場合はInpIndicatorParams  |
//|   側の拡張、またはメイン指標側のバッファを直接読む運用に変更する   |
//|   必要がある。                                                    |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.00"
#property description "相場状態(SQ/TR/SP)のサブウィンドウ帯表示。DokaKotsu_indicator_13のbuf57を参照する表示専用インジ。"

#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_width1  5
#property indicator_color1  clrGray, clrYellow, clrLime   // 色インデックス0=SQ,1=TR,2=SP ★2026-07-12: TR色をYellowに変更

input string InpIndicatorName = "DokaKotsu_indicator_13"; // 参照する親指標のファイル名(拡張子なし)

double BufVal[];    // ヒストグラムの値(常に1固定=帯の高さを揃えるだけ)
double BufColor[];  // 色インデックス(0=SQ/1=TR/2=SP)

int hMain = INVALID_HANDLE;

int OnInit()
{
   SetIndexBuffer(0, BufVal,   INDICATOR_DATA);
   SetIndexBuffer(1, BufColor, INDICATOR_COLOR_INDEX);
   ArraySetAsSeries(BufVal,   false);
   ArraySetAsSeries(BufColor, false);

   PlotIndexSetString(0, PLOT_LABEL, "相場状態(SQ/TR/SP)");
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu_MarketState");
   IndicatorSetInteger(INDICATOR_DIGITS, 0);

   // ★親指標(DokaKotsu_indicator_13)をiCustomで参照。既定input値を使用(注意書き参照)。
   hMain = iCustom(_Symbol, _Period, InpIndicatorName);
   if(hMain == INVALID_HANDLE)
   {
      Print("[MarketState_Sub] iCustomハンドル作成失敗。InpIndicatorName=", InpIndicatorName, " を確認してください。");
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

   double state[];
   ArraySetAsSeries(state, false);
   if(CopyBuffer(hMain, 57, 0, rates_total, state) <= 0) return(prev_calculated); // buf57=相場状態

   int start = (prev_calculated > 1) ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++)
   {
      int st = (int)state[i];
      BufVal[i] = 1.0; // 帯の高さは常に一定(色だけで状態を表す)
      switch(st)
      {
         case 1:  BufColor[i] = 0.0; break; // SQ=Gray
         case 3:  BufColor[i] = 2.0; break; // SP=Lime
         default: BufColor[i] = 1.0; break; // TR(既定/未計算含む)=RGB(34,116,128)
      }
   }
   return(rates_total);
}
