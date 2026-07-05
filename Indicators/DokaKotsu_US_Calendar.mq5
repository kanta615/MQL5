//+------------------------------------------------------------------+
//|                                       DokaKotsu_US_Calendar.mq5  |
//|                     米国重要経済指標カレンダー表示インジケーター          |
//|   対象: FOMC/雇用統計/CPI/ISM/GDP/PCE/重要発言 (2026-07-02 日本語名+ISM対応) |
//|        ・本日分(JST基準)のみ表示。読み込みは毎日0時(JST)のみ          |
//|        ・時刻表示は JST(日本時間)に変換                              |
//|        ・GDP / PCE はチャート上に縦線マーカーを表示                     |
//|        ・米国休日はEA(DokaKotsu_EA_10.mq5)が書き出すGlobalVariable  |
//|          (DK_EA_USHOL_*_<magic>) を読んで表示する(EAとの完全連動)。   |
//|          EA未起動/心拍切れ時は独自のMT5カレンダー動的判定→固定リスト  |
//|          の順にフォールバックし、情報の出所をタグで明示する。          |
//|          (2026-07-03: US_ImportantCalendar.mq5 から改名・EA連携追加) |
//+------------------------------------------------------------------+
#property copyright   "Custom Indicator"
#property version     "1.40"
#property indicator_chart_window
#property indicator_plots 0

//--- 入力パラメーター（パネル）
input int    InpMaxEvents      = 15;             // 最大表示件数
input int    InpCornerX        = 10;             // 表示X位置（左端からの距離）
input int    InpCornerY        = 125;            // 表示Y位置（上端からの距離）
input color  InpTitleColor     = clrWhite;       // 小見出し色
input color  InpEventColor     = clrWhite;       // イベント色（未到来）
input color  InpNextColor      = clrLimeGreen;   // 次回イベント色
input color  InpPastColor      = clrGray;        // 発表済み色
input int    InpFontSize       = 10;             // フォントサイズ
input string InpFontName       = "Consolas";     // フォント名

//--- 入力パラメーター（チャート縦線マーカー：GDP / PCE のみ）
input bool   InpShowChartLines = true;           // GDP/PCE 縦線マーカーを表示
input color  InpGDPColor       = clrDeepSkyBlue; // GDP 縦線色
input color  InpPCEColor       = clrViolet;      // PCE 縦線色

//--- 入力パラメーター（米国休日表示）
input bool   InpShowUSHoliday    = true;         // 米国休日を表示するか
input color  InpHolidayColor     = clrOrange;    // 米国休日(予定)の表示色
input color  InpHolidayActiveColor = clrRed;     // 米国休日(現在停止中)の表示色
input int    InpUSHolStopHourJST = 14;           // EAの米国休日新規停止時刻(JST・時)。EA未連携時のフォールバック表示用
input int    InpResumeHourJST    = 8;            // EAのオセアニア再開時刻(JST・時)。フォールバック時の解除時刻計算用
input int    InpResumeMinJST     = 58;           // EAのオセアニア再開時刻(JST・分)。フォールバック時の解除時刻計算用

//--- 入力パラメーター（EA連携: DokaKotsu_EA_10.mq5 と同じマジックナンバー）
input int    InpMagic            = 20260606;     // ★EAと同じマジックナンバー(GlobalVariable連携キー)
input int    InpEALinkFreshSec   = 120;          // EA心拍(DK_EA_HB)がこの秒数以内なら「EA連携中」とみなす

//--- オブジェクト名プレフィックス
#define PREFIX "USICAL_"

//+------------------------------------------------------------------+
//| 初期化                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   UpdateDisplay();        // 起動時に当日分を即表示
   ScheduleNextMidnight(); // 次回更新を「次の0時(JST)」に予約
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| 終了処理                                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteAllObjects();
  }

//+------------------------------------------------------------------+
//| タイマーイベント（0時(JST)ちょうどに1回だけ発火）                      |
//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateDisplay();        // 当日分を読み込み直し（＝翌日へ差し替え）
   ScheduleNextMidnight(); // また次の0時(JST)を予約
  }

//+------------------------------------------------------------------+
//| チャート描画イベント                                                  |
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
   return rates_total;
  }

