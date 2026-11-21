//+------------------------------------------------------------------+
//|                              DokaKotsu_EA.mq5                    |
//|   DokaKotsu_indicator_2 のシグナルで売買するEA(ロジック無し版)  |
//|                                                                  |
//|   役割: インジが判断、EAは実行するだけ。                         |
//|     iCustomで DokaKotsu_indicator_2 のバッファを読む:           |
//|       バッファ7=BUY矢印 / 8=SELL矢印 / 9=EXIT(決済)            |
//|                                                                  |
//|   処理優先順位(毎・確定足):                                      |
//|     ① 決済(最優先・確実性重視): EXITが出たら保有を閉じる        |
//|     ② 新規エントリー: BUY/SELL矢印。ただし決済後の              |
//|        クールダウン(InpCooldownBars本)中は入らない(調整波回避) |
//|     ③ (将来) Python送信は別途・後から分離して追加               |
//|                                                                  |
//|   ※ DokaKotsu_indicator_2 と同じチャート(同じ時間足/銘柄)に   |
//|     適用すること。インジのバッファ構成と一致が前提。            |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
CTrade trade;

//=== バージョン(最新確認用) =======================================
#define EA_VERSION "v1.1"
#define EA_BUILD   "2026-06-08 09:00 DBG"

//=== 入力 =========================================================
input string InpVersionInfo  = "v1.1 / 2026-06-08 09:00 DBG"; // ★バージョン(確認用・変更不要)
input double InpLots         = 0.10;   // ロット数(固定)
input int    InpCooldownBars = 5;      // 決済後この本数はエントリー禁止(調整波回避)
input bool   InpUseSL        = true;   // 保険のSLを置くか(急変対策)
input double InpSLpips       = 30.0;   // SL幅(pips)。InpUseSL=true時
input int    InpMagic        = 20260606;// マジックナンバー(このEAの注文識別)
input int    InpSlippage     = 20;     // 許容スリッページ(ポイント)

//--- 時間フィルター(JST)
input bool   InpUseTimeFilter = true;  // 時間フィルターを使うか
input int    InpStopHourJST   = 4;     // 停止開始時刻(JST・時)
input int    InpStopMinJST    = 0;     // 停止開始時刻(JST・分)
input int    InpResumeHourJST = 7;     // 再開時刻(JST・時)  ※7:00=6:59まで停止
input int    InpResumeMinJST  = 0;     // 再開時刻(JST・分)

//--- インジ名(MQL5\Indicators\ 直下に置く場合はこの名前)
input string InpIndicatorName = "DokaKotsu_indicator_2"; // 読み込むインジ名

//=== 内部 =========================================================
int       hInd     = INVALID_HANDLE;   // インジハンドル
datetime  g_lastBarTime = 0;           // 最後に処理した足の時刻(新足検出用)
datetime  g_lastExitBar = 0;           // 最後に決済した足の時刻(クールダウン用)
int       g_cooldownLeft = 0;          // 残りクールダウン本数

double    PIP = 0.0;                    // 1pipの価格幅

//+------------------------------------------------------------------+
int OnInit()
{
   // pip幅(XAUUSDは 0.1 が1pip相当。桁で自動判定)
   PIP = (_Digits==3 || _Digits==5) ? _Point*10 : _Point;
   // ゴールドは慣習的に 0.1 を1pipとするので明示
   if(_Symbol=="XAUUSD" || StringFind(_Symbol,"XAU")>=0) PIP = 0.1;

   // インジをロード(チャートと同じ時間足・銘柄)
   //   ※インジの入力はインジ側のデフォルトを使う(EAからは指定しない=
   //     チャートに乗っているインジ設定と揃えるのは運用で担保)
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

   Print("[EA] 起動 ", EA_VERSION, " build ", EA_BUILD,
         " / Lots=", InpLots, " Cooldown=", InpCooldownBars,
         " SL=", (InpUseSL?DoubleToString(InpSLpips,1)+"pips":"OFF"));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hInd != INVALID_HANDLE) IndicatorRelease(hInd);
}

//+------------------------------------------------------------------+
//| このEA(マジック一致)の保有ポジション方向を返す                 |
//|   1=買い保有 / -1=売り保有 / 0=なし                            |
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
//| インジのバッファ値を1本分読む(shift本前)。値が有効ならtrue     |
//+------------------------------------------------------------------+
bool ReadBuf(int bufIndex, int shift, double &valOut)
{
   double tmp[];
   if(CopyBuffer(hInd, bufIndex, shift, 1, tmp) <= 0) return false;
   valOut = tmp[0];
   // 矢印/EXITは「値あり」がシグナル。0やEMPTY_VALUEは非シグナル。
   if(valOut==0.0 || valOut==EMPTY_VALUE || !MathIsValidNumber(valOut)) return false;
   return true;
}

