//+------------------------------------------------------------------+
//|                          DokaKotsu_MemoPad.mq5                   |
//|   バージョン : Ver3.2    修正 : 2026-07-24 (JST)                |
//|------------------------------------------------------------------|
//|   ■ 変更履歴                                                    |
//|   ・[Ver3.2] 2026-07-24 4点の大改修(田島さんご依頼①②③④):     |
//|     ①保存形式をCSVへ変更                                        |
//|       MQL5\Files\DokaKotsu_MemoPad\memopad_<銘柄>.csv            |
//|       (列: BOX,id,時刻epoch,時刻可読,price,テキスト。UTF-8。    |
//|        テキストは最終列でカンマを含んでも壊れない読取り方式)     |
//|       初回起動時にCSVが無く旧TXT(DK_MsgBox21_*.txt)があれば      |
//|       自動移行する(旧TXTは安全のため残す)。チャートから削除→    |
//|       再挿入でも過去メモをCSVから完全復元。                      |
//|     ②InpLoadCount(直近何個を表示対象にするか。初期30、0=全部)   |
//|       を追加。アンカー時刻の新しい順に数える。                   |
//|       ※CSVの全行は常にメモリ保持・保存されるため、表示対象外の  |
//|         古いメモも消えない(保存時の取りこぼし防止)。             |
//|     ③InpShowCount(起動直後に生成する個数。初期10)を追加。       |
//|       残りの表示対象は「過去へスクロールしてその日時が画面に     |
//|       入った瞬間」に初めてオブジェクト生成する遅延表示方式。     |
//|       1箱=4オブジェクトの生成コストを起動時に払わないため軽い。  |
//|     ④描画負荷の大幅削減(カクつき・ドラッグが重い問題の根治):    |
//|       旧版は150msタイマーで変化がなくても毎回                    |
//|       「全箱ObjectSet+ChartRedraw(チャート全体再描画)」を        |
//|       無条件実行しており、静止中も毎秒6〜7回の全再描画が走り、   |
//|       箱ドラッグ中はMT5本体のドラッグ描画と衝突して固まっていた。|
//|       → (a)ダーティチェック: 先頭表示バー/価格スケール/          |
//|            チャートサイズが前回と同じなら何もしない(負荷ゼロ)    |
//|         (b)差分同期: 画面が動いた時も、前回ピクセル座標と        |
//|            変わった箱だけObjectSetし、1つも変わらなければ        |
//|            ChartRedrawもしない                                   |
//|         (c)ドラッグ中は完全沈黙: グリップ選択中は同期も          |
//|            ChartRedrawも一切行わず、MT5ネイティブのドラッグ      |
//|            描画を邪魔しない(=マウスに素直に追従)                |
//|   ・[Ver3.1] 新規追加ボックスの初期位置をチャート表示範囲の      |
//|     縦横中央基準に変更                                           |
//|   ・[Ver3.0] InpStartY初期値400。InpRowGap入力を削除し内部固定化 |
//|   ・[Ver2.9] [＋]ボタンの角ごとの補正値を再調整                  |
//|   ・[Ver2.5〜2.8] ドラッグ座標の奪取修正・[＋]位置/オフセット等  |
//|   ・[Ver2.4] 初期3箱の自動生成廃止・ミリ秒タイマー常時再同期     |
//|   ・旧名 DokaKotsu_MessageBox.mq5 から改称                       |
//|------------------------------------------------------------------|
//|  役割: チャート上メモ表示専用ツール。トレードロジックは持たない。|
//|  (DokaKotsu絶対ルール: ロジックはインジ本体のみ。本ファイルは    |
//|   表示補助でありエントリー判定に一切関与しない)                  |
//|------------------------------------------------------------------|
//|  ■ 機能一覧                                                     |
//|   ① チャートの[＋]ボタンで箱を追加(数量無制限)                 |
//|   ② 箱右端の[×]ボタンで個別削除                                |
//|   ③ 箱をクリックしてその場で文字を直接編集                      |
//|   ④ 箱をドラッグして移動 → チャート座標(時間/価格)で保存      |
//|   ⑤ 過去スクロールしても箱はその日時・価格に追従する            |
//|   ⑥ 再起動・時間足変更・削除→再挿入後もCSVから完全復元         |
//|   ⑦ 直近InpShowCount個だけ即表示、残りはスクロールで遅延表示    |
//|                                                                  |
//|  使い方:                                                         |
//|   ・追加 : チャートの[＋]ボタンを押す                           |
//|   ・編集 : 箱をクリック → そのまま文字入力 → Enterで確定       |
//|   ・移動 : 箱左端のグリップ(⠿)をクリックして選択→ドラッグ      |
//|   ・削除 : 箱右端の[×]を押す                                   |
//|                                                                  |
//|  ※ MQL5\Indicators\ に置いてコンパイル。UTF-8 BOMで保存。      |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "3.20"
#property strict
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//=== 入力 ============================================================
input int    InpFontSize    = 12;           // フォントサイズ
input color  InpBoxColor    = clrDeepPink;  // 枠線・ボタン色
input color  InpBgColor     = clrWhite;     // 箱の背景色
input color  InpTextColor   = clrBlack;     // 文字色
input string InpFont        = "Meiryo";     // フォント
input int    InpBoxW        = 220;          // 箱の幅(px) ※日本語10文字分
input int    InpBoxH        = 34;           // 箱の高さ(px)
input int    InpStartX      = 120;          // [＋]追加時の初期配置 X(px)
input int    InpStartY      = 400;          // 初期配置 Y(px)
input ENUM_BASE_CORNER InpAddBtnCorner = CORNER_LEFT_LOWER; // [＋]ボタンの表示位置(4隅)
input int    InpAddBtnOffsetX = 0;          // [＋]ボタン X方向オフセット(px) ※微調整用、角補正とは別に加算
input int    InpAddBtnOffsetY = 0;          // [＋]ボタン Y方向オフセット(px) ※微調整用、角補正とは別に加算
input int    InpLoadCount   = 30;           // ★Ver3.2② 表示対象にする直近メモ数(0=全部)
input int    InpShowCount   = 10;           // ★Ver3.2③ 起動直後に生成する個数(残りは遅延表示)

