//+------------------------------------------------------------------+
//|                                        DokaKotsu_Dashboard.mq5    |
//|  dokakotu_dashboard_v8_4.html のデザインをMT5チャート上に         |
//|  再現するパネル（第一段階：機能なし・表示のみ／固定サンプル値）   |
//|                                                                    |
//|  ■ 修正日: 2026-07-13  修正内容                                  |
//|    ①パネル縦幅(InpPanelHeightPct)既定を160→110に変更              |
//|    ②上位足の方向を固定サンプルから実データへ変更。本体インジを    |
//|      Watchdogと同じ接頭辞方式(バージョン自動検出)でChartIndicator |
//|      Getし、buf15(BufLongState)を読む。1=上昇(ライム/↑)、        |
//|      -1=下降(マゼンダ/↓)、0=グレー(→)。                         |
//|    ③ボラティリティを固定サンプルから実ATR連動へ変更。添付HTML     |
//|      (dokakotu_dashboard_v8_4.html)のanimateWave()と同じサイン波  |
//|      合成ノイズで滑らかに波打たせる。3段階(小さい=グレー/         |
//|      通常=黄色/荒れ狂う=赤、InpAtrLow/InpAtrHighで閾値調整可)。   |
//|      タイマーを500ms→150msに短縮し滑らかさを向上。                |
//|    ④経済指標「本日は該当指標なし」のフォントサイズを11→9に縮小。  |
//|      指標がある時のフォントカラーをグレー→白に変更。              |
//|                                                                  |
//|  ■ 修正日: 2026-07-13(2回目)  修正内容                            |
//|    ①上位足の方向「→レンジ」の矢印とテキストの間に半角スペース追加。|
//|    ②★★★全決済横に「DR (日次レンジpips) ★」を表示するよう変更。   |
//|      日次レンジの大きさで★の数が1〜3に変わる(InpDrSmall/Large)。  |
//|    ③エントリータイミングのレインボーバーを、DokaKotsu_RainbowBar_ |
//|      Test.mq5のCanvas版(滑らかグラデーション+角丸+グロー付き針)へ |
//|      置き換え。進捗の実ロジックは未実装(次回渡される予定)、       |
//|      暫定でサンプル値0.12のまま。                                 |
//|                                                                  |
//|  ■ 修正日: 2026-07-13(3回目)  修正内容                            |
//|    ①「決済目安」をセグメント10分割から、モニター「今日」タブの    |
//|      スクイーズ(EMA10収束)と同じ2色バー+閾値線+針のデザインに     |
//|      差し替え。収束度は仮値0.22のまま(ロジックは後日)。           |
//|    ②「エントリータイミング」を、モニター側の箱を丸ごと移植する    |
//|      形でフル実装。状態テキスト(18pt相当)・グラデーションバー     |
//|      (黄55%→緑70%→青85-100%の不等間隔ストップに修正)・シマー    |
//|      演出(光の帯が流れる)・下3ラベル・進捗%行・メッセージ箱       |
//|      (IN/GET/LOSEを状況に応じ出し分け)・連勝/獲得pips行・凡例。   |
//|      ロジック未実装のため、InpEntryDemoState(NOTRADE/READY/IN/   |
//|      GET/LOSE)で見た目だけを切り替えて確認できるようにした。      |
//|      既定はいただいたスクリーンショットに合わせGET状態。          |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

#include <Canvas\Canvas.mqh>

//--- ★2026-07-13追加: 「エントリータイミング」レインボーバーをCanvas化(DokaKotsu_RainbowBar_Testより移植)
//    5色帯の直角バーから、滑らかなグラデーション+角丸+フェザー境界+グロー付き針に変更。
//    ロジック(進捗0-1がどう決まるか)は次回渡される予定のため、今回は従来通りの
//    サンプル値(0.12=WAIT!)を暫定表示のまま使う。
#define RB_OBJ "DKD_RainbowBarCanvas"

//--- ★2026-07-13(3回目)追加: エントリータイミングBOXのデザイン確認用デモ状態切替(InpUseRealLogic=falseの時のみ使用)
enum ENUM_ENTRY_DEMO { DEMO_NOTRADE=0, DEMO_READY=1, DEMO_IN=2, DEMO_GET=3, DEMO_LOSE=4 };
input ENUM_ENTRY_DEMO InpEntryDemoState = DEMO_GET;  // 見た目確認用。既定=いただいたスクショに合わせGET状態

//--- ★2026-07-14追加: エントリータイミングを実データで動かす(モニターと同じ5ステップ判定)
input bool InpUseRealLogic = true;   // true=実ロジックで動かす。falseにするとInpEntryDemoStateの見た目確認モードに戻る
input long InpMagic = 20260606;      // EAのマジックナンバー(保有中判定に使用)
input double InpMeterConvMargin = 0.40; // メーターReady表示に必要な収束度の余裕(モニターのMETER_CONV_MARGINと同じ)
input double InpCloseFlashSeconds = 45.0; // ★2026-07-14追加: 直近決済からこの秒数以内ならGET/LOSEメッセージを表示

//+------------------------------------------------------------------+
//| ★2026-07-14追加: EA(DK_UpdateGameStats)が書くGlobalVariableを読み、|
//|   直近決済がGET(勝ち)かLOSE(負け)か、まだ「表示に値する新しさ」か、 |
//|   連勝数・pips文字列を組み立てて返す。                             |
//+------------------------------------------------------------------+
void ReadGameStats(bool &showGet, bool &showLose, string &streakTxt, string &pipsTxt, color &pipsCol)
  {
   showGet=false; showLose=false; streakTxt=""; pipsTxt=""; pipsCol=COL_GREEN;

   string gTime = StringFormat("DK_EA_LASTCLOSE_TIME_%d", InpMagic);
   string gWin  = StringFormat("DK_EA_LASTCLOSE_WIN_%d",  InpMagic);
   string gPips = StringFormat("DK_EA_LASTCLOSE_PIPS_%d", InpMagic);
   string gStrk = StringFormat("DK_EA_WINSTREAK_%d",      InpMagic);
   if(!GlobalVariableCheck(gTime)) return;

   datetime closeTime = (datetime)GlobalVariableGet(gTime);
   double   age        = (double)(TimeCurrent() - closeTime);
   if(age < 0 || age > InpCloseFlashSeconds) return;   // 決済から時間が経ちすぎていれば何も出さない

   bool   isWin = GlobalVariableCheck(gWin)  ? (GlobalVariableGet(gWin) >= 0.5) : false;
   double pips  = GlobalVariableCheck(gPips) ? GlobalVariableGet(gPips) : 0.0;
   int    strk  = GlobalVariableCheck(gStrk) ? (int)MathRound(GlobalVariableGet(gStrk)) : 0;

   if(isWin) { showGet=true;  pipsTxt=StringFormat("WIN +%.1fp",  MathAbs(pips)); pipsCol=COL_GREEN; }
   else      { showLose=true; pipsTxt=StringFormat("LOSE -%.1fp", MathAbs(pips)); pipsCol=COL_RED;   }
   if(strk>0) streakTxt="🔥"+IntegerToString(strk)+"連勝";
  }

