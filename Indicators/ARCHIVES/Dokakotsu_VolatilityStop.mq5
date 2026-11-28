//+------------------------------------------------------------------+
//| Dokakotsu_VolatilityStop.mq5                                     |
//| 更新日: 2026-11-03                                               |
//| 変更履歴:                                                        |
//|   v1.05 2026-11-03 ファイル名を変更(名称のみ。判定・表示は不変)  |
//|         ・VolatilityStop.mq5 → Dokakotsu_VolatilityStop.mq5       |
//|         ・通知メールの件名も Dokakotsu_VolatilityStop に変更       |
//|         ・DokaKotsu本体との連携はGV DK_VSTOP_<チャートID>のみで、  |
//|           ファイル名には依存しないので、連携は今までどおり動く     |
//|         ・EAは、このGVを読んで、エントリー時のSTOP/RUNを           |
//|           エントリーリーズン(context.vstop)に記録する              |
//|           (GV=1→"STOP" / 0→"RUN" / 無い・古い→"NA")               |
//|   v1.04 2026-10-22 DokaKotsuのエントリー禁止用にSTOP状態を公開    |
//|         ・GV DK_VSTOP_<チャートID>(1=禁止マーク表示中/0=非表示)  |
//|           と DK_VSTOP_TS_<チャートID>(最終更新)を毎回書き込む    |
//|         ・公開値は禁止マークの表示判定(stop)そのもの(WYSIWYG)    |
//|         ・削除時はGVも削除。InpPublishGVでON/OFF                 |
//|   v1.03 2026-10-21 MT4版の計算式照合用ログを追加                 |
//|         ・ATR候補4式(SMA/Wilder/H-L/EMA)、VR候補3式を確定足で出力|
//|         ・計算足とチャート足の両方で出力                         |
//|   v1.02 2026-10-21 MT4版との数値合わせ                           |
//|         ・XAUUSD/GOLDのpip自動判定を 0.1ドル=1pip に修正         |
//|         ・現在足出来高の経過時間換算を選択式に（初期値OFF=MT4互換）|
//|         ・検証用ログ出力（新しい足ごとに計算過程を出力）を追加   |
//|   v1.01 2026-10-21 表示表の改修                                  |
//|         ・表示コーナー指定を追加（初期値: 左下）                 |
//|         ・枠線/見出し/行ラベル色を状態に連動させる設定を追加     |
//|         ・表の配置をチャートサイズから計算し、サイズ変更に追従   |
//|   v1.00 2026-10-21 新規作成                                      |
//|         MT4版ボラティリティ判定インジ（ATR/Volumes比）のMT5移植  |
//|         ・ATR比 / ATR[Pips] による許容判定                       |
//|         ・Volumes比（短期平均÷長期平均）による許容判定           |
//|         ・許容外のときチャート中央背景にSTOPマーク表示           |
//|         ・STOP解消時のサウンド/アラート/メール/プッシュ通知      |
//|         ・判定足（現在足/確定足）、ATRとVRの組合せ(OR/AND)を追加 |
//| ※判定ロジックは本インジケーター内のみで管理する                 |
//| ※グレー表示 = 禁止エリア（ボラティリティ不足）                  |
//+------------------------------------------------------------------+
#property version   "1.05"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

//--- 列挙型 -----------------------------------------------------------
enum ENUM_ATR_DISP
  {
   ATR_DISP_PIPS  = 0, // ATR [Pips]
   ATR_DISP_RATIO = 1  // ATR比
  };
enum ENUM_JUDGE
  {
   JUDGE_RATIO = 0, // ATR比
   JUDGE_PIPS  = 1  // ATR [Pips]
  };
enum ENUM_NOTIFY
  {
   NOTIFY_LOW  = 0, // 過小時
   NOTIFY_HIGH = 1, // 過大時
   NOTIFY_BOTH = 2, // 過小・過大時
   NOTIFY_OFF  = 3  // 表示しない
  };
enum ENUM_COMBINE
  {
   COMB_OR  = 0, // ATR・VRどちらかで判定 (OR)
   COMB_AND = 1  // ATR・VR両方で判定 (AND)
  };
enum ENUM_JUDGE_BAR
  {
   JBAR_NOW = 0, // 現在足 (Now)
   JBAR_PRE = 1  // 確定足 (Pre)
  };