//=== 定数 ============================================================
#define PFX_ANCHOR  "DKMB21_A_"   // OBJ_TEXT (チャート座標アンカー・非表示)
#define PFX_GRIP    "DKMB21_G_"   // OBJ_LABEL (ドラッグハンドル・掴みやすい)
#define PFX_ED      "DKMB21_E_"   // OBJ_EDIT (テキスト編集・ピクセル追従)
#define PFX_CL      "DKMB21_C_"   // OBJ_BUTTON (×削除ボタン)
#define BTN_ADD     "DKMB21_ADD"  // OBJ_BUTTON (＋追加ボタン)
#define CLOSE_W     24             // ×ボタン幅
#define CLOSE_H     24             // ×ボタン高
#define GRIP_W      20             // グリップ幅
#define ROW_GAP     50             // 新規追加時の縦の間隔(px)
#define OFFSCR_X    -10000         // 画面外退避用X(アンカーが可視範囲外のとき箱をここへ=非表示)
#define PX_NONE     -99999         // ★Ver3.2④ 「前回座標なし」を表すキャッシュ初期値

//=== メモデータ(★Ver3.2: オブジェクトではなくメモリ配列が正) =======
//  CSVの全行を常にここへ保持する。表示対象(eligible)や生成済み(created)は
//  あくまで描画上のフラグであり、SaveAll()は全行を書き出すため、
//  InpLoadCountで絞っても古いメモがCSVから消えることはない。
struct MemoRec
{
   int      id;        // 一意ID(欠番あり得る)
   datetime t;         // アンカー時刻
   double   price;     // アンカー価格
   string   txt;       // メモ本文
   bool     eligible;  // ②表示対象か(直近InpLoadCount個。0=全部ならtrue)
   bool     created;   // ③チャートオブジェクトを生成済みか
   int      lastPx;    // ④前回同期時のX(差分同期用キャッシュ)
   int      lastPy;    // ④前回同期時のY
};
MemoRec g_recs[];
int     g_maxId = 0;

//=== ④ダーティチェック用の前回チャート状態 ==========================
long    g_prevFirstBar = -1;
double  g_prevPMin = 0.0, g_prevPMax = 0.0;
long    g_prevW = 0, g_prevH = 0, g_prevScale = -1;

//+------------------------------------------------------------------+
//| ファイル名                                                       |
//+------------------------------------------------------------------+
string CsvFileName()
{
   // ★Ver3.2①: 新CSV保存先(サブフォルダはFileOpen書込時に自動作成される)
   return "DokaKotsu_MemoPad\\memopad_" + _Symbol + ".csv";
}
string OldTxtFileName()
{
   // 旧形式(Ver3.1まで)。CSVへの自動移行元としてのみ使用。移行後も削除しない。
   return "DK_MsgBox21_" + _Symbol + ".txt";
}

//+------------------------------------------------------------------+
string DefaultText(int idx)
{
   return "自由に変更ください";
}

//+------------------------------------------------------------------+
//| id → g_recs添字(見つからなければ-1)                              |
//+------------------------------------------------------------------+
int FindRec(int id)
{
   for(int i = 0; i < ArraySize(g_recs); i++)
      if(g_recs[i].id == id) return i;
   return -1;
}

//+------------------------------------------------------------------+
//| チャート座標 ⇔ ピクセル座標変換                                  |
//+------------------------------------------------------------------+
bool AnchorToPixel(datetime t, double price, int &px, int &py)
{
   int sub = 0;
   return ChartTimePriceToXY(0, sub, t, price, px, py);
}
bool PixelToAnchor(int px, int py, datetime &t, double &price)
{
   int sub = 0;
   return ChartXYToTimePrice(0, px, py, sub, t, price);
}

