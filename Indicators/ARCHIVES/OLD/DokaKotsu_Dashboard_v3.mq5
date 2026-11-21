//+------------------------------------------------------------------+
//|                                        DokaKotsu_Dashboard.mq5    |
//|  dokakotu_dashboard_v8_4.html のデザインをMT5チャート上に         |
//|  再現するパネル（第一段階：機能なし・表示のみ／固定サンプル値）   |
//|                                                                    |
//|  ■ 修正日: 2026-07-17(3回目)  修正内容                            |
//|    ボラティリティ閾値の単位を修正: 画面表示は「Vol +22%」のように %|
//|    なのに、プロパティのinput値は比率(0.22)のままで単位がズレて     |
//|    調整しづらかったため、InpVolScoreLow/Mid/HighをPct付きに変更し、|
//|    %表示とそのまま一致する数値で入力できるようにした。田島さんの   |
//|    実測(22%=体感イエロー)を踏まえた提案値を初期値として採用:      |
//|    グレー境界-40%(旧-20)/イエロー境界30%(旧0)/レッド境界120%(旧50)。|
//|    以後の微調整は田島さんご自身で実測しながら行う想定。            |
//|                                                                  |
//|  ■ 修正日: 2026-07-17  修正内容(ボラティリティをVolScore基準へ置換)|
//|    ADX生値(本体インジbuf60)基準から、田島さんご提示のVolScore式へ |
//|    置き換え: CurrentVol=EMA(High-Low,5)、VolScore=(CurrentVol-     |
//|    EMA(CurrentVol,20))/EMA(CurrentVol,20)。「今の値幅」が「直近   |
//|    20本の平均的な値幅」から何%乖離しているかを表す相対指標(0=普段 |
//|    通り/正=拡大中/負=縮小中)。ComputeVolScore()新設(本体インジに |
//|    依存せず自前でHigh/Lowから2段EMAを計算)。InpAdxVolLow/Mid/High |
//|    をInpVolScoreLow(-0.20)/Mid(0.00)/High(0.50)に置き換え。見出し |
//|    右横の表示も「ADX x.x」から「Vol +xx%」に変更。閾値は初期値で   |
//|    あり、実測して調整が必要な想定(ADXの時と同様)。                |
//|                                                                  |
//|  ■ 修正日: 2026-07-16  修正内容                                  |
//|    ①ボラティリティの閾値初期値を変更: グレー境界29(旧22)/         |
//|      イエロー境界36(旧40)。                                      |
//|    ②「決済目安」メーターに実ロジックを実装(案②採用)。0%=エント   |
//|      リー直後/InpMeterStagedPct%(既定65)=含み益がInpStagedTrig   |
//|      PipsMirror(既定100、EA_15のInpStagedTrigPipsと同じ値にする   |
//|      必要あり)に到達=段階決済モードへ切替/100%=実際の決済。       |
//|      節目到達後(トレーリング監視中)はそれ以上の進捗を正確には      |
//|      予測できないため、節目〜100%の中間で固定表示する(誇張しない  |
//|      設計)。保有していない間は、直近決済が新しければ100%のまま    |
//|      (次のエントリーまで、GET/LOSEメッセージと同じGVで判定)、     |
//|      無ければ0%。GetOpenPositionProfitPips()新設。                |
//|                                                                  |
//|  ■ 修正日: 2026-07-15(8回目)  修正内容(indicator/EA 14→15対応確認) |
//|    indicator/EAを14→15へバージョンアップしたのに伴う確認。          |
//|    本ファイルのFindDokaKotsuHandle()は接頭辞"DokaKotsu_indicator_" |
//|    でチャート上を走査する設計(InpIndicatorPrefix)のため、バージョン|
//|    番号を問わず自動検出される。コード変更は不要(念のため確認のみ)。|
//|                                                                  |
//|  ■ 修正日: 2026-07-15(7回目)  修正内容                            |
//|    ①「稼働中」→「EA稼働中」に文言変更。約1.6秒周期でゆっくり      |
//|      点滅するように変更(GetTickCount()の位相だけを見て背景色に    |
//|      落とす方式。専用タイマーは追加せず既存の1秒更新のまま=負荷    |
//|      増加なし)。取引停止中(赤)側は点滅させていない。               |
//|    ②「決済目安」の3ラベルを「圧縮/閾0.30/ボラあり」から            |
//|      「エントリー/50%/決済」に変更。                              |
//|    ③「本日の経済指標」見出しのフォントサイズを6→7に変更し、        |
//|      「決済目安」見出しと同じサイズに統一。                        |
//|                                                                  |
//|  ■ 修正日: 2026-07-15(6回目)  修正内容                            |
//|    ①再生ボタンの「▶」が文字化けする(環境依存でtofu表示になる)ため |
//|      ASCIIの">"に変更。フォントサイズも13へ調整。                 |
//|    ②(ボタン中央揃え)MQL5のOBJ_BUTTONはテキストを自動で中央寄せ    |
//|      する仕様のため、個別の水平/垂直揃えプロパティは存在しない。   |
//|      ①の文字化け解消とフォント調整で見た目の改善を図った。         |
//|    ③「▶稼働中」表記は前回(5回目)修正で既に「稼働中」化済み        |
//|      (今回変更なし、念のため確認)。                               |
//|    ②(アニメーション停止・負荷対策)ボラティリティバーの波形と       |
//|      レインボーバーのシマー演出、両方ともGetTickCount()による      |
//|      常時アニメーションを廃止し、固定値(t=0.0/shimmerT=0.5)による |
//|      静止表示に変更。あわせて、アニメーションを滑らかにするためだけに|
//|      150msへ短縮していたタイマー間隔を1000msへ戻し、負荷を軽減した。|
//|    ③「WAIT Ready IN」行と「決済目安」の間が詰まっていたため        |
//|      空白1行分のスペースを追加。                                  |
//|    ④メッセージ箱(GET/LOSE/IN)のテキストをANCHOR_CENTERで箱の       |
//|      水平・垂直中央に配置するよう変更。                            |
//|    ⑤ボラティリティのグレー境界値(InpAdxVolLow)を20→22に変更。      |
//|    ⑥「DR」の左の★の数の閾値を変更: 400以下=★/1000以下=★★/       |
//|      1000超=★★★(旧150/300から変更、境界も<から<=に修正)。       |
//|                                                                  |
//|  ■ 修正日: 2026-07-15(5回目)  修正内容                            |
//|    ①■/▶ボタンを1.5倍に拡大(20px→30px)。CreateButtonObjにフォント |
//|      サイズ引数を追加し、拡大しても▶/■の記号が小さいままになら   |
//|      ないよう文字も一緒に大きくした(11pt)。収まるようlotboxHも    |
//|      28→38に拡大。                                                |
//|    ②「▶稼働中」「■取引停止中」の先頭アイコンを削除し「稼働中」   |
//|      「取引停止中」に変更。                                       |
//|    ②(レイヤー)CreateRectLabelにOBJPROP_FILL=trueを追加。MT5では   |
//|      環境によりOBJPROP_BGCOLORだけでは実際に塗りつぶされず、       |
//|      背後のチャートオブジェクトが透けて見える既知の不具合がある   |
//|      ため、明示的にFILLを有効化する対策を追加(MQL5公式フォーラム  |
//|      の複数の報告に基づく)。                                      |
//|    ③「INしました」等のテキストを30%縮小(フォント14→10)。          |
//|    ④GET/LOSEメッセージの自動消去(InpMsgFreshSec、旧180秒)を廃止。 |
//|      次のエントリー(IN)が発生するまでずっと表示し続けるよう変更。 |
//|    ⑤ボラティリティの閾値初期値を変更: グレー境界20(旧1.6)/        |
//|      イエロー境界40(旧2.0)/レッド境界80(旧50)。                   |
//|                                                                  |
//|  ■ 修正日: 2026-07-15(4回目)  修正内容                            |
//|    ①「0.1 Lot」表示を■(取引停止)/▶(復活)ボタンに置き換え。        |
//|      クリックするとGlobalVariable DK_DASH_TRADEPAUSE_<magic>へ     |
//|      1(停止)/0(復活)を書き込む(OnChartEvent新設)。EA_14側に       |
//|      IsDashboardPaused()を追加し、新規エントリーの可否判定に       |
//|      組み込んだ(対で修正。保有中ポジションの強制決済はしない)。    |
//|    ②ボラティリティ見出しの右横に現在のADX実測値(buf60)を表示      |
//|      (「ADX 1.6」のように)。閾値調整の目安に使える。               |
//|    ③「INしました」等のメッセージ箱の高さ・フォントを約3倍に拡大   |
//|      (18px→54px、フォント8→14)。                                  |
//|    ④「INしました」ブロックと「決済目安」ブロックの表示順を入替    |
//|      (決済目安を先に表示するよう変更)。                            |
//|    ⑤ボラティリティのライム/レッド境界値(InpAdxVolHigh)の初期値を   |
//|      3.5→50に変更(実測のADX値に合わせて調整)。                    |
//|                                                                  |
//|  ■ 修正日: 2026-07-15(3回目)  修正内容                            |
//|    ①「Label」誤表示の真因を修正: entrypct削除だけでは直らず、      |
//|      実際の原因は⑥連勝／獲得pips行(gamestreak/gamepips)が         |
//|      streakTxt/pipsTxt空文字のまま常時描画されていたことだった。   |
//|      空の時はテキストを背景色(COL_BG)にして見えなくする安全策を   |
//|      追加。同じ理由でwavewarn(警告なし時)・legendtxtも背景色に統一。|
//|    ②レイヤー問題再修正: OBJPROP_ZORDERを9000台→1億台へさらに      |
//|      引き上げ。indicator_14のSQ/TR/SPラベルはOBJ_TEXT(価格面     |
//|      アンカー)、パネル側はOBJ_LABEL(画面コーナーアンカー)で        |
//|      本来レイヤーが異なるはずだが、実機で解消しなかったため        |
//|      z-orderの数値をさらに大きく確保する対策で対応。               |
//|    ③「本日の経済指標」の各イベント行(重要発言PPI等)のフォント     |
//|      サイズを11→8に縮小。                                        |
//|    ④右上バッジの文言を「US_Calendar _連携中」「US_Calendar_未連携」|
//|      に変更(前回の「_US_Calendar連携中」から表記修正)。            |
//|                                                                  |
//|  ■ 修正日: 2026-07-15(2回目)  修正内容                            |
//|    ①「本日の経済指標」見出しのフォントサイズを7→6に縮小。         |
//|    ②パネル全オブジェクトのOBJPROP_ZORDERを1000〜1003台から         |
//|      9000〜9600台へ大幅引き上げ。他インジ(indicator_14が描画する  |
//|      SQ/TR/SPラベル等)の文字がパネルの手前に出てしまう問題への対策。|
//|    ③タイトルを「DokaKotsu — XAUUSD」から「DokaKotsu」に変更(銘柄名 |
//|      を削除)。                                                    |
//|    ④右上バッジを固定「● EA稼働中」から、DokaKotsu_US_Calendarが   |
//|      実際にチャート上に存在するかの実チェックへ変更。存在すれば    |
//|      緑「● _US_Calendar連携中」、無ければ赤「● _US_Calendar_未連携」|
//|      (IsUsCalendarPresent()新設、ChartIndicatorNameで名前接頭辞    |
//|      "DokaKotsu_US_Calendar"を走査)。                             |
//|    ⑤WAIT/Ready/INの下にあった進捗%テキスト行(entrypct)を削除。    |
//|      実データに未接続のまま空白/既定文字"Label"が表示され続ける    |
//|      バグだった。メッセージ箱(GET/LOSE/IN)だけで表現し、非表示時は |
//|      高さも詰まるようにした(元々メッセージ箱側に実装済みの挙動)。  |
//|                                                                  |
//|  ■ 修正日: 2026-07-15  修正内容                                  |
//|    ①GET/LOSEメッセージ箱を実データで動かせるよう実装。EA_14の     |
//|      DK_UpdateGameStats()(2026-07-14追加)が書き出すGV             |
//|      (DK_EA_LASTCLOSE_PIPS/WIN/TIME_<magic>,                     |
//|       DK_EA_WINSTREAK_<magic>)を読み、直近決済がInpMsgFreshSec    |
//|      (既定180)秒以内ならGET(勝ち)/LOSE(負け)を表示する。保有中     |
//|      (IN)の時はそちらを優先。従来はInpUseRealLogic=trueでもこの   |
//|      2つは常に非表示のままだった。                                |
//|    ②ボラティリティ表示をATR(pips)基準からADX基準へ変更。          |
//|      本体インジ(DokaKotsu_indicator_14 Ver14.02)に新設した        |
//|      buf60(BufAdxRaw,ADX生値)を読み、<1.6=グレー(動かず)/         |
//|      <2.0=イエロー/<3.5=ライム/>=3.5=レッドの4段階で表示。         |
//|      InpAtrLow/Mid/High・InpAtrPeriod・g_atrHandleは削除。         |
//|    ③バー下・状態テキストの表示文言「NOTRADE」を全箇所「WAIT」へ   |
//|      変更。                                                       |
//|                                                                  |
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
//|                                                                  |
//|  ■ 修正日: 2026-07-20  修正内容                                  |
//|    「本日の経済指標」見出しの直下に日本の祝日表示を追加。          |
//|    DokaKotsu_US_Calendar.mq5(v5)が書き出すGlobalVariable          |
//|    (DK_CAL_JPHOL_TODAY/ACTIVE/END_<magic>)を読むだけで、          |
//|    このファイル自身は祝日判定ロジックを持たない(絶対ルール1に      |
//|    従い、判定ロジックはDokaKotsu_US_Calendar.mq5に一本化)。        |
//|    本日該当なしの日はオブジェクトごと削除して詰める。              |
//|                                                                  |
//|  ■ 修正日: 2026-07-20(2回目)  修正内容                            |
//|    前回追加した日本祝日専用の赤/オレンジ行を削除。「本日は該当     |
//|    指標なし」等と同じ経済指標の並び(白文字・同じセル)の先頭に      |
//|    差し込む方式に変更。DokaKotsu_US_Calendar.mq5(v6)がCAL_FILEへ   |
//|    追加書き出す"HOLIDAY_JP|名前|時刻表記"行をReadTodayJpHoliday()  |
//|    で読むだけで、判定ロジックはCalendar側に一本化されたまま。       |
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