//+------------------------------------------------------------------+
//| ★2026-07-14変更: モニター(monitor_3.py)の5ステップ判定をそのまま移植。
//|   mc(短期波色)=buf22、ha(平均足)=buf14、isTrend(非スクイーズ)=buf53、
//|   power(ADX)=buf26、convN(収束度)=buf58、stReentry(再入ロック)=buf60。
//|   buf60はindicator_14側に今回新規追加してもらったため、暫定値から実値に差し替え。
//+------------------------------------------------------------------+
void ReadEntryTimingState(int &rbLeft, string &rbText, color &rbColor, string &rbPct)
  {
   rbLeft=8; rbText="NOTRADE"; rbColor=C'200,160,0'; rbPct="";
   if(g_indHandle == INVALID_HANDLE) return;

   double bufMc[], bufHa[], bufTrend[], bufPower[], bufConv[], bufReentry[];
   if(CopyBuffer(g_indHandle,22,1,1,bufMc)      <= 0) return;
   if(CopyBuffer(g_indHandle,14,1,1,bufHa)      <= 0) return;
   if(CopyBuffer(g_indHandle,53,1,1,bufTrend)   <= 0) return;
   if(CopyBuffer(g_indHandle,26,1,1,bufPower)   <= 0) return;
   if(CopyBuffer(g_indHandle,58,1,1,bufConv)    <= 0) return;
   if(CopyBuffer(g_indHandle,60,1,1,bufReentry) <= 0) return;

   int    mc      = (int)MathRound(bufMc[0]);      // 1=上昇/-1=下降/0=グレー
   int    ha      = (int)MathRound(bufHa[0]);      // 1=上昇/-1=下降
   bool   isTrend = (bufTrend[0] < 0.5);            // buf53: 0=トレンド/1=スクイーズ
   int    power   = (int)MathRound(bufPower[0]);   // 1=ADX上昇/2=ADX下降/0=グレー
   double convN   = bufConv[0];

   bool stDir   = (mc==1 || mc==-1);
   bool stHa    = (mc==1 && ha==1) || (mc==-1 && ha==-1);
   bool stTrend = isTrend;
   bool stPower = (mc==1 && power==1) || (mc==-1 && power==2);
   bool stReentry = (bufReentry[0] < 0.5);   // ★2026-07-14変更: buf60(BufReentryLock)の実値(1=ロック中→不許可)

   bool allReady = stDir && stHa && stTrend && stPower && stReentry;
   bool convMarginOK = (convN >= InpMeterConvMargin);
   bool meterReady = allReady && convMarginOK;

   // --- 保有中(IN)判定: このシンボル・このEAのマジックでポジションがあるか ---
   string pos_state="";
   for(int k=PositionsTotal()-1; k>=0; k--)
     {
      ulong tk=PositionGetTicket(k);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      pos_state="IN"; break;
     }

   // --- モニターと同じ判定チェーン(そのまま移植) ---
   if(pos_state=="IN")        { rbLeft=100; rbText="IN！";     rbColor=C'126,200,227'; rbPct=""; }
   else if(meterReady)        { rbLeft=75;  rbText="Ready!";   rbColor=C'46,204,46';   rbPct=""; }
   else if(allReady)          { rbLeft=55;  rbText="NOTRADE";  rbColor=C'200,160,0';   rbPct="あと一歩"; }
   else if(stDir && stHa && stTrend) { rbLeft=50; rbText="NOTRADE"; rbColor=C'200,160,0'; rbPct="あと一歩"; }
   else if(stDir)             { rbLeft=25;  rbText="NOTRADE";  rbColor=C'200,160,0';   rbPct="方向◯"; }
   else                       { rbLeft=8;   rbText="NOTRADE";  rbColor=C'200,160,0';   rbPct=""; }
  }
CCanvas RbCanvas;
bool    g_rbCanvasReady = false;
int     g_rbCanvasW = 0, g_rbCanvasH = 0;

//--- ★2026-07-13(3回目)変更: モニター側の実仕様(linear-gradient 90deg,#f5c518 0%,#f5c518 55%,
//    #4caf50 70%,#42a5f5 85%,#42a5f5 100%)に合わせて、不等間隔ストップに対応させた。
double RbStopPos[5] = {0.00, 0.55, 0.70, 0.85, 1.00};
color RbGradStops[5] =
  {
   C'245,197,24',  // #f5c518 黄(NOTRADE)
   C'245,197,24',  // #f5c518 黄(55%まで同色)
   C'74,175,80',   // #4caf50 緑(Ready)
   C'66,165,245',  // #42a5f5 青(IN)
   C'66,165,245'   // #42a5f5 青(100%まで同色)
  };

color RbLerpColor(color a,color b,double t)
  {
   if(t<0) t=0;
   if(t>1) t=1;
   int r =(int)MathRound((1-t)*((a>>0) &0xFF)+t*((b>>0) &0xFF));
   int g =(int)MathRound((1-t)*((a>>8) &0xFF)+t*((b>>8) &0xFF));
   int bl=(int)MathRound((1-t)*((a>>16)&0xFF)+t*((b>>16)&0xFF));
   return (color)((bl<<16)|(g<<8)|r);
  }