//+------------------------------------------------------------------+
//| 時間フィルター判定(JST)                                         |
//|   MT5のサーバー時刻はUTC。JSTはUTC+9。                          |
//|   戻り値: true=停止時間帯 / false=稼働OK                        |
//+------------------------------------------------------------------+
bool IsInStopTime()
{
   if(!InpUseTimeFilter) return false;

   // サーバー時刻(UTC)→ JST(+9時間)
   datetime utcNow  = TimeCurrent();
   datetime jstNow  = utcNow + 9 * 3600;

   MqlDateTime jst;
   TimeToStruct(jstNow, jst);

   int nowMin  = jst.hour * 60 + jst.min;
   int stopMin = InpStopHourJST  * 60 + InpStopMinJST;   // 4*60+0 = 240
   int resumeMin = InpResumeHourJST * 60 + InpResumeMinJST; // 7*60+0 = 420

   if(stopMin < resumeMin)
      return (nowMin >= stopMin && nowMin < resumeMin);   // 通常: 240〜419
   else
      // 日をまたぐ場合(例: 22:00〜03:00)
      return (nowMin >= stopMin || nowMin < resumeMin);
}

//+------------------------------------------------------------------+
void OnTick()
{
   // --- 新しい確定足ができた時だけ処理(確定足=shift1で判定) ---
   datetime curBar = (datetime)iTime(_Symbol, _Period, 0);
   if(curBar == g_lastBarTime) return;   // まだ同じ足 → 何もしない
   g_lastBarTime = curBar;
   // ここから下は「新しい足が出た最初の1回」だけ実行される

   // --- 時間フィルター(JST 04:00〜06:59 は新規エントリー禁止) ---
   bool inStop = IsInStopTime();

   // 直前の確定足(shift=1)のシグナルを読む
   double vBuy=0, vSell=0, vExit=0;
   bool sBuy  = ReadBuf(7, 1, vBuy);
   bool sSell = ReadBuf(8, 1, vSell);
   bool sExit = ReadBuf(9, 1, vExit);

   ulong tk=0;
   int pos = CurrentPos(tk);

   // ===== ↓デバッグ用(原因切り分けが終わったら削除OK) =====
   //   新足ごとに1行出力。エキスパートタブで確認する。
   //     r7/r8/r9 : CopyBufferの戻り(>0で成功・<=0で読み取り失敗)
   //     v7/v8/v9 : BUY/SELL/EXITバッファの値(0.000=非シグナル)
   //     pos      : 保有方向(1=買い/-1=売り/0=なし)
   //     cd       : 残りクールダウン本数 / stop : 時間フィルター停止中か(1=停止)
   {
      double raw7[], raw8[], raw9[];
      int r7 = CopyBuffer(hInd, 7, 1, 1, raw7);
      int r8 = CopyBuffer(hInd, 8, 1, 1, raw8);
      int r9 = CopyBuffer(hInd, 9, 1, 1, raw9);
      PrintFormat("[DBG] %s r7=%d v7=%.3f | r8=%d v8=%.3f | r9=%d v9=%.3f | pos=%d cd=%d stop=%d hInd=%d",
         TimeToString(curBar), r7,(r7>0?raw7[0]:-999.0), r8,(r8>0?raw8[0]:-999.0),
         r9,(r9>0?raw9[0]:-999.0), pos, g_cooldownLeft, (int)inStop, hInd);
   }
   // ===== ↑デバッグ用ここまで =====

   // ───────────────────────────────────────────────
   // ① 決済(最優先) — EXITが出ていて、保有があれば閉じる
   // ───────────────────────────────────────────────
   if(sExit && pos != 0)
   {
      if(trade.PositionClose(tk))
      {
         Print("[EA] 決済 OK ticket=", tk);
         g_cooldownLeft = InpCooldownBars;   // 決済後クールダウン開始
      }
      else
         Print("[EA] 決済 失敗 ticket=", tk, " err=", GetLastError());
      // 決済した足では新規を出さない(同足ドテン防止)
      return;
   }

   // クールダウンを1本消化(決済していない新足ごと)
   if(g_cooldownLeft > 0) g_cooldownLeft--;

   // ───────────────────────────────────────────────
   // ② 新規エントリー — ノーポジ かつ クールダウン明け かつ 稼働時間内
   // ───────────────────────────────────────────────
   if(pos == 0 && g_cooldownLeft <= 0 && !inStop)
   {
      if(sBuy && !sSell)
         OpenTrade(ORDER_TYPE_BUY);
      else if(sSell && !sBuy)
         OpenTrade(ORDER_TYPE_SELL);
   }

   // ③ (将来) ここでPython送信を追加する場所。
   //    取引処理の後に分離して置くことで、送信が遅れても取引は守られる。
}

//+------------------------------------------------------------------+
//| 発注(SLは任意)                                                  |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type)
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
   else   Print("[EA] 発注失敗 err=", GetLastError());
}
//+------------------------------------------------------------------+
