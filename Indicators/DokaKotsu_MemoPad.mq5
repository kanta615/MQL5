//+------------------------------------------------------------------+
//|                          DokaKotsu_MemoPad.mq5                   |
//|   バージョン : Ver2.5    修正 : 2026-07-03 (JST)                |
//|   ・旧名 DokaKotsu_MessageBox.mq5 から改称                       |
//|   ・画面外退避を追加し、メモを貼った日時・価格に確実に追従        |
//|     (アンカーが可視範囲外のときは箱を退避=非表示にする)          |
//|   ・[Ver2.4] インストール時の初期3箱の自動生成を廃止              |
//|     (保存データが無い場合は箱ゼロで開始。[＋]で手動追加のみ)     |
//|   ・[Ver2.4] ミリ秒タイマーで常時再同期し、チャートのドラッグ    |
//|     スクロール中も箱がその日時・価格に確実に追従するよう強化     |
//|   ・[Ver2.5] タイマー同期がドラッグ中の座標を奪う不具合を修正     |
//|     (選択中=ドラッグ中の箱は同期をスキップし、ドロップ後に      |
//|      選択解除して追従を再開する)                                |
//|   ・[Ver2.6] [＋]追加ボタンの表示位置を4隅から選択可能に          |
//|     (InpAddBtnCorner、初期値は左下)                              |
//|   ・[Ver2.7] [＋]ボタンのX/Yオフセットを個別調整可能に            |
//|     (InpAddBtnOffsetX/Y、初期値10,10。右側コーナーは価格        |
//|      スケールに隠れないよう内部で+40px補正)                     |
//|   ・[Ver2.8] [＋]ボタンのオフセット初期値を0,0に変更。角ごとの   |
//|     補正値を内蔵(左下:上30右20/左上:下20右30/右下:上30左60/    |
//|     右上:下20左60)。InpAddBtnOffsetX/Yはこれに追加する微調整用 |
//|   ・[Ver2.9] 角ごとの補正値を再調整                              |
//|     (左下:上50右20/左上:下20右20/右下:上50左60/右上:下20左60) |
//|   ・[Ver3.0] 初期配置Y(InpStartY)の初期値を400に変更。          |
//|     「縦の間隔(px)」入力(InpRowGap)を削除し、内部固定値化       |
//|   ・[Ver3.1] 新規追加ボックスの初期位置を、チャートの現在表示    |
//|     範囲の縦横中央を基準に計算するよう変更(従来は左側固定)      |
//|------------------------------------------------------------------|
//|  チャートの好きな場所にメッセージ箱を自由に貼るツール。          |
//|                                                                  |
//|  ■ 機能一覧                                                     |
//|   ① チャート左下の[＋]ボタンで箱を追加(数量無制限)             |
//|   ② 箱右端の[×]ボタンで個別削除                                |
//|   ③ 箱をクリックしてその場で文字を直接編集                      |
//|   ④ 箱をドラッグして移動 → チャート座標(時間/価格)で保存      |
//|   ⑤ 過去スクロールしても箱はその日時・価格に追従する            |
//|   ⑥ 再起動・時間足変更後も位置・文字を完全復元                  |
//|   ⑦ インストール直後は箱ゼロ。必要な分だけ[＋]で追加            |
//|                                                                  |
//|  使い方:                                                         |
//|   ・追加 : チャート左下の[＋]ボタンを押す                       |
//|   ・編集 : 箱をクリック → そのまま文字入力 → Enterで確定       |
//|   ・移動 : 箱の枠(色付き部分)をドラッグ                        |
//|   ・削除 : 箱右端の[×]を押す                                   |
//|                                                                  |
//|  ※ MQL5\Indicators\ に置いてコンパイル。UTF-8 BOMで保存。      |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "3.10"
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

