//+------------------------------------------------------------------+
//|                              DokaKotsu_EA_8.mq5                   |
//|                                                                  |
//|  ■ このEAは何をするか(役割)                                     |
//|    DokaKotsu_indicator_8 が出すシグナルを「来たら速攻で実行」    |
//|    するだけの実行役です。売買の判断ロジックは一切持ちません。    |
//|      ・売買の判断(方向・グレーゾーン・エントリー/決済の          |
//|        タイミング・M1早出し・クールダウン)は すべてインジ側。   |
//|      ・EAが持つのは「固定概念・リスク管理」だけ:                |
//|          - 時間フィルター(下記)                                |
//|          - ロット数 / 保険SL / 建値ストップ                     |
//|      → 両方にロジックを置かないので、長期使用でもズレません。   |
//|                                                                  |
//|  ■ どう動くか                                                    |
//|    インジのバッファを iCustom で直読み:7=BUY / 8=SELL / 9=EXIT  |
//|    形成中の足(shift=0)を毎ティック見て、                        |
//|      ・BUY/SELL矢印が出た瞬間に発注                              |
//|      ・EXITが出た瞬間に決済                                      |
//|    つまり「チャートの見たまま・最速」で実行します。              |
//|                                                                  |
//|  ■ 時間フィルター(JST)                                          |
//|    新規エントリーは JST 04:00〜06:59 は停止し、07:00 に再開。    |
//|    ※決済(EXIT)・建値ストップ・保険SLは時間に関係なく常に有効。 |
//|    InpUseTimeFilter=false で無効化。時刻は入力で変更可。         |
//|    (サーバー時刻=GMT+2/+3 を +6/+7時間して JST に換算)          |
//|                                                                  |
//|  ■ 建値ストップ(引き分け確保)                                  |
//|    含み益が InpBEtriggerPips に達したら、SLを建値(+わずか)へ    |
//|    寄せます。以後は反転しても±0付近で逃げられます。毎ティック。 |
//|                                                                  |
//|  ■ 理由ログ(任意・診断用)                                      |
//|    各M5足ごと、および売買した瞬間に、インジの判断理由を          |
//|    MQL5\Files\<InpReasonDir>\reason_YYYYMMDD.csv へ1行追記。     |
//|    取引には影響しません(analyze_entry_reason.py で集計)。       |
//|                                                                  |
//|  ■ 今回追加した機能 (EA_8 / 2026-06-20)                       |
//|    (6) 連敗ロット管理(リスク管理=EA側の責務)                  |
//|        実約定履歴(magic一致の決済ディール)から連敗を数え、     |
//|          3連敗 → ロット半減(×0.5)                            |
//|          4連敗 → 停止(新規を出さない。異常レンジ想定)         |
//|          復活  → 翌オセアニア(JST07:00 InpLossResumeHourJST)で   |
//|                  自動的に0.5ロット再開。または手動再開フラグでも  |
//|                  0.5再開。次の1勝で連敗0=通常(×1.0)復帰。       |
//|                  次の1勝で連敗0=フラグ自動削除→通常(×1.0)。  |
//|        勝ち/建値(損益≧0)で連敗リセット。損益はネット          |
//|        (利益+スワップ+手数料)。入力: InpUseLossLot /          |
//|        InpResumeFlag(ダッシュボードが作成/削除)。            |
//|        ※最小ロット(0.01)運用では半減は0.01未満に出来ず実質    |
//|          無効。停止(4連敗)は常に有効。半減を効かせるなら       |
//|          InpLots≧0.02 にすること。                            |
//|    (8) 参照インジを DokaKotsu_indicator_8 に更新(WMA34/案C・番号統一)。             |
//|                                                                  |
//|  ■ 既存機能 (EA_3 / 2026-06-14)                                |
//|    (1) 金曜の新規エントリー停止                                |
//|        JST土曜02:00(=サーバー金曜の夜)〜週末クローズまで、     |
//|        新規を出さない。金曜深夜に動いた後はドラマが無いため。 |
//|        決済/SL/建値/週末強制決済は常時有効。                |
//|        入力: InpFriBan / InpFriBanJstHour / InpFriBanJstMin       |
//|    (2) watchdog連携ハートビート                                |
//|        OnTimer(InpHbSec=30秒)で GlobalVariable に生存時刻を書く。  |
//|          DK_EA_HB_<magic>         … EA生存(土日・閑散時も更新)  |
//|          DK_EA_LASTREASON_<magic> … 理由CSVを書けた瞬間の時刻 |
//|        さらに ea_heartbeat.txt も出力(Pythonモニターが生存確認)。|
//|        入力: InpHeartbeat / InpHbSec                              |
//|    (3) 週末強制決済                                            |
//|        金曜クローズ前に保有を強制手仕舞い。                  |
//|        入力: InpWeekendFlatten / InpFriFlattenHour・Min           |
//|    (4) 理由ログをJSTで記録(ファイル名・time列ともJST)       |
//|    (5) Discord通知(EA本体の機能。WebRequest使用)             |
//|        ・起動時                                              |
//|        ・理由CSV書込み失敗(reason未出力を直接検知)          |
//|        ・稼働ハートビート(市場オープン中・InpDiscordHbMin分毎) |
//|        入力: InpUseDiscord / InpDiscordURL /                      |
//|              InpDiscordOnStart / InpDiscordHbMin                  |
//|        ※EA自身の停止は自己通知不可(watchdog/スマホ側で検知)。 |
//|        ※URLはツール>オプションの許可リストに登録要。         |
//|                                                                  |
//|  ※ インジと同じチャート(同じM5・同じXAUUSD)に載せること。     |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "4.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//=== バージョン(最新確認用) =======================================
#define EA_VERSION "v8.0"
#define EA_BUILD   "2026-06-20 EA_8 / 参照先=DokaKotsu_indicator_8(Ver8.0) / MT5カレンダー(CPI/NFP/FOMC)+米国休日+年末年始 / 停止理由GV出力 / M15状態(buf13)読取+リーズンに15分足列 / 連敗ロット+自動復活 / ドテン廃止 / 2026-06-22:日次pip停止(InpMaxDayLossPip)+復活で基準リセット+チャート3行警告 / 2026-06-22:平均足色列(buf14)+決済理由細分化(30/31/32)+出来高(21) / 2026-06-23:損切り再決済(✖再送+広スリッページ)+緊急逆行ストップ(任意・既定OFF)+救済GV(Watchdog表示)"
#define RESUME_BTN  "DK_ResumeBtn"   // ★連敗手動復活ボタンのオブジェクト名
#define RESUME_TXT  "DK_ResumeTxt"   // ★状態テキスト(警告/停止中)のオブジェクト名
#define WARN_TXT2   "DK_WarnTxt2"    // ★2026-06-22 3行警告の2行目(連敗)
#define WARN_TXT3   "DK_WarnTxt3"    // ★2026-06-22 3行警告の3行目(日次pip)

//=== 入力 =========================================================
input string InpVersionInfo  = "v8.0 / EA_8 / 連敗ロット + 金曜停止 + イベント/米国休日/年末年始 + 停止理由GV + Discord"; // ★バージョン(確認用)
input double InpLots         = 0.01;   // ロット数(固定・基準)※最小ロット。連敗時はこれを×0.5/×0(停止)

//--- ★連敗ロット管理(リスク管理=EA側)。実約定履歴から連敗を数えてロットを絞る/止める。
input bool   InpUseLossLot  = true;    // ★連敗ロット管理を使うか(3連敗→半減/4連敗→停止)
input string InpResumeFlag   = "dokakotsu_status\\resume_half.flag"; // ★再開フラグ(存在=0.5ロットで再開)。ダッシュボードが作成、1勝でEAが自動削除
input int    InpLossResumeHourJST = 7;  // ★連敗停止の自動復活(JST・時)。4連敗後は次のこの時刻(翌オセアニア)まで停止
input bool   InpTestForceLossStop = false; // ★テスト用: 強制的に4連敗停止状態にして復活ボタンを確認(確認後はfalse)
//--- ★日次pip停止(リスク管理=EA側 / 2026-06-22)。本日のネット損益pip合計が「基準」から-しきい値で本日新規停止。
//    復活ボタンを押すと『その時点の本日pip』を新しい基準(ゼロ点)にして再開→そこから更に-しきい値で再停止。JST日替わりで基準は0に自動リセット。
input bool   InpUseDayPipStop  = true;    // ★日次pip停止を使うか((本日合計pip - 基準) ≦ -InpMaxDayLossPip で新規停止)
input double InpMaxDayLossPip   = 200.0;   // ★日次pip停止のしきい値(pip)。基準から-これで停止/再停止 (2026-06-22 ボラ拡大により100→200)
input double InpDayPipWarnPip    = 20.0;   // ★日次pip警告: 停止まで残りこのpip以内でチャート3行警告を点灯
input bool   InpUseSL        = true;   // 保険のSLを置くか(急変対策)
input double InpSLpips       = 100.0;  // SL幅(pips)。InpUseSL=true時

//--- ★損切りの「滑り/取りこぼし」対策 (2026-06-23 追加)
//    ✖(動的決済)・イベント決済・週末決済が1回で失敗しても、保有が消えるまで
//    毎ティック再送する。再送は許容スリッページを広げて急変でも約定させる。
input bool   InpUseExitRetry    = true;   // ★決済の再送(失敗①=取りこぼし対策)。出るまで投げ続ける
input int    InpExitRetryDevPts = 1000;   // ★再送/強制決済の許容スリッページ(ポイント)。急変でも約定させるため広め
input int    InpExitTimeoutSec  = 3;      // ★決済命令後この秒数たっても保有が残っていればスマホ/Discordへ通知
//--- ★緊急逆行ストップ(失敗②=飛び越え対策)。✖が出ないまま価格が走った時の独立保険。
//    保険SL(InpSLpips)の手前で能動的に消し込む。※ノイズで余計に切られる代償あり(ハードSLを締めるのと同じ性質)。
//    既定OFF。②に備えて武装したい時だけ true に。
input bool   InpUseEmergencyStop = false; // ★緊急逆行ストップを使うか(既定OFF)
input double InpEmergencyPips     = 70.0; // ★この含み損(pip)に触れたら即・強制決済(保険SL100の手前で消し込む)

