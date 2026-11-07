//+------------------------------------------------------------------+
//|                         DokaKotsu_Watchdog.mq5                   |
//|  バージョン : v1.2 (インジケーター版 / _Ind→_Watchdogへ改名)      |
//|  更新日時   : 2026-06-20 (JST)                                   |
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
#property version   "1.10"
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
//--- ★決済の安全網(見張り+緊急ブザー)
input string InpIndicatorPrefix = "DokaKotsu_indicator_"; // ★2026-07-08変更: 監視する本体インジ名の"接頭辞"のみ指定。バージョン番号(_10/_13等)は自動検出するため毎回の手動更新が不要
input bool   InpForceExit      = true;      // ★EXIT継続なのに保有残存(背景も保有方向でない)を検知→EAへ決済指示(GV)
input int    InpStuckGraceSec  = 20;        // ★その状態がこの秒数続いたら決済指示を発令(EAの自力決済を待つ猶予)

//--- 状態
enum WD_STATE { WD_OK=0, WD_MARKET_CLOSED=1, WD_REASON_DOWN=2, WD_EA_DOWN=3 };
WD_STATE  g_prev      = WD_OK;
datetime  g_lastAlert = 0;
bool      g_started   = false;
string    LBL_MAIN   = "DKWD_main";
string    LBL_RESCUE = "DKWD_rescue";       // ★損切り救済の2行目ラベル
string    LBL_REASON = "DKWD_reason";       // ★2026-07-08追加: 停止理由専用の別行(1行目が画面幅で見切れて理由が読めない対策)
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
   CreateLabel(LBL_MAIN,   InpY,      InpFontSize, clrSilver, "DokaKotsu : starting...");
   CreateLabel(LBL_RESCUE, InpY + 22, InpFontSize, clrAqua,   "");   // ★救済表示(2行目)
   CreateLabel(LBL_REASON, InpY + 44, InpFontSize, clrOrange, "");   // ★2026-07-08追加: 停止理由(3行目)
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
   int     tickAge    = gotTick ? (int)(nowTrd - tk.time) : 999999;   // 進み続ける時計で測る
   bool    marketOpen = gotTick && tickAge >= 0 && tickAge <= InpTickStaleSec;

   // --- 3) 理由CSVの健全性(書込み成功時刻GV。市場オープン中のみ厳格判定) ---
   string   rsName = StringFormat("DK_EA_LASTREASON_%d", InpMagic);
   bool     rsEx   = GlobalVariableCheck(rsName);
   datetime rs     = rsEx ? (datetime)GlobalVariableGet(rsName) : 0;
   int      rsAge  = rsEx ? (int)(now - rs) : -1;
   bool reasonDown = (!eaDown) && marketOpen &&
                     ((!rsEx) || (rsAge < 0) || (rsAge > InpReasonStaleSec));

   // --- 総合状態 ---
   WD_STATE st;
   if(eaDown)           st = WD_EA_DOWN;
   else if(reasonDown)  st = WD_REASON_DOWN;
   else if(!marketOpen) st = WD_MARKET_CLOSED;
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

   // --- チャート表示(1行目=最重要枠: 年月日+稼働+緊急) ---
   bool tradeOk = GlobalVariableCheck(StringFormat("DK_EA_TRADEOK_%d",InpMagic)) && GlobalVariableGet(StringFormat("DK_EA_TRADEOK_%d",InpMagic))!=0.0;
   bool linkOk  = GlobalVariableCheck(StringFormat("DK_EA_LINKOK_%d", InpMagic)) && GlobalVariableGet(StringFormat("DK_EA_LINKOK_%d", InpMagic))!=0.0;
   string ts   = NowStamp();
   string hbT  = (eaAge>=0) ? (AgeTxt(eaAge)+"前") : "—";
   string tail = " / EA心拍 "+hbT+" / 自動売買"+(tradeOk?"ON":"OFF")+" / 連携"+(linkOk?"OK":"NG");
   color  c; string main; string reasonLine = "";
   if(eaDown)            { c=clrRed;    main = ts+"  🚨EA停止"+tail+" / EAを確認!"; }
   else if(stuck)        { c=clrRed;    main = ts+"  🚨EXIT継続なのに保有残存"+tail+(fire?" / 決済指示発令":" / 監視中(猶予)"); }
   else if(!marketOpen)  { c=clrSilver; main = ts+"  ⏸市場休場"+tail; }
   else if(reasonDown)   { c=clrOrange; main = ts+"  ⚠理由ログ停止"+tail; }
   else if(rcode>0)      { c=clrOrange; main = ts+"  ⚠EA稼働(停止理由あり)"+tail;
                            reasonLine = "　→ "+ReasonText(rcode,lstreak); }   // ★2026-07-08変更: 1行目に詰め込まず専用行へ(画面幅で見切れ対策)
   else                  { c=clrLime;   main = ts+"  ✅EA正常稼働"+tail+" / 異常なし"; }
   SetLabel(LBL_MAIN, c, main);
   SetLabel(LBL_REASON, clrOrange, reasonLine);   // ★2026-07-08追加: 空文字なら非表示(SetLabel/DrawWarnLine同様の挙動)

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
   bool isBad = (st==WD_EA_DOWN || st==WD_REASON_DOWN);
   if(isBad)
   {
      bool changed = g_started && (st != g_prev);
      bool firstBad= (!g_started);   // 起動直後から異常なら即通知
      bool resend  = (InpResendMin > 0 && g_lastAlert > 0 &&
                      (now - g_lastAlert) >= (datetime)InpResendMin*60);
      if(changed || firstBad || resend)
      {
         string head = (st==WD_EA_DOWN) ? "【!】DokaKotsu EA停止"
                                        : "【!】DokaKotsu reasonログ停止";
         string msg  = StringFormat("%s (EA最終%s前 / reason%s前) %s JST",
                          head, AgeTxt(eaAge), AgeTxt(rsAge),
                          TimeToString(TimeLocal(), TIME_MINUTES));
         Notify(msg);
         g_lastAlert = now;
      }
   }
   else
   {
      // 復旧通知(直前が異常 → 正常/クローズ)
      if(InpNotifyRecover && g_started &&
         (g_prev==WD_EA_DOWN || g_prev==WD_REASON_DOWN))
      {
         Notify(StringFormat("【OK】DokaKotsu 復旧: %s  %s JST",
                main, TimeToString(TimeLocal(), TIME_MINUTES)));
      }
      g_lastAlert = 0;
   }
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
//--- 停止理由コード → 表示文言(EA側 DK_StopReasonCode と対応)
string ReasonText(int code, int streak)
{
   switch(code)
   {
      case 1: return "オセアニア市場停止";
      case 2: return "金曜深夜新規停止";
      case 3: return "CPI発表前停止";
      case 4: return "雇用統計発表前停止";
      case 5: return "FOMC発表前停止";
      case 6: return "米国休日停止";
      case 7: return "日本休日停止";
      case 8: return StringFormat("連敗%d(4で停止)", streak);
      case 9: return "週末クローズ";
      default: return "";
   }
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
void SetLabel(string name, color c, string txt)
{
   if(ObjectFind(0, name) < 0)
      CreateLabel(name, InpY, InpFontSize, c, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetString (0, name, OBJPROP_TEXT,  txt);
}
//+------------------------------------------------------------------+