//+------------------------------------------------------------------+
//| サーバー時間に足すと JST になる秒数を返す                              |
//|   JST = サーバー時間 + (9h - サーバーのGMTオフセット)                  |
//|   ブローカーの夏時間切替にも自動追従                                   |
//+------------------------------------------------------------------+
int ServerToJstShift()
  {
   int g = (int)(TimeTradeServer() - TimeGMT());      // サーバーのGMTオフセット(秒)
   g = (int)MathRound((double)g / 3600.0) * 3600;     // 時間単位に丸め
   return 9 * 3600 - g;
  }

//+------------------------------------------------------------------+
//| サーバー現在時刻（ティックが無くても進む）                             |
//+------------------------------------------------------------------+
datetime ServerNow()
  {
   datetime t = TimeTradeServer();
   if(t <= 0)
      t = TimeCurrent();
   return t;
  }

//+------------------------------------------------------------------+
//| 次の0時(JST)までの秒数でタイマーを予約                                |
//+------------------------------------------------------------------+
void ScheduleNextMidnight()
  {
   int      shift  = ServerToJstShift();
   datetime jstNow = ServerNow() + shift;

   MqlDateTime jst;
   TimeToStruct(jstNow, jst);
   long sinceMid = (long)jst.hour * 3600 + (long)jst.min * 60 + (long)jst.sec;
   long secs     = 86400 - sinceMid;
   if(secs < 1)     secs = 1;
   if(secs > 86400) secs = 86400;

   EventKillTimer();
   EventSetTimer((int)secs);
  }

//+------------------------------------------------------------------+
//| イベント名を対象カテゴリに分類（対象外は "" を返す）                    |
//+------------------------------------------------------------------+
string ClassifyEvent(const string rawName)
  {
   string n = rawName;
   StringToUpper(n);

   //--- 重要発言（FOMC/FED を含む「発言系」を先に判定して誤分類を防ぐ）
   bool isSpeech = (StringFind(n, "SPEAK")  >= 0 ||
                    StringFind(n, "SPEECH") >= 0 ||
                    StringFind(n, "TESTIMONY") >= 0 ||
                    StringFind(n, "REMARK") >= 0 ||
                    StringFind(n, "PRESS CONFERENCE") >= 0 ||
                    StringFind(rawName, "発言") >= 0 ||
                    StringFind(rawName, "証言") >= 0 ||
                    StringFind(rawName, "講演") >= 0);
   if(isSpeech)
     {
      if(StringFind(n, "POWELL")>=0    || StringFind(rawName,"パウエル")>=0) return "重要発言(パウエル)";
      if(StringFind(n, "FED CHAIR")>=0 || StringFind(rawName,"議長")>=0)     return "重要発言(議長)";
      if(StringFind(n, "FOMC")      >= 0) return "重要発言(FOMC)";
      if(StringFind(n, "FEDERAL RESERVE") >= 0 || StringFind(n, "FED") >= 0)
                                          return "重要発言(FRB)";
      return "";  // その他の発言は対象外
     }

   //--- 雇用統計（NFP）
   if(StringFind(n, "NONFARM") >= 0 || StringFind(n, "NON-FARM") >= 0 ||
      StringFind(n, "NFP") >= 0 || StringFind(rawName, "非農業部門雇用者数") >= 0)
      return "雇用統計";

   //--- CPI
   if(StringFind(n, "CPI") >= 0 || StringFind(n, "CONSUMER PRICE") >= 0 ||
      StringFind(rawName, "消費者物価") >= 0)
      return "CPI";
   //--- ISM(本物の景況指数のみ。"製造業受注/給与"は対象外)
   if(StringFind(n, "ISM") >= 0 || StringFind(n, "MANUFACTURING PMI") >= 0 ||
      StringFind(n, "PURCHASING MANAGERS") >= 0 ||
      StringFind(rawName, "製造業景気") >= 0 || StringFind(rawName, "購買担当者") >= 0)
      return "ISM";

   //--- PCE
   if(StringFind(n, "PCE") >= 0 || StringFind(n, "PERSONAL CONSUMPTION") >= 0 ||
      StringFind(rawName, "個人消費") >= 0)
      return "PCE";

   //--- GDP
   if(StringFind(n, "GDP") >= 0 || StringFind(n, "GROSS DOMESTIC") >= 0 ||
      StringFind(rawName, "国内総生産") >= 0)
      return "GDP";

   //--- FOMC 議事録
   if(StringFind(n, "MINUTE") >= 0 &&
      (StringFind(n, "FOMC") >= 0 || StringFind(n, "FEDERAL OPEN MARKET") >= 0))
      return "FOMC議事録";

   //--- FOMC（金利決定）
   if(StringFind(n, "FOMC") >= 0 || StringFind(n, "FEDERAL OPEN MARKET") >= 0 ||
      StringFind(n, "INTEREST RATE DECISION") >= 0 ||
      (StringFind(n, "INTEREST RATE") >= 0 && StringFind(n, "FED") >= 0) ||
      StringFind(rawName, "政策金利") >= 0 || StringFind(rawName, "連邦公開市場委員会") >= 0)
      return "FOMC";

   return "";  // 対象外
  }

