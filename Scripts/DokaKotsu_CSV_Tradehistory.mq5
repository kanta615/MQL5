//+------------------------------------------------------------------+
//|                                  DokaKotsu_CSV_Tradehistory.mq5   |
//|   口座の取引履歴を、日本時間(JST)＋獲得Pips付きでCSV出力する     |
//|                                                                  |
//|   作成日時 : 2026.06.11 (JST)                                     |
//|   バージョン: 1.31                                                |
//|                                                                  |
//|   ── ver.1.31 変更点 ──                                          |
//|     ・「本日のみ出力」チェックを廃止(期間を選んでも今日しか出ない |
//|        不具合の原因だったため)。期間は「期間の選び方」一本に統一。 |
//|        初期値=今日。プルダウン/カレンダーを変えれば即反映。       |
//|     ・自動ファイル名を「年月日時分」のみに(期間ラベルを削除)。   |
//|   ── ver.1.30 ──                                                 |
//|     ・保存先フォルダ指定を追加(空=デスクトップ)。               |
//|     ・通貨ペアの例表記から「.raw」を削除。冒頭に作成日時を記載。  |
//|     ※プロパティ初期タブを「入力」固定はMQL5では不可             |
//|        (ターミナルのUI挙動でコード指定不可)。                   |
//|                                                                  |
//|   使い方:                                                        |
//|     ナビゲーター→スクリプト→チャートにドラッグ→               |
//|     「パラメータ入力」タブで期間を確認/変更→OK で実行           |
//|     出力先: 既定=デスクトップ(InpSaveFolderで変更可)             |
//|                                                                  |
//|   CSV項目(ヘッダー有り):                                          |
//|     連番, 注文番号, エントリー日時(JST), 曜日, 取引種別,          |
//|     勝敗(WIN/LOSE), ロット, 通貨ペア, エントリー価格, SL, TP,     |
//|     決済日時(JST), 決済価格, 獲得Pips, 損益, 手数料, スワップ     |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.31"
#property script_show_inputs

//=== 外部DLL =====================================================
//   ※ツール→オプション→エキスパートアドバイザで
//     「DLLの使用を許可する」にチェックが必要。
//   shell32 : メモ帳起動 / デスクトップ等のフォルダパス取得
//   kernel32: サンドボックス→保存先フォルダへのファイルコピー
#import "shell32.dll"
int ShellExecuteW(int hwnd, string lpOperation, string lpFile,
                  string lpParameters, string lpDirectory, int nShowCmd);
int SHGetSpecialFolderPathW(int hwnd, ushort &path[], int csidl, int create);
#import
#import "kernel32.dll"
int CopyFileW(string lpExistingFileName, string lpNewFileName, int bFailIfExists);
#import

#define CSIDL_DESKTOPDIRECTORY 0x0010   // 実体のデスクトップフォルダ

//=== 期間プリセット =============================================
enum ENUM_PERIOD_PRESET
{
   PRESET_CUSTOM,      // カレンダーで指定(下の開始日/終了日)
   PRESET_ALL,         // 全履歴
   PRESET_TODAY,       // 今日
   PRESET_YESTERDAY,   // 昨日
   PRESET_THIS_WEEK,   // 今週(月曜〜)
   PRESET_THIS_MONTH,  // 今月
   PRESET_LAST_MONTH,  // 先月
   PRESET_THIS_YEAR,   // 今年
   PRESET_VISIBLE      // 画面表示期間
};

//=== 入力パラメータ =============================================
input ENUM_PERIOD_PRESET InpPeriod = PRESET_TODAY;         // ★期間の選び方(初期=今日 / 変えると即反映)
input datetime InpFromDate  = D'2026.06.01 00:00';         // 開始日(カレンダー/JST) ※カレンダー指定時
input datetime InpToDate    = D'2026.06.11 00:00';         // 終了日(カレンダー/JST) ※カレンダー指定時
input string   InpSaveFolder= "";                          // 保存先フォルダ(空=デスクトップ / 例:D:\mt5\export)
input string   InpSymbol    = "";                          // 通貨ペア(空=全て / 例:XAUUSD)
input double   InpPipSize   = 0.1;                          // 1pipの価格幅(XAUUSD=0.1)
input bool     InpAutoDST   = true;                         // 夏/冬を自動判定してJST変換
input bool     InpManualSummer = true;                      // 手動時の夏時間(InpAutoDST=false時)
input bool     InpSlashDate    = false;                     // 日付区切り true=/ false=.
input string   InpFileName     = "";                        // 出力ファイル名(空=自動命名)