color RbGradientAt(double t)
  {
   if(t<=RbStopPos[0]) return RbGradStops[0];
   if(t>=RbStopPos[4]) return RbGradStops[4];
   for(int i=0;i<4;i++)
     {
      if(t>=RbStopPos[i] && t<=RbStopPos[i+1])
        {
         double segLen=RbStopPos[i+1]-RbStopPos[i];
         double localT=(segLen>0.0)?(t-RbStopPos[i])/segLen:0.0;
         return RbLerpColor(RbGradStops[i],RbGradStops[i+1],localT);
        }
     }
   return RbGradStops[4];
  }

void RbSetPixelAlpha(int x,int y,int w,int h,uchar alpha)
  {
   if(x<0 || y<0 || x>=w || y>=h) return;
   uint cur=RbCanvas.PixelGet(x,y);
   uint rgb=cur & 0x00FFFFFF;
   RbCanvas.PixelSet(x,y,((uint)alpha<<24)|rgb);
  }

void RbApplyRoundedMask(int w,int h,int r)
  {
   for(int cy=0;cy<r;cy++)
     {
      for(int cx=0;cx<r;cx++)
        {
         double dx=r-cx-0.5;
         double dy=r-cy-0.5;
         double dist=MathSqrt(dx*dx+dy*dy);
         double alphaF;
         if(dist<=r-1.0)
            continue;
         else if(dist>=r+0.0)
            alphaF=0.0;
         else
            alphaF=1.0-(dist-(r-1.0));

         uchar a=(uchar)MathRound(255*alphaF);
         RbSetPixelAlpha(cx,       cy,       w,h,a);
         RbSetPixelAlpha(w-1-cx,   cy,       w,h,a);
         RbSetPixelAlpha(cx,       h-1-cy,   w,h,a);
         RbSetPixelAlpha(w-1-cx,   h-1-cy,   w,h,a);
        }
     }
  }

//+------------------------------------------------------------------+
//| レインボーバー本体の描画(w,h,progress0-1,角丸半径)                |
//+------------------------------------------------------------------+
void DrawRainbowBarCanvas(int w,int h,double progress,int r=9)
  {
   if(r*2>h) r=h/2;

   RbCanvas.Erase(0x00000000);

   for(int x=0;x<w;x++)
     {
      double t=(double)x/(double)(w-1);
      color  c=RbGradientAt(t);
      uint   argb=ColorToARGB(c,255);
      RbCanvas.LineVertical(x,0,h-1,argb);
     }

   double maskStartPx=w*progress;
   int    featherPx=6;
   color  darkOverlay=C'28,31,38';
   for(int x=0;x<w;x++)
     {
      if(x<maskStartPx-featherPx)
         continue;
      double distIntoMask=x-(maskStartPx-featherPx);
      double blend=distIntoMask/(double)(featherPx*2);
      if(blend<0) blend=0;
      if(blend>1) blend=1;
      double t=(double)x/(double)(w-1);
      color  base=RbGradientAt(t);
      color  mixed=RbLerpColor(base,darkOverlay,blend);
      uint   argb=ColorToARGB(mixed,255);
      RbCanvas.LineVertical(x,0,h-1,argb);
     }

   RbApplyRoundedMask(w,h,r);

   // ★2026-07-13(3回目)追加: シマー(光が斜めに流れる)演出。モニターの.rb-shimmerに相当。
   //   時間経過で位置を動かし、半透明の白い帯をバーに重ねる。
   {
      double shimmerT = MathMod((double)GetTickCount()/1200.0, 1.0);   // 0→1を約1.2秒で周回
      double shimmerCenterPx = -w*0.3 + shimmerT*(w*1.6);              // バー幅の外側から外側へ流れる
      double shimmerWidthPx  = w*0.18;
      for(int x=0;x<w;x++)
        {
         double d=MathAbs(x-shimmerCenterPx);
         if(d>shimmerWidthPx) continue;
         double a=(1.0-d/shimmerWidthPx);
         a=a*a*0.35; // 最大35%の白重ね(強すぎないように)
         uint cur=RbCanvas.PixelGet(x,h/2);
         uint origAlpha=cur & 0xFF000000;
         uint rgb=cur & 0x00FFFFFF;
         int rr=(int)(rgb&0xFF), gg=(int)((rgb>>8)&0xFF), bb=(int)((rgb>>16)&0xFF);
         int nr=(int)(rr+(255-rr)*a), ng=(int)(gg+(255-gg)*a), nb=(int)(bb+(255-bb)*a);
         uint mixedArgb=origAlpha|((uint)nb<<16)|((uint)ng<<8)|(uint)nr;
         RbCanvas.LineVertical(x,0,h-1,mixedArgb);
        }
   }

   int needleX=(int)MathRound(maskStartPx);
   for(int d=3;d>=0;d--)
     {
      int  alpha=(d==0)?255:(90-d*20);
      if(alpha<0) alpha=0;
      uint glowArgb=ColorToARGB(clrWhite,(uchar)alpha);
      int  nx=needleX-d;
      if(nx>=0 && nx<w) RbCanvas.LineVertical(nx,0,h-1,glowArgb);
      int  nx2=needleX+d;
      if(d>0 && nx2>=0 && nx2<w) RbCanvas.LineVertical(nx2,0,h-1,glowArgb);
     }

   RbCanvas.Update();
  }

//--- パネル位置・サイズ設定
input int InpPanelX          = 0;    // パネルX位置（左からの距離）＝売買ボタンの左端に合わせる
input int InpPanelY          = 120;  // パネルY位置（上からの距離）＝売買ボタンより下
input int InpPanelWidth      = 320;  // パネル幅＝売買ボタンの横幅に合わせる（環境により微調整）
input int InpPanelHeightPct  = 110;  // パネル縦幅（%）100=基準の詰まった表示／大きいほど縦に広がる

#define PFX "DKD_"

