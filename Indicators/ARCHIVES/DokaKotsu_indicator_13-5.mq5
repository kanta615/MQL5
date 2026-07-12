//+------------------------------------------------------------------+
//|                              DokaKotsu_indicator_13.mq5            |
//|   バージョン : Ver13.0(_13)  修正日 : 2026-07-07 (context専用バッファ追加)|
//|                                                                  |
//|  ■ 修正日 : 2026-07-08  修正内容(バージョン番号は据え置き)       |
//|    ①長期足の参加タイミング(順番)ON/OFF                          |
//|      既存の InpUseLongFirst で既に true/false 切替可能だった。  |
//|      false にすると「長期が最後に点灯していてもNGにしない」＝   |
//|      順番を問わず短期(WMA34)・中期(M15)・長期の3本が同色に      |
//|      揃ってさえいれば(InpUseLongFilterのみでゲート)エントリー   |
//|      できる。ロジック自体は変更なし、コメント文言のみ明確化。   |
//|    ②長期足5段階色(グレー/水色/アクア/薄マゼンタ/マゼンタ)      |
//|      のうち薄い色(水色・薄マゼンタ)もエントリー対象か           |
//|      → 確認の結果、エントリー判定に使う longDir(1/-1)は         |
//|      濃淡(sc=描画専用の5段階)を区別しておらず、薄い色も          |
//|      既にエントリー対象に含まれていた。ロジック変更なし。       |
//|      理由(reason)も濃淡で分けていない(仕様どおり)。             |
//|    ③インジケーターリストの表示名バグを修正                     |
//|      IndicatorSetString(INDICATOR_SHORTNAME, ...) が             |
//|      旧ファイル名 "DokaKotsu_indicator_11" のままだったため、    |
//|      チャート上で「DokaKotsu_indicator_13(DokaKotsu_indicator_11)」|
//|      という二重表示になっていた。"DokaKotsu_indicator_13" に修正。|
//|                                                                  |
//|  ■ Ver13.0(_13) 変更点(2026-07-07)                              |
//|    エントリーリーズンのAI分析基盤として、判定には一切使わない    |
//|    「context専用」バッファを buf28〜40 に追加(観測のみ)。       |
//|      buf28 RSI(14) / buf29-31 MACD(12,26,9)main・signal・hist   |
//|      buf32 GMMA短期角度(代理:EMA10傾き,真の6本平均ではない)     |
//|      buf33 GMMA長期角度(代理:長期足MA=既定KAMA180の傾き)        |
//|      buf34 EMA乖離(符号付・ATR正規化) / buf35 MA傾き(生値)      |
//|      buf36/37 直近20本の高値/安値更新フラグ / buf38 レンジ幅    |
//|        (ATR倍率) / buf39/40 前日高値・安値                      |
//|    これらはEA側で読み取り、entry_snapshotのcontextセクション    |
//|    として記録するだけで、BufBuy/BufSell/BufExitの判定ロジック   |
//|    には一切影響しない(絶対ルール継続遵守)。                    |
//|                                                                  |
//|  ■■ 最重要・絶対ルール(EAと共通) ■■                            |
//|    売買ロジックは すべてこのインジ側 に持たせる。               |
//|    EA(DokaKotsu_EA)はロジックを一切持たず、ここが出す           |
//|    シグナル(BUY=buf7 / SELL=buf8 / EXIT=buf9)を実行するだけ。  |
//|    EAが持つのは固定概念・リスク管理のみ(時間/ロット/SL/建値)。 |
//|    → 両方にロジックを置かない。長期使用でぶつかり、バグが       |
//|       消えなくなるため厳禁。変更時は必ずこの分担を守ること。    |
//|                                                                  |
//|  ■ Ver3 = 基本版(まず素直に動かす)                              |
//|    エントリー: KAMA10 の色だけで判断。                           |
//|      ・グレー(平行)= レンジ → 取引しない(徹底)                |
//|      ・緑(上昇点灯) → BUY / オレンジ(下降点灯) → SELL          |
//|    決済: 平均足(SmoothedHA)が逆色に転換、またはベースMAが逆転。  |
//|    任意フィルター(M1スパイク/圧縮/オーバーシュート/EMA同時点灯)  |
//|    は 基本版では全てOFF。慣れたら1つずつONで検証する。           |
//|    (表示のみ・発注はEAが行う)                                   |
//|                                                                  |
//|  ベースMA(InpWmaType): 既定 FRAMA(期間20)。傾き(slope)が          |
//|    +しきい値→上(緑)/ -しきい値→下(オレンジ)/ 間→平行(グレー)。   |
//|    グレーの間はエントリー禁止(=レンジは触らない)。              |
//|                                                                  |
//|  任意フィルター(基本版OFF):                                     |
//|    ①InpFilM1Spike     : M1スパイク点灯を要求                    |
//|    ②InpFilSqueeze     : 圧縮(スクイーズ)中は弾く               |
//|    ③InpFilOvershoot   : オーバーシュート(急変)を弾く           |
//|    ⑤InpRequireEmaColit: 方向MAとEMA点灯の同時点灯を要求          |
//|                                                                  |
//|  ※M5チャートに入れて使う前提(_Period=M5想定)。                |
//|                                                                  |
//|  ■ Ver5.1 変更点(2026-06-14)                                     |
//|    ・背景色: 上昇=Gray / 下降=RGB(34,116,128) / 中立=#222222      |
//|    ・確認本数 既定 2→1 (1本目の色で即エントリー=1本早い)         |
//|    ・グレー基準の再エントリー: グレーを挟んだら本命=ロック解除、  |
//|      グレー無しの直接フリップは調整波=見送り(コード14)。         |
//|    ・A案:実ポジ同期(ライブ足)。EAがノーポジなら保有解除し再武装。 |
//|    ・背景(BG_)の掃除を OnDeinit → OnInit へ移管(EA非連動)。      |
//|    ・情報ラベル(ファイル名)を既定OFF(InpShowInfoLabel)。        |
//|                                                                  |
//|  ■ Ver7.0 変更点(2026-06-17)                                     |
//|    ②決済用平均足を 前後とも 期間5・SMOOTHED(SMMA) に変更。       |
//|      → 平均足が滑らかになり、ダマシの色転換による早すぎる決済を   |
//|        抑える(その分、決済はやや遅くなる=FW/BTで要確認)。       |
//|    ③表示の色保持 InpColorHoldBars を追加(背景/方向MA線)。       |
//|      新しい色がこの本数続くまで前の色を保持し、1本だけの          |
//|      色の途切れ(背景の黒帯)を埋めて連続表示にする。            |
//|      ※表示のみ。エントリー判定は raw wmaDir のままで挙動不変。   |
//|    ①連敗ロット縮小/停止は『リスク管理=EA側』の分担のためEAに    |
//|      実装する(本インジには入れない。絶対ルール遵守)。          |
//|                                                                  |
//|  ■ Ver8.0(_8) 変更点(2026-06-20) ※EA_8と番号統一               |
//|    ①方向判定MAを WMA・期間34 に変更(既定)。大きく見て“ポン”の  |
//|      小さなダマシを無視 → ピーク飛び乗りエントリーを構造的に減らす|
//|      (FRAMA8は速すぎて小波に点灯していた)。                     |
//|    ②決済に『案Cハイブリッド』を追加(InpExitHybridC=ON 既定)。   |
//|      基本はMAの色でトレンドを伸ばし、ただし“平均足が逆色へ転換   |
//|      ＋価格がSMA中心線を割り込み=本物の反転”の時だけ、MAグレーを  |
//|      待たず早決済。浅い押しは無視して伸ばし、急反転は早逃げ。     |
//|      OFFにすると案A(MAグレー/反転のみ)でBT比較できる。          |
//|                                                                  |
//|  ■ 2026-06-22 追記(Ver8.0据置) M15フィルターの確定足参照化      |
//|    現象: M15足の頭(例 07:00)でライブ(進行中)のM15足の方向が     |
//|      一瞬だけ点灯し、その未確定値でフィルターを通過→誤エントリー。|
//|    対策: InpM15ConfirmClosed(既定 true)。M15の方向は『1本前の    |
//|      確定したM15足』で判定・表示する(shift1相当)。頭の一瞬の     |
//|      ブレでは入らない。表示(buf1/2/11)・状態buf13も同じ確定足に  |
//|      統一(WYSIWYG厳守)。falseで従来のライブ足参照に戻せる。      |
//====================================================================
//  設定スナップショット   修正年月日: 2026-07-05
//   (このインジのプロパティ(input)現在値。開いた時の確認用)
//====================================================================
//  (1) 長期足
//    長期足一致フィルター             = true
//    長期が先頭に点灯                 = true
//    長期足MAの種類                   = KAMA
//    長期足の期間                     = 180
//    傾き1サンプルの本数              = 5
//    傾きの平滑化サンプル数           = 4
//    グレー閾値(ATR正規化slope)       = 0.05
//    ヒステリシス(色閾値=Gray×本値)   = 1.5
//  (2) 15分足
//    15分足MAの種類                   = KAMA
//    15分足MAの期間                   = 15
//    M15一致フィルター                = true
//    M15ライブ足参照(false=確定足)    = false
//    エントリーのM15確定足要求        = 2
//    M15グレー判定しきい値            = 0.05
//    M15をSELLにも適用(2026-07-06)    = false  (実験: SELLはM15フィルター対象外)
//  (3) 平均足(決済用の作り)
//    前平滑化の期間                   = 4
//    前平滑化の方式                   = Smoothed
//    後平滑化の期間                   = 5
//    後平滑化の方式                   = Smoothed
//  (4) 5分MA(方向=WMA34・背景の基準)
//    方向判定MAの種類                 = WMA
//    方向判定MAの期間                 = 34
//    表示線の平滑(本数,1=なし)        = 5
//    点灯しきい値(slope/ATR)          = 0.1
//    色の粘り                         = 0.3
//    色の確認本数                     = 1
//    直前確定足も同方向を必須         = true
//  (5) WAVE(波)   ← 2026-07-02 変更
//    波:MAの種類                      = KAMA
//    波:早い線の期間                  = 6    (旧14)
//    波:遅い線EMA期間                 = 24   (旧34)
//    波:シグナル平滑                  = 9    (旧10)
//    波:中立帯                        = 0.03
//    Waveが同方向を最終条件           = true
//  (5b) ADXトレンドフィルター  ← 2026-07-05 新規追加
//    ADXグレーで禁止(最終ゲート)      = true
//    ADX期間                          = 12
//    ADX用EMA期間                     = 50
//    EMAスロープ遡り本数              = 3
//    ADX閾値(未満=グレー)             = 25.0
//    ADX継続確認本数(2026-07-06追加)  = 2   (直前グレーからの即時フリップを弾く)
//  (5c) ZigZag弱波/天底近接フィルター ← 2026-07-06 新規追加(実験・既定OFF)
//    ZigZagフィルターを使う           = false
//    ZigZag用ATR期間                  = 14
//    ZigZag用ATR倍率                  = 2.0
//    残存強度%の下限(未満=禁止)       = 40.0
//  (6) 決済
//    SMA期間(決済基準=SMA10)          = 10
//    二重平滑の期間(1=なし)           = 1
//    案B 平均足の色で決済             = true
//    MA決済グレー本数                 = 2
//    案C 平均足逆転+価格がSMA         = true
//  (7) その他 - エントリー制御/フィルター
//    クールダウン本数                 = 5
//    調整波も狙う(false=一致時のみ)   = false
//    (1)M1スパイク要求                = false
//    (2)圧縮中は弾く                  = false
//    (3)オーバーシュートを弾く        = false
//    (4)方向MAとEMA同時点灯           = false
//    エントリー/終了アラート          = true
//  (7) その他 - 出来高フィルター
//    出来高フィルター                 = false
//    出来高移動平均本数(M5)           = 20
//    出来高の下限倍率                 = 0.5
//  (7) その他 - スパイク/スクイーズ
//    EMA10収束度                      = 2.0
//    M1スパイク収束本数               = 2.0
//    取得M1本数                       = 30000
//    スクイーズBB偏差                 = 2.0
//    圧縮ケルトナー幅                 = 1.5
//    M1スパイク足もEMA10マゼンタ      = true
//  (7) その他 - ATR適応・MAMA(全MA共有)
//    ATR適応:速いα                   = 0.6
//    ATR適応:遅いα                   = 0.05
//    ATR適応:参照期間                 = 50
//    ATR Adaptive:高ボラで速く        = true
//    MAMA:FastLimit                   = 0.5
//    MAMA:SlowLimit                   = 0.05
//  (7) その他 - EA連携・旧設定
//    ライブ足で実ポジ同期             = true
//    同期対象マジック                 = 20260606
//    旧・引き金/スパイク線            = KAMA
//    旧・未使用                       = 10
//  背景色・表示(描画)
//    背景色を表示                     = true
//    上昇の背景色                     = Gray
//    中立(グレー)の背景色             = 34,34,34
//    下降の背景色                     = 34,116,128
//    ファイル名/版ラベル表示          = false
//    表示の色保持                     = 2
//    トレンド内一時グレー橋渡し本数   = 3
//    背景を塗る本数(直近)             = 800
//  線幅(描画)
//    MA_UP / MA_DOWN / MA_FLAT        = 5 / 5 / 5
//    M15 NORM / UP / DOWN             = 5 / 5 / 5
//    長期足                           = 5
//====================================================================
//  修正履歴 (年月日  変更内容)
//    2026-07-05  Ver11.0(_11) ADXトレンドフィルターを追加(ロジック変更=売買に影響)。
//                DokaKotsu_Trend_FilterのADX(既定期間12)+EMA(50)判定を本体に統合し、
//                ADXグレー(トレンド終盤の弱い波=ノイズ)の時だけ最終ゲートでエントリー禁止(reason29)。
//                方向不一致(色反転)は見ない=ラグ回避。既存のグレーライン環境認識(長期/M15レンジ判定)
//                とは別軸のフィルターとして並存。状態はbuf26で公開(WYSIWYG/EA・ログ連携用)。
//    2026-07-02  波(Wave)を 早い14→6 / 遅い34→24 / シグナル10→9 に変更(ロジック変更=売買に影響)。
//                冒頭に設定スナップショット＋修正履歴を追加。
//    (それ以前の詳細な変更履歴は下の #define DK_BUILD を参照)
//====================================================================
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "13.00"

