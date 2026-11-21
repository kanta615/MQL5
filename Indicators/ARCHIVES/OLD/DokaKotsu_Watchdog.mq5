//+------------------------------------------------------------------+
//|                         DokaKotsu_Watchdog.mq5                   |
//|  バージョン : v2.1 (矢印GV停止を常に検知・連携NGの通知)            |
//|  更新日時   : 2026-11-04 (JST・2回目)                             |
//|------------------------------------------------------------------|
//|  ■ 変更履歴                                                     |
//|   ○ 2026-11-09 11/9の朝、EAが08:00から11:40まで、矢印GVが古いために      |
//|      エントリーを見送り続けたのに、Watchdogが何も出さなかった問題の修正。       |
//|      原因: 連携先のGVは「止まってから6時間を超えたものは外したとみなして出さない」|
//|      仕様(InpOptGoneSec)を、本体インジの矢印GVにも当てていた。週末明けは、最後の  |
//|      更新が土曜のため48時間以上古く、「矢印GV停止」が表示されなかった。          |
//|      ①矢印GV(DK_SIG_TS)は、6時間の上限なしで、市場が開いている間は常に検知する。 |
//|        (VStop・RRインジは従来どおり6時間まで)                                  |
//|      ②新規エントリーができない連携NG(矢印GV停止・本体インジ未検出・EAの連携NG判定)|
//|        が InpLinkNotifyMin(既定3分)続いたら、スマホへ通知する(0=通知しない)。     |
//|   ○ 2026-11-06 「動きが鈍い」の見える化。最新ティックの時刻(TimeCurrent)と、  |
//|      最新のM1足の開始時刻の差=「足の遅れ」を測る(通常0〜60秒)。InpLagWarnSec |
//|      (既定150秒)を超えたら、連携NGの内訳に「処理遅れ ○分」を出す(橙。エントリー|
//|      は止めない)。InpLagNotifyMin(既定5分)続いたらスマホ通知(0=通知しない)。  |
//|      原因: 同じ銘柄のスレッドが、インジの計算で詰まると、足の更新が遅れる。     |
//|      ティックの受信(TimeCurrent)は進むので、差が開く。                        |
//|   ○ 2026-11-05(2回目) 指標(雇用統計など)の停止の出どころを、ダッシュボードと |
//|      同じCalendarインジに統一したのに合わせ、Calendarインジが止まって       |
//|      EAが従来の直接判定に切り替わっている時(GV DK_EA_EVSRC=2)は、           |
//|      連携NGの内訳に「カレンダー連携切れ」を出す(エントリーは止めない=橙)。   |
//|   ○ 2026-11-05 田島さんご指示。毎日の時間帯の停止の名前を表示に追加:       |
//|      「オセアニア市場停止」(4:00〜8:59)・「10時のみ取引停止」(10:00〜10:59)・|
//|      「日本市場午後停止」(13:00〜18:59)。分類は「時間帯」。例:              |
//|      Watchdog ： 取引停止中 / 時間帯(日本市場午後停止) / 連携OK            |
//|      (EAの停止理由コード20・21に対応。オセアニアの名前も「オセアニア市場停止」へ)|
//|   ○ 2026-11-04(4回目) 田島さんご指示。①先頭の表示を、EA稼働中/EA停止中から  |
//|      「取引中」/「取引停止中」に変更。新規エントリーができない状態は、     |
//|      全て「取引停止中」: EA停止・通信断・自動売買OFF・価格停止・市場休場・ |
//|      停止ルール中(経済指標など)・連携NG(EA判定/本体インジ未検出/矢印GV停止)。|
//|      正常は「取引中 / 連携OK」。理由は次に出す。例:                       |
//|        Watchdog ： 取引停止中 / 経済指標(ISM) / 連携OK                   |
//|        Watchdog ： 取引停止中 / 連携NG(矢印GV停止 11分)                   |
//|      VolatilityStop・RRインジの停止、理由ログ停止、EXIT継続なのに保有残存は、|
//|      新規エントリーは止まらないので「取引中」のまま警告だけ出す。          |
//|      ②「価格停止(… --)」と出て、チャートは動いているのに止まって見えた    |
//|      不具合を修正。原因=最後のティックの時刻が、PCから見たサーバー時刻より |
//|      先(PCの時計が遅れている)で、経過秒が負になり、「ティックが来ない」と |
//|      誤判定していた(従来の「市場休場」誤表示も同じ原因の可能性)。            |
//|      時計の差に頼らず、「ティックが更新され続けているか」でも見る方式に変更。|
//|   ○ 2026-11-04(3回目) 田島さんご指示で、「Watchdog ：」の右の先頭に、     |
//|      EA稼働中 / EA停止中 を出すようにした。EA稼働中=EAの心拍(GV)が       |
//|      InpEaTimeoutSec以内。EA停止中=心拍が途絶(従来の「EA停止」と同じ判定)。|
//|      例: Watchdog ： EA稼働中 / 経済指標(ISM) / 連携OK                    |
//|          Watchdog ： 🚨EA停止中 / EAを確認! / 連携NG(EA心拍切れ 2分)       |
//|      あわせて、停止がない時の分類名を、「稼働中」から「取引可」に変更      |
//|      (先頭の「EA稼働中」と重なって紛らわしいため)。                      |
//|      表示は1つのラベルなので、色は行全体の状態(赤/橙/黄/緑/灰)で変わる。    |
//|   ○ 2026-11-04(2回目) 「市場休場」の表示が、本当の休場と、通信断・価格が |
//|      来ない状態を見分けられなかった問題に対応(11/4の夜、取引時間中に    |
//|      ティックが止まったのに「市場休場」と出ていた)。                    |
//|      ①通信断: MT5が取引サーバーに接続していない(TERMINAL_CONNECTED=false)|
//|        時は「🚨通信断」(赤)。スマホ通知する。                           |
//|      ②価格停止: 接続はしているのに、その銘柄の取引時間中(気配の時間帯)に  |
//|        ティックが来ない時は「⚠価格停止(...)」(橙)。InpStallNotifyMin     |
//|        (既定10分)続いたらスマホ通知。0で通知しない。                     |
//|      ③市場休場: 取引時間の外の時だけ「⏸市場休場」(灰)。取引時間が取れない |
//|        場合は、従来どおり「市場休場」。                                  |
//|      ④通知の時間計算を、ティックが止まると進まないTimeCurrentから、      |
//|        進み続けるTimeTradeServerへ変更(ティックが止まっている間も、       |
//|        再通知・継続時間が正しく進む)。                                  |
//|   ○ 2026-11-04 田島さんご指示で、表示を作り直した(判定・通知・決済指示の|
//|      ロジックは変更なし)。                                          |
//|      ①1行表示「Watchdog ： 分類名 / 連携OK」に統一。停止の分類名は     |
//|        手動停止/成績停止/休日/週末/時間帯/経済指標。具体名を括弧で、     |
//|        重なっている停止の数を「+N」で添える。例: 経済指標(ISM) +1。    |
//|        分類の判定はEAだけが持つ(GV DK_EA_STOPCAT_/DK_EA_STOPCNT_)。     |
//|        停止なしは「稼働中」。EA停止・自動売買OFF・市場休場・理由ログ停止|
//|        ・EXIT継続なのに保有残存は、従来どおりの意味で、同じ書式で表示。 |
//|      ②時刻・EA心拍の秒数・「自動売買ON」は通常は出さない(異常時だけ:   |
//|        EA停止/自動売買OFF/連携NGの内訳に出す)。                        |
//|      ③連携NGの内訳を表示: EA心拍切れ・本体インジ未検出・矢印GV停止・     |
//|        VStop停止・RRインジ停止。連携先のGVは、止まってから6時間以内の   |
//|        ものだけ(外したものを出し続けない。InpOptGoneSec)。              |
//|      ④左端の「Label」を消した。空文字のラベルは、MT5が既定の「Label」を |
//|        表示するため、ラベルごと削除する方式に変更(損切り再決済の行も同じ)。|
//|        停止理由の3行目は廃止(1行に統合)。                              |
//|      ⑤チャート左上のMT5標準の見出しから価格(OHLC)を消す(InpHideOhlc。  |
//|        外した時は元の設定へ戻す)。「/ Spot」は銘柄の説明文で消せない。   |
//|      ⑥停止理由の名前表を、EAの停止理由コード1〜19に全て対応させた(従来は |
//|        1〜9だけで、日次損失上限・手動停止などが出なかった)。            |
//|   ○ 2026-09-09 EAハートビート/reasonログが生きていても、MT5端末   |
//|      側のアルゴ取引ボタンOFF(TERMINAL_TRADE_ALLOWED=false)や口座 |
//|      側のEA取引不許可(ACCOUNT_TRADE_EXPERT=false)で発注が          |
//|      ブロックされている状態(retcode 10027等)を「EA正常稼働」と    |
//|      誤表示していた問題を修正(田島さん報告)。Check()内で           |
//|      TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)と                |
//|      AccountInfoInteger(ACCOUNT_TRADE_EXPERT)をこのインジ自身が    |
//|      直接読む(EA側GVの書き忘れ・実装漏れに依存しない一箇所管理)。  |
//|      WD_TRADE_OFF状態を新設し、1行目見出しを🚨自動売買OFFに変更、  |
//|      スマホ通知(isBad)対象にも追加。                              |
//|------------------------------------------------------------------|
//|  役割:                                                           |
//|   ・DokaKotsu EA の生存(ハートビート)を GlobalVariable で監視     |
//|   ・理由CSV(reason)の書込み成功時刻を監視                         |
//|   ・★EAの停止理由(GV)を読み、RUNNING行の右に色付きで表示         |
//|   ・異常/復旧時にスマホ(SendNotification)へ通知                   |
//|   ・★EAの損切り「再決済(救済)」発火を読み、数分間チャートに表示  |
//|                                                                  |
//|  ■ チャート表示の意味(左上1行)                                 |
//|     DokaKotsu : RUNNING  hh:mm                     (緑) 取引可    |
//|     DokaKotsu : RUNNING  hh:mm ｜ オセアニア市場停止 (橙) 停止理由 |
//|     DokaKotsu : MARKET CLOSED  hh:mm               (灰) 相場休場  |
//|     DokaKotsu : REASON LOG STOPPED!  hh:mm         (橙) reason未更新|
//|     EA停止中: Warning: EA Stopped: ERROR  hh:mm    (赤) EA停止    |
//|     ※停止理由(橙)= オセアニア/金曜深夜/CPI/雇用統計/FOMC/米国休日/ |
//|        日本休日/連敗 を EA の GV から読んで表示。                 |
//|     末尾の時刻が更新され続ける=この監視自体が生きている証拠      |
//|                                                                  |
//|  ■ 置き場所/設定                                                |
//|   ・MQL5\Indicators\ に置く(EAではない)。UTF-8 BOMで保存。       |
//|   ・XAUUSDのチャートにドラッグ(EAと同じチャートでOK)。           |
//|   ・スマホ通知はツール>オプション>通知でMetaQuotes ID設定。      |
//|   ・監視対象EA(DokaKotsu_EA_8)が以下のGVを更新している前提:       |
//|       DK_EA_HB_<magic>         … EA生存(OnTimerでサーバー時刻)    |
//|       DK_EA_LASTREASON_<magic> … 理由CSV書込み成功時刻           |
//|       DK_EA_STOPREASON_<magic> … ★現在の停止理由コード(0=取引可) |
//|       DK_EA_LOSSSTREAK_<magic> … 連敗数(連敗表示用)              |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "2.10"
#property strict
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

