//+------------------------------------------------------------------+
//| DokaKotsu_MACD_Filter.mq5                                        |
//| MACD線(12,26,14)を「グレーラインの考え方」で色分けする変則MACD    |
//|                                                                    |
//| 通常のMACD(ヒストグラム/シグナルクロス)ではなく、MACD本線そのものの|
//| 傾きだけを見て、上昇/水平(グレー)/下降の3状態に色分けする。       |
//| 既存のWMA34方向インジケーターと同じ「傾き閾値+ヒステリシス」方式: |
//|   点灯しきい値  = InpMacdSlopeTh                                  |
//|   消灯しきい値  = InpMacdSlopeTh × InpMacdStickyMult(既定0.3=粘る)|
//| グレー(水平)は「レンジ・待機」を意味し、エントリー判断には使わない|
//| (この考え方はDokaKotsu本体の長期足/短期足と共通)。                |
//|                                                                    |
//| ※MACD値はシンボル/価格帯によってスケールが変わるため、            |
//|   傾きはATRで正規化してから閾値判定している(本体の他フィルターと  |
//|   同じ考え方)。                                                    |
//|                                                                    |
//|  ■ 追加変更: InpMacdSmoothPeriod(単純移動平均)でMACD本線を         |
//|    平滑化できるようにした。表示・傾き判定の両方に平滑化後の値を   |
//|    使う(1=平滑化なし=生のMACD値のまま)。                          |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property indicator_separate_window
#property indicator_buffers 2
#property indicator_plots   1

#property indicator_label1  "MACD"
#property indicator_type1   DRAW_COLOR_LINE
#property indicator_color1  clrLime, clrRed, clrGray
#property indicator_width1  2

//--- 入力パラメータ
input int    InpFastEMA       = 12;    // MACD短期EMA期間
input int    InpSlowEMA       = 26;    // MACD長期EMA期間
input int    InpSignalPeriod  = 14;    // MACDシグナル期間(本線色分けには未使用。ヒストグラム等の拡張用に保持)
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; // MACD計算に使う価格

input int    InpAtrPeriod     = 14;    // 傾き正規化用ATR期間
input int    InpMacdSmoothPeriod = 3;  // ★MACD本線の平滑化期間(単純移動平均。1=平滑化なし)
input double InpMacdSlopeTh   = 0.05;  // 点灯しきい値(ATR正規化slope。上げるとグレー増)
input double InpMacdStickyMult= 0.3;   // 色の粘り(消灯=点灯×本値。小さいほど色が途切れにくい)
input int    InpMaxBarsBack   = 5000;  // 再計算する過去バー数の上限

//--- バッファ
double BufMacd[];       // MACD本線の値(表示)
double BufColorIdx[];   // 色インデックス(0=上昇/緑 1=下降/赤 2=グレー)

int hMacd = INVALID_HANDLE;
int hAtr  = INVALID_HANDLE;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufMacd,     INDICATOR_DATA);
   SetIndexBuffer(1, BufColorIdx, INDICATOR_COLOR_INDEX);

   hMacd = iMACD(_Symbol, _Period, InpFastEMA, InpSlowEMA, InpSignalPeriod, InpAppliedPrice);
   hAtr  = iATR(_Symbol, _Period, InpAtrPeriod);

   if(hMacd == INVALID_HANDLE || hAtr == INVALID_HANDLE)
   {
      Print("DokaKotsu_MACD_Filter: ハンドル作成に失敗しました");
      return(INIT_FAILED);
   }

   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("DokaKotsu_MACD_Filter(%d,%d,%d)", InpFastEMA, InpSlowEMA, InpSignalPeriod));
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hMacd != INVALID_HANDLE) IndicatorRelease(hMacd);
   if(hAtr  != INVALID_HANDLE) IndicatorRelease(hAtr);
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
   int need = InpSlowEMA + InpSignalPeriod + InpAtrPeriod + 5;
   if(rates_total < need)
      return(0);

   double macdArr[];
   ArraySetAsSeries(macdArr, false);
   if(CopyBuffer(hMacd, 0, 0, rates_total, macdArr) <= 0)
      return(0);

   double atrArr[];
   ArraySetAsSeries(atrArr, false);
   if(CopyBuffer(hAtr, 0, 0, rates_total, atrArr) <= 0)
      return(0);

   int start = 0;
   if(rates_total > InpMaxBarsBack)
      start = rates_total - InpMaxBarsBack;

   int dir = 0;   // 1=上昇/緑 -1=下降/赤 0=グレー(水平・待機)

   int smoothN = MathMax(1, InpMacdSmoothPeriod);

   for(int i = start; i < rates_total; i++)
   {
      // ★平滑化: 直近smoothN本の単純移動平均(1本なら生値のまま)
      double smVal;
      if(smoothN <= 1)
      {
         smVal = macdArr[i];
      }
      else
      {
         int cnt = MathMin(smoothN, i - start + 1);
         double sum = 0.0;
         for(int k = i - cnt + 1; k <= i; k++) sum += macdArr[k];
         smVal = sum / cnt;
      }
      BufMacd[i] = smVal;

      if(i == start || atrArr[i] <= 0.0)
      {
         BufColorIdx[i] = 2;   // 初回/ATR未整備分はグレー扱い
         continue;
      }

      double slope = (smVal - BufMacd[i-1]) / atrArr[i];   // ★平滑化後の値でATR正規化した傾きを見る

      double thOn  = InpMacdSlopeTh;
      double thOff = InpMacdSlopeTh * InpMacdStickyMult;   // ★グレーラインの考え方: 点灯より緩い基準で保持(ちらつき防止)

      if(dir == 1)
         dir = (slope < -thOn) ? -1 : (slope < thOff ? 0 : 1);
      else if(dir == -1)
         dir = (slope >  thOn) ?  1 : (slope > -thOff ? 0 : -1);
      else
         dir = (slope >  thOn) ?  1 : (slope < -thOn ? -1 : 0);

      BufColorIdx[i] = (dir == 1) ? 0 : (dir == -1) ? 1 : 2;   // 0=緑(上昇) 1=赤(下降) 2=グレー(水平・待機)
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