//+------------------------------------------------------------------+
//| ★米国休日 固定リスト（フォールバック専用。ブローカーのMT5カレンダーに   |
//|   祝日データが配信されていない場合のみ使用。毎年12月に更新すること。    |
//|   ai_comment.py の US_HOLIDAYS_2026 と同じ日付を使用）               |
//|   ★正式な判定はEA(EA_10)と同じくCALENDAR_TYPE_HOLIDAYの動的照会。     |
//+------------------------------------------------------------------+
struct USHolidayEntry
  {
   string dateStr;   // "YYYY.MM.DD" (JST日付)
   string name;
  };

USHolidayEntry g_usHolidays2026[] =
  {
   {"2026.01.01", "元日 (New Year's Day)"},
   {"2026.01.19", "マーティン・ルーサー・キング・デー"},
   {"2026.02.16", "大統領の日 (Presidents' Day)"},
   {"2026.05.25", "メモリアルデー (Memorial Day)"},
   {"2026.06.19", "ジューンティーンス (Juneteenth)"},
   {"2026.07.03", "独立記念日振替 (Independence Day)"},
   {"2026.09.07", "レイバーデー (Labor Day)"},
   {"2026.11.26", "感謝祭 (Thanksgiving Day)"},
   {"2026.11.27", "感謝祭翌日 (Black Friday)"},
   {"2026.12.25", "クリスマス (Christmas Day)"},
  };

//+------------------------------------------------------------------+
//| ★EA連携: DokaKotsu_EA_10.mq5 が書き出すGVを読み、EAが本当に稼働     |
//|   してこの値を出しているか(心拍の鮮度)まで確認して返す。              |
//|   戻り値: EAのGVが読めた(=EA由来の情報が取得できた)場合 true         |
//+------------------------------------------------------------------+
bool GetUSHolidayFromEA(bool &active, bool &today, datetime &start, datetime &end, bool &eaAlive)
  {
   active = false; today = false; start = 0; end = 0; eaAlive = false;

   string hbName = StringFormat("DK_EA_HB_%d", InpMagic);
   if(!GlobalVariableCheck(hbName))
      return false;   // EAがこのマジックで一度も動いていない

   double hb = GlobalVariableGet(hbName);
   eaAlive = ((TimeCurrent() - (datetime)hb) <= InpEALinkFreshSec);

   string tActive = StringFormat("DK_EA_USHOL_ACTIVE_%d", InpMagic);
   string tToday  = StringFormat("DK_EA_USHOL_TODAY_%d",  InpMagic);
   string tStart  = StringFormat("DK_EA_USHOL_START_%d",  InpMagic);
   string tEnd    = StringFormat("DK_EA_USHOL_END_%d",    InpMagic);
   if(!GlobalVariableCheck(tToday))
      return false;   // 対応していない旧EAの可能性

   active = GlobalVariableCheck(tActive) && (GlobalVariableGet(tActive) > 0.5);
   today  = GlobalVariableGet(tToday) > 0.5;
   start  = GlobalVariableCheck(tStart) ? (datetime)GlobalVariableGet(tStart) : 0;
   end    = GlobalVariableCheck(tEnd)   ? (datetime)GlobalVariableGet(tEnd)   : 0;
   return true;
  }