//=== 定数 ============================================================
#define PFX_ANCHOR  "DKMB21_A_"   // OBJ_TEXT (チャート座標アンカー・非表示)
#define PFX_GRIP    "DKMB21_G_"   // OBJ_LABEL (ドラッグハンドル・掴みやすい)
#define PFX_ED      "DKMB21_E_"   // OBJ_EDIT (テキスト編集・ピクセル追従)
#define PFX_CL      "DKMB21_C_"   // OBJ_BUTTON (×削除ボタン)
#define BTN_ADD     "DKMB21_ADD"  // OBJ_BUTTON (＋追加ボタン)
#define CLOSE_W     24             // ×ボタン幅
#define CLOSE_H     24             // ×ボタン高
#define GRIP_W      20             // グリップ幅
#define ROW_GAP     50              // 新規追加時の縦の間隔(px) ※旧InpRowGap固定値
#define OFFSCR_X    -10000         // ★画面外退避用X(アンカーが可視範囲外のとき箱をここへ=非表示)

//=== グローバル ======================================================
int g_maxId = 0;

//+------------------------------------------------------------------+
string SaveFileName()
{
   // ★改称後も既存メモを引き継ぐため、保存ファイル名は旧名のまま据え置く
   return "DK_MsgBox21_" + _Symbol + ".txt";
}

//+------------------------------------------------------------------+
string DefaultText(int idx)
{
   return "自由に変更ください";
}

//+------------------------------------------------------------------+
//| チャート座標 → ピクセル座標変換                                  |
//+------------------------------------------------------------------+
bool AnchorToPixel(datetime t, double price, int &px, int &py)
{
   int sub = 0;
   return ChartTimePriceToXY(0, sub, t, price, px, py);
}

//+------------------------------------------------------------------+
//| ピクセル座標 → チャート座標変換                                  |
//+------------------------------------------------------------------+
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

   // ★角ごとの補正値(角ちょうどだと隠れる/被るため、内側へ寄せる基準オフセット)
   //   左下: 上50・右20 / 左上: 下20・右20 / 右下: 上50・左60 / 右上: 下20・左60
   //   InpAddBtnOffsetX/Y(初期値0,0)はこの基準値に対する追加の微調整分
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
//| 1箱セット描画                                                    |
//|   アンカー(OBJ_TEXT)はチャート座標に固定→スクロール追従         |
//|   グリップ(OBJ_LABEL)はアンカーに重ねて表示・ドラッグ可         |
//|   Edit/Closeはアンカーのピクセル位置に毎回同期                   |
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
   ObjectSetInteger(0, nmA, OBJPROP_SELECTABLE,  false);   // 選択させない
   ObjectSetInteger(0, nmA, OBJPROP_HIDDEN,      true);
   ObjectSetInteger(0, nmA, OBJPROP_ZORDER,      1);

   //--- ピクセル座標を求める ---
   int px = InpStartX, py = InpStartY;
   AnchorToPixel(t, price, px, py);

   //--- グリップハンドル (OBJ_LABEL・左端に配置・ドラッグで移動) ---
   //    ドラッグするとCHARTEVENT_OBJECT_DRAGが発火する
   if(ObjectFind(0, nmG) < 0)
      ObjectCreate(0, nmG, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, nmG, OBJPROP_XDISTANCE,   px - GRIP_W);
   ObjectSetInteger(0, nmG, OBJPROP_YDISTANCE,   py);
   ObjectSetString (0, nmG, OBJPROP_TEXT,        "⠿");    // 掴みやすいグリップ文字
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
}

//+------------------------------------------------------------------+
//| 箱セット削除                                                     |
//+------------------------------------------------------------------+
void DeleteBox(int id)
{
   ObjectDelete(0, PFX_ANCHOR + (string)id);
   ObjectDelete(0, PFX_GRIP   + (string)id);
   ObjectDelete(0, PFX_ED     + (string)id);
   ObjectDelete(0, PFX_CL     + (string)id);
}

