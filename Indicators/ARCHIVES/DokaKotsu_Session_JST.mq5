//+------------------------------------------------------------------+
//|                                  DokaKotsu_Session_JST.mq5        |
//|   日本時間(JST)ベースの市場セッションを背景色で表示する          |
//|   インジケーター。                                                |
//|     オセアニア=濃い青 / 東京=濃いベージュ / ロンドン=緑 / NY=濃赤 |
//|   ※セッション境界は夏/冬時間で自動的に1時間ずれる。              |
//|     時刻はJST基準(日本時間固定)で判定。                           |
//|                                                                  |
//|   セッション(JST・重なりなし):                                    |
//|     オセアニア : 5:00 〜 9:00                                     |
//|     東京       : 9:00 〜 16:00                                    |
//|     ロンドン   : 16:00(冬17:00) 〜 NY開始                         |
//|     NY         : 21:00(冬22:00) 〜 翌5:00                         |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.00"
#property indicator_chart_window
#property indicator_plots 0

//=== 入力パラメータ ==============================================
input bool  InpAutoDST     = true;   // 夏/冬を自動判定するか(falseなら手動)
input bool  InpManualSummer= true;   // 手動時の夏時間ON/OFF(InpAutoDST=false時のみ)
input color InpColOceania  = C'10,20,60';    // オセアニア=濃い青
input color InpColTokyo    = C'70,60,35';     // 東京=濃いベージュ
input color InpColLondon   = C'15,55,25';     // ロンドン=緑
input color InpColNY       = C'70,15,15';     // NY=濃赤
input bool  InpShowLabel   = true;   // 現在セッション名とJST時刻をラベル表示

string OBJ_PREFIX = "DKsess_";
string LBL_NAME   = "DKsess_label";

//+------------------------------------------------------------------+
//| サーバー時刻 → JST のオフセット(時間)を推定                       |
//|   多くのGoldサーバーはGMT+2(冬)/GMT+3(夏)。JST=GMT+9。           |
//|   よって JST = サーバー時刻 + (夏:6 / 冬:7)。                     |
//|   ※環境により異なる場合は InpAutoDST=false で手動調整可。        |
//+------------------------------------------------------------------+
bool IsSummerTime()
{
   if(!InpAutoDST) return InpManualSummer;
   // サーバーのGMTオフセットから夏時間を推定
   //   TimeGMTOffset(): ローカル(端末)とGMTの差。ここではサーバー基準で簡易判定。
   //   米国DST: 3月第2日曜〜11月第1日曜 を夏時間とする(ゴールドは主に米国DST準拠)
   datetime now = TimeCurrent();
   MqlDateTime t; TimeToStruct(now, t);
   int y = t.year;
   // 3月第2日曜
   datetime mar = StringToTime(StringFormat("%d.03.01 00:00", y));
   MqlDateTime mt; TimeToStruct(mar, mt);
   int firstSunMar = (7 - mt.day_of_week) % 7 + 1;   // 3/1からみた最初の日曜
   int secondSunMar = firstSunMar + 7;
   datetime dstStart = StringToTime(StringFormat("%d.03.%02d 00:00", y, secondSunMar));
   // 11月第1日曜
   datetime nov = StringToTime(StringFormat("%d.11.01 00:00", y));
   MqlDateTime nt; TimeToStruct(nov, nt);
   int firstSunNov = (7 - nt.day_of_week) % 7 + 1;
   datetime dstEnd = StringToTime(StringFormat("%d.11.%02d 00:00", y, firstSunNov));
   return (now >= dstStart && now < dstEnd);
}

//+------------------------------------------------------------------+
//| サーバー時刻 → JST時刻 に変換                                     |
//+------------------------------------------------------------------+
datetime ToJST(datetime serverTime)
{
   int off = IsSummerTime() ? 6 : 7;   // 夏:+6 / 冬:+7
   return serverTime + off*3600;
}

//+------------------------------------------------------------------+
//| JST時刻から、その時のセッション色を返す                          |
//+------------------------------------------------------------------+
color SessionColor(datetime jst)
{
   MqlDateTime t; TimeToStruct(jst, t);
   int h = t.hour;
   bool summer = IsSummerTime();
   int londonStart = summer ? 16 : 17;
   int nyStart     = summer ? 21 : 22;

   // オセアニア 5〜9
   if(h >= 5 && h < 9)            return InpColOceania;
   // 東京 9〜16(or17)
   if(h >= 9 && h < londonStart)  return InpColTokyo;
   // ロンドン londonStart〜nyStart
   if(h >= londonStart && h < nyStart) return InpColLondon;
   // NY nyStart〜翌5(=21or22 〜 24、および 0〜5)
   if(h >= nyStart || h < 5)      return InpColNY;
   return clrNONE;
}