//+------------------------------------------------------------------+
//| 本日(JST)が米国休日かどうかを判定(固定リスト)。休日名を返す(該当なしは"")|
//+------------------------------------------------------------------+
string GetUSHolidayName(datetime jstDayStart)
  {
   string today = TimeToString(jstDayStart, TIME_DATE); // "2026.07.03"
   int n = ArraySize(g_usHolidays2026);
   for(int i = 0; i < n; i++)
      if(g_usHolidays2026[i].dateStr == today)
         return g_usHolidays2026[i].name;
   return "";
  }

//+------------------------------------------------------------------+
//| メイン表示更新処理（本日分・JST基準）                                  |
//+------------------------------------------------------------------+
void UpdateDisplay()
  {
   int shift = ServerToJstShift();

   //--- 本日(JST)の範囲をサーバー時間に換算して取得
   datetime jstNow = ServerNow() + shift;
   MqlDateTime jst;
   TimeToStruct(jstNow, jst);
   jst.hour = 0; jst.min = 0; jst.sec = 0;
   datetime jstDayStart = StructToTime(jst);          // JST 0:00（JST座標）
   datetime serverFrom  = jstDayStart - shift;         // サーバー時間に換算
   datetime serverTo    = serverFrom + 86400;

   //--- カレンダーデータ取得（US のみ）
   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, serverFrom, serverTo, "US");
   if(count < 0)
     {
      ShowError("カレンダー取得失敗 (" + IntegerToString(count) + ")");
      return;
     }

   //--- フィルタリング ＋ 分類 ＋ 重複除去（時刻はサーバー時間で保持）
   datetime evTimes[];
   string   evLabels[];
   int      n = 0;

   for(int i = 0; i < count; i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;

      //--- 重要度（★★ 以上のみ）
      if(ev.importance < CALENDAR_IMPORTANCE_MODERATE)
         continue;

      //--- 対象6カテゴリに分類
      string label = ClassifyEvent(ev.name);
      if(label == "")
         continue;

      datetime t = values[i].time;                 // サーバー時間
      if(t < serverFrom || t >= serverTo)
         continue;

      //--- 重複除去（同一ラベル かつ 同一JST時刻）
      string hhmm = TimeToString(t + shift, TIME_MINUTES);
      bool dup = false;
      for(int j = 0; j < n; j++)
        {
         if(evLabels[j] == label &&
            TimeToString(evTimes[j] + shift, TIME_MINUTES) == hhmm)
           { dup = true; break; }
        }
      if(dup)
         continue;

      ArrayResize(evTimes,  n + 1);
      ArrayResize(evLabels, n + 1);
      evTimes[n]  = t;
      evLabels[n] = label;
      n++;
     }

   //--- 時刻昇順ソート
   for(int a = 0; a < n - 1; a++)
      for(int b = a + 1; b < n; b++)
         if(evTimes[b] < evTimes[a])
           {
            datetime tt = evTimes[a];  evTimes[a]  = evTimes[b];  evTimes[b]  = tt;
            string   ss = evLabels[a]; evLabels[a] = evLabels[b]; evLabels[b] = ss;
           }

   //--- ★米国休日判定（3段階フォールバック）
   //    ①EA(DokaKotsu_EA_10.mq5)のGV(DK_EA_USHOL_*)を読む＝EAが実際に
   //      計算した値そのもの。心拍(DK_EA_HB)が新しければ「EA連携確認」。
   //    ②EAのGVが無ければ、このインジ自身がMT5カレンダーを動的照会。
   //    ③それも無ければ固定リスト(要確認)。
   string   holidayName    = "";
   datetime holidayStart   = 0;
   datetime holidayEnd     = 0;
   bool     holidayToday   = false;
   bool     holidayActive  = false;
   int      holidaySrc     = 0;   // 0=なし 1=EA連携確認 2=EA連携(心拍切れ) 3=独自判定 4=固定リスト

   if(InpShowUSHoliday)
     {
      bool eaActive=false, eaToday=false, eaAlive=false;
      datetime eaStart=0, eaEnd=0;
      bool eaGvFound = GetUSHolidayFromEA(eaActive, eaToday, eaStart, eaEnd, eaAlive);

      if(eaGvFound && eaToday)
        {
         holidayToday  = true;
         holidayActive = eaActive;
         holidayStart  = eaStart;
         holidayEnd    = eaEnd;
         holidaySrc    = eaAlive ? 1 : 2;
        }

      //--- 名称はEAのGVには乗らないため、参考として独自にカレンダー名を探す
      //    (holidaySrcが1/2の場合でも、名称欄の穴埋めとしてのみ使用)
      bool liveFound = false;
      for(int i = 0; i < count; i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(values[i].event_id, ev))
            continue;
         if(ev.type != CALENDAR_TYPE_HOLIDAY)
            continue;
         datetime t = values[i].time;
         if(t < serverFrom || t >= serverTo)
            continue;
         holidayName = ev.name;
         liveFound = true;
         break;
        }

      if(holidaySrc == 0)   // EA連携が取れなかった場合のみ、独自判定を正式ソースにする
        {
         if(liveFound)
           {
            holidayToday = true;
            holidaySrc   = 3;
            holidayStart = jstDayStart - shift + InpUSHolStopHourJST*3600;
            holidayEnd   = holidayStart + (datetime)((24 - InpUSHolStopHourJST) + InpResumeHourJST)*3600 + InpResumeMinJST*60;
           }
         else
           {
            string fallbackName = GetUSHolidayName(jstDayStart);
            if(fallbackName != "")
              {
               holidayName  = fallbackName;
               holidayToday = true;
               holidaySrc   = 4;
               holidayStart = jstDayStart - shift + InpUSHolStopHourJST*3600;
               holidayEnd   = holidayStart + (datetime)((24 - InpUSHolStopHourJST) + InpResumeHourJST)*3600 + InpResumeMinJST*60;
              }
           }
        }
     }

   if(holidayToday && holidayName == "")
      holidayName = "米国休日";  // 名称が取得できなくてもEA判定は優先表示

   //--- 再描画
   DeleteAllObjects();
   DrawPanel(evTimes, evLabels, n, shift, jstDayStart,
             holidayName, holidayToday, holidayActive, holidayStart, holidayEnd, holidaySrc);
   DrawChartMarkers(evTimes, evLabels, n, shift);
  }

