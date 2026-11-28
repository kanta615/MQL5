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
//|          (2026-07-07: 更新方式を単発24hタイマー→30秒周期チェックに変更。|
//|           長時間の単発EventSetTimerはMT5環境によって発火しないことが  |
//|           あり、日付が変わっても前日分が表示され続ける不具合の原因に  |
//|           なっていたため。日付変更検知時は一旦テキストファイルに出力 |
//|           し、それを読み直してから描画する(監査・デバッグ用の証跡)。 |
//|          (2026-07-08: ai_comment.py/PostgreSQLへの連携用に           |
//|           mt5_calendar_today.json(重要度・カテゴリ付き)を           |
//|           Common\Files へ追加出力。既存のCAL_FILE(監査用txt)と       |
//|           同じ「ファイルに保存→読み直してから描画」の流れに相乗り。  |
//|           Python側でjson.load()できるようFILE_ANSI+CP_UTF8で書く   |
//|           (FILE_UNICODEはUTF-16になりPythonのutf-8読込と食い違うため)|
//|          (2026-07-09 v4: JSON出力を「今日だけ」から「過去InpCalLookBackDays日  |
//|           〜先InpCalLookAheadDays日」の広範囲へ根本的に拡張。FOMC等の先の予定 |
//|           も、その日が来る前からDBへ貯められるようにするための変更。         |
//|           パネル/チャートマーカー描画は従来通り「今日のみ」のまま変更なし     |
//|           (SaveWideCalendarJsonを新設し、JSON出力だけ別経路で広範囲取得する)。|
//|          (2026-07-09b: チャート左上のテキストパネル(本日の経済指標...)を    |
//|           InpShowPanel=false(既定)で非表示化。モニター側「経済指標」タブに |
//|           同じ情報が出るようになったため、チャートの見た目を優先。          |
//|           チャートマーカー(縦線)・JSON出力は従来通り変更なし。              |
//|          (2026-07-15: PPI(生産者物価指数)をCPIと同様に分類対象へ追加。          |
//|           ClassifyEvent()にPPI判定、CategoryCode()にPPIマッピングを追加。       |
//|           EA_13側もEV_PPI追加・CPIと同じ発表前時間窓(InpCpiNfpHoursBefore)で対応)。|
//|          (2026-07-16: 小売売上高(Retail Sales)をCPI/PPIと同様に    |
//|           分類対象へ追加。ClassifyEvent()に判定、CategoryCode()に |
//|           RETAILマッピングを追加。EA_15側もEV_RETAIL追加・共通の  |
//|           InpEvStopHourJST起点ルールで対応)。                     |
//|          (2026-07-16(2回目): 小売売上高の内部ラベルを英語コード     |
//|           "RETAIL"から最初から日本語「小売売上高」に変更。         |
//|           JSON出力(category)・DB・Python側すべてが自動的に         |
//|           「小売売上高」になり、翻訳/変換処理が不要になる)。       |
//+------------------------------------------------------------------+
#property copyright   "Custom Indicator"
#property version     "1.74"
#property indicator_chart_window
#property indicator_plots 0

//--- 入力パラメーター（パネル）
input int    InpMaxEvents      = 15;             // 最大表示件数
input bool   InpShowPanel      = false;          // ★2026-07-09追加: チャート左上のテキストパネル(本日の経済指標)を表示するか。既定OFF=非表示
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

//--- ★2026-07-07追加: 日付変更検知用(最後に描画したJST日の0時タイムスタンプ)
datetime g_lastDrawnJstDay = -1;   // -1=まだ一度も描画していない(起動直後は必ず更新させる)
//--- ★2026-07-08追加: 日中でもブローカー側カレンダーの後追い更新(FOMC等)を拾うための定期再取得用
datetime g_lastRefresh     = 0;    // 最後にUpdateDisplay()を実行したサーバー時刻
input int InpRefreshMinutes = 5;   // ★2026-07-08追加: 日付変更が無くてもこの分数ごとに再取得(0=従来通り日付変更時のみ)
//--- ★2026-07-09追加: JSON出力(Python/DB連携用)だけを広範囲取得する。チャート表示(パネル/マーカー)には影響しない
input int InpCalLookBackDays  = 3;    // JSON: 何日前まで遡って含めるか
input int InpCalLookAheadDays = 21;   // JSON: 何日先まで先読みして含めるか(FOMC等の予定を事前に貯めるため)
//--- ★2026-07-08追加: 取得結果の出力先(MQL5\Files\配下。監査・デバッグ用の証跡)
#define CAL_FILE "DokaKotsu_Calendar_Today.txt"
//--- ★2026-07-08追加: Python(ai_comment.py)連携用JSON出力先。CAL_FILEと同じCommon\Filesに置く
#define CAL_JSON_FILE "mt5_calendar_today.json"

