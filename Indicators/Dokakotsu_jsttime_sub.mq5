//+------------------------------------------------------------------+
//|                            Dokakotsu_jsttime_sub.mq5            |
//|   JST(日本時間)の毎正時ラベルを、サブウィンドウに一直線で       |
//|   並べて表示する。価格軸に縛られないので、スクロール/ズームで    |
//|   位置が安定し、画面から消えない。                               |
//|   背景色・文字色・文字サイズを入力パラメータで選択できる。        |
//|                                                                  |
//|  ■ 更新日: 2026-10-21                                            |
//|    変更履歴:                                                     |
//|      - 2026-10-21 v1.41 毎回の「再描画完了」ログを入力スイッチ   |
//|        (InpDiagLog、既定false)で切替式に変更。M1では毎分出力され |
//|        エキスパートタブが埋まるため。ObjectCreate失敗・          |
//|        ChartWindowFind()=-1 等の異常時ログは従来どおり常に出力。 |
//|      - 2026-09-17 v1.40                                          |
//|      - メインチャート左上に「カーソル位置のJST時刻」を常時表示    |
//|        する機能を追加(InpShowCursorJST、既定true)。田島さんより  |
//|        「データウィンドウのTime(サーバー時刻)を見せるたびに      |
//|        JSTと言われるので、最初からJSTを表示したい」とのご要望。  |
//|        データウィンドウのTimeはMT5仕様上サーバー時刻固定で       |
//|        変更不可のため、カーソル(十字線)が指している位置の時刻を  |
//|        ChartXYToTimePrice()で取得し、既存の夏冬時間判定          |
//|        (IsSummerTimeAt)でJSTへ変換してメインウィンドウ左上に     |
//|        固定表示するラベルを新設。スクリーンショットに毎回写る    |
//|        ので、以後「それはJSTですか」の確認不要になる想定。       |
//|  ■ 修正日: 2026-07-13  修正内容(診断用ビルド)                    |
//|    表示が消える不具合の原因を特定するため、Print診断ログを追加。 |
//|    ①OnInit時点のウィンドウ番号、②毎回の再描画で実際に何本の    |
//|    ラベルを作れた/失敗したか、③ChartWindowFind()が-1を返した   |
//|    場合の検知、をExperts/journalタブに出力するようにした。       |
//|    あわせて、背景描画とラベル作成で別々にChartWindowFind()を     |
//|    呼んでいたのを1箇所に統一(値のズレの可能性を除去)。          |
//|    見た目のロジック(何を描画するか)自体は変更していない。       |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.41"
#property indicator_separate_window
#property indicator_buffers 0
#property indicator_plots   0
#property indicator_minimum 0.0
#property indicator_maximum 1.0

//=== 入力 =========================================================
input int    InpAxisBars   = 1000;     // 目盛りを表示する本数(過去方向)
input color  InpAxisColor  = clrWhite;   // 文字色
input int    InpFontSize   = 8;          // 文字サイズ
input color  InpBgColor    = 0x1a1a1a;   // 背景色(clrNONEで背景を描画しない)
input double InpYPos        = 0.5;      // サブ窓内の縦位置(0=下 1=上)
input bool   InpAutoDST     = true;     // 夏/冬を自動判定(米国DST)
input bool   InpManualSummer= true;     // 手動時の夏時間(InpAutoDST=false時)
input bool   InpShowCursorJST = true;   // ★2026-09-17追加: メインチャート左上にカーソル位置のJST時刻を常時表示
input color  InpCursorJSTColor = clrYellow; // カーソルJST表示の文字色
input int    InpCursorJSTFontSize = 10;     // カーソルJST表示の文字サイズ
input bool   InpDiagLog = false;          // ★2026-10-21追加: 再描画完了ログを毎回出力(診断用)