//=== バージョン情報(最新版か確認用) ==============================
#define DK_VERSION   "Ver12.0"
#define DK_BUILD     "2026-07-10c バグ修正: InpRegimeBBMult既定を1.5→1.8に変更。1.5(=KCMultと同値)だと圧縮判定の実質閾値がsd/rangema<1.0となり緩めすぎ、明確な下降トレンド中(平均足/長期/15分/ADX全て一致)でも毎足圧縮判定が再発火し続け、解除チェック(else分岐)に一度も到達できず65分以上スクイーズに固定される実例が発生(2026-07-10 16:45-17:50)。1.8で閾値0.83=旧来のInpFilSqueeze用0.75よりやや緩い程度に是正。 / 2026-07-10b 相場レジーム判定(スクイーズ/トレンド二層構造)追加: BB×KC圧縮(InpRegimeBBMult=1.5/InpRegimeKCMult=1.5,緩め既定・従来のInpFilSqueeze用sqzOnとは独立)をトリガーにレジームをスクイーズへ切替え、長期足・M15足の両方が非グレーになった瞬間にトレンドへ解除(reason40)。エントリー許可チェーンの最上流でスクイーズ中を一括禁止するため、ZigZag弱波(35)/スパイクADX禁止(37/39)等トレンド専用フィルターはスクイーズ中は個別評価されない。開始トリガーと解除条件を別指標にすることで、旧BBスクイーズ運用時の「解除が遅れてエントリーが遅くなる」問題を構造的に回避(InpUseRegimeSystemでON/OFF切替可)。診断用にbuf53(レジーム0/1)を追加。 / 2026-07-10 スパイクADX新規禁止(reason39)追加: スパイク面積300超を検出したらポジション有無に関係なくトリガーし、トリガー時点のADX色(0グレー/1上昇/2下降)と異なる色になるまで新規エントリーを禁止(InpUseSpikeAdxBan,既定true)。既存③(spikeBanActive/haColor,reason37)は保有中にスパイクで決済した場合のみのトリガーだったが、深夜のボラなし局面で平均足がグレー化した後もスパイクの余韻でダマシが出た実例があったため、より確実な独立軸としてADX色を基準に採用(平均足/MA反転は使わない)。グレー経由・逆色いずれでも解除。診断用にbuf50(禁止中フラグ)/buf51(直近トリガー面積,保持型)/buf52(直近トリガーからの経過本数)を追加、弱5波対策の効果検証に利用可(判定ロジックには影響しない観測専用)。 / 2026-07-09c 「勘に頼らない敗因分析」残項目を一括追加(buf44-49): ①再入クールダウン残り本数(cdLeft,buf44) ②ベースMAのグレー閾値距離(|slope|-thOn,buf45) ③長期MAの平滑化傾き実値(buf46)と閾値距離(buf47) ④Wave早い/遅い線の生値(wvMA/wvSlow,buf48/49)。いずれも判定ロジックには一切影響しない観測専用(WYSIWYG/絶対ルール継続遵守)。 / 2026-07-09b スパイク保持型バッファ追加(buf42/43): BufSpikeArea(buf41)は確定した1本の足でしか値が立たない単発パルスのため、エントリー側からは同一足でない限りほぼ0.0しか見えず相関が取れなかった。次のスパイクまで値を保持するBufSpikeAreaLast(buf42)と、経過本数のBufSpikeBarsSince(buf43,未観測=-1)を追加し、「何本前にどれくらいの面積のスパイクがあったか」を常に読めるようにした。 / 2026-07-09 スパイク面積(buf41)をEAへ公開: thisBarSpikeAreaがローカル変数のままでEAから読めなかったのを解消。スイング確定足では閾値未達(300未満)の「不発」も含めて常に実測値を書く=閾値300の妥当性検証に使える。 / 2026-07-08b ZigZag⇔M15を入れ替えて検証開始: InpUseZzFilter=false→true(弱5波フィルター有効化,InpZzMinStrength=40.0)。同時にInpM15ApplyToSell=true→false(SELLはM15対象外の実験構成に再度戻す)。ZigZagが効かないと判断した場合はInpUseZzFilter=false・InpM15ApplyToSell=trueに戻す。 / 2026-07-08 InpM15ApplyToSell既定をfalse→trueに復帰: 2026-07-06の実験(SELLのみM15フィルター対象外)投入直後に敗戦したため、BUY/SELL両方に再度M15フィルターを適用する対称構成に戻した(falseにすればいつでも実験構成へ切替可)。 / 2026-07-06 Ver12.0(_12) ①ADX継続性チェック追加(InpAdxConfirmBars,既定2)=前足グレーからの即時フリップを弾く(reason36) ②ZigZag_ATR(iCustom)を統合し残存強度%フィルターを追加(InpUseZzFilter,既定false=実験投入待ち。reason35=直近確定レッグの反対側到達間近=弱5波) ③M15フィルターの方向別非対称化(InpM15ApplyToSell,既定false=SELLはM15対象外の実験) / 2026-06-20 Ver8.0(_8) 方向MA=WMA34・案Cハイブリッド決済・M15(WMA20)一致フィルター+M15状態buf13/リーズン列・EA_8と番号統一 / 2026-06-22:M15確定足参照(InpM15ConfirmClosed) / 2026-06-22:M15=KAMA20既定・決済案B(平均足反転最優先+理由30/31/32)・出来高フィルター・平均足色buf14 / 2026-06-22:後平滑1・色確認1・M15ライブ足で前倒し / 2026-06-22:平均足一致を必須化(調整波回避ON)で天井づかみ防止 / 2026-06-24:Ver8.3 長期足(M5・既定KAMA360)追加=短期WMA34/中期M15/長期の3本MTFパーフェクトオーダー門番(reason22)・SMA20_CENTERを長期足表示に転用 / 2026-06-24:エントリーM15を確定足要求(InpM15EntryConfirm 0/1/2,既定2)=ライブ点火+確定足門番で深夜グレーのちらつき偽SELL(reason23)を抑止 / 2026-06-24:Ver9.0 ファイル名/版を8→9統一(EAと同番号)・初期値 中期M15期間=15/長期足期間=380・CSVに長期足状態列(平均足|長期足|15分|理由,buf15)追加 / 2026-06-25:Ver9.0 長期線スムージング=色判定の傾きをInpLongSlopeSmooth個平均(各InpLongSlopeStep本幅)・ATR正規化のまま+デッドバンドInpLongGrayThresh+ヒステリシスInpLongHystRatio(線位置は不変=WYSIWYG/本数増やさず)。スパイク一発で長期線が瞬間的に青判定→近フラットをグレー化。旧InpLongSlopeBars/InpLongSlopeThを置換。長期足状態buf15の二重ゼロ上書きバグ修正(EAが正しい長期方向を読めるように) / 2026-06-25:Ver9.0 平均足を一元化=後平滑OHLCをbuf16-19で公開(表示用DokaKotsu_HeikinAshiがiCustomで参照し色だけ付与)。前平滑3/後平滑5(ともSMMA)に統一=見ている平均足と決済判定の平均足を完全一致(旧:インジ後平滑1 vs 表示後平滑5でズレていた)。後平滑1→5で決済はやや滑らか/遅め化(意図的) / 2026-06-25:Ver9.0 確定足ガードInpConfirmClosedBar(既定ON)=エントリー時に直前確定足のWMA34も同方向dに点灯を必須化。ライブ足の途中grey→点灯した単発ブレ(フラッシュ点火/底でのダマシ)を弾く。継続は素通り=速度温存、グレー明けの一発目のみ確定1本待ち。reason24=直前確定足が未点灯 / 2026-06-28:Ver10.0(_10) 波オシレーターを本体に統合=波/シグナル/レジーム/上抜け/下抜けをbuf20-24で公開(Wave_Subは描画専用に)・MAエンジンにTMA/VWMA/ATR Adaptive/ATR Trendを追加(波で全17種対応) / エントリー新ルール:長期足が先頭に点灯(最後に点灯ならreason25で除外,InpUseLongFirst)＋Waveが同方向を最終条件(reason26,InpUseWaveTrigger)。既存フィルター(再入14/クールダウン15/確定足ガード24/平均足一致18/M15門番19,23/長期一致22)は維持 / 2026-06-29:Wave判定を長期足より前へ独立評価し3状態化(26=ウェーブ中立/27=ウェーブ上昇クロス/28=ウェーブ下降クロス,中立帯InpWaveNeutralBand)。22長期不一致・17色確認をallowガード化(エントリー判定は不変・理由の優先順位のみ整理) / 2026-06-30:buf25=5分背景方向(wmaDir)を公開。EAが段階決済モードでグレー継続/MA反転を自前計数して決済する土台(インジ再計算では保有継続中のgrayRunを積めないため) / 2026-06-30:A層(enum/MAエンジン)をDokaKotsu_Core.mqhへ移管しincludeに変更(挙動不変・置き場所のみ。Coreは MQL5\\Include\\ に配置) / 2026-07-05:ADXトレンドフィルター追加=DokaKotsu_Trend_FilterのADX(既定期間12)+EMA(50)ロジックを本体に統合(buf26=ADXState/WYSIWYG)。ADX<閾値(既定25)=グレーの時のみ最終ゲートで禁止(reason29)。方向不一致(色反転)は見ない=ラグ回避。既存グレーライン環境認識(長期/M15レンジ判定)とは別軸のトレンド終盤ノイズ除去フィルター"
#property indicator_chart_window
#property indicator_buffers 54
#property indicator_plots   11

//--- 15分足オーバーレイ: M15グレー(レンジ)
#property indicator_label1  "15分足 NORM"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDimGray  // 2026-06-22 見やすさ向上のためGray->DimGray(15分足NORM)
#property indicator_width1  5
//--- 15分足オーバーレイ: M15上昇
#property indicator_label2  "15分足 UP"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrAqua
#property indicator_width2  5
//--- 方向MA 上昇(緑)
#property indicator_label3  "MA_UP"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrLime
#property indicator_width3  5
//--- 方向MA 下降(オレンジレッド)
#property indicator_label4  "MA_DOWN"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrOrangeRed
#property indicator_width4  5
//--- 方向MA 平行(灰=グレーゾーン)
#property indicator_label5  "MA_FLAT"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrDimGray
#property indicator_width5  5
//--- SMA20 センターライン(5段階カラー)
#property indicator_label6  "長期足"
#property indicator_type6   DRAW_COLOR_LINE
#property indicator_color6  clrLightGray,clrLightSkyBlue,clrGray,clrPlum,clrMagenta
#property indicator_width6  1
//--- BUYエントリー矢印
#property indicator_label7  "ENTRY_BUY"
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrAqua
#property indicator_width7  4
//--- SELLエントリー矢印
#property indicator_label8  "ENTRY_SELL"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrRed
#property indicator_width8  4
//--- 終了マーカー(×)
#property indicator_label9  "EXIT"
#property indicator_type9   DRAW_ARROW
#property indicator_color9  clrYellow
#property indicator_width9  5

#property indicator_label10 "OVERSHOOT"
#property indicator_type10  DRAW_ARROW
#property indicator_color10 clrMagenta
#property indicator_width10 2
//--- 15分足オーバーレイ: M15下降(DeepPink)
#property indicator_label11 "15分足 DOWN"
#property indicator_type11  DRAW_LINE
#property indicator_color11 clrDeepPink
#property indicator_width11 5


//=== 入力パラメータ ==============================================
#include "DokaKotsu_Core.mqh"   // ★A層(enum/MAエンジン)はCoreへ移管。MQL5\\Include\\に配置
input group "バージョン情報（確認用）"
input string InpVersionInfo = "Ver9.0(_9) / 2026-06-25 長期線スムージング・平均足OHLC公開(前3/後5 SMMA)で表示=決済一致・buf15修正 / 2026-06-26 孤児ポジ救済=A案同期を双方向化(EA保有&インジ0なら実方向を採用→決済評価) / 2026-06-28 Ver10.0 波統合(buf20-24)・長期足が先頭・Waveトリガーをエントリー条件に追加";  // バージョン(最新確認用・変更不要)

input group "① 長期足"
input bool         InpUseLongFilter = true;                 // 長期足一致フィルター(3本が同色に揃った時だけエントリー)
input bool   InpUseLongFirst   = true;                      // 長期が先頭に点灯していることを必須にするか。true=長期が最後発(後発)ならエントリー禁止。false=順番不問(2026-07-08明確化:短中長期が同色に揃ってさえいればOK。InpUseLongFilterのみでゲート)
input ENUM_WMATYPE InpLongType      = WT_KAMA;              // 長期足のMAの種類(KAMA)
input int          InpLongPeriod    = 180;                  // 長期足の期間(180)
input int          InpLongSlopeStep   = 5;                  // 長期足: 傾き1サンプルを測る本数(旧InpLongSlopeBars)
input int          InpLongSlopeSmooth = 4;                  // 長期足: 傾きの平滑化サンプル数(直近N個の傾きを平均=スパイク一発を均す)
input double       InpLongGrayThresh  = 0.03;               // 長期足のグレー閾値(ATR正規化slope。|傾き|<これ=ほぼ水平=グレー=待機)★2026-07-08(_13)変更:0.05→0.03=1波目でグレーを早く抜けさせる
input double       InpLongHystRatio   = 1.3;                // 長期足: ヒステリシス(色に入る閾値=GrayThresh×これ。境界の青⇔グレーちらつき防止)★2026-07-08(_13)変更:1.5→1.3=同上

input group "② 15分足"
input ENUM_WMATYPE InpM15Type   = WT_KAMA;                  // Ver8/2026-06-22: 15分足MAの種類(KAMA。適応型でレンジは横ばい→グレー、トレンドで追従)
input int    InpM15Period    = 15;                          // Ver9: 15分足MAの期間(既定15)
input bool   InpUseM15Filter = true;                        // Ver8: M15一致フィルター(M15が点灯&M5と同方向の時だけエントリー)
input bool   InpM15ConfirmClosed = false;                   // 2026-06-22更新: false=M15ライブ足参照(確定待ち15分を削りエントリー前倒し。KAMAなのでフラッシュ起きにくい)。true=確定足(WMA時代のフラッシュ対策)
input int    InpM15EntryConfirm  = 1;                       // 2026-06-24: エントリーのM15確定足要求(0=ライブのみ/1=確定足が逆なら拒否/2=確定足もd必須=深夜グレーのちらつき防止)。点火はライブのまま速い。★2026-07-08(_13)変更:2→1=確定足がグレーでも拒否せず、明確な逆行のみ拒否(reason23緩和)
input double InpM15SlopeTh   = 0.05;                        // Ver8: M15のグレー判定しきい値(M5とは別。小さいほど点灯しやすい/BTで調整)
input bool   InpM15ApplyToSell = false;                     // 2026-07-08: ZigZagフィルター検証のため再度OFF(SELL方向はM15対象外)に戻す。ZigZagが効かないと判断したらtrueに戻す

input group "③ 平均足（決済用の作り）"
input int            InpHaPrePeriod  = 4;                   // 決済用平均足:前平滑化の期間(SMOOTHED)。2026-06-28 既定3→4。表示用HAインジと一致させる単一の真実
input ENUM_MA_METHOD InpHaPreMethod  = MODE_SMMA;           // 決済用平均足:前平滑化の方式(Smoothed)
input int            InpHaPostPeriod = 5;                   // 2026-06-25: 決済用平均足:後平滑化の期間(SMOOTHED)。表示と決済を一致させるため5に統一(旧1=決済前倒しは廃止)
input ENUM_MA_METHOD InpHaPostMethod = MODE_SMMA;           // Ver7: 決済用平均足:後平滑化の方式(Smoothed)

input group "④ 5分MA（方向=WMA34・背景の基準）"
input ENUM_WMATYPE InpWmaType   = WT_WMA;                   // Ver8: 方向判定MAの種類(WMAに変更)
input int          InpWmaPeriod = 34;                       // Ver8: 方向判定MAの期間(WMA34=大きく見る/ポンを無視)
input int          InpLineSmooth = 5;                       // InpLineSmooth: 表示線の平滑(本数。1=生KAMA。ロジックは生のまま線だけ滑らか)
input double InpWmaSlopeTh    = 0.10;                       // InpWmaSlopeTh: 点灯しきい値(上げるとグレー増)
input double InpWmaStickyMult = 0.3;                        // Ver8: 色の粘り(消灯=点灯×本値。小=途切れにくい=表示も判定も連続化)
input int    InpColorConfirmBars = 1;                       // InpColorConfirmBars: 色の確認本数(2→1で即エントリー=1本前倒し。flash保険はM15確定足が担保)。2=直前確定足も同色要
input bool   InpConfirmClosedBar = true;                    // 2026-06-25: 直前の確定足のWMA34も同方向点灯を必須(ライブ足の単発ブレ=フラッシュ点火を弾く)。継続は即時/グレー明けの一発目だけ確定1本待ち。reason24

input group "⑤ WAVE（波）"
input ENUM_WMATYPE InpWaveMaType = WT_KAMA;                 // 波:MAの種類
input int    InpWaveFast   = 6;                             // 波:早い線の期間 (2026-07-02: 14→6)
input int    InpWaveSlow   = 24;                            // 波:遅い線EMA期間 (2026-07-02: 34→24)
input int    InpWaveSignal = 9;                             // 波:シグナル平滑 (2026-07-02: 10→9)
input double InpWaveNeutralBand = 0.03;                     // 波:中立帯(|波-シグナル|がこれ以下は中立。上昇/下降クロスと区別)
input bool   InpUseWaveTrigger = true;                      // 新: Waveが同方向(波線>シグナル=上/<シグナル=下)を最終条件にする

input group "⑤b ADXトレンドフィルター(2026-07-05追加: トレンド終盤ノイズ除去)"
input bool   InpUseAdxFilter    = true;                     // ADXグレー(トレンド終盤の弱い波)ならエントリー禁止。全フィルターの最後段で判定

//--- ★2026-07-08追加: スパイク(急変)フィルター(DokaKotsu_Spikek_Filterと同じ考え方を本体に内蔵)
input bool   InpUseSpikeExit     = true;    // スパイク面積が閾値以上で保有中なら決済する
input double InpSpikeAtrMultiplier = 2.0;   // スパイク検出用ATR倍率(スイング確定に必要な逆行幅)
input double InpSpikeAreaThresh  = 300.0;   // スパイクとみなす面積(値幅×継続バー数)の閾値
input bool   InpUseSpikeEntryBan = true;    // スパイク決済後、平均足が変わるまで新規エントリー禁止
input bool   InpUseSpikeAdxBan   = true;    // ★2026-07-10追加: スパイク面積300超→ADX色が変わるまで新規禁止(ポジション有無を問わない。弱5波/深夜ダラダラ対策)

input group "⑥ 相場レジーム判定(2026-07-10追加: スクイーズ/トレンドの二層構造)"
input bool   InpUseRegimeSystem = true;    // レジーム判定を使う。ON時、スクイーズ中はZigZag/スパイク関連ゲートより先に一括で新規禁止(reason40)
input double InpRegimeBBMult    = 1.8;     // レジーム判定用ボリンジャー偏差(★2026-07-10c修正: 1.5は緩めすぎ=閾値sd/rangema<1.0で常時圧縮化しトレンド中も解除できないバグ。1.8で閾値0.83=旧来0.75よりやや緩い程度に是正)
input double InpRegimeKCMult    = 1.5;     // レジーム判定用ケルトナー幅(既存InpKCMultと同値スタートだが別変数)
input int    InpAdxPeriod       = 12;                       // ADX期間
input int    InpAdxEmaPeriod    = 50;                       // ADX用EMA期間(方向判定はここでは使わず、ADX自体の強弱のみゲートに使用)
input int    InpAdxSlopeLookback= 3;                        // EMAスロープ計算の遡り本数(DokaKotsu_Trend_Filterと同じ定義)
input double InpAdxThreshold    = 25.0;                     // ADX閾値。これ未満=グレー(方向感の弱いトレンド終盤ノイズ)と判定して禁止。色反転(方向不一致)は見ない=ラグ回避
input int    InpAdxConfirmBars  = 2;                        // 2026-07-06追加: ADXが非グレーで連続この本数(直前確定足も含む)続いていることを要求。1=当足のみ(旧仕様)。前足グレー→当足だけ点灯という即時フリップを弾く(reason36)

input group "⑤c ZigZag弱波/天底近接フィルター(2026-07-06追加・実験)"
input bool   InpUseZzFilter     = true;                     // 2026-07-08有効化: M15フィルターと入れ替えでZigZag弱5波フィルターを検証。効かないと判断したらfalseに戻しM15を再度ON
input int    InpZzAtrPeriod     = 14;                        // ZigZag_ATR側のATR期間(チャート上の表示インジと必ず合わせる)
input double InpZzAtrMultiplier = 2.0;                       // ZigZag_ATR側のATR倍率(チャート上の表示インジと必ず合わせる)
input int    InpZzMaxBarsBack   = 2000;                      // ZigZag_ATR側の再計算上限本数(表示インジと合わせる)
input double InpZzMinStrength   = 40.0;                      // 残存強度%(100=直近確定した天/底のその場・0=その前の確定点まで到達)がこれ未満なら禁止=反対側到達間近(弱5波)

input group "⑥ 決済"
input int    InpSmaPeriod    = 10;                          // SMA期間(決済の基準線=SMA10)
input int    InpSma2ndPeriod = 1;                           // 二重平滑の期間(1=平滑なし → 素のSMA10)
input bool   InpHaPriorityExit = true;                      // Ver8/2026-06-22 案B: ON=平均足の色反転を最優先で即決済＋保険(MA急反転/グレー化)。OFF=旧案C/案A(BT比較)。既定ON
input int    InpExitGrayConfirmBars = 2;                    // Ver8: MA決済はグレーがこの本数“続いたら”実行(1本だけのチラつき=中間色は無視)。1=即時
input bool   InpExitHybridC = true;                         // Ver8 案C: 平均足が逆転＋価格がSMA中心線を割込みで早決済(MAグレーを待たず本物の反転だけ早逃げ)。OFF=案A(MAグレー/反転のみ)

