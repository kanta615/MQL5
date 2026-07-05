//+------------------------------------------------------------------+
//|                                   DokaKotsu_Walls.mq5             |
//|                                                                  |
//|  ■ これは「表示専用」の壁(レジサポ)オーバーレイです。           |
//|    売買ロジックには一切使いません。グレーライン(indicator_3)の   |
//|    検証用に、価格の“壁”を目で確認するための線だけを描きます。    |
//|    DokaKotsu_indicator_3 とは独立(別ファイル)。本体は汚しません。|
//|                                                                  |
//|    描くもの(各ON/OFF可):                                        |
//|      ・スイングハイ/ロー … 前後k本より高い高値/安い安値=価格構造 |
//|      ・ピボット          … 前日H/L/Cから PP/R1/S1/R2/S2         |
//|      ・ラウンドナンバー  … 一定間隔($10など)の節目             |
//|                                                                  |
//|  ※同じチャート(XAUUSD M5想定)に indicator_3 と重ねて使う。      |
//|    重い時は不要な種類をOFF。新足ごとにだけ再描画(軽量)。        |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//=== 入力 ==========================================================
input bool   InpShowSwing  = true;     // スイングハイ/ローを描く
input int    InpSwingK      = 3;       // スイング判定:前後この本数より高い/安い
input int    InpSwingLookback = 300;   // スイング探索の対象本数(直近)
input int    InpSwingShow   = 6;       // 上下それぞれ直近この数だけ線を残す
input color  InpSwingHighCol = clrTomato;   // 上の壁(高値)の色
input color  InpSwingLowCol  = clrMediumSeaGreen; // 下の壁(安値)の色

input bool   InpShowPivot  = true;     // ピボット(前日ベース)を描く
input color  InpPivotCol    = clrGoldenrod;

input bool   InpShowRound  = true;     // ラウンドナンバーを描く
input double InpRoundStep    = 10.0;   // 節目の間隔($)。ゴールドは10 or 50
input double InpRoundRange    = 60.0;  // 現在値から上下この範囲($)だけ描く
input color  InpRoundCol     = clrDimGray;

const string PFX = "DKW_";             // このインジが作る全オブジェクトの接頭辞

datetime g_lastBar = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu_Walls v1.0");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, PFX);   // 自分の線を全消去
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   if(rates_total < InpSwingK*2 + 5) return(rates_total);

   // 新しい足ができた時だけ再描画(軽量・⑥再描画対策)
   datetime cur = time[rates_total-1];
   if(cur == g_lastBar) return(rates_total);
   g_lastBar = cur;

   ObjectsDeleteAll(0, PFX);   // いったん全消し → 引き直し

   double price = close[rates_total-1];
   datetime tEnd = time[rates_total-1];

   //--- スイングハイ/ロー ---------------------------------------
   if(InpShowSwing)
   {
      int k = MathMax(1, InpSwingK);
      int start = MathMax(k, rates_total-1-InpSwingLookback);
      int hi_done=0, lo_done=0;
      // 直近(右)から左へ走査し、上下それぞれ InpSwingShow 本だけ採用
      for(int i=rates_total-1-k; i>=start && (hi_done<InpSwingShow || lo_done<InpSwingShow); i--)
      {
         bool isHigh=true, isLow=true;
         for(int j=1; j<=k; j++)
         {
            if(high[i] <= high[i-j] || high[i] <= high[i+j]) isHigh=false;
            if(low[i]  >= low[i-j]  || low[i]  >= low[i+j])  isLow=false;
            if(!isHigh && !isLow) break;
         }
         if(isHigh && hi_done<InpSwingShow)
         {
            _ray(PFX+"sh_"+(string)i, time[i], high[i], tEnd, InpSwingHighCol, STYLE_DOT);
            hi_done++;
         }
         if(isLow && lo_done<InpSwingShow)
         {
            _ray(PFX+"sl_"+(string)i, time[i], low[i], tEnd, InpSwingLowCol, STYLE_DOT);
            lo_done++;
         }
      }
   }

   //--- ピボット(前日H/L/Cベース) -------------------------------
   if(InpShowPivot)
   {
      double H = iHigh(_Symbol, PERIOD_D1, 1);
      double L = iLow (_Symbol, PERIOD_D1, 1);
      double C = iClose(_Symbol, PERIOD_D1, 1);
      if(H>0 && L>0)
      {
         double PP = (H+L+C)/3.0;
         double R1 = 2*PP - L,  S1 = 2*PP - H;
         double R2 = PP + (H-L), S2 = PP - (H-L);
         _hline(PFX+"pp", PP, InpPivotCol, STYLE_SOLID, "PP");
         _hline(PFX+"r1", R1, InpPivotCol, STYLE_DASH,  "R1");
         _hline(PFX+"s1", S1, InpPivotCol, STYLE_DASH,  "S1");
         _hline(PFX+"r2", R2, InpPivotCol, STYLE_DOT,   "R2");
         _hline(PFX+"s2", S2, InpPivotCol, STYLE_DOT,   "S2");
      }
   }

   //--- ラウンドナンバー -----------------------------------------
   if(InpShowRound && InpRoundStep>0)
   {
      double lo = price - InpRoundRange, hi = price + InpRoundRange;
      double startLvl = MathCeil(lo/InpRoundStep)*InpRoundStep;
      int n=0;
      for(double lvl=startLvl; lvl<=hi && n<40; lvl+=InpRoundStep, n++)
         _hline(PFX+"rn_"+(string)(int)lvl, lvl, InpRoundCol, STYLE_DOT, "");
   }

   ChartRedraw(0);
   return(rates_total);
}

//+------------------------------------------------------------------+
//| 水平線(チャート全体)+右端ラベル                               |
//+------------------------------------------------------------------+
void _hline(string name, double price, color col, ENUM_LINE_STYLE st, string label)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_STYLE,st);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   if(label!="")
   {
      string tn=name+"_t";
      datetime tt = TimeCurrent();
      if(ObjectFind(0,tn)<0) ObjectCreate(0,tn,OBJ_TEXT,0,tt,price);
      ObjectSetInteger(0,tn,OBJPROP_TIME,tt);
      ObjectSetDouble(0,tn,OBJPROP_PRICE,price);
      ObjectSetString(0,tn,OBJPROP_TEXT," "+label);
      ObjectSetInteger(0,tn,OBJPROP_COLOR,col);
      ObjectSetInteger(0,tn,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,tn,OBJPROP_SELECTABLE,false);
   }
}

//+------------------------------------------------------------------+
//| スイング水準を、その足から右端へ伸ばす水平レイ                   |
//+------------------------------------------------------------------+
void _ray(string name, datetime t1, double price, datetime t2, color col, ENUM_LINE_STYLE st)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TREND,0,t1,price,t2,price);
   ObjectSetInteger(0,name,OBJPROP_TIME,0,t1);
   ObjectSetDouble (0,name,OBJPROP_PRICE,0,price);
   ObjectSetInteger(0,name,OBJPROP_TIME,1,t2);
   ObjectSetDouble (0,name,OBJPROP_PRICE,1,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_STYLE,st);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,true);   // 右へ延長(壁として見やすく)
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
}
//+------------------------------------------------------------------+