//--- 段階建値(ラダー)。含み益が伸びてからSLを段階的に引き上げる
//    1段目:+InpBEtriggerPips で建値(±InpBEoffsetPips)へ
//    2段目:+InpBE2triggerPips で +InpBE2offsetPips をロック
input bool   InpUseBreakeven  = true;  // 段階建値を使うか
input double InpBEtriggerPips = 100.0; // 1段目:この含み益(pip)で建値へ(100pip=約$10)
input double InpBEoffsetPips   = 0.0;  // 1段目:建値+この分(0=ちょうど建値)
input double InpBE2triggerPips = 150.0;// 2段目:この含み益(pip)で利益ロック(150pip=約$15)
input double InpBE2offsetPips  = 20.0; // 2段目:この分(pip)を利側にロック(20pip=約$2)

input int    InpMagic        = 20260606;// マジックナンバー(このEAの注文識別)
input int    InpSlippage     = 20;     // 許容スリッページ(ポイント)

//--- イベント予防線(FOMC/NFP)。発表前後はフラット&新規停止。日時はJSTで手入力。
input bool   InpUseEventGuard = true;  // イベント予防線を使うか
input string InpEvent1 = "";           // イベント1 日時(JST "YYYY.MM.DD HH:MM")例:FOMC
input string InpEvent2 = "";           // イベント2 日時(JST)例:NFP
input string InpEvent3 = "";           // イベント3 日時(JST)
input string InpEvent4 = "";           // イベント4 日時(JST)
input int    InpEventBeforeMin = 10;   // 発表この分前から:フラット&新規停止
input int    InpEventAfterMin  = 20;   // 発表この分後まで:新規停止
input bool   InpEventFlatten   = true; // 窓に入ったら保有を手仕舞いするか

//--- ★経済指標イベント回避(MT5カレンダー自動取得: CPI/NFP/FOMC)。リーク窓あり。
//    ※MQL5専用。業者がカレンダー配信していること(ツールボックス→カレンダー)。テスターでは無効。
input bool   InpUseCalEvent       = true; // ★MT5カレンダーでCPI/NFP/FOMC回避を使うか
input int    InpCpiNfpHoursBefore = 3;    // CPI/雇用統計: 何時間前から新規禁止(デッドレンジ)
input int    InpFomcHoursBefore   = 10;   // FOMC: 何時間前から新規禁止
input int    InpEvLeakMin         = 30;   // 発表この分前〜発表は新規OK(リークに乗る)
input int    InpEvAfterMin        = 30;   // 発表〜この分後まで新規禁止(直後の乱高下回避)
input int    InpEvBeMinBefore     = 1;    // 発表この分前に含み益なら建値(スパイク保険)

//--- ★米国休日(MT5カレンダー)。JSTこの時刻〜翌オセアニア開放(InpResumeHourJST)まで新規停止。
input bool   InpUseUSHoliday      = true; // ★米国休日停止を使うか(カレンダーの祝日を自動判定)
input int    InpUSHolStopHourJST  = 18;   // 米国休日: JSTこの時刻から新規停止(開放は翌 InpResumeHourJST 時)

//--- ★年末年始(固定: 12/30〜1/3)終日新規停止。カレンダー不使用・入力更新不要。
input bool   InpUseYearEnd        = true; // ★年末年始(12/30〜1/3)終日停止を使うか

//--- 時間フィルター(JST) 新規エントリーのみ停止。決済・SL・建値は常時有効。
input bool   InpUseTimeFilter = true;  // 時間フィルターを使うか
input int    InpStopHourJST   = 4;     // 停止開始(JST・時)   既定 04:00
input int    InpStopMinJST    = 0;     // 停止開始(JST・分)
input int    InpResumeHourJST = 7;     // 再開(JST・時)       既定 07:00(=06:59まで停止)
input int    InpResumeMinJST  = 0;     // 再開(JST・分)
input int    InpJstOffSummer  = 6;     // サーバー→JST時差(夏)。ThreeTrader等は +6
input int    InpJstOffWinter  = 7;     // サーバー→JST時差(冬)。 +7

//--- ★ハートビート(watchdog監視用)。OnTimerでGlobalVariableに現在時刻を書き生存を知らせる。
//    GV名: DK_EA_HB_<magic>(生存) / DK_EA_LASTREASON_<magic>(理由CSV書込み成功時刻)
input bool   InpHeartbeat    = true;   // ★ハートビートを出すか(watchdog監視用)
input int    InpHbSec        = 30;     // ★ハートビート更新間隔(秒)

//--- ★Discord通知(EAなのでWebRequestで直接投稿可)。URLはツール>オプションの許可リストに登録要。
input bool   InpUseDiscord    = true;   // ★Discordへ通知するか
input string InpDiscordURL     = "";    // ★Discord Webhook URL(空なら送らない)
input bool   InpDiscordOnStart = true;  // ★起動時に通知するか
input int    InpDiscordHbMin    = 60;   // ★稼働ハートビートの間隔(分。0=送らない)。市場オープン中のみ

//--- 週末持ち越し防止(金曜クローズ前の強制決済)。時刻はサーバー時間で指定。
input bool   InpWeekendFlatten = true; // 金曜クローズ前に保有を強制決済するか
input int    InpFriFlattenHour = 23;   // 金曜・強制決済の時刻(サーバー時間・時) ※クローズ5分前に設定
input int    InpFriFlattenMin  = 55;   // 金曜・強制決済の時刻(サーバー時間・分)

//--- ★金曜の新規停止。JST土曜02:00(=サーバー金曜の夜)以降は新規を出さない。
//    金曜は深夜0時頃に動くかレンジで、その後はドラマが無いため。決済/SL/建値/週末強制決済は常時有効。
input bool   InpFriBan        = true;  // ★金曜の新規停止を使うか
input int    InpFriBanJstHour = 2;     // ★新規停止の開始時刻(JST・時)※金曜の夜=JSTでは土曜未明
input int    InpFriBanJstMin  = 0;     // ★新規停止の開始時刻(JST・分)

//--- インジ名(MQL5\Indicators\ 直下に置く場合はこの名前)
input string InpIndicatorName = "DokaKotsu_indicator_8"; // 読み込むインジ名

//--- 理由ログ(診断用・取引に影響なし)
input bool   InpLogReason  = true;                       // 理由をCSVに記録するか
input string InpReasonDir   = "dokakotsu_entry_reason";  // 保存先サブフォルダ(MQL5\Files\配下)

//=== 内部 =========================================================
int       hInd     = INVALID_HANDLE;   // インジハンドル
//--- ★Discord用の状態
bool      g_reasonFailPending  = false; // 理由CSV書込み失敗(OnTimerでDiscord送信)
datetime  g_lastReasonFailDisc = 0;     // 直近の理由失敗Discord送信(連投抑制)
datetime  g_lastHbDisc         = 0;     // 直近の稼働ハートビートDiscord送信
datetime  g_lastBarTime = 0;           // 最後に診断行を書いたM5足
datetime  g_lastSignalBar = 0;         // 最後に発注したM5足(同足二重発注防止)
int       g_lastOrderErr = 0;          // 直近の発注エラー(理由CSV用)
int       g_lossStreak   = 0;          // ★連敗回数(新足ごとに実履歴から再計算してキャッシュ)
double    g_dayPip       = 0.0;        // ★2026-06-22 本日(JST)のネット損益pip合計(新足/タイマーで実履歴から再計算)
datetime  g_lastLossDt   = 0;          // ★直近(最新)の負けトレードの決済時刻(server)。自動復活時刻の起点
double    PIP = 0.0;                   // 1pipの価格幅
//--- ★決済リトライ/緊急ストップの状態 (2026-06-23)
bool     g_exitCommanded     = false;  // 決済を命令済み(=出るまで再送する)
int      g_exitKind          = 0;      // 1=✖ 2=緊急逆行 3=イベント 4=週末
string   g_exitWhy           = "";     // 表示/ログ用の理由文
datetime g_exitCmdTime       = 0;      // 決済命令を出した時刻(タイムアウト判定用)
bool     g_exitTimeoutNoticed= false;  // 長引き通知を出したか(1命令につき1回)
bool     g_rescueDiscPending = false;  // ★救済をDiscordへ(OnTick内ではWebRequest不可のため保留)
string   g_rescueDiscMsg     = "";     // ★保留中のDiscord本文