//+------------------------------------------------------------------+
//| ★2026-07-14追加: モニター(monitor_3.py)の5ステップ判定をそのまま移植。
//|   mc(短期波色)=buf22、ha(平均足)=buf14、isTrend(非スクイーズ)=buf53、
//|   power(ADX)=buf26、convN(収束度)=buf58。
//|   ※stReentry(再入ロック)は現状インジ側にshift付きで読める専用バッファが
//|     無いため、暫定でtrue(常に満たす)固定にしている。要注意。
//+------------------------------------------------------------------+
void ReadEntryTimingState(int &rbLeft, string &rbText, color &rbColor, string &rbPct)
  {
   rbLeft=8; rbText="WAIT"; rbColor=C'200,160,0'; rbPct="";
   if(g_indHandle == INVALID_HANDLE) return;

   double bufMc[], bufHa[], bufTrend[], bufPower[], bufConv[];
   if(CopyBuffer(g_indHandle,22,1,1,bufMc)    <= 0) return;
   if(CopyBuffer(g_indHandle,14,1,1,bufHa)    <= 0) return;
   if(CopyBuffer(g_indHandle,53,1,1,bufTrend) <= 0) return;
   if(CopyBuffer(g_indHandle,26,1,1,bufPower) <= 0) return;
   if(CopyBuffer(g_indHandle,58,1,1,bufConv)  <= 0) return;

   int    mc      = (int)MathRound(bufMc[0]);      // 1=上昇/-1=下降/0=グレー
   int    ha      = (int)MathRound(bufHa[0]);      // 1=上昇/-1=下降
   bool   isTrend = (bufTrend[0] < 0.5);            // buf53: 0=トレンド/1=スクイーズ
   int    power   = (int)MathRound(bufPower[0]);   // 1=ADX上昇/2=ADX下降/0=グレー
   double convN   = bufConv[0];

   bool stDir   = (mc==1 || mc==-1);
   bool stHa    = (mc==1 && ha==1) || (mc==-1 && ha==-1);
   bool stTrend = isTrend;
   bool stPower = (mc==1 && power==1) || (mc==-1 && power==2);
   bool stReentry = true;   // ★暫定固定。再入ロック専用バッファが出来たら差し替える

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
   else if(allReady)          { rbLeft=55;  rbText="WAIT";  rbColor=C'200,160,0';   rbPct="あと一歩"; }
   else if(stDir && stHa && stTrend) { rbLeft=50; rbText="WAIT"; rbColor=C'200,160,0'; rbPct="あと一歩"; }
   else if(stDir)             { rbLeft=25;  rbText="WAIT";  rbColor=C'200,160,0';   rbPct="方向◯"; }
   else                       { rbLeft=8;   rbText="WAIT";  rbColor=C'200,160,0';   rbPct=""; }
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
      double shimmerT = 0.5;   // ★2026-07-15(6回目)変更: GetTickCount()による常時アニメーションを廃止(負荷対策)。固定位置で静止表示
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
//--- ★2026-07-15変更: ボラティリティ判定をATR(pips)からADX生値(本体インジbuf60)基準へ変更
//--- ★2026-07-17変更: ボラティリティ判定をADX基準からVolScore基準(EMA(High-Low,5)の20本平均からの乖離率)へ置き換え
input double InpVolScoreLowPct    = -40.0;  // これ未満=ボラ縮小(グレー・動かず)。%表示(画面の「Vol +xx%」と同じ単位) ★2026-07-17(3回目)変更: -20→-40
input double InpVolScoreMidPct    = 30.0;   // これ未満=イエロー(普段並み)。%表示 ★2026-07-17(3回目)変更: 0→30
input double InpVolScoreHighPct   = 120.0;  // これ未満=ライム。これ以上=レッド。%表示 ★2026-07-17(3回目)変更: 50→120
//--- ★2026-07-16追加: 「決済目安」メーター(0%=エントリー直後/100%=決済)。案②=段階決済モード切替の節目を基準にする
input double InpStagedTrigPipsMirror = 100.0;  // EA_15のInpStagedTrigPipsと同じ値にしてください(段階決済モードへ切り替わる含み益pips)
input double InpMeterStagedPct       = 65.0;   // 上記の節目に到達した時、メーターを何%の位置に置くか

//--- ★2026-07-13追加: DR(日次レンジ)の★段階しきい値(pips、Dashboard共通のpoint*10換算)
input int InpDrSmall = 400;    // これ以下=★ ★2026-07-15(6回目)変更: 150→400
input int InpDrLarge = 1000;   // これ以下=★★。これより大きい=★★★ ★2026-07-15(6回目)変更: 300→1000

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
//| ★2026-07-15追加: DokaKotsu_US_Calendarがチャート上に存在するか判定 |
//+------------------------------------------------------------------+
bool IsUsCalendarPresent()
  {
   int winTotal = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for(int w = 0; w < winTotal; w++)
     {
      int total = ChartIndicatorsTotal(0, w);
      for(int i = 0; i < total; i++)
        {
         string name = ChartIndicatorName(0, w, i);
         if(StringFind(name, "DokaKotsu_US_Calendar") == 0) return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| ★2026-07-16追加: 「決済目安」メーター用。保有中ポジションの含み益 |
//|   をpipsで返す(無ければfalse)。このシンボル・このEAのマジックの   |
//|   ポジションだけを対象にする(既存のpos_state判定と同じ絞り込み)。 |
//+------------------------------------------------------------------+
bool GetOpenPositionProfitPips(double &profitPips)
  {
   profitPips = 0.0;
   for(int k=PositionsTotal()-1; k>=0; k--)
     {
      ulong tk=PositionGetTicket(k);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC)!=InpMagic) continue;
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double pipSize = _Point*10;   // XAUUSD慣習(他のブロックと統一)
      if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
         profitPips = (SymbolInfoDouble(_Symbol,SYMBOL_BID) - entry) / pipSize;
      else
         profitPips = (entry - SymbolInfoDouble(_Symbol,SYMBOL_ASK)) / pipSize;
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//| ★2026-07-17追加: 「ボラティリティ」ゲージをADX基準からVolScore基準へ |
//|   置き換え。田島さんご提示の式をそのまま実装:                     |
//|     CurrentVol = EMA(High-Low, 5)                                 |
//|     VolScore   = (CurrentVol - EMA(CurrentVol, 20)) / EMA(CurrentVol, 20) |
//|   「今の値幅」が「直近20本の平均的な値幅」から何%乖離しているかを  |
//|   返す(0=普段通り/正=拡大中/負=縮小中)。MQL5のiMAはHigh-Lowを     |
//|   直接の対象価格にできないため、値幅配列を作って手計算のEMAを      |
//|   2段階で適用する。                                               |
//+------------------------------------------------------------------+
double ComputeVolScore()
  {
   int need = 80;   // EMA(20)のEMA(5)が収束するのに十分な本数を確保
   double hi[], lo[];
   if(CopyHigh(_Symbol,_Period,0,need,hi) < need) return 0.0;
   if(CopyLow(_Symbol,_Period,0,need,lo)  < need) return 0.0;
   ArraySetAsSeries(hi,false);   // 0=古い→末尾=最新の時系列順に統一(EMAを古い側から積むため)
   ArraySetAsSeries(lo,false);

   double rng[];
   ArrayResize(rng, need);
   for(int i=0;i<need;i++) rng[i] = hi[i]-lo[i];

   double vol5[];
   ArrayResize(vol5, need);
   double k5 = 2.0/(5.0+1.0);
   vol5[0] = rng[0];
   for(int i=1;i<need;i++) vol5[i] = rng[i]*k5 + vol5[i-1]*(1.0-k5);

   double vol20[];
   ArrayResize(vol20, need);
   double k20 = 2.0/(20.0+1.0);
   vol20[0] = vol5[0];
   for(int i=1;i<need;i++) vol20[i] = vol5[i]*k20 + vol20[i-1]*(1.0-k20);

   double lastVol5  = vol5[need-1];
   double lastVol20 = vol20[need-1];
   if(lastVol20 <= 0.0) return 0.0;
   return (lastVol5 - lastVol20) / lastVol20;
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
//| ★2026-07-20(2回目)追加: DokaKotsu_US_Calendar.mq5(v6)がCAL_FILEへ  |
//|   書き出す"HOLIDAY_JP|名前|時刻表記"行を読む。判定ロジックは        |
//|   Calendar側のみに存在し、ここでは名前と時刻表記を読むだけ。         |
//+------------------------------------------------------------------+
bool ReadTodayJpHoliday(string &name, string &hhmm)
  {
   name = ""; hhmm = "";

   int h = FileOpen(CAL_FILE, FILE_READ|FILE_TXT|FILE_UNICODE|FILE_COMMON);
   if(h == INVALID_HANDLE)
      return false;

   datetime jstNow = TimeTradeServer() + ServerToJstShiftDKD();
   if(jstNow <= 0) jstNow = TimeCurrent() + ServerToJstShiftDKD();
   string todayTag = TimeToString(jstNow, TIME_DATE);

   bool dateOk = false;
   bool found  = false;
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
      if(cnt >= 3 && parts[0] == "HOLIDAY_JP" && dateOk)
        {
         name  = parts[1];
         hhmm  = parts[2];
         found = true;
        }
     }
   FileClose(h);
   return found;
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
   ObjectSetInteger(0,full,OBJPROP_FILL,true);   // ★2026-07-15(5回目)追加: MT5環境によってはBGCOLORだけでは
                                                   //   塗りつぶされずチャートの文字が透けることがあるための対策
   ObjectSetInteger(0,full,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,full,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,full,OBJPROP_ZORDER,100000000+zorder);   // ★2026-07-15: 他インジ(SQ/TR/SP等)より必ず手前に出すため大幅に引き上げ
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
   ObjectSetInteger(0,full,OBJPROP_ZORDER,100000500);   // ★2026-07-15: 同上
  }

void CreateButtonObj(string name,int x,int y,int w,int h,string text,color bg,color txt,color border,int fontsize=7)
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
   ObjectSetInteger(0,full,OBJPROP_FONTSIZE,fontsize);   // ★2026-07-15(5回目)変更: 固定7→引数化(ボタン拡大時に文字も追従)
   ObjectSetInteger(0,full,OBJPROP_BACK,false);
   ObjectSetInteger(0,full,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,full,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,full,OBJPROP_ZORDER,100000600);   // ★2026-07-15: 同上
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
   CreateLabelText("title",x+pad,curY,"DokaKotsu",COL_TEXT,9);
   // ★2026-07-15変更: 固定「EA稼働中」から、DokaKotsu_US_Calendarの実在チェックへ変更
   bool calOnChart = IsUsCalendarPresent();
   if(calOnChart)
      CreateLabelText("badge",rightEdge,curY+1,"● US_Calendar _連携中",COL_GREEN,7,"Arial",ANCHOR_RIGHT_UPPER);
   else
      CreateLabelText("badge",rightEdge,curY+1,"● US_Calendar_未連携",COL_RED,7,"Arial",ANCHOR_RIGHT_UPPER);
   curY+=(int)(38*sc);

   // ロット / TOTAL pips（★2026-07-15(4回目)変更: 「0.1 Lot」を■(取引停止)/▶(復活)ボタンに置き換え）
   int lotboxH=(int)(38*sc);   // ★2026-07-15(5回目)変更: 28→38(拡大したボタンが収まるように)
   CreateRectLabel("lotbox",x+pad,curY,innerW,lotboxH,COL_CELL,COL_BORDER);
   bool dashPaused = GlobalVariableCheck(StringFormat("DK_DASH_TRADEPAUSE_%d",InpMagic))
                     && GlobalVariableGet(StringFormat("DK_DASH_TRADEPAUSE_%d",InpMagic))!=0.0;
   int btnSize=(int)(30*sc);   // ★2026-07-15(5回目)変更: 20→30(1.5倍)
   CreateButtonObj("btnstop",x+pad+8,           curY+(lotboxH-btnSize)/2,btnSize,btnSize,"■",C'200,40,40',COL_TEXT,C'160,20,20',11);
   CreateButtonObj("btnplay",x+pad+8+btnSize+6, curY+(lotboxH-btnSize)/2,btnSize,btnSize,">",C'0,140,120',COL_TEXT,C'0,100,90',13);   // ★2026-07-15(6回目)変更: ▶が文字化けするため">"に変更
   string pauseTxt = dashPaused ? "取引停止中" : "EA稼働中";   // ★2026-07-15(7回目)変更: 「稼働中」→「EA稼働中」
   color  pauseCol = dashPaused ? COL_RED : COL_GREEN;
   if(!dashPaused)
     {
      // ★2026-07-15(7回目)追加: ゆっくり点滅(約1.6秒周期)。専用タイマーは追加せず、
      //   既存の1秒更新の中でGetTickCount()の位相だけ見て色を背景色に落とす=負荷を増やさない
      bool blinkOn = (((int)(GetTickCount()/800)) % 2 == 0);
      if(!blinkOn) pauseCol = COL_BG;
     }
   CreateLabelText("pausestate",x+pad+8+btnSize*2+16,curY+(int)(9*sc),pauseTxt,pauseCol,7);
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
      string stars = (drPips <= InpDrSmall) ? "★" : (drPips <= InpDrLarge) ? "★★" : "★★★";   // ★2026-07-15(6回目)変更: <を<=に(「以下」の意味に合わせる)
      // ★2026-07-13(2回目)変更: 全決済ボタンを削除し2部屋構成に。左=上方向(既存,左詰め)/右=★★★DR628のように右詰め
      CreateLabelText("dirstars",rightEdge,curY+(int)(10*sc),stars+"DR"+IntegerToString(drPips),col,10,"Arial",ANCHOR_RIGHT_UPPER);
     }
   ObjectDelete(0,PFX+"closeall");   // ★2026-07-13(2回目): 全決済ボタンを撤去(過去に作られた分も消す)
   curY+=dirboxH+(int)(24*sc);

   // ボラティリティ（★2026-07-17変更: ADX生値基準→VolScore基準に置き換え。
   //   VolScore=(EMA(High-Low,5)-EMA(それ,20))/EMA(それ,20)。「普段の値幅」からの乖離率(%)。
   //   4段階: <InpVolScoreLowPct=グレー(縮小)/<InpVolScoreMidPct=イエロー/<InpVolScoreHighPct=ライム/以上=レッド)
   //   ★2026-07-17(2回目)修正: 閾値inputを%表示に統一。画面の「Vol +xx%」の数字とプロパティの数値が
   //   そのまま一致するようにした(従来は画面%・input比率で単位がズレており調整しづらかった)。
   double volScore = ComputeVolScore();
   double volScorePct = volScore*100.0;
   CreateLabelText("wavelbl",x+pad,curY,"ボラティリティ",COL_GRAY,7);
   CreateLabelText("wavevalnow",x+pad+62,curY,StringFormat("Vol %+.0f%%",volScorePct),COL_GRAY2,7);
   curY+=(int)(20*sc);
   int waveboxH=(int)(36*sc);
   CreateRectLabel("wavebox",x+pad,curY,innerW,waveboxH,COL_CELL,COL_BORDER);
     {
      string mode; color baseCol; double amp, base;
      if(volScorePct < InpVolScoreLowPct)        { mode="grey";   baseCol=COL_GRAY2;  amp=0.16; base=0.08; }
      else if(volScorePct < InpVolScoreMidPct)   { mode="yellow"; baseCol=COL_YELLOW; amp=0.38; base=0.18; }
      else if(volScorePct < InpVolScoreHighPct)  { mode="lime";   baseCol=COL_LIME;   amp=0.60; base=0.30; }
      else                                  { mode="red";    baseCol=COL_RED;   amp=0.90; base=0.48; }

      int barCount=16;
      int barAreaW=innerW-8;
      int barW=barAreaW/barCount;
      double t=0.0;   // ★2026-07-15(6回目)変更: GetTickCount()による常時アニメーションを廃止(負荷対策)。最初の1枚を固定表示
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
      string stateTxt = (mode=="grey") ? "LOW" : (mode=="yellow") ? "MID" : (mode=="lime") ? "HIGH" : " "; // ★2026-07-14変更: DANGERは警告文と重なるため削除(スペースに)
      CreateLabelText("wavestate",x+pad,curY,stateTxt,baseCol,8);
      if(mode=="grey")
         CreateLabelText("wavewarn",rightEdge,curY+1,"⚠ ボラ不足 — エントリー非推奨",COL_ORANGE,7,"Arial",ANCHOR_RIGHT_UPPER);
      else if(mode=="lime")
         CreateLabelText("wavewarn",rightEdge,curY+1,"⚠ 高ボラ — ロット調整を検討",COL_ORANGE,7,"Arial",ANCHOR_RIGHT_UPPER);
      else if(mode=="red")
         CreateLabelText("wavewarn",rightEdge,curY+1,"⚠ ボラ異常 — ロットを下げるか中止してください",COL_RED,7,"Arial",ANCHOR_RIGHT_UPPER);
      else
         CreateLabelText("wavewarn",rightEdge,curY+1," ",COL_BG,7,"Arial",ANCHOR_RIGHT_UPPER);   // ★2026-07-15(2回目): 警告なし時は背景色化
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
      // ★2026-07-15追加: EA_14(DK_UpdateGameStats,2026-07-14追加)が書き出す直近決済GVを読み、
      //   GET/LOSEのポップアップを実データで反映する。保有中(showMsgIn)の時はそちらを優先。
      // ★2026-07-15(5回目)変更: 時間切れによる自動非表示をやめ、次のエントリー(showMsgIn=true)が
      //   発生するまでずっと表示し続けるよう変更(InpMsgFreshSecは使わなくなったため削除)。
      if(!showMsgIn)
        {
         string gvPips = StringFormat("DK_EA_LASTCLOSE_PIPS_%d", InpMagic);
         string gvWin  = StringFormat("DK_EA_LASTCLOSE_WIN_%d",  InpMagic);
         string gvTime = StringFormat("DK_EA_LASTCLOSE_TIME_%d", InpMagic);
         string gvWs   = StringFormat("DK_EA_WINSTREAK_%d",      InpMagic);
         if(GlobalVariableCheck(gvTime))
           {
            datetime closeTime = (datetime)GlobalVariableGet(gvTime);
            if(closeTime>0)
              {
               double pips  = GlobalVariableCheck(gvPips) ? GlobalVariableGet(gvPips) : 0.0;   // 符号付き(勝ち=正/負け=負)
               bool   isWin = GlobalVariableCheck(gvWin)  ? (GlobalVariableGet(gvWin)!=0.0) : (pips>=0.0);
               int    ws    = GlobalVariableCheck(gvWs)   ? (int)GlobalVariableGet(gvWs) : 0;
               if(isWin) { showMsgGet=true;  pipsTxt=StringFormat("WIN +%.1fp", pips); pipsCol=COL_GREEN; }
               else      { showMsgLose=true; pipsTxt=StringFormat("LOSE %.1fp", pips); pipsCol=COL_RED;  }
               streakTxt = (ws>=2) ? StringFormat("🔥%d連勝", ws) : "";
              }
           }
        }
     }
   else
     {
      switch(InpEntryDemoState)
        {
         case DEMO_READY: statusTxt="Ready";   statusCol=C'74,175,80';  demoProgress=0.60; break;
         case DEMO_IN:    statusTxt="IN";      statusCol=C'66,165,245'; demoProgress=0.95; showMsgIn=true; streakTxt="🔥3連勝"; break;
         case DEMO_GET:   statusTxt="WAIT"; statusCol=C'245,197,24'; demoProgress=0.08; showMsgGet=true;  streakTxt="🔥3連勝"; pipsTxt="WIN +55.2p"; pipsCol=COL_GREEN; break;
         case DEMO_LOSE:  statusTxt="WAIT"; statusCol=C'245,197,24'; demoProgress=0.08; showMsgLose=true; streakTxt="";        pipsTxt="LOSE -32.1p"; pipsCol=COL_RED;  break;
         default:         statusTxt="WAIT"; statusCol=C'245,197,24'; demoProgress=0.08; break; // DEMO_NOTRADE
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
            ObjectSetInteger(0,RB_OBJ,OBJPROP_ZORDER,100000500);   // ★2026-07-15: 同上
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
   CreateLabelText("rblabel_l",x+pad,curY,"WAIT",C'245,197,24',7);
   CreateLabelText("rblabel_m",x+pad+innerW/2,curY,"Ready",C'74,175,80',7,"Arial",ANCHOR_UPPER);
   CreateLabelText("rblabel_r",rightEdge,curY,"IN",C'66,165,245',7,"Arial",ANCHOR_RIGHT_UPPER);
   curY+=(int)(14*sc);
   curY+=(int)(14*sc);   // ★2026-07-15(6回目)追加: 「決済目安」との間が詰まって見づらいため空白1行分を追加

   // ★2026-07-15削除: 進捗%テキスト(entrypct)は実データに未接続のまま空白/既定文字"Label"が
   //   表示され続けるバグだった行。下のメッセージ箱(⑤)だけで十分表現できるため廃止し、
   //   非表示時は詰める(高さを使わない)。再コンパイル前の古いオブジェクトが残っていれば削除する。
   ObjectDelete(0,PFX+"entrypct");

   // ★2026-07-15(4回目)変更: 「決済目安」と「INしました」ブロックの表示順を入替(決済目安を先に)
   // 決済目安（★2026-07-16変更: 案②=段階決済モード切替の節目を基準にした実ロジックへ差し替え。
   //   0%=エントリー直後/InpMeterStagedPct%=含み益がInpStagedTrigPipsMirrorに到達(段階決済モードへ切替)/
   //   100%=実際の決済。節目到達後はトレーリングの経過を厳密には予測できないため、節目〜100%の中間で
   //   固定表示する(「決済判断の監視フェーズに入った」ことを示す簡易表現。ウソをつかない設計)。
   //   保有していない時は、直近決済があれば100%のまま(次のエントリーまで)、無ければ0%。
   CreateLabelText("ailbl",x+pad,curY,"決済目安",COL_GRAY,7);
   curY+=(int)(20*sc);
   int segH=(int)(9*sc);
     {
      int barX=x+pad;
      int barW=innerW;
      double convVal;   // 0.0〜1.0
      double profitPips=0.0;
      bool posOpen = GetOpenPositionProfitPips(profitPips);
      if(posOpen)
        {
         double stagedFrac = InpMeterStagedPct/100.0;
         if(profitPips < InpStagedTrigPipsMirror)
            convVal = MathMax(0.0, profitPips/InpStagedTrigPipsMirror) * stagedFrac;
         else
            convVal = stagedFrac + (1.0-stagedFrac)*0.5;   // 節目到達後(トレーリング監視中)は中間で固定
        }
      else
        {
         // ★直近決済がまだ新しければ100%のまま表示(GET/LOSEメッセージと同じ鮮度判定を流用)
         string gvTime = StringFormat("DK_EA_LASTCLOSE_TIME_%d", InpMagic);
         bool recentClose = GlobalVariableCheck(gvTime) && (datetime)GlobalVariableGet(gvTime) > 0
                             && !showMsgIn;   // showMsgInがtrueなら別途保有中扱いなのでここには来ないはずだが念のため
         convVal = (recentClose && (showMsgGet || showMsgLose)) ? 1.0 : 0.0;
        }
      double convThresh=InpMeterStagedPct/100.0;   // 節目の区切り線位置(メーターと同じ基準に統一)
      double needlePos = convVal; if(needlePos>1.0) needlePos=1.0; if(needlePos<0.0) needlePos=0.0;
      int splitX=barX+(int)(barW*convThresh);
      CreateRectLabel("sqzbg_l",barX,curY,splitX-barX,segH,C'90,45,45',C'90,45,45',1);              // 圧縮ゾーン(暗い赤)
      CreateRectLabel("sqzbg_r",splitX,curY,barX+barW-splitX,segH,C'45,90,50',C'45,90,50',1);        // ボラありゾーン(暗い緑)
      CreateRectLabel("sqzsplit",splitX,curY,1,segH,C'204,204,204',C'204,204,204',2);                // 閾値の区切り線
      int needleX=barX+(int)(barW*needlePos);
      CreateRectLabel("sqzneedle",needleX-1,curY,3,segH,clrWhite,clrWhite,3);                        // 現在値の針
      CreateLabelText("sqzlbl_l",x+pad,curY+segH+2,"エントリー",C'200,122,122',7);
      CreateLabelText("sqzlbl_m",x+pad+innerW/2,curY+segH+2,StringFormat("%.0f%%",InpMeterStagedPct),COL_GRAY,7,"Arial",ANCHOR_UPPER);
      CreateLabelText("sqzlbl_r",rightEdge,curY+segH+2,"決済",C'106,176,106',7,"Arial",ANCHOR_RIGHT_UPPER);
     }
   curY+=segH+(int)(24*sc);

   // ⑤ メッセージ箱(IN/GET/LOSEのいずれか1つだけ、無ければ非表示=高さも詰める)
   // ★2026-07-15(4回目)変更: 高さ・フォントを約3倍に拡大(18*sc→54*sc、フォント8→14)
   if(showMsgIn || showMsgGet || showMsgLose)
     {
      int msgH=(int)(54*sc);
      color msgBg, msgBorder, msgCol; string msgTxt;
      if(showMsgIn)        { msgBg=C'7,30,53';  msgBorder=C'26,74,122'; msgCol=C'66,165,245'; msgTxt="🔔 INしました（保有中）"; }
      else if(showMsgGet)  { msgBg=C'7,30,53';  msgBorder=C'26,74,122'; msgCol=C'79,195,247'; msgTxt="✔ GETしました 🎉"; }
      else                 { msgBg=C'58,26,26'; msgBorder=C'106,26,26'; msgCol=C'239,83,80';  msgTxt="次がんばりましょう 💪"; }
      CreateRectLabel("entrymsgbox",x+pad,curY,innerW,msgH,msgBg,msgBorder,1);
      CreateLabelText("entrymsgtxt",x+pad+innerW/2,curY+msgH/2,msgTxt,msgCol,10,"Arial",ANCHOR_CENTER);   // ★2026-07-15(6回目)変更: ANCHOR_CENTERで水平・垂直とも中央揃え
      curY+=msgH+(int)(6*sc);
     }
   else
     {
      ObjectDelete(0,PFX+"entrymsgbox");
      ObjectDelete(0,PFX+"entrymsgtxt");
     }

   // ⑥ 連勝／獲得pips行
   // ★2026-07-15(2回目)追加: streakTxt/pipsTxtが空文字のままだとMT5既定の"Label"表示が
   //   出てしまう不具合への安全策。空の時は背景色と同化させて見えなくする。
     {
      int rowH=(int)(16*sc);
      color streakCol = (streakTxt=="") ? COL_BG : C'255,215,0';
      color pipsColSafe = (pipsTxt=="") ? COL_BG : pipsCol;
      string streakShow = (streakTxt=="") ? " " : streakTxt;
      string pipsShow   = (pipsTxt=="")   ? " " : pipsTxt;
      CreateLabelText("gamestreak",x+pad,curY+rowH/2-6,streakShow,streakCol,9);
      CreateLabelText("gamepips",rightEdge,curY+rowH/2-6,pipsShow,pipsColSafe,10,"Arial",ANCHOR_RIGHT_UPPER);
      curY+=rowH+(int)(6*sc);
     }

   // ⑦ 凡例(小さいグレー、3行)
     {
      CreateRectLabel("legendline",x+pad,curY,innerW,1,COL_BORDER,COL_BORDER,1);
      curY+=(int)(4*sc);
      CreateLabelText("legendtxt",x+pad,curY," ",COL_BG,7);   // ★2026-07-15(2回目)変更: 空文字だと既定文字"Label"が出るため背景色で見えなくする
      curY+=(int)(12*sc);
     }
   curY+=(int)(16*sc);

   // 経済指標見出し（★2026-07-07変更: 「本日の趣味レーション」の誤字修正＋日付表示）
   int accH=(int)(20*sc);
   CreateRectLabel("accbox",x+pad,curY,innerW,accH,COL_BG,COL_BORDER,1);
   {
      datetime jstNow2 = TimeTradeServer() + ServerToJstShiftDKD();
      if(jstNow2 <= 0) jstNow2 = TimeCurrent() + ServerToJstShiftDKD();
      string dateStr = TimeToString(jstNow2, TIME_DATE);
      StringReplace(dateStr, ".", "/");
      CreateLabelText("acclbl",x+pad+8,curY+accH/2-6,"▲ 本日の経済指標  "+dateStr,COL_GRAY2,7);   // ★2026-07-15(7回目)変更: 「決済目安」と同じフォント7に統一
   }
   curY+=accH+(int)(12*sc);

   // ★2026-07-07変更: GDP/PCIの固定サンプル2行→テキストファイルから読んだ当日分を可変件数で表示。
   //   フォントサイズはご要望により従来(7)の50%増(11)に拡大。
   int calH=(int)(18*sc);
   int calFont=8;        // ★2026-07-15(2回目)変更: 指標あり時のフォントサイズを11→8に縮小
   int calEmptyFont=9;   // ★2026-07-13変更: 「本日は該当指標なし」はこちらをやや小さく(11→9)

   string evLabels[], evHhmm[];
   int evCount = ReadTodayEconEvents(evLabels, evHhmm);

   // ★2026-07-20(2回目)修正: 前回追加した専用の赤/オレンジ行は削除。
   //   日本の祝日は経済指標と同じ並び(白文字・同じセル)の先頭に差し込む方式に変更。
   //   判定ロジックはDokaKotsu_US_Calendar.mq5(v6)側のみに存在し、ここでは
   //   同ファイルが監査用CAL_FILEへ書き出す"HOLIDAY_JP"行の名前を読むだけ。
   string jpHolName, jpHolHhmm;
   if(ReadTodayJpHoliday(jpHolName, jpHolHhmm) && jpHolName != "")
     {
      ArrayResize(evLabels, evCount + 1);
      ArrayResize(evHhmm,   evCount + 1);
      for(int i = evCount; i > 0; i--)
        {
         evLabels[i] = evLabels[i-1];
         evHhmm[i]   = evHhmm[i-1];
        }
      evLabels[0] = jpHolName;
      evHhmm[0]   = jpHolHhmm;
      evCount++;
     }
   // ★前バージョンで作成していたオブジェクトが残っていた場合の掃除
   ObjectDelete(0, PFX+"jphol");
   ObjectDelete(0, PFX+"jpholtxt");

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
   // ★2026-07-15: ボラティリティはADX(buf60)基準に変更したためATRハンドルは不要(削除)
   CreatePanel();
   EventSetMillisecondTimer(1000);   // ★2026-07-15(6回目)変更: 150→1000。アニメーション静止化に伴い高頻度更新が不要になったため負荷軽減
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
//| ★2026-07-15(4回目)追加: ■(取引停止)/▶(復活)ボタンのクリック処理。 |
//|   DK_DASH_TRADEPAUSE_<magic>というGlobalVariableへ1(停止)/0(復活) |
//|   を書き込むだけ。EA_14側がこのGVを毎ティック参照して新規エント   |
//|   リーを止める/再開する(IsDashboardPaused関数)。保有中のポジションは|
//|   このボタンでは決済されない(あくまで「新規を止める/再開する」   |
//|   スイッチ)。                                                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
  {
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   string gv = StringFormat("DK_DASH_TRADEPAUSE_%d", InpMagic);
   if(sparam == PFX+"btnstop")
     {
      GlobalVariableSet(gv, 1.0);
      ObjectSetInteger(0, PFX+"btnstop", OBJPROP_STATE, false);   // 押しっぱなし表示にしない(単発トリガー)
      CreatePanel();
      ChartRedraw();
     }
   else if(sparam == PFX+"btnplay")
     {
      GlobalVariableSet(gv, 0.0);
      ObjectSetInteger(0, PFX+"btnplay", OBJPROP_STATE, false);
      CreatePanel();
      ChartRedraw();
     }
  }

//+------------------------------------------------------------------+
//| 終了処理（オブジェクト全削除）                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   if(g_indHandle != INVALID_HANDLE) IndicatorRelease(g_indHandle);
   // ★2026-07-15: ATRハンドルは廃止(ボラティリティはADX/buf60基準へ変更)
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