string   PFX       = "DKjstax_";
string   CPFX      = "DKjstcursor_";     // ★カーソルJST表示ラベル専用プレフィックス(PFXの一括削除対象から外すため別出し)
string   CURSOR_NAME;
string   BG_NAME;  // 背景矩形オブジェクト名(PFXを含めて一括削除対象にする)
datetime g_lastBar = 0;    // 最後に描き直した足の時刻(毎ティック処理を防ぐ)
int      g_lastOff = -1;   // 最後に使ったJSTオフセット(夏冬の切替検知)

//+------------------------------------------------------------------+
//| ★2026-09-17追加: メインチャート左上に固定表示するカーソルJSTラベル |
//|   を作成/更新する。時間・価格軸ではなく画面座標(コーナー基準)で   |
//|   固定するので、スクロール/ズームしても常に同じ位置に見える。     |
//+------------------------------------------------------------------+
void CreateOrUpdateCursorLabel(string txt)
{
   if(ObjectFind(0, CURSOR_NAME) < 0)
   {
      if(!ObjectCreate(0, CURSOR_NAME, OBJ_LABEL, 0, 0, 0))
      {
         Print("[JSTsub] カーソルJSTラベルObjectCreate失敗 err=", GetLastError());
         return;
      }
      ObjectSetInteger(0, CURSOR_NAME, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, CURSOR_NAME, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, CURSOR_NAME, OBJPROP_YDISTANCE, 18);
      ObjectSetInteger(0, CURSOR_NAME, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, CURSOR_NAME, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, CURSOR_NAME, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, CURSOR_NAME, OBJPROP_BACK, false);
      ObjectSetInteger(0, CURSOR_NAME, OBJPROP_ZORDER, 100);
   }
   ObjectSetString (0, CURSOR_NAME, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, CURSOR_NAME, OBJPROP_COLOR, InpCursorJSTColor);
   ObjectSetInteger(0, CURSOR_NAME, OBJPROP_FONTSIZE, InpCursorJSTFontSize);
}