//--- 監視対象
input int    InpMagic          = 20260606; // 監視対象EAのマジック(GV名に使用)
input string InpWatchSymbol    = "";        // 市場開閉判定に使う銘柄(空=このチャートの銘柄)
//--- しきい値
input int    InpCheckSec       = 10;        // 監視間隔(秒)
input int    InpEaTimeoutSec   = 90;        // EAハートビートがこの秒数途絶で「EA停止」(HB30秒×3)
input int    InpReasonStaleSec = 480;       // 市場オープン中、理由CSVがこの秒数未更新で「reason停止」
input int    InpTickStaleSec   = 120;       // 直近ティックがこの秒数以内なら「市場オープン」と判定
//--- 表示
input int    InpFontSize       = 10;        // メイン表示の文字サイズ
input int    InpCorner         = 0;         // 表示位置(0=左上 1=右上 2=左下 3=右下)
input int    InpX              = 12;        // X余白(px)
input int    InpY              = 18;        // Y余白(px)
//--- 通知(スマホのみ。インジはDiscord/WebRequest不可)
input bool   InpUseNotify      = true;      // スマホプッシュ(SendNotification)
input int    InpResendMin      = 30;        // 異常継続中の再通知間隔(分。0=最初の1回のみ)
input bool   InpNotifyRecover  = true;      // 復旧時も通知するか
//--- ★損切り救済(EAの再決済)表示
input int    InpRescueShowMin  = 5;         // 損切り再決済を検知したら、この分数だけ2行目に表示
input bool   InpHideOhlc       = true;      // ★2026-11-04: チャート左上のMT5標準の見出しから価格(OHLC)を消す(外した時は元の設定へ戻す)
input int    InpOptStaleSec    = 180;       // ★2026-11-04: 連携先(矢印GV/VolatilityStop/RRインジ)の生存確認がこの秒数より古ければ、連携NGの内訳に出す
input int    InpLinkNotifyMin  = 3;         // ★2026-11-09: 新規エントリーができない連携NG(矢印GV停止など)がこの分数続いたらスマホ通知(0=通知しない)
input int    InpLagWarnSec     = 150;       // ★2026-11-06: 足の遅れ(最新ティックの時刻−最新M1足の開始時刻)がこの秒数を超えたら「処理遅れ」と出す(0=無効)
input int    InpLagNotifyMin   = 5;         // ★2026-11-06: 処理遅れがこの分数以上続いたらスマホ通知(0=通知しない)
input int    InpStallNotifyMin = 10;        // ★2026-11-04(2回目): 「価格停止」(取引時間中のティック無し)がこの分数続いたらスマホ通知(0=通知しない)
input int    InpOptGoneSec     = 21600;     // ★2026-11-04: 上より古く、この秒数も超えたものは「外した」とみなして出さない(既定6時間)
//--- ★決済の安全網(見張り+緊急ブザー)
input string InpIndicatorPrefix = "DokaKotsu_indicator_"; // ★2026-07-08変更: 監視する本体インジ名の"接頭辞"のみ指定。バージョン番号(_10/_13等)は自動検出するため毎回の手動更新が不要
input bool   InpForceExit      = true;      // ★EXIT継続なのに保有残存(背景も保有方向でない)を検知→EAへ決済指示(GV)
input int    InpStuckGraceSec  = 20;        // ★その状態がこの秒数続いたら決済指示を発令(EAの自力決済を待つ猶予)

