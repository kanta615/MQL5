//+------------------------------------------------------------------+
//| DokaKotsu_RSI_Filter.mq5                                          |
//| RSIフィルター(旧名: DokaKotsu_OikakeKinshi / NoChase_Filter)        |
//|                                                                    |
//| RSI2ラインをグレーで表示。                                        |
//| 買われすぎ(RSI2 > InpRSIOverbought)/売られすぎ(RSI2 < InpRSIOversold)|
//| に入ったかどうかを、DokaKotsu_Trend_Filterと同じ方式で、           |
//| RSI線とは別に下部の■(塗りつぶし正方形)の色で表示する。            |
//|   ■グレー = 通常(買われすぎ/売られすぎのどちらでもない)           |
//|   ■青     = 買われすぎ(新規買い注意)                              |
//|   ■赤     = 売られすぎ(新規売り注意)                              |
//|                                                                    |
//| ★2026-07-09変更: ①名称をDokaKotsu_RSI_Filterに変更                |
//|   ②矢印(BuyKinshi/SellKinshi)は削除。RSI線のみ残し色をグレーに    |
//|   ③状態表示をTrend_Filterと同じ「下部■」方式に変更                |
//|   あわせてEMA/ATR/BB(前バージョンで判定に未使用だった計算)は       |
//|   完全に削除してシンプル化した。                                   |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.00"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   2
#property indicator_minimum 0
#property indicator_maximum 100
#property indicator_level1  90
#property indicator_level2  10
#property indicator_levelcolor clrGray
#property indicator_levelstyle STYLE_DOT

//--- Plot 1 : RSI2 ライン
#property indicator_label1  "RSI2"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGray
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 2 : 状態(下部の■。Trend_Filterと同じ方式)
#property indicator_label2  "RSIState"
#property indicator_type2   DRAW_COLOR_ARROW
#property indicator_color2  clrGray, clrDodgerBlue, clrRed
#property indicator_width2  5

//--- 入力パラメータ
input int    InpRSIPeriod      = 2;      // RSI期間
input double InpRSIOverbought  = 90.0;   // RSI買われすぎ閾値
input double InpRSIOversold    = 10.0;   // RSI売られすぎ閾値
input bool   InpShowLabel      = true;   // チャート上にステータスラベルを表示
input bool   InpShowRSILine    = true;   // ★2026-07-09追加: RSI2ラインを表示する(falseで非表示)
input ENUM_BASE_CORNER InpLabelCorner = CORNER_LEFT_UPPER; // ラベル表示位置

//--- バッファ
double BufRSI[];
double BufState[];       // 常に0.0(下端に固定表示)。状態は BufStateColor で区別する
double BufStateColor[];  // 0=灰(通常) 1=赤(買われすぎ) 2=青(売られすぎ)

int hRSI = INVALID_HANDLE;

//--- ラベルオブジェクト名
string LabelName = "DokaKotsu_RSI_Filter_Label";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufRSI,       INDICATOR_DATA);
   SetIndexBuffer(1, BufState,     INDICATOR_DATA);
   SetIndexBuffer(2, BufStateColor,INDICATOR_COLOR_INDEX);

   ArraySetAsSeries(BufRSI, false);
   ArraySetAsSeries(BufState, false);
   ArraySetAsSeries(BufStateColor, false);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);   // ★2026-07-09追加: RSI線非表示トグル用
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetInteger(1, PLOT_ARROW, 110);   // Wingdings: 塗りつぶし正方形(■)

   hRSI = iRSI(_Symbol, _Period, InpRSIPeriod, PRICE_CLOSE);

   if(hRSI == INVALID_HANDLE)
     {
      Print("DokaKotsu_RSI_Filter: RSIハンドルの作成に失敗しました");
      return(INIT_FAILED);
     }

   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu_RSI_Filter");
   IndicatorSetInteger(INDICATOR_DIGITS, 2);

   if(InpShowLabel)
     {
      if(ObjectFind(0, LabelName) < 0)
         ObjectCreate(0, LabelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, LabelName, OBJPROP_CORNER, InpLabelCorner);
      ObjectSetInteger(0, LabelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, LabelName, OBJPROP_YDISTANCE, 15);
      ObjectSetInteger(0, LabelName, OBJPROP_FONTSIZE, 11);
      ObjectSetString(0, LabelName, OBJPROP_FONT, "MS Gothic");
      ObjectSetInteger(0, LabelName, OBJPROP_COLOR, clrWhite);
      ObjectSetString(0, LabelName, OBJPROP_TEXT, "DokaKotsu RSI Filter 初期化中...");
     }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(InpShowLabel)
      ObjectDelete(0, LabelName);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
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
   int min_bars = InpRSIPeriod + 2;
   if(rates_total < min_bars)
      return(0);

   double rsiBuf[];
   if(CopyBuffer(hRSI, 0, 0, rates_total, rsiBuf) <= 0) return(0);
   ArraySetAsSeries(rsiBuf, false);

   int start = (prev_calculated > 1) ? prev_calculated - 1 : min_bars;

   for(int i = start; i < rates_total; i++)
     {
      double rsi = rsiBuf[i];

      BufRSI[i]   = InpShowRSILine ? rsi : EMPTY_VALUE;   // ★2026-07-09追加: falseならライン非表示(状態判定には影響しない)
      BufState[i] = 0.0;   // ★常に下端(0)固定表示。色だけで状態を区別する(Trend_Filterと同方式)

      if(rsi > InpRSIOverbought)
         BufStateColor[i] = 1.0;   // 赤=買われすぎ
      else if(rsi < InpRSIOversold)
         BufStateColor[i] = 2.0;   // 青=売られすぎ
      else
         BufStateColor[i] = 0.0;   // 灰=通常
     }

   //--- 最新バーの状態をチャートラベルへ反映
   if(InpShowLabel && rates_total > 0)
     {
      int last = rates_total - 1;
      string txt;
      color  col;

      if(BufStateColor[last] == 1.0)
        {
         txt = "⚠ 買われすぎ (RSI2:" + DoubleToString(rsiBuf[last],1) + ")";
         col = clrDodgerBlue;
        }
      else if(BufStateColor[last] == 2.0)
        {
         txt = "⚠ 売られすぎ (RSI2:" + DoubleToString(rsiBuf[last],1) + ")";
         col = clrRed;
        }
      else
        {
         txt = "通常範囲 (RSI2:" + DoubleToString(rsiBuf[last],1) + ")";
         col = clrGray;
        }

      ObjectSetString(0, LabelName, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, LabelName, OBJPROP_COLOR, col);
     }

   return(rates_total);
}
//+------------------------------------------------------------------+