//+------------------------------------------------------------------+
int OnInit()
{
   // pip幅(XAUUSDは 0.1 が1pip相当。桁で自動判定 → ゴールドは明示)
   PIP = (_Digits==3 || _Digits==5) ? _Point*10 : _Point;
   if(_Symbol=="XAUUSD" || StringFind(_Symbol,"XAU")>=0) PIP = 0.1;

   hInd = iCustom(_Symbol, _Period, InpIndicatorName);
   if(hInd == INVALID_HANDLE)
   {
      Print("[EA] インジのロードに失敗: ", InpIndicatorName,
            " — MQL5\\Indicators\\ に存在するか確認してください");
      return(INIT_FAILED);
   }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(_Symbol);

   // ★ハートビート開始(watchdogがGVの鮮度でEA生存/理由CSV書込みを判定)
   if(InpHeartbeat)
   {
      EventSetTimer(InpHbSec);
      double nowd = (double)TimeCurrent();
      GlobalVariableSet(StringFormat("DK_EA_HB_%d", InpMagic), nowd);
      GlobalVariableSet(StringFormat("DK_EA_LASTREASON_%d", InpMagic), nowd); // 起動時は現在で初期化
      GlobalVariableSet(StringFormat("DK_EA_STOPREASON_%d", InpMagic), 0.0);  // ★停止理由(0=取引可)で初期化
      GlobalVariableSet(StringFormat("DK_EA_LASTRESCUE_%d", InpMagic), 0.0);  // ★損切り救済の発火時刻(Watchdog表示用)で初期化
      WriteHeartbeatFile();   // ★起動直後にもファイル出力(モニター用)
   }

   Print("[EA] 起動 ", EA_VERSION, " build ", EA_BUILD,
         " / Lots=", InpLots,
         " SL=", (InpUseSL?DoubleToString(InpSLpips,1)+"pips":"OFF"),
         " BE=", (InpUseBreakeven?DoubleToString(InpBEtriggerPips,0)+"pip":"OFF"),
         " 実行=shift0(即時)");

   if(InpDiscordOnStart)
      PostDiscord(StringFormat("【起動】DokaKotsu EA_8 %s  %s JST",
                  EA_VERSION, TimeToString(TimeLocal(), TIME_MINUTES)));
   g_lossStreak = DK_LossStreak();   // 起動時に連敗を評価
   g_dayPip     = DK_DayPip();        // ★2026-06-22 起動時に本日pipを評価
   UpdateResumeButton();             // ★復活ボタン初期表示(連敗3以上で出る)
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(ObjectFind(0, RESUME_BTN) >= 0) ObjectDelete(0, RESUME_BTN);   // ★復活ボタン撤去
   if(ObjectFind(0, RESUME_TXT) >= 0) ObjectDelete(0, RESUME_TXT);   // ★状態テキスト撤去
   if(ObjectFind(0, WARN_TXT2) >= 0) ObjectDelete(0, WARN_TXT2);   // ★3行警告2行目撤去
   if(ObjectFind(0, WARN_TXT3) >= 0) ObjectDelete(0, WARN_TXT3);   // ★3行警告3行目撤去
   if(hInd != INVALID_HANDLE) IndicatorRelease(hInd);
}

//+------------------------------------------------------------------+
//| ★連敗の手動復活ボタン(チャート左上)。                            |
//|   連敗3(停止前) : ボタン無し。赤テキスト「※警告：3連敗中…」のみ。  |
//|   連敗4(停止中) : 「復活ボタン」(赤・押すと有効)＋右に状態テキスト。|
//|   → 押して無効な状態のボタンは出さない(販売時の誤クリック対策)。  |
//+------------------------------------------------------------------+
void UpdateResumeButton()
{
   string bn = RESUME_BTN, t1 = RESUME_TXT, t2 = WARN_TXT2, t3 = WARN_TXT3;

   bool lossStopped = DK_IsLossStopped();
   bool dayStopped  = DK_IsDayPipStopped();
   bool stopped     = lossStopped || dayStopped;

   double base   = DK_DayStopBase();
   double segPip = g_dayPip - base;          // 基準からのセグメント損益(=-閾値で停止する対象)
   int    lim    = (int)MathRound(InpMaxDayLossPip);

   bool warnLoss = InpUseLossLot    && !stopped && (g_lossStreak == 3);
   bool warnDay  = InpUseDayPipStop && !stopped && (segPip <= -(InpMaxDayLossPip - InpDayPipWarnPip));

   int x0 = 12, y0 = 70;
   int btnW = 120, btnH = 28, gap = 14, lineH = 20;

   // --- 復活ボタン: 停止中(連敗 or 日次)なら表示 ---
   if(stopped)
   {
      if(ObjectFind(0, bn) < 0)
      {
         ObjectCreate(0, bn, OBJ_BUTTON, 0, 0, 0);
         ObjectSetInteger(0, bn, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, bn, OBJPROP_XDISTANCE, x0);
         ObjectSetInteger(0, bn, OBJPROP_YDISTANCE, y0);
         ObjectSetInteger(0, bn, OBJPROP_XSIZE, btnW);
         ObjectSetInteger(0, bn, OBJPROP_YSIZE, btnH);
         ObjectSetInteger(0, bn, OBJPROP_FONTSIZE, 11);
         ObjectSetString (0, bn, OBJPROP_FONT, "Meiryo UI");
         ObjectSetInteger(0, bn, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, bn, OBJPROP_BORDER_COLOR, clrWhite);
      }
      ObjectSetString (0, bn, OBJPROP_TEXT, "復活ボタン");
      ObjectSetInteger(0, bn, OBJPROP_BGCOLOR, clrFireBrick);
      ObjectSetInteger(0, bn, OBJPROP_STATE, false);
   }
   else if(ObjectFind(0, bn) >= 0) ObjectDelete(0, bn);

   // --- 行テキスト(最大3行)。使う行だけ設定、不要な行は消す ---
   string L1="", L2="", L3="";
   color  c1=clrRed,  c2=clrRed,  c3=clrRed;
   int    x1=x0,      y1=y0+6;

   if(stopped)
   {
      if(lossStopped)                            // 連敗停止: ボタン右に金色
      {
         x1=x0+btnW+gap; y1=y0+6; c1=clrGold;
         L1="※停止中：押すと0.5ロットで再開";
      }
      else                                       // 日次pip停止: ボタン右に赤
      {
         x1=x0+btnW+gap; y1=y0+6; c1=clrOrangeRed;
         L1=StringFormat("※本日停止：日次 %.1f / -%d pip 到達(明朝%d時再開。復活ボタン押すと今すぐ再開)", segPip, lim, InpLossResumeHourJST);
      }
   }
   else if(warnLoss || warnDay)                  // 警告(次の負けで停止が近い)
   {
      x1=x0; y1=y0+6; c1=clrRed;
      L1="※ WARNING：次回の負けで本日の取引を停止します";
      if(warnLoss)
         L2=StringFormat("　連敗 %d / 4 （あと%d敗で停止）", g_lossStreak, 4-g_lossStreak);
      if(warnDay)
      {
         double rem = InpMaxDayLossPip + segPip; // 停止まで残り(正)
         L3=StringFormat("　日次 %.1f / -%d pip （あと%.1fpipで停止）", segPip, lim, rem);
      }
   }

   DrawWarnLine(t1, x1, y1,           c1, L1);
   DrawWarnLine(t2, x0, y0+6+lineH,   c2, L2);
   DrawWarnLine(t3, x0, y0+6+lineH*2, c3, L3);
}
//--- ★2026-06-22 警告1行を描く(txtが空なら消す)。3行警告で共用。
void DrawWarnLine(string name, int x, int y, color c, string txt)
{
   if(StringLen(txt)==0)
   {
      if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
      return;
   }
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 11);
      ObjectSetString (0, name, OBJPROP_FONT, "Meiryo UI");
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetString (0, name, OBJPROP_TEXT, txt);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK || sparam != RESUME_BTN) return;
   g_dayPip = DK_DayPip();          // ★押下時点の本日pipを最新化(判定/基準を正確に)
   bool didResume = false;
   // --- 連敗停止の復活: 0.5ロット再開フラグ ---
   if(DK_IsLossStopped())
   {
      int fh = FileOpen(InpResumeFlag, FILE_WRITE|FILE_TXT|FILE_ANSI);   // 再開フラグ作成
      if(fh != INVALID_HANDLE)
      { FileWrite(fh, TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES)); FileClose(fh); }
      g_lossStreak = DK_LossStreak();   // 状態再評価
      Print("[EA] 手動復活(連敗): 0.5ロットで再開(次の1勝で連敗0=通常へ)");
      LogReason((datetime)iTime(_Symbol, _Period, 0), "手動復活(0.5再開)");
      WriteLossStopFile();
      didResume = true;
   }
   // --- 日次pip停止の復活: いまの本日pipを新基準に(=ここから更に-閾値で再停止) ---
   if(DK_IsDayPipStopped())
   {
      DK_DayStopResume();
      Print("[EA] 手動復活(日次): 基準を ", DoubleToString(g_dayPip,1),
            " pip にリセット(ここから -", DoubleToString(InpMaxDayLossPip,0), "pip で再停止)");
      LogReason((datetime)iTime(_Symbol, _Period, 0), "手動復活(日次基準リセット)");
      didResume = true;
   }
   if(!didResume)
      Print("[EA] 復活ボタン: 現在は停止中ではありません");
   ObjectSetInteger(0, RESUME_BTN, OBJPROP_STATE, false);
   UpdateResumeButton();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| ★Discordへ投稿(WebRequest)。許可リストにURL登録が必要。          |
//|   ※WebRequestはOnTick内では呼ばない(OnInit/OnTimerのみ)。        |
//+------------------------------------------------------------------+
string JsonEscape(string t)
{
   StringReplace(t, "\\", "\\\\");
   StringReplace(t, "\"", "\\\"");
   StringReplace(t, "\n", "\\n");
   StringReplace(t, "\r", "");
   return t;
}
void PostDiscord(string msg)
{
   if(!InpUseDiscord || StringLen(InpDiscordURL) < 8) return;
   string js = "{\"content\":\"" + JsonEscape(msg) + "\"}";
   char   post[];
   int    len = StringToCharArray(js, post, 0, -1, CP_UTF8);
   if(len > 0) ArrayResize(post, len - 1);   // 終端NUL除去
   char   res[];
   string rh  = "";
   string hdr = "Content-Type: application/json\r\n";
   ResetLastError();
   int code = WebRequest("POST", InpDiscordURL, hdr, 5000, post, res, rh);
   if(code == -1)
      Print("[EA] Discord送信失敗 err=", GetLastError(), " (許可リストにURL登録を確認)");
}