//--- 状態
enum WD_STATE { WD_OK=0, WD_MARKET_CLOSED=1, WD_REASON_DOWN=2, WD_EA_DOWN=3, WD_TRADE_OFF=4, WD_DISCONNECTED=5, WD_PRICE_STALL=6, WD_LAG=7, WD_LINK=8 };   // ★2026-11-09: 連携NG(新規エントリー不可)を追加   // ★2026-11-06: 処理遅れを追加   // ★2026-11-04(2回目): 通信断/価格停止を追加  // ★2026-09-09追加: WD_TRADE_OFF(自動売買OFF)
WD_STATE  g_prev      = WD_OK;
datetime  g_lastAlert = 0;
long      g_tickMsc    = 0;       // ★2026-11-04(4回目): 前回見た最後のティックのミリ秒時刻(更新の検出用)
ulong     g_tickChgMs  = 0;       // ★2026-11-04(4回目): ティックが更新されたのを最後に見たPC時刻(GetTickCount64。時計のずれの影響を受けない)
int       g_barLag     = 0;       // ★2026-11-06: 足の遅れ(秒)
bool      g_lagging    = false;   // ★2026-11-06: 処理遅れ中か
datetime  g_linkSince  = 0;       // ★2026-11-09: 連携NG(新規エントリー不可)が始まった時刻(TimeTradeServer基準)
datetime  g_stallSince = 0;       // ★2026-11-04(2回目): 「価格停止」が始まった時刻(TimeTradeServer基準)
bool      g_prevBad    = false;   // ★2026-11-04(2回目): 直前が通知対象の異常だったか
bool      g_notifiedBad= false;   // ★2026-11-04(2回目): 異常をスマホへ通知済みで、復旧の通知がまだか
bool      g_started   = false;
string    LBL_MAIN   = "DKWD_main";
string    LBL_RESCUE = "DKWD_rescue";       // ★損切り救済の2行目ラベル
string    LBL_REASON = "DKWD_reason";       // ★2026-11-04: 廃止(1行に統合)。旧版が残したラベルを消すためだけに名前を持つ
long      g_prevOhlc       = -1;            // ★2026-11-04: OHLC表示の元の設定
bool      g_ohlcHidden     = false;         // ★2026-11-04: このインジがOHLCを消したか
datetime  g_lastRescueSeen = 0;             // ★直近で通知済みの救済時刻(再通知防止)
int       g_ind            = INVALID_HANDLE; // ★本体インジ(buf9/buf25)ハンドル
string    g_indNameSeen    = "";            // ★直近で見つけた実名(ログ確認用)