//+------------------------------------------------------------------+
//| 初期化                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   UpdateDisplay();        // 起動時に当日分を即表示
   //--- ★2026-07-07変更: 「次の0時(JST)ちょうど」を狙う単発の長時間タイマー(最大24h)は、
   //    端末のスリープ/再接続/仕様により発火しないことがあり、日付が変わっても
   //    前日分の表示が残り続ける不具合の原因になっていた。
   //    そのため、30秒ごとに「今のJST日付が前回描画した日と違うか」だけを
   //    チェックする周期タイマーに変更(0時から最大30秒程度の遅れで確実に更新される)。
   EventSetTimer(30);
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
//| タイマーイベント（30秒ごと。日付が変わっていた時だけ更新する）           |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int      shift  = ServerToJstShift();
   datetime jstNow = ServerNow() + shift;
   MqlDateTime jst;
   TimeToStruct(jstNow, jst);
   jst.hour = 0; jst.min = 0; jst.sec = 0;
   datetime jstDayStart = StructToTime(jst);

   bool dayChanged  = (jstDayStart != g_lastDrawnJstDay);
   bool dueForRetry = (InpRefreshMinutes > 0) &&
                       ((ServerNow() - g_lastRefresh) >= InpRefreshMinutes*60);

   if(dayChanged || dueForRetry)   // ★2026-07-08変更: 日付変更に加え、一定間隔でも再取得
      UpdateDisplay();             //   (ブローカー側カレンダーが日中に後追いで追加されるケースに対応)
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
   //--- ★2026-07-15追加: PPI(生産者物価指数)。CPIと同じ扱いで別カテゴリとして分類する
   if(StringFind(n, "PPI") >= 0 || StringFind(n, "PRODUCER PRICE") >= 0 ||
      StringFind(rawName, "生産者物価") >= 0)
      return "PPI";
   //--- ★2026-07-16追加: 小売売上高。他指標と同じ扱いで別カテゴリとして分類する
   //    ★2026-07-16(2回目)修正: 英語コード"RETAIL"ではなく、最初から日本語「小売売上高」を返す。
   //    こうすることでJSON出力(category)・DB・Python側すべてが自動的に「小売売上高」になる
   //    (CategoryCodeでの変換不要・二重管理の回避)。
   if(StringFind(n, "RETAIL SALES") >= 0 || StringFind(rawName, "小売売上高") >= 0)
      return "小売売上高";
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
   int      evImportance[];   // ★2026-07-08追加: JSON出力用(HIGH/MODERATE表示に使う)
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
      ArrayResize(evImportance, n + 1);
      evTimes[n]  = t;
      evLabels[n] = label;
      evImportance[n] = (int)ev.importance;
      n++;
     }

   //--- ★2026-07-08追加: FOMCだけは「今日の箱」に頼らず、EA(RefreshCalEvent)と同じ
   //    "今"基準の移動窓でも別途確認し、見つかれば強制的に加える。
   //    (ブローカー側カレンダーの一時的な不安定さで、厳密な当日窓だと拾えないことがあるため。
   //     FOMCは重要度・頻度ともに例外的に重いイベントなので、これだけ二重チェックする)
   {
      datetime wideFrom = ServerNow() - 2*3600;
      datetime wideTo   = ServerNow() + 36*3600;   // 今から36時間先まで(日付境界を跨いでも拾えるように)
      MqlCalendarValue wv[];
      int wcnt = CalendarValueHistory(wv, wideFrom, wideTo, "US");
      for(int i = 0; i < wcnt; i++)
        {
         MqlCalendarEvent ev;
         if(!CalendarEventById(wv[i].event_id, ev)) continue;
         if(ev.importance < CALENDAR_IMPORTANCE_MODERATE) continue;
         string label = ClassifyEvent(ev.name);
         if(label != "FOMC" && label != "FOMC議事録") continue;   // FOMC系以外はここでは対象外(通常の当日窓に任せる)

         datetime t = wv[i].time;
         string hhmm = TimeToString(t + shift, TIME_MINUTES);
         bool dup = false;
         for(int j = 0; j < n; j++)
            if(evLabels[j] == label && TimeToString(evTimes[j] + shift, TIME_MINUTES) == hhmm) { dup = true; break; }
         if(dup) continue;

         ArrayResize(evTimes,  n + 1);
         ArrayResize(evLabels, n + 1);
         ArrayResize(evImportance, n + 1);
         evTimes[n]  = t;
         evLabels[n] = label;
         evImportance[n] = (int)ev.importance;
         n++;
         Print("[US_Calendar] FOMC移動窓チェックで検出(当日窓では見つからなかった分): ",
               TimeToString(t + shift, TIME_DATE|TIME_MINUTES), " JST  ", ev.name);
        }
   }
   for(int a = 0; a < n - 1; a++)
      for(int b = a + 1; b < n; b++)
         if(evTimes[b] < evTimes[a])
           {
            datetime tt = evTimes[a];  evTimes[a]  = evTimes[b];  evTimes[b]  = tt;
            string   ss = evLabels[a]; evLabels[a] = evLabels[b]; evLabels[b] = ss;
            int      ii = evImportance[a]; evImportance[a] = evImportance[b]; evImportance[b] = ii;
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

   //--- ★2026-07-07追加: 取得結果を一旦テキストファイルに出力し、それを読み直してから描画する。
   //    (a)日付変更のたびに「実際に何を取得したか」が証跡として残るのでデバッグしやすい
   //    (b)描画処理を「ライブ取得直後の配列」ではなく「ファイルの内容」に依存させることで、
   //       取得と描画が正しく連動しているかをファイルの中身だけで検証できるようにする
   SaveCalendarToFile(jstDayStart, evTimes, evLabels, evImportance, n,
                      holidayName, holidayToday, holidayActive, holidayStart, holidayEnd, holidaySrc, shift);

   datetime fEvTimes[]; string fEvLabels[]; int fEvImportance[]; int fN = 0;
   string   fHolidayName; bool fHolidayToday=false, fHolidayActive=false;
   datetime fHolidayStart=0, fHolidayEnd=0; int fHolidaySrc=0;

   bool loaded = LoadCalendarFromFile(fEvTimes, fEvLabels, fEvImportance, fN,
                                       fHolidayName, fHolidayToday, fHolidayActive,
                                       fHolidayStart, fHolidayEnd, fHolidaySrc);
   if(!loaded)   // 万一読み直しに失敗したら、ライブ取得した値をそのまま使う(表示が消えるのを防ぐ安全策)
     {
      ArrayResize(fEvTimes,  n); ArrayResize(fEvLabels, n); ArrayResize(fEvImportance, n);
      for(int k = 0; k < n; k++) { fEvTimes[k] = evTimes[k]; fEvLabels[k] = evLabels[k]; fEvImportance[k] = evImportance[k]; }
      fN = n;
      fHolidayName = holidayName; fHolidayToday = holidayToday; fHolidayActive = holidayActive;
      fHolidayStart = holidayStart; fHolidayEnd = holidayEnd; fHolidaySrc = holidaySrc;
     }

   //--- 再描画（＝ファイルから読み直した内容で表示する）
   DeleteAllObjects();
   // ★2026-07-09: InpShowPanel=false(既定)ならテキストパネル(本日の経済指標...)は描画しない。
   //   モニター(monitor_4.py「経済指標」タブ)側で同じ情報を確認できるため、チャートの見た目を
   //   優先してデフォルトで非表示にした。DeleteAllObjects()は呼ぶので、以前描画されていた
   //   パネルオブジェクトが残っている場合もこのタイミングでちゃんと消える。
   if(InpShowPanel)
      DrawPanel(fEvTimes, fEvLabels, fN, shift, jstDayStart,
                fHolidayName, fHolidayToday, fHolidayActive, fHolidayStart, fHolidayEnd, fHolidaySrc);
   DrawChartMarkers(fEvTimes, fEvLabels, fN, shift);

   //--- ★2026-07-08追加: Python(ai_comment.py)連携用JSONも同じ「ファイル読み直し後」のデータで出力
   //--- ★2026-07-09追加: Python(ai_comment.py)連携用JSONは「今日だけ」ではなく広範囲(過去/先読み)で出力する。
   //    パネル/チャートマーカー描画(直前のDrawPanel/DrawChartMarkers)は従来通り「今日のみ」のまま変更しない。
   SaveWideCalendarJson(shift, jstDayStart, InpCalLookBackDays, InpCalLookAheadDays);

   g_lastDrawnJstDay = jstDayStart;   // ★この日はもう更新済みとして記録(次のOnTimerで再取得しない)
   g_lastRefresh     = ServerNow();   // ★2026-07-08追加: 定期リトライの基準時刻
  }