input group "⑦ その他 ─ エントリー制御/フィルター"
input int    InpCooldownBars  = 5;                          // 決済後この本数は新規エントリーを出さない(調整波回避・EAから移管)。グレー出現で即解除
input bool   InpAlsoTakePullback = false;                   // 2026-06-22: OFF=背景色と平均足が一致時だけ入る(平均足が逆色=reason18で見送り。天井づかみ防止)。true=平均足無視で調整波も狙う
input bool   InpFilM1Spike     = false;                     // ①M1スパイク要求(だまし対策・タイミング)※基本版はOFF
input bool   InpFilSqueeze     = false;                     // ②圧縮中は弾く(スクイーズのダマシ対策)
input bool   InpFilOvershoot   = false;                     // ③オーバーシュートを弾く(急変飛び乗り対策)
input bool   InpRequireEmaColit = false;                    // ④方向MAとEMA同時点灯
input bool   InpAlert          = true;                      // エントリー/終了でアラート

input group "⑦ その他 ─ 出来高フィルター"
input bool   InpUseVolFilter  = false;                      // 出来高フィルターを使うか(薄商いの足では新規を出さない)
input int    InpVolMaPeriod   = 20;                         // 出来高の移動平均本数(M5)
input double InpVolMinRatio    = 0.5;                       // 現在の出来高がこの倍率×平均を下回ったら薄商い=見送り

input group "⑦ その他 ─ スパイク/スクイーズ"
input double InpSpikeTh       = 2.0;                        // M5でEMA10が点灯(マゼンタ)する収束度
input double InpM1SpikeTh      = 2.0;                       // M1スパイクの収束本数
input int    InpM1Bars         = 30000;                     // 取得するM1本数(フィルター①ON時)
input double InpBBMult          = 2.0;                      // スクイーズ判定用 ボリンジャー偏差(フィルター②ON時)
input double InpKCMult          = 1.5;                      // ⑦圧縮ケルトナー幅
input bool   InpLightFromM1    = true;                      // M1スパイクの足もEMA10をマゼンタにする(点灯と矢印を一致)

input group "⑦ その他 ─ ATR適応・MAMA（全MA共有）"
input double InpAtrFastA      = 0.6;                        // ATR適応:速い時のα(0〜1・大きいほど速い)
input double InpAtrSlowA      = 0.05;                       // ATR適応:遅い時のα(0〜1・小さいほど滑らか)
input int    InpAtrRefPeriod  = 50;                         // ATR適応:ATR平均/変化率の参照期間
input bool   InpHighVolFaster = true;                       // ATR Adaptive:高ボラで速くするか(既定false=高ボラで遅く)
input double InpMamaFast      = 0.5;                        // MAMA:FastLimit(速さ上限)
input double InpMamaSlow      = 0.05;                       // MAMA:SlowLimit(速さ下限)

input group "⑦ その他 ─ EA連携・旧設定"
input bool   InpSyncEAPos     = true;                       // ライブ足で実ポジと同期(EAがノーポジなら指標の保有も解除=コード20の空転防止)
input long   InpEAMagic       = 20260606;                   // 同期対象EAのマジックナンバー(EA側と一致させる)
input ENUM_WMATYPE InpEmaType   = WT_KAMA;                  // (旧・引き金/スパイク線。現在は表示をM15に転用したため未使用)
input int    InpEmaPeriod    = 10;                          // (旧・未使用)

input group "背景色・表示（描画）"
input bool   InpShowBG     = true;                          // 背景色を表示する
input color  InpColorBull  = clrGray;                       // 上昇の背景色 (Gray)
input color  InpColorRange = C'34,34,34';                   // 中立(グレー)の背景色 (#222222)
input color  InpColorBear  = C'34,116,128';                 // 下降の背景色 (RGB 34,116,128)
input bool   InpShowInfoLabel = false;                      // チャートにファイル名/バージョンのラベルを出すか(既定OFF=非表示)
input int    InpColorHoldBars = 2;                          // Ver7③ 表示の色保持(背景/方向MA線):新色がこの本数続くまで前色を保持(1=保持なし)。表示のみ・エントリー不変
input int    InpGrayHoldBars = 3;                           // Ver7③ トレンド内の一時グレーをこの本数まで前色で橋渡し(背景の黒帯を埋める)。本物のレンジ(この本数以上の連続グレー)はグレー表示。表示のみ
input int    InpBgLookback = 800;                           // 背景を塗る本数(直近)

input group "線幅（描画）"
input int    InpW_MaUp        = 5;                          // MA_UP   の幅(0〜5、0=非表示)
input int    InpW_MaDown      = 5;                          // MA_DOWN の幅(0〜5、0=非表示)
input int    InpW_MaFlat      = 5;                          // MA_FLAT の幅(0〜5、0=非表示)
input int    InpW_M15Norm    = 5;                           // 15分足 NORM(M15グレー時)の幅(0〜10、0=非表示)
input int    InpW_M15Up       = 5;                          // 15分足 UP(M15上昇)の幅(0〜10、0=非表示)
input int    InpW_M15Down     = 5;                          // 15分足 DOWN(M15下降)の幅(0〜10、0=非表示)
input int    InpW_Sma20       = 5;                          // 長期足 の幅(0〜5、0=非表示)


//=== バッファ ====================================================
double BufEmaNorm[];
double BufEmaSpike[];
double BufWmaUp[];
double BufWmaDown[];
double BufWmaFlat[];
double BufSma20[];
double BufSma20Col[];    // SMA20の5段階カラーインデックス
double BufBuy[];
double BufSell[];
double BufExit[];
double BufOvershoot[];   // オーバーシュート(急変・行き過ぎ)印
double BufReason[];      // ★エントリー理由コード(描画なし・EAがCopyBuffer(12)で読む)
double BufM15Down[];     // ★Ver8: 15分足 DOWN(M15下降)のオーバーレイ線(プロット11=buf11)
double BufM15State[];    // ★Ver8: 15分足の状態(0=グレー/1=上昇/-1=下降)。描画なし・EAがCopyBuffer(13)で読む
double BufHaState[];     // ★2026-06-22: 平均足の色(1=上昇/-1=下降)。描画なし・EAがCopyBuffer(14)で読む
double BufLongState[];   // ★2026-06-24: 長期足の状態(0=グレー/1=上昇/-1=下降)。描画なし・EAがCopyBuffer(15)で読む
double BufHaOpen[];      // ★2026-06-25: 平均足 始値(後平滑後)。描画なし・表示用HAインジがCopyBuffer(16)で参照
double BufHaHigh[];      // ★2026-06-25: 平均足 高値(後平滑後)。CopyBuffer(17)
double BufHaLow[];       // ★2026-06-25: 平均足 安値(後平滑後)。CopyBuffer(18)
double BufHaClose[];     // ★2026-06-25: 平均足 終値(後平滑後)。CopyBuffer(19)。色は(close>=open)で表示インジ側が判定
                         //   1=BUY発生 2=SELL発生 10=グレー 11=M1無し 12=圧縮
                         //   13=オーバーシュート 14=再エントリーロック 20=保有中 30=EXIT
                         //   35=ZigZag弱波(反対側到達間近・2026-07-06) 36=ADX継続未達(直前グレーからの即時フリップ・2026-07-06)

//=== アラート重複防止 ============================================
datetime g_lastAlertTime = 0;

double BufWaveVal[];     // ★波: (早MA-遅EMA)/ATR。描画なし・Wave_SubがCopyBuffer(20)で読む
double BufWaveSig[];     // ★波: シグナル（波のEMA）。CopyBuffer(21)
double BufWaveReg[];     // ★波: 背景レジーム(1=上昇/0=レンジ/-1=下降)。CopyBuffer(22)
double BufWaveUp[];      // ★波: 上抜けクロス位置（値/EMPTY）。CopyBuffer(23)
double BufWaveDn[];      // ★波: 下抜けクロス位置（値/EMPTY）。CopyBuffer(24)
double BufBgDir[];       // ★5分背景方向(wmaDir=決済が使う背景)。EAがグレー/反転決済で読む。CopyBuffer(25)
double BufAdxState[];    // ★2026-07-05: ADXトレンド状態(0=グレー/1=上昇/2=下降)。描画なし・EAがCopyBuffer(26)で読む
double BufZzState[];     // ★2026-07-06: ZigZag残存強度%(0〜100。対象外/データ不足時は100)。描画なし・EAがCopyBuffer(27)で読む
//--- ★2026-07-07(_13) 未使用ロジック探索用のcontextバッファ群。判定(BufBuy/BufSell/BufExit)には一切使用しない。
//    EAがエントリー/決済のたび読み取り、entry_snapshotのcontextセクションとして記録するだけの「観測専用」データ。
double BufRsi[];             // RSI(14)。CopyBuffer(28)
double BufMacdMain[];        // MACDメイン(12,26,9)。CopyBuffer(29)
double BufMacdSignal[];      // MACDシグナル。CopyBuffer(30)
double BufMacdHist[];        // MACDヒストグラム(main-signal)。CopyBuffer(31)
double BufGmmaShortAngle[];  // ★代理:EMA10(ema[])のATR正規化傾き。真の6本GMMA平均ではない簡易版。CopyBuffer(32)
double BufGmmaLongAngle[];   // ★代理:長期足MA(longLine[],既定KAMA180)のATR正規化傾き。CopyBuffer(33)
double BufEmaDist[];         // 価格とEMA10のATR正規化乖離(符号付き)。CopyBuffer(34)
double BufMaSlope[];         // ベースMA(方向判定用)のATR正規化傾き 生値。CopyBuffer(35)
double BufHighUpdate[];      // 直近20本高値更新フラグ(1/0)。CopyBuffer(36)
double BufLowUpdate[];       // 直近20本安値更新フラグ(1/0)。CopyBuffer(37)
double BufRangeWidth[];      // 直近20本のレンジ幅(ATR倍率)。CopyBuffer(38)
double BufPrevDayHigh[];     // 前日高値(価格)。CopyBuffer(39)
double BufPrevDayLow[];      // 前日安値(価格)。CopyBuffer(40)
//--- ★2026-07-09追加: スパイク決済(2026-07-08導入)の面積実測値をEAへ公開する。
//    thisBarSpikeAreaはOnCalculate内のローカル変数のままだと決済発動の瞬間しかAlertに出ず、
//    EAからは読めなかった(=「スパイクが有効だったか」を後日検証できなかった)。
//    スイングが確定した足では常にこの値を書く(InpSpikeAreaThresh未満の「不発」スイングも含む)ので、
//    閾値300が適切かどうかの検証にそのまま使える。
double BufSpikeArea[];       // スパイク面積(値幅×継続バー数)。スイング確定足のみ非ゼロ。CopyBuffer(41)
//--- ★2026-07-09追加: BufSpikeAreaは確定した1本の足でしか値が立たない単発パルスのため、
//    「直前にスパイクがあったか」を見たいエントリー側からは、確定と同じ足でない限りほぼ0.0しか
//    見えなかった(=エントリー判断との相関がほぼ取れない)。直近値を次のスパイクまで保持する
//    バッファと、経過本数バッファを追加し、何本前にどれくらいの面積のスパイクがあったかを
//    常に読めるようにする。
double BufSpikeAreaLast[];   // 直近に確定したスパイク面積(次のスパイクまで保持)。CopyBuffer(42)
double BufSpikeBarsSince[];  // 直近スパイク確定からの経過本数(未観測=-1)。CopyBuffer(43)
//--- ★2026-07-09追加: 「勘に頼らない敗因分析」の残項目(グレーゾーン閾値距離/再入クールダウン/Wave個別線)
double BufCooldownLeft[];      // 再入クールダウン残り本数(0=解除)。CopyBuffer(44)
double BufWmaSlopeDist[];      // ベースMA: |slope|-thOn(正=色の中/負=グレー側,境界までの距離)。CopyBuffer(45)
double BufLongSlopeSmoothed[]; // 長期MA: 平滑化後の傾き実値(色判定に使う値そのもの)。CopyBuffer(46)
double BufLongSlopeDist[];     // 長期MA: |平滑化傾き|-InpLongGrayThresh(同上、長期版)。CopyBuffer(47)
double BufWaveFastRaw[];       // Wave早い線(WMA6相当)の生値(価格スケール)。CopyBuffer(48)
double BufWaveSlowRaw[];       // Wave遅い線(EMA24相当)の生値(価格スケール)。CopyBuffer(49)
//--- ★2026-07-10追加: スパイク面積300超→ADX色が変わるまで新規禁止(弱5波/深夜ダラダラ対策)の診断用。
//    判定ロジック自体はスパイク検出部で直接BufAdxState等を参照して行う(この3本は観測専用・WYSIWYG/絶対ルール継続遵守)。
double BufSpikeAdxBanActive[];      // このバーで本ルールにより新規エントリーが禁止中か(1/0)。CopyBuffer(50)
double BufSpikeAdxBanTriggerArea[]; // 直近にこのルールをトリガーしたスパイク面積(次のトリガーまで保持)。CopyBuffer(51)
double BufSpikeAdxBanBarsSince[];   // 直近トリガーからの経過本数(未観測=-1)。禁止の実効継続本数の把握に使う。CopyBuffer(52)
//--- ★2026-07-10追加: 相場レジーム判定(0=トレンド/1=スクイーズ)。EAがCopyBuffer(53)で読む。
//    トリガー=BB×KC圧縮(緩め既定)、解除=長期・M15の両方が非グレーになった瞬間(遅くてもよい/ダマシに強い側)。
double BufRegime[];                 // 相場レジーム(0=トレンド/1=スクイーズ)。CopyBuffer(53)
int    hWave = INVALID_HANDLE;  // ★波: 早い線MAハンドル（標準型のみ。配列計算型はINVALID）
int hEMA, hSMA, hWMA, hATR;          // M5(チャート足)
int hM15, hAtrM15;                    // ★Ver8: 15分足オーバーレイ(FRAMA8)+M15 ATR
int hKAMA=-1, hVIDYA=-1, hFRAMA=-1;  // 適応型MA(標準関数)
int hLong=-1;                        // ★Ver8.3: 長期足(M5・既定KAMA360)
int hEMA1, hSMA1, hATR1;             // M1
int hAdx=INVALID_HANDLE, hAdxEma=INVALID_HANDLE;   // ★2026-07-05: ADXトレンドフィルター用(ADX期間12・EMA期間50)
int hZigZag=INVALID_HANDLE;                        // ★2026-07-06: ZigZag_ATR(iCustom)ハンドル。チャート表示との整合確認用(ロジックは下のhZzAtrで内部複製)
int hZzAtr=INVALID_HANDLE;                         // ★2026-07-06: ZigZag判定用ATR(InpZzAtrPeriod)。ZigZag_ATR.mq5と同じ式を本体内で複製計算するため使用
//--- ★2026-07-07(_13) context専用ハンドル(判定には使わない・観測のみ)
int hRsi  = INVALID_HANDLE;                        // RSI(14)
int hMacd = INVALID_HANDLE;                        // MACD(12,26,9)



//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 指定した種類・期間のMAハンドルを返す(引き金/スパイク線用)       |
//|   標準関数で出せる型(EMA/SMA/WMA/SMMA/KAMA/VIDYA/FRAMA)に対応。   |
//|   TMA/VWMA/ATR系を選んだ時は当面EMAで代替(必要なら後日対応)。    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| 1本の移動平均値(配列srcのpos位置・period本・方式)。平均足平滑用。 |
//|   配列は時系列昇順(0=古い)。period<=1 で平滑なし。               |
//+------------------------------------------------------------------+
//--- A層(MAValue/MakeMA/LWMAat/Calc_*/MakeWaveHandle/enum)はDokaKotsu_Core.mqhへ移管 ---