//+------------------------------------------------------------------+
//| ★2026-07-08追加: チャートに実際に貼られている本体インジを         |
//|   接頭辞(InpIndicatorPrefix)だけで探す。バージョン番号(_10/_13等) |
//|   が変わってもハードコード不要。全サブウィンドウを走査。          |
//+------------------------------------------------------------------+
int FindDokaKotsuHandle()
{
   int winTotal = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for(int w = 0; w < winTotal; w++)
   {
      int total = ChartIndicatorsTotal(0, w);
      for(int i = 0; i < total; i++)
      {
         string name = ChartIndicatorName(0, w, i);
         if(StringFind(name, InpIndicatorPrefix) != 0) continue;   // 前方一致しなければスキップ

         if(name == g_indNameSeen && g_ind != INVALID_HANDLE)
            return g_ind;   // ★同じインジのまま→再取得せず使い回す(ハンドルリーク防止)

         int h = ChartIndicatorGet(0, w, name);
         if(h != INVALID_HANDLE)
         {
            if(g_ind != INVALID_HANDLE && g_ind != h) IndicatorRelease(g_ind);   // 差し替わったら古い方を解放
            Print("[Watchdog] 本体インジ検出: ", name, (g_indNameSeen=="") ? "" : (" (前回: "+g_indNameSeen+")"));
            g_indNameSeen = name;
            return h;
         }
      }
   }
   return INVALID_HANDLE;
}
datetime  g_stuckSince     = 0;             // ★EXIT継続なのに保有残存を最初に検知した時刻
datetime  g_lastForceNotice= 0;             // ★決済指示の通知再送防止

//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(InpCheckSec > 0 ? InpCheckSec : 10);
   g_ind = FindDokaKotsuHandle();   // ★2026-07-08変更: バージョン番号を問わず自動検出
   if(InpHideOhlc)   // ★2026-11-04: MT5標準の見出し(銘柄, 時間足: 説明 価格)から、価格(OHLC)を消す
   {
      g_prevOhlc   = ChartGetInteger(0, CHART_SHOW_OHLC);
      ChartSetInteger(0, CHART_SHOW_OHLC, false);
      g_ohlcHidden = true;
   }
   ObjectDelete(0, LBL_REASON);   // ★2026-11-04: 旧版の3行目ラベルが残っていたら消す
   CreateLabel(LBL_MAIN, InpY, InpFontSize, clrSilver, "Watchdog ： starting...");
   Check();   // 即時1回
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| 描画はしない(監視専用)。OnCalculateは形だけ用意。                |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   return(rates_total);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(g_ind != INVALID_HANDLE) IndicatorRelease(g_ind);
   ObjectDelete(0, LBL_MAIN);
   ObjectDelete(0, LBL_RESCUE);
   ObjectDelete(0, LBL_REASON);
   if(g_ohlcHidden && g_prevOhlc >= 0) ChartSetInteger(0, CHART_SHOW_OHLC, g_prevOhlc);   // ★2026-11-04: OHLC表示を元へ戻す
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void OnTimer() { Check(); }

//+------------------------------------------------------------------+
//| ★本体インジのバッファ読取(buf9 EXIT / buf25 背景方向)          |
//+------------------------------------------------------------------+
double ReadIndV(int buf, int shift)
{
   if(g_ind == INVALID_HANDLE) return 0.0;
   double a[];
   if(CopyBuffer(g_ind, buf, shift, 1, a) > 0) return a[0];
   return 0.0;
}
bool ReadIndNonEmpty(int buf, int shift)
{
   double v = ReadIndV(buf, shift);
   return (v != 0.0 && v != EMPTY_VALUE && MathIsValidNumber(v));
}
//--- ★自分のマジックの保有方向(1=買い/-1=売り/0=無し)
int GetMyPos()
{
   string sym = (StringLen(InpWatchSymbol) > 0) ? InpWatchSymbol : _Symbol;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != sym) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
   }
   return 0;
}
//--- ★年月日+時刻スタンプ "2026-06-30 14:25:33"
string NowStamp()
{
   MqlDateTime d; TimeToStruct(TimeLocal(), d);
   return StringFormat("%04d-%02d-%02d %02d:%02d:%02d", d.year, d.mon, d.day, d.hour, d.min, d.sec);
}

//+------------------------------------------------------------------+
//| ★2026-11-04(2回目): いま(サーバー時間)が、その銘柄の「気配が来るはずの時間帯」か。                |
//|   1=時間帯の中 / 0=時間帯の外(週末・休止) / -1=時間帯の情報が取れない(判断できない)。         |
//+------------------------------------------------------------------+
int QuoteSessionState(const string sym, const datetime nowSrv)
{
   MqlDateTime d; TimeToStruct(nowSrv, d);
   int tod = d.hour*3600 + d.min*60 + d.sec;
   ENUM_DAY_OF_WEEK dow = (ENUM_DAY_OF_WEEK)d.day_of_week;
   bool any = false;
   for(uint i = 0; i < 16; i++)
   {
      datetime f, t;
      if(!SymbolInfoSessionQuote(sym, dow, i, f, t)) break;
      any = true;
      int fs = (int)(((long)f) % 86400);
      int te = (int)t;  if(te > 86400) te = te % 86400;   // 24:00は86400のまま扱う
      if(te == 0 && t > 0) te = 86400;
      if(tod >= fs && tod < te) return 1;
   }
   return any ? 0 : -1;
}

