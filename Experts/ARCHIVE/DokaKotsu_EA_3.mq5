//+------------------------------------------------------------------+
//|                              DokaKotsu_EA_3.mq5                   |
//|                                                                  |
//|  ■ このEAは何をするか(役割)                                     |
//|    DokaKotsu_indicator_6 が出すシグナルを「来たら速攻で実行」    |
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
//|  ■ 今回追加した機能 (EA_3 / 2026-06-14)                       |
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
#property version   "3.10"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//=== バージョン(最新確認用) =======================================
#define EA_VERSION "v3.1"
#define EA_BUILD   "2026-06-15 EA_3 / 参照先=DokaKotsu_indicator_6 / 金曜停止+ハートビート+Discord"

//=== 入力 =========================================================
input string InpVersionInfo  = "v3.1 / EA_3 / 金曜停止 + ハートビート + Discord通知"; // ★バージョン(確認用)
input double InpLots         = 0.01;   // ロット数(固定)※最小ロット
input bool   InpUseSL        = true;   // 保険のSLを置くか(急変対策)
input double InpSLpips       = 100.0;  // SL幅(pips)。InpUseSL=true時

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
input string InpIndicatorName = "DokaKotsu_indicator_6"; // 読み込むインジ名

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
double    PIP = 0.0;                   // 1pipの価格幅

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
      WriteHeartbeatFile();   // ★起動直後にもファイル出力(モニター用)
   }

   Print("[EA] 起動 ", EA_VERSION, " build ", EA_BUILD,
         " / Lots=", InpLots,
         " SL=", (InpUseSL?DoubleToString(InpSLpips,1)+"pips":"OFF"),
         " BE=", (InpUseBreakeven?DoubleToString(InpBEtriggerPips,0)+"pip":"OFF"),
         " 実行=shift0(即時)");

   if(InpDiscordOnStart)
      PostDiscord(StringFormat("【起動】DokaKotsu EA_3 %s  %s JST",
                  EA_VERSION, TimeToString(TimeLocal(), TIME_MINUTES)));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   if(hInd != INVALID_HANDLE) IndicatorRelease(hInd);
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

void OnTimer()
{
   if(InpHeartbeat)
   {
      GlobalVariableSet(StringFormat("DK_EA_HB_%d", InpMagic), (double)TimeCurrent());
      WriteHeartbeatFile();   // ★Python監視用(モニターがmtimeで生存判定)
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
         PostDiscord(StringFormat("【稼働】DokaKotsu EA_3  保有=%s  証拠金=%.0f  %s JST",
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
   if(CopyBuffer(hInd, 11, shift, 1, rr) > 0) return (int)MathRound(rr[0]);
   return 0;
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
//| メイン:毎ティック。判断はインジ、EAは即実行のみ。               |
//+------------------------------------------------------------------+
void OnTick()
{
   // 建値ストップは毎ティック監視(含み益を即守る)
   ManageBreakeven();

   datetime curBar = (datetime)iTime(_Symbol, _Period, 0);
   bool inStop  = IsInStopTime();
   bool inEvent = IsInEventWindow();   // FOMC/NFP予防線の窓内か
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

   // ★イベント予防線:窓に入ったら保有を手仕舞い(発表のスパイクに晒さない)
   if(inEvent && InpEventFlatten && pos != 0)
   {
      if(trade.PositionClose(tk))
      {
         Print("[EA] イベント予防線で決済 ticket=", tk);
         LogReason(curBar, "イベント決済");
         pos = 0;
      }
      else
      {
         g_lastOrderErr = (int)GetLastError();
         Print("[EA] イベント決済 失敗 ticket=", tk, " err=", g_lastOrderErr);
      }
   }

   // ★週末持ち越し防止:金曜クローズ前は保有を強制決済(以降は新規も停止)
   if(inWeekendFlat && pos != 0)
   {
      if(trade.PositionClose(tk))
      {
         Print("[EA] 週末クローズ前の強制決済 ticket=", tk);
         LogReason(curBar, "週末強制決済");
         pos = 0;
      }
      else
      {
         g_lastOrderErr = (int)GetLastError();
         Print("[EA] 週末強制決済 失敗 ticket=", tk, " err=", g_lastOrderErr);
      }
   }

   // ① 決済(最優先):EXITが出ていて保有があれば即クローズ
   if(sExit && pos != 0)
   {
      if(trade.PositionClose(tk))
      {
         Print("[EA] 決済 OK ticket=", tk);
         LogReason(curBar, "決済OK");
      }
      else
      {
         g_lastOrderErr = (int)GetLastError();
         Print("[EA] 決済 失敗 ticket=", tk, " err=", g_lastOrderErr);
      }
   }
   // ② 新規:ノーポジ・稼働時間内・イベント窓外・金曜停止外・この足でまだ入っていない → 即発注
   else if(pos == 0 && !inStop && !inEvent && !inWeekendFlat && !inFriBan && curBar != g_lastSignalBar)
   {
      if(sBuy && !sSell)
      {
         if(OpenTrade(ORDER_TYPE_BUY))  { g_lastSignalBar = curBar; LogReason(curBar, "エントリーBUY"); }
      }
      else if(sSell && !sBuy)
      {
         if(OpenTrade(ORDER_TYPE_SELL)) { g_lastSignalBar = curBar; LogReason(curBar, "エントリーSELL"); }
      }
   }

   // 新足ごとに診断行を1行(理由の流れを残す)
   if(curBar != g_lastBarTime)
   {
      g_lastBarTime = curBar;
      int code = ReadReason(1);  // 確定足(shift1)の判断理由
      string note = (pos!=0) ? "保有中" : (inWeekendFlat ? "週末クローズ" : (inFriBan ? "金曜停止" : (inEvent ? "イベント予防線" : (inStop ? "時間フィルター" : "ノーポジ"))));
      WriteReasonRow(curBar, code, pos, 0, (int)(inStop||inEvent||inFriBan), note);
   }
}

//+------------------------------------------------------------------+
//| 発注(SLは任意)。成功でtrue。失敗時は g_lastOrderErr に格納      |
//+------------------------------------------------------------------+
bool OpenTrade(ENUM_ORDER_TYPE type)
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
   if(type==ORDER_TYPE_BUY) ok = trade.Buy(InpLots, _Symbol, 0.0, sl, 0.0, "DokaKotsu");
   else                     ok = trade.Sell(InpLots, _Symbol, 0.0, sl, 0.0, "DokaKotsu");

   if(ok) Print("[EA] ", (type==ORDER_TYPE_BUY?"BUY":"SELL"), " OK lots=", InpLots,
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
//| 理由コード → 日本語(インジ DokaKotsu_indicator_6 と対応)        |
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
      case 20: return "保有中(新規対象外)";
      case 30: return "決済(EXIT)";
      default: return "(未評価)";
   }
}
int ReasonDir(int code){ if(code==1) return 1; if(code==2) return -1; return 0; }

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
      FileWrite(h, "time","dir","code","reason","ea_note","pos","cooldown","time_filter","order_err");
   FileWrite(h,
      TimeToString(btJst, TIME_DATE|TIME_MINUTES),
      ReasonDir(code), code, ReasonText(code), eaNote,
      pos, cd, tf, g_lastOrderErr);
   FileClose(h);
   // ★理由CSVを実際に書けた時刻をGVへ(watchdogの「reasonログ」健全性判定に使用)
   if(InpHeartbeat)
      GlobalVariableSet(StringFormat("DK_EA_LASTREASON_%d", InpMagic), (double)TimeCurrent());
}
//+------------------------------------------------------------------+
