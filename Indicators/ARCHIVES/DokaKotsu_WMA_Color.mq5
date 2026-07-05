//+------------------------------------------------------------------+
//|                                    DokaKotsu_WMA_Color.mq5        |
//|   WMA14 を傾き(slope)で色分け表示する参考用インジケーター        |
//|     上昇(slope>+th)=緑 / 下降(slope<-th)=オレンジ / 平行=グレー  |
//|   ※slope は T2.1 と同じ「ATR正規化したWMA14の1本差」            |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   3

//--- 上昇(緑)
#property indicator_label1  "WMA_UP"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrLime
#property indicator_width1  2
//--- 下降(オレンジ)
#property indicator_label2  "WMA_DOWN"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrOrange
#property indicator_width2  2
//--- 平行(グレー)
#property indicator_label3  "WMA_FLAT"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrGray
#property indicator_width3  2

//=== 入力パラメータ ==============================================
input int    InpWmaPeriod = 14;    // WMA期間（T2.1の方向判定の主役）
input double InpSlopeTh    = 0.10;  // 色分けしきい値（|slope|>これで上昇/下降、以内は平行）

//=== バッファ ====================================================
double BufUp[];    // 上昇区間のWMA値
double BufDown[];  // 下降区間のWMA値
double BufFlat[];  // 平行区間のWMA値
double BufWma[];   // WMA生値（内部計算用）

int hWMA, hATR;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufUp,   INDICATOR_DATA);
   SetIndexBuffer(1, BufDown, INDICATOR_DATA);
   SetIndexBuffer(2, BufFlat, INDICATOR_DATA);
   SetIndexBuffer(3, BufWma,  INDICATOR_CALCULATIONS);
   // 色の途切れを線でつなぐため EMPTY を空に
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   hWMA = iMA(_Symbol, _Period, InpWmaPeriod, 0, MODE_LWMA, PRICE_CLOSE);
   hATR = iATR(_Symbol, _Period, 14);
   if(hWMA==INVALID_HANDLE || hATR==INVALID_HANDLE)
   {
      Print("ハンドル作成失敗");
      return(INIT_FAILED);
   }
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu WMA Color");
   return(INIT_SUCCEEDED);
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
   int need = InpWmaPeriod + 20;
   if(rates_total < need) return(0);

   double wma[], atr[];
   if(CopyBuffer(hWMA,0,0,rates_total,wma)<=0) return(prev_calculated);
   if(CopyBuffer(hATR,0,0,rates_total,atr)<=0) return(prev_calculated);
   ArraySetAsSeries(wma,false);
   ArraySetAsSeries(atr,false);

   int start = (prev_calculated>1)? prev_calculated-1 : need;
   for(int i=start; i<rates_total; i++)
   {
      BufUp[i]=EMPTY_VALUE; BufDown[i]=EMPTY_VALUE; BufFlat[i]=EMPTY_VALUE;
      BufWma[i]=wma[i];
      if(i<need || atr[i]<=0) continue;

      // slope = ATR正規化した WMA の1本差（T2.1と同じ）
      double slope = (wma[i]-wma[i-1])/atr[i];

      // 区間が途切れないよう、前の足の値も同じバッファに入れて線をつなぐ
      if(slope > InpSlopeTh)
      {
         BufUp[i]=wma[i];   BufUp[i-1]=wma[i-1];
      }
      else if(slope < -InpSlopeTh)
      {
         BufDown[i]=wma[i]; BufDown[i-1]=wma[i-1];
      }
      else
      {
         BufFlat[i]=wma[i]; BufFlat[i-1]=wma[i-1];
      }
   }
   return(rates_total);
}
//+------------------------------------------------------------------+