//+------------------------------------------------------------------+
//| 監視本体                                                         |
//+------------------------------------------------------------------+
void Check()
{
   int foundInd = FindDokaKotsuHandle();   // ★2026-07-08変更: 毎回検出し直す(バージョン差し替えに追従・見つからなければ直前のハンドルを維持)
   if(foundInd != INVALID_HANDLE) g_ind = foundInd;

   datetime now    = TimeCurrent();        // EA HB/理由の比較用(EA側もTimeCurrentで記録)
   datetime nowTrd = TimeTradeServer();    // ★市場開閉用:ティックが無い土日も進み続ける時計
   string   sym = (StringLen(InpWatchSymbol) > 0) ? InpWatchSymbol : _Symbol;

   // --- 1) EA生存(ハートビートGVの鮮度) ---
   string   hbName = StringFormat("DK_EA_HB_%d", InpMagic);
   bool     hbEx   = GlobalVariableCheck(hbName);
   datetime hb     = hbEx ? (datetime)GlobalVariableGet(hbName) : 0;
   int      eaAge  = hbEx ? (int)(now - hb) : -1;
   bool     eaDown = (!hbEx) || (eaAge < 0) || (eaAge > InpEaTimeoutSec);

   // --- 2) 市場オープン判定(直近ティック鮮度)。TimeCurrentはティック時刻=土日は止まるため不可 ---
   MqlTick tk;
   bool    gotTick    = SymbolInfoTick(sym, tk);
   int     tickAge    = gotTick ? (int)(nowTrd - tk.time) : 999999;   // 進み続ける時計で測る(PCの時計とサーバー時刻の差の影響を受ける)
   // ★2026-11-04(4回目)修正: PCの時計が遅れていると、最後のティックの時刻がPC側の「いまのサーバー時刻」より先になり、tickAgeが負になる。
   //   従来はこれを「ティックが来ない」と誤判定し、チャートが動いているのに「市場休場/価格停止」と出ていた。
   //   tickAgeが負の時は、時計の差に頼らず、「最後のティックが更新され続けているか(最後に更新を見てからの経過秒)」で鮮度を見る。
   ulong   nowMs      = GetTickCount64();
   if(gotTick && (long)tk.time_msc != g_tickMsc) { g_tickMsc = (long)tk.time_msc; g_tickChgMs = nowMs; }
   int     sinceChg   = (g_tickChgMs > 0) ? (int)((nowMs - g_tickChgMs) / 1000) : 999999;
   int     staleAge   = (gotTick && tickAge < 0) ? sinceChg : tickAge;     // 鮮度(秒)
   bool    marketOpen = gotTick && staleAge <= InpTickStaleSec;

   // --- 3) 理由CSVの健全性(書込み成功時刻GV。市場オープン中のみ厳格判定) ---
   string   rsName = StringFormat("DK_EA_LASTREASON_%d", InpMagic);
   bool     rsEx   = GlobalVariableCheck(rsName);
   datetime rs     = rsEx ? (datetime)GlobalVariableGet(rsName) : 0;
   int      rsAge  = rsEx ? (int)(now - rs) : -1;
   bool reasonDown = (!eaDown) && marketOpen &&
                     ((!rsEx) || (rsAge < 0) || (rsAge > InpReasonStaleSec));

   // --- ★2026-09-09追加: MT5端末側の自動売買許可(ハートビート/reasonログとは別問題)。
   //     TERMINAL_TRADE_ALLOWED=ツールバーのアルゴ取引ボタン、ACCOUNT_TRADE_EXPERT=口座側の
   //     EA取引許可。どちらもEAではなくこのインジ自身から直接読める値なので、EA側のGV書き忘れに
   //     依存せずここ一箇所で判定する(retcode 10027="AutoTrading disabled by client terminal"対策)。
   bool algoOk = (bool)TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && (bool)AccountInfoInteger(ACCOUNT_TRADE_EXPERT);

   // --- ★2026-11-04(2回目): 通信断/価格停止/市場休場を見分ける ---
   //     通信断   : MT5が取引サーバーに接続していない(TERMINAL_CONNECTED=false)
   //     価格停止 : 接続はしている・その銘柄の気配の時間帯の中・なのにティックが来ない(InpTickStaleSec超)
   //     市場休場 : 気配の時間帯の外(週末・休止)。時間帯の情報が取れない時も、従来どおり休場とする
   bool connected = (bool)TerminalInfoInteger(TERMINAL_CONNECTED);
   int  inSess    = (connected && !marketOpen) ? QuoteSessionState(sym, nowTrd) : 0;

   // --- ★2026-11-06追加: 処理遅れ(足の遅れ)。ティックの受信(TimeCurrent)は進むのに、足の更新が追いつかない状態を測る ---
   //     同じ銘柄のスレッドで、インジの計算が詰まると、最新のM1足の開始時刻が遅れる(通常は0〜60秒)。
   datetime bar0 = (datetime)iTime(sym, PERIOD_M1, 0);
   g_barLag  = (bar0 > 0) ? (int)(TimeCurrent() - bar0) : 0;
   g_lagging = (InpLagWarnSec > 0 && marketOpen && g_barLag > InpLagWarnSec);

   // --- ★2026-11-09追加: 新規エントリーができない連携NG(矢印GV停止など)を、状態の判定の前に求める ---
   bool linkBlockE = false;
   string issuesE  = LinkIssues(eaDown, eaAge, linkBlockE);
   if(!(GlobalVariableCheck(StringFormat("DK_EA_LINKOK_%d", InpMagic)) && GlobalVariableGet(StringFormat("DK_EA_LINKOK_%d", InpMagic)) != 0.0)) linkBlockE = true;   // EA自身が連携NGと判定

   // --- 総合状態 ---
   WD_STATE st;
   if(eaDown)           st = WD_EA_DOWN;
   else if(!connected)  st = WD_DISCONNECTED;   // ★2026-11-04(2回目)
   else if(!algoOk)     st = WD_TRADE_OFF;   // ★2026-09-09追加: プロセスは生きていても発注不可
   else if(reasonDown)  st = WD_REASON_DOWN;
   else if(!marketOpen) st = (inSess == 1) ? WD_PRICE_STALL : WD_MARKET_CLOSED;   // ★2026-11-04(2回目)
   else if(linkBlockE)  st = WD_LINK;          // ★2026-11-09: 連携NG(新規エントリー不可。矢印GV停止など)
   else if(g_lagging)   st = WD_LAG;           // ★2026-11-06: 処理遅れ
   else                 st = WD_OK;

   // --- ★EAの停止理由(GV)を読む。RUNNING行の右に出す ---
   int rcode   = ReadStopReason();
   int lstreak = ReadLossStreak();

   // --- ★安全網: EXIT(buf9)継続なのに保有残存(背景buf25も保有方向でない=決済すべき) → EAへ決済指示 ---
   int  posDir   = GetMyPos();
   bool hasPos   = (posDir != 0);
   bool exitSig  = ReadIndNonEmpty(9,0) || ReadIndNonEmpty(9,1);   // EXITが現/確定足で出ている
   int  bgDir    = (int)MathRound(ReadIndV(25,1));                 // 確定足の背景方向(1/0/-1)
   bool exitWorthy = hasPos && (bgDir != posDir);                  // 背景が保有方向でない(グレー/逆)=決済すべき
   bool stuck    = hasPos && exitSig && exitWorthy;
   if(stuck){ if(g_stuckSince==0) g_stuckSince=now; }
   else     { g_stuckSince=0; }
   bool fire = stuck && InpForceExit && (now - g_stuckSince) >= InpStuckGraceSec;

   string reqNm = StringFormat("DK_WD_EXITREQ_%d", InpMagic);
   if(fire)
      GlobalVariableSet(reqNm, 33.0);                              // ★EAが受けて即決済+再送(手法33)
   else if(!hasPos && GlobalVariableCheck(reqNm) && GlobalVariableGet(reqNm)!=0.0)
      GlobalVariableSet(reqNm, 0.0);                               // フラット化→指示を下ろす

   // --- チャート表示(★2026-11-04: 1行「Watchdog ： 分類名 / 連携OK」。時刻・心拍秒数・自動売買ONは異常時だけ) ---
   bool tradeOk = GlobalVariableCheck(StringFormat("DK_EA_TRADEOK_%d",InpMagic)) && GlobalVariableGet(StringFormat("DK_EA_TRADEOK_%d",InpMagic))!=0.0;
   bool linkOk  = GlobalVariableCheck(StringFormat("DK_EA_LINKOK_%d", InpMagic)) && GlobalVariableGet(StringFormat("DK_EA_LINKOK_%d", InpMagic))!=0.0;
   string ts   = NowStamp();
   bool   linkBlock = false;
   string issues = LinkIssues(eaDown, eaAge, linkBlock);      // 連携NGの内訳(EA心拍切れ/本体インジ未検出/矢印GV停止/VStop停止/RRインジ停止)
   bool   linkNg = (!linkOk) || (issues != "");
   if(!linkOk) linkBlock = true;                              // EA自身が「連携NG」と判定している時も、新規エントリーはできない扱い
   string link   = linkNg ? ("連携NG(" + (issues != "" ? issues : "EA判定") + ")") : "連携OK";
   int    cat    = ReadStopCat();
   int    cnt    = ReadStopCnt();
   color  c; string head = "";
   bool   blocked = false;   // ★2026-11-04(4回目): 新規エントリーができない状態か(true→先頭は「取引停止中」)
   if(eaDown)            { c=clrRed;    head = "🚨EA停止中(EAを確認!)"; blocked = true; }
   else if(!connected)   { c=clrRed;    head = "🚨通信断(MT5が取引サーバーに接続していません)"; blocked = true; }
   else if(stuck)        { c=clrRed;    head = "🚨EXIT継続なのに保有残存" + (fire ? "(決済指示発令)" : "(監視中)"); }   // 新規エントリーは止まらない(警告)
   else if(!algoOk)      { c=clrRed;    head = "🚨自動売買OFF(Ctrl+Eを確認)"; blocked = true; }
   else if(!marketOpen)  {
                           blocked = true;
                           if(inSess == 1) { c=clrOrange; head = "⚠価格停止(取引時間中なのにティックが来ません " + (gotTick ? AgeTxt(staleAge) : "ティックなし") + ")"; }   // ★2026-11-04(2回目)
                           else            { c=clrSilver; head = "⏸市場休場"; }
                         }
   else if(reasonDown)   { c=clrOrange; head = "⚠理由ログ停止"; }   // 取引は続く(警告)
   else if(rcode>0)      { c=clrGold;   blocked = true;
                           string det = StopDetail(rcode, lstreak);
                           head = (cat>0) ? (CatName(cat) + "(" + det + ")") : det;     // 分類GVが無い古いEAでも、具体名だけは出す
                           if(cnt>1) head += " +" + IntegerToString(cnt-1); }
   else                  { c=clrLime; }                         // 正常: 理由の欄は出さない
   if(linkBlock) { blocked = true; if(c!=clrRed) c = clrRed; }   // 矢印GVが止まっている等=EAは入れない→赤
   else if(linkNg && c!=clrRed) c = clrOrange;                  // VStop/RRインジの停止は警告色(エントリーは止まらない)
   string main = "Watchdog ： " + (blocked ? "取引停止中" : "取引中") + (head != "" ? " / " + head : "") + " / " + link;   // ★2026-11-04(4回目)
   SetLabel(LBL_MAIN, c, main);
   SetLabel(LBL_REASON, clrOrange, "");                         // ★2026-11-04: 3行目は廃止(旧版のラベルが残っていれば消える)

   // 決済指示を発令したらスマホ通知(5分再送防止)
   if(fire && (g_lastForceNotice==0 || (now-g_lastForceNotice)>=300))
   {
      Notify("【!】DokaKotsu 保有残存→決済指示発令 "+ts);
      g_lastForceNotice = now;
   }
   if(!stuck) g_lastForceNotice = 0;
   ShowRescue();   // ★損切り再決済(救済)を2行目に数分表示
   ChartRedraw(0);

   // --- 通知(状態変化 or 一定間隔で再送) ---
   //   ★2026-11-04(2回目): 時間計算はnowTrd(TimeTradeServer。ティックが止まっても進む)で行う。
   //   通知対象: EA停止/reasonログ停止/自動売買OFF/通信断、および価格停止がInpStallNotifyMin分以上続いた時。
   if(st == WD_PRICE_STALL) { if(g_stallSince == 0) g_stallSince = nowTrd; }
   else                       g_stallSince = 0;
   bool stallLong = (st == WD_PRICE_STALL && InpStallNotifyMin > 0 && g_stallSince > 0 &&
                     (nowTrd - g_stallSince) >= (datetime)InpStallNotifyMin*60);
   if(st == WD_LINK) { if(g_linkSince == 0) g_linkSince = nowTrd; }
   else                g_linkSince = 0;
   bool linkLong = (st == WD_LINK && InpLinkNotifyMin > 0 && g_linkSince > 0 && (nowTrd - g_linkSince) >= (datetime)InpLinkNotifyMin*60);   // ★2026-11-09
   bool lagLong = (st == WD_LAG && InpLagNotifyMin > 0 && g_barLag >= InpLagNotifyMin * 60);   // ★2026-11-06
   bool isBad = (st==WD_EA_DOWN || st==WD_REASON_DOWN || st==WD_TRADE_OFF || st==WD_DISCONNECTED || stallLong || lagLong || linkLong);   // ★2026-09-09追加: WD_TRADE_OFFも通知対象
   if(isBad)
   {
      bool changed = g_started && ((!g_prevBad) || (st != g_prev));
      bool firstBad= (!g_started);   // 起動直後から異常なら即通知
      bool resend  = (InpResendMin > 0 && g_lastAlert > 0 &&
                      (nowTrd - g_lastAlert) >= (datetime)InpResendMin*60);
      if(changed || firstBad || resend)
      {
         string head = (st==WD_EA_DOWN)       ? "【!】DokaKotsu EA停止"
                     : (st==WD_TRADE_OFF)     ? "【!】DokaKotsu 自動売買OFF(発注不可)"   // ★2026-09-09追加
                     : (st==WD_DISCONNECTED)  ? "【!】DokaKotsu 通信断(MT5が取引サーバーに接続していません)"   // ★2026-11-04(2回目)
                     : (st==WD_LINK)          ? ("【!】DokaKotsu 連携NG(新規エントリーできません): " + issuesE)   // ★2026-11-09
                     : (st==WD_LAG)           ? ("【!】DokaKotsu 処理遅れ(足が" + AgeTxt(g_barLag) + "遅れ。インジの計算が追いついていません)")   // ★2026-11-06
                     : (st==WD_PRICE_STALL)   ? ("【!】DokaKotsu 価格停止(取引時間中なのに最後のティックから" + (gotTick ? AgeTxt(staleAge) : "--") + ")")   // ★2026-11-04(2回目)
                                              : "【!】DokaKotsu reasonログ停止";
         string msg  = StringFormat("%s (EA最終%s前 / reason%s前) %s JST",
                          head, AgeTxt(eaAge), AgeTxt(rsAge),
                          TimeToString(TimeLocal(), TIME_MINUTES));
         Notify(msg);
         g_lastAlert   = nowTrd;
         g_notifiedBad = true;
      }
   }
   else
   {
      // 復旧通知(直前が異常 → 正常/クローズ)
      //   ★2026-11-04(2回目): 通知した異常は、正常(または休場)に戻った時に1回だけ復旧通知する。通信断から復帰した直後に価格がまだ来ない
      //   (価格停止・まだ短い)間は、復旧とは言わない。通知していない短い価格停止の終了では、復旧通知は出さない。
      if(g_notifiedBad && (st==WD_OK || st==WD_MARKET_CLOSED))
      {
         if(InpNotifyRecover && g_started)
            Notify(StringFormat("【OK】DokaKotsu 復旧: %s  %s JST",
                   main, TimeToString(TimeLocal(), TIME_MINUTES)));
         g_notifiedBad = false;
      }
      g_lastAlert = 0;
   }
   g_prevBad = isBad;
   g_prev    = st;
   g_started = true;
}