//+------------------------------------------------------------------+
//| [＋]ボタンを指定コーナー(4隅から選択)に配置                      |
//+------------------------------------------------------------------+
void DrawAddButton()
{
   string nm = BTN_ADD;
   if(ObjectFind(0, nm) < 0)
      ObjectCreate(0, nm, OBJ_BUTTON, 0, 0, 0);

   // 角ごとの補正値(角ちょうどだと隠れる/被るため、内側へ寄せる基準オフセット)
   bool isLower = (InpAddBtnCorner == CORNER_LEFT_LOWER || InpAddBtnCorner == CORNER_RIGHT_LOWER);
   bool isRight = (InpAddBtnCorner == CORNER_RIGHT_LOWER || InpAddBtnCorner == CORNER_RIGHT_UPPER);
   int baseY = isLower ? 50 : 20;
   int baseX = isRight ? 60 : 20;
   int marginX = InpAddBtnOffsetX + baseX;
   int marginY = InpAddBtnOffsetY + baseY;

   ObjectSetInteger(0, nm, OBJPROP_CORNER,      InpAddBtnCorner);
   ObjectSetInteger(0, nm, OBJPROP_XDISTANCE,   marginX);
   ObjectSetInteger(0, nm, OBJPROP_YDISTANCE,   marginY);
   ObjectSetInteger(0, nm, OBJPROP_XSIZE,       44);
   ObjectSetInteger(0, nm, OBJPROP_YSIZE,       28);
   ObjectSetString (0, nm, OBJPROP_TEXT,        "＋");
   ObjectSetString (0, nm, OBJPROP_FONT,        InpFont);
   ObjectSetInteger(0, nm, OBJPROP_FONTSIZE,    14);
   ObjectSetInteger(0, nm, OBJPROP_COLOR,       clrWhite);
   ObjectSetInteger(0, nm, OBJPROP_BGCOLOR,     InpBoxColor);
   ObjectSetInteger(0, nm, OBJPROP_BORDER_COLOR,InpBoxColor);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN,      true);
   ObjectSetInteger(0, nm, OBJPROP_ZORDER,      100);
}