//+------------------------------------------------------------------+
//| ★2026-07-07追加: 本日分の取得結果をテキストファイルに保存             |
//|   保存先: %APPDATA%\MetaQuotes\Terminal\Common\Files\               |
//|           DokaKotsu_Calendar_Today.txt (FILE_COMMON=端末共通領域)     |
//+------------------------------------------------------------------+
void SaveCalendarToFile(datetime jstDayStart, const datetime &evTimes[], const string &evLabels[],
                         const int &evImportance[], int n,
                         const string &holidayName, bool holidayToday, bool holidayActive,
                         datetime holidayStart, datetime holidayEnd, int holidaySrc, int shift)
  {
   //--- ★2026-07-07修正: FILE_TXTモードのFileWrite/FileReadStringは複数引数を
   //    「同じ行の別トークン」としては読み書きできない(1回の呼び出し=1行という
   //    前提が誤りだった)。1行=1レコード・"|"区切りの明示的な文字列に変更。
   //    また日本語(休日名・イベント名)の文字化けを避けるため FILE_ANSI→FILE_UNICODE。
   int h = FileOpen(CAL_FILE, FILE_WRITE|FILE_TXT|FILE_UNICODE|FILE_COMMON);
   if(h == INVALID_HANDLE)
     {
      Print("[US_Calendar] 出力ファイルを開けませんでした: ", CAL_FILE, " err=", GetLastError());
      return;
     }
   FileWriteString(h, "DATE=" + TimeToString(jstDayStart, TIME_DATE) + "\r\n");
   string hline = StringFormat("HOLIDAY|%d|%d|%d|%s|%I64d|%I64d",
                                holidayToday ? 1 : 0, holidayActive ? 1 : 0, holidaySrc,
                                holidayName, (long)holidayStart, (long)holidayEnd);
   FileWriteString(h, hline + "\r\n");
   for(int i = 0; i < n; i++)
     {
      //--- JST表記(HH:MM)もここで作って一緒に書き出す。読み手(Python等)が
      //    改めてサーバー時間→JST変換をしなくて済むようにするため。
      //    ★2026-07-08: 末尾に重要度(MqlCalendarImportance整数値)を追加(JSON出力用)
      string hhmm = TimeToString(evTimes[i] + shift, TIME_MINUTES);
      string eline = StringFormat("EVENT|%I64d|%s|%s|%d", (long)evTimes[i], evLabels[i], hhmm, evImportance[i]);
      FileWriteString(h, eline + "\r\n");
     }
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| ★2026-07-07追加: SaveCalendarToFileで書いた内容を読み直す              |
//+------------------------------------------------------------------+
bool LoadCalendarFromFile(datetime &evTimes[], string &evLabels[], int &evImportance[], int &n,
                          string &holidayName, bool &holidayToday, bool &holidayActive,
                          datetime &holidayStart, datetime &holidayEnd, int &holidaySrc)
  {
   n = 0;
   holidayToday = false; holidayActive = false; holidaySrc = 0;
   holidayStart = 0; holidayEnd = 0; holidayName = "";

   int h = FileOpen(CAL_FILE, FILE_READ|FILE_TXT|FILE_UNICODE|FILE_COMMON);
   if(h == INVALID_HANDLE)
      return false;

   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);   // FILE_TXTモードなので1行まるごと読める
      if(line == "")
         continue;

      string parts[];
      int cnt = StringSplit(line, '|', parts);
      if(cnt == 0)
         continue;

      if(parts[0] == "HOLIDAY" && cnt >= 7)
        {
         holidayToday  = (StringToInteger(parts[1]) != 0);
         holidayActive = (StringToInteger(parts[2]) != 0);
         holidaySrc    = (int)StringToInteger(parts[3]);
         holidayName   = parts[4];
         holidayStart  = (datetime)StringToInteger(parts[5]);
         holidayEnd    = (datetime)StringToInteger(parts[6]);
        }
      else if(parts[0] == "EVENT" && cnt >= 3)
        {
         datetime t   = (datetime)StringToInteger(parts[1]);
         string   lb  = parts[2];
         // ★2026-07-08: 5番目に重要度を追加した新形式。旧形式ファイル(cnt<5)が
         //   残っていてもMODERATE扱いで読めるよう後方互換を維持する。
         int      imp = (cnt >= 5) ? (int)StringToInteger(parts[4]) : (int)CALENDAR_IMPORTANCE_MODERATE;
         ArrayResize(evTimes,  n + 1);
         ArrayResize(evLabels, n + 1);
         ArrayResize(evImportance, n + 1);
         evTimes[n]  = t;
         evLabels[n] = lb;
         evImportance[n] = imp;
         n++;
        }
     }
   FileClose(h);
   return true;
  }