//+------------------------------------------------------------------+
//| 夏時間(米国DST)判定                                               |
//+------------------------------------------------------------------+
bool IsSummerTime(datetime t)
{
   if(!InpAutoDST) return InpManualSummer;
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
//| サーバー時刻 → JST  (JST = サーバー + 夏:6h / 冬:7h)             |
//+------------------------------------------------------------------+
datetime ToJST(datetime serverTime)
{
   int off = IsSummerTime(serverTime) ? 6 : 7;
   return serverTime + off*3600;
}

//+------------------------------------------------------------------+
//| JST → サーバー時刻 (ToJSTの逆変換)                               |
//+------------------------------------------------------------------+
datetime JstToServer(datetime jst)
{
   int off = IsSummerTime(jst) ? 6 : 7;
   return jst - off*3600;
}

//+------------------------------------------------------------------+
//| デスクトップの実フォルダパスを取得(取得失敗時は空文字)          |
//+------------------------------------------------------------------+
string GetDesktopPath()
{
   ushort buf[260];
   ArrayInitialize(buf, 0);
   if(SHGetSpecialFolderPathW(0, buf, CSIDL_DESKTOPDIRECTORY, 0))
      return ShortArrayToString(buf);
   return "";
}

//+------------------------------------------------------------------+
//| 日時を文字列に（JST・区切り指定）                                 |
//+------------------------------------------------------------------+
string FmtDateTime(datetime jst)
{
   MqlDateTime t; TimeToStruct(jst, t);
   string sep = InpSlashDate ? "/" : ".";
   return StringFormat("%04d%s%02d%s%02d %02d:%02d:%02d",
            t.year, sep, t.mon, sep, t.day, t.hour, t.min, t.sec);
}

//+------------------------------------------------------------------+
//| 曜日を日本語1文字で                                              |
//+------------------------------------------------------------------+
string WeekdayJP(datetime jst)
{
   MqlDateTime t; TimeToStruct(jst, t);
   string wd[] = {"日","月","火","水","木","金","土"};
   return wd[t.day_of_week];
}

//+------------------------------------------------------------------+
int OnStart()
{
   datetime from = 0, to = 0;
   datetime fromJst = 0, toJst = 0;
   bool serverSet = false;          // from/to が既にサーバー時間ならtrue
   string periodLabel = "";

   //── JSTの「今」と各種日付境界を用意 ──
   datetime nowJst = ToJST(TimeCurrent());
   MqlDateTime n; TimeToStruct(nowJst, n);

   MqlDateTime d0 = n; d0.hour=0; d0.min=0; d0.sec=0;
   datetime todayStartJst = StructToTime(d0);                 // 今日 0:00 (JST)

   int dow = n.day_of_week;                                   // 0=日..6=土
   int backToMon = (dow == 0) ? 6 : (dow - 1);
   datetime weekStartJst = todayStartJst - backToMon*86400;   // 今週 月曜0:00

   MqlDateTime dm = n; dm.day=1; dm.hour=0; dm.min=0; dm.sec=0;
   datetime monthStartJst = StructToTime(dm);                 // 今月 1日0:00

   MqlDateTime dlm = dm;
   if(dlm.mon == 1){ dlm.mon = 12; dlm.year--; } else dlm.mon--;
   datetime lastMonthStartJst = StructToTime(dlm);            // 先月 1日0:00

   MqlDateTime dy = n; dy.mon=1; dy.day=1; dy.hour=0; dy.min=0; dy.sec=0;
   datetime yearStartJst = StructToTime(dy);                  // 今年 1/1 0:00

   //── 期間の選び方に応じて範囲を決める ──
   switch(InpPeriod)
   {
      case PRESET_CUSTOM:
      {
         fromJst = InpFromDate;
         toJst   = InpToDate;
         // 終了日が 0:00 (日付だけ選択)のときは、その日いっぱい(23:59:59)まで含める
         MqlDateTime tt; TimeToStruct(toJst, tt);
         if(tt.hour==0 && tt.min==0 && tt.sec==0)
            toJst = toJst + 86400 - 1;
         periodLabel = "カレンダー指定";
         break;
      }
      case PRESET_ALL:
         from = 0; to = TimeCurrent() + 86400; serverSet = true;
         periodLabel = "全履歴";
         break;
      case PRESET_TODAY:
         fromJst = todayStartJst;          toJst = nowJst;            periodLabel = "今日";   break;
      case PRESET_YESTERDAY:
         fromJst = todayStartJst - 86400;  toJst = todayStartJst - 1; periodLabel = "昨日";   break;
      case PRESET_THIS_WEEK:
         fromJst = weekStartJst;           toJst = nowJst;            periodLabel = "今週";   break;
      case PRESET_THIS_MONTH:
         fromJst = monthStartJst;          toJst = nowJst;            periodLabel = "今月";   break;
      case PRESET_LAST_MONTH:
         fromJst = lastMonthStartJst;      toJst = monthStartJst - 1; periodLabel = "先月";   break;
      case PRESET_THIS_YEAR:
         fromJst = yearStartJst;           toJst = nowJst;            periodLabel = "今年";   break;
      case PRESET_VISIBLE:
      {
         int leftIdx  = (int)ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
         int visBars  = (int)ChartGetInteger(0, CHART_VISIBLE_BARS);
         int rightIdx = leftIdx - visBars + 1;
         if(rightIdx < 0) rightIdx = 0;
         datetime lt = iTime(_Symbol, _Period, leftIdx);
         datetime rt = iTime(_Symbol, _Period, rightIdx);
         if(lt > 0 && rt > 0)
         {
            from = lt; to = rt + PeriodSeconds(_Period); serverSet = true;
         }
         else { Print("[CSV] 画面期間の取得に失敗しました。"); return(0); }
         periodLabel = "画面表示期間";
         break;
      }
   }

   //── JST境界 → サーバー時間へ変換 ──
   if(!serverSet)
   {
      if(fromJst <= 0 || toJst <= 0)
      { Print("期間の指定が不正です。開始日/終了日を確認してください。"); return(0); }
      if(fromJst > toJst)
      { Print("開始日が終了日より後になっています。順序を確認してください。"); return(0); }
      from = JstToServer(fromJst);
      to   = JstToServer(toJst);
   }

   // 履歴を読み込む
   if(!HistorySelect(from, to))
   { Print("履歴の取得に失敗しました。"); return(0); }

   // 出力ファイル名(自動命名: DokaKotsu_CSV_Tradehistory_<期間>_YYYYMMDD.CSV)
   string fname = InpFileName;
   if(fname == "")
   {
      MqlDateTime d; TimeToStruct(nowJst, d);
      fname = StringFormat("DokaKotsu_CSV_Tradehistory_%04d%02d%02d%02d%02d.CSV",
                           d.year, d.mon, d.day, d.hour, d.min);
   }

   // まずMT5サンドボックス(MQL5\Files\)に書き出す
   int fh = FileOpen(fname, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(fh == INVALID_HANDLE)
   { Print("ファイルを開けません: ", fname, "  err=", GetLastError()); return(0); }

   string header = "連番,注文番号,エントリー日時(JST),曜日,取引種別,勝敗,"
                   "ロット数,通貨ペア,エントリー価格,決済逆指値,決済指値,"
                   "決済日時(JST),決済価格,獲得Pips,損益,手数料,スワップ";
   FileWriteString(fh, header + "\r\n");

   int total_deals = HistoryDealsTotal();
   int serial = 0;
   int written = 0;

   // ポジションID毎に IN(entry) と OUT(exit) を突き合わせる
   for(int i = 0; i < total_deals; i++)
   {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;

      long entry_type = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry_type != DEAL_ENTRY_OUT) continue;   // 決済dealだけを起点にする

      long   pos_id   = HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      string symbol   = HistoryDealGetString (deal, DEAL_SYMBOL);
      if(InpSymbol != "" && symbol != InpSymbol) continue;

      // 決済側の情報
      datetime close_t = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      double close_px  = HistoryDealGetDouble (deal, DEAL_PRICE);
      double profit    = HistoryDealGetDouble (deal, DEAL_PROFIT);
      double commission= HistoryDealGetDouble (deal, DEAL_COMMISSION);
      double swap      = HistoryDealGetDouble (deal, DEAL_SWAP);
      double lot       = HistoryDealGetDouble (deal, DEAL_VOLUME);
      long   order_no  = (long)HistoryDealGetInteger(deal, DEAL_ORDER);

      // エントリー側を同じポジションIDから探す
      datetime open_t = 0; double open_px = 0; string otype = "";
      double sl = 0, tp = 0;
      for(int j = 0; j < total_deals; j++)
      {
         ulong d2 = HistoryDealGetTicket(j);
         if(d2 == 0) continue;
         if(HistoryDealGetInteger(d2, DEAL_POSITION_ID) != pos_id) continue;
         if(HistoryDealGetInteger(d2, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
         open_t  = (datetime)HistoryDealGetInteger(d2, DEAL_TIME);
         open_px = HistoryDealGetDouble (d2, DEAL_PRICE);
         long it = HistoryDealGetInteger(d2, DEAL_TYPE);
         otype = (it == DEAL_TYPE_BUY) ? "buy" : "sell";
         break;
      }
      // SL/TP はポジションから取得(履歴に残っていれば)
      if(HistoryOrderSelect(order_no))
      {
         sl = HistoryOrderGetDouble(order_no, ORDER_SL);
         tp = HistoryOrderGetDouble(order_no, ORDER_TP);
      }

      // Pips計算
      double pips = 0;
      if(open_px > 0)
      {
         if(otype == "buy") pips = (close_px - open_px) / InpPipSize;
         else               pips = (open_px - close_px) / InpPipSize;
      }

      // 勝敗(純損益ベース)
      double net = profit + commission + swap;
      string winlose = (net > 0) ? "WIN" : "LOSE";

      serial++;
      datetime open_jst  = ToJST(open_t);
      datetime close_jst = ToJST(close_t);
      string line = StringFormat(
         "%d,%d,%s,%s,%s,%s,%.2f,%s,%.2f,%.2f,%.2f,%s,%.2f,%.1f,%.2f,%.2f,%.2f",
         serial, order_no, FmtDateTime(open_jst), WeekdayJP(open_jst),
         otype, winlose, lot, symbol, open_px, sl, tp,
         FmtDateTime(close_jst), close_px, pips, profit, commission, swap);
      FileWriteString(fh, line + "\r\n");
      written++;
   }

   FileClose(fh);

   // サンドボックスのフルパス
   string sandboxFull = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\" + fname;

   //── ② 保存先フォルダへコピー(空欄ならデスクトップ) ──
   string destFolder = InpSaveFolder;
   if(destFolder == "") destFolder = GetDesktopPath();
   // 末尾の \ を除去して整える
   if(StringLen(destFolder) > 0 && StringGetCharacter(destFolder, StringLen(destFolder)-1) == '\\')
      destFolder = StringSubstr(destFolder, 0, StringLen(destFolder)-1);

   string openTarget = sandboxFull;   // 既定はサンドボックスのファイルを開く
   if(destFolder != "")
   {
      string destFull = destFolder + "\\" + fname;
      // 第3引数0 = 既存上書き可
      if(CopyFileW(sandboxFull, destFull, 0) != 0)
      {
         openTarget = destFull;
         PrintFormat("保存先へコピーしました: %s", destFull);
      }
      else
      {
         PrintFormat("保存先へのコピーに失敗(フォルダ存在/権限を確認): %s  err=%d",
                     destFull, GetLastError());
         PrintFormat("→ サンドボックスの方を使用します: %s", sandboxFull);
      }
   }
   else
   {
      Print("デスクトップのパス取得に失敗。サンドボックスへ保存しました。");
   }

   // 完了ログ
   if(InpPeriod == PRESET_ALL)
      PrintFormat("出力完了: %s に %d 件(全履歴)", fname, written);
   else
      PrintFormat("出力完了: %s に %d 件(%s / JST %s 〜 %s)",
                  fname, written, periodLabel,
                  FmtDateTime(ToJST(from)), FmtDateTime(ToJST(to)));

   // 保存したファイルをメモ帳で開く
   int r = ShellExecuteW(0, "open", "notepad.exe", "\"" + openTarget + "\"", "", 1);
   if(r <= 32)
      PrintFormat("メモ帳の起動に失敗(コード%d)。DLL使用許可を確認してください。保存先: %s", r, openTarget);
   else
      PrintFormat("メモ帳で開きました: %s", openTarget);
   return(0);
}
//+------------------------------------------------------------------+