//--- カラー定義（元HTMLの配色を再現）
color COL_BG      = C'14,17,23';     // #0e1117 パネル背景
color COL_CELL    = C'22,24,32';     // #161820 内側セル
color COL_BORDER  = C'37,40,48';     // #252830 枠線
color COL_TEXT    = C'232,234,240';  // #e8eaf0 メインテキスト
color COL_GRAY    = C'136,136,136';  // ラベル用グレー（元より少し明るく視認性UP）
color COL_GRAY2   = C'85,85,85';     // #555 薄いグレー
color COL_GREEN   = C'76,175,80';    // #4caf50
color COL_RED     = C'244,67,54';    // #f44336
color COL_BLUE    = C'79,195,247';   // #4fc3f7
color COL_YELLOW  = C'230,184,0';    // #e6b800
color COL_ORANGE  = C'245,166,35';   // #f5a623
color COL_DARKCELL= C'28,31,38';     // #1c1f26
color COL_MAGENTA = C'255,0,255';    // 長期足下方向用(マゼンダ)
color COL_LIME    = C'0,255,0';      // 長期足上方向用(ライム)
color COL_WHITE   = C'232,234,240';  // 経済指標あり時のフォント色(白)

//--- ★2026-07-13追加: 本体インジ(バージョン問わず自動検出)から長期足方向を読む
input string InpIndicatorPrefix = "DokaKotsu_indicator_"; // 本体インジ名の接頭辞(バージョン番号は自動検出)
int g_indHandle = INVALID_HANDLE;
string g_indNameSeen = "";

//--- ★2026-07-13追加: ボラティリティ(ATR)の3段階しきい値(pips)
input int InpAtrPeriod    = 14;   // ATR期間
input double InpAtrLow    = 30.0;  // これ未満=ボラ無し(グレー)
input double InpAtrMid    = 70.0;  // これ未満=東京市場レベル(黄色)
input double InpAtrHigh   = 120.0; // これ未満=NY23時レベル(オレンジ)。これ以上=戦争レベル(赤、数ヶ月に一度)
int g_atrHandle = INVALID_HANDLE;

//--- ★2026-07-13追加: DR(日次レンジ)の★段階しきい値(pips、Dashboard共通のpoint*10換算)
input int InpDrSmall = 150;   // これ未満=★
input int InpDrLarge = 300;   // これ以上=★★★。間は★★

//+------------------------------------------------------------------+
//| ★2026-07-13追加: チャートに実際に貼られている本体インジを          |
//|   接頭辞だけで探す(Watchdogと同じ方式)。バージョン番号が変わっても  |
//|   ハードコード不要。                                               |
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
         if(StringFind(name, InpIndicatorPrefix) != 0) continue;

         if(name == g_indNameSeen && g_indHandle != INVALID_HANDLE)
            return g_indHandle;

         int h = ChartIndicatorGet(0, w, name);
         if(h != INVALID_HANDLE)
           {
            if(g_indHandle != INVALID_HANDLE && g_indHandle != h) IndicatorRelease(g_indHandle);
            g_indNameSeen = name;
            return h;
           }
        }
     }
   return INVALID_HANDLE;
  }

//+------------------------------------------------------------------+
//| ★2026-07-13追加: 長期足の方向を読む(buf15=BufLongState。1=上昇/-1=下降/0=グレー) |
//+------------------------------------------------------------------+
int ReadLongDirection()
  {
   if(g_indHandle == INVALID_HANDLE) return 0;
   double buf[];
   if(CopyBuffer(g_indHandle, 15, 1, 1, buf) <= 0) return 0;   // 確定足(shift=1)を使う
   return (int)MathRound(buf[0]);
  }

//--- ★2026-07-07追加: DokaKotsu_US_Calendar.mq5が書き出す当日の経済指標ファイル(共通)
#define CAL_FILE "DokaKotsu_Calendar_Today.txt"
#define CAL_MAXROWS 6   // パネルに表示する最大件数(多すぎて縦に伸びすぎないよう上限)

//+------------------------------------------------------------------+
//| サーバー時間→JSTのオフセット秒(DokaKotsu_US_Calendar.mq5と同じ考え方) |
//+------------------------------------------------------------------+
int ServerToJstShiftDKD()
  {
   int g = (int)(TimeTradeServer() - TimeGMT());
   g = (int)MathRound((double)g / 3600.0) * 3600;
   return 9 * 3600 - g;
  }

//+------------------------------------------------------------------+
//| ★2026-07-07追加: DokaKotsu_US_Calendar.mq5が書き出したテキストを読み、  |
//| 「今日」の分だけラベル・JST時刻を配列で返す(件数を返り値に)              |
//+------------------------------------------------------------------+
int ReadTodayEconEvents(string &labels[], string &hhmms[])
  {
   ArrayResize(labels, 0);
   ArrayResize(hhmms,  0);

   int h = FileOpen(CAL_FILE, FILE_READ|FILE_TXT|FILE_UNICODE|FILE_COMMON);
   if(h == INVALID_HANDLE)
      return 0;

   datetime jstNow = TimeTradeServer() + ServerToJstShiftDKD();
   if(jstNow <= 0) jstNow = TimeCurrent() + ServerToJstShiftDKD();
   string todayTag = TimeToString(jstNow, TIME_DATE);   // "2026.07.07" 形式(MQL5既定)

   bool dateOk = false;
   int  n = 0;
   while(!FileIsEnding(h))
     {
      string line = FileReadString(h);
      if(line == "")
         continue;
      if(StringFind(line, "DATE=") == 0)
        {
         dateOk = (StringSubstr(line, 5) == todayTag);
         continue;
        }
      string parts[];
      int cnt = StringSplit(line, '|', parts);
      if(cnt >= 4 && parts[0] == "EVENT" && dateOk && n < CAL_MAXROWS)
        {
         ArrayResize(labels, n + 1);
         ArrayResize(hhmms,  n + 1);
         labels[n] = parts[2];
         hhmms[n]  = parts[3];
         n++;
        }
     }
   FileClose(h);
   return n;
  }