//+------------------------------------------------------------------+
//| ★EAの損切り「再決済(救済)」を2行目に数分表示し、新規ならスマホ通知|
//|   EAが書くGV: DK_EA_LASTRESCUE_<magic>(時刻) / _RESCUEPIP_ / _RESCUEKIND_|
//+------------------------------------------------------------------+
void ShowRescue()
{
   string nm = StringFormat("DK_EA_LASTRESCUE_%d", InpMagic);
   if(!GlobalVariableCheck(nm)) { SetLabel(LBL_RESCUE, clrSilver, ""); return; }
   datetime rt = (datetime)GlobalVariableGet(nm);
   if(rt <= 0)  { SetLabel(LBL_RESCUE, clrSilver, ""); return; }
   int age = (int)(TimeCurrent() - rt);                 // EA側もTimeCurrentで記録
   if(age < 0 || age > InpRescueShowMin*60)             // 古い=表示しない
   {
      SetLabel(LBL_RESCUE, clrSilver, "");
      g_lastRescueSeen = rt;                            // 既知扱い(再通知しない)
      return;
   }
   double pip  = GlobalVariableCheck(StringFormat("DK_EA_RESCUEPIP_%d", InpMagic))
                 ? GlobalVariableGet(StringFormat("DK_EA_RESCUEPIP_%d", InpMagic)) : 0.0;
   int    kind = GlobalVariableCheck(StringFormat("DK_EA_RESCUEKIND_%d", InpMagic))
                 ? (int)GlobalVariableGet(StringFormat("DK_EA_RESCUEKIND_%d", InpMagic)) : 1;
   string knd  = (kind==2)?"緊急逆行":(kind==3)?"イベント":(kind==4)?"週末":"✖滑り救済";
   string tmh  = TimeToString(TimeLocal(), TIME_MINUTES);
   SetLabel(LBL_RESCUE, clrAqua,
            StringFormat("直近: 損切り再決済 %.1fpip (%s) %s", pip, knd, tmh));
   // 新規(時刻が変わった)ならスマホ通知。起動直後の既存分は通知しない。
   if(rt != g_lastRescueSeen)
   {
      if(g_started && InpUseNotify)
         SendNotification(StringFormat("【救済】DokaKotsu 損切り再決済 %.1fpip (%s) %s JST",
                          pip, knd, tmh));
      g_lastRescueSeen = rt;
   }
}