//+------------------------------------------------------------------+
//| ★2026-07-08追加: JSON用のカテゴリコードへ変換(ai_comment.py側の    |
//|   format_mt5_key_events()がcategory in ("ISM","NFP")で絞り込むため、|
//|   ここで一致するコードに変換しておく。それ以外は将来のDB活用のため   |
//|   ラベルをそのままコードとして残す)                                 |
//+------------------------------------------------------------------+
string CategoryCode(const string label)
  {
   if(label == "雇用統計")   return "NFP";
   if(label == "ISM")        return "ISM";
   if(label == "CPI")        return "CPI";
   if(label == "PPI")        return "PPI";   // ★2026-07-15追加
   if(label == "小売売上高") return "小売売上高";   // ★2026-07-16(2回目)修正: RETAIL→日本語表記に統一
   if(label == "GDP")        return "GDP";
   if(label == "PCE")        return "PCE";
   if(label == "FOMC")       return "FOMC";
   if(label == "FOMC議事録") return "FOMC_MINUTES";
   return "SPEECH";   // 重要発言(パウエル)等はまとめてSPEECH
  }

//+------------------------------------------------------------------+
//| ★2026-07-08追加: MqlCalendarImportance整数値を文字列コードへ変換    |
//+------------------------------------------------------------------+
string ImportanceCode(int imp)
  {
   if(imp >= (int)CALENDAR_IMPORTANCE_HIGH)     return "HIGH";
   if(imp >= (int)CALENDAR_IMPORTANCE_MODERATE) return "MODERATE";
   return "LOW";
  }