//+------------------------------------------------------------------+
//| ★ハートビート: watchdogへ生存を知らせる(GVに現在時刻=サーバー時間)|
//|   OnTimerはティックが無くても動くので、土日・閑散時もEA生存を示せる。|
//|   (理由CSVの書込み成功時刻は WriteReasonRow 側でGV更新)            |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ★ハートビートをファイルにも出力(Pythonモニターがmtimeで生存判定)|
//|   MQL5\Files\dokakotsu_status\ea_heartbeat.txt を毎回上書き。     |
//|   OnTimerで30秒毎に更新 → モニターは更新時刻の鮮度でEA生存を見る。|
//+------------------------------------------------------------------+
void WriteHeartbeatFile()
{
   int fh = FileOpen("dokakotsu_status\\ea_heartbeat.txt", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fh == INVALID_HANDLE) return;
   ulong _tk=0; int _p = CurrentPos(_tk);
   FileWrite(fh, TimeToString(TimeLocal(), TIME_DATE|TIME_SECONDS),
             "pos="+IntegerToString(_p), EA_VERSION);
   FileClose(fh);
}

void WriteLossStopFile()
{
   // ダッシュボード用: 連敗停止の状態。 stopped(0/1) / streak / resume(JST文字列)
   int fh = FileOpen("dokakotsu_status\\loss_stop.txt", FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fh == INVALID_HANDLE) return;
   bool stopped = DK_IsLossStopped();
   datetime rt  = (g_lossStreak >= 4) ? DK_LossResumeTime() : 0;
   string resumeStr = "";
   if(rt > 0)
   {
      int off = IsSummerTime(rt) ? InpJstOffSummer : InpJstOffWinter;
      resumeStr = TimeToString(rt + off*3600, TIME_DATE|TIME_MINUTES);
   }
   FileWrite(fh, IntegerToString(stopped ? 1 : 0),
                 IntegerToString(g_lossStreak), resumeStr);
   FileClose(fh);
}

void OnTimer()
{
   // ★損切り救済/長引き通知 → Discord(保留分。PostDiscordは無効時は何もしない)
   if(g_rescueDiscPending)
   {
      PostDiscord(g_rescueDiscMsg);
      g_rescueDiscPending = false;
      g_rescueDiscMsg     = "";
   }

   if(InpHeartbeat)
   {
      g_lossStreak = DK_LossStreak();   // ★状態ファイル/GV用に最新化(g_lastLossDtも更新)
      GlobalVariableSet(StringFormat("DK_EA_HB_%d", InpMagic), (double)TimeCurrent());
      GlobalVariableSet(StringFormat("DK_EA_LOSSSTREAK_%d", InpMagic), (double)g_lossStreak); // ★連敗数(ダッシュボード表示用)
      g_dayPip = DK_DayPip();           // ★2026-06-22 本日pipを最新化
      GlobalVariableSet(StringFormat("DK_EA_DAYPIP_%d", InpMagic), g_dayPip);                 // ★本日pip合計(表示用)
      WriteHeartbeatFile();   // ★Python監視用(モニターがmtimeで生存判定)
      WriteLossStopFile();    // ★連敗停止の状態をダッシュボードへ
      UpdateStopReasonGV();   // ★停止理由をGVへ(Watchdog表示用・30〜60秒間隔で最新化)
   }

   if(!InpUseDiscord || StringLen(InpDiscordURL) < 8) return;
   datetime nowS = TimeCurrent();

   // (1) 理由CSV書込み失敗 → Discord(10分に1回まで)
   if(g_reasonFailPending && (g_lastReasonFailDisc==0 || nowS - g_lastReasonFailDisc > 600))
   {
      PostDiscord(StringFormat("【!】DokaKotsu 理由CSV書込み失敗  %s JST",
                  TimeToString(TimeLocal(), TIME_MINUTES)));
      g_lastReasonFailDisc = nowS;
      g_reasonFailPending  = false;
   }

   // (2) 稼働ハートビート → Discord(市場オープン中・指定間隔)
   if(InpDiscordHbMin > 0)
   {
      MqlTick tk; bool got = SymbolInfoTick(_Symbol, tk);
      bool mktOpen = got && (TimeTradeServer() - tk.time) <= 120;
      if(mktOpen && (g_lastHbDisc==0 || nowS - g_lastHbDisc >= (datetime)InpDiscordHbMin*60))
      {
         ulong _tk=0; int _p = CurrentPos(_tk);
         string ps = (_p==1?"買い":(_p==-1?"売り":"なし"));
         PostDiscord(StringFormat("【稼働】DokaKotsu EA_8  保有=%s  証拠金=%.0f  %s JST",
                     ps, AccountInfoDouble(ACCOUNT_EQUITY),
                     TimeToString(TimeLocal(), TIME_MINUTES)));
         g_lastHbDisc = nowS;
      }
   }
}