//+------------------------------------------------------------------+
//| ★EAが書く停止理由GVを読む                                        |
//+------------------------------------------------------------------+
int ReadStopReason()
{
   string nm = StringFormat("DK_EA_STOPREASON_%d", InpMagic);
   if(!GlobalVariableCheck(nm)) return 0;
   return (int)GlobalVariableGet(nm);
}
int ReadLossStreak()
{
   string nm = StringFormat("DK_EA_LOSSSTREAK_%d", InpMagic);
   if(!GlobalVariableCheck(nm)) return 0;
   return (int)GlobalVariableGet(nm);
}
//--- ★2026-11-04: 停止の分類(EAが GV DK_EA_STOPCAT_<magic> で公開する番号 → 表示名。分類の判定はEAだけが持つ)
string CatName(int cat)
{
   switch(cat)
   {
      case 1: return "手動停止";
      case 2: return "成績停止";
      case 3: return "休日";
      case 4: return "週末";
      case 5: return "時間帯";
      case 6: return "経済指標";
   }
   return "";
}
int ReadStopCat()
{
   string nm = StringFormat("DK_EA_STOPCAT_%d", InpMagic);
   if(!GlobalVariableCheck(nm)) return 0;
   return (int)GlobalVariableGet(nm);
}
int ReadStopCnt()   // 効いている停止の数(1なら単独。2以上なら、表示した1つのほかに重なっている)
{
   string nm = StringFormat("DK_EA_STOPCNT_%d", InpMagic);
   if(!GlobalVariableCheck(nm)) return 0;
   return (int)GlobalVariableGet(nm);
}
//--- 停止理由コード → 具体名(EA側 DK_StopReasonCode の1〜21に全て対応。括弧の中に出す短い名前)
string StopDetail(int code, int streak)
{
   switch(code)
   {
      case 1:  return "オセアニア市場停止";
      case 2:  return "金曜深夜";
      case 3:  return "CPI";
      case 4:  return "雇用統計";
      case 5:  return "FOMC";
      case 6:  return "米国休日";
      case 7:  return "正月休み";
      case 8:  return StringFormat("連敗%d", streak);
      case 9:  return "週末クローズ前";
      case 10: return "日次損失上限";
      case 11: return "ISM";
      case 12: return "PPI";
      case 13: return "ダッシュボード";
      case 14: return "小売売上高";
      case 15: return "日本祝日";
      case 16: return "NY値幅超過";
      case 17: return "取引時間外";
      case 18: return "PCE";
      case 19: return "イベント予防線";
      case 20: return "10時のみ取引停止";    // ★2026-11-05
      case 21: return "日本市場午後停止";    // ★2026-11-05
   }
   return "コード" + IntegerToString(code);
}