enum ENUM_CORNER_POS
  {
   POS_LEFT_UPPER  = 0, // 左上
   POS_LEFT_LOWER  = 1, // 左下
   POS_RIGHT_UPPER = 2, // 右上
   POS_RIGHT_LOWER = 3  // 右下
  };
enum ENUM_SOUND
  {
   SND_STOPS  = 0, // stops.wav
   SND_ALERT  = 1, // alert.wav
   SND_ALERT2 = 2, // alert2.wav
   SND_NEWS   = 3, // news.wav
   SND_OK     = 4, // ok.wav
   SND_EXPERT = 5, // expert.wav
   SND_CUSTOM = 6  // ファイル名指定
  };

//--- 入力パラメータ ---------------------------------------------------
input ENUM_TIMEFRAMES InpTF        = PERIOD_M5;     // 計算時間足
input ENUM_CORNER_POS InpCorner    = POS_LEFT_LOWER; // 表示コーナー
input int             InpX         = 34;            // 表示位置 X (コーナーからの距離)
input int             InpY         = 11;            // 表示位置 Y (コーナーからの距離)
input double          InpScale     = 300.0;         // 表示比率 [%]
input int             InpFontSize  = 8;             // 文字サイズ
input color           InpBgColor   = C'20,20,20';   // 背景色
input bool            InpLinkColor = true;          // 枠線・見出し色を状態に連動
input color           InpFrameColor= C'90,90,90';   // 枠線色 (連動しない場合)

input group "●ATR設定●"
input ENUM_ATR_DISP   InpAtrDisp   = ATR_DISP_PIPS; // ATR表示設定
input int             InpAtrShort  = 5;             // 短期計算周期
input int             InpAtrLong   = 1000;          // 長期計算周期 (ATR比 = 短期÷長期)
input double          InpPipPoints = 0;             // 1pipのポイント数 (0=自動 / XAUUSDは0.1ドル=1pip)
input ENUM_JUDGE      InpJudge     = JUDGE_RATIO;   // 許容判定方式
input double          InpAtrMin    = 0.7;           // 最低許容ATR比 (又はATR[Pips])
input double          InpAtrMax    = 3.0;           // 最高許容ATR比 (又はATR[Pips])
input color           InpAtrColLow = clrGray;       // 状態表示色 ボラティリティ小
input color           InpAtrColOk  = clrLightSkyBlue; // 状態表示色 適正
input color           InpAtrColHi  = clrRed;        // 状態表示色 ボラティリティ大

input group "●Volumes比設定●"
input bool            InpVolOn     = true;          // Volumesスイッチ
input int             InpVolShort  = 12;            // 短期計算周期
input int             InpVolLong   = 1000;          // 長期計算周期 (Volumes比 = 短期÷長期)
input bool            InpVolProject= false;         // 現在足出来高を経過時間で換算 (false=MT4互換)
input double          InpVolMin    = 0.6;           // 最低許容Volumes比
input double          InpVolMax    = 2.5;           // 最高許容Volumes比
input color           InpVolColLow = clrGray;       // 状態表示色 ボラティリティ小
input color           InpVolColOk  = clrAquamarine; // 状態表示色 適正
input color           InpVolColHi  = clrRed;        // 状態表示色 ボラティリティ大

input group "●STOPマーク設定●"
input ENUM_NOTIFY     InpNotify    = NOTIFY_LOW;    // 通知モード
input ENUM_COMBINE    InpCombine   = COMB_OR;       // ATR・VRの組合せ
input ENUM_JUDGE_BAR  InpJudgeBar  = JBAR_NOW;      // 判定に使う足
input string          InpMarkFont  = "Webdings";    // フォント
input string          InpMarkText  = "x";           // テキスト
input int             InpMarkSize  = 300;           // マークサイズ
input color           InpMarkColor = clrBrown;      // マーク色
input int             InpMarkDX    = 0;             // シフト量 X
input int             InpMarkDY    = 0;             // シフト量 Y