//+------------------------------------------------------------------+
//| このEA(マジック一致)の保有方向。1=買い / -1=売り / 0=なし     |
//+------------------------------------------------------------------+
int CurrentPos(ulong &ticketOut)
{
   ticketOut = 0;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      ticketOut = tk;
      long type = PositionGetInteger(POSITION_TYPE);
      return (type==POSITION_TYPE_BUY) ? 1 : -1;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| インジのバッファ値を読む。値があれば true(0/EMPTYは非シグナル) |
//+------------------------------------------------------------------+
bool ReadBuf(int bufIndex, int shift, double &valOut)
{
   double tmp[];
   if(CopyBuffer(hInd, bufIndex, shift, 1, tmp) <= 0) return false;
   valOut = tmp[0];
   if(valOut==0.0 || valOut==EMPTY_VALUE || !MathIsValidNumber(valOut)) return false;
   return true;
}

//+------------------------------------------------------------------+
//| インジの判断理由コード(buffer11)を読む                         |
//+------------------------------------------------------------------+
int ReadReason(int shift)
{
   double rr[];
   if(CopyBuffer(hInd, 12, shift, 1, rr) > 0) return (int)MathRound(rr[0]); // ★理由バッファはVer8.2でbuf12へ移動
   return 0;
}

//+------------------------------------------------------------------+
//| ★Ver8: インジの15分足状態(buffer13)を読む(0=グレー/1=上昇/-1=下降)|
//+------------------------------------------------------------------+
int ReadM15State(int shift)
{
   double mm[];
   if(CopyBuffer(hInd, 13, shift, 1, mm) > 0) return (int)MathRound(mm[0]);
   return 0;
}
//--- ★2026-06-22: インジの平均足の色(buffer14)を読む(1=上昇/-1=下降)
int ReadHaState(int shift)
{
   double hh[];
   if(CopyBuffer(hInd, 14, shift, 1, hh) > 0) return (int)MathRound(hh[0]);
   return 1;
}

//+------------------------------------------------------------------+
//| 夏時間(US DST: 3月第2日曜〜11月第1日曜)か                        |
//+------------------------------------------------------------------+
bool IsSummerTime(datetime t)
{
   MqlDateTime st; TimeToStruct(t, st);
   int y = st.year;
   datetime mar = StringToTime(StringFormat("%d.03.01 00:00", y));
   MqlDateTime mt; TimeToStruct(mar, mt);
   int firstSunMar = (7 - mt.day_of_week) % 7 + 1;
   datetime dstStart = StringToTime(StringFormat("%d.03.%02d 00:00", y, firstSunMar + 7));
   datetime nov = StringToTime(StringFormat("%d.11.01 00:00", y));
   MqlDateTime nt; TimeToStruct(nov, nt);
   int firstSunNov = (7 - nt.day_of_week) % 7 + 1;
   datetime dstEnd = StringToTime(StringFormat("%d.11.%02d 00:00", y, firstSunNov));
   return (t >= dstStart && t < dstEnd);
}

//+------------------------------------------------------------------+
//| 時間フィルター(JST)。true=停止時間帯(新規禁止)               |
//|   サーバー時刻(GMT+2/+3)→ JST は +6時間(夏)/+7時間(冬)。       |
//+------------------------------------------------------------------+
bool IsInStopTime()
{
   if(!InpUseTimeFilter) return false;
   int off = IsSummerTime(TimeCurrent()) ? InpJstOffSummer : InpJstOffWinter;
   datetime jstNow = TimeCurrent() + off*3600;
   MqlDateTime jst; TimeToStruct(jstNow, jst);
   int nowMin    = jst.hour*60 + jst.min;
   int stopMin   = InpStopHourJST*60   + InpStopMinJST;    // 既定 240 (04:00)
   int resumeMin = InpResumeHourJST*60 + InpResumeMinJST;  // 既定 420 (07:00)
   if(stopMin < resumeMin) return (nowMin >= stopMin && nowMin < resumeMin);
   else                    return (nowMin >= stopMin || nowMin < resumeMin); // 日跨ぎ
}

//+------------------------------------------------------------------+
//| イベント予防線(FOMC/NFP)。true=発表前後の窓内(フラット&新規禁止)|
//|   日時はJSTで手入力。jstNow と同じ土俵(JST)で比較する。          |
//+------------------------------------------------------------------+
bool IsInEventWindow()
{
   if(!InpUseEventGuard) return false;
   int off = IsSummerTime(TimeCurrent()) ? InpJstOffSummer : InpJstOffWinter;
   datetime jstNow = TimeCurrent() + off*3600;
   string evs[4]; evs[0]=InpEvent1; evs[1]=InpEvent2; evs[2]=InpEvent3; evs[3]=InpEvent4;
   for(int i=0;i<4;i++)
   {
      if(StringLen(evs[i]) < 10) continue;     // 未設定はスキップ
      datetime ev = StringToTime(evs[i]);
      if(ev <= 0) continue;
      if(jstNow >= ev - InpEventBeforeMin*60 && jstNow <= ev + InpEventAfterMin*60)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| 週末持ち越し防止: 金曜クローズ前(サーバー時間)なら true        |
//|   週末クローズはサーバー時間で固定なので server 時間で判定する。 |
//+------------------------------------------------------------------+
bool IsWeekendFlattenTime()
{
   if(!InpWeekendFlatten) return false;
   MqlDateTime s; TimeToStruct(TimeCurrent(), s);   // サーバー時間
   if(s.day_of_week != 5) return false;             // 金曜のみ(サーバー時間)
   int nowMin  = s.hour*60 + s.min;
   int flatMin = InpFriFlattenHour*60 + InpFriFlattenMin;
   return (nowMin >= flatMin);
}

//+------------------------------------------------------------------+
//| ★金曜の新規停止。JST土曜02:00(=サーバー金曜の夜)〜週末クローズ。 |
//|   true=新規禁止。決済/SL/建値/週末強制決済は呼び出し側で常時有効。|
//|   金曜のトレード“夜”はJSTでは土曜の未明に当たる                  |
//|   (例:サーバー金曜20:00=JST土曜02:00)。よってJST土曜で判定する。|
//+------------------------------------------------------------------+
bool IsFridayEntryBan()
{
   if(!InpFriBan) return false;
   int off = IsSummerTime(TimeCurrent()) ? InpJstOffSummer : InpJstOffWinter;
   datetime jstNow = TimeCurrent() + off*3600;
   MqlDateTime jst; TimeToStruct(jstNow, jst);
   if(jst.day_of_week != 6) return false;               // JST土曜のみ(=金曜の夜)
   int nowMin = jst.hour*60 + jst.min;
   int banMin = InpFriBanJstHour*60 + InpFriBanJstMin;   // 既定 02:00
   return (nowMin >= banMin);                            // 02:00以降は新規禁止
}

//+------------------------------------------------------------------+
//| ★MT5経済指標カレンダー: CPI/NFP/FOMC 回避(リーク窓あり)         |
//|   ・カレンダーはサーバー時間で返る → サーバー時間で比較。        |
//|   ・状態: 0=影響なし / 1=新規禁止(デッドレンジ or 発表後) / 2=リークOK|
//|   ・g_evKind に該当種別(理由表示用)、g_evNeedBE に -1分建値フラグ。|
//|   ・毎ティックのカレンダー照会は重いので30秒キャッシュ。          |
//+------------------------------------------------------------------+
enum EV_KIND { EV_NONE=0, EV_CPI=1, EV_NFP=2, EV_FOMC=3 };

int      g_evState    = 0;        // 0 none / 1 ban / 2 leak
EV_KIND  g_evKind     = EV_NONE;  // 直近で該当した種別(理由用)
bool     g_evNeedBE   = false;    // -1分建値が必要か
datetime g_evLastCalc = 0;        // キャッシュ更新時刻

EV_KIND ClassifyEvent(const string name)
{
   string n = name; StringToLower(n);   // 英語判定用に小文字化
   if(StringFind(n,"fomc")>=0 || StringFind(n,"federal funds")>=0 ||
      StringFind(n,"interest rate")>=0 || StringFind(name,"政策金利")>=0 ||
      StringFind(name,"FOMC")>=0)
      return EV_FOMC;
   if(StringFind(n,"consumer price")>=0 || StringFind(n,"cpi")>=0 ||
      StringFind(name,"消費者物価")>=0)
      return EV_CPI;
   if(StringFind(n,"nonfarm")>=0 || StringFind(n,"non-farm")>=0 ||
      StringFind(n,"payroll")>=0 || StringFind(name,"雇用統計")>=0 ||
      StringFind(name,"非農業")>=0)
      return EV_NFP;
   return EV_NONE;
}

void RefreshCalEvent()
{
   datetime now = TimeCurrent();
   if(g_evLastCalc!=0 && (now - g_evLastCalc) < 30) return;   // 30秒キャッシュ
   g_evLastCalc = now;
   g_evState = 0; g_evKind = EV_NONE; g_evNeedBE = false;
   if(!InpUseCalEvent) return;

   datetime from = now - 2*3600;
   datetime to   = now + (InpFomcHoursBefore + 2)*3600;
   MqlCalendarValue values[];
   int cnt = CalendarValueHistory(values, from, to, "US");
   if(cnt <= 0) return;

   bool banFound=false, leakFound=false;
   EV_KIND banKind=EV_NONE, leakKind=EV_NONE;
   bool needBE=false;
   for(int i=0;i<cnt;i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev)) continue;
      if(ev.importance != CALENDAR_IMPORTANCE_HIGH) continue;   // 重要度HIGHのみ
      EV_KIND k = ClassifyEvent(ev.name);
      if(k==EV_NONE) continue;
      datetime evt = values[i].time;                            // 発表時刻(サーバー時間)
      int   hb     = (k==EV_FOMC) ? InpFomcHoursBefore : InpCpiNfpHoursBefore;
      datetime deadStart = evt - (datetime)hb*3600;
      datetime leakStart = evt - (datetime)InpEvLeakMin*60;
      datetime postEnd   = evt + (datetime)InpEvAfterMin*60;
      datetime beStart   = evt - (datetime)InpEvBeMinBefore*60;
      if(now >= deadStart && now < leakStart)      { banFound=true; banKind=k; }       // デッドレンジ禁止
      else if(now >= leakStart && now < evt)       { leakFound=true; leakKind=k; if(now>=beStart) needBE=true; } // リークOK
      else if(now >= evt && now <= postEnd)        { banFound=true; banKind=k; }       // 発表後禁止
   }
   if(banFound)       { g_evState=1; g_evKind=banKind; }   // 禁止はリークに優先
   else if(leakFound) { g_evState=2; g_evKind=leakKind; g_evNeedBE=needBE; }
}

//+------------------------------------------------------------------+
//| ★米国休日(MT5カレンダー祝日)。JST 18:00〜翌07:00 新規停止。     |
//|   毎ティック照会は重いので60秒キャッシュ。                       |
//+------------------------------------------------------------------+
bool     g_usHol        = false;
datetime g_usHolLastCalc= 0;

void RefreshUSHoliday()
{
   datetime now = TimeCurrent();
   if(g_usHolLastCalc!=0 && (now - g_usHolLastCalc) < 60) return;  // 60秒キャッシュ
   g_usHolLastCalc = now;
   g_usHol = false;
   if(!InpUseUSHoliday) return;

   MqlCalendarValue values[];
   int cnt = CalendarValueHistory(values, now-36*3600, now+12*3600, "US");
   if(cnt <= 0) return;

   int off = IsSummerTime(now) ? InpJstOffSummer : InpJstOffWinter;
   datetime jstNow = now + off*3600;                  // JST壁時計をdatetimeで表現
   for(int i=0;i<cnt;i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev)) continue;
      if(ev.type != CALENDAR_TYPE_HOLIDAY) continue;   // 祝日のみ
      datetime holJst = values[i].time + off*3600;     // 祝日の日付(JST壁時計)
      MqlDateTime hd; TimeToStruct(holJst, hd);
      hd.hour=InpUSHolStopHourJST; hd.min=0; hd.sec=0;
      datetime winStart = StructToTime(hd);            // 祝日当日 18:00(JST)
      datetime winEnd   = winStart + (datetime)((24 - InpUSHolStopHourJST) + InpResumeHourJST)*3600; // 翌 07:00
      if(jstNow >= winStart && jstNow < winEnd) { g_usHol = true; return; }
   }
}

//+------------------------------------------------------------------+
//| ★年末年始(固定: 12/30〜1/3)。JST日付で終日 新規停止。          |
//+------------------------------------------------------------------+
bool IsYearEndStop()
{
   if(!InpUseYearEnd) return false;
   int off = IsSummerTime(TimeCurrent()) ? InpJstOffSummer : InpJstOffWinter;
   datetime jstNow = TimeCurrent() + off*3600;
   MqlDateTime j; TimeToStruct(jstNow, j);
   if(j.mon==12 && j.day>=30) return true;
   if(j.mon==1  && j.day<=3 ) return true;
   return false;
}

//+------------------------------------------------------------------+
//| ★停止理由コード(Watchdog表示用・優先順位つき)                  |
//|  0=取引可 1=オセアニア 2=金曜深夜 3=CPI 4=雇用統計 5=FOMC        |
//|  6=米国休日 7=日本休日(年末年始) 8=連敗 9=週末クローズ           |
//+------------------------------------------------------------------+
int DK_StopReasonCode(bool dayStop, bool lossStop, bool inWeekendFlat, bool inFriBan,
                      bool usHol, bool yearEnd, bool inStop)
{
   if(dayStop)       return 10;   // ★2026-06-22 日次損失上限(最優先表示)
   if(lossStop)      return 8;
   if(yearEnd)       return 7;
   if(usHol)         return 6;
   if(g_evState==1)                       // イベント新規禁止中
   {
      if(g_evKind==EV_FOMC) return 5;
      if(g_evKind==EV_NFP)  return 4;
      return 3;                            // CPI
   }
   if(inWeekendFlat) return 9;
   if(inFriBan)      return 2;
   if(inStop)        return 1;
   return 0;
}

//+------------------------------------------------------------------+
//| ★停止理由をGVへ出力(Watchdogが読む)。OnTimer/新足から呼ぶ。    |
//+------------------------------------------------------------------+
int g_stopReason = 0;
void UpdateStopReasonGV()
{
   RefreshCalEvent();
   RefreshUSHoliday();
   bool lossStop = DK_IsLossStopped();
   bool dayStop  = DK_IsDayPipStopped();
   int code = DK_StopReasonCode(dayStop, lossStop, IsWeekendFlattenTime(), IsFridayEntryBan(),
                                g_usHol, IsYearEndStop(), IsInStopTime());
   g_stopReason = code;
   GlobalVariableSet(StringFormat("DK_EA_STOPREASON_%d", InpMagic), (double)code);
   GlobalVariableSet(StringFormat("DK_EA_DAYPIP_%d", InpMagic), g_dayPip); // ★2026-06-22 本日pip合計
}