//+------------------------------------------------------------------+
//| 全箱のEdit/Closeをアンカーのピクセル位置に同期                   |
//| (チャートスクロール・ズーム変更時に呼ぶ)                         |
//|   ★アンカー(時刻/価格)が可視範囲外なら箱を画面外へ退避=非表示。  |
//|     位置はアンカーに保持されるので、その日時に戻れば再表示される。|
//+------------------------------------------------------------------+
void SyncAllPixels()
{
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);

   for(int id = 0; id < g_maxId; id++)
   {
      string nmA = PFX_ANCHOR + (string)id;
      string nmG = PFX_GRIP   + (string)id;
      string nmE = PFX_ED     + (string)id;
      string nmC = PFX_CL     + (string)id;
      if(ObjectFind(0, nmA) < 0) continue;

      // ★ドラッグ中(=グリップが選択状態)の箱は座標を触らない。
      //   ここで上書きすると、マウス追従中の位置が毎ティック元へ
      //   引き戻され、ドラッグ操作自体が効かなくなってしまう。
      if((bool)ObjectGetInteger(0, nmG, OBJPROP_SELECTED))
         continue;

      datetime t     = (datetime)ObjectGetInteger(0, nmA, OBJPROP_TIME);
      double   price = ObjectGetDouble(0, nmA, OBJPROP_PRICE);

      int px = 0, py = 0;
      bool ok = AnchorToPixel(t, price, px, py);

      // 横方向(時刻)で可視判定。箱の矩形(グリップ〜×まで)が画面に少しでも
      // 掛かっていれば表示。掛かっていない/変換失敗なら画面外として退避。
      bool onScreen = ok
                      && (px + InpBoxW + CLOSE_W > 0)   // 右端が画面左より右
                      && (px - GRIP_W       < chartW);  // 左端が画面右より左

      if(!onScreen)
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
}

//+------------------------------------------------------------------+
//| 全箱を保存                                                       |
//+------------------------------------------------------------------+
void SaveAll()
{
   int h = FileOpen(SaveFileName(), FILE_WRITE | FILE_TXT | FILE_ANSI, '\t', CP_UTF8);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, StringFormat("MAXID\t%d\r\n", g_maxId));

   for(int id = 0; id < g_maxId; id++)
   {
      string nmA = PFX_ANCHOR + (string)id;
      string nmE = PFX_ED     + (string)id;
      if(ObjectFind(0, nmA) < 0) continue;

      datetime t     = (datetime)ObjectGetInteger(0, nmA, OBJPROP_TIME);
      double   price = ObjectGetDouble(0, nmA, OBJPROP_PRICE);
      string   txt   = ObjectGetString(0, nmE, OBJPROP_TEXT);
      StringReplace(txt, "\t", " ");
      StringReplace(txt, "\r", " ");
      StringReplace(txt, "\n", " ");
      FileWriteString(h, StringFormat("BOX\t%d\t%I64d\t%.8f\t%s\r\n",
                                      id, (long)t, price, txt));
   }
   FileClose(h);
}

//+------------------------------------------------------------------+
//| 保存から復元。戻り値=復元した箱数                                |
//+------------------------------------------------------------------+
int LoadAll()
{
   if(!FileIsExist(SaveFileName())) return 0;
   int h = FileOpen(SaveFileName(), FILE_READ | FILE_TXT | FILE_ANSI, '\t', CP_UTF8);
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
         g_maxId = (int)StringToInteger(a[1]);
      }
      else if(a[0] == "BOX" && k >= 5)
      {
         int      id    = (int)StringToInteger(a[1]);
         datetime t     = (datetime)StringToInteger(a[2]);
         double   price = StringToDouble(a[3]);
         string   txt   = a[4];
         if(t < D'2010.01.01' || price <= 0.0) continue;
         DrawBox(id, t, price, txt);
         if(id >= g_maxId) g_maxId = id + 1;
         count++;
      }
   }
   FileClose(h);
   return count;
}