input group "●通知設定●"
input bool            InpSoundOn   = true;          // STOP解消サウンド
input string          InpSndFont   = "Webdings";    // フォント
input string          InpSndText   = "~";           // テキスト
input int             InpSndSize   = 10;            // マークサイズ
input color           InpSndColor  = clrOrange;     // サウンドマーク色
input ENUM_SOUND      InpSndFile   = SND_STOPS;     // サウンドファイル
input string          InpSndCustom = "ファイル名.wav"; // 指定ファイル名 (「ファイル名指定」選択時)
input bool            InpAlert     = false;         // アラート
input bool            InpMail      = false;         // メール
input bool            InpPush      = false;         // プッシュ通知

input group "●検証用●"
input bool            InpDebugLog  = false;         // 計算過程をログ出力 (新しい足ごと)
input bool            InpCandLog   = false;         // 数式候補をログ出力 (MT4照合用)

input group "●DokaKotsu連携●"
input bool            InpPublishGV = true;          // STOP状態をGVで公開 (DokaKotsuのエントリー禁止に使用)

//--- 定数・グローバル -------------------------------------------------
#define PREFIX   "VSTOP_"
#define ST_NA    2
#define ST_LOW  -1
#define ST_OK    0
#define ST_HIGH  1

ENUM_TIMEFRAMES g_tf;
int    g_hAtrS = INVALID_HANDLE;
int    g_hAtrL = INVALID_HANDLE;
double g_pip   = 0;
bool   g_stopPrev = false;
bool   g_ready    = false;
int    g_cellW, g_cellH;
int    g_ox = 0, g_oy = 0;     // 表の左上座標（左上基準px）
bool   g_log = false;          // 今回の更新でログを出すか
datetime g_logBar = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   if(InpAtrShort < 1 || InpAtrLong < InpAtrShort ||
      InpVolShort < 1 || InpVolLong < InpVolShort)
     {
      Print("周期設定が不正です（短期>=1 かつ 長期>=短期）");
      return(INIT_PARAMETERS_INCORRECT);
     }

   g_tf = (InpTF == PERIOD_CURRENT) ? (ENUM_TIMEFRAMES)_Period : InpTF;

   string sym = _Symbol;
   StringToUpper(sym);
   if(InpPipPoints > 0)                     g_pip = InpPipPoints * _Point;
   else if(StringFind(sym, "XAU") >= 0 ||
           StringFind(sym, "GOLD") >= 0)    g_pip = 0.1;          // 金: 0.1ドル=1pip
   else if(_Digits == 3 || _Digits == 5)    g_pip = 10 * _Point;
   else                                     g_pip = _Point;

   g_hAtrS = iATR(_Symbol, g_tf, InpAtrShort);
   g_hAtrL = iATR(_Symbol, g_tf, InpAtrLong);
   if(g_hAtrS == INVALID_HANDLE || g_hAtrL == INVALID_HANDLE)
     {
      Print("ATRハンドルの作成に失敗しました");
      return(INIT_FAILED);
     }

   double sc = MathMax(InpScale, 10.0) / 100.0;
   g_cellW = (int)MathRound(InpFontSize * 3.2 * sc);
   g_cellH = (int)MathRound(InpFontSize * 2.0 * sc);

   EventSetTimer(1);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0, PREFIX);
   if(InpPublishGV)
     {
      GlobalVariableDel(StringFormat("DK_VSTOP_%I64d",    ChartID()));
      GlobalVariableDel(StringFormat("DK_VSTOP_TS_%I64d", ChartID()));
     }
   if(g_hAtrS != INVALID_HANDLE) IndicatorRelease(g_hAtrS);
   if(g_hAtrL != INVALID_HANDLE) IndicatorRelease(g_hAtrL);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[],
                const double &high[], const double &low[],
                const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
  {
   Update();
   return(rates_total);
  }

void OnTimer() { Update(); }

void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
  {
   if(id == CHARTEVENT_CHART_CHANGE) Update();
  }