//+------------------------------------------------------------------+
//| ★2026-07-08追加: JSON文字列値のエスケープ(バックスラッシュ/ダブル   |
//|   クォート/改行の最低限のみ。イベント名・休日名は通常これらを含まない|
//|   想定だが、将来の想定外データに備えて安全側に倒す)                 |
//+------------------------------------------------------------------+
string JsonEscape(const string s)
  {
   string r = s;
   StringReplace(r, "\\", "\\\\");
   StringReplace(r, "\"", "\\\"");
   StringReplace(r, "\r", " ");
   StringReplace(r, "\n", " ");
   return r;
  }

//+------------------------------------------------------------------+
//| ★2026-07-09追加: JSON出力専用の広範囲イベント取得(過去数日〜数週間先)。 |
//|   パネル(DrawPanel)・チャートマーカー(DrawChartMarkers)は「今日のみ」 |
//|   のfEvTimes等を今まで通り使い続けるため、この関数の結果はチャート   |
//|   表示に一切影響しない。JSON出力(=Python/DB連携)専用の独立処理。      |
//|   これにより、FOMC等の先の予定も「その日が来る前」からDBへ貯められる。|
//+------------------------------------------------------------------+
void SaveWideCalendarJson(int shift, datetime jstDayStart, int lookBackDays, int lookAheadDays)
  {
   datetime serverFrom = jstDayStart - shift - (datetime)lookBackDays * 86400;
   datetime serverTo   = jstDayStart - shift + (datetime)(lookAheadDays + 1) * 86400;

   MqlCalendarValue values[];
   int count = CalendarValueHistory(values, serverFrom, serverTo, "US");
   if(count < 0)
     {
      Print("[US_Calendar] 広範囲カレンダー取得失敗(JSON出力用): ", count);
      return;
     }

   datetime evTimes[]; string evLabels[]; int evImportance[];
   int n = 0;

   for(int i = 0; i < count; i++)
     {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev)) continue;
      if(ev.importance < CALENDAR_IMPORTANCE_MODERATE) continue;

      string label = ClassifyEvent(ev.name);
      if(label == "") continue;

      datetime t = values[i].time;

      // ★重複除去: ラベル+分単位のJST日時「全体」で判定する。
      //   複数日にまたがるため、時刻(hhmm)だけの比較では別日の同時刻イベントを誤って
      //   同一視してしまう(既存のUpdateDisplay側の当日限定dedupとは判定基準が異なる点に注意)。
      string fullKey = label + "|" + TimeToString(t + shift, TIME_DATE|TIME_MINUTES);
      bool dup = false;
      for(int j = 0; j < n; j++)
        {
         string kj = evLabels[j] + "|" + TimeToString(evTimes[j] + shift, TIME_DATE|TIME_MINUTES);
         if(kj == fullKey) { dup = true; break; }
        }
      if(dup) continue;

      ArrayResize(evTimes, n + 1);
      ArrayResize(evLabels, n + 1);
      ArrayResize(evImportance, n + 1);
      evTimes[n]  = t;
      evLabels[n] = label;
      evImportance[n] = (int)ev.importance;
      n++;
     }

   //--- 時刻昇順ソート
   for(int a = 0; a < n - 1; a++)
      for(int b = a + 1; b < n; b++)
         if(evTimes[b] < evTimes[a])
           {
            datetime tt = evTimes[a];  evTimes[a]  = evTimes[b];  evTimes[b]  = tt;
            string   ss = evLabels[a]; evLabels[a] = evLabels[b]; evLabels[b] = ss;
            int      ii = evImportance[a]; evImportance[a] = evImportance[b]; evImportance[b] = ii;
           }

   SaveCalendarToJson(jstDayStart, evTimes, evLabels, evImportance, n, shift);   // 既存の書き出し関数をそのまま再利用(各イベント自身の日付を使う実装のため広範囲でも正しく書ける)
  }