//+------------------------------------------------------------------+
//| 背景色(backend_1統合)用                                          |
//+------------------------------------------------------------------+
const string PREFIX_BG = "BG_";
const double BG_TOP = 10000000.0;   // 背景四角の上端(全銘柄をほぼカバー)
const double BG_BOT = 0.0;
void DrawBG(const datetime t1,const datetime t2,const color c)
{
   string obj=PREFIX_BG+IntegerToString((int)t1);
   if(ObjectFind(0,obj)<0)
   {
      ObjectCreate(0,obj,OBJ_RECTANGLE,0,t1,BG_TOP,t2,BG_BOT);
      ObjectSetInteger(0,obj,OBJPROP_BACK,true);     // ローソクの後ろ
      ObjectSetInteger(0,obj,OBJPROP_FILL,true);     // 塗りつぶし
      ObjectSetInteger(0,obj,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,obj,OBJPROP_HIDDEN,true);
   }
   ObjectSetInteger(0,obj,OBJPROP_COLOR,c);          // 色は毎回更新
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ★Ver8: プロットの線幅を適用。0以下=非表示(DRAW_NONE)。           |
//+------------------------------------------------------------------+
void ApplyPlotWidth(int plot, int w, int drawType)
{
   if(w <= 0)
      PlotIndexSetInteger(plot, PLOT_DRAW_TYPE, DRAW_NONE);   // 非表示
   else
   {
      PlotIndexSetInteger(plot, PLOT_DRAW_TYPE, drawType);
      PlotIndexSetInteger(plot, PLOT_LINE_WIDTH, w);
   }
}

int OnInit()
{
   SetIndexBuffer(0, BufEmaNorm,  INDICATOR_DATA);
   SetIndexBuffer(1, BufEmaSpike, INDICATOR_DATA);
   SetIndexBuffer(2, BufWmaUp,    INDICATOR_DATA);
   SetIndexBuffer(3, BufWmaDown,  INDICATOR_DATA);
   SetIndexBuffer(4, BufWmaFlat,  INDICATOR_DATA);
   SetIndexBuffer(5, BufSma20,    INDICATOR_DATA);
   SetIndexBuffer(6, BufSma20Col, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(7, BufBuy,      INDICATOR_DATA);
   SetIndexBuffer(8, BufSell,     INDICATOR_DATA);
   SetIndexBuffer(9, BufExit,     INDICATOR_DATA);
   SetIndexBuffer(10, BufOvershoot, INDICATOR_DATA);
   SetIndexBuffer(11, BufM15Down,  INDICATOR_DATA);        // ★15分足 DOWN(プロット11)
   SetIndexBuffer(12, BufReason,  INDICATOR_CALCULATIONS); // ★描画しない・EA読み取り専用(番号が11→12に移動)
   SetIndexBuffer(13, BufM15State, INDICATOR_CALCULATIONS); // ★Ver8: 15分足状態(EAがbuf13で読む)
   SetIndexBuffer(14, BufHaState,  INDICATOR_CALCULATIONS); // ★2026-06-22: 平均足の色(EAがbuf14で読む)
   SetIndexBuffer(15, BufLongState,INDICATOR_CALCULATIONS); // ★2026-06-24: 長期足の状態(EAがbuf15で読む)
   SetIndexBuffer(16, BufHaOpen,   INDICATOR_CALCULATIONS); // ★2026-06-25: 平均足 始値(表示用HAインジが参照)
   SetIndexBuffer(17, BufHaHigh,   INDICATOR_CALCULATIONS); // ★2026-06-25: 平均足 高値
   SetIndexBuffer(18, BufHaLow,    INDICATOR_CALCULATIONS); // ★2026-06-25: 平均足 安値
   SetIndexBuffer(19, BufHaClose,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(20, BufWaveVal, INDICATOR_CALCULATIONS); // ★波: 値
   SetIndexBuffer(21, BufWaveSig, INDICATOR_CALCULATIONS); // ★波: シグナル
   SetIndexBuffer(22, BufWaveReg, INDICATOR_CALCULATIONS); // ★波: レジーム
   SetIndexBuffer(23, BufWaveUp,  INDICATOR_CALCULATIONS); // ★波: 上抜け
   SetIndexBuffer(24, BufWaveDn,  INDICATOR_CALCULATIONS); // ★波: 下抜け // ★2026-06-25: 平均足 終値
   SetIndexBuffer(25, BufBgDir,   INDICATOR_CALCULATIONS); // ★5分背景方向(wmaDir)=EAの決済(グレー/反転)用
   SetIndexBuffer(26, BufAdxState,INDICATOR_CALCULATIONS); // ★2026-07-05: ADXトレンド状態(EAがbuf26で読む)
   SetIndexBuffer(27, BufZzState, INDICATOR_CALCULATIONS); // ★2026-07-06: ZigZag残存強度%(EAがbuf27で読む)
   //--- ★2026-07-07(_13) context専用(判定に使わない・観測のみ)
   SetIndexBuffer(28, BufRsi,            INDICATOR_CALCULATIONS);
   SetIndexBuffer(29, BufMacdMain,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(30, BufMacdSignal,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(31, BufMacdHist,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(32, BufGmmaShortAngle, INDICATOR_CALCULATIONS);
   SetIndexBuffer(33, BufGmmaLongAngle,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(34, BufEmaDist,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(35, BufMaSlope,        INDICATOR_CALCULATIONS);
   SetIndexBuffer(36, BufHighUpdate,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(37, BufLowUpdate,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(38, BufRangeWidth,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(39, BufPrevDayHigh,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(40, BufPrevDayLow,     INDICATOR_CALCULATIONS);
   SetIndexBuffer(41, BufSpikeArea,      INDICATOR_CALCULATIONS); // ★2026-07-09: スパイク面積実測値(EAがbuf41で読む)
   SetIndexBuffer(42, BufSpikeAreaLast,  INDICATOR_CALCULATIONS); // ★2026-07-09: 直近スパイク面積(保持型,buf42)
   SetIndexBuffer(43, BufSpikeBarsSince, INDICATOR_CALCULATIONS); // ★2026-07-09: 直近スパイクからの経過本数(buf43)
   SetIndexBuffer(44, BufCooldownLeft,      INDICATOR_CALCULATIONS); // ★2026-07-09: 再入クールダウン残り本数(buf44)
   SetIndexBuffer(45, BufWmaSlopeDist,      INDICATOR_CALCULATIONS); // ★2026-07-09: ベースMA閾値距離(buf45)
   SetIndexBuffer(46, BufLongSlopeSmoothed, INDICATOR_CALCULATIONS); // ★2026-07-09: 長期MA平滑化傾き(buf46)
   SetIndexBuffer(47, BufLongSlopeDist,     INDICATOR_CALCULATIONS); // ★2026-07-09: 長期MA閾値距離(buf47)
   SetIndexBuffer(48, BufWaveFastRaw,       INDICATOR_CALCULATIONS); // ★2026-07-09: Wave早い線生値(buf48)
   SetIndexBuffer(49, BufWaveSlowRaw,       INDICATOR_CALCULATIONS); // ★2026-07-09: Wave遅い線生値(buf49)
   SetIndexBuffer(50, BufSpikeAdxBanActive,      INDICATOR_CALCULATIONS); // ★2026-07-10: スパイクADX禁止 有効中フラグ(buf50)
   SetIndexBuffer(51, BufSpikeAdxBanTriggerArea, INDICATOR_CALCULATIONS); // ★2026-07-10: 直近トリガー面積(保持型,buf51)
   SetIndexBuffer(52, BufSpikeAdxBanBarsSince,   INDICATOR_CALCULATIONS); // ★2026-07-10: 直近トリガーからの経過本数(buf52)
   SetIndexBuffer(53, BufRegime,                 INDICATOR_CALCULATIONS); // ★2026-07-10: 相場レジーム(0=トレンド/1=スクイーズ,buf53)

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(5, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   // SMA20(plot5)を5段階カラーに
   PlotIndexSetInteger(5, PLOT_COLOR_INDEXES, 5);
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 0, clrAqua);          // 強い上昇
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 1, clrLightSkyBlue);  // 上昇
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 2, clrGray);          // レンジ
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 3, clrPlum);          // 下降(薄マゼンタ)
   PlotIndexSetInteger(5, PLOT_LINE_COLOR, 4, clrMagenta);       // 強い下降
   PlotIndexSetInteger(6, PLOT_ARROW, 233);
   PlotIndexSetInteger(7, PLOT_ARROW, 234);
   PlotIndexSetInteger(8, PLOT_ARROW, 251);            // EXIT(×印)
   PlotIndexSetInteger(8, PLOT_LINE_WIDTH, 5);         // 決済マークを大きく
   PlotIndexSetInteger(9, PLOT_ARROW, 251);            // オーバーシュート印
   PlotIndexSetInteger(9, PLOT_LINE_COLOR, clrMagenta);
   PlotIndexSetInteger(9, PLOT_LINE_WIDTH, 2);
   PlotIndexSetDouble(6, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(7, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(8, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(9, PLOT_EMPTY_VALUE, 0.0);

   // ★Ver8: プロット幅を入力から適用(0=非表示=DRAW_NONE)。ラベルもM15用に。
   ApplyPlotWidth(0, InpW_M15Norm,  DRAW_LINE);        // 15分足 NORM
   ApplyPlotWidth(1, InpW_M15Up,    DRAW_LINE);        // 15分足 UP
   ApplyPlotWidth(2, InpW_MaUp,     DRAW_LINE);        // MA_UP
   ApplyPlotWidth(3, InpW_MaDown,   DRAW_LINE);        // MA_DOWN
   ApplyPlotWidth(4, InpW_MaFlat,   DRAW_LINE);        // MA_FLAT
   ApplyPlotWidth(5, InpW_Sma20,    DRAW_COLOR_LINE);  // SMA20_CENTER
   ApplyPlotWidth(10, InpW_M15Down, DRAW_LINE);        // 15分足 DOWN
   PlotIndexSetString(0,  PLOT_LABEL, "15分足 NORM");
   PlotIndexSetString(1,  PLOT_LABEL, "15分足 UP");
   PlotIndexSetString(10, PLOT_LABEL, "15分足 DOWN");
   PlotIndexSetDouble(10, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   // チャート足(M5想定)
   hEMA = MakeMA(InpEmaType, InpEmaPeriod, _Period);   // 引き金/スパイク線(種類選択)
   hSMA = iMA(_Symbol, _Period, InpSmaPeriod, 0, MODE_SMA,  PRICE_CLOSE);
   // WMA(方向判定線)は種類選択。SMA/WMA/SMMAはiMA、TMA/VWMAは自前計算。
   ENUM_MA_METHOD wmode = MODE_LWMA;
   if(InpWmaType==WT_SMA)       wmode = MODE_SMA;
   else if(InpWmaType==WT_WMA)  wmode = MODE_LWMA;
   else if(InpWmaType==WT_SMMA) wmode = MODE_SMMA;
   else if(InpWmaType==WT_EMA)  wmode = MODE_EMA;  // ★修正: 従来は下のelseでSMAになっていた
   else                         wmode = MODE_SMA;  // TMA/VWMA/KAMA/VIDYA/FRAMA/ATRは仮(後で上書き計算)
   hWMA = iMA(_Symbol, _Period, InpWmaPeriod, 0, wmode, PRICE_CLOSE);
   // 適応型MA(標準関数)。選択時のみ実際に使う
   if(InpWmaType==WT_KAMA)
      hKAMA = iAMA(_Symbol, _Period, InpWmaPeriod, 2, 30, 0, PRICE_CLOSE);
   if(InpWmaType==WT_VIDYA)
      hVIDYA = iVIDyA(_Symbol, _Period, 9, 12, 0, PRICE_CLOSE);
   if(InpWmaType==WT_FRAMA)
      hFRAMA = iFrAMA(_Symbol, _Period, InpWmaPeriod, 0, PRICE_CLOSE);
   hATR = iATR(_Symbol, _Period, 14);
   // M1(引き金用)
   hEMA1 = MakeMA(InpEmaType, InpEmaPeriod, PERIOD_M1); // M1引き金線(種類選択)
   hSMA1 = iMA(_Symbol, PERIOD_M1, InpSmaPeriod, 0, MODE_SMA, PRICE_CLOSE);
   hATR1 = iATR(_Symbol, PERIOD_M1, 14);
   // ★2026-07-05: ADXトレンドフィルター(M5・DokaKotsu_Trend_Filterと同一計算をWYSIWYGのため本体に統合)
   hAdx    = iADX(_Symbol, _Period, InpAdxPeriod);
   hAdxEma = iMA(_Symbol, _Period, InpAdxEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   // ★Ver8: 15分足オーバーレイ用(種類/期間は入力。既定FRAMA8)
   hM15    = MakeMA(InpM15Type, InpM15Period, PERIOD_M15);
   hLong   = MakeMA(InpLongType, InpLongPeriod, _Period); // ★Ver8.3: 長期足(M5・KAMA360)
   hAtrM15 = iATR(_Symbol, PERIOD_M15, 14);
   hWave   = MakeWaveHandle(InpWaveMaType, InpWaveFast); // ★波: 早い線MA
   // ★2026-07-06: ZigZag_ATR(iCustom)。InpUseZzFilterがOFFでも一応生成しておく(実行中にONへ切替えても即対応できるように)
   hZigZag = iCustom(_Symbol, _Period, "ZigZag_ATR", InpZzAtrPeriod, InpZzAtrMultiplier, InpZzMaxBarsBack);
   // ★2026-07-06: ZigZag判定ロジック用ATR。ZigZag_ATR.mq5と同一式(ATR×倍率)を本体内で複製し、
   //   バッファ位置ベースの参照による未来参照(リペイント/先読み)を避けるため、判定は自前で再計算する。
   hZzAtr  = iATR(_Symbol, _Period, InpZzAtrPeriod);
   //--- ★2026-07-07(_13) context専用(判定には使わない・観測のみ)
   hRsi  = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   hMacd = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);

   if(hEMA==INVALID_HANDLE || hSMA==INVALID_HANDLE || hWMA==INVALID_HANDLE ||
      hATR==INVALID_HANDLE || hEMA1==INVALID_HANDLE || hSMA1==INVALID_HANDLE ||
      hATR1==INVALID_HANDLE || hAdx==INVALID_HANDLE || hAdxEma==INVALID_HANDLE ||
      hZzAtr==INVALID_HANDLE)
   {
      Print("ハンドル作成失敗");
      return(INIT_FAILED);
   }
   if(hZigZag==INVALID_HANDLE)
   {
      Print("ZigZag_ATRハンドル作成失敗(ファイルがIndicators配下にあるか確認)。InpUseZzFilterはfalse動作のまま続行");
   }
   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu_indicator_13"); // 2026-07-08修正: ファイル名と一致させ括弧内の旧名(_11)表示を解消

   // チャート上の情報ラベル(ファイル名/バージョン)。既定OFF=他表示と重なるため非表示。
   string vname = "DK2_version_label";
   if(InpShowInfoLabel)
   {
      if(ObjectFind(0, vname) < 0)
         ObjectCreate(0, vname, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, vname, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, vname, OBJPROP_XDISTANCE, 5);
      ObjectSetInteger(0, vname, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, vname, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, vname, OBJPROP_FONTSIZE, 9);
      ObjectSetString (0, vname, OBJPROP_TEXT,
         StringFormat("DokaKotsu indicator_9  %s  (build %s)", DK_VERSION, DK_BUILD));
      ObjectSetInteger(0, vname, OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectDelete(0, vname);   // 既存ラベルがあれば消す
   }

   // ★背景(BG_)の掃除は「起動時」に行う(終了時ではない)。
   //   理由: EAの iCustom 解放・再コンパイルで OnDeinit が走っても背景を消さないため。
   //   背景はインジの責務。起動時に古い物を消し、直後の OnCalculate で塗り直す。
   {
      int _t = ObjectsTotal(0, -1, -1);
      for(int _i = _t - 1; _i >= 0; _i--)
      {
         string _nm = ObjectName(0, _i, -1, -1);
         if(StringFind(_nm, PREFIX_BG) == 0) ObjectDelete(0, _nm);
      }
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // ★背景(BG_)とバージョンラベルは終了時に消さない。
   //   EAの iCustom 解放/再コンパイルでこの OnDeinit が走っても背景を残すため
   //   (背景がEAに連動して消える問題の排除)。古い背景の掃除は OnInit 側で行う。
   if(hZigZag != INVALID_HANDLE) IndicatorRelease(hZigZag);   // ★2026-07-06
}

//+------------------------------------------------------------------+
//| ★A案:対象EA(InpEAMagic)の実ポジ保有有無を返す                    |
//|   PositionsTotalを走査し、_Symbol かつ 指定マジックがあれば true。|
//|   ライブ足の同期判定にのみ使用(過去足は純シミュレーション)。     |
//+------------------------------------------------------------------+
bool EAHasPosition()
{
   int total = PositionsTotal();
   for(int k=0; k<total; k++)
   {
      ulong tk = PositionGetTicket(k);   // インデックスで選択しチケット取得
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC)==InpEAMagic)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| ★2026-06-26:対象EA(InpEAMagic)の実ポジ方向を返す               |
//|   +1=買い / -1=売り / 0=無し。孤児ポジ救済(A案同期の双方向化)で |
//|   指標の仮想ポジをEAの実方向へ合わせるために使用。ライブ足のみ。   |
//+------------------------------------------------------------------+
int EAPosDir()
{
   int total = PositionsTotal();
   for(int k=0; k<total; k++)
   {
      ulong tk = PositionGetTicket(k);
      if(tk==0) continue;
      if(PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (long)PositionGetInteger(POSITION_MAGIC)==InpEAMagic)
         return (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY) ? 1 : -1;
   }
   return 0;
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
   int need = MathMax(MathMax(MathMax(MathMax(MathMax(InpEmaPeriod, InpSmaPeriod), InpWmaPeriod), InpLongPeriod), InpAdxEmaPeriod), InpZzAtrPeriod) + 5;
   if(rates_total < need + 2) return(0);

   ArraySetAsSeries(time,  false);
   ArraySetAsSeries(high,  false);
   ArraySetAsSeries(low,   false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(tick_volume, false);   // ★出来高フィルター用(昇順)

   // --- チャート足(M5)の値 ---
   double ema[], sma[], wma[], atr[];
   if(CopyBuffer(hEMA,0,0,rates_total,ema)<=0) return(prev_calculated);
   if(CopyBuffer(hSMA,0,0,rates_total,sma)<=0) return(prev_calculated);
   if(CopyBuffer(hWMA,0,0,rates_total,wma)<=0) return(prev_calculated);
   if(CopyBuffer(hATR,0,0,rates_total,atr)<=0) return(prev_calculated);
   double longLine[];                                    // ★Ver8.3: 長期足(M5)
   if(CopyBuffer(hLong,0,0,rates_total,longLine)<=0) return(prev_calculated);
   ArraySetAsSeries(ema,false); ArraySetAsSeries(sma,false); ArraySetAsSeries(longLine,false);

   // ★2026-07-05: ADXトレンドフィルター用データ(ADX期間12・EMA期間50。DokaKotsu_Trend_Filterと同一計算)
   double adxArr[], adxEmaArr[];
   if(CopyBuffer(hAdx, MAIN_LINE, 0, rates_total, adxArr) <= 0) return(prev_calculated);
   if(CopyBuffer(hAdxEma, 0, 0, rates_total, adxEmaArr) <= 0) return(prev_calculated);
   ArraySetAsSeries(adxArr, false); ArraySetAsSeries(adxEmaArr, false);

   // ★2026-07-06: ZigZag弱波フィルター用ATR(InpZzAtrPeriod)
   double zzAtrArr[];
   bool zzAtrOk = (CopyBuffer(hZzAtr, 0, 0, rates_total, zzAtrArr) > 0);
   if(zzAtrOk) ArraySetAsSeries(zzAtrArr, false);

   // ★2026-07-07(_13) context専用(判定には使わない・観測のみ)。取得失敗してもソフトフェイルで本体判定は継続する。
   double rsiArr[], macdMainArr[], macdSignalArr[];
   bool rsiOk  = (CopyBuffer(hRsi, 0, 0, rates_total, rsiArr) > 0);
   bool macdOk = (CopyBuffer(hMacd, MAIN_LINE, 0, rates_total, macdMainArr) > 0) &&
                 (CopyBuffer(hMacd, SIGNAL_LINE, 0, rates_total, macdSignalArr) > 0);
   if(rsiOk)  ArraySetAsSeries(rsiArr, false);
   if(macdOk) { ArraySetAsSeries(macdMainArr, false); ArraySetAsSeries(macdSignalArr, false); }
   double prevDayHigh = iHigh(_Symbol, PERIOD_D1, 1);   // 前日高値(context用。日中は一定値でよい)
   double prevDayLow  = iLow(_Symbol, PERIOD_D1, 1);    // 前日安値

   // SMA20を二重平滑(さらに期間Nで平均)して滑らかにする。
   //   カクつき軽減。グレー判定のタイミングも滑らかになる。
   double sma2[]; ArrayResize(sma2, rates_total);
   int smN = MathMax(1, InpSma2ndPeriod);   // 二次平滑の期間(入力で調整。1=平滑なし)
   for(int i=0;i<rates_total;i++)
   {
      if(i < smN-1){ sma2[i]=sma[i]; continue; }
      double s=0; for(int k=0;k<smN;k++) s+=sma[i-k];
      sma2[i]=s/smN;
   }
   ArraySetAsSeries(wma,false); ArraySetAsSeries(atr,false);

   // ★Ver8: 15分足オーバーレイ(FRAMA8)。M15のMA値・ATR・時刻を取得し、各M15足の方向を前計算。
   double m15ma[], m15atr[]; datetime m15time[];
   int m15n = 0;
   {
      int want = MathMin(Bars(_Symbol, PERIOD_M15), rates_total);
      if(want > 3 && hM15!=INVALID_HANDLE && hAtrM15!=INVALID_HANDLE)
      {
         ArraySetAsSeries(m15ma,false); ArraySetAsSeries(m15atr,false); ArraySetAsSeries(m15time,false);
         int g1 = CopyBuffer(hM15,   0, 0, want, m15ma);
         int g2 = CopyBuffer(hAtrM15,0, 0, want, m15atr);
         int g3 = CopyTime  (_Symbol, PERIOD_M15, 0, want, m15time);
         m15n = MathMin(MathMin(g1, g2), g3);
         if(m15n < 0) m15n = 0;
      }
   }
   int m15dir[]; ArrayResize(m15dir, MathMax(m15n,1));
   for(int k=0;k<m15n;k++)
   {
      if(k<1 || m15atr[k]<=0.0) { m15dir[k]=0; continue; }
      double sl = (m15ma[k]-m15ma[k-1]) / m15atr[k];   // ATR正規化したM15傾き
      m15dir[k] = (sl > InpM15SlopeTh) ? 1 : (sl < -InpM15SlopeTh ? -1 : 0);
   }

   // ── 決済用 平均足(Smoothed Heikin Ashi)の色を前計算 ──
   //   haColor[i]: 0=陽線(上昇) / 1=陰線(下降)。決済はこの色の転換で行う。
   double prO[],prH[],prL[],prC[],hO[],hH[],hL[],hC[];
   ArrayResize(prO,rates_total); ArrayResize(prH,rates_total);
   ArrayResize(prL,rates_total); ArrayResize(prC,rates_total);
   ArrayResize(hO,rates_total);  ArrayResize(hH,rates_total);
   ArrayResize(hL,rates_total);  ArrayResize(hC,rates_total);
   int haColor[]; ArrayResize(haColor, rates_total);
   for(int i=0;i<rates_total;i++)   // ①前平滑化
   {
      prO[i]=MAValue(open ,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
      prH[i]=MAValue(high ,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
      prL[i]=MAValue(low  ,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
      prC[i]=MAValue(close,i,InpHaPrePeriod,InpHaPreMethod,rates_total);
   }
   for(int i=0;i<rates_total;i++)   // ②平均足の生値
   {
      double hac=(prO[i]+prH[i]+prL[i]+prC[i])/4.0;
      double hao=(i==0)?(prO[i]+prC[i])/2.0:(hO[i-1]+hC[i-1])/2.0;
      hO[i]=hao; hC[i]=hac;
      hH[i]=MathMax(prH[i],MathMax(hao,hac));
      hL[i]=MathMin(prL[i],MathMin(hao,hac));
   }
   for(int i=0;i<rates_total;i++)   // ③後平滑化 → OHLC出力＋色(表示用HAインジが参照する単一の真実)
   {
      double o=MAValue(hO,i,InpHaPostPeriod,InpHaPostMethod,rates_total);
      double h=MAValue(hH,i,InpHaPostPeriod,InpHaPostMethod,rates_total);
      double l=MAValue(hL,i,InpHaPostPeriod,InpHaPostMethod,rates_total);
      double c=MAValue(hC,i,InpHaPostPeriod,InpHaPostMethod,rates_total);
      double hi=MathMax(h,MathMax(o,c));   // 高安が前後関係を保つよう補正(表示と同一)
      double lo=MathMin(l,MathMin(o,c));
      BufHaOpen[i]=o; BufHaHigh[i]=hi; BufHaLow[i]=lo; BufHaClose[i]=c; // ★表示用HAインジがこの値を参照(値はインジが一元保持)
      haColor[i]=(c>=o)?0:1;               // 決済判定の色=表示色と同一((c>=o)で陽線)
   }

   // TMA/VWMA は iMA に無いので自前計算で wma[] を上書き
   if(InpWmaType==WT_TMA)
   {
      // 三角移動平均 = SMAを2回かける
      int h=(InpWmaPeriod+1)/2;
      double tmp[]; ArrayResize(tmp,rates_total);
      for(int i=0;i<rates_total;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=close[i-k];c++;} tmp[i]=(c>0)?s/c:close[i]; }
      for(int i=0;i<rates_total;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=tmp[i-k];c++;} wma[i]=(c>0)?s/c:close[i]; }
   }
   else if(InpWmaType==WT_VWMA)
   {
      // 出来高加重移動平均
      for(int i=0;i<rates_total;i++)
      {
         if(i<InpWmaPeriod-1){ wma[i]=close[i]; continue; }
         double sp=0,sv=0;
         for(int k=0;k<InpWmaPeriod;k++){ double v=(double)tick_volume[i-k]; sp+=close[i-k]*v; sv+=v; }
         wma[i]=(sv>0)?sp/sv:close[i];
      }
   }
   else if(InpWmaType==WT_KAMA && hKAMA!=INVALID_HANDLE && hKAMA>=0)
   {
      double buf[];
      if(CopyBuffer(hKAMA,0,0,rates_total,buf)>0)
      { ArraySetAsSeries(buf,false); for(int i=0;i<rates_total;i++) wma[i]=buf[i]; }
   }
   else if(InpWmaType==WT_VIDYA && hVIDYA!=INVALID_HANDLE && hVIDYA>=0)
   {
      double buf[];
      if(CopyBuffer(hVIDYA,0,0,rates_total,buf)>0)
      { ArraySetAsSeries(buf,false); for(int i=0;i<rates_total;i++) wma[i]=buf[i]; }
   }
   else if(InpWmaType==WT_FRAMA && hFRAMA!=INVALID_HANDLE && hFRAMA>=0)
   {
      double buf[];
      if(CopyBuffer(hFRAMA,0,0,rates_total,buf)>0)
      { ArraySetAsSeries(buf,false); for(int i=0;i<rates_total;i++) wma[i]=buf[i]; }
   }
   else if(InpWmaType==WT_ATR_ADAPT)
   {
      // ATR Adaptive: ATRの「水準」(ATR / ATR平均)でαを変える適応EMA
      //   既定(InpHighVolFaster=false): 高ボラで遅く(なめらか)
      //   true: 高ボラで速く
      for(int i=0;i<rates_total;i++)
      {
         if(i<1){ wma[i]=close[i]; continue; }
         // ATR平均(参照期間)
         double am=0; int ac=0;
         for(int k=0;k<InpAtrRefPeriod && i-k>=0;k++){ am+=atr[i-k]; ac++; }
         am=(ac>0)?am/ac:atr[i];
         double ratio=(am>0)?atr[i]/am:1.0;       // ATR水準(1で平均並み)
         // ratioを0〜1に写像してαを決める(高ratio=高ボラ)
         double t=MathMin(2.0,MathMax(0.0,ratio))/2.0; // 0〜1
         double a;
         if(InpHighVolFaster) a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t;       // 高ボラで速い
         else                 a=InpAtrFastA-(InpAtrFastA-InpAtrSlowA)*t;       // 高ボラで遅い
         wma[i]=close[i]*a + wma[i-1]*(1.0-a);
      }
   }
   else if(InpWmaType==WT_ATR_TREND)
   {
      // ATR Trend: ATRの「傾き」(過去N本との変化率)でαを変える適応EMA
      //   ATR拡大局面で速く追従。
      for(int i=0;i<rates_total;i++)
      {
         if(i<1){ wma[i]=close[i]; continue; }
         int j=MathMax(0,i-InpAtrRefPeriod);
         double base=atr[j];
         double chg=(base>0)?(atr[i]-base)/base:0.0;  // ATR変化率(+で拡大)
         double t=MathMin(1.0,MathMax(0.0,chg));       // 0〜1(拡大ほど1)
         double a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t; // 拡大で速い
         wma[i]=close[i]*a + wma[i-1]*(1.0-a);
      }
   }
   else if(InpWmaType==WT_HMA)   Calc_HMA  (wma, close, InpWmaPeriod, rates_total);
   else if(InpWmaType==WT_DEMA)  Calc_DEMA (wma, close, InpWmaPeriod, rates_total);
   else if(InpWmaType==WT_ZLEMA) Calc_ZLEMA(wma, close, InpWmaPeriod, rates_total);
   else if(InpWmaType==WT_MAMA)  Calc_MAMA (wma, close, InpMamaFast, InpMamaSlow, rates_total);
   else if(InpWmaType==WT_LSMA)  Calc_LSMA (wma, close, InpWmaPeriod, rates_total);
   else if(InpWmaType==WT_VWAP)  Calc_VWAP (wma, high, low, close, tick_volume, InpWmaPeriod, rates_total);

   // ── 表示用ライン wmaShow[](ロジックは生 wma[](KAMA等)のまま、線だけ平滑化) ──
   //   KAMAは蛇行しやすいので、表示は EMA(InpLineSmooth) で滑らかに見せる。
   //   slope/wmaDir/背景/エントリーは全て生 wma[] を使うので挙動は変わらない。
   double wmaShow[]; ArrayResize(wmaShow, rates_total);
   {
      int smN = MathMax(1, InpLineSmooth);
      if(smN<=1){ for(int i=0;i<rates_total;i++) wmaShow[i]=wma[i]; }
      else{
         double aS = 2.0/(smN+1.0);
         wmaShow[0]=wma[0];
         for(int i=1;i<rates_total;i++) wmaShow[i]=wma[i]*aS + wmaShow[i-1]*(1.0-aS);
      }
   }

   // ── 引き金/スパイク線(ema[])も TMA/VWMA/ATR系に対応 ──
   //   SMA/WMA/SMMA/EMA/KAMA/VIDYA/FRAMA は MakeMA のハンドルで対応済み。
   //   ここでは iMA に無い4種だけ、wma[]と同じ式で ema[] を上書きする。
   //   ※M5(チャート足)の引き金線のみ。M1引き金(応用フィルター)はハンドルのまま。
   if(InpEmaType==WT_TMA)
   {
      int h=(InpEmaPeriod+1)/2;
      double tmp[]; ArrayResize(tmp,rates_total);
      for(int i=0;i<rates_total;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=close[i-k];c++;} tmp[i]=(c>0)?s/c:close[i]; }
      for(int i=0;i<rates_total;i++){ double s=0;int c=0; for(int k=0;k<h&&i-k>=0;k++){s+=tmp[i-k];c++;} ema[i]=(c>0)?s/c:close[i]; }
   }
   else if(InpEmaType==WT_VWMA)
   {
      for(int i=0;i<rates_total;i++)
      {
         if(i<InpEmaPeriod-1){ ema[i]=close[i]; continue; }
         double sp=0,sv=0;
         for(int k=0;k<InpEmaPeriod;k++){ double v=(double)tick_volume[i-k]; sp+=close[i-k]*v; sv+=v; }
         ema[i]=(sv>0)?sp/sv:close[i];
      }
   }
   else if(InpEmaType==WT_ATR_ADAPT)
   {
      for(int i=0;i<rates_total;i++)
      {
         if(i<1){ ema[i]=close[i]; continue; }
         double am=0; int ac=0;
         for(int k=0;k<InpAtrRefPeriod && i-k>=0;k++){ am+=atr[i-k]; ac++; }
         am=(ac>0)?am/ac:atr[i];
         double ratio=(am>0)?atr[i]/am:1.0;
         double t=MathMin(2.0,MathMax(0.0,ratio))/2.0;
         double a;
         if(InpHighVolFaster) a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t;
         else                 a=InpAtrFastA-(InpAtrFastA-InpAtrSlowA)*t;
         ema[i]=close[i]*a + ema[i-1]*(1.0-a);
      }
   }
   else if(InpEmaType==WT_ATR_TREND)
   {
      for(int i=0;i<rates_total;i++)
      {
         if(i<1){ ema[i]=close[i]; continue; }
         int j=MathMax(0,i-InpAtrRefPeriod);
         double base=atr[j];
         double chg=(base>0)?(atr[i]-base)/base:0.0;
         double t=MathMin(1.0,MathMax(0.0,chg));
         double a=InpAtrSlowA+(InpAtrFastA-InpAtrSlowA)*t;
         ema[i]=close[i]*a + ema[i-1]*(1.0-a);
      }
   }
   else if(InpEmaType==WT_HMA)   Calc_HMA  (ema, close, InpEmaPeriod, rates_total);
   else if(InpEmaType==WT_DEMA)  Calc_DEMA (ema, close, InpEmaPeriod, rates_total);
   else if(InpEmaType==WT_ZLEMA) Calc_ZLEMA(ema, close, InpEmaPeriod, rates_total);
   else if(InpEmaType==WT_MAMA)  Calc_MAMA (ema, close, InpMamaFast, InpMamaSlow, rates_total);
   else if(InpEmaType==WT_LSMA)  Calc_LSMA (ema, close, InpEmaPeriod, rates_total);
   else if(InpEmaType==WT_VWAP)  Calc_VWAP (ema, high, low, close, tick_volume, InpEmaPeriod, rates_total);

   // --- M1の値（引き金用・直近 InpM1Bars 本）---
   datetime t1[]; double c1[], e1[], s1[], a1[], conv1[];
   int m1count = 0;
   if(InpFilM1Spike && PeriodSeconds(_Period) > PeriodSeconds(PERIOD_M1))
   {
      int want = InpM1Bars;
      int nT = CopyTime(_Symbol, PERIOD_M1, 0, want, t1);
      int nC = CopyClose(_Symbol, PERIOD_M1, 0, want, c1);
      int nE = CopyBuffer(hEMA1, 0, 0, want, e1);
      int nS = CopyBuffer(hSMA1, 0, 0, want, s1);
      int nA = CopyBuffer(hATR1, 0, 0, want, a1);
      if(nT>0 && nC>0 && nE>0 && nS>0 && nA>0)
      {
         ArraySetAsSeries(t1,false); ArraySetAsSeries(c1,false);
         ArraySetAsSeries(e1,false); ArraySetAsSeries(s1,false);
         ArraySetAsSeries(a1,false);
         m1count = MathMin(MathMin(nT,nC), MathMin(MathMin(nE,nS),nA));
         ArrayResize(conv1, m1count);
         for(int k=0; k<m1count; k++)
         {
            if(a1[k] > 0)
            {
               double sp1 = MathMax(MathMax(MathAbs(c1[k]-e1[k]),
                                            MathAbs(c1[k]-s1[k])),
                                            MathAbs(e1[k]-s1[k]));
               conv1[k] = sp1/a1[k];
            }
            else conv1[k] = 0.0;
         }
      }
   }

   int barSecs = PeriodSeconds(_Period);

   // ポジション状態は先頭から順に追うため毎回 need から全再計算。
   int  pos        = 0;
   int  trendDir   = 0;     // 確立中のWMAトレンド方向(灰を挟んでも継続・反対色で更新)
   bool segHadEntry= false; // 現トレンドで既に1回エントリーしたか
   bool prevSpike5 = false;
   int  p1         = 0;   // M1配列を前進させるポインタ
   int  cdLeft     = 0;   // 残りクールダウン本数(決済後 InpCooldownBars 本)
   int  colorRun   = 0;   // 同方向の色が連続している本数(0=グレー)。持続確認用
   int  prevDirRun = 0;   // 1本前のwmaDir(連続判定用)
   int  prevWmaDir = 0;   // ★Ver8: 1本前のwmaDir(決済の直接フリップ判定用。色保持の影響を受けない生の前足方向)
   int  grayRun    = 0;   // ★Ver8: 保有中にグレー(or非直接の逆)が連続している本数(中間色チラつき無視用)
   int  pM15       = 0;   // ★Ver8: M5足に対応するM15足を追うポインタ(オーバーレイ描画用)
   int  heldDir    = 0;   // (Ver8で表示の色保持は廃止。未使用)
   int  longRun    = 0;   // ★新: 長期足の連続点灯本数(先頭判定用)
   int  m15Run     = 0;   // ★新: M15の連続点灯本数
   int  haRun      = 0;   // ★新: 平均足の連続同色本数
   bool spikeBanActive = false; // ★2026-07-08追加: スパイク決済後、平均足が変わるまで新規禁止
   int  spikeBanHaColor = -1;   // ★2026-07-08追加: スパイク発生時点の平均足色(この色のままなら禁止継続)
   bool   spikeAdxBanActive       = false; // ★2026-07-10追加: スパイク面積300超→ADX色が変わるまで新規禁止(ポジション有無を問わない)
   int    spikeAdxBanColor        = -1;    //   トリガー時点のADX色(0=グレー/1=上昇/2=下降。これと異なる色になったら解除)
   double spikeAdxBanTriggerArea  = 0.0;   //   診断用: 直近トリガー面積(保持型)
   int    spikeAdxBanTriggerIdx   = -1;    //   診断用: 直近トリガーバー(-1=まだ未観測)
   bool   regimeSqueeze = false;   // ★2026-07-10追加: 相場レジーム(true=スクイーズ/false=トレンド)。既定はトレンド扱いで開始
   int    spkDir         = 0;          // ★2026-07-08追加: スパイク検出用スイング方向(1=上/-1=下/0=未定)
   int    spkSwIdx        = need;      //   現在進行中のスイングの起点バー
   double spkSwPrice      = (need < rates_total) ? close[need] : 0.0;  // 現在進行中のスイングの起点価格
   int    spkSwPrevIdx    = need;      //   直前に確定したスイングの起点バー(面積計算用)
   double spkSwPrevPrice  = spkSwPrice;// 直前に確定したスイングの起点価格
   double lastSpikeArea   = 0.0;       // ★2026-07-09: 直近に確定したスパイク面積(次の確定まで保持)
   int    lastSpikeIdx    = -1;        // ★2026-07-09: 直近スパイク確定バー(-1=まだ未観測)
   int  prevLongD  = 0;   // ★新: 1本前のlongDir
   int  prevM15L   = 0;   // ★新: 1本前のM15ライブ方向
   int  prevHaD    = 0;   // ★新: 1本前の平均足方向
   int  adxRun     = 0;   // ★2026-07-06: ADXが非グレー(BufAdxState!=0)で連続している本数(継続性チェック用)

   // ウォームアップ区間を空に
   for(int j=0; j<need && j<rates_total; j++)
   {
      BufEmaNorm[j]=EMPTY_VALUE; BufEmaSpike[j]=EMPTY_VALUE; BufM15Down[j]=EMPTY_VALUE;
      BufWmaUp[j]=EMPTY_VALUE;   BufWmaDown[j]=EMPTY_VALUE; BufWmaFlat[j]=EMPTY_VALUE;
      BufSma20[j]=EMPTY_VALUE; BufSma20Col[j]=2;
      BufBuy[j]=0.0; BufSell[j]=0.0; BufExit[j]=0.0; BufOvershoot[j]=0.0; BufBgDir[j]=0.0;
      BufReason[j]=0.0; BufM15State[j]=0.0; BufLongState[j]=0.0; BufAdxState[j]=0.0; BufZzState[j]=100.0;
   }

   // 背景は新規バー時のみ再描画(毎ティックの全再描画による点滅・高CPUを防止)
   static datetime s_lastBgBar = 0;
   bool doBg = InpShowBG && (prev_calculated==0 || time[rates_total-1]!=s_lastBgBar);
   s_lastBgBar = time[rates_total-1];

   //--- 波オシレーター（エントリー判定で使うためループ前に計算） ---
   //============ 波オシレーター（buf20-24 で公開：Wave_Sub が読む） ============
   {
      static double wvMA[], wvSlow[];
      ArrayResize(wvMA,rates_total); ArrayResize(wvSlow,rates_total);
      for(int i=0;i<rates_total;i++) wvMA[i]=close[i];   // ★不定値(inf)混入防止：既定でcloseで埋める
      if(hWave!=INVALID_HANDLE)
      {
         ArraySetAsSeries(wvMA,false);
         CopyBuffer(hWave,0,0,rates_total,wvMA);          // 取れた分だけ上書き(部分コピーでも前方はclose=有限)
      }
      else
      {
         switch(InpWaveMaType)
         {
            case WT_TMA:       Calc_TMA   (wvMA,close,InpWaveFast,rates_total);                 break;
            case WT_VWMA:      Calc_VWMA  (wvMA,close,tick_volume,InpWaveFast,rates_total);      break;
            case WT_ATR_ADAPT: Calc_ATRADAPT(wvMA,close,atr,InpAtrRefPeriod,InpAtrFastA,InpAtrSlowA,InpHighVolFaster,rates_total); break;
            case WT_ATR_TREND: Calc_ATRTREND(wvMA,close,atr,InpAtrRefPeriod,InpAtrFastA,InpAtrSlowA,rates_total); break;
            case WT_HMA:       Calc_HMA   (wvMA,close,InpWaveFast,rates_total);                 break;
            case WT_DEMA:      Calc_DEMA  (wvMA,close,InpWaveFast,rates_total);                 break;
            case WT_ZLEMA:     Calc_ZLEMA (wvMA,close,InpWaveFast,rates_total);                 break;
            case WT_MAMA:      Calc_MAMA  (wvMA,close,InpMamaFast,InpMamaSlow,rates_total);      break;
            case WT_LSMA:      Calc_LSMA  (wvMA,close,InpWaveFast,rates_total);                 break;
            case WT_VWAP:      Calc_VWAP  (wvMA,high,low,close,tick_volume,InpWaveFast,rates_total); break;
            default:           for(int i=0;i<rates_total;i++) wvMA[i]=close[i];                 break;
         }
      }
      double wps=2.0/(InpWaveSlow+1.0);
      for(int i=0;i<rates_total;i++) wvSlow[i]=(i==0)?wvMA[i]:wvMA[i]*wps+wvSlow[i-1]*(1.0-wps);
      double wpg=2.0/(InpWaveSignal+1.0);
      double wPrevSig=0.0; int wPrevDir=0;
      double wThOn=InpWmaSlopeTh, wThOff=InpWmaSlopeTh*InpWmaStickyMult;
      for(int i=0;i<rates_total;i++)
      {
         double a=atr[i];
         double wv=(a>0.0)?((wvMA[i]-wvSlow[i])/a):0.0;
         if(!MathIsValidNumber(wv)) wv=0.0;                      // ★inf/nan遮断
         double sg=(i==0)?wv:(wv*wpg+wPrevSig*(1.0-wpg));
         if(!MathIsValidNumber(sg)) sg=0.0;                      // ★signalへのinf伝播を断つ
         wPrevSig=sg;
         BufWaveVal[i]=wv; BufWaveSig[i]=sg;
         BufWaveFastRaw[i] = wvMA[i];    // ★2026-07-09: Wave早い線(WMA6相当)の生値(wvMA/wvSlowはこのブロック内でしか有効でないため、ここで書く)
         BufWaveSlowRaw[i] = wvSlow[i];  // ★2026-07-09: Wave遅い線(EMA24相当)の生値
         double slope=(i>0 && a>0.0)?((wma[i]-wma[i-1])/a):0.0;
         int d;
         if(wPrevDir==1)       d=(slope<-wThOn)?-1:(slope< wThOff?0: 1);
         else if(wPrevDir==-1) d=(slope> wThOn)? 1:(slope>-wThOff?0:-1);
         else                  d=(slope> wThOn)? 1:(slope<-wThOn ?-1: 0);
         wPrevDir=d; BufWaveReg[i]=d;
         BufWaveUp[i]=EMPTY_VALUE; BufWaveDn[i]=EMPTY_VALUE;
      }
      for(int i=1;i<=rates_total-2;i++)
      {
         if(BufWaveVal[i]>BufWaveSig[i] && BufWaveVal[i-1]<=BufWaveSig[i-1]) BufWaveUp[i]=BufWaveVal[i];
         if(BufWaveVal[i]<BufWaveSig[i] && BufWaveVal[i-1]>=BufWaveSig[i-1]) BufWaveDn[i]=BufWaveVal[i];
      }
   }

   //============ ★2026-07-06: ZigZag(ATR型)弱波/天底近接フィルター 前計算 ============
   //  ZigZag_ATR.mq5と同一のスイング確定ロジック(ATR×倍率のブレイクで反転確定)を
   //  本体内で自前複製する。iCustomのバッファをバー位置で直接参照すると、確定が
   //  分かるのは反転を検知した"後"のバーなのに、値は元の天底の"位置"に書かれるため
   //  未来参照(先読み)になってしまう。そのためここでは1本ずつ前進しながら、
   //  「今の足の時点で分かっている直近2つの確定スイング(A→B)」だけを積み上げる。
   //  zzRefB=直近に確定した天底(第一条件・100%地点) zzRefA=その1つ前の確定天底(0%地点=反対側)
   double zzRefA[], zzRefB[]; ArrayResize(zzRefA, rates_total); ArrayResize(zzRefB, rates_total);
   int    zzRefBIsPeak[];     ArrayResize(zzRefBIsPeak, rates_total);   // 1=Bは高値(天) / -1=Bは安値(底)
   bool   zzRefValid[];       ArrayResize(zzRefValid, rates_total);     // A・Bとも確定済みか
   {
      int    zDir      = 0;       // 0=未確定 1=高値追跡中 -1=安値追跡中
      double zCurPrice = 0.0;
      bool   zCurIsPeak= false;
      double lastA=0.0, lastB=0.0; int lastBIsPeak=0; bool haveA=false, haveB=false;
      bool   zInit=false;
      for(int i=0; i<rates_total; i++)
      {
         if(zzAtrOk)
         {
            double th = zzAtrArr[i] * InpZzAtrMultiplier;
            if(!zInit) { zCurPrice = close[i]; zInit = true; }
            if(th > 0.0)
            {
               if(zDir == 0)
               {
                  if(high[i]-zCurPrice >= th) { zDir=1;  zCurPrice=high[i]; zCurIsPeak=true;  }
                  else if(zCurPrice-low[i] >= th) { zDir=-1; zCurPrice=low[i]; zCurIsPeak=false; }
               }
               else if(zDir==1)
               {
                  if(high[i] > zCurPrice) zCurPrice = high[i];
                  else if(zCurPrice-low[i] >= th)
                  {
                     // 高値を確定(=このi足で初めて分かる) → 参照ペアを1つ更新
                     lastA=lastB; haveA=haveB; lastB=zCurPrice; lastBIsPeak=1; haveB=true;
                     zDir=-1; zCurPrice=low[i]; zCurIsPeak=false;
                  }
               }
               else // zDir==-1
               {
                  if(low[i] < zCurPrice) zCurPrice = low[i];
                  else if(high[i]-zCurPrice >= th)
                  {
                     lastA=lastB; haveA=haveB; lastB=zCurPrice; lastBIsPeak=-1; haveB=true;
                     zDir=1; zCurPrice=high[i]; zCurIsPeak=true;
                  }
               }
            }
         }
         // このi足の「時点で確定済み」の参照ペアだけを格納(今足で新たに確定した分も含めてOK=
         //  同じ足の中で情報が出そろってから判定するのは先読みではない。1本前のデータで
         //  未来足を覗くことはしていない)
         zzRefA[i]=lastA; zzRefB[i]=lastB; zzRefBIsPeak[i]=lastBIsPeak; zzRefValid[i]=(haveA && haveB);
      }
   }

   for(int i=need; i<rates_total; i++)
   {
      BufEmaNorm[i]=EMPTY_VALUE; BufEmaSpike[i]=EMPTY_VALUE; BufM15Down[i]=EMPTY_VALUE;
      BufWmaUp[i]=EMPTY_VALUE;   BufWmaDown[i]=EMPTY_VALUE; BufWmaFlat[i]=EMPTY_VALUE;

      // ★2026-07-05: ADXトレンド状態(DokaKotsu_Trend_Filterと同一ロジック)。
      //   ADX(12)がInpAdxThreshold未満=グレー(0)。以上ならEMA(50)のInpAdxSlopeLookback本前差分の符号で1(上昇)/2(下降)。
      //   方向不一致(色反転)は判定に使わない=グレー検知のみでラグを避ける方針(田島さん確認済み)。
      {
         int _aIdxPrev = i - InpAdxSlopeLookback;
         if(_aIdxPrev >= 0 && _aIdxPrev < ArraySize(adxEmaArr) && i < ArraySize(adxArr) && i < ArraySize(adxEmaArr))
         {
            double _aSlope = adxEmaArr[i] - adxEmaArr[_aIdxPrev];
            double _aVal   = adxArr[i];
            if(_aVal >= InpAdxThreshold && _aSlope > 0.0)      BufAdxState[i] = 1.0; // 上昇(ロング許可)
            else if(_aVal >= InpAdxThreshold && _aSlope < 0.0) BufAdxState[i] = 2.0; // 下降(ショート許可)
            else                                               BufAdxState[i] = 0.0; // グレー(トレンド終盤ノイズ/方向感弱い)
         }
         else
         {
            BufAdxState[i] = 0.0;
         }
         // ★2026-07-06: 連続本数を更新(継続性チェック用)。グレーに戻ったら0リセット。
         if(BufAdxState[i] != 0.0) adxRun++; else adxRun = 0;
      }

      // ★2026-07-06: ZigZag残存強度%(0〜100)。データ不足/対象外は100(=制限なし)のまま。
      BufZzState[i] = 100.0;
      if(InpUseZzFilter && zzRefValid[i])
      {
         double A=zzRefA[i], B=zzRefB[i]; int bIsPeak=zzRefBIsPeak[i];
         double rangeAB = MathAbs(B-A);
         if(rangeAB > 0.0)
         {
            double strength;
            if(bIsPeak==1) strength = (close[i]-A)/rangeAB*100.0;   // B=天井 → 下降方向の残存強度
            else           strength = (A-close[i])/rangeAB*100.0;   // B=底値 → 上昇方向の残存強度
            BufZzState[i] = MathMax(0.0, MathMin(100.0, strength));
         }
      }

      // ★Ver8.3: SMA20_CENTERプロットを「長期足」(M5・既定KAMA380)に転用。線位置は不変=WYSIWYG。
      //   ★Ver9.0: 色判定の傾きを「直近InpLongSlopeSmooth個の傾きの平均」に平滑化し、
      //   デッドバンド(InpLongGrayThresh)＋ヒステリシス(InpLongHystRatio)を追加。
      //   スパイク一発で長期線が瞬間的に青(上昇)判定される問題を解消し、近フラットをグレー化。
      //   ※本数(InpLongPeriod)は増やさない。色を決める傾きだけを均す(線位置は不変)。
      BufSma20[i]=longLine[i];
      int longDir = 0;   // 長期足の方向(0=グレー/1=上昇/-1=下降)。3本一致ゲートで使用。
      if(i-(InpLongSlopeStep + MathMax(0,InpLongSlopeSmooth-1))>=0 && atr[i]>0)
      {
         // 直近 InpLongSlopeSmooth 個の傾き(各 InpLongSlopeStep 本幅)を平均 → ATR正規化
         double sumSlope=0.0; int cntS=0;
         for(int ks=0; ks<InpLongSlopeSmooth; ks++)
         {
            int a = i - ks;
            int b = a - InpLongSlopeStep;
            if(b < 0) break;
            sumSlope += (longLine[a]-longLine[b]);
            cntS++;
         }
         double lsl = (cntS>0) ? (sumSlope/cntS)/atr[i] : 0.0;
         BufLongSlopeSmoothed[i] = lsl;                              // ★2026-07-09: 平滑化後の傾き実値
         BufLongSlopeDist[i]     = MathAbs(lsl) - InpLongGrayThresh; // ★2026-07-09: グレー閾値との距離(正=色/負=グレー)

         // デッドバンド＋ヒステリシス(青⇔グレーの境界ちらつきを止める)
         double enterTh  = InpLongGrayThresh * InpLongHystRatio; // グレーを抜けて色に入る(厳しめ)
         double holdTh   = InpLongGrayThresh;                    // 色を維持する下限(緩め)
         double strongTh = InpLongGrayThresh * 3.0;              // 強色(アクア/マゼンタ)境界
         int prevDir = (i>0) ? (int)BufLongState[i-1] : 0;       // 前足の長期方向(維持判定用)

         if(lsl >=  enterTh)                    longDir = 1;  // 上昇に入る
         else if(lsl <= -enterTh)               longDir = -1; // 下降に入る
         else if(prevDir== 1 && lsl >  holdTh)  longDir = 1;  // 上昇を維持
         else if(prevDir==-1 && lsl < -holdTh)  longDir = -1; // 下降を維持
         else                                   longDir = 0;  // グレー

         // ★2026-07-08確認: このsc(0-4)は描画専用の濃淡表示。エントリー判定(1615行のInpUseLongFilter)は
         //   longDir(1/-1)のみを見ており、濃淡(強色sc=0,4 / 薄色sc=1,3)を区別していない。
         //   → 水色(1)・薄マゼンタ(3)も既にエントリー対象に含まれている(ロジック変更なし・仕様確認のみ)。
         int sc;
         if(longDir== 1)      sc = (lsl >=  strongTh) ? 0 : 1; // アクア / 水色
         else if(longDir==-1) sc = (lsl <= -strongTh) ? 4 : 3; // マゼンタ / 薄マゼンタ
         else                 sc = 2;                          // グレー
         BufSma20Col[i]=sc;
      }
      else { BufSma20Col[i]=2; BufLongSlopeSmoothed[i]=0.0; BufLongSlopeDist[i]=0.0; }   // ★2026-07-09: 履歴不足時のデフォルト
      BufBuy[i]=0.0; BufSell[i]=0.0; BufExit[i]=0.0; BufOvershoot[i]=0.0; BufBgDir[i]=0.0;
      BufReason[i]=0.0; BufM15State[i]=0.0;
      BufLongState[i] = (double)longDir;   // ★Ver9.0: EA/分析用の長期足状態(buf15)。旧コードのゼロ上書きバグを修正
      if(atr[i]<=0) continue;

      double price = close[i];

      // ★2026-07-07(_13) context専用の記録(判定=BufBuy/BufSell/BufExitには一切影響しない。観測のみ)
      BufRsi[i]       = (rsiOk  && i<ArraySize(rsiArr))        ? rsiArr[i] : EMPTY_VALUE;
      BufMacdMain[i]   = (macdOk && i<ArraySize(macdMainArr))   ? macdMainArr[i]   : EMPTY_VALUE;
      BufMacdSignal[i] = (macdOk && i<ArraySize(macdSignalArr)) ? macdSignalArr[i] : EMPTY_VALUE;
      BufMacdHist[i]   = (macdOk && i<ArraySize(macdMainArr) && i<ArraySize(macdSignalArr))
                          ? (macdMainArr[i]-macdSignalArr[i]) : EMPTY_VALUE;
      BufEmaDist[i]        = (atr[i]>0.0) ? (price - ema[i])/atr[i] : 0.0;
      BufGmmaShortAngle[i] = (i>0 && atr[i]>0.0) ? (ema[i]-ema[i-1])/atr[i]         : 0.0; // 代理:EMA10傾き
      BufGmmaLongAngle[i]  = (i>0 && atr[i]>0.0) ? (longLine[i]-longLine[i-1])/atr[i] : 0.0; // 代理:長期足MA傾き
      if(i>=20)
      {
         double hh=-DBL_MAX, ll=DBL_MAX;
         for(int k=i-20;k<i;k++){ if(high[k]>hh) hh=high[k]; if(low[k]<ll) ll=low[k]; }
         BufHighUpdate[i] = (high[i] > hh) ? 1.0 : 0.0;
         BufLowUpdate[i]  = (low[i]  < ll) ? 1.0 : 0.0;
         BufRangeWidth[i] = (atr[i]>0.0) ? (hh-ll)/atr[i] : 0.0;   // ATR倍率のレンジ幅(直近20本)
      }
      else { BufHighUpdate[i]=0.0; BufLowUpdate[i]=0.0; BufRangeWidth[i]=0.0; }
      BufPrevDayHigh[i] = prevDayHigh;
      BufPrevDayLow[i]  = prevDayLow;

      // --- M5 EMA10スパイク（表示＆代替トリガー）---
      double sp5 = MathMax(MathMax(MathAbs(price-ema[i]),
                                   MathAbs(price-sma[i])),
                                   MathAbs(ema[i]-sma[i]));
      double conv5 = sp5/atr[i];
      bool spike5 = (conv5 > InpSpikeTh);
      int emaDir5 = 0;
      if(price > ema[i]) emaDir5 = 1; else if(price < ema[i]) emaDir5 = -1;

      // --- M1の引き金（このM5足の中で最初のM1スパイク点灯を探す）---
      int  m1Dir = 0;
      bool m1Onset = false;
      if(m1count > 0)
      {
         datetime t0 = time[i];
         datetime te = time[i] + barSecs;
         while(p1 < m1count && t1[p1] < t0) p1++;     // この足の先頭まで前進
         int q = p1;
         while(q < m1count && t1[q] < te)             // この足の中を走査
         {
            bool onsetq = (conv1[q] > InpM1SpikeTh) &&
                          (q==0 || conv1[q-1] <= InpM1SpikeTh);
            if(onsetq)
            {
               m1Onset = true;
               if(c1[q] > e1[q]) m1Dir = 1; else if(c1[q] < e1[q]) m1Dir = -1;
               break;
            }
            q++;
         }
      }

      // --- ★Ver8: 15分足オーバーレイ(プロット1=NORM/2=SPIKE)。案ア: M15方向あり=SPIKE / M15グレー=NORM ---
      //   M5足 time[i] に対応するM15足までポインタを進めて、その値・方向で描画。
      while(pM15+1 < m15n && m15time[pM15+1] <= time[i]) pM15++;
      // ★確定足参照(2026-06-22): ライブ(進行中)のM15足はブレるため、判定/表示とも1本前の確定足(pM15c)を使う。
      int pM15c = (InpM15ConfirmClosed && pM15 >= 1) ? (pM15 - 1) : pM15;
      BufEmaNorm[i]=EMPTY_VALUE; BufEmaSpike[i]=EMPTY_VALUE; BufM15Down[i]=EMPTY_VALUE; // この足を一旦クリア
      int m15dCur = (m15n > 0 && pM15c >= 0 && pM15c < m15n) ? m15dir[pM15c] : 0; // ★Ver8: この足のM15方向(0/1/-1)
      BufM15State[i] = (double)m15dCur;                                       // ★Ver8: EA/分析用に出力(確定足)
      BufHaState[i]  = (haColor[i]==0) ? 1.0 : -1.0;                          // ★2026-06-22: 平均足の色(1=上昇/-1=下降)
      if(m15n > 0 && pM15c >= 0 && pM15c < m15n && m15ma[pM15c]!=EMPTY_VALUE && m15ma[pM15c]>0.0)
      {
         int md = m15dir[pM15c];
         if(md==1)       { BufEmaSpike[i]=m15ma[pM15c]; BufEmaSpike[i-1]=m15ma[pM15c]; } // UP
         else if(md==-1) { BufM15Down[i] =m15ma[pM15c]; BufM15Down[i-1] =m15ma[pM15c]; } // DOWN
         else            { BufEmaNorm[i] =m15ma[pM15c]; BufEmaNorm[i-1] =m15ma[pM15c]; } // NORM(グレー)
      }

      // --- WMAの色 ---
      double slope = (wma[i]-wma[i-1])/atr[i];
      BufMaSlope[i] = slope;   // ★2026-07-07(_13) context専用: ベースMA傾きの生値(判定=wmaDirは従来通り別途計算)
      // --- 色のヒステリシス(粘り) ---
      //   点灯= InpWmaSlopeTh / 消灯= InpWmaSlopeTh*InpWmaStickyMult。
      //   一度点いた色は、傾きが消灯値を割る or 反対の点灯値を割るまで維持=途切れない。
      double thOn  = InpWmaSlopeTh;
      double thOff = InpWmaSlopeTh * InpWmaStickyMult;
      BufWmaSlopeDist[i] = MathAbs(slope) - thOn;   // ★2026-07-09: グレー閾値との距離(正=色の中/負=グレー側)
      int wmaDir = 0;
      if(prevDirRun == 1)       wmaDir = (slope < -thOn) ? -1 : (slope <  thOff ? 0 :  1);
      else if(prevDirRun == -1) wmaDir = (slope >  thOn) ?  1 : (slope > -thOff ? 0 : -1);
      else                      wmaDir = (slope >  thOn) ?  1 : (slope < -thOn  ? -1 : 0);
      BufBgDir[i]=(double)wmaDir;   // ★buf25: 決済が使う背景方向をEAへ公開(1=上/0=グレー/-1=下)
      // 色の連続本数(同方向が何本続いたか)。グレーで0にリセット。
      if(wmaDir==0)                 colorRun = 0;
      else if(wmaDir==prevDirRun)   colorRun++;
      else                          colorRun = 1;

      // ★新: 各シグナルのrun更新(長期が先頭か判定用)。HAはグレー無し(常に±1)。
      int m15LiveR = (m15n>0 && pM15c>=0 && pM15c<m15n) ? m15dir[pM15c] : 0;
      int haDirR   = (haColor[i]==0) ? 1 : -1;
      if(longDir==0)      longRun=0; else if(longDir==prevLongD)  longRun++; else longRun=1;
      if(m15LiveR==0)     m15Run=0;  else if(m15LiveR==prevM15L)  m15Run++;  else m15Run=1;
      if(haDirR==prevHaD) haRun++;   else haRun=1;
      prevLongD=longDir; prevM15L=m15LiveR; prevHaD=haDirR;
      prevDirRun = wmaDir;

      // ★Ver8 土台①: 単一の真実(WYSIWYG)。表示の色 = wmaDir = エントリー判定方向。
      //   表示専用の色保持(旧InpColorHoldBars/GrayHoldBars)は廃止。連続化は
      //   ヒステリシス(InpWmaStickyMult)で“判定そのものを粘らせる”ことで表示も判定も同時に連続化する。
      int bgDir = wmaDir;   // 表示(背景/線色)も判定もこの値1本

      if(bgDir==1)      { BufWmaUp[i]=wmaShow[i];   BufWmaUp[i-1]=wmaShow[i-1]; }
      else if(bgDir==-1){ BufWmaDown[i]=wmaShow[i]; BufWmaDown[i-1]=wmaShow[i-1]; }
      else              { BufWmaFlat[i]=wmaShow[i]; BufWmaFlat[i-1]=wmaShow[i-1]; }

      // --- 背景色(backend_1統合)。wmaDirで塗る=線色/エントリー許可方向と一致 ---
      if(doBg && i >= rates_total-InpBgLookback)
      {
         color bgc = (bgDir==1) ? InpColorBull :
                     (bgDir==-1)? InpColorBear : InpColorRange;
         datetime tR = (i+1<rates_total) ? time[i+1] : time[i]+barSecs;
         DrawBG(time[i], tR, bgc);
      }

      // --- WMAトレンドの更新（灰は継続扱い・反対色の点灯で新トレンド）---
      // --- WMAトレンドの更新（色変化でtrendDirを更新。直接フリップではロック解除しない）---
      //   ★ルール: グレーを挟んだら本命=解除して色確認エントリー /
      //            グレーなしの直接フリップは調整波=見送り。
      //   よって segHadEntry は「色変化」では解除せず、「グレー出現」でのみ解除する。
      if(wmaDir==1 && trendDir!=1)        { trendDir=1;  }
      else if(wmaDir==-1 && trendDir!=-1) { trendDir=-1; }
      // ★グレー(平行)が出たら本命扱い:再エントリーロックとクールダウンを解除(=次の色確認で入れる)
      if(wmaDir==0) { segHadEntry = false; cdLeft = 0; }

      // --- 圧縮(スクイーズ)判定（BBがKCの内側=圧縮）M5基準 ---
      bool sqzOn = false;
      if(InpFilSqueeze)
      {
         double basis = sma[i];
         double var = 0.0, rsum = 0.0;
         for(int k=0; k<InpSmaPeriod; k++)
         {
            double dd = close[i-k]-basis; var += dd*dd;
            int jj = i-k;
            double rng;
            if(jj>0)
            {
               double aa = high[jj]-low[jj];
               double bb = MathAbs(high[jj]-close[jj-1]);
               double cc = MathAbs(low[jj]-close[jj-1]);
               rng = MathMax(aa, MathMax(bb,cc));
            }
            else rng = high[jj]-low[jj];
            rsum += rng;
         }
         double sd      = MathSqrt(var/InpSmaPeriod);
         double rangema = rsum/InpSmaPeriod;
         double upBB = basis + InpBBMult*sd,      loBB = basis - InpBBMult*sd;
         double upKC = basis + InpKCMult*rangema, loKC = basis - InpKCMult*rangema;
         sqzOn = (loBB > loKC) && (upBB < upKC);   // BBがKC内 = 圧縮
      }

      // ── ★2026-07-10追加: 相場レジーム判定(スクイーズ/トレンドの二層構造) ──
      //   既存sqzOn(InpFilSqueeze専用・現在は不使用)とは独立した係数(InpRegimeBBMult/InpRegimeKCMult,緩め既定)で
      //   常時計算する。トリガー=BB×KC圧縮検知(素早く反応させたい)。
      //   解除=長期足・M15足の両方が非グレーになった瞬間(longDir!=0 && m15dCur!=0。多少遅くてもダマシに強い側)。
      //   スクイーズ判定中はエントリー側で最上流ブロック(reason40)し、ZigZag/スパイク関連は個別に評価しない。
      bool regimeSqzOn = false;
      if(InpUseRegimeSystem)
      {
         double rBasis = sma[i];
         double rVar = 0.0, rRsum = 0.0;
         for(int rk=0; rk<InpSmaPeriod; rk++)
         {
            double rdd = close[i-rk]-rBasis; rVar += rdd*rdd;
            int rjj = i-rk;
            double rRng;
            if(rjj>0)
            {
               double raa = high[rjj]-low[rjj];
               double rbb = MathAbs(high[rjj]-close[rjj-1]);
               double rcc = MathAbs(low[rjj]-close[rjj-1]);
               rRng = MathMax(raa, MathMax(rbb,rcc));
            }
            else rRng = high[rjj]-low[rjj];
            rRsum += rRng;
         }
         double rSd      = MathSqrt(rVar/InpSmaPeriod);
         double rRangema = rRsum/InpSmaPeriod;
         double rUpBB = rBasis + InpRegimeBBMult*rSd,      rLoBB = rBasis - InpRegimeBBMult*rSd;
         double rUpKC = rBasis + InpRegimeKCMult*rRangema, rLoKC = rBasis - InpRegimeKCMult*rRangema;
         regimeSqzOn = (rLoBB > rLoKC) && (rUpBB < rUpKC);   // BBがKC内 = 圧縮(レジーム用・緩め係数)

         if(regimeSqzOn) regimeSqueeze = true;
         else if(regimeSqueeze && longDir!=0 && m15dCur!=0) regimeSqueeze = false;
      }
      else
      {
         regimeSqueeze = false;
      }
      BufRegime[i] = regimeSqueeze ? 1.0 : 0.0;

      bool isLastBar = (i==rates_total-1);

      // ── ★A案:実ポジ同期(ライブ足のみ)。2026-06-26 双方向化 ──
      //   従来(片方向): EAがフラット(SL等で手仕舞い済み)なら指標の仮想保有も解除。
      //   追加(逆方向): EAが保有しているのに指標の仮想ポジが食い違う(=ライブ点火を
      //     確定足で取り消したフラッシュ等で孤児化)場合、指標ポジにEAの実方向を採用。
      //     → 直後の決済ブロックが走り、孤児ポジにも reason30/31/32 が正常に出る
      //       (= EAがSLまで放置される問題の根治)。売買ロジックはインジ側のまま。
      //   ※過去足は実ポジ情報が無いので純シミュレーション(ライブ足だけ補正)。
      if(isLastBar && InpSyncEAPos)
      {
         int eaDir = EAPosDir();          // +1=買い / -1=売り / 0=無し
         if(eaDir==0)
         {
            if(pos!=0) pos = 0;           // EAフラット → 指標も解除(segHadEntryは保持)
         }
         else if(pos != eaDir)
         {
            pos         = eaDir;          // EA実ポジを採用(孤児ポジを決済評価対象に戻す)
            trendDir    = eaDir;          // 再エントリーロックを正規化(グレーまで同方向の新規を抑止)
            segHadEntry = true;
            grayRun     = 0;              // MAグレー確認カウンタは採用時にリセット
         }
      }

      // ── ★2026-07-08追加: スパイク検出(DokaKotsu_Spikek_Filterと同じ考え方をロジックへ内蔵) ──
      //   ATR×InpSpikeAtrMultiplier以上の逆行でスイング確定。値幅×継続バー数=面積。
      //   外部インジ(iCustom)には依存せず、判定に使う数値は本体内で直接計算する(WYSIWYG/絶対ルール)。
      double thisBarSpikeArea = 0.0;   // このバーでスイングが確定した場合のみ非ゼロ
      if(atr[i] > 0.0)
      {
         double spkThresh = atr[i] * InpSpikeAtrMultiplier;
         if(spkDir == 0)
         {
            if(high[i] - spkSwPrice >= spkThresh)      { spkDir=1;  spkSwIdx=i; spkSwPrice=high[i]; }
            else if(spkSwPrice - low[i] >= spkThresh)  { spkDir=-1; spkSwIdx=i; spkSwPrice=low[i];  }
         }
         else if(spkDir==1)
         {
            if(high[i] > spkSwPrice) { spkSwPrice=high[i]; spkSwIdx=i; }
            else if(spkSwPrice - low[i] >= spkThresh)
            {
               thisBarSpikeArea = MathAbs(spkSwPrice - spkSwPrevPrice) * (double)MathMax(spkSwIdx - spkSwPrevIdx, 1);
               spkSwPrevIdx=spkSwIdx; spkSwPrevPrice=spkSwPrice;
               spkDir=-1; spkSwIdx=i; spkSwPrice=low[i];
            }
         }
         else // spkDir==-1
         {
            if(low[i] < spkSwPrice) { spkSwPrice=low[i]; spkSwIdx=i; }
            else if(high[i] - spkSwPrice >= spkThresh)
            {
               thisBarSpikeArea = MathAbs(spkSwPrice - spkSwPrevPrice) * (double)MathMax(spkSwIdx - spkSwPrevIdx, 1);
               spkSwPrevIdx=spkSwIdx; spkSwPrevPrice=spkSwPrice;
               spkDir=1; spkSwIdx=i; spkSwPrice=high[i];
            }
         }
      }

      BufSpikeArea[i] = thisBarSpikeArea;   // ★2026-07-09: 0(未確定)/実測面積(確定)をそのままEAへ公開

      // ★2026-07-09追加: 保持型。新しいスパイクが確定したら更新、それ以外は前回値を維持し続ける。
      if(thisBarSpikeArea > 0.0) { lastSpikeArea = thisBarSpikeArea; lastSpikeIdx = i; }
      BufSpikeAreaLast[i]  = lastSpikeArea;
      BufSpikeBarsSince[i] = (lastSpikeIdx >= 0) ? (double)(i - lastSpikeIdx) : -1.0;

      // ── ★2026-07-10追加: ⑤スパイク面積300超→ADX色が変わるまで新規エントリー禁止 ──
      //   既存③(spikeBanActive/haColor)は「保有中にスパイクで決済した場合」のみのトリガーだったが、
      //   ポジションを持っていてもいなくても「スパイクが出た波はダラダラしやすい」ため、
      //   ポジション状態に関係なく面積閾値超過そのものをトリガーにする(深夜ボラなし局面での無駄な負け対策)。
      //   基準に平均足ではなくADX色を使うのは、平均足がグレー化した後もスパイクの余韻でダマシが
      //   出た実例があったため(ADXはトレンド強度そのものを見る独立軸で、より確実な終了シグナル)。
      //   グレー経由・逆色いずれでも「トリガー時と異なる色」になった瞬間に解除する。
      if(thisBarSpikeArea >= InpSpikeAreaThresh)
      {
         spikeAdxBanTriggerArea = thisBarSpikeArea;
         spikeAdxBanTriggerIdx  = i;
         spikeAdxBanColor       = (int)BufAdxState[i];
         spikeAdxBanActive      = InpUseSpikeAdxBan; // OFF設定時はトリガー記録のみ行いゲートはしない
      }
      else if(spikeAdxBanActive && (int)BufAdxState[i] != spikeAdxBanColor)
      {
         spikeAdxBanActive = false;
      }
      BufSpikeAdxBanActive[i]      = spikeAdxBanActive ? 1.0 : 0.0;
      BufSpikeAdxBanTriggerArea[i] = spikeAdxBanTriggerArea;
      BufSpikeAdxBanBarsSince[i]   = (spikeAdxBanTriggerIdx >= 0) ? (double)(i - spikeAdxBanTriggerIdx) : -1.0;

      //   条件1: BB拡大中(圧縮でない=波が進行) 条件2: 直近3本の変化がATR2.5倍超
      //   Python(analyzer)と同じ条件。両方成立で印を出す。
      if(i >= 3 && atr[i] > 0 && !sqzOn)
      {
         double mv = MathAbs(close[i] - close[i-3]);
         if(mv >= atr[i]*2.5)
            BufOvershoot[i] = high[i] + atr[i]*1.2;   // ローソク上にマゼンタ印
      }

      // --- ② 決済（保有中）。土台: 方向MAが保有を支えなくなったら決済。平均足優先は任意 ---
      //   InpHaPriorityExit=OFF(既定): 方向MAがグレー化(cfm本確認)で決済。逆色への直接フリップは即決済。
      //   ※ドテン(同足で反対へ反転)は廃止。反対側は通常の確認付きエントリーに任せる(フラッシュ対策)。
      //   InpHaPriorityExit=ON       : 旧式(平均足の逆色転換で決済。BT比較用)。
      bool justExited = false;   // この足で決済したか(同足の通常エントリー防止)
      int  cfm = MathMax(1, InpExitGrayConfirmBars);
      double wGapExit = BufWaveVal[i] - BufWaveSig[i];   // ★2026-07-08追加: ②ウェーブクロス救済用(下のexit判定で共用)
      int waveStateExit = (wGapExit >  InpWaveNeutralBand) ?  1 :
                          (wGapExit < -InpWaveNeutralBand) ? -1 : 0;
      if(pos==1)
      {
         if(InpUseSpikeExit && thisBarSpikeArea >= InpSpikeAreaThresh)
         {
            // ★2026-07-08追加: ①スパイク面積が閾値以上→最優先で即決済
            BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=33.0; cdLeft=InpCooldownBars; grayRun=0;
            spikeBanActive = InpUseSpikeEntryBan; spikeBanHaColor = haColor[i];
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ロング・スパイク面積",DoubleToString(thisBarSpikeArea,1),")"); g_lastAlertTime=time[i]; }
         }
         else if(InpUseSpikeExit && waveStateExit==-1)
         {
            // ★2026-07-08追加: ②スパイクに遅れた場合の救済=ウェーブ下降クロスで決済
            BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=34.0; cdLeft=InpCooldownBars; grayRun=0;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ロング・ウェーブクロス救済)"); g_lastAlertTime=time[i]; }
         }
         else if(InpHaPriorityExit)
         {
            // ★2026-06-22 案B: 平均足の陰転を最優先で即決済。保険でWMA34の急反転/グレー化もOR。
            if(haColor[i]==1)
            { BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=30.0; cdLeft=InpCooldownBars; grayRun=0;
              if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ロング・平均足反転)"); g_lastAlertTime=time[i]; } }
            else if(wmaDir==-1 && prevWmaDir==1)
            { BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=31.0; cdLeft=InpCooldownBars; grayRun=0;
              if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ロング・急反転)"); g_lastAlertTime=time[i]; } }
            else if(wmaDir!=1)
            { grayRun++;
              if(grayRun>=cfm)
              { BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=32.0; cdLeft=InpCooldownBars; grayRun=0;
                if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ロング・MAグレー)"); g_lastAlertTime=time[i]; } } }
            else grayRun=0;
         }
         else if(InpExitHybridC && haColor[i]==1 && close[i] < sma2[i])
         {
            // 旧・案C(BT比較用): 平均足陰転＋価格がSMA中心線割り込み
            BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=30.0; cdLeft=InpCooldownBars; grayRun=0;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ロング・案C早決済)"); g_lastAlertTime=time[i]; }
         }
         else if(wmaDir==-1 && prevWmaDir==1)
         {
            BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=31.0; cdLeft=InpCooldownBars; grayRun=0;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ロング・急反転)"); g_lastAlertTime=time[i]; }
         }
         else if(wmaDir!=1)
         {
            grayRun++;
            if(grayRun>=cfm)
            { BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=32.0; cdLeft=InpCooldownBars; grayRun=0;
              if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ロング)"); g_lastAlertTime=time[i]; } }
         }
         else grayRun=0;
      }
      else if(pos==-1)
      {
         if(InpUseSpikeExit && thisBarSpikeArea >= InpSpikeAreaThresh)
         {
            // ★2026-07-08追加: ①スパイク面積が閾値以上→最優先で即決済
            BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=33.0; cdLeft=InpCooldownBars; grayRun=0;
            spikeBanActive = InpUseSpikeEntryBan; spikeBanHaColor = haColor[i];
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ショート・スパイク面積",DoubleToString(thisBarSpikeArea,1),")"); g_lastAlertTime=time[i]; }
         }
         else if(InpUseSpikeExit && waveStateExit==1)
         {
            // ★2026-07-08追加: ②スパイクに遅れた場合の救済=ウェーブ上昇クロスで決済
            BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=34.0; cdLeft=InpCooldownBars; grayRun=0;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ショート・ウェーブクロス救済)"); g_lastAlertTime=time[i]; }
         }
         else if(InpHaPriorityExit)
         {
            // ★2026-06-22 案B: 平均足の陽転を最優先で即決済。保険でWMA34の急反転/グレー化もOR。
            if(haColor[i]==0)
            { BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=30.0; cdLeft=InpCooldownBars; grayRun=0;
              if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ショート・平均足反転)"); g_lastAlertTime=time[i]; } }
            else if(wmaDir==1 && prevWmaDir==-1)
            { BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=31.0; cdLeft=InpCooldownBars; grayRun=0;
              if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ショート・急反転)"); g_lastAlertTime=time[i]; } }
            else if(wmaDir!=-1)
            { grayRun++;
              if(grayRun>=cfm)
              { BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=32.0; cdLeft=InpCooldownBars; grayRun=0;
                if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ショート・MAグレー)"); g_lastAlertTime=time[i]; } } }
            else grayRun=0;
         }
         else if(InpExitHybridC && haColor[i]==0 && close[i] > sma2[i])
         {
            // 旧・案C(BT比較用): 平均足陽転＋価格がSMA中心線上抜き
            BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=30.0; cdLeft=InpCooldownBars; grayRun=0;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ショート・案C早決済)"); g_lastAlertTime=time[i]; }
         }
         else if(wmaDir==1 && prevWmaDir==-1)
         {
            BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=31.0; cdLeft=InpCooldownBars; grayRun=0;
            if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ショート・急反転)"); g_lastAlertTime=time[i]; }
         }
         else if(wmaDir!=-1)
         {
            grayRun++;
            if(grayRun>=cfm)
            { BufExit[i]=sma2[i]; pos=0; justExited=true; BufReason[i]=32.0; cdLeft=InpCooldownBars; grayRun=0;
              if(InpAlert && isLastBar && time[i]!=g_lastAlertTime){ Alert(_Symbol," 終了(ショート)"); g_lastAlertTime=time[i]; } }
         }
         else grayRun=0;
      }
            else grayRun=0;   // ノーポジはリセット

      // 保有継続中なら「保有中(新規対象外)」=20
      if(pos!=0) BufReason[i]=20.0;

      // クールダウン消化(ノーポジの足ごとに1本)
      if(pos==0 && !justExited && cdLeft>0) cdLeft--;
      BufCooldownLeft[i] = (double)cdLeft;   // ★2026-07-09: 再入クールダウン残り本数をそのまま公開

      // --- ① エントリー（ノーポジ時。ただし決済と同じ足ではドテンしない）---
      if(pos==0 && !justExited)
      {
         if(cdLeft>0)
         {
            BufReason[i]=15.0;   // クールダウン中=新規を出さない(調整波回避)
         }
         else
         {
         // ── 新方式: ベースMA(選択したMAのslope方向)が主役 ──
         //   方向 d は wmaDir(=ベースMAの傾き) で決める。
         //   M1スパイク/圧縮/オーバーシュートは「任意フィルター」。
         //   全フィルターOFFなら、ベースMAの傾きだけで矢印を出す。
         // ★2026-07-08追加: ③スパイク決済後の平均足待ち状態を更新(色が変わったら解除)
         if(spikeBanActive && haColor[i] != spikeBanHaColor)
            spikeBanActive = false;

         int d = wmaDir;   // ベースMAの傾き方向(1=上/-1=下/0=平行グレー)

         if(d == 0)
         {
            BufReason[i]=10.0;   // グレーゾーン(レンジ)=待機
         }
         else
         {
            bool allow = true;

            // ★2026-07-10追加: ⑥レジーム判定(スクイーズ中は他の全フィルターより先に一括禁止)
            //   スクイーズ中はZigZag弱波(35)/スパイク関連(37/39)などトレンド専用フィルターを個別に見る意味がないため、
            //   最上流でまとめてブロックする。トレンド復帰(=長期・M15両方が非グレー)を検知した瞬間に
            //   regimeSqueeze=false となり、以降は既存の全フィルターがそのまま(変更なし)適用される。
            if(allow && regimeSqueeze) { allow=false; BufReason[i]=40.0; }

            // ★2026-07-08追加: ③スパイク決済後、平均足が変わるまで新規エントリー禁止
            if(allow && spikeBanActive) { allow=false; BufReason[i]=37.0; }

            // ★2026-07-10追加: ⑤スパイク面積300超→ADX色が変わるまで新規禁止(ポジション有無を問わない)
            if(allow && spikeAdxBanActive) { allow=false; BufReason[i]=39.0; }

            // ★Ver8 M15一致フィルター(門番): M15が点灯&M5(d)と同方向でなければ入らない
            //   M15グレー(0) or 逆方向 → 中止。点灯継続中に限りM5のグレー→点灯で入る。
            // ★2026-07-06追加(実験): InpM15ApplyToSell=falseならSELL(d==-1)はこの門番を丸ごとスキップ。
            //   下降相場でのM15平滑ラグにより「本来ブロックすべきでない場面まで待たされ、
            //   その間に価格が進み過ぎる」問題への対処。BUYは常時従来通り適用。
            if(InpUseM15Filter && (InpM15ApplyToSell || d==1))
            {
               // 点火=ライブM15(速い)。確定M15(1本前)を要求度に応じた門番にして
               //   深夜グレーのちらつき偽点灯(ライブが一瞬だけ点灯)を防ぐ。
               int m15Live = (m15n>0 && pM15c>=0 && pM15c<m15n)   ? m15dir[pM15c]   : 0; // ライブ(点火)
               int m15Conf = (m15n>0 && pM15c>=1 && pM15c-1<m15n) ? m15dir[pM15c-1] : 0; // 確定(1本前=門番)
               if(m15Live != d)   // ★2026-07-09変更: グレー許容(==-d)を戻し、グレー/逆行どちらも拒否(上昇/下降とも同一基準)
               {
                  allow = false; BufReason[i]=19.0;                       // ライブM15不一致(グレー/逆)★2026-07-09: グレーも逆行も拒否に戻す(上昇/下降とも同一基準)
               }
               else if(InpM15EntryConfirm==1 && m15Conf == -d)
               {
                  allow = false; BufReason[i]=23.0;                       // 確定M15が逆=拒否(弱)
               }
               else if(InpM15EntryConfirm>=2 && m15Conf != d)
               {
                  allow = false; BufReason[i]=23.0;                       // 確定M15がd以外(グレー/逆)=拒否(強・①対策)
               }
            }

            // ★Wave状態を長期足より前に独立評価（26=中立 / 27=上昇クロス / 28=下降クロス）
            if(allow && InpUseWaveTrigger)
            {
               double wGap = BufWaveVal[i] - BufWaveSig[i];
               int waveState = (wGap >  InpWaveNeutralBand) ?  1 :
                               (wGap < -InpWaveNeutralBand) ? -1 : 0;   // 1=上昇クロス -1=下降クロス 0=中立
               if(d==1)
               {
                  if(waveState==0)       { allow=false; BufReason[i]=26.0; } // ウェーブ中立
                  else if(waveState==-1) { allow=false; BufReason[i]=28.0; } // ウェーブ下降クロス(買い不可)
               }
               else if(d==-1)
               {
                  if(waveState==0)       { allow=false; BufReason[i]=26.0; } // ウェーブ中立
                  else if(waveState==1)  { allow=false; BufReason[i]=27.0; } // ウェーブ上昇クロス(売り不可)
               }
            }

            // ★Ver8.3 長期足フィルター(門番): 長期足(M5・KAMA360)もM5(d)と同方向=パーフェクトオーダー時のみ。
            //   短期(WMA34)・中期(M15)・長期(KAMA360)の3本が同色(全上昇or全下降)に揃わなければ待機。
            if(allow && InpUseLongFilter && longDir == -d) { allow = false; BufReason[i]=22.0; } // 長期足不一致(グレー/逆)★2026-07-08(_13)変更:longDir!=d→longDir==-d=1波目対応。長期グレー(0)は許容し、明確な逆行のみ拒否

            // ★新: 長期が先頭(最後に点灯したのが長期=後発ならNG)。長期runが他より短ければ後発。
            if(allow && InpUseLongFirst && longDir!=0 && !(longRun>=m15Run && longRun>=haRun && longRun>=colorRun))
            { allow = false; BufReason[i]=25.0; } // 長期が後発(=最後に点灯)→除外★2026-07-08(_13)変更:longDir!=0を追加=長期グレー中はこのゲートを適用しない(runが0でreason25に化けるのを防止)

            // ★守備つまみ②:色がInpColorConfirmBars本“連続”するまで入らない
            //   (レンジ内の1本だけの跳ね=単発を消す。1なら従来どおり即許可)
            if(allow && colorRun < InpColorConfirmBars) { allow = false; BufReason[i]=17.0; } // 色の確認待ち

            // ★2026-06-25 確定足ガード: 直前の確定足(i-1)のWMA34も同方向dに点灯していること。
            //   prevWmaDir=1本前の生wmaDir。ライブ足の途中でgrey→点灯した単発ブレ(=フラッシュ点火)を弾く。
            //   継続(直前足が既にd)は素通り=即時/グレー明けの一発目だけ確定1本待ち。速度は継続側で温存。
            if(allow && InpConfirmClosedBar && prevWmaDir != d) { allow = false; BufReason[i]=24.0; } // 直前確定足が未点灯=フラッシュ回避

            // ★調整波回避(任意): 平均足の色がエントリー方向と一致していること
            //   (FRAMAが一瞬上向いても、平均足がまだ陰線=押し目/戻りなら入らない)
            if(allow && !InpAlsoTakePullback)
            {
               bool haAgree = (d==1 && haColor[i]==0) || (d==-1 && haColor[i]==1);
               if(!haAgree) { allow = false; BufReason[i]=18.0; } // 平均足が逆色=調整波回避
            }

            // ※Wave判定は長期足より前へ移動済み（26/27/28）。

            // ①M1スパイク要求(ONの時だけ)：引き金が同方向に点灯していること
            if(InpFilM1Spike)
            {
               bool m1ok = (m1Onset && m1Dir==d);
               bool m5ok = (spike5 && !prevSpike5 && emaDir5==d);
               if(!(m1ok || m5ok)) { allow = false; BufReason[i]=11.0; } // M1スパイク無し
            }

            // ②圧縮フィルター(ONの時だけ)：スクイーズ中は弾く
            if(allow && InpFilSqueeze && sqzOn) { allow = false; BufReason[i]=12.0; } // 圧縮

            // ③オーバーシュートフィルター(ONの時だけ)：急変・行き過ぎは弾く
            if(allow && InpFilOvershoot && BufOvershoot[i] != 0.0) { allow = false; BufReason[i]=13.0; } // オーバーシュート

            // ★出来高フィルター(2026-06-22, ONの時だけ): 薄商い(現在<直近平均×比率)は見送り
            if(allow && InpUseVolFilter && i >= InpVolMaPeriod)
            {
               double vsum=0.0; for(int kv=1; kv<=InpVolMaPeriod; kv++) vsum += (double)tick_volume[i-kv];
               double volAvg = vsum / InpVolMaPeriod;
               if((double)tick_volume[i] < volAvg * InpVolMinRatio) { allow = false; BufReason[i]=21.0; } // 出来高薄
            }

            // ⑤方向MA(KAMA)とEMA点灯(スパイク)の同方向・同時点灯を要求(ONの時)
            //   d=KAMAの傾き方向, spike5=EMA収束スパイク点灯, emaDir5=EMAスパイクの向き
            if(allow && InpRequireEmaColit && !(spike5 && emaDir5==d)) { allow = false; BufReason[i]=16.0; } // EMA未点灯/方向不一致

            // 既に同方向で1回出していたら、平行(グレー)に戻るまで再度出さない
            //   (レンジでの連続矢印を防ぐ。trendDirが変わればまた出せる)
            if(allow && segHadEntry && d==trendDir) { allow = false; BufReason[i]=14.0; } // 再エントリーロック

            // ★2026-07-05 ADXトレンドフィルター(最終ゲート): ADXグレー(トレンド終盤ノイズ)なら
            //   他の全フィルターを通過していても最後にここで禁止する。方向不一致は見ない(色反転待ちは5分ラグが出るため)。
            if(allow && InpUseAdxFilter && BufAdxState[i]==0.0) { allow = false; BufReason[i]=29.0; } // ADXグレー(トレンド終盤ノイズ)

            // ★2026-07-06 ADX継続性チェック: 前の足がグレーだった場合、当足でADXが閾値をまたいだ
            //   "その場"では通さない。InpAdxConfirmBars本、非グレーが連続して初めて許可する。
            //   (前の足グレー→当足だけ点灯という即時フリップの飛びつきを防止)
            if(allow && InpUseAdxFilter && adxRun < InpAdxConfirmBars) { allow = false; BufReason[i]=36.0; } // ADX継続未達(直前グレーからの即時フリップ)

            // ★2026-07-06 ZigZag弱波/天底近接フィルター: 直近確定レッグ(A→B)に対する残存強度%が
            //   InpZzMinStrength未満(=反対側Aへの到達間近)ならエントリー禁止。方向dが「Bから離れる
            //   自然な継続方向」と一致する時だけ判定(B=天井なら d=-1、B=底値なら d=1)。
            if(allow && InpUseZzFilter && zzRefValid[i])
            {
               bool dirMatches = (zzRefBIsPeak[i]==1 && d==-1) || (zzRefBIsPeak[i]==-1 && d==1);
               if(dirMatches && BufZzState[i] < InpZzMinStrength)
               { allow = false; BufReason[i]=35.0; } // ZigZag弱波(反対側到達間近)
            }

            if(allow)
            {
               if(d==1)
               {
                  BufBuy[i] = low[i] - atr[i]*0.5; BufReason[i]=1.0;   // BUY発生
                  pos = 1; segHadEntry = true; trendDir = 1;
                  if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
                  { Alert(_Symbol," BUYシグナル(ベースMA)"); g_lastAlertTime=time[i]; }
               }
               else
               {
                  BufSell[i] = high[i] + atr[i]*0.5; BufReason[i]=2.0;  // SELL発生
                  pos = -1; segHadEntry = true; trendDir = -1;
                  if(InpAlert && isLastBar && time[i]!=g_lastAlertTime)
                  { Alert(_Symbol," SELLシグナル(ベースMA)"); g_lastAlertTime=time[i]; }
               }
            }
         }
         }
      }

      prevSpike5 = spike5;
      prevWmaDir = wmaDir;   // ★Ver8: 次足の直接フリップ判定用に今足のwmaDirを保存
   }
   if(doBg) ChartRedraw(0);

   return(rates_total);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