//+------------------------------------------------------------------+
//| ATR取得（pips値と比率）                                          |
//+------------------------------------------------------------------+
bool GetAtr(const int shift, double &pips, double &ratio)
  {
   if(BarsCalculated(g_hAtrS) <= shift || BarsCalculated(g_hAtrL) <= shift)
      return(false);
   double s[1], l[1];
   if(CopyBuffer(g_hAtrS, 0, shift, 1, s) != 1) return(false);
   if(CopyBuffer(g_hAtrL, 0, shift, 1, l) != 1) return(false);
   if(l[0] <= 0 || g_pip <= 0) return(false);
   pips  = s[0] / g_pip;
   ratio = s[0] / l[0];
   if(g_log)
      PrintFormat("[ATR shift%d] 短期ATR=%.3f 長期ATR=%.3f pip=%.5f → %.1fpips 比=%.2f",
                  shift, s[0], l[0], g_pip, pips, ratio);
   return(true);
  }

//+------------------------------------------------------------------+
//| Volumes比取得（短期平均÷長期平均）                               |
//| 現在足(shift=0)は形成途中のため経過時間で出来高を換算する        |
//+------------------------------------------------------------------+
bool GetVolRatio(const int shift, double &ratio)
  {
   int need = InpVolLong + shift + 1;
   long v[];
   ArraySetAsSeries(v, true);
   if(CopyTickVolume(_Symbol, g_tf, 0, need, v) < need) return(false);

   double v0 = (double)v[shift];
   if(shift == 0 && InpVolProject)
     {
      int    per = PeriodSeconds(g_tf);
      double el  = (double)(TimeCurrent() - iTime(_Symbol, g_tf, 0));
      double w   = (per > 0) ? el / per : 1.0;
      if(w < 0.2)      v0 = (double)v[1];      // 足の序盤は直前足で代用
      else if(w < 1.0) v0 = (double)v[0] / w;  // 経過時間で1本分に換算
     }

   double sumS = 0, sumL = 0;
   for(int i = shift; i < shift + InpVolLong; i++)
     {
      double x = (i == shift) ? v0 : (double)v[i];
      if(i < shift + InpVolShort) sumS += x;
      sumL += x;
     }
   if(sumL <= 0) return(false);
   ratio = (sumS / InpVolShort) / (sumL / InpVolLong);
   if(g_log)
      PrintFormat("[VR shift%d] 短期平均=%.1f 長期平均=%.1f VR=%.2f (現在足出来高=%I64d)",
                  shift, sumS / InpVolShort, sumL / InpVolLong, ratio, v[0]);
   return(true);
  }

//+------------------------------------------------------------------+
int Judge(const double val, const double mn, const double mx)
  {
   if(val < mn) return(ST_LOW);
   if(val > mx) return(ST_HIGH);
   return(ST_OK);
  }

color StateColor(const int st, const color cLow, const color cOk, const color cHi)
  {
   if(st == ST_LOW)  return(cLow);
   if(st == ST_HIGH) return(cHi);
   if(st == ST_OK)   return(cOk);
   return(clrDimGray);
  }