//+------------------------------------------------------------------+
//| ★2026-07-08追加: Python(ai_comment.py)連携用JSONを書き出す         |
//|   保存先: Common\Files\mt5_calendar_today.json                    |
//|   FILE_ANSI+CP_UTF8で書くことで、Python側のjson.load()(既定UTF-8) |
//|   がそのまま読める(FILE_UNICODEはUTF-16になり不一致を起こすため)。 |
//+------------------------------------------------------------------+
void SaveCalendarToJson(datetime jstDayStart, const datetime &evTimes[], const string &evLabels[],
                        const int &evImportance[], int n, int shift)
  {
   string dateStr = TimeToString(jstDayStart, TIME_DATE);
   StringReplace(dateStr, ".", "-");                          // "2026.07.08" → "2026-07-08"

   string nowStr = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   StringReplace(nowStr, ".", "-");

   string body = "";
   for(int i = 0; i < n; i++)
     {
      // ★2026-07-08修正: 各イベントごとの実際のJST日付+時刻を使う(従来はdateStr固定+hhmmだけを
      //   組み合わせていたため、サーバー時間との時差で日付を跨ぐイベント(例:FOMC 21:00server=翌03:00JST)
      //   の日付欄が誤って「今日」のまま表示される不具合があった)
      string evDateTime = TimeToString(evTimes[i] + shift, TIME_DATE|TIME_MINUTES);
      StringReplace(evDateTime, ".", "-");
      string cat        = CategoryCode(evLabels[i]);
      string imp        = ImportanceCode(evImportance[i]);

      if(i > 0) body += ",\r\n";
      body += StringFormat("    {\"time\":\"%s\",\"name\":\"%s\",\"importance\":\"%s\",\"category\":\"%s\"}",
                            evDateTime, JsonEscape(evLabels[i]), imp, cat);
     }

   string json = "{\r\n"
               + "  \"date\": \"" + dateStr + "\",\r\n"
               + "  \"generated_at\": \"" + nowStr + "\",\r\n"
               + "  \"events\": [\r\n" + body + (n > 0 ? "\r\n" : "") + "  ]\r\n"
               + "}\r\n";

   // ★codepage引数を使うオーバーロードのため delimiter は使わないが省略不可(0を渡す)
   int h = FileOpen(CAL_JSON_FILE, FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON, 0, CP_UTF8);
   if(h == INVALID_HANDLE)
     {
      Print("[US_Calendar] JSON出力ファイルを開けませんでした: ", CAL_JSON_FILE, " err=", GetLastError());
      return;
     }
   FileWriteString(h, json);
   FileClose(h);
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