//+------------------------------------------------------------------+
int OnInit()
{
   BG_NAME = PFX + "background";
   CURSOR_NAME = CPFX + "label";
   IndicatorSetString(INDICATOR_SHORTNAME, "JST目盛り");
   IndicatorSetInteger(INDICATOR_DIGITS, 0);
   // ★診断用(2026-07-13追加): OnInit時点でのウィンドウ番号を記録。
   //   これが-1や意図しない番号(0=メインチャート等)になっていないか確認するため。
   Print("[JSTsub] OnInit win=", ChartWindowFind(), " chart_windows=", (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL));

   // ★2026-09-17追加: カーソル位置のJST時刻表示のため、マウス移動イベントを有効化。
   if(InpShowCursorJST)
   {
      ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
      CreateOrUpdateCursorLabel("JST(カーソル位置): ―");   // 初期表示(マウスが動くまでのプレースホルダ)
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, PFX);
   ObjectsDeleteAll(0, CPFX);   // ★2026-09-17追加: カーソルJST表示ラベルも削除
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| 夏時間(米国DST)判定:指定した日時がDST期間内かどうかを判定する    |
//+------------------------------------------------------------------+
bool IsSummerTimeAt(datetime t)
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
//+------------------------------------------------------------------+
//| サブウィンドウ全体を覆う背景矩形を描画/更新する                    |
//+------------------------------------------------------------------+
void DrawBackground(int win)
{
   if(InpBgColor == clrNONE)
     {
      ObjectDelete(0, BG_NAME);
      return;
     }

   long chartWidth = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   long winHeight  = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, win);

   if(ObjectFind(0, BG_NAME) < 0)
   {
      if(!ObjectCreate(0, BG_NAME, OBJ_RECTANGLE_LABEL, win, 0, 0))
         Print("[JSTsub] 背景ObjectCreate失敗 win=", win, " err=", GetLastError());
   }

   ObjectSetInteger(0, BG_NAME, OBJPROP_XDISTANCE,  0);
   ObjectSetInteger(0, BG_NAME, OBJPROP_YDISTANCE,  0);
   ObjectSetInteger(0, BG_NAME, OBJPROP_XSIZE,      (int)chartWidth);
   ObjectSetInteger(0, BG_NAME, OBJPROP_YSIZE,      (int)winHeight);
   ObjectSetInteger(0, BG_NAME, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
   ObjectSetInteger(0, BG_NAME, OBJPROP_BGCOLOR,    InpBgColor);
   ObjectSetInteger(0, BG_NAME, OBJPROP_COLOR,      InpBgColor);
   ObjectSetInteger(0, BG_NAME, OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0, BG_NAME, OBJPROP_STYLE,      STYLE_SOLID);
   ObjectSetInteger(0, BG_NAME, OBJPROP_WIDTH,      1);
   ObjectSetInteger(0, BG_NAME, OBJPROP_BACK,       true);  // 背面に固定(文字より奥に描画)
   ObjectSetInteger(0, BG_NAME, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, BG_NAME, OBJPROP_HIDDEN,     true);
   ObjectSetInteger(0, BG_NAME, OBJPROP_ZORDER,     0);
}

//+------------------------------------------------------------------+
//| チャートサイズ変更時に背景の大きさを追従させる                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                   const long &lparam,
                   const double &dparam,
                   const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      int win = ChartWindowFind();
      if(win >= 0) DrawBackground(win);
   }

   // ★2026-09-17追加: マウス移動のたびに、カーソル(十字線)が指している位置の
   //   時刻をメインウィンドウ(0)基準で取得し、JSTに変換して左上ラベルへ反映。
   //   データウィンドウのTimeと同じX座標を参照しているので、常に一致する。
   if(InpShowCursorJST && id == CHARTEVENT_MOUSE_MOVE)
   {
      int x = (int)lparam;
      int y = (int)dparam;
      datetime tAtCursor;
      double   pAtCursor;
      int      subWin;
      if(ChartXYToTimePrice(0, x, y, subWin, tAtCursor, pAtCursor))
      {
         int offCur = IsSummerTimeAt(tAtCursor) ? 6 : 7;
         datetime jstCur = tAtCursor + offCur*3600;
         MqlDateTime jc; TimeToStruct(jstCur, jc);
         string txt = StringFormat("JST(カーソル位置): %04d.%02d.%02d %02d:%02d",
                                    jc.year, jc.mon, jc.day, jc.hour, jc.min);
         CreateOrUpdateCursorLabel(txt);
         ChartRedraw(0);
      }
   }
}

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
   if(rates_total < 5) return(0);

   // ★2026-07-13修正: ChartWindowFind()をここで1回だけ取得し、以降はこの値を使い回す
   //   (従来は背景描画とラベル作成でそれぞれ別々に呼んでおり、タイミングによって
   //   違う値を拾う/無効値(-1)を拾う可能性があった)。
   int win = ChartWindowFind();
   if(win < 0)
   {
      // ★診断用: ウィンドウが見つからない場合はここで必ずログに残す。
      //   これが出続けているなら「サブウィンドウとして認識されていない」ことが確定する。
      Print("[JSTsub] ChartWindowFind()が-1を返しました。再試行します(rates_total=", rates_total, ")");
      return(prev_calculated); // g_lastBar/g_lastOffを更新せず、次のティックで必ず再挑戦する
   }

   int off = IsSummerTimeAt(TimeCurrent()) ? 6 : 7;      // JST = server + off(現在時刻ベース、再描画トリガー用)
   datetime curBar = time[rates_total-1];

   // 背景色はキャッシュ判定と切り離し、毎回(パラメータ変更直後も含め)必ず
   // 最新の色・サイズに更新する。ObjectSetIntegerは軽い処理なので負荷は問題ない。
   DrawBackground(win);

   // ★負荷対策:毎ティックではなく「新しい足が出来た時」だけ引き直す。
   //   (夏/冬でオフセットが変わった時・初回/全再計算も引き直す)
   //   これでティック中はゼロ負荷になり、点滅・ファン唸り・固着が止まる。
   if(prev_calculated > 0 && curBar == g_lastBar && off == g_lastOff)
      return(rates_total);
   g_lastBar = curBar;
   g_lastOff = off;

   // 引き直す時だけ、自分のラベルを全消去してから作る(重複防止)
   ObjectsDeleteAll(0, PFX);
   DrawBackground(win);   // 上のObjectsDeleteAllで消えた背景をここで再度描き直す

   int begin = MathMax(0, rates_total - InpAxisBars);
   int lbl   = 0;
   int created = 0, failed = 0;   // ★診断用: 実際に何本作れたか/失敗したかを数える
   string wd[7] = {"日","月","火","水","木","金","土"};

   // 直前に表示した「年月日」を保持。これが変わった瞬間(=週末の飛びを含む
   // 日付またぎ)は、毎正時でなくてもフル日付を強制的に出す。
   datetime lastDate = 0;

   // 季節(夏時間/冬時間)の切り替わり検知用。1本前のバーの状態を基準にする。
   bool isSummerPrev = IsSummerTimeAt(time[MathMax(begin - 1, 0)]);

   for(int i = begin; i < rates_total; i++)
   {
      bool isSummerNow = IsSummerTimeAt(time[i]);
      int  offBar = isSummerNow ? 6 : 7;      // JST = server + offBar(このバー自身の日付で判定)
      bool seasonChanged = (i > begin) && (isSummerNow != isSummerPrev);
      isSummerPrev = isSummerNow;

      datetime jst = time[i] + offBar*3600;
      MqlDateTime jt; TimeToStruct(jst, jt);

      datetime curDate = StringToTime(StringFormat("%04d.%02d.%02d 00:00",
                                       jt.year, jt.mon, jt.day));
      bool isNewDay = (curDate != lastDate);

      if(!isNewDay && !seasonChanged && jt.min != 0) continue;   // 通常は毎正時(分=0)だけ

      if(isNewDay) lastDate = curDate;

      string seasonPrefix = seasonChanged ? (isSummerNow ? "夏時間 " : "冬時間 ") : "";

      string nm = PFX + IntegerToString(lbl++);
      string txt;
      if(isNewDay)
         // 日付が変わった最初の足(週末明けはここで月曜の日付が必ず出る)
         txt = seasonPrefix + StringFormat("%d年%d月%d日(%s) %d:%02d",
                             jt.year, jt.mon, jt.day, wd[jt.day_of_week],
                             jt.hour, jt.min);
      else
         txt = seasonPrefix + StringFormat("%d時", jt.hour);

      // サブ窓(自分のウィンドウ)に OBJ_TEXT を1個だけ作る。
      //   座標 = (その足の時刻, 縦InpYPos)。作成時に正しく指定する。
      //   ★2026-07-13修正: OnCalculate冒頭で確定させたwinを使い回す(従来はここで毎回
      //   ChartWindowFind()を呼び直しており、値がズレる余地があった)。失敗したら診断ログを出す。
      if(!ObjectCreate(0, nm, OBJ_TEXT, win, time[i], InpYPos))
      {
         failed++;
         if(failed <= 5) Print("[JSTsub] ラベルObjectCreate失敗 name=", nm, " win=", win, " err=", GetLastError());
         continue;
      }
      created++;
      ObjectSetString (0, nm, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, InpAxisColor);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, InpFontSize);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
   }

   // ★診断用: この再描画で何本のラベルを作れた/失敗したかを必ず1行残す。
   //   created=0が続くようならbegin~rates_totalの範囲やInpAxisBarsの設定を疑う。
   if(InpDiagLog)
   Print("[JSTsub] 再描画完了 win=", win, " created=", created, " failed=", failed,
         " begin=", begin, " rates_total=", rates_total);

   ChartRedraw(0);
   return(rates_total);
}
//+------------------------------------------------------------------+