bool Hit(const int st)
  {
   switch(InpNotify)
     {
      case NOTIFY_LOW:  return(st == ST_LOW);
      case NOTIFY_HIGH: return(st == ST_HIGH);
      case NOTIFY_BOTH: return(st == ST_LOW || st == ST_HIGH);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| メイン更新処理（全ロジックはここに集約）                         |
//+------------------------------------------------------------------+
void Update()
  {
   datetime bt = iTime(_Symbol, g_tf, 0);
   bool newBar = (bt != g_logBar && bt > 0);
   if(newBar) g_logBar = bt;
   g_log = (InpDebugLog && newBar);
   if(InpCandLog && newBar) LogCandidates();
   double atrDisp[2], volVal[2], atrJudgeVal[2];
   int    atrSt[2], volSt[2];

   for(int s = 0; s < 2; s++)
     {
      double pips, ratio, vr;
      if(GetAtr(s, pips, ratio))
        {
         atrDisp[s]     = (InpAtrDisp == ATR_DISP_PIPS) ? pips : ratio;
         atrJudgeVal[s] = (InpJudge   == JUDGE_PIPS)    ? pips : ratio;
         atrSt[s]       = Judge(atrJudgeVal[s], InpAtrMin, InpAtrMax);
        }
      else { atrDisp[s] = 0; atrJudgeVal[s] = 0; atrSt[s] = ST_NA; }

      if(InpVolOn && GetVolRatio(s, vr))
        { volVal[s] = vr; volSt[s] = Judge(vr, InpVolMin, InpVolMax); }
      else
        { volVal[s] = 0; volSt[s] = ST_NA; }
     }

   //--- 表の描画
   DrawTable(atrDisp, atrSt, volVal, volSt);

   //--- STOP判定
   int  b      = (InpJudgeBar == JBAR_NOW) ? 0 : 1;
   bool atrHit = Hit(atrSt[b]);
   bool stop;
   if(!InpVolOn)                stop = atrHit;
   else if(InpCombine == COMB_OR) stop = atrHit || Hit(volSt[b]);
   else                         stop = atrHit && Hit(volSt[b]);

   DrawStopMark(stop);
   PublishStopGV(stop);

   //--- STOP解消通知
   if(g_ready && g_stopPrev && !stop)
      NotifyRelease(atrDisp[b], volVal[b]);

   if(atrSt[b] != ST_NA) g_ready = true;
   g_stopPrev = stop;

   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| 表示表                                                           |
//+------------------------------------------------------------------+
void DrawTable(const double &atr[], const int &atrSt[],
               const double &vol[], const int &volSt[])
  {
   string font = "Arial";
   int cols = InpVolOn ? 3 : 2;
   int tw   = cols * g_cellW;
   int th   = 3 * g_cellH;
   int cw   = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int ch   = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);

   //--- 表の左上座標をコーナー指定から算出
   switch(InpCorner)
     {
      case POS_LEFT_UPPER:  g_ox = InpX;           g_oy = InpY;           break;
      case POS_LEFT_LOWER:  g_ox = InpX;           g_oy = ch - InpY - th; break;
      case POS_RIGHT_UPPER: g_ox = cw - InpX - tw; g_oy = InpY;           break;
      default:              g_ox = cw - InpX - tw; g_oy = ch - InpY - th; break;
     }

   //--- 色の決定（現在足の状態に連動）
   color atrC = StateColor(atrSt[0], InpAtrColLow, InpAtrColOk, InpAtrColHi);
   color volC = StateColor(volSt[0], InpVolColLow, InpVolColOk, InpVolColHi);
   color lblC = clrSilver;
   color fAtr = InpFrameColor, fVol = InpFrameColor, fLbl = InpFrameColor;
   color hAtr = InpAtrColOk,   hVol = InpVolColOk;
   if(InpLinkColor)
     {
      lblC = OverallColor(atrSt[0], volSt[0]);
      fAtr = atrC; fVol = volC; fLbl = lblC;
      hAtr = atrC; hVol = volC;
     }

   // ヘッダー行
   Cell(0, 0, InpSoundOn ? InpSndText : "", InpSndColor, InpSndFont, InpSndSize, fLbl);
   Cell(1, 0, "ATR", hAtr, font, InpFontSize, fAtr);
   if(InpVolOn) Cell(2, 0, "VR", hVol, font, InpFontSize, fVol);

   string rows[2] = {"Now", "Pre"};
   for(int r = 0; r < 2; r++)
     {
      Cell(0, r + 1, rows[r], lblC, font, InpFontSize, fLbl);
      Cell(1, r + 1, (atrSt[r] == ST_NA) ? "--" : DoubleToString(atr[r], 1),
           StateColor(atrSt[r], InpAtrColLow, InpAtrColOk, InpAtrColHi), font, InpFontSize, fAtr);
      if(InpVolOn)
         Cell(2, r + 1, (volSt[r] == ST_NA) ? "--" : DoubleToString(vol[r], 1),
              StateColor(volSt[r], InpVolColLow, InpVolColOk, InpVolColHi), font, InpFontSize, fVol);
     }
  }

//--- 全体状態の色（大 > 小 > 適正 の優先順）
color OverallColor(const int atrSt, const int volSt)
  {
   int vs = InpVolOn ? volSt : ST_NA;
   if(atrSt == ST_HIGH || vs == ST_HIGH) return(InpAtrColHi);
   if(atrSt == ST_LOW  || vs == ST_LOW)  return(InpAtrColLow);
   if(atrSt == ST_OK)                    return(InpAtrColOk);
   return(clrDimGray);
  }

void Cell(const int col, const int row, const string text,
          const color txtCol, const string font, const int fsize,
          const color frameCol)
  {
   string rn = PREFIX + "R" + IntegerToString(col) + "_" + IntegerToString(row);
   string tn = PREFIX + "T" + IntegerToString(col) + "_" + IntegerToString(row);
   int x = g_ox + col * g_cellW;
   int y = g_oy + row * g_cellH;

   if(ObjectFind(0, rn) < 0)
     {
      ObjectCreate(0, rn, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, rn, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, rn, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, rn, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, rn, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, rn, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, rn, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, rn, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, rn, OBJPROP_XSIZE, g_cellW);
   ObjectSetInteger(0, rn, OBJPROP_YSIZE, g_cellH);
   ObjectSetInteger(0, rn, OBJPROP_BGCOLOR, InpBgColor);
   ObjectSetInteger(0, rn, OBJPROP_COLOR, frameCol);

   if(ObjectFind(0, tn) < 0)
     {
      ObjectCreate(0, tn, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, tn, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, tn, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, tn, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, tn, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, tn, OBJPROP_BACK, false);
     }
   ObjectSetInteger(0, tn, OBJPROP_XDISTANCE, x + g_cellW / 2);
   ObjectSetInteger(0, tn, OBJPROP_YDISTANCE, y + g_cellH / 2);
   ObjectSetString (0, tn, OBJPROP_TEXT, text);
   ObjectSetString (0, tn, OBJPROP_FONT, font);
   ObjectSetInteger(0, tn, OBJPROP_FONTSIZE, fsize);
   ObjectSetInteger(0, tn, OBJPROP_COLOR, txtCol);
  }

//+------------------------------------------------------------------+
//| STOPマーク（チャート中央・背景）                                 |
//+------------------------------------------------------------------+
void DrawStopMark(const bool show)
  {
   string n = PREFIX + "STOP";
   if(!show)
     {
      if(ObjectFind(0, n) >= 0) ObjectDelete(0, n);
      return;
     }
   int w = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int h = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);

   if(ObjectFind(0, n) < 0)
     {
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, n, OBJPROP_BACK, true);          // ローソク足の背面
      ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
     }
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, w / 2 + InpMarkDX);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, h / 2 + InpMarkDY);
   ObjectSetString (0, n, OBJPROP_TEXT, InpMarkText);
   ObjectSetString (0, n, OBJPROP_FONT, InpMarkFont);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, InpMarkSize);
   ObjectSetInteger(0, n, OBJPROP_COLOR, InpMarkColor);
  }