string SessionName(datetime jst)
{
   MqlDateTime t; TimeToStruct(jst, t);
   int h = t.hour;
   bool summer = IsSummerTime();
   int londonStart = summer ? 16 : 17;
   int nyStart     = summer ? 21 : 22;
   if(h >= 5 && h < 9)            return "オセアニア";
   if(h >= 9 && h < londonStart)  return "東京";
   if(h >= londonStart && h < nyStart) return "ロンドン";
   return "NY";
}

//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu Session(JST)");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, OBJ_PREFIX);
   ObjectDelete(0, LBL_NAME);
}

//+------------------------------------------------------------------+
//| 各足の背景に、その足のセッション色の縦帯を描く                   |
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
   // 表示足数が多いと重いので、直近 InpMaxBars 本だけ塗る
   int maxBars = 500;
   int begin = MathMax(0, rates_total - maxBars);

   // セッションが切り替わる境目ごとに長方形を1つ描く(塗りすぎ防止)
   ArraySetAsSeries(time, false);
   datetime segStart = 0;
   color    segCol   = clrNONE;
   int      segIdx   = 0;

   // 既存オブジェクトを一旦消す(再描画)
   ObjectsDeleteAll(0, OBJ_PREFIX);

   for(int i=begin; i<rates_total; i++)
   {
      datetime jst = ToJST(time[i]);
      color c = SessionColor(jst);
      if(c != segCol)
      {
         // 前のセグメントを確定して描く
         if(segCol != clrNONE && segStart>0)
            DrawBand(segIdx, segStart, time[i], segCol);
         segCol   = c;
         segStart = time[i];
         segIdx++;
      }
   }
   // 最後のセグメント
   if(segCol != clrNONE && segStart>0)
      DrawBand(segIdx, segStart, time[rates_total-1]+PeriodSeconds(), segCol);

   // 現在のセッション名+JST時刻ラベル
   if(InpShowLabel)
   {
      datetime nowJst = ToJST(TimeCurrent());
      MqlDateTime t; TimeToStruct(nowJst, t);
      string txt = StringFormat("%s  JST %02d:%02d  (%s)",
                     SessionName(nowJst), t.hour, t.min,
                     IsSummerTime()?"夏時間":"冬時間");
      if(ObjectFind(0, LBL_NAME) < 0)
      {
         ObjectCreate(0, LBL_NAME, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, LBL_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, LBL_NAME, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(0, LBL_NAME, OBJPROP_YDISTANCE, 20);
         ObjectSetInteger(0, LBL_NAME, OBJPROP_FONTSIZE, 11);
      }
      ObjectSetString(0, LBL_NAME, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, LBL_NAME, OBJPROP_COLOR, SessionColor(nowJst)==clrNONE? clrWhite : clrWhite);
   }

   return(rates_total);
}

//+------------------------------------------------------------------+
//| 背景帯(長方形)を1つ描く                                          |
//+------------------------------------------------------------------+
void DrawBand(int idx, datetime t1, datetime t2, color c)
{
   string name = OBJ_PREFIX + IntegerToString(idx);
   // チャート全体の高さをカバーする価格範囲
   double pmax = ChartGetDouble(0, CHART_PRICE_MAX);
   double pmin = ChartGetDouble(0, CHART_PRICE_MIN);
   if(pmax<=pmin)
   {
      // 取得できない時は現在値の上下に十分広い範囲を取る
      double cur = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      pmax = cur*2.0; pmin = 0.0;
   }
   else
   {
      // 帯が画面端で切れないよう少し広げる
      double pad = (pmax - pmin) * 0.5;
      pmax += pad; pmin -= pad;
   }
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, pmax, t2, pmin);
   else
   {
      ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
      ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
      ObjectSetDouble (0, name, OBJPROP_PRICE, 0, pmax);
      ObjectSetDouble (0, name, OBJPROP_PRICE, 1, pmin);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);   // ローソクの背面に
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}
//+------------------------------------------------------------------+