//--- ★2026-11-04: 連携先の生存確認(GV)。止まってから InpOptGoneSec(既定6時間)以内のものだけ出す(外したものを出し続けない)
string OptIssue(const string label, const string tsName, const bool noCutoff = false)
{
   if(!GlobalVariableCheck(tsName)) return "";
   int age = (int)(TimeCurrent() - (datetime)GlobalVariableGet(tsName));
   // ★2026-11-09: noCutoff=true(本体インジの矢印GV)は、InpOptGoneSec(6時間)の上限をつけない。週末明けは、最後の更新が土曜で48時間以上古く、
   //   上限をつけると「矢印GV停止」が出ず、EAが見送っているのに、Watchdogが何も出さなかった。
   if(age > InpOptStaleSec && (noCutoff || age <= InpOptGoneSec)) return label + " " + AgeTxt(age);
   return "";
}
//--- 連携NGの内訳(空文字=問題なし)
string LinkIssues(const bool eaDown, const int eaAge, bool &blocking)   // blocking: 新規エントリーができなくなる内訳(EA心拍切れ/本体インジ未検出/矢印GV停止)があるか
{
   string s = "", x;
   blocking = false;
   if(eaDown) { s = "EA心拍切れ " + AgeTxt(eaAge); blocking = true; }
   if(g_ind == INVALID_HANDLE) { s += (s != "" ? "・" : "") + "本体インジ未検出"; blocking = true; }
   long cid = ChartID();
   x = OptIssue("矢印GV停止",   StringFormat("DK_SIG_TS_%I64d",   cid), true); if(x != "") { s += (s != "" ? "・" : "") + x; blocking = true; }   // EAは矢印GVが古い(InpSigStaleSec=180秒)と入らない
   x = OptIssue("VStop停止",    StringFormat("DK_VSTOP_TS_%I64d", cid)); if(x != "") s += (s != "" ? "・" : "") + x;
   x = OptIssue("RRインジ停止", StringFormat("YDS_TS_%I64d",      cid)); if(x != "") s += (s != "" ? "・" : "") + x;
   // ★2026-11-06追加: 処理遅れ(足の遅れ)。エントリーは止めないが、判断が古い足で行われる状態
   if(g_lagging) s += (s != "" ? "・" : "") + "処理遅れ " + AgeTxt(g_barLag);
   // ★2026-11-05(2回目): 指標の出どころ。2=Calendarインジが止まっていて、EAが従来の直接判定に切り替わっている(ダッシュボードと分類がずれるおそれ)
   string evsrc = StringFormat("DK_EA_EVSRC_%d", InpMagic);
   if(GlobalVariableCheck(evsrc) && (int)GlobalVariableGet(evsrc) == 2) s += (s != "" ? "・" : "") + "カレンダー連携切れ(指標はEA直接判定)";
   return s;
}

//+------------------------------------------------------------------+
//| 経過秒を読みやすく("12秒" / "3分" / "--")                        |
//+------------------------------------------------------------------+
string AgeTxt(int s)
{
   if(s < 0)   return "--";
   if(s < 90)  return IntegerToString(s) + "秒";
   return IntegerToString(s/60) + "分";
}

//+------------------------------------------------------------------+
//| 通知(スマホのみ)                                                |
//+------------------------------------------------------------------+
void Notify(string msg)
{
   Print("[WD] ", msg);
   if(InpUseNotify)
      SendNotification(msg);
}

//+------------------------------------------------------------------+
//| ラベル生成/更新                                                  |
//+------------------------------------------------------------------+
void CreateLabel(string name, int y, int fs, color c, string txt)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,     InpCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  InpX);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   fs);
   ObjectSetString (0, name, OBJPROP_FONT,       "Meiryo");
   ObjectSetInteger(0, name, OBJPROP_COLOR,      c);
   ObjectSetString (0, name, OBJPROP_TEXT,       txt);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
}

//+------------------------------------------------------------------+
int LabelY(string name)
{
   if(name == LBL_RESCUE) return InpY + 22;   // 損切り再決済の行は、メイン表示の下
   return InpY;
}

void SetLabel(string name, color c, string txt)
{
   // ★2026-11-04修正: 空文字のOBJ_LABELは、MT5が既定の「Label」を表示してしまう(左端に「Label」が出ていた原因)。
   //   表示する内容が無い時は、ラベルごと削除する。
   if(StringLen(txt) == 0)
   {
      if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
      return;
   }
   if(ObjectFind(0, name) < 0)
      CreateLabel(name, LabelY(name), InpFontSize, c, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetString (0, name, OBJPROP_TEXT,  txt);
}
//+------------------------------------------------------------------+