//+------------------------------------------------------------------+
//| オブジェクト生成ヘルパー                                          |
//+------------------------------------------------------------------+
void CreateRectLabel(string name,int x,int y,int w,int h,color bg,color border,int zorder=1)
  {
   string full=PFX+name;
   if(ObjectFind(0,full)<0) ObjectCreate(0,full,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,full,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,full,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,full,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,full,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,full,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,full,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,full,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,full,OBJPROP_COLOR,border);
   ObjectSetInteger(0,full,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,full,OBJPROP_BACK,false);
   ObjectSetInteger(0,full,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,full,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,full,OBJPROP_ZORDER,1000+zorder);
  }

void CreateLabelText(string name,int x,int y,string text,color clr,int fontsize=8,string font="Arial",ENUM_ANCHOR_POINT anchor=ANCHOR_LEFT_UPPER)
  {
   string full=PFX+name;
   if(ObjectFind(0,full)<0) ObjectCreate(0,full,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,full,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,full,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,full,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,full,OBJPROP_ANCHOR,anchor);
   ObjectSetString(0,full,OBJPROP_TEXT,text);
   ObjectSetString(0,full,OBJPROP_FONT,font);
   ObjectSetInteger(0,full,OBJPROP_FONTSIZE,fontsize);
   ObjectSetInteger(0,full,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,full,OBJPROP_BACK,false);
   ObjectSetInteger(0,full,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,full,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,full,OBJPROP_ZORDER,1002);
  }

void CreateButtonObj(string name,int x,int y,int w,int h,string text,color bg,color txt,color border)
  {
   string full=PFX+name;
   if(ObjectFind(0,full)<0) ObjectCreate(0,full,OBJ_BUTTON,0,0,0);
   ObjectSetInteger(0,full,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,full,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,full,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,full,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,full,OBJPROP_YSIZE,h);
   ObjectSetString(0,full,OBJPROP_TEXT,text);
   ObjectSetInteger(0,full,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,full,OBJPROP_COLOR,txt);
   ObjectSetInteger(0,full,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,full,OBJPROP_FONTSIZE,7);
   ObjectSetInteger(0,full,OBJPROP_BACK,false);
   ObjectSetInteger(0,full,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,full,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,full,OBJPROP_ZORDER,1003);
   ObjectSetInteger(0,full,OBJPROP_STATE,false);
  }