//+------------------------------------------------------------------+
//| ★-1分建値: 含み益なら建値へSL移動(イベントスパイク保険)        |
//+------------------------------------------------------------------+
void ForceEventBreakeven()
{
   ulong tk=0; int pos = CurrentPos(tk);
   if(pos==0 || tk==0) return;
   if(!PositionSelectByTicket(tk)) return;
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL = PositionGetDouble(POSITION_SL);
   double tp    = PositionGetDouble(POSITION_TP);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double eps   = _Point*0.5;
   double profitPips = (pos==1) ? (bid-entry)/PIP : (entry-ask)/PIP;
   if(profitPips <= 0) return;                       // 含み益のみ
   double newSL = NormalizeDouble(entry, _Digits);
   if(pos==1 && curSL < newSL - eps)
   { if(trade.PositionModify(tk,newSL,tp)) Print("[EA] イベント-1分 建値(買い)"); }
   else if(pos==-1 && (curSL==0.0 || curSL > newSL + eps))
   { if(trade.PositionModify(tk,newSL,tp)) Print("[EA] イベント-1分 建値(売り)"); }
}

//+------------------------------------------------------------------+
//| 段階建値(ラダー):含み益に応じてSLを段階的に利側へ(片方向)    |
//+------------------------------------------------------------------+
void ManageBreakeven()
{
   if(!InpUseBreakeven) return;
   ulong tk=0;
   int pos = CurrentPos(tk);
   if(pos==0 || tk==0) return;
   if(!PositionSelectByTicket(tk)) return;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double curSL = PositionGetDouble(POSITION_SL);
   double tp    = PositionGetDouble(POSITION_TP);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double eps   = _Point * 0.5;

   // 含み益(pip)と、ロックすべき利側オフセット(pip)を決める
   double profitPips = (pos==1) ? (bid - entry)/PIP : (entry - ask)/PIP;
   double lockPips;
   if(profitPips >= InpBE2triggerPips)      lockPips = InpBE2offsetPips; // 2段目:+20ロック
   else if(profitPips >= InpBEtriggerPips)  lockPips = InpBEoffsetPips;  // 1段目:建値
   else return;                                                         // まだどの段にも未達

   if(pos==1) // 買い:SLは entry + lock。現在SLより上(利側)の時だけ引き上げ
   {
      double newSL = NormalizeDouble(entry + lockPips*PIP, _Digits);
      if(curSL < newSL - eps)
      {
         if(trade.PositionModify(tk, newSL, tp))
            Print("[EA] 段階建値 買い SL->", DoubleToString(newSL,_Digits),
                  " (含み益 ", DoubleToString(profitPips,1), "pip)");
         else
            Print("[EA] 段階建値失敗(買い) err=", GetLastError());
      }
   }
   else // 売り:SLは entry - lock。現在SLより下(利側)の時だけ引き下げ
   {
      double newSL = NormalizeDouble(entry - lockPips*PIP, _Digits);
      if(curSL==0.0 || curSL > newSL + eps)
      {
         if(trade.PositionModify(tk, newSL, tp))
            Print("[EA] 段階建値 売り SL->", DoubleToString(newSL,_Digits),
                  " (含み益 ", DoubleToString(profitPips,1), "pip)");
         else
            Print("[EA] 段階建値失敗(売り) err=", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| ★連敗ロット管理(リスク管理=EA側)                                |
//|   実約定履歴(このEAのmagic/symbolの決済ディール)を新しい順に    |
//|   走査し、損益<0が何回連続しているかを数える。勝ち/建値(≧0)で  |
//|   打ち切り。損益はネット(利益+スワップ+手数料)。               |
//+------------------------------------------------------------------+
int DK_LossStreak()
{
   g_lastLossDt = 0;
   datetime from = TimeCurrent() - 60*60*24*60;   // 直近60日窓(連敗を捉えるのに十分)
   if(!HistorySelect(from, TimeCurrent())) return 0;
   int total = HistoryDealsTotal();
   int streak = 0;
   datetime newestLoss = 0;
   for(int i=total-1; i>=0; i--)                   // 新しい順
   {
      ulong t = HistoryDealGetTicket(i);
      if(t==0) continue;
      if(HistoryDealGetString(t, DEAL_SYMBOL) != _Symbol) continue;
      if((long)HistoryDealGetInteger(t, DEAL_MAGIC) != InpMagic) continue;
      ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(t, DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_INOUT) continue;   // 決済(orドテン)のみ
      double pl = HistoryDealGetDouble(t, DEAL_PROFIT)
                + HistoryDealGetDouble(t, DEAL_SWAP)
                + HistoryDealGetDouble(t, DEAL_COMMISSION);    // ネット損益
      if(pl < 0.0)
      {
         if(newestLoss==0) newestLoss = (datetime)HistoryDealGetInteger(t, DEAL_TIME); // 最新の負けの時刻
         streak++;            // 損失=連敗加算
      }
      else break;             // 勝ち/建値(±0)で打ち切り=連敗リセット
   }
   g_lastLossDt = newestLoss;
   return streak;
}

//+------------------------------------------------------------------+
//| ★2026-06-22 日次pip停止 関連                                     |
//|  DK_DayPip()       : 本日(JST)決済の価格差pip合計(建値とペアで算出)|
//|  DK_DayStopBase()  : 基準pip(復活で付け替え/JST日替わりで0自動)    |
//|  DK_DayStopResume(): いまの本日pipを新基準に(=ここから-閾値で再停止)|
//|  DK_IsDayPipStopped(): (本日pip - 基準) ≦ -InpMaxDayLossPip       |
//+------------------------------------------------------------------+
long DK_JstYmd()   // ★取引日ID(JST InpLossResumeHourJST時始まり)。7時前は前日扱い→翌7時で日次枠リセット。
{
   int off = IsSummerTime(TimeCurrent()) ? InpJstOffSummer : InpJstOffWinter;
   datetime jst = TimeCurrent() + off*3600 - InpLossResumeHourJST*3600;  // 7時始まりを0時に寄せる
   MqlDateTime j; TimeToStruct(jst, j);
   return (long)j.year*10000 + (long)j.mon*100 + (long)j.day;
}
datetime DK_JstDayStartServer()   // ★取引日開始(直近のJST InpLossResumeHourJST時)を server時刻で返す
{
   int off = IsSummerTime(TimeCurrent()) ? InpJstOffSummer : InpJstOffWinter;
   datetime jst = TimeCurrent() + off*3600;
   MqlDateTime j; TimeToStruct(jst, j);
   MqlDateTime s = j; s.hour=InpLossResumeHourJST; s.min=0; s.sec=0;
   datetime startJst = StructToTime(s);
   if(jst < startJst) startJst -= 24*3600;     // まだ7時前 → 前日の7時開始
   return startJst - off*3600;
}
double DK_DayPip()
{
   datetime dayStart = DK_JstDayStartServer();
   datetime from = dayStart - 60*60*24*2;        // 建値ペア用に2日前から選択
   if(!HistorySelect(from, TimeCurrent())) return 0.0;
   int total = HistoryDealsTotal();
   double sum = 0.0;
   for(int i=0; i<total; i++)
   {
      ulong t = HistoryDealGetTicket(i);
      if(t==0) continue;
      if(HistoryDealGetString(t, DEAL_SYMBOL) != _Symbol) continue;
      if((long)HistoryDealGetInteger(t, DEAL_MAGIC) != InpMagic) continue;
      ENUM_DEAL_ENTRY e = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(t, DEAL_ENTRY);
      if(e!=DEAL_ENTRY_OUT && e!=DEAL_ENTRY_INOUT) continue;   // 決済のみ
      datetime dt = (datetime)HistoryDealGetInteger(t, DEAL_TIME);
      if(dt < dayStart) continue;                              // 本日(JST)決済のみ
      long   posid    = (long)HistoryDealGetInteger(t, DEAL_POSITION_ID);
      double outPrice = HistoryDealGetDouble(t, DEAL_PRICE);
      double inPrice  = 0.0; int inType = -1;
      for(int k=0; k<total; k++)                               // 対応INの建値・方向
      {
         ulong tk = HistoryDealGetTicket(k);
         if(tk==0) continue;
         if((long)HistoryDealGetInteger(tk, DEAL_POSITION_ID) != posid) continue;
         if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
         inPrice = HistoryDealGetDouble(tk, DEAL_PRICE);
         inType  = (int)HistoryDealGetInteger(tk, DEAL_TYPE);
         break;
      }
      if(inPrice <= 0.0 || PIP <= 0.0) continue;
      double pip = (inType==DEAL_TYPE_BUY) ? (outPrice-inPrice)/PIP : (inPrice-outPrice)/PIP;
      sum += pip;
   }
   return sum;
}
double DK_DayStopBase()
{
   string dn = StringFormat("DK_EA_DAYSTOPDATE_%d", InpMagic);
   string bn = StringFormat("DK_EA_DAYSTOPBASE_%d", InpMagic);
   long today = DK_JstYmd();
   long saved = GlobalVariableCheck(dn) ? (long)GlobalVariableGet(dn) : 0;
   if(saved != today)                              // 日替わり → 基準0へ
   {
      GlobalVariableSet(dn, (double)today);
      GlobalVariableSet(bn, 0.0);
      return 0.0;
   }
   return GlobalVariableCheck(bn) ? GlobalVariableGet(bn) : 0.0;
}
void DK_DayStopResume()
{
   GlobalVariableSet(StringFormat("DK_EA_DAYSTOPDATE_%d", InpMagic), (double)DK_JstYmd());
   GlobalVariableSet(StringFormat("DK_EA_DAYSTOPBASE_%d", InpMagic), g_dayPip);
}
bool DK_IsDayPipStopped()
{
   if(!InpUseDayPipStop) return false;
   return ((g_dayPip - DK_DayStopBase()) <= -InpMaxDayLossPip);
}

//--- 再開フラグ(存在=4連敗停止後も0.5ロットで再開)。ダッシュボードが作成。
bool DK_ResumeHalfOn() { return FileIsExist(InpResumeFlag); }

//--- 連敗停止の自動復活時刻(server)。直近の負けの「次の InpLossResumeHourJST(JST)=翌オセアニア」。
datetime DK_LossResumeTime()
{
   if(g_lastLossDt <= 0) return 0;
   int off = IsSummerTime(g_lastLossDt) ? InpJstOffSummer : InpJstOffWinter;
   datetime lossJst = g_lastLossDt + off*3600;
   MqlDateTime j; TimeToStruct(lossJst, j);
   j.hour = InpLossResumeHourJST; j.min = 0; j.sec = 0;
   datetime resumeJst = StructToTime(j);
   if(resumeJst <= lossJst) resumeJst += 24*3600;   // 既に過ぎていれば翌日のその時刻
   return resumeJst - off*3600;                       // JST→server
}

//--- いま連敗停止中か(4連敗・手動再開なし・自動復活時刻前)。
bool DK_IsLossStopped()
{
   if(InpTestForceLossStop) return true;              // ★テスト用: 強制停止中扱い(ボタン確認)
   if(!InpUseLossLot)    return false;
   if(g_lossStreak < 4)  return false;
   if(DK_ResumeHalfOn()) return false;                // 手動再開中
   datetime rt = DK_LossResumeTime();
   if(rt > 0 && TimeCurrent() >= rt) return false;     // 翌オセアニアを過ぎた=自動復活
   return true;
}

//+------------------------------------------------------------------+
//| ★この連敗回数(キャッシュ g_lossStreak)に応じた発注ロット。      |
//|   0.0 を返したら「停止=新規を出さない」。                        |
//|   3連敗→×0.5 / 4連敗→停止 / 再開フラグ時は4連敗以上でも×0.5。    |
//|   ※最小ロット0.01運用では×0.5は0.01未満に出来ず実質無効。       |
//+------------------------------------------------------------------+
double DK_OrderLot()
{
   if(!InpUseLossLot) return InpLots;
   int  s      = g_lossStreak;
   bool resume = DK_ResumeHalfOn();
   if(s==0 && resume) FileDelete(InpResumeFlag);   // 1勝で連敗0=フラグ掃除→通常復帰

   double f;
   if(s >= 4)      f = DK_IsLossStopped() ? 0.0 : 0.5; // 4連敗=停止(翌7時JSTまで)。復活後/手動再開は0.5
   else if(s == 3) f = 0.5;                   // 3連敗=半減
   else            f = 1.0;                   // 通常
   if(f <= 0.0) return 0.0;                    // 停止

   double lot  = InpLots * f;
   double mn   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   lot = MathMax(mn, MathFloor(lot/step + 0.5)*step);
   return lot;
}

//+------------------------------------------------------------------+
//| ★損切り救済の発火をGV/ログへ公開(Watchdog表示・スマホ通知用)    |
//|   kind: 1=✖滑り救済 / 2=緊急逆行 / 3=イベント / 4=週末          |
//+------------------------------------------------------------------+
void PublishRescue(int kind, double pip)
{
   datetime now = TimeCurrent();
   GlobalVariableSet(StringFormat("DK_EA_LASTRESCUE_%d", InpMagic), (double)now);
   GlobalVariableSet(StringFormat("DK_EA_RESCUEPIP_%d",  InpMagic), pip);
   GlobalVariableSet(StringFormat("DK_EA_RESCUEKIND_%d", InpMagic), (double)kind);
   string knd = (kind==2)?"緊急逆行":(kind==3)?"イベント":(kind==4)?"週末":"✖滑り救済";
   Print("[EA] 損切り再決済 約定 ", DoubleToString(pip,1), "pip (", knd, ")");
   // ★DiscordはOnTick内でWebRequest不可 → OnTimerで送る
   g_rescueDiscMsg = StringFormat("【救済】DokaKotsu 損切り再決済 %.1fpip (%s) %s JST",
                       pip, knd, TimeToString(TimeLocal(), TIME_MINUTES));
   g_rescueDiscPending = true;
}

//+------------------------------------------------------------------+
//| ★自分(magic一致)の保有を強制決済。許容スリッページを広げて急変  |
//|   でも約定させる。成功した建玉ごとに約定pipを救済として公開。     |
//|   戻り値: 全部消えたら true                                       |
//+------------------------------------------------------------------+
bool ForceCloseMyPositions(int kind, const string why)
{
   bool allClosed = true;
   trade.SetDeviationInPoints(InpExitRetryDevPts);   // ★急変時に約定させるため広く
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC)  != InpMagic) continue;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      long   ptype = PositionGetInteger(POSITION_TYPE);
      if(trade.PositionClose(tk))
      {
         double fill = trade.ResultPrice();
         double pip  = (ptype==POSITION_TYPE_BUY) ? (fill-entry)/PIP : (entry-fill)/PIP;
         PublishRescue(kind, pip);
      }
      else
      {
         allClosed = false;
         g_lastOrderErr = (int)trade.ResultRetcode();
         if(g_lastOrderErr==0) g_lastOrderErr=(int)GetLastError();
         Print("[EA] 強制決済リトライ失敗 (", why, ") ticket=", tk,
               " retcode=", trade.ResultRetcode(), " (", trade.ResultRetcodeDescription(), ")");
      }
   }
   trade.SetDeviationInPoints(InpSlippage);            // ★通常スリッページへ戻す
   return allClosed;
}

//+------------------------------------------------------------------+
//| ★決済を命令(=ラッチを立て、その場で強制決済を1回試行)。         |
//|   以後 ReconcileExit が毎ティック、保有が消えるまで再送する。     |
//+------------------------------------------------------------------+
void CommandExit(int kind, const string why)
{
   if(!g_exitCommanded)            // 新規の命令だけ時刻を記録
   {
      g_exitCmdTime        = TimeCurrent();
      g_exitTimeoutNoticed = false;
   }
   g_exitCommanded = true;
   g_exitKind      = kind;
   g_exitWhy       = why;
   ForceCloseMyPositions(kind, why);
}

//+------------------------------------------------------------------+
//| ★毎ティック先頭: 決済命令が残っていて保有も残っていれば再送。    |
//|   フラットを確認した時点でラッチを下ろす。長引けば通知フラグ。   |
//+------------------------------------------------------------------+
void ReconcileExit()
{
   if(!InpUseExitRetry)  return;
   if(!g_exitCommanded)  return;

   ulong tk=0;
   int pos = CurrentPos(tk);
   if(pos==0)                       // ★実際にフラット=救済完了
   {
      g_exitCommanded      = false;
      g_exitCmdTime        = 0;
      g_exitTimeoutNoticed = false;
      return;
   }
   // まだ保有 → 出るまで毎ティック投げ続ける(広いスリッページ)
   ForceCloseMyPositions(g_exitKind, g_exitWhy);

   // 命令から InpExitTimeoutSec を超えても残っている=異常。1回だけ通知。
   if(!g_exitTimeoutNoticed && g_exitCmdTime>0 &&
      (TimeCurrent() - g_exitCmdTime) >= InpExitTimeoutSec)
   {
      g_exitTimeoutNoticed = true;
      g_rescueDiscMsg = StringFormat("【!】DokaKotsu 決済が%d秒たっても約定せず保有残存(%s) %s JST",
                          InpExitTimeoutSec, g_exitWhy, TimeToString(TimeLocal(), TIME_MINUTES));
      g_rescueDiscPending = true;
   }
}

//+------------------------------------------------------------------+
//| ★緊急逆行ストップ(失敗②=飛び越え対策・任意)。✖が出ないまま     |
//|   含み損が InpEmergencyPips に触れたら即・強制決済を命令する。    |
//|   戻り値: 命令を出したら true(呼び出し側で pos を読み直す)。      |
//+------------------------------------------------------------------+
bool CheckEmergencyStop(int pos)
{
   if(!InpUseEmergencyStop) return false;
   if(pos==0)               return false;
   if(g_exitCommanded)      return false;   // 既に決済中なら二重に出さない

   ulong tk=0;
   if(CurrentPos(tk)==0 || tk==0) return false;
   if(!PositionSelectByTicket(tk)) return false;
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double bid   = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask   = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double adversePips = (pos==1) ? (entry-bid)/PIP : (ask-entry)/PIP;  // 含み損(正=逆行)
   if(adversePips >= InpEmergencyPips)
   {
      Print("[EA] ★緊急逆行ストップ発火 逆行=", DoubleToString(adversePips,1),
            "pip ≥ ", DoubleToString(InpEmergencyPips,1), "pip → 強制決済");
      CommandExit(2, StringFormat("緊急逆行%.0fpip", InpEmergencyPips));
      g_lastSignalBar = (datetime)iTime(_Symbol,_Period,0);  // 同足の即・再エントリーを抑止
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| メイン:毎ティック。判断はインジ、EAは即実行のみ。               |
//+------------------------------------------------------------------+
void OnTick()
{
   // ★決済命令が残っていれば最優先で再送(出るまで追う=失敗①対策)
   ReconcileExit();

   // 建値ストップは毎ティック監視(含み益を即守る)
   ManageBreakeven();

   datetime curBar = (datetime)iTime(_Symbol, _Period, 0);

   // ★連敗回数は新足ごとに実履歴から再計算してキャッシュ(毎ティックのHistorySelectを避ける)
   static datetime s_lastStreakBar = 0;
   if(curBar != s_lastStreakBar) { s_lastStreakBar = curBar; g_lossStreak = DK_LossStreak(); g_dayPip = DK_DayPip(); UpdateResumeButton(); }

   bool inStop  = IsInStopTime();
   bool inEvent = IsInEventWindow();   // FOMC/NFP予防線の窓内か(手入力・既定OFF)

   // ★MT5カレンダー: CPI/NFP/FOMC と 米国休日 を更新
   RefreshCalEvent();
   RefreshUSHoliday();
   bool calBan   = (g_evState == 1);   // イベント新規禁止(デッドレンジ/発表後)。リーク(2)は許可
   bool usHol    = g_usHol;            // 米国休日(JST18:00〜翌07:00)
   bool yearEnd  = IsYearEndStop();    // 年末年始(12/30〜1/3)

   // ★イベント-1分: 含み益なら建値(発表スパイク保険)。早期フラットはしない。
   if(g_evNeedBE) ForceEventBreakeven();
   bool inWeekendFlat = IsWeekendFlattenTime();   // 金曜クローズ前の強制決済時間か
   bool inFriBan = IsFridayEntryBan();            // ★金曜の新規停止(JST土曜02:00〜)

   // インジのシグナルを「形成中足(shift=0)」から読む = 速攻
   double vB=0, vS=0, vE=0;
   bool sBuy  = ReadBuf(7, 0, vB);
   bool sSell = ReadBuf(8, 0, vS);
   bool sExit = ReadBuf(9, 0, vE);

   ulong tk=0;
   int pos = CurrentPos(tk);
   g_lastOrderErr = 0;

   // ★緊急逆行ストップ(失敗②対策・任意)。✖が出ないまま走った時の保険。
   if(CheckEmergencyStop(pos)) pos = CurrentPos(tk);

   // ★イベント予防線:窓に入ったら保有を手仕舞い(発表のスパイクに晒さない)
   if(inEvent && InpEventFlatten && pos != 0)
   {
      CommandExit(3, "イベント決済");   // ★1回失敗で諦めず再送(失敗①対策)
      LogReason(curBar, "イベント決済");
      pos = CurrentPos(tk);
   }

   // ★週末持ち越し防止:金曜クローズ前は保有を強制決済(以降は新規も停止)
   if(inWeekendFlat && pos != 0)
   {
      CommandExit(4, "週末強制決済");   // ★1回失敗で諦めず再送(失敗①対策)
      LogReason(curBar, "週末強制決済");
      pos = CurrentPos(tk);
   }

   // ① 決済(最優先):EXITが出ていて保有があれば即クローズ。
   //    ※ドテン(同足で反対へ反転)は廃止。反対側は通常の確認付きエントリーに任せる(フラッシュ対策)。
   if(sExit && pos != 0)
   {
      CommandExit(1, "決済(✖)");   // ★1回で諦めず保有が消えるまで広スリッページで再送
      LogReason(curBar, "決済OK");
      pos = CurrentPos(tk);
   }
   // ② 新規:ノーポジ・稼働時間内・イベント窓外・金曜停止外・この足でまだ入っていない → 即発注
   else if(pos == 0 && !inStop && !inEvent && !calBan && !usHol && !yearEnd && !inWeekendFlat && !inFriBan && !DK_IsDayPipStopped() && curBar != g_lastSignalBar)
   {
      double useLot = DK_OrderLot();   // ★連敗ロット(0=停止)
      if(useLot <= 0.0)
      {
         // 4連敗=停止(再開フラグが無い限り新規を出さない)。診断行に「連敗停止」を残す。
      }
      else if(sBuy && !sSell)
      {
         if(OpenTrade(ORDER_TYPE_BUY, useLot))  { g_lastSignalBar = curBar; LogReason(curBar, "エントリーBUY"); }
      }
      else if(sSell && !sBuy)
      {
         if(OpenTrade(ORDER_TYPE_SELL, useLot)) { g_lastSignalBar = curBar; LogReason(curBar, "エントリーSELL"); }
      }
   }

   // 新足ごとに診断行を1行(理由の流れを残す)
   if(curBar != g_lastBarTime)
   {
      g_lastBarTime = curBar;
      int code = ReadReason(1);  // 確定足(shift1)の判断理由
      bool lossStop = DK_IsLossStopped();
      bool dayStop  = DK_IsDayPipStopped();
      string evName = (g_evKind==EV_FOMC)?"FOMC発表前停止":(g_evKind==EV_NFP)?"雇用統計発表前停止":"CPI発表前停止";
      string note = (pos!=0) ? "保有中"
                  : (dayStop       ? "日次損失上限停止"
                  : (lossStop      ? "連敗停止"
                  : (yearEnd       ? "年末年始停止"
                  : (usHol         ? "米国休日停止"
                  : (inWeekendFlat ? "週末クローズ"
                  : (calBan        ? evName
                  : (inFriBan      ? "金曜停止"
                  : (inStop        ? "オセアニア市場停止"
                  : (inEvent       ? "イベント予防線" : "ノーポジ")))))))));
      // ★停止理由をGVへ(Watchdog表示用)
      int rcode = DK_StopReasonCode(dayStop, lossStop, inWeekendFlat, inFriBan, usHol, yearEnd, inStop);
      g_stopReason = rcode;
      GlobalVariableSet(StringFormat("DK_EA_STOPREASON_%d", InpMagic), (double)rcode);
      WriteReasonRow(curBar, code, pos, 0, (int)(inStop||inEvent||calBan||usHol||yearEnd||inFriBan), note);
   }
}

//+------------------------------------------------------------------+
//| 発注(SLは任意)。成功でtrue。失敗時は g_lastOrderErr に格納      |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE type, double lots)
{
   double price = (type==ORDER_TYPE_BUY)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0.0;
   if(InpUseSL)
   {
      double d = InpSLpips * PIP;
      sl = (type==ORDER_TYPE_BUY) ? price - d : price + d;
      sl = NormalizeDouble(sl, _Digits);
   }

   bool ok;
   if(type==ORDER_TYPE_BUY) ok = trade.Buy(lots, _Symbol, 0.0, sl, 0.0, "DokaKotsu");
   else                     ok = trade.Sell(lots, _Symbol, 0.0, sl, 0.0, "DokaKotsu");

   if(ok) Print("[EA] ", (type==ORDER_TYPE_BUY?"BUY":"SELL"), " OK lots=", lots,
                " (連敗", g_lossStreak, ")",
                " sl=", (InpUseSL?DoubleToString(sl,_Digits):"none"));
   else
   {
      g_lastOrderErr = (int)trade.ResultRetcode();
      if(g_lastOrderErr==0) g_lastOrderErr = (int)GetLastError();
      Print("[EA] 発注失敗 retcode=", trade.ResultRetcode(),
            " (", trade.ResultRetcodeDescription(), ") err=", GetLastError());
   }
   return ok;
}

//+------------------------------------------------------------------+
//| 理由コード → 日本語(インジ DokaKotsu_indicator_8 と対応)        |
//+------------------------------------------------------------------+
string ReasonText(int code)
{
   switch(code)
   {
      case 1:  return "BUY発生";
      case 2:  return "SELL発生";
      case 10: return "グレーゾーン(レンジ)";
      case 11: return "M1スパイク無し";
      case 12: return "圧縮スクイーズ中";
      case 13: return "オーバーシュート";
      case 14: return "再エントリーロック";
      case 15: return "クールダウン中";
      case 16: return "EMA未点灯/方向不一致";
      case 17: return "色の確認待ち(持続不足)";
      case 18: return "平均足が逆色(調整波回避)";
      case 19: return "M15不一致(M15グレー/逆)";
      case 20: return "保有中(新規対象外)";
      case 21: return "出来高薄(薄商い)";
      case 30: return "決済(平均足反転)";
      case 31: return "決済(MA急反転)";
      case 32: return "決済(MAグレー化)";
      default: return "(未評価)";
   }
}
int ReasonDir(int code){ if(code==1) return 1; if(code==2) return -1; return 0; }

//--- ★Ver8: 15分足の状態 → 表示文字(リーズンCSVの新列)
string M15StateText(int s)
{
   if(s == 1)  return "15分足上昇";
   if(s == -1) return "15分足下降";
   return "15分足グレー";
}
//--- ★2026-06-22: 平均足の色 → 表示文字(リーズンCSVの新列。平均足は二値)
string HaStateText(int s){ return (s==1) ? "平均足上昇" : "平均足下降"; }

//+------------------------------------------------------------------+
//| いま(shift0)の理由 + 任意のノートでCSVに1行                    |
//+------------------------------------------------------------------+
void LogReason(datetime bt, string note)
{
   if(!InpLogReason) return;
   ulong tk=0; int pos = CurrentPos(tk);
   WriteReasonRow(bt, ReadReason(0), pos, 0, (int)IsInStopTime(), note);
}

//+------------------------------------------------------------------+
//| 理由を1行CSVに追記(日付ごとにファイル分割)                      |
//|   保存先: MQL5\Files\<InpReasonDir>\reason_YYYYMMDD.csv          |
//+------------------------------------------------------------------+
void WriteReasonRow(datetime bt, int code, int pos, int cd, int tf, string eaNote)
{
   if(!InpLogReason) return;
   // ★JSTで記録:ファイル名の日付・time列ともJST(サーバー→JSTは夏+6/冬+7)
   int jstOff = IsSummerTime(bt) ? InpJstOffSummer : InpJstOffWinter;
   datetime btJst = bt + jstOff*3600;
   MqlDateTime dt; TimeToStruct(btJst, dt);
   string fname = StringFormat("%s\\reason_%04d%02d%02d.csv",
                               InpReasonDir, dt.year, dt.mon, dt.day);
   bool isNew = !FileIsExist(fname);
   int h = FileOpen(fname, FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
   {
      Print("[EA] 理由CSVを開けません err=", GetLastError(), " path=", fname);
      g_reasonFailPending = true;   // ★OnTimerでDiscordへ通知(OnTick内ではWebRequestしない)
      return;
   }
   FileSeek(h, 0, SEEK_END);
   if(isNew)
      FileWrite(h, "time","dir","code","ha","m15","reason","ea_note","pos","cooldown","time_filter","order_err");
   FileWrite(h,
      TimeToString(btJst, TIME_DATE|TIME_MINUTES),
      ReasonDir(code), code, HaStateText(ReadHaState(0)), M15StateText(ReadM15State(0)), ReasonText(code), eaNote,
      pos, cd, tf, g_lastOrderErr);
   FileClose(h);
   // ★理由CSVを実際に書けた時刻をGVへ(watchdogの「reasonログ」健全性判定に使用)
   if(InpHeartbeat)
      GlobalVariableSet(StringFormat("DK_EA_LASTREASON_%d", InpMagic), (double)TimeCurrent());
}
//+------------------------------------------------------------------+