//+------------------------------------------------------------------+
//| STOP解消通知                                                     |
//+------------------------------------------------------------------+
string SoundFileName()
  {
   switch(InpSndFile)
     {
      case SND_STOPS:  return("stops.wav");
      case SND_ALERT:  return("alert.wav");
      case SND_ALERT2: return("alert2.wav");
      case SND_NEWS:   return("news.wav");
      case SND_OK:     return("ok.wav");
      case SND_EXPERT: return("expert.wav");
     }
   return(InpSndCustom);
  }

void NotifyRelease(const double atr, const double vr)
  {
   string tf  = StringSubstr(EnumToString(g_tf), 7);
   string msg = StringFormat("%s %s STOP解消（ボラティリティ回復） ATR=%.1f VR=%.1f",
                             _Symbol, tf, atr, vr);
   if(InpSoundOn) PlaySound(SoundFileName());
   if(InpAlert)   Alert(msg);
   if(InpMail)    SendMail("Dokakotsu_VolatilityStop: " + _Symbol, msg);
   if(InpPush)    SendNotification(msg);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| MT4照合用：数式候補ログ（確定足 shift=1 で出力）                 |
//+------------------------------------------------------------------+
double MeanArr(const double &a[], const int from, const int n)
  {
   double sm = 0;
   for(int i = from; i < from + n; i++) sm += a[i];
   return(sm / n);
  }

// wilder=true: Wilder平滑(1/n)、false: EMA(2/(n+1))
double SmoothArr(const double &a[], const int target, const int n,
                 const int got, const bool wilder)
  {
   double alpha = wilder ? 1.0 / n : 2.0 / (n + 1);
   double v = a[got - 1];
   for(int i = got - 2; i >= target; i--) v += alpha * (a[i] - v);
   return(v);
  }

void LogAtrSet(const ENUM_TIMEFRAMES tf, const string tag, const int sh)
  {
   int cnt = MathMin(Bars(_Symbol, tf), InpAtrLong * 3 + 10);
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int got = CopyRates(_Symbol, tf, 0, cnt, r);
   if(got < InpAtrLong + sh + 2)
     { PrintFormat("[候補ATR %s] 履歴不足 %d本", tag, got); return; }

   double tr[], hl[];
   ArrayResize(tr, got);
   ArrayResize(hl, got);
   for(int i = 0; i < got - 1; i++)
     {
      double pc = r[i + 1].close;
      tr[i] = MathMax(r[i].high, pc) - MathMin(r[i].low, pc);
      hl[i] = r[i].high - r[i].low;
     }
   tr[got - 1] = r[got - 1].high - r[got - 1].low;
   hl[got - 1] = tr[got - 1];

   double aS = MeanArr(tr, sh, InpAtrShort),            aL = MeanArr(tr, sh, InpAtrLong);
   double wS = SmoothArr(tr, sh, InpAtrShort, got, true), wL = SmoothArr(tr, sh, InpAtrLong, got, true);
   double hS = MeanArr(hl, sh, InpAtrShort),            hL = MeanArr(hl, sh, InpAtrLong);
   double eS = SmoothArr(tr, sh, InpAtrShort, got, false), eL = SmoothArr(tr, sh, InpAtrLong, got, false);

   PrintFormat("[候補ATR %s %s 足=%s] A1 SMA(TR)=%.1fpips 比%.2f | A2 Wilder=%.1fpips 比%.2f | A3 SMA(H-L)=%.1fpips 比%.2f | A4 EMA(TR)=%.1fpips 比%.2f",
               tag, StringSubstr(EnumToString(tf), 7), TimeToString(r[sh].time),
               aS / g_pip, aS / aL, wS / g_pip, wS / wL,
               hS / g_pip, hS / hL, eS / g_pip, eS / eL);
  }

void LogVolSet(const ENUM_TIMEFRAMES tf, const string tag, const int sh)
  {
   int need = InpVolLong + InpVolShort + sh + 1;
   long v[];
   ArraySetAsSeries(v, true);
   int got = CopyTickVolume(_Symbol, tf, 0, need, v);
   if(got < need)
     { PrintFormat("[候補VR %s] 履歴不足 %d本", tag, got); return; }

   double d[];
   ArrayResize(d, got);
   for(int i = 0; i < got; i++) d[i] = (double)v[i];

   double sS  = MeanArr(d, sh, InpVolShort);
   double sL  = MeanArr(d, sh, InpVolLong);
   double sL2 = MeanArr(d, sh + InpVolShort, InpVolLong);
   double s0  = MeanArr(d, 0, InpVolShort);
   double l0  = MeanArr(d, 0, InpVolLong);

   PrintFormat("[候補VR %s %s] V1 短期/長期=%.2f | V2 短期/長期(短期区間を除く)=%.2f | V3 現在足込み(Now相当)=%.2f | 短期平均=%.1f 長期平均=%.1f",
               tag, StringSubstr(EnumToString(tf), 7),
               sS / sL, sS / sL2, (l0 > 0 ? s0 / l0 : 0), sS, sL);
  }

void LogCandidates()
  {
   ENUM_TIMEFRAMES ctf = (ENUM_TIMEFRAMES)_Period;
   Print("==== MT4照合用 数式候補（確定足=Pre相当） ====");
   LogAtrSet(g_tf, "計算足", 1);
   if(ctf != g_tf) LogAtrSet(ctf, "チャート足", 1);
   LogVolSet(g_tf, "計算足", 1);
   if(ctf != g_tf) LogVolSet(ctf, "チャート足", 1);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| DokaKotsu連携: 禁止マークの表示状態をGVへ公開                     |
//| 判定はこのインジのみが持ち、DokaKotsu側は読むだけ                 |
//+------------------------------------------------------------------+
void PublishStopGV(const bool stop)
  {
   if(!InpPublishGV) return;
   GlobalVariableSet(StringFormat("DK_VSTOP_%I64d",    ChartID()), stop ? 1.0 : 0.0);
   GlobalVariableSet(StringFormat("DK_VSTOP_TS_%I64d", ChartID()), (double)TimeCurrent());
  }
//+------------------------------------------------------------------+