//+------------------------------------------------------------------+
//| パネル構築（固定サンプル値・機能なし）                            |
//+------------------------------------------------------------------+
void CreatePanel()
  {
   int x=InpPanelX;
   int y=InpPanelY;
   int w=InpPanelWidth;
   int pad=14;
   int innerW=w-pad*2;
   int rightEdge=x+w-pad;   // 内側の右端（ここより右にはみ出させない）
   double sc=InpPanelHeightPct/100.0;
   if(sc<0.5) sc=0.5;

   // 背景（サイズは最後に確定させる）
   CreateRectLabel("bg",x,y,w,900,COL_BG,COL_BORDER,0);

   int curY=y+(int)(18*sc);

   // タイトル + バッジ（バッジは右揃え）
   CreateLabelText("title",x+pad,curY,"DokaKotsu — XAUUSD",COL_TEXT,9);
   CreateLabelText("badge",rightEdge,curY+1,"● EA稼働中",COL_GREEN,7,"Arial",ANCHOR_RIGHT_UPPER);
   curY+=(int)(38*sc);

   // ロット / TOTAL pips（TOTALラベルと値はどちらも右揃えで重ならないよう間隔を確保）
   int lotboxH=(int)(28*sc);
   CreateRectLabel("lotbox",x+pad,curY,innerW,lotboxH,COL_CELL,COL_BORDER);
   CreateLabelText("lot",x+pad+8,curY+(int)(8*sc),"0.1 Lot",COL_TEXT,8);
   CreateLabelText("totallbl",rightEdge-72,curY+(int)(9*sc),"TOTAL",COL_GRAY2,7,"Arial",ANCHOR_RIGHT_UPPER);
   CreateLabelText("totalval",rightEdge-8,curY+(int)(7*sc),"+345 pips",COL_BLUE,8,"Arial",ANCHOR_RIGHT_UPPER);
   curY+=lotboxH+(int)(24*sc);

   // 上位足の方向（★2026-07-13変更: 固定サンプル→本体インジのbuf15(長期足状態)を実際に読む）
   CreateLabelText("dirlbl",x+pad,curY,"上位足の方向と日次レンジ",COL_GRAY,7);
   curY+=(int)(20*sc);
   int dirboxH=(int)(32*sc);
   CreateRectLabel("dirbox",x+pad,curY,innerW,dirboxH,COL_CELL,COL_BORDER);
     {
      int longDir = ReadLongDirection();   // 1=上昇/-1=下降/0=グレー
      string arrow, txt; color col;
      if(longDir==1)       { arrow="↑"; txt="上方向"; col=COL_LIME; }
      else if(longDir==-1) { arrow="↓"; txt="下方向"; col=COL_MAGENTA; }
      else                 { arrow="→"; txt=" レンジ"; col=COL_GRAY; }
      CreateLabelText("dirarrow",x+pad+8,curY+(int)(5*sc),arrow,col,14);
      CreateLabelText("dirtext",x+pad+32,curY+(int)(9*sc),txt,col,9);
      // ★2026-07-13追加: DR(日次レンジ)を実際に読み、大きさに応じて★の数を1〜3に変える
      double dayHigh = iHigh(_Symbol, PERIOD_D1, 0);
      double dayLow  = iLow(_Symbol, PERIOD_D1, 0);
      int drPips = (int)MathRound((dayHigh - dayLow) / _Point / 10.0);   // Dashboard共通のpips換算(point*10)
      string stars = (drPips < InpDrSmall) ? "★" : (drPips < InpDrLarge) ? "★★" : "★★★";
      // ★2026-07-13(2回目)変更: 全決済ボタンを削除し2部屋構成に。左=上方向(既存,左詰め)/右=★★★DR628のように右詰め
      CreateLabelText("dirstars",rightEdge,curY+(int)(10*sc),stars+"DR"+IntegerToString(drPips),col,10,"Arial",ANCHOR_RIGHT_UPPER);
     }
   ObjectDelete(0,PFX+"closeall");   // ★2026-07-13(2回目): 全決済ボタンを撤去(過去に作られた分も消す)
   curY+=dirboxH+(int)(24*sc);

   // ボラティリティ（★2026-07-13変更: 固定サンプル→ATRを読み、添付HTMLと同じサイン波ノイズで
   //   滑らかに波打たせる。3段階: 小さい=グレー/通常=黄色/荒れ狂う=赤）
   CreateLabelText("wavelbl",x+pad,curY,"ボラティリティ",COL_GRAY,7);
   curY+=(int)(20*sc);
   int waveboxH=(int)(36*sc);
   CreateRectLabel("wavebox",x+pad,curY,innerW,waveboxH,COL_CELL,COL_BORDER);
     {
      // --- ATR読み取り→pips換算(XAUUSD 2桁建値・point*10慣習。値がおかしい場合はここを調整) ---
      double atrPips = 0.0;
      if(g_atrHandle != INVALID_HANDLE)
        {
         double atrBuf[];
         if(CopyBuffer(g_atrHandle, 0, 1, 1, atrBuf) > 0)
            atrPips = atrBuf[0] / _Point / 10.0;
        }
      string mode; color baseCol; double amp, base;
      if(atrPips < InpAtrLow)        { mode="grey";   baseCol=COL_GRAY2;  amp=0.16; base=0.08; }
      else if(atrPips < InpAtrMid)   { mode="yellow"; baseCol=COL_YELLOW; amp=0.38; base=0.18; }
      else if(atrPips < InpAtrHigh)  { mode="orange"; baseCol=COL_ORANGE; amp=0.60; base=0.30; }
      else                           { mode="red";    baseCol=COL_RED;   amp=0.90; base=0.48; }

      int barCount=16;
      int barAreaW=innerW-8;
      int barW=barAreaW/barCount;
      double t=(double)GetTickCount()/350.0;   // ★添付HTMLのanimateWave()と同じ考え方(sin合成でゆらぎ)
      for(int i=0;i<barCount;i++)
        {
         double noise = MathSin(t+i*0.55)*0.5 + MathSin(t*1.3+i*0.3)*0.3 + MathSin(t*0.7+i*0.9)*0.2;
         double hFrac = base + amp*MathMax(0.0,(noise+1.0)/2.0);
         if(hFrac>1.0) hFrac=1.0;
         if(hFrac<0.04) hFrac=0.04;
         int bh=(int)MathMax(4,(waveboxH-4)*hFrac);
         int bx=x+pad+4+i*barW;
         int by=curY+(waveboxH-bh)-2;
         CreateRectLabel("wavebar"+IntegerToString(i),bx,by,barW-1,bh,baseCol,baseCol,1);
        }
      curY+=waveboxH+(int)(14*sc);
      string stateTxt = (mode=="grey") ? "LOW" : (mode=="yellow") ? "MID" : (mode=="orange") ? "HIGH" : " "; // ★2026-07-14変更: DANGERは警告文と重なるため削除(スペースに)
      CreateLabelText("wavestate",x+pad,curY,stateTxt,baseCol,8);
      if(mode=="grey")
         CreateLabelText("wavewarn",rightEdge,curY+1,"⚠ ボラ不足 — エントリー非推奨",COL_ORANGE,7,"Arial",ANCHOR_RIGHT_UPPER);
      else if(mode=="orange")
         CreateLabelText("wavewarn",rightEdge,curY+1,"⚠ 高ボラ — ロット調整を検討",COL_ORANGE,7,"Arial",ANCHOR_RIGHT_UPPER);
      else if(mode=="red")
         CreateLabelText("wavewarn",rightEdge,curY+1,"⚠ ボラ異常 — ロットを下げるか中止してください",COL_RED,7,"Arial",ANCHOR_RIGHT_UPPER);
      else
         CreateLabelText("wavewarn",rightEdge,curY+1," ",COL_ORANGE,7,"Arial",ANCHOR_RIGHT_UPPER);
     }
   curY+=(int)(32*sc);

   // エントリータイミング（★2026-07-13(3回目)変更: モニター「今日」タブの箱を丸ごと移植。
   //   ロジック未実装のため、InpEntryDemoStateで見た目だけ状態を切り替えられるようにしてある。
   CreateLabelText("rblbl",x+pad,curY,"エントリータイミング",COL_GRAY,7);
   curY+=(int)(18*sc);

   string statusTxt; color statusCol; double demoProgress;
   bool showMsgIn=false, showMsgGet=false, showMsgLose=false;
   string streakTxt="", pipsTxt=""; color pipsCol=COL_GREEN;

   if(InpUseRealLogic)
     {
      // ★2026-07-14追加: モニターと同じ5ステップ判定を実データで反映
      int rbLeft; string rbText, rbPct; color rbColor;
      ReadEntryTimingState(rbLeft, rbText, rbColor, rbPct);
      statusTxt   = rbText;
      statusCol   = rbColor;
      demoProgress= rbLeft/100.0;
      showMsgIn   = (rbText=="IN！");

      // ★2026-07-14追加: EA(DK_UpdateGameStats)が書くGVから、直近決済のGET/LOSEと連勝/pipsを反映
      bool gGet, gLose;
      ReadGameStats(gGet, gLose, streakTxt, pipsTxt, pipsCol);
      if(!showMsgIn) { showMsgGet=gGet; showMsgLose=gLose; }   // 保有中(IN)表示を優先し、GET/LOSEと同時には出さない
     }
   else
     {
      switch(InpEntryDemoState)
        {
         case DEMO_READY: statusTxt="Ready";   statusCol=C'74,175,80';  demoProgress=0.60; break;
         case DEMO_IN:    statusTxt="IN";      statusCol=C'66,165,245'; demoProgress=0.95; showMsgIn=true; streakTxt="🔥3連勝"; break;
         case DEMO_GET:   statusTxt="NOTRADE"; statusCol=C'245,197,24'; demoProgress=0.08; showMsgGet=true;  streakTxt="🔥3連勝"; pipsTxt="WIN +55.2p"; pipsCol=COL_GREEN; break;
         case DEMO_LOSE:  statusTxt="NOTRADE"; statusCol=C'245,197,24'; demoProgress=0.08; showMsgLose=true; streakTxt="";        pipsTxt="LOSE -32.1p"; pipsCol=COL_RED;  break;
         default:         statusTxt="NOTRADE"; statusCol=C'245,197,24'; demoProgress=0.08; break; // DEMO_NOTRADE
        }
     }

   // ① 状態テキスト(18pt、大きく)
   CreateLabelText("entrystatus",x+pad,curY,statusTxt,statusCol,12);
   curY+=(int)(22*sc);

   // ② グラデーションバー本体(Canvas、シマー付き)
   int rbarH=(int)(16*sc);
     {
      int barX=x+pad;
      int barW=innerW;
      int barH=rbarH;

      if(!g_rbCanvasReady || barW!=g_rbCanvasW || barH!=g_rbCanvasH)
        {
         if(g_rbCanvasReady) RbCanvas.Destroy();
         if(RbCanvas.CreateBitmapLabel(0,0,RB_OBJ,barX,curY,barW,barH,COLOR_FORMAT_ARGB_NORMALIZE))
           {
            ObjectSetInteger(0,RB_OBJ,OBJPROP_CORNER,CORNER_LEFT_UPPER);
            ObjectSetInteger(0,RB_OBJ,OBJPROP_BACK,false);
            ObjectSetInteger(0,RB_OBJ,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,RB_OBJ,OBJPROP_HIDDEN,true);
            ObjectSetInteger(0,RB_OBJ,OBJPROP_ZORDER,1002);
            g_rbCanvasReady=true; g_rbCanvasW=barW; g_rbCanvasH=barH;
           }
         else
            Print("DokaKotsu_Dashboard: レインボーバーCanvas作成失敗: ",GetLastError());
        }
      else
        {
         ObjectSetInteger(0,RB_OBJ,OBJPROP_XDISTANCE,barX);
         ObjectSetInteger(0,RB_OBJ,OBJPROP_YDISTANCE,curY);
        }
      if(g_rbCanvasReady) DrawRainbowBarCanvas(barW,barH,demoProgress);
     }
   curY+=rbarH+(int)(4*sc);

   // ③ バー下の3ラベル(NOTRADE/Ready/IN)
   CreateLabelText("rblabel_l",x+pad,curY,"NOTRADE",C'245,197,24',7);
   CreateLabelText("rblabel_m",x+pad+innerW/2,curY,"Ready",C'74,175,80',7,"Arial",ANCHOR_UPPER);
   CreateLabelText("rblabel_r",rightEdge,curY,"IN",C'66,165,245',7,"Arial",ANCHOR_RIGHT_UPPER);
   curY+=(int)(14*sc);

   // ④ 進捗%テキスト(中央、小さいグレー)
   CreateLabelText("entrypct",x+pad+innerW/2,curY," ",COL_GRAY2,8,"Arial",ANCHOR_UPPER);
   curY+=(int)(12*sc);

   // ⑤ メッセージ箱(IN/GET/LOSEのいずれか1つだけ、無ければ非表示=高さも詰める)
   if(showMsgIn || showMsgGet || showMsgLose)
     {
      int msgH=(int)(18*sc);
      color msgBg, msgBorder, msgCol; string msgTxt;
      if(showMsgIn)        { msgBg=C'7,30,53';  msgBorder=C'26,74,122'; msgCol=C'66,165,245'; msgTxt="🔔 INしました（保有中）"; }
      else if(showMsgGet)  { msgBg=C'7,30,53';  msgBorder=C'26,74,122'; msgCol=C'79,195,247'; msgTxt="✔ GETしました 🎉"; }
      else                 { msgBg=C'58,26,26'; msgBorder=C'106,26,26'; msgCol=C'239,83,80';  msgTxt="次がんばりましょう 💪"; }
      CreateRectLabel("entrymsgbox",x+pad,curY,innerW,msgH,msgBg,msgBorder,1);
      CreateLabelText("entrymsgtxt",x+pad+6,curY+msgH/2-6,msgTxt,msgCol,8);
      curY+=msgH+(int)(6*sc);
     }
   else
     {
      ObjectDelete(0,PFX+"entrymsgbox");
      ObjectDelete(0,PFX+"entrymsgtxt");
     }

   // ⑥ 連勝／獲得pips行
     {
      int rowH=(int)(16*sc);
      CreateLabelText("gamestreak",x+pad,curY+rowH/2-6,streakTxt,C'255,215,0',9);
      CreateLabelText("gamepips",rightEdge,curY+rowH/2-6,pipsTxt,pipsCol,10,"Arial",ANCHOR_RIGHT_UPPER);
      curY+=rowH+(int)(6*sc);
     }

   // ⑦ 凡例(小さいグレー、3行)
     {
      CreateRectLabel("legendline",x+pad,curY,innerW,1,COL_BORDER,COL_BORDER,1);
      curY+=(int)(4*sc);
      CreateLabelText("legendtxt",x+pad,curY," ",COL_GRAY2,7);   // ★2026-07-13(5回目)変更: 空文字だと既定文字"Label"が出るためスペース1文字に変更
      curY+=(int)(12*sc);
     }
   curY+=(int)(16*sc);

   // 決済目安（★2026-07-13変更: セグメント10分割→スクイーズ収束度と同じ2色バー+針のデザインに差し替え。
   //   ロジックは後日いただく予定のため、今回は針位置を固定値(0.22)のまま仮表示。
   CreateLabelText("ailbl",x+pad,curY,"決済目安",COL_GRAY,7);
   curY+=(int)(20*sc);
   int segH=(int)(9*sc);
     {
      int barX=x+pad;
      int barW=innerW;
      double convVal=0.22;      // ★仮値。ロジック未実装(後日差し替え予定)
      double convThresh=0.30;   // 閾値(30%位置に区切り線)
      double needlePos = convVal/1.0; if(needlePos>1.0) needlePos=1.0; if(needlePos<0.0) needlePos=0.0;
      int splitX=barX+(int)(barW*convThresh);
      CreateRectLabel("sqzbg_l",barX,curY,splitX-barX,segH,C'90,45,45',C'90,45,45',1);              // 圧縮ゾーン(暗い赤)
      CreateRectLabel("sqzbg_r",splitX,curY,barX+barW-splitX,segH,C'45,90,50',C'45,90,50',1);        // ボラありゾーン(暗い緑)
      CreateRectLabel("sqzsplit",splitX,curY,1,segH,C'204,204,204',C'204,204,204',2);                // 閾値の区切り線
      int needleX=barX+(int)(barW*needlePos);
      CreateRectLabel("sqzneedle",needleX-1,curY,3,segH,clrWhite,clrWhite,3);                        // 現在値の針
      CreateLabelText("sqzlbl_l",x+pad,curY+segH+2,"圧縮",C'200,122,122',7);
      CreateLabelText("sqzlbl_m",x+pad+innerW/2,curY+segH+2,"閾0.30",COL_GRAY,7,"Arial",ANCHOR_UPPER);
      CreateLabelText("sqzlbl_r",rightEdge,curY+segH+2,"ボラあり",C'106,176,106',7,"Arial",ANCHOR_RIGHT_UPPER);
     }
   curY+=segH+(int)(24*sc);

   // 経済指標見出し（★2026-07-07変更: 「本日の趣味レーション」の誤字修正＋日付表示）
   int accH=(int)(20*sc);
   CreateRectLabel("accbox",x+pad,curY,innerW,accH,COL_BG,COL_BORDER,1);
   {
      datetime jstNow2 = TimeTradeServer() + ServerToJstShiftDKD();
      if(jstNow2 <= 0) jstNow2 = TimeCurrent() + ServerToJstShiftDKD();
      string dateStr = TimeToString(jstNow2, TIME_DATE);
      StringReplace(dateStr, ".", "/");
      CreateLabelText("acclbl",x+pad+8,curY+accH/2-6,"▲ 本日の経済指標  "+dateStr,COL_GRAY2,7);
   }
   curY+=accH+(int)(12*sc);

   // ★2026-07-07変更: GDP/PCIの固定サンプル2行→テキストファイルから読んだ当日分を可変件数で表示。
   //   フォントサイズはご要望により従来(7)の50%増(11)に拡大。
   int calH=(int)(18*sc);
   int calFont=11;       // 指標あり時のフォントサイズ(従来通り)
   int calEmptyFont=9;   // ★2026-07-13変更: 「本日は該当指標なし」はこちらをやや小さく(11→9)
   string evLabels[], evHhmm[];
   int evCount = ReadTodayEconEvents(evLabels, evHhmm);

   if(evCount == 0)
     {
      CreateRectLabel("calempty",x+pad,curY,innerW,calH,COL_CELL,COL_CELL,1);
      CreateLabelText("calemptytxt",x+pad+6,curY+calH/2-7,"本日は該当指標なし",COL_GRAY2,calEmptyFont);
      curY+=calH+(int)(14*sc);
     }
   else
     {
      for(int i=0;i<evCount;i++)
        {
         string rowName="calrow"+IntegerToString(i);
         string aName  ="cal"+IntegerToString(i)+"a";
         string bName  ="cal"+IntegerToString(i)+"b";
         CreateRectLabel(rowName,x+pad,curY,innerW,calH,COL_CELL,COL_CELL,1);
         // ★2026-07-13変更: 指標がある時はフォントカラーを白に(従来はグレー固定だった)
         CreateLabelText(aName,x+pad+6,curY+calH/2-7,evLabels[i],COL_WHITE,calFont);
         CreateLabelText(bName,rightEdge-4,curY+calH/2-7,evHhmm[i],COL_GRAY2,calFont,"Arial",ANCHOR_RIGHT_UPPER);
         curY+=calH+(int)(8*sc);
        }
      curY+=(int)(6*sc);   // 最終行の下に少し余白
     }

   //--- ★2026-07-07追加: 前回より件数が減った場合、余った行オブジェクトが
   //    消えずに前日分の文字列のまま残ってしまうのを防ぐ(掃除)
   for(int i=evCount; i<CAL_MAXROWS; i++)
     {
      ObjectDelete(0, PFX+"calrow"+IntegerToString(i));
      ObjectDelete(0, PFX+"cal"+IntegerToString(i)+"a");
      ObjectDelete(0, PFX+"cal"+IntegerToString(i)+"b");
     }
   if(evCount > 0)   // 該当指標が出てきた日は、以前の「該当指標なし」表示を消す
     {
      ObjectDelete(0, PFX+"calempty");
      ObjectDelete(0, PFX+"calemptytxt");
     }

   // 背景サイズを実際のコンテンツ高さに合わせて確定
   int panelH=curY-y+10;
   ObjectSetInteger(0,PFX+"bg",OBJPROP_YSIZE,panelH);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| インジケーター初期化                                              |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME,"DokaKotsu_Dashboard");
   // 価格チャート（ローソク足・MA等の重ね書きインジケーター）がオブジェクトより
   // 前面に来ないようにする＝パネルが常に最前面に表示される
   ChartSetInteger(0,CHART_FOREGROUND,false);
   g_indHandle = FindDokaKotsuHandle();   // ★2026-07-13追加: 本体インジ自動検出
   g_atrHandle = iATR(_Symbol, _Period, InpAtrPeriod);   // ★2026-07-13追加: ボラティリティ用ATR
   CreatePanel();
   EventSetMillisecondTimer(150);   // ★2026-07-13変更: 500→150。波形アニメーションを滑らかにするため
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| タイマー：他インジケーターが後から前面に出てきた場合に            |
//| パネルを再度最前面へ引き上げる                                    |
//+------------------------------------------------------------------+
void OnTimer()
  {
   int found = FindDokaKotsuHandle();   // ★2026-07-13追加: 毎回検出し直す(バージョン差し替えに追従)
   if(found != INVALID_HANDLE) g_indHandle = found;
   CreatePanel();
  }

//+------------------------------------------------------------------+
//| 終了処理（オブジェクト全削除）                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_indHandle != INVALID_HANDLE) IndicatorRelease(g_indHandle);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_rbCanvasReady) RbCanvas.Destroy();
   ObjectsDeleteAll(0,PFX);
   ObjectDelete(0,RB_OBJ);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| OnCalculate（描画のみのため実処理なし）                           |
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
   return(rates_total);
  }
//+------------------------------------------------------------------+