//+------------------------------------------------------------------+
//| パネル描画（左上・本日分・JST表記）                                   |
//+------------------------------------------------------------------+
void DrawPanel(const datetime &evTimes[], const string &evLabels[], int total,
               int shift, datetime jstDayStart, const string &holidayName,
               const bool holidayToday, const bool holidayActive,
               const datetime holidayStart, const datetime holidayEnd,
               const int holidaySrc)
  {
   int y     = InpCornerY;
   int lineH = InpFontSize + 8;

   //--- 小見出し（本日の経済指標 + 日付(JST)）
   string head = "本日の経済指標  " + TimeToString(jstDayStart, TIME_DATE);
   StringReplace(head, ".", "/");
   CreateLabel(PREFIX + "title", head, InpCornerX, y, InpTitleColor, InpFontSize + 1);
   y += lineH + 4;

   //--- ★米国休日表示（該当日のみ）
   //    ソースタグで情報の出所を明示:
   //      (EA連携確認)   = EAが実際に計算しGV出力・心拍も新しい → 最も信頼できる
   //      (EA連携・心拍切れ) = EAのGVはあるが最近の更新が無い → EA停止/未接続の疑い
   //      (独自判定)      = このインジ自身がMT5カレンダーを直接照会(EA未検出)
   //      (固定リスト・要確認) = カレンダー未配信のため固定日付表で参考表示
   if(holidayToday)
     {
      string tag;
      switch(holidaySrc)
        {
         case 1: tag = "(EA連携確認)";       break;
         case 2: tag = "(EA連携・心拍切れ)";  break;
         case 3: tag = "(独自判定・EA未検出)"; break;
         default:tag = "(固定リスト・要確認)"; break;
        }

      string timeTxt;
      if(holidayActive)
        {
         string endTxt = (holidayEnd > 0) ? TimeToString(holidayEnd + shift, TIME_MINUTES) : "?";
         timeTxt = "停止中(解除:" + endTxt + ")";
        }
      else
        {
         string startTxt = (holidayStart > 0) ? TimeToString(holidayStart + shift, TIME_MINUTES)
                                               : (IntegerToString(InpUSHolStopHourJST) + ":00");
         timeTxt = startTxt + " 停止予定";
        }

      color lineColor = holidayActive ? InpHolidayActiveColor : InpHolidayColor;
      string holLine  = "★米国休日" + tag + ": " + holidayName + "  (" + timeTxt + ")";
      CreateLabel(PREFIX + "holiday", holLine, InpCornerX, y, lineColor, InpFontSize);
      y += lineH + 2;
     }

   //--- 指標がない日は小見出しのみ
   if(total == 0)
      return;

   datetime now = ServerNow();   // 色判定はサーバー時間同士で比較

   int nextIdx = -1;
   for(int i = 0; i < total; i++)
      if(evTimes[i] >= now) { nextIdx = i; break; }

   int showCount = MathMin(total, InpMaxEvents);

   for(int i = 0; i < showCount; i++)
     {
      string hhmm = TimeToString(evTimes[i] + shift, TIME_MINUTES);  // JST "21:30"
      string line = evLabels[i] + "  " + hhmm;                       // "GDP  21:30"

      color col;
      if(evTimes[i] < now)   col = InpPastColor;
      else if(i == nextIdx)  col = InpNextColor;
      else                   col = InpEventColor;

      CreateLabel(PREFIX + "ev" + IntegerToString(i), line,
                  InpCornerX, y, col, InpFontSize);
      y += lineH;
     }
  }