//+------------------------------------------------------------------+
//| 1箱セット描画(オブジェクト生成)                                  |
//|   ★Ver3.2③: 起動時は直近InpShowCount個だけ呼ばれる。残りは     |
//|   スクロールでアンカーが画面に入った時にLazyCreate経由で呼ぶ。   |
//+------------------------------------------------------------------+
void DrawBox(int id, datetime t, double price, string txt)
{
   string nmA = PFX_ANCHOR + (string)id;
   string nmG = PFX_GRIP   + (string)id;
   string nmE = PFX_ED     + (string)id;
   string nmC = PFX_CL     + (string)id;

   //--- アンカー (OBJ_TEXT・透明・選択不可・チャート座標追従) ---
   if(ObjectFind(0, nmA) < 0)
      ObjectCreate(0, nmA, OBJ_TEXT, 0, t, price);
   ObjectSetInteger(0, nmA, OBJPROP_TIME,        t);
   ObjectSetDouble (0, nmA, OBJPROP_PRICE,       price);
   ObjectSetString (0, nmA, OBJPROP_TEXT,        " ");
   ObjectSetInteger(0, nmA, OBJPROP_COLOR,       clrNONE);
   ObjectSetInteger(0, nmA, OBJPROP_FONTSIZE,    1);
   ObjectSetInteger(0, nmA, OBJPROP_SELECTABLE,  false);
   ObjectSetInteger(0, nmA, OBJPROP_HIDDEN,      true);
   ObjectSetInteger(0, nmA, OBJPROP_ZORDER,      1);

   //--- ピクセル座標を求める ---
   int px = InpStartX, py = InpStartY;
   AnchorToPixel(t, price, px, py);

   //--- グリップハンドル (OBJ_LABEL・左端に配置・ドラッグで移動) ---
   if(ObjectFind(0, nmG) < 0)
      ObjectCreate(0, nmG, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nmG, OBJPROP_XDISTANCE,   px - GRIP_W);
   ObjectSetInteger(0, nmG, OBJPROP_YDISTANCE,   py);
   ObjectSetString (0, nmG, OBJPROP_TEXT,        "⠿");
   ObjectSetString (0, nmG, OBJPROP_FONT,        "Segoe UI Symbol");
   ObjectSetInteger(0, nmG, OBJPROP_FONTSIZE,    InpBoxH > 28 ? 16 : 13);
   ObjectSetInteger(0, nmG, OBJPROP_COLOR,       clrWhite);
   ObjectSetInteger(0, nmG, OBJPROP_BGCOLOR,     InpBoxColor);
   ObjectSetInteger(0, nmG, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, nmG, OBJPROP_SELECTABLE,  true);   // ドラッグ可
   ObjectSetInteger(0, nmG, OBJPROP_SELECTED,    false);
   ObjectSetInteger(0, nmG, OBJPROP_HIDDEN,      false);
   ObjectSetInteger(0, nmG, OBJPROP_ZORDER,      15);

   //--- OBJ_EDIT (テキスト編集) ---
   if(ObjectFind(0, nmE) < 0)
      ObjectCreate(0, nmE, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, nmE, OBJPROP_XDISTANCE,    px);
   ObjectSetInteger(0, nmE, OBJPROP_YDISTANCE,    py);
   ObjectSetInteger(0, nmE, OBJPROP_XSIZE,        InpBoxW);
   ObjectSetInteger(0, nmE, OBJPROP_YSIZE,        InpBoxH);
   ObjectSetString (0, nmE, OBJPROP_TEXT,         txt);
   ObjectSetString (0, nmE, OBJPROP_FONT,         InpFont);
   ObjectSetInteger(0, nmE, OBJPROP_FONTSIZE,     InpFontSize);
   ObjectSetInteger(0, nmE, OBJPROP_COLOR,        InpTextColor);
   ObjectSetInteger(0, nmE, OBJPROP_BGCOLOR,      InpBgColor);
   ObjectSetInteger(0, nmE, OBJPROP_BORDER_COLOR, InpBoxColor);
   ObjectSetInteger(0, nmE, OBJPROP_ALIGN,        ALIGN_LEFT);
   ObjectSetInteger(0, nmE, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   ObjectSetInteger(0, nmE, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, nmE, OBJPROP_HIDDEN,       false);
   ObjectSetInteger(0, nmE, OBJPROP_ZORDER,       10);

   //--- ×削除ボタン ---
   if(ObjectFind(0, nmC) < 0)
      ObjectCreate(0, nmC, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, nmC, OBJPROP_XDISTANCE,    px + InpBoxW);
   ObjectSetInteger(0, nmC, OBJPROP_YDISTANCE,    py);
   ObjectSetInteger(0, nmC, OBJPROP_XSIZE,        CLOSE_W);
   ObjectSetInteger(0, nmC, OBJPROP_YSIZE,        CLOSE_H);
   ObjectSetString (0, nmC, OBJPROP_TEXT,         "×");
   ObjectSetString (0, nmC, OBJPROP_FONT,         "Arial");
   ObjectSetInteger(0, nmC, OBJPROP_FONTSIZE,     10);
   ObjectSetInteger(0, nmC, OBJPROP_COLOR,        clrWhite);
   ObjectSetInteger(0, nmC, OBJPROP_BGCOLOR,      InpBoxColor);
   ObjectSetInteger(0, nmC, OBJPROP_BORDER_COLOR, InpBoxColor);
   ObjectSetInteger(0, nmC, OBJPROP_CORNER,       CORNER_LEFT_UPPER);
   ObjectSetInteger(0, nmC, OBJPROP_SELECTABLE,   false);
   ObjectSetInteger(0, nmC, OBJPROP_HIDDEN,       true);
   ObjectSetInteger(0, nmC, OBJPROP_ZORDER,       20);

   //--- ★Ver3.2④ 差分同期キャッシュを更新 ---
   int r = FindRec(id);
   if(r >= 0){ g_recs[r].lastPx = px; g_recs[r].lastPy = py; }
}

//+------------------------------------------------------------------+
//| 箱セット(オブジェクト)削除 ※データはg_recs側で管理              |
//+------------------------------------------------------------------+
void DeleteBoxObjects(int id)
{
   ObjectDelete(0, PFX_ANCHOR + (string)id);
   ObjectDelete(0, PFX_GRIP   + (string)id);
   ObjectDelete(0, PFX_ED     + (string)id);
   ObjectDelete(0, PFX_CL     + (string)id);
}

//+------------------------------------------------------------------+
//| ★Ver3.2④ いずれかの箱がドラッグ中(グリップ選択中)か            |
//|   ドラッグ中はタイマー同期もChartRedrawも完全停止し、            |
//|   MT5ネイティブのドラッグ描画を一切邪魔しない(=サクサク動く)     |
//+------------------------------------------------------------------+
bool AnyGripSelected()
{
   for(int i = 0; i < ArraySize(g_recs); i++)
   {
      if(!g_recs[i].created) continue;
      string nmG = PFX_GRIP + (string)g_recs[i].id;
      if((bool)ObjectGetInteger(0, nmG, OBJPROP_SELECTED))
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| ★Ver3.2④ チャート表示状態が前回から変わったか(ダーティチェック)|
//|   変わっていなければ呼び側は何もしない=静止中の負荷ほぼゼロ      |
//+------------------------------------------------------------------+
bool ChartViewChanged()
{
   long   fb    = ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
   double pmin  = ChartGetDouble (0, CHART_PRICE_MIN);
   double pmax  = ChartGetDouble (0, CHART_PRICE_MAX);
   long   w     = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   long   h     = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   long   scale = ChartGetInteger(0, CHART_SCALE);

   bool changed = (fb != g_prevFirstBar || pmin != g_prevPMin || pmax != g_prevPMax
                   || w != g_prevW || h != g_prevH || scale != g_prevScale);
   if(changed)
   {
      g_prevFirstBar = fb; g_prevPMin = pmin; g_prevPMax = pmax;
      g_prevW = w; g_prevH = h; g_prevScale = scale;
   }
   return changed;
}

//+------------------------------------------------------------------+
//| ★Ver3.2③ 遅延生成: 未生成の表示対象のうち、アンカーが現在の    |
//|   可視範囲に入ったものだけこの場でオブジェクト生成する。         |
//|   戻り値=新たに生成した数                                        |
//+------------------------------------------------------------------+
int LazyCreateVisible()
{
   int made = 0;
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   for(int i = 0; i < ArraySize(g_recs); i++)
   {
      if(g_recs[i].created || !g_recs[i].eligible) continue;
      int px = 0, py = 0;
      // 変換成功=チャート描画範囲内。横方向に箱が少しでも掛かれば生成する
      if(AnchorToPixel(g_recs[i].t, g_recs[i].price, px, py)
         && (px + InpBoxW + CLOSE_W > 0) && (px - GRIP_W < chartW))
      {
         DrawBox(g_recs[i].id, g_recs[i].t, g_recs[i].price, g_recs[i].txt);
         g_recs[i].created = true;
         made++;
      }
   }
   return made;
}

//+------------------------------------------------------------------+
//| 生成済みの全箱をアンカーのピクセル位置に同期                     |
//|   ★Ver3.2④ 差分同期: 前回座標(lastPx/lastPy)と変わった箱だけ   |
//|   ObjectSetする。戻り値=座標を書き換えた箱の数(0なら再描画不要)  |
//+------------------------------------------------------------------+
int SyncAllPixels()
{
   int changed = 0;
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);

   for(int i = 0; i < ArraySize(g_recs); i++)
   {
      if(!g_recs[i].created) continue;
      int    id  = g_recs[i].id;
      string nmA = PFX_ANCHOR + (string)id;
      string nmG = PFX_GRIP   + (string)id;
      string nmE = PFX_ED     + (string)id;
      string nmC = PFX_CL     + (string)id;
      if(ObjectFind(0, nmA) < 0) continue;

      // ドラッグ中の箱は座標を触らない(上書きするとドラッグが効かなくなる)
      if((bool)ObjectGetInteger(0, nmG, OBJPROP_SELECTED))
         continue;

      datetime t     = (datetime)ObjectGetInteger(0, nmA, OBJPROP_TIME);
      double   price = ObjectGetDouble(0, nmA, OBJPROP_PRICE);

      int px = 0, py = 0;
      bool ok = AnchorToPixel(t, price, px, py);

      // 可視判定: 箱の矩形(グリップ〜×)が画面に少しでも掛かっていれば表示
      bool onScreen = ok
                      && (px + InpBoxW + CLOSE_W > 0)
                      && (px - GRIP_W       < chartW);
      if(!onScreen){ px = OFFSCR_X; py = g_recs[i].lastPy; }

      // ★差分チェック: 前回と同じ座標なら一切ObjectSetしない
      if(px == g_recs[i].lastPx && py == g_recs[i].lastPy) continue;
      g_recs[i].lastPx = px;
      g_recs[i].lastPy = py;
      changed++;

      if(px == OFFSCR_X)
      {
         // アンカーの日時/価格が画面外 → 箱ごと退避(=非表示)
         ObjectSetInteger(0, nmG, OBJPROP_XDISTANCE, OFFSCR_X);
         ObjectSetInteger(0, nmE, OBJPROP_XDISTANCE, OFFSCR_X);
         ObjectSetInteger(0, nmC, OBJPROP_XDISTANCE, OFFSCR_X);
         continue;
      }
      // 画面内 → アンカーのピクセル位置へ同期(スクロール/ズーム追従)
      ObjectSetInteger(0, nmG, OBJPROP_XDISTANCE, px - GRIP_W);
      ObjectSetInteger(0, nmG, OBJPROP_YDISTANCE, py);
      ObjectSetInteger(0, nmE, OBJPROP_XDISTANCE, px);
      ObjectSetInteger(0, nmE, OBJPROP_YDISTANCE, py);
      ObjectSetInteger(0, nmC, OBJPROP_XDISTANCE, px + InpBoxW);
      ObjectSetInteger(0, nmC, OBJPROP_YDISTANCE, py);
   }
   return changed;
}

//+------------------------------------------------------------------+
//| ★Ver3.2④ 同期の入口(タイマー/CHART_CHANGE共通)                 |
//|   1) ドラッグ中 → 完全に何もしない                              |
//|   2) 画面が動いていない → 何もしない                            |
//|   3) 動いた → 遅延生成+差分同期。実際に変化があった時だけ再描画 |
//+------------------------------------------------------------------+
void SyncIfNeeded(bool force)
{
   if(ArraySize(g_recs) == 0) return;
   if(AnyGripSelected()) return;                 // (1)ドラッグ中は沈黙
   bool moved = ChartViewChanged();
   if(!moved && !force) return;                  // (2)静止中は負荷ゼロ

   int made    = LazyCreateVisible();            // (3)③の遅延生成
   int changed = SyncAllPixels();                //    ④の差分同期
   if(made > 0 || changed > 0)
      ChartRedraw(0);                            // 変化があった時だけ再描画
}

//+------------------------------------------------------------------+
//| ★Ver3.2① CSV1行を書く: BOX,id,epoch,可読時刻,price,テキスト    |
//+------------------------------------------------------------------+
void WriteCsvLine(int h, int id, datetime t, double price, string txt)
{
   // テキストの改行・タブは半角スペースへ。カンマはそのままでよい
   // (読取り側が「5個目のカンマ以降を全部テキスト」として復元するため)
   StringReplace(txt, "\t", " ");
   StringReplace(txt, "\r", " ");
   StringReplace(txt, "\n", " ");
   FileWriteString(h, StringFormat("BOX,%d,%I64d,%s,%.8f,%s\r\n",
                   id, (long)t, TimeToString(t, TIME_DATE|TIME_MINUTES), price, txt));
}

//+------------------------------------------------------------------+
//| 全メモを保存(★Ver3.2①: g_recsの全行をCSVへ。表示対象外も含む)  |
//+------------------------------------------------------------------+
void SaveAll()
{
   // 保存前に、生成済み箱の最新テキストをオブジェクトから回収しておく
   // (Enter未確定のまま終了した場合の取りこぼし防止)
   for(int i = 0; i < ArraySize(g_recs); i++)
   {
      if(!g_recs[i].created) continue;
      string nmE = PFX_ED + (string)g_recs[i].id;
      if(ObjectFind(0, nmE) >= 0)
         g_recs[i].txt = ObjectGetString(0, nmE, OBJPROP_TEXT);
      string nmA = PFX_ANCHOR + (string)g_recs[i].id;
      if(ObjectFind(0, nmA) >= 0)
      {
         g_recs[i].t     = (datetime)ObjectGetInteger(0, nmA, OBJPROP_TIME);
         g_recs[i].price = ObjectGetDouble(0, nmA, OBJPROP_PRICE);
      }
   }

   int h = FileOpen(CsvFileName(), FILE_WRITE | FILE_TXT | FILE_ANSI, ',', CP_UTF8);
   if(h == INVALID_HANDLE)
   {
      Print("[MemoPad] CSV保存失敗: ", CsvFileName(), " err=", GetLastError());
      return;
   }
   FileWriteString(h, StringFormat("MAXID,%d\r\n", g_maxId));
   for(int i = 0; i < ArraySize(g_recs); i++)
      WriteCsvLine(h, g_recs[i].id, g_recs[i].t, g_recs[i].price, g_recs[i].txt);
   FileClose(h);
}

//+------------------------------------------------------------------+
//| g_recsへ1件追加(読込用)                                          |
//+------------------------------------------------------------------+
void PushRec(int id, datetime t, double price, string txt)
{
   int n = ArraySize(g_recs);
   ArrayResize(g_recs, n + 1);
   g_recs[n].id = id; g_recs[n].t = t; g_recs[n].price = price; g_recs[n].txt = txt;
   g_recs[n].eligible = false; g_recs[n].created = false;
   g_recs[n].lastPx = PX_NONE; g_recs[n].lastPy = PX_NONE;
   if(id >= g_maxId) g_maxId = id + 1;
}

//+------------------------------------------------------------------+
//| ★Ver3.2① CSV読込。戻り値=読み込んだ件数                        |
//|   行形式: BOX,id,epoch,可読時刻,price,テキスト                   |
//|   テキストは5個目のカンマ以降すべて(カンマを含んでも復元可能)    |
//+------------------------------------------------------------------+
int LoadCsv()
{
   if(!FileIsExist(CsvFileName())) return 0;
   int h = FileOpen(CsvFileName(), FILE_READ | FILE_TXT | FILE_ANSI, ',', CP_UTF8);
   if(h == INVALID_HANDLE) return 0;

   int count = 0;
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      if(StringLen(line) == 0) continue;
      string a[];
      int k = StringSplit(line, ',', a);
      if(k < 2) continue;

      if(a[0] == "MAXID")
      {
         g_maxId = MathMax(g_maxId, (int)StringToInteger(a[1]));
      }
      else if(a[0] == "BOX" && k >= 6)
      {
         int      id    = (int)StringToInteger(a[1]);
         datetime t     = (datetime)StringToInteger(a[2]);   // a[3]=可読時刻(人間用・読み飛ばし)
         double   price = StringToDouble(a[4]);
         string   txt   = a[5];
         for(int j = 6; j < k; j++) txt += "," + a[j];       // テキスト内カンマを復元
         if(t < D'2010.01.01' || price <= 0.0) continue;
         PushRec(id, t, price, txt);
         count++;
      }
   }
   FileClose(h);
   return count;
}

//+------------------------------------------------------------------+
//| ★Ver3.2① 旧TXT(タブ区切り)からの一回限りの自動移行             |
//|   CSVが無い場合のみ呼ばれる。旧TXTは安全のため削除しない。       |
//|   戻り値=移行した件数                                            |
//+------------------------------------------------------------------+
int MigrateOldTxt()
{
   if(!FileIsExist(OldTxtFileName())) return 0;
   int h = FileOpen(OldTxtFileName(), FILE_READ | FILE_TXT | FILE_ANSI, '\t', CP_UTF8);
   if(h == INVALID_HANDLE) return 0;

   int count = 0;
   while(!FileIsEnding(h))
   {
      string line = FileReadString(h);
      if(StringLen(line) == 0) continue;
      string a[];
      int k = StringSplit(line, '\t', a);
      if(k < 2) continue;
      if(a[0] == "MAXID")
      {
         g_maxId = MathMax(g_maxId, (int)StringToInteger(a[1]));
      }
      else if(a[0] == "BOX" && k >= 5)
      {
         int      id    = (int)StringToInteger(a[1]);
         datetime t     = (datetime)StringToInteger(a[2]);
         double   price = StringToDouble(a[3]);
         string   txt   = a[4];
         if(t < D'2010.01.01' || price <= 0.0) continue;
         PushRec(id, t, price, txt);
         count++;
      }
   }
   FileClose(h);
   if(count > 0)
   {
      SaveAll();   // 移行内容を即CSVへ書き出す(次回からはCSVが正)
      Print("[MemoPad] 旧TXT→CSVへ ", count, " 件を自動移行しました: ", CsvFileName());
   }
   return count;
}

//+------------------------------------------------------------------+
//| ★Ver3.2②③ 表示対象と初期生成対象を決める                      |
//|   ・時刻の新しい順に並べ、直近InpLoadCount個をeligible=true      |
//|     (InpLoadCount=0なら全部)                                     |
//|   ・そのうち直近InpShowCount個だけ即オブジェクト生成             |
//|     残りはスクロールで画面に入った時にLazyCreateVisibleが生成    |
//+------------------------------------------------------------------+
void MarkEligibleAndShowInitial()
{
   int n = ArraySize(g_recs);
   if(n == 0) return;

   // 時刻降順の添字リストを作る(単純挿入ソート。件数は高々数百想定)
   int order[];
   ArrayResize(order, n);
   for(int i = 0; i < n; i++) order[i] = i;
   for(int i = 1; i < n; i++)
   {
      int cur = order[i]; int j = i - 1;
      while(j >= 0 && g_recs[order[j]].t < g_recs[cur].t)
      { order[j + 1] = order[j]; j--; }
      order[j + 1] = cur;
   }

   int loadN = (InpLoadCount <= 0) ? n : MathMin(InpLoadCount, n);
   int showN = MathMin(MathMax(InpShowCount, 0), loadN);

   for(int r = 0; r < loadN; r++)
      g_recs[order[r]].eligible = true;

   for(int r = 0; r < showN; r++)
   {
      int i = order[r];
      DrawBox(g_recs[i].id, g_recs[i].t, g_recs[i].price, g_recs[i].txt);
      g_recs[i].created = true;
   }
}

//+------------------------------------------------------------------+
//| 箱を新規追加                                                     |
//+------------------------------------------------------------------+
void AddNewBox()
{
   int id = g_maxId;
   g_maxId++;

   // チャートの現在の表示範囲(縦横)から中央座標を算出し、そこを基準配置とする
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int centerX = chartW / 2 - InpBoxW / 2;
   int centerY = chartH / 2 - InpBoxH / 2;

   // 既存の生成済み箱の最下端ピクセルを探して、その下に配置(中央基準からスタック)
   int bestPY = centerY;
   for(int i = 0; i < ArraySize(g_recs); i++)
   {
      if(!g_recs[i].created) continue;
      int px2 = 0, py2 = 0;
      if(AnchorToPixel(g_recs[i].t, g_recs[i].price, px2, py2))
      {
         if(py2 + ROW_GAP > bestPY)
            bestPY = py2 + ROW_GAP;
      }
   }
   if(bestPY + InpBoxH > chartH - 50) bestPY = centerY;

   datetime newT; double newPrice;
   if(!PixelToAnchor(centerX, bestPY, newT, newPrice))
   {
      // 変換失敗時フォールバック
      newT     = iTime(_Symbol, PERIOD_CURRENT, 3);
      if(newT <= 0) newT = TimeCurrent();
      newPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }

   PushRec(id, newT, newPrice, DefaultText(id));
   int r = FindRec(id);
   g_recs[r].eligible = true;
   g_recs[r].created  = true;
   DrawBox(id, newT, newPrice, DefaultText(id));
   SaveAll();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
int OnInit()
{
   g_maxId = 0;
   ArrayResize(g_recs, 0);

   // ★Ver3.2①: CSVから復元。無ければ旧TXTから一回限りの自動移行
   if(LoadCsv() == 0)
      MigrateOldTxt();

   // ★Ver3.2②③: 直近InpLoadCount個を表示対象・直近InpShowCount個を即生成
   MarkEligibleAndShowInitial();

   DrawAddButton();
   SyncIfNeeded(true);   // 初回は強制同期(画面外の箱は退避)
   ChartRedraw(0);

   // タイマーは保険(チャートのドラッグスクロール中はCHART_CHANGEが
   // 間引かれるため)。★Ver3.2④: 中身はダーティチェック付きなので
   // 静止中はほぼ負荷ゼロ、ドラッグ中は完全沈黙。
   EventSetMillisecondTimer(150);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   SaveAll();
   for(int i = 0; i < ArraySize(g_recs); i++)
      if(g_recs[i].created) DeleteBoxObjects(g_recs[i].id);
   ObjectDelete(0, BTN_ADD);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| タイマー: ★Ver3.2④ ダーティチェック付き。静止中は何もしない    |
//+------------------------------------------------------------------+
void OnTimer()
{
   SyncIfNeeded(false);
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   return(rates_total);
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   //--- チャート変化(スクロール・ズーム・リサイズ)→ 再同期 ---
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      DrawAddButton();       // リサイズでボタン位置も再計算
      SyncIfNeeded(true);    // ★Ver3.2④: 遅延生成+差分同期(変化時のみ再描画)
      return;
   }

   //--- [＋]ボタン → 箱を追加 ---
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_ADD)
   {
      ObjectSetInteger(0, BTN_ADD, OBJPROP_STATE, false);
      AddNewBox();
      return;
   }

   //--- [×]ボタン → 対応箱を削除 ---
   if(id == CHARTEVENT_OBJECT_CLICK && StringFind(sparam, PFX_CL) == 0)
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      string idStr = StringSubstr(sparam, StringLen(PFX_CL));
      int    delId = (int)StringToInteger(idStr);
      DeleteBoxObjects(delId);
      // ★Ver3.2: データ(g_recs)からも取り除く
      int r = FindRec(delId);
      if(r >= 0)
      {
         for(int i = r; i < ArraySize(g_recs) - 1; i++)
            g_recs[i] = g_recs[i + 1];
         ArrayResize(g_recs, ArraySize(g_recs) - 1);
      }
      SaveAll();
      ChartRedraw(0);
      return;
   }

   //--- グリップドラッグ完了 → チャート座標を逆算してアンカー更新・保存 ---
   if(id == CHARTEVENT_OBJECT_DRAG && StringFind(sparam, PFX_GRIP) == 0)
   {
      string idStr  = StringSubstr(sparam, StringLen(PFX_GRIP));
      int    dragId = (int)StringToInteger(idStr);
      string nmA    = PFX_ANCHOR + (string)dragId;
      string nmG    = PFX_GRIP   + (string)dragId;
      string nmE    = PFX_ED     + (string)dragId;
      string nmC    = PFX_CL     + (string)dragId;

      // グリップの現在ピクセル位置を取得
      int gx = (int)ObjectGetInteger(0, nmG, OBJPROP_XDISTANCE);
      int gy = (int)ObjectGetInteger(0, nmG, OBJPROP_YDISTANCE);
      // Edit左端に合わせる (グリップはEditの左 GRIP_W px)
      int px = gx + GRIP_W;
      int py = gy;

      // ピクセル→チャート座標変換してアンカーとg_recsを更新
      datetime newT; double newPrice;
      if(PixelToAnchor(px, py, newT, newPrice))
      {
         ObjectSetInteger(0, nmA, OBJPROP_TIME,  newT);
         ObjectSetDouble (0, nmA, OBJPROP_PRICE, newPrice);
         int r = FindRec(dragId);
         if(r >= 0){ g_recs[r].t = newT; g_recs[r].price = newPrice; }
      }

      // Edit・Close位置も更新
      ObjectSetInteger(0, nmE, OBJPROP_XDISTANCE, px);
      ObjectSetInteger(0, nmE, OBJPROP_YDISTANCE, py);
      ObjectSetInteger(0, nmC, OBJPROP_XDISTANCE, px + InpBoxW);
      ObjectSetInteger(0, nmC, OBJPROP_YDISTANCE, py);

      // ★差分キャッシュも更新(直後のタイマー同期での無駄書換え防止)
      int r2 = FindRec(dragId);
      if(r2 >= 0){ g_recs[r2].lastPx = px; g_recs[r2].lastPy = py; }

      // ドロップ完了。選択状態を解除し、以後は通常どおりチャート追従を再開させる
      ObjectSetInteger(0, nmG, OBJPROP_SELECTED, false);

      SaveAll();
      ChartRedraw(0);
      return;
   }

   //--- OBJ_EDIT の文字確定 → g_recsへ反映して保存 ---
   if(id == CHARTEVENT_OBJECT_ENDEDIT && StringFind(sparam, PFX_ED) == 0)
   {
      string idStr = StringSubstr(sparam, StringLen(PFX_ED));
      int    edId  = (int)StringToInteger(idStr);
      int r = FindRec(edId);
      if(r >= 0 && ObjectFind(0, sparam) >= 0)
         g_recs[r].txt = ObjectGetString(0, sparam, OBJPROP_TEXT);
      SaveAll();
      return;
   }
}
//+------------------------------------------------------------------+