//+------------------------------------------------------------------+
//| 箱を新規追加                                                     |
//+------------------------------------------------------------------+
void AddNewBox()
{
   int id = g_maxId;
   g_maxId++;

   // ★チャートの現在の表示範囲(縦横)から中央座標を算出し、そこを基準配置とする
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int centerX = chartW / 2 - InpBoxW / 2;
   int centerY = chartH / 2 - InpBoxH / 2;

   // 既存箱の最下端ピクセルを探して、その下に配置(中央基準からスタック)
   int bestPY = centerY;
   for(int i = 0; i < id; i++)
   {
      string nmA = PFX_ANCHOR + (string)i;
      if(ObjectFind(0, nmA) < 0) continue;
      datetime t  = (datetime)ObjectGetInteger(0, nmA, OBJPROP_TIME);
      double   pr = ObjectGetDouble(0, nmA, OBJPROP_PRICE);
      int px2 = 0, py2 = 0;
      if(AnchorToPixel(t, pr, px2, py2))
      {
         if(py2 + InpBoxH + ROW_GAP - InpBoxH > bestPY)
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

   DrawBox(id, newT, newPrice, DefaultText(id));
   SaveAll();
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
int OnInit()
{
   g_maxId = 0;
   LoadAll();   // 保存データがあれば復元。無ければ箱ゼロのまま(自動生成しない)

   DrawAddButton();
   SyncAllPixels();   // ★復元直後にアンカー基準で位置同期(画面外の箱は退避)
   ChartRedraw(0);

   // ★チャートのドラッグスクロール中も確実に追従させるため、
   //   CHARTEVENT_CHART_CHANGEに加えてタイマーでも定期的に再同期する
   EventSetMillisecondTimer(150);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   SaveAll();
   for(int id = 0; id < g_maxId; id++) DeleteBox(id);
   ObjectDelete(0, BTN_ADD);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| タイマー: チャートのスクロール/ズーム中も箱をその日時・価格に   |
//|          張り付かせ続けるための定期再同期                       |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_maxId <= 0) return;
   SyncAllPixels();
   ChartRedraw(0);
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
   //--- チャート変化(スクロール・ズーム・リサイズ)→ 全箱を再同期 ---
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      DrawAddButton();   // リサイズでボタン位置も再計算
      SyncAllPixels();
      ChartRedraw(0);
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
      DeleteBox(delId);
      SaveAll();
      ChartRedraw(0);
      return;
   }

   //--- グリップドラッグ完了 → チャート座標を逆算してアンカー更新・全同期・保存 ---
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

      // ピクセル→チャート座標変換してアンカーを更新
      datetime newT; double newPrice;
      if(PixelToAnchor(px, py, newT, newPrice))
      {
         ObjectSetInteger(0, nmA, OBJPROP_TIME,  newT);
         ObjectSetDouble (0, nmA, OBJPROP_PRICE, newPrice);
      }

      // Edit・Close位置も更新
      ObjectSetInteger(0, nmE, OBJPROP_XDISTANCE, px);
      ObjectSetInteger(0, nmE, OBJPROP_YDISTANCE, py);
      ObjectSetInteger(0, nmC, OBJPROP_XDISTANCE, px + InpBoxW);
      ObjectSetInteger(0, nmC, OBJPROP_YDISTANCE, py);

      // ★ドロップ完了。選択状態を解除し、以後は通常どおりチャート追従を再開させる
      ObjectSetInteger(0, nmG, OBJPROP_SELECTED, false);

      SaveAll();
      ChartRedraw(0);
      return;
   }

   //--- アンカードラッグ完了(念のため残す) ---
   if(id == CHARTEVENT_OBJECT_DRAG && StringFind(sparam, PFX_ANCHOR) == 0)
   {
      string idStr  = StringSubstr(sparam, StringLen(PFX_ANCHOR));
      int    dragId = (int)StringToInteger(idStr);
      string nmA    = PFX_ANCHOR + (string)dragId;
      string nmE    = PFX_ED     + (string)dragId;
      string nmC    = PFX_CL     + (string)dragId;

      datetime t     = (datetime)ObjectGetInteger(0, nmA, OBJPROP_TIME);
      double   price = ObjectGetDouble(0, nmA, OBJPROP_PRICE);
      int px = 0, py = 0;
      if(AnchorToPixel(t, price, px, py))
      {
         ObjectSetInteger(0, nmE, OBJPROP_XDISTANCE, px);
         ObjectSetInteger(0, nmE, OBJPROP_YDISTANCE, py);
         ObjectSetInteger(0, nmC, OBJPROP_XDISTANCE, px + InpBoxW);
         ObjectSetInteger(0, nmC, OBJPROP_YDISTANCE, py);
      }
      SaveAll();
      ChartRedraw(0);
      return;
   }

   //--- OBJ_EDIT の文字確定 → 保存 ---
   if(id == CHARTEVENT_OBJECT_ENDEDIT && StringFind(sparam, PFX_ED) == 0)
   {
      SaveAll();
      return;
   }
}
//+------------------------------------------------------------------+