//+------------------------------------------------------------------+
//| チャート縦線マーカー描画（GDP / PCE のみ）                            |
//|   位置はサーバー時間（チャート時間軸に一致）／ラベルはJST表記          |
//+------------------------------------------------------------------+
void DrawChartMarkers(const datetime &evTimes[], const string &evLabels[], int total,
                      int shift)
  {
   if(!InpShowChartLines)
      return;

   for(int i = 0; i < total; i++)
     {
      if(evLabels[i] != "GDP" && evLabels[i] != "PCE")
         continue;

      string nm = PREFIX + "vl" + IntegerToString(i);
      ObjectCreate(0, nm, OBJ_VLINE, 0, evTimes[i], 0);   // サーバー時間で配置

      color c = (evLabels[i] == "GDP") ? InpGDPColor : InpPCEColor;
      ObjectSetInteger(0, nm, OBJPROP_COLOR,      c);
      ObjectSetInteger(0, nm, OBJPROP_STYLE,      STYLE_DOT);
      ObjectSetInteger(0, nm, OBJPROP_WIDTH,      1);
      ObjectSetInteger(0, nm, OBJPROP_BACK,       true);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN,     true);

      string desc = evLabels[i] + " " + TimeToString(evTimes[i] + shift, TIME_MINUTES);
      ObjectSetString(0, nm, OBJPROP_TEXT,    desc);
      ObjectSetString(0, nm, OBJPROP_TOOLTIP, desc);
     }
  }

//+------------------------------------------------------------------+
//| ラベル作成（左上基準）                                                |
//+------------------------------------------------------------------+
void CreateLabel(const string name, const string text,
                 int x, int y, color clr, int fontSize)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  fontSize);
   ObjectSetString (0, name, OBJPROP_FONT,      InpFontName);
   ObjectSetString (0, name, OBJPROP_TEXT,      text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,    true);
  }

//+------------------------------------------------------------------+
//| エラー表示                                                          |
//+------------------------------------------------------------------+
void ShowError(const string msg)
  {
   DeleteAllObjects();
   CreateLabel(PREFIX + "err", "⚠ " + msg, InpCornerX, InpCornerY, clrRed, InpFontSize);
  }

//+------------------------------------------------------------------+
//| 全オブジェクト削除                                                    |
//+------------------------------------------------------------------+
void DeleteAllObjects()
  {
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, PREFIX) == 0)
         ObjectDelete(0, name);
     }
  }
//+------------------------------------------------------------------+
