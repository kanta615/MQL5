//+------------------------------------------------------------------+
//|                              Dokakotsu_Risk-Reward Ratio.mq5      |
//|   DokaKotsu Risk-Reward Ratio(旧 Dokakotsu_Dow_Indicator_v1)     |
//+------------------------------------------------------------------+
//| ■ 修正日: 2026-11-21(9回目)  修正内容(勝ちのpipsを500までに制限 / 現実的な候補なしの表示)     |
//|   田島さんご指示。遠い線を使った候補は現実的でなかった。取得できる(勝ちの)pipsが500pipsまでの |
//|   候補だけを出す。500pipsを超える線しか無い時は、パネルに「現実的な候補はありません」と表示。|
//|   新input InpRrMaxWinPips=500(0=制限なし)。現在値からTP(勝ちの線の手前)までのpips。       |
//|   候補が出ない時は、従来どおりGVのRR候補なし扱い=EAはreason56で見送る(RR候補ゼロ=禁止)。   |
//|   他の制限(ATRの6倍=InpRrMaxWinAtr)は従来どおり。RR1未満の候補も、そのまま出す。          |
//|   計算式・GV・EAへの受け渡しの形は変更なし。                                              |
//| ■ 修正日: 2026-11-21(8回目)  修正内容(RR候補が必ず出るようにする / 遠い線の候補)           |
//|   田島さんご指示「RR比は1以下でも必ず出して欲しい」。長期ライン(過去分)を足したのに候補が全く |
//|   出なくなった。原因: 長期ラインは現在値から遠く、RR候補の「勝ちの線が遠すぎる候補は除く」     |
//|   (InpRrMaxWinAtr=上位足ATRの6倍)に全て引っかかり、候補がゼロになった。                      |
//|   対策: まず従来どおり(遠い線を除く)で候補を作り、1件も作れない時だけ、遠い線の制限を外して    |
//|   もう一度作る。遠い線を使った候補は、パネルに「※遠い線」と付ける。RRが1未満でも、そのまま出す |
//|   (1以上=白 / 1未満=紫の色分けは従来どおり)。計算式・GV・EAへの受け渡しの形は変更なし。       |
//|   ※遠い線のRRは、勝ち幅が大きくなるため高く出やすい。EAの見送り判定(reason56)にも、そのRRが    |
//|   渡る。                                                                                    |
//| ■ 修正日: 2026-11-21(7回目)  修正内容(起動時に最近分を必ず読み直す / スキャン日時を日本時間で表示) |
//|   田島さんご指示。①起動(再起動・付け直し・時間足やパラメータの変更)のたびに、最近分        |
//|   (InpLongCacheFrom〜今)を必ず読み直して保存する(ファイルが新しくても)。以後は従来どおり  |
//|   一定時間ごと(24時間)。過去分(2013〜)は従来どおり、ファイルがあれば読まない。            |
//|   ②パネルの「スキャン」の日時は、証券会社のサーバー時間でなく日本時間で出す                  |
//|   (新input InpDispUtcOffsetH=9。サーバー時間との差を引いてUTCにし、+9時間)。例: 2026.11.21 01:44 |
//|   内部の判定(24時間ごと)はサーバー時間のまま。計算・GV・EAへの受け渡しは変更なし。            |
//| ■ 修正日: 2026-11-21(6回目)  修正内容(過去分と最近分に分けて保存し、合算して使う)          |
//|   田島さんご指示。起動時に「2013年〜2025年5月」を読み取り、一度保存したら二度と読まない。  |
//|   毎回(24時間ごと)読むのは「2025年5月〜今」だけ。この2つを合算して使う。               |
//|   ①過去分: InpArchiveFrom(既定2013.01.01。履歴が無ければある一番古い日から)〜 InpLongCacheFrom |
//|     (既定2025.05.01)。ファイル「<通貨>_archive.csv」が無い時だけ一度スキャンして保存(上限  |
//|     InpArchiveMax=30本)。ファイルがあれば読み込むだけ。設定(開始日・終了日・時間足等)を変えた |
//|     時だけ再スキャン。②最近分: InpLongCacheFrom〜今を「<通貨>_longlines.csv」に(従来どおり)。|
//|   ③InpLongCacheMonths(ヶ月前)は廃止し、開始日の指定(InpLongCacheFrom)に変更。             |
//|   ④パネルの「読取 2013.04〜…」は、過去分があれば過去分の最初の年月(=読み取った一番古い日)。   |
//|   ⑤ラインの使い方は従来どおり(上下の本数が足りない側だけ、合算したラインから現在値に近い順)。 |
//|   計算・GV・EAへの受け渡しは変更なし。                                                  |
//| ■ 修正日: 2026-11-21(5回目)  修正内容(パネルの読取期間とスキャン日時の表示)              |
//|   田島さんご指示。パネルの長期ラインの行を「読取 2013.04〜2026.11.21  スキャン 2026.11.21 01:25」|
//|   の形にした。①読取=読み取った一番古い足の年月(例 2013年4月なら 2013.04)〜 読み取った最後の足の |
//|   年月日。②スキャン=年月日と時刻(分まで)。古い年(スキャン期間を長くした時)でも、そのまま出る。 |
//|   計算・GV・EAへの受け渡しは変更なし。                                                  |
//| ■ 修正日: 2026-11-21(4回目)  修正内容(インジ一覧の名前・パネルの表示の整理)              |
//|   田島さんご指示。①インジケーター一覧に出る名前を「Dokakotsu_Risk-Reward Ratio 18」に      |
//|   (INDICATOR_SHORTNAME。ファイル名と同じ。後ろの(  )は付けない)。                       |
//|   ②パネルの長期ラインの行から「長期ライン」「(777本)」「保存12本」を消し、読み取った     |
//|   一番古い日付と、スキャン日だけにした。例: 読取 2026.05.25〜 / スキャン 2026.11.20       |
//|   計算・GV・EAへの受け渡しは変更なし。                                                  |
//| ■ 修正日: 2026-11-21(3回目)  修正内容(パネルが「未読込(スキャン待ち)」のままになる不具合)  |
//|   原因: ①v2.07で作ったCSVには「最初の足の日時」が無く、読み込んでも未読込扱いのまま、     |
//|   24時間後まで再スキャンされなかった。②期間(日時)指定のCopyRatesは、履歴が未同期だと失敗する。|
//|   対策: ①最初の日時が無い古いCSVは、すぐ再スキャンする。②期間指定で足りない時は、本数指定で |
//|   再取得する。③失敗した時は、パネルに理由(本数・エラー番号)を表示し、2分ごとに再試行する。  |
//|   計算・GV・EAへの受け渡しは変更なし。                                                  |
//| ■ 修正日: 2026-11-21(2回目)  修正内容(ファイル名に本体インジと同じ番号18 / 読み取った期間の表示)  |
//|   田島さんご指示。①ファイル名を「Dokakotsu_Risk-Reward Ratio 18.mq5」にし、DokaKotsu_  |
//|   indicator_1M_18 と同じ番号にした(次回以降も本体インジの番号に合わせる)。            |
//|   ②長期ラインで「読み取った最初の年月日(最も古い足の日付)」を表示。パネルの1行・Expertsの|
//|   ログ・CSVのヘッダー(#scan行の末尾)に出す。パネル例: 長期ライン 読取 2026.05.21〜(812本)  |
//|   保存15本 / スキャン 2026.11.21 00:50。計算・GV・EAへの受け渡しは変更なし。            |
//| ■ 修正日: 2026-11-21  修正内容(長期ラインをテキスト保存し、上下の不足を補う)(v2.07)  |
//|   田島さんご指示。急な下落で現在値の下にラインが無くなる件の追加対策。毎回、古い履歴を |
//|   計算すると重く、自動売買が止まる恐れがあるため、「数ヶ月前からの長期ライン」は        |
//|   たまにだけスキャンしてテキスト(CSV)に保存し、普段はそのファイルを読むだけにした。      |
//|   ①スキャン: 起動時にファイルが無い/古い時と、以降は一定時間ごと(既定24時間)だけ。      |
//|     H4の確定したスイング高値・安値を、InpLongCacheMonths(既定6ヶ月)前から集め、       |
//|     近い価格を1本にまとめ、点数(まとめた数+新しさ)の高い順に最大InpLongCacheMax本。   |
//|     期間内の最高値・最安値のラインは必ず含める。約800本のH4を1日1回なので負荷は小さい。 |
//|   ②保存: MQL5\Files\DokaKotsu_rr_lines\<通貨>_longlines.csv (InpLongCacheCommon=true  |
//|     なら共通フォルダ)。再起動しても、ファイルが新しければスキャンしない。               |
//|   ③使い方: 通常のライン選びの後、現在値の上側・下側で、InpImpMinPerSide(既定3)に       |
//|     足りない側だけ、保存ラインから現在値に近い順に追加(forced=RR候補に使う。表示は      |
//|     「(長期)」付き)。ファイルが無い・読めない時は従来どおり(v2.06と同じ)。             |
//|   ※スキャン期間より安く(高く)なった時は、その側に保存ラインも無い。その時は            |
//|     InpLongCacheMonthsを増やす(例: 12)。OnCalculateでの履歴の再計算はしない。          |
//|   RRの計算式・GV・EAへの受け渡しの形は変更なし。                                      |
//| ■ 修正日: 2026-11-20  修正内容(現在値の上下に、必ずラインを残す)(v2.06)             |
//|   田島さんご指示。急な下落で、現在値の下に、点数の高いラインが無くなり、RR候補が    |
//|   ゼロになった(パネル「候補なし」/ 11/19夜〜11/20)。原因: 重要なライン(点数の高い    |
//|   InpImpLineMax本だけを表示)が、すべて現在値の上側になり、下側のラインが残らなかった。|
//|   対策: 新input InpImpMinPerSide(既定3)。現在値の上側・下側のそれぞれに、最低この本数 |
//|   のラインを残す。足りない側は、候補の中で点数の高いものから追加する(ライン同士の最小  |
//|   間隔は守る)。追加したラインは、★の数が足りなくても、RR候補に使う(RR候補の対象に   |
//|   なる)。0で無効=従来どおり。ラインを探す期間(InpLineLookback)の中に、下側の候補が |
//|   無い時は、InpLineLookbackを増やす(例: 2400=H1で約100営業日)。                    |
//|   RRの計算式・GV・EAへの受け渡しの形は変更なし(候補が出るようになるだけ)。          |
//| ■ 修正日: 2026-11-05  修正内容(パネルの向きの文字に色)(v2.05)              |
//|   田島さんご指示。RR候補の行の「▲上昇(買い)」をアクア、「▼下降(売り)」を    |
//|   マゼンタ(マジェンタ)に変更。行のほかの文字(RR1 289% / 勝ち… / 負け…)は    |
//|   従来どおり(RRが1以上=白 / 1未満=紫)。見出しの「トレンド: 上昇/下降」と      |
//|   他の行は変更なし。1つの行を、前・向き・後ろの3つの文字に分けて描き、        |
//|   向きの部分だけ色を変える(位置は文字の幅を測って合わせる=見た目は従来と同じ)。|
//|   新規input: InpDirBuyColor(アクア)/InpDirSellColor(マゼンタ)。                |
//|   表示のみの変更。RRの計算・GV・EAへの受け渡しは変更なし。                    |
//| ■ 修正日: 2026-11-03(5回目)  修正内容(RR候補ごとのSL・TPをGVで公開)      |
//|   田島さんご指示「RR100%未満はエントリーしない規則」と「エントリーリーズンに |
//|   RR240 RR100 RR40 の形でRRを記載」のため。表示は変更なし。                |
//|   表示中のRR候補(最大6件)ごとに、向き・SL・TPを GV で公開する:            |
//|   YDS_C1D/C1SL/C1TP 〜 YDS_C6D/C6SL/C6TP(1が一番RRが高い。向きは +1=買い/  |
//|   -1=売り/0=なし)。DokaKotsu EA が、エントリーした瞬間の価格でRRを計算し直し、|
//|   エントリーリーズン(context.rr_list)に記録する。                          |
//|   ※「100%未満はエントリーしない」の判定は、DokaKotsu本体インジ(reason56)が   |
//|   既存のGV YDS_RB/YDS_RS(買い・売りそれぞれの最良RR)を読んで行う。          |
//| ■ 修正日: 2026-11-03(4回目)  修正内容(パネルの文字の整理)(v2.03)             |
//|   田島さんご指示。①パネルの見出しの「DokaKotsu」を「DK」に変更             |
//|   (ファイル名・チャート上の名前は変更なし)。②凡例の2行(「RR% = 勝ち幅÷負け|
//|   幅×100 RR比 1以上=白 / 1未満=紫」「★3以上の水平線が対象 / TP=勝ちの線の  |
//|   手前 / SL=負けの線の外側」)を削除。設定 InpPanelShowLegend も削除。      |
//|   ③「候補なし」の文を「候補なし(現在値の上下に★3以上の水平線が必要。)」に  |
//|   短縮。(★の数は設定 InpRrMinStars に連動)                                 |
//|   RR%の意味(勝ち幅÷負け幅×100)・色(1以上=白/1未満=紫)・TP/SLの置き方は、 |
//|   このヘッダーと、各ラインの説明(InpLineSlAtr/InpLineTpBufAtr)に残してある。|
//| ■ 修正日: 2026-11-03(3回目)  修正内容(背景の横幅を文字に合わせて小さく)(v2.02)|
//|   田島さんご指摘「背景ボックスの横幅が大きすぎる。可変型にできるか」。      |
//|   背景の幅は、元から固定値ではなく、文字の幅を測って決めていた。幅が大きく  |
//|   なっていたのは、一番長い行(凡例の1行=約85文字)に合わせていたため。        |
//|   ①凡例を2行に分けた(RR%の意味と色の説明 / TPとSLの置き方)。               |
//|   ②行の最大幅 InpPanelMaxW(既定640ピクセル)を超える行は、自動で折り返す    |
//|     (空白・「/」・「)」・句読点の後ろを優先して切る)。0で折り返さない。        |
//|   ③凡例が不要なら InpPanelShowLegend=false で消せる。                        |
//|   ④幅の測り方がずれて大きすぎる/小さすぎる時のために、補正 InpPanelWidthScale |
//|     (既定1.0。0.85なら15%狭く)を追加。                                       |
//| ■ 修正日: 2026-11-03(2回目)  修正内容(パネルの文字を1pt小さく+背景色)(v2.01) |
//|   田島さんご指示。①パネルの文字を1pt小さくした(見出し・候補の行 9→8pt、    |
//|   凡例の行 8→7pt)。新しい設定 InpPanelFontSize(既定8)で変えられる。      |
//|   ②文字が見えないため、パネルに背景(四角)を付けた。DokaKotsu_Dashboardと  |
//|   同じ形式(OBJ_RECTANGLE_LABEL・塗りつぶし・枠線つき・文字より後ろ)で、    |
//|   色はダークグレー(既定 RGB 60,60,60。Dashboardの黒系 14,17,23 より明るい)。|
//|   大きさは文字の長さに合わせて自動で決まる(余白 InpPanelPad=10)。          |
//|   新規input: InpPanelFontSize/InpPanelBgShow/InpPanelBgColor/               |
//|   InpPanelBorderColor/InpPanelPad。背景を消すには InpPanelBgShow=false。    |
//|   ※水平線の右の文字(8pt)は変更していない(背景を付けられないため)。         |
//| ■ 修正日: 2026-11-03  修正内容(RR候補の一覧に作り替え・名称変更)(v2.00)     |
//|   田島さんご指示。①ファイル名を Dokakotsu_Dow_Indicator_v1.mq5 から       |
//|   「Dokakotsu_Risk-Reward Ratio.mq5」へ変更(チャート上の名前・パネルの題名も)|
//|   ②左上パネルの内容を、水平線の一覧と「現在値から見たRR」から、「RR候補」の|
//|   一覧に入れ替えた。RR1・RR2・RR3…の順に、RRが高い順で上から並べる。       |
//|   1行 = RR比(%) / 上昇(買い)か下降(売り)か / 勝ちの期待値(pips)と          |
//|   勝ちの水平線の値 / 負けの期待値(pips)と負けの水平線の値。               |
//|   ・RR% = 勝ち幅÷負け幅×100。勝ち幅=現在値から目標(勝ちの線の手前)まで、 |
//|     負け幅=現在値から損切り(負けの線の外側)まで(pips=価格差×10)。        |
//|   ・候補: 現在値の上下にある★InpRrMinStars以上の水平線から作る。買いは勝ち |
//|     の線=上の線(近い方から InpRrWinLines 本)・負けの線=下の線(近い方から  |
//|     InpRrLossLines 本)、売りはその逆。勝ちの線が現在値から                |
//|     InpRrMaxWinAtr×上位足ATR より遠いものは除く(遠すぎる目標でRRが         |
//|     大きく見えるのを防ぐ)。最大 InpRrCandMax 件(既定6)を表示。            |
//|   ・RRが1以上は白(InpRrOkColor)、1未満は明るい紫(InpRrLowColor)で表示。   |
//|   ・上か下に水平線が無く、候補が作れない時は「候補なし」と表示。          |
//|   ③勝ち・負けとして想定した水平線は、水平線の表示をオフにしていても必ず    |
//|   引き、右に「決済対象(RR1勝ち・RR2負け…)」の文字を出す。                 |
//|   ④5分足・15分足のMTF_SR方式のラインを表示しない(点数の計算には引き続き   |
//|   使う)。プロパティからも5分足・15分足の色の入力を削除した。              |
//|   ⑤EAへのGVを RR1(全体の最良)と、買い・売りそれぞれの最良の候補に切り替え。 |
//|   (YDS_R1*, YDS_RB*, YDS_RS*。旧 YDS_RRB/RRS/SLB/TPB/SLS/TPS/UPP/UPS/DNP/DNS |
//|   は廃止)。DokaKotsu EA は、エントリーリーズンにこの値を記録する。         |
//| ■ 修正日: 2026-11-02(3回目)  修正内容(現在値から見たRR+パネル位置800)(v1.02)|
//|   田島さんご指示。①パネルの「上からの表示位置」InpPanelY の既定を 20→800 |
//|   に変更。②「現在値から見たRR」を追加(エントリーの見送り判断用)。        |
//|   現在値の直上・直下にある ★InpRrMinStars(既定3)以上 のラインだけを使い、|
//|   買い: SL=直下ライン-0.5ATR(InpLineSlAtr) / TP=直上ライン-0.1ATR、        |
//|   売り: SL=直上ライン+0.5ATR / TP=直下ライン+0.1ATR。RR=(TPまで)÷(SLまで)。|
//|   上か下に該当ラインが無い方向は算出不可(-)。InpEntryMinRR(既定1.5)未満は|
//|   パネルに「×見送り」と表示(表示とGVのフラグだけ。このインジはエントリーを|
//|   止めない)。③パネルの先頭に、買い/売りのRRと使ったラインを2行で表示。    |
//|   ④EAが記録に使えるよう、グローバル変数 YDS_RRB/RRS(RR)・YDS_SLB/TPB/SLS/  |
//|   TPS(SL・TPの価格)・YDS_UPP/UPS・DNP/DNS(使ったラインの価格と★)・        |
//|   YDS_TREND(上位足トレンド)・YDS_RRMIN(見送り基準)を公開(足が新しくなる    |
//|   たびに更新)。DokaKotsu EA が、エントリー時にこれを entry_*.jsonl の       |
//|   context(エントリーリーズン)に記録する(記録専用・発注には影響しない)。     |
//| ■ 修正日: 2026-11-02(2回目)  修正内容(パネルの行間を1.5倍に)(v1.01)       |
//|   田島さんご指示「行間が狭いので50%ほど縦に長く」。左上パネルの行の        |
//|   間隔を16ピクセル→24ピクセル(1.5倍)に変更。新しい設定 InpPanelRowH      |
//|   (既定24)で調整できる。タイトル後・現在値の行・シグナル行の余白も同じ   |
//|   比率で広げた(従来の 18/20 ピクセル → 行間×1.125 / ×1.25)。             |
//|   元に戻すには InpPanelRowH=16。                                         |
//| ■ 修正日: 2026-11-02  修正内容(名称変更+パネルの位置・色を設定可能に)  |
//|   田島さんご指示。①名称変更: Yosuga_Dow_Indicator_v6.mq5 →               |
//|   Dokakotsu_Dow_Indicator_v1.mq5。ファイル名・#property・チャート上の     |
//|   短い名前・起動ログ・パネルの題名を Dokakotsu_Dow_Indicator_v1 /         |
//|   DokaKotsu Dow v1 に変更。中身(判定・点数づけ・MTF_SR方式のライン)は    |
//|   旧v6と同じ。番号は v1 からにやり直し(旧 Yosuga_Dow v1〜v6 の続きではない)|
//|   ※EAとの受け渡し用のGV名・オブジェクト名の接頭辞「YDS_」は変更していない |
//|   (EAがYDS_のGVを読むため。EAはそのまま使える)。                         |
//|   ②画面左上のテキスト(パネル)の「上からの表示位置」を設定できるように       |
//|   した(InpPanelY、既定20ピクセル=従来と同じ)。                          |
//|   ③パネルの文字色を設定できるようにした(InpPanelColor)。既定は白。         |
//|   従来は水平線の色(赤・青など)で行ごとに色分けされていたが、全ての行が      |
//|   この1つの色になる(チャート上のラインの色や右側の文字は従来どおり)。     |
//| ■ 修正日: 2026-11-01(2回目)  修正内容(v6: MTF_SR方式のライン表示を内蔵)(旧 Yosuga_Dow v6)|
//|   田島さんご指示「重要なラインの表示を MTF_SR_Eli_MT5 のようにしたい。  |
//|   両方は使わず、MTF_SR_Eli_MT5は使わない」。①MTF_SR_Eli_MT5の表示を      |
//|   このインジに内蔵(「3c」の設定)。時間足1〜4(既定 H4/H1/M15/M5)の      |
//|   直近のフラクタル(高値=抵抗/安値=支持)を、新しいフラクタルが出るまで    |
//|   引き継いで階段状に表示。色・非表示(clrNONE)・記号/線・太さは             |
//|   MTF_SR_Eli_MT5と同じ(田島さんの現在の設定を既定にしている)。            |
//|   ②重要なライン(★・RR付き)も、含まれる最上位の時間足の色(同じ色の        |
//|   組み合わせ)で表示し、既定で点線(InpImpDots)にして見た目をそろえた。     |
//|   これでMTF_SR_Eli_MT5を別に貼る必要はない(同時に貼ると二重に出る)。      |
//|   ③バッファの並びを変更(矢印2つ+MTFの線8つ+計算用6つ=計16)。            |
//|   EAに渡すGV・シグナル判定は変更なし(EAは v5 のまま使える)。              |
//| ■ 修正日: 2026-11-01  修正内容(v5: 複数の時間足の重なりを点数づけに)(v5) |
//|   田島さんご指示「複数の時間足の重なりをv4の点数づけに組み込む。      |
//|   4時間足も加え、M30は無視」。①水平線の候補(確定ピボット)を、H4・H1・|
//|   M15・M5の4つの時間足から集める(時間足と重みは設定で変更可。重み0で |
//|   その時間足を使わない。M30は入れていない)。②重みの既定: H4=3.0 /     |
//|   H1=2.0 / M15=1.0 / M5=0.5。ピボット1つの点数(1/3/6)に、その時間足の |
//|   重みを掛けて足し合わせる。③近い価格を1本のラインにまとめる時、含ま   |
//|   れる時間足の種類が1つ増えるごとに InpConfBonus(既定2.0)を加点。      |
//|   ④ラインの文字に「重なり3(H4·H1·M15)」のように重なった時間足を表示。  |
//|   ⑤InpUseMtf=falseにするとv4と同じ(上位足1つだけ)の点数になる。         |
//|   ⑥点数の足し方: 時間足ごとに「最強のピボットの重み+繰り返しの小さな加点|
//|   (上限あり)」を出して時間足の重みを掛けて合計する(ピボットの数を単純に |
//|   足すと、低い時間足のピボットが多い混雑した価格帯が高得点になるため)。 |
//|   「重なり」に数えるのは、その時間足で主要なスイング(重み3以上=前後12本 |
//|   で最高/最安)を持つ時だけ(InpConfMinG)。                             |
//|   ※ラインをまとめる幅・反発の数え方・ATRは、従来どおり上位足(InpHigherTF)|
//|   基準。矢印/EAのシグナル判定は変更なし。                              |
//| ■ 修正日: 2026-10-31(2回目)  修正内容(v4: 重要な水平線を主役に)(v4)    |
//|   田島さんご指示「矢印は表示しなくてよい。それより重要な水平線を        |
//|   把握できるか」。①上位足(既定H1)の高値・安値(確定ピボット)を集め、     |
//|   近い価格(ATR×InpClusterAtr以内)を1本のラインにまとめ、点数づけして   |
//|   上位InpImpLineMax本だけを表示。点数=ピボット数×2+触れた回数(最大8)    |
//|   +目立つヒゲの数+キリ番(2)+前日/前週の高値安値(2)、これに新しさの係数   |
//|   (0.5〜1.0)を掛ける。★1〜5で重要度を表示。②各ラインに「そのラインで    |
//|   逆張りした場合のRR」を表示: 買いRR=ラインで買い・SL=ライン-0.5ATR・    |
//|   TP=1つ上の重要ラインの手前、売りRR=その逆。③左上パネルに、価格順の    |
//|   一覧と現在値の位置を表示。④矢印は既定で非表示(InpShowArrows=false)。   |
//|   シグナル計算とEAへのGV公開は従来どおり(EAを使わなければ無関係)。      |
//|   ⑤v3の取りこぼし修正: 押し(戻し)の極値を、ピボット確定(右4本)を待たず |
//|   直前スイング以降の最安値(最高値)で測るようにし、素早い反転でも          |
//|   ダウ転換のシグナルが成立するようにした。                              |
//| ■ 修正日: 2026-10-31  修正内容(v2のEAを「インジ+EA」に分離)(v3)        |
//|   田島さんご要望: DokaKotsuのように、矢印を出すインジと、それを読む  |
//|   EAに分ける。仕様(ロジック)はこのインジだけが持ち、修正もここだけ。 |
//|   EAは発注・建値移動(決済管理)だけを行い、仕様は持たない。           |
//|   ①上位足(既定H1)のダウ理論トレンドと水平線(高値・安値のヒゲ先)を表示|
//|   ②執行足(このチャートの時間足・既定M15)の転換初動でエントリー矢印: |
//|     買い=緑 / 売り=紫(DokaKotsuの矢印と区別するため)                |
//|   ③矢印ごとにSL・TP・RR比率を表示(RRの文字+SL/TPの線)              |
//|   ④シグナルの種類: ダウ転換 / ダブルトップ・ボトム / 三尊(逆三尊)    |
//|     / ピンバー。上位足の水平線の近くで成立した時だけ矢印を出す。     |
//|   ⑤v2(Yosuga_Dow_Strategy-v2.mq5)から直した点:                      |
//|     ・上位足トレンドの向きが逆だった判定を修正(新しい高値/安値が      |
//|       切り上がれば上昇)                                              |
//|     ・ZigZag(未確定の最新点が動く)をやめ、確定したピボットだけで判定 |
//|       (矢印は後から消えない)                                         |
//|     ・RR1.0=建値移動の位置でTPと重なり建値移動が働かなかった点は、    |
//|       TPを「次の水平線の手前」にして改善(TPモードで切替可)           |
//|   【EAへの受け渡し】チャートのこのインジが、最新のシグナル(足の時刻・|
//|   方向・SL・TP・RR・種類)と、資金管理/建値移動の設定値を、            |
//|   グローバル変数 YDS_*_<チャートID> で公開する(EAはそれを読むだけ)。 |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu Risk-Reward Ratio (formerly Dokakotsu_Dow_Indicator / Yosuga Dow)"
#property version   "2.07"
#property description "DokaKotsu Risk-Reward Ratio: 上位足の重要な水平線から、勝ち・負けの線を組み合わせたRR候補(RR1・RR2…)を高い順に表示。矢印は任意(既定は非表示)"
#property indicator_chart_window
#property indicator_buffers 16
#property indicator_plots   10

#property indicator_label1  "YDS買い"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  3
#property indicator_label2  "YDS売り"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrMagenta
#property indicator_width2  3

enum ENUM_MSR_STYLE
{
   MSR_LINE = 0,   // 線(階段状)
   MSR_DOTS = 1    // 記号(元のMT4版 #MTF SR の見た目)
};

enum ENUM_YDS_TPMODE
{
   YDS_TP_RR_FIXED     = 0,   // RR固定(SL幅×最小RR)
   YDS_TP_NEXTLINE_STR = 1,   // 次の水平線の手前(RR未満なら見送り)
   YDS_TP_NEXTLINE_RR  = 2    // 次の水平線の手前(RR未満ならRR固定)
};

//--- 入力
input group "=== 1. 時間足(執行足=このチャートの時間足。M15を推奨) ==="
input ENUM_TIMEFRAMES InpHigherTF   = PERIOD_H1;   // 上位足(トレンド・水平線)
input int             InpCalcBars   = 3000;        // 計算する執行足の本数

input group "=== 2. ダウ理論・スイング(確定したピボットだけを使う) ==="
input int    InpExecSwing  = 4;       // 執行足: ピボット確定に必要な左右の本数
input int    InpHtfSwing   = 3;       // 上位足: 同上
input int    InpAtrPeriod  = 14;      // ATR期間(執行足)

input group "=== 3. 重要な水平線(上位足の高値・安値を集めて点数づけ) ==="
input bool   InpShowLines      = true;    // 水平線を描画する
input int    InpImpLineMax     = 8;       // 表示する重要な水平線の数(点数の高い順)
input int    InpImpMinPerSide  = 3;       // ★2026-11-20追加: 現在値の上側・下側のそれぞれに、最低この本数のラインを残す(足りない側は点数の高い順に追加。RR候補に使う)。0=無効
input int    InpLineLookback   = 600;     // 候補を探す上位足の本数
input group "=== 3b. 長期ライン(テキスト保存) ★2026-11-21追加 ==="
input bool   InpUseLongCache   = true;    // 長期ラインを保存ファイルから補う(上側/下側のラインが足りない時だけ)
input datetime InpLongCacheFrom = D'2025.05.01 00:00';  // 最近分: ここから今までを、毎回(下の間隔ごと)スキャンして保存
input bool   InpArchiveUse     = true;    // 過去分も使う(起動時に、ファイルが無ければ一度だけスキャンして保存。以後は読まない)
input datetime InpArchiveFrom  = D'2013.01.01 00:00';  // 過去分: ここから「最近分の開始日」までを一度だけスキャン(履歴が無ければ、ある一番古い日から)
input int    InpDispUtcOffsetH = 9;       // パネルのスキャン日時の表示に使う時差(日本時間=9)
input int    InpArchiveMax     = 30;      // 過去分として保存するラインの最大本数
input ENUM_TIMEFRAMES InpLongCacheTF = PERIOD_H4;  // スキャンする時間足
input int    InpLongCacheSwing = 2;       // スイング判定の左右の本数
input int    InpLongCacheRefreshH = 24;   // 再スキャンの間隔(時間)。ファイルが新しければ起動時もスキャンしない
input int    InpLongCacheMax   = 15;      // 最近分として保存するラインの最大本数
input bool   InpLongCacheCommon = false;  // true=共通フォルダに保存(複数のMT5で共有) / false=このMT5のFiles
input double InpClusterAtr     = 0.5;     // この幅(上位足ATRの倍数)以内の高値・安値は1本のラインにまとめる
input double InpTouchAtr       = 0.25;    // ラインの「反発」を数える幅(上位足ATRの倍数)
input int    InpMajorBars1     = 12;      // 主要なスイングの目安(前後この本数で最も高い/低い=点数3)
input int    InpMajorBars2     = 36;      // さらに大きなスイングの目安(前後この本数で最も高い/低い=点数6)
input double InpMinSepAtr      = 1.2;     // 表示するライン同士の最小間隔(上位足ATRの倍数。近すぎる線は点数の高い方だけ)
input double InpWickAtr        = 0.5;     // 「目立つヒゲ」とみなすヒゲの長さ(上位足ATRの倍数)
input int    InpRecencyBars    = 200;     // 新しさの半減の目安(上位足の本数)
input double InpRoundStep      = 50.0;    // キリ番の間隔(価格。0=無効。金なら50や100)
input bool   InpUseDailyLevels = true;    // 前日・前週の高値安値を加点する
input double InpMinScore       = 4.0;     // この点数未満のラインは出さない
input double InpLineSlAtr      = 0.5;     // 「ラインから見たRR」のSL幅(上位足ATRの倍数)
input double InpLineTpBufAtr   = 0.1;     // TPを隣のラインの手前に置く余裕(上位足ATRの倍数)
input color  InpResColor       = clrOrangeRed;   // 現在値より上のライン(抵抗)の色
input color  InpSupColor       = clrDodgerBlue;  // 現在値より下のライン(支持)の色
input group "--- 複数の時間足の重なり(MTF)。重み0=その時間足を使わない ---"
input bool   InpUseMtf    = true;             // 複数の時間足から候補を集めて、重なりを加点する
input ENUM_TIMEFRAMES InpMtfTF1 = PERIOD_H4;  // 時間足1
input double InpMtfW1     = 3.0;              // 時間足1の重み
input ENUM_TIMEFRAMES InpMtfTF2 = PERIOD_H1;  // 時間足2
input double InpMtfW2     = 2.0;              // 時間足2の重み
input ENUM_TIMEFRAMES InpMtfTF3 = PERIOD_M15; // 時間足3
input double InpMtfW3     = 1.0;              // 時間足3の重み
input ENUM_TIMEFRAMES InpMtfTF4 = PERIOD_M5;  // 時間足4(M30は使わない)
input double InpMtfW4     = 0.5;              // 時間足4の重み
input double InpConfBonus = 2.0;              // 重なった時間足が1つ増えるごとの加点
input int    InpConfMinG  = 3;                // 「重なり」に数えるのは、その時間足で主要なスイング(重み3以上)を持つ時だけ
input int    InpMtfMaxBars = 3000;            // 時間足ごとに読み込む本数の上限
input group "=== 3c. MTF_SR方式のライン(時間足別の直近フラクタル。MTF_SR_Eli_MT5の代わり) ==="
input bool   InpShowMsr    = true;            // 時間足別の直近フラクタルのラインを表示する(時間足は上の「重なり」の時間足1〜4)
input bool   InpMsrShow1   = true;            // 時間足1を表示
input bool   InpMsrShow2   = true;            // 時間足2を表示
// ★2026-11-03: 時間足3(M15)・4(M5)のラインは表示しない(田島さんご指示)。色の入力も削除。点数の計算には引き続き使う。
input color  InpMsrHi1     = clrSienna;       // 時間足1(H4) 抵抗(高値)の色。clrNONE=表示しない
input color  InpMsrLo1     = clrRoyalBlue;    // 時間足1(H4) 支持(安値)の色
input color  InpMsrHi2     = clrRed;          // 時間足2(H1) 抵抗(高値)の色
input color  InpMsrLo2     = clrBlue;         // 時間足2(H1) 支持(安値)の色
input ENUM_MSR_STYLE InpMsrStyle = MSR_DOTS;  // 描画: 記号(元の見た目) / 線(階段状)
input int    InpMsrWidth   = 1;               // 線の太さ(元は細線)
input int    InpMsrFractal = 2;               // フラクタルの左右の本数(ウィリアムズ標準=2)
input bool   InpMsrNoLookAhead = true;        // true=確定した時点から表示 / false=元のMT4の動き(フラクタルの足から)
input bool   InpMsrLabels  = true;            // 右端に「H4 抵抗 4210.50」の文字を出す
input int    InpMsrMaxBars = 5000;            // 計算するチャートの足の本数
input int    InpMsrMaxTfBars = 20000;         // 時間足ごとに読み込む本数の上限
input bool   InpImpColorByTf = true;          // 重要なラインを、含まれる最上位の時間足の色(上の色)で表示する
input bool   InpImpDots      = true;          // 重要なラインを点線で表示する(falseなら★に応じて実線/破線)
input group "--- 矢印/EA用(シグナル判定で使う水平線) ---"
input double InpNearAtr        = 2.0;     // 「ライン付近」とみなす距離(執行足ATRの倍数)
input int    InpSigLineMax     = 6;       // シグナル判定で使うライン数(高値側・安値側それぞれ)

input group "=== 4. エントリーシグナル ==="
input bool   InpUseDow       = true;  // ダウ転換(直前のスイングのブレイク)
input bool   InpUseDouble    = true;  // ダブルトップ/ボトム(ダウ転換の特別形として種類を区別)
input bool   InpUseHS        = true;  // 三尊/逆三尊
input bool   InpUsePin       = true;  // ピンバー
input double InpPullbackAtr  = 0.8;   // 押し・戻しの最小幅(ATRの倍数。小さな揺れを除く)
input int    InpMaxPullbackBars = 60; // 直前スイングからこの本数を超えた押し・戻しは使わない
input double InpDoubleTolAtr = 0.35;  // ダブルトップ/ボトムの高さの許容差(ATR倍)
input double InpHsTolAtr     = 1.5;   // 三尊の左右の肩の高さの許容差(ATR倍)
input double InpPinWick      = 0.60;  // ピンバー: ヒゲがレンジに占める割合の下限
input double InpPinBody      = 0.35;  // ピンバー: 実体がレンジに占める割合の上限
input int    InpCooldownBars = 6;     // 同じ方向の矢印を続けて出さない本数

input group "=== 5. 損切り・利確・RR・資金管理(EAはここを読む) ==="
input double InpSlBufferAtr  = 0.2;   // SLの余裕(ATR倍。スプレッドは別に加算)
input double InpMaxSlAtr     = 10.0;  // SL幅の上限(ATR倍。広すぎるものは見送り)
input double InpMinRR        = 1.0;   // 最小リスクリターン比
input ENUM_YDS_TPMODE InpTpMode = YDS_TP_NEXTLINE_RR; // TPの決め方
input double InpTpLineBufAtr = 0.1;   // TPを次の水平線の手前に置く余裕(ATR倍)
input bool   InpUseBreakEven = true;  // 建値移動を使う
input double InpBETriggerRatio = 1.0; // SL幅の何倍進んだら建値移動するか
input double InpBEOffsetPoints = 5;   // 建値移動の上乗せ(ポイント)
input double InpRiskPercent  = 1.0;   // 1トレードの許容損失(残高の%)

input group "=== 6. 表示 ==="
input bool   InpShowArrows  = false;        // 矢印とシグナルのRR/SL/TP線を表示する(既定は非表示)
input color  InpBuyColor    = clrLime;      // 買い矢印の色(緑)
input color  InpSellColor   = clrMagenta;   // 売り矢印の色(紫)
input int    InpArrowWidth  = 3;            // 矢印の太さ
input int    InpMaxLabels   = 30;           // RR・SL/TPを表示する直近シグナル数
input bool   InpShowPanel   = true;         // 左上の情報パネル
input int    InpPanelY       = 800;          // パネルの表示位置: 画面の上からのピクセル(既定800。以前は20)
input int    InpPanelRowH    = 24;           // パネルの行の間隔(ピクセル)。従来は16。既定24=1.5倍
input int    InpRrMinStars   = 3;            // RR候補に使う水平線の最低の★の数(勝ち・負けの線とも)
input double InpEntryMinRR   = 1.5;          // EAの記録で「見送り候補」を判定する基準RR(表示とGVのフラグのみ。エントリーは止めない)
input int    InpRrCandMax    = 6;            // 表示するRR候補の最大数(RR1〜)
input int    InpRrWinLines   = 3;            // 勝ちの線として使う、現在値に近い方からの本数
input int    InpRrLossLines  = 2;            // 負けの線として使う、現在値に近い方からの本数
input double InpRrMaxWinPips = 500.0;        // ★2026-11-21追加: 勝ち(現在値からTPまで)がこのpipsより大きい候補は出さない(0=制限なし)。無ければ「現実的な候補はありません」
input double InpRrMaxWinAtr  = 6.0;          // 勝ちの線が現在値からこの値(上位足ATR倍)より遠い候補は除く(0=制限なし)
input color  InpRrOkColor    = clrWhite;     // RRが1以上の行の色
input color  InpRrLowColor   = C'204,102,255'; // RRが1未満の行の色(明るい紫)
input color  InpDirBuyColor  = clrAqua;     // ★2026-11-05追加: RR候補の行の「▲上昇(買い)」の色
input color  InpDirSellColor = clrMagenta;  // ★2026-11-05追加: RR候補の行の「▼下降(売り)」の色
input color  InpPanelColor   = clrWhite;     // パネルの文字色(既定は白。全ての行がこの色)
input int    InpPanelFontSize = 8;           // パネルの文字の大きさ(pt)。以前は9。見出し・候補の行はこの値、凡例の行は1小さい
input bool   InpPanelBgShow   = true;        // パネルの背景(四角)を表示する。DokaKotsu_Dashboardと同じ形式(塗りつぶし・枠線つき)
input color  InpPanelBgColor  = C'60,60,60';     // 背景の色(ダークグレー。Dashboardの黒系は 14,17,23)
input color  InpPanelBorderColor = C'96,96,96';  // 背景の枠線の色
input int    InpPanelPad      = 10;          // 背景の余白(ピクセル)
input int    InpPanelMaxW     = 640;         // 行の最大の幅(ピクセル)。これを超える行は自動で折り返す。0=折り返さない(背景は一番長い行に合わせて広がる)
input double InpPanelWidthScale = 1.0;       // 背景の幅の補正(文字の幅の測定が大きすぎる/小さすぎる時に調整。0.85なら15%狭く)
input bool   InpPublishGV   = true;         // EAへ受け渡すGVを公開する

//--- ピボット
struct YPivot
{
   double   price;
   int      type;      // +1=高値, -1=安値
   datetime time;
   int      bornK;
   int      diedK;
};

//--- バッファ
double BufBuy[];
double BufSell[];
double BufSL[];
double BufTP[];
double BufRR[];
double BufType[];
double BufTrend[];
double BufEntry[];
// MTF_SR方式のライン(時間足ごとに 高値側=抵抗 / 安値側=支持)
double MB0[], MB1[], MB2[], MB3[], MB4[], MB5[], MB6[], MB7[];

//--- 内部状態
int      g_hAtr = INVALID_HANDLE;
double   g_atr[];
datetime g_lastBar = 0;
int      g_lm = 6;

// 上位足
int      g_hM = 0;
datetime g_hTime[];
int      g_hTrend[];
double   g_hResP[];
double   g_hSupP[];
datetime g_hResT[];
datetime g_hSupT[];
int      g_hResN[];
int      g_hSupN[];
MqlRates g_hrr[];
YPivot   g_hp[];
int      g_hpN = 0;
int      g_act[];
int      g_actN = 0;

// シグナル記録
int      g_sigN = 0;
int      g_sigI[];
int      g_sigDir[];
int      g_sigType[];
double   g_sigEntry[];
double   g_sigSL[];
double   g_sigTP[];
double   g_sigRR[];
double   g_sigArrow[];

#define YDS_PFX "YDS_"

//+------------------------------------------------------------------+
//| 上位足ピボット: 追加(同じ種類が続いたら、より極端な方だけ残す)      |
//+------------------------------------------------------------------+
void HpAdd(const int type, const double price, const datetime tm, const int k)
{
   if(g_actN > 0)
   {
      int li = g_act[g_actN - 1];
      if(g_hp[li].type == type)
      {
         bool better = (type == 1) ? (price > g_hp[li].price) : (price < g_hp[li].price);
         if(!better) return;
         g_hp[li].diedK = k;
         g_actN--;
      }
   }
   if(g_hpN >= ArraySize(g_hp)) ArrayResize(g_hp, g_hpN + 256);
   g_hp[g_hpN].price = price;
   g_hp[g_hpN].type  = type;
   g_hp[g_hpN].time  = tm;
   g_hp[g_hpN].bornK = k;
   g_hp[g_hpN].diedK = INT_MAX;
   if(g_actN >= ArraySize(g_act)) ArrayResize(g_act, g_actN + 256);
   g_act[g_actN] = g_hpN;
   g_actN++;
   g_hpN++;
}

//+------------------------------------------------------------------+
//| 上位足のダウトレンド: 直近の高値2つ・安値2つの切り上げ/切り下げ      |
//+------------------------------------------------------------------+
int HtfTrend()
{
   double h1 = 0, h2 = 0, l1 = 0, l2 = 0;
   int nh = 0, nl = 0;
   for(int t = g_actN - 1; t >= 0 && (nh < 2 || nl < 2); t--)
   {
      int pi = g_act[t];
      if(g_hp[pi].type == 1 && nh < 2)
      {
         if(nh == 0) h1 = g_hp[pi].price; else h2 = g_hp[pi].price;
         nh++;
      }
      else if(g_hp[pi].type == -1 && nl < 2)
      {
         if(nl == 0) l1 = g_hp[pi].price; else l2 = g_hp[pi].price;
         nl++;
      }
   }
   if(nh < 2 || nl < 2) return 0;
   if(h1 > h2 && l1 > l2) return 1;     // 高値も安値も切り上げ=上昇
   if(h1 < h2 && l1 < l2) return -1;    // 高値も安値も切り下げ=下降
   return 0;
}

//+------------------------------------------------------------------+
//| 上位足の水平線(その時点の直近の高値・安値)を保存                    |
//+------------------------------------------------------------------+
void HtfCollect(const int k)
{
   int base = k * g_lm;
   int nr = 0, ns = 0;
   for(int t = g_actN - 1; t >= 0 && (nr < g_lm || ns < g_lm); t--)
   {
      int pi = g_act[t];
      if(g_hp[pi].type == 1 && nr < g_lm)
      {
         g_hResP[base + nr] = g_hp[pi].price;
         g_hResT[base + nr] = g_hp[pi].time;
         nr++;
      }
      else if(g_hp[pi].type == -1 && ns < g_lm)
      {
         g_hSupP[base + ns] = g_hp[pi].price;
         g_hSupT[base + ns] = g_hp[pi].time;
         ns++;
      }
   }
   g_hResN[k] = nr;
   g_hSupN[k] = ns;
}

//+------------------------------------------------------------------+
//| 上位足データの構築(確定した足だけ。最後の足は形成中なので使わない)  |
//+------------------------------------------------------------------+
bool BuildHtf()
{
   int execSec = PeriodSeconds(_Period);
   int htfSec  = PeriodSeconds(InpHigherTF);
   if(execSec <= 0 || htfSec <= 0) return false;
   int R = MathMax(1, InpHtfSwing);
   int want = (int)((double)InpCalcBars * execSec / htfSec) + 100 + 4 * R;
   if(want < InpLineLookback + 4 * R + 60) want = InpLineLookback + 4 * R + 60;
   int avail = Bars(_Symbol, InpHigherTF);
   if(avail < 30) return false;
   if(want > avail) want = avail;

   MqlRates rr[];
   ArraySetAsSeries(rr, false);
   int got = CopyRates(_Symbol, InpHigherTF, 0, want, rr);
   if(got < 30) return false;

   g_hM = got;
   ArrayResize(g_hrr, got);
   ArrayCopy(g_hrr, rr, 0, 0, got);
   ArrayResize(g_hTime,  got);
   ArrayResize(g_hTrend, got);
   ArrayResize(g_hResN,  got);
   ArrayResize(g_hSupN,  got);
   ArrayResize(g_hResP,  got * g_lm);
   ArrayResize(g_hSupP,  got * g_lm);
   ArrayResize(g_hResT,  got * g_lm);
   ArrayResize(g_hSupT,  got * g_lm);
   g_hpN = 0;
   g_actN = 0;

   for(int k = 0; k < got; k++)
   {
      g_hTime[k]  = rr[k].time;
      g_hTrend[k] = 0;
      g_hResN[k]  = 0;
      g_hSupN[k]  = 0;
      int j = k - R;                       // ピボット候補の足(右にR本確定したら判定できる)
      if(k <= got - 2 && j - R >= 0)
      {
         bool isH = true, isL = true;
         for(int t = j - R; t <= j + R; t++)
         {
            if(t == j) continue;
            if(rr[t].high > rr[j].high) isH = false;
            if(rr[t].low  < rr[j].low)  isL = false;
         }
         if(isH && isL)                    // 包み足: 直前と交互になる側を採る
         {
            if(g_actN > 0 && g_hp[g_act[g_actN - 1]].type == 1) isH = false; else isL = false;
         }
         if(isH)      HpAdd(1,  rr[j].high, rr[j].time, k);
         else if(isL) HpAdd(-1, rr[j].low,  rr[j].time, k);
      }
      g_hTrend[k] = HtfTrend();
      HtfCollect(k);
   }
   return true;
}

//+------------------------------------------------------------------+
//| 水平線の近さ・次の水平線                                           |
//+------------------------------------------------------------------+
bool NearLine(const int k, const double price, const double dist)
{
   int base = k * g_lm;
   for(int t = 0; t < g_hResN[k]; t++) if(MathAbs(g_hResP[base + t] - price) <= dist) return true;
   for(int t = 0; t < g_hSupN[k]; t++) if(MathAbs(g_hSupP[base + t] - price) <= dist) return true;
   return false;
}

double NextLine(const int k, const double entry, const int d, const double minGap)
{
   int base = k * g_lm;
   double best = 0.0;
   for(int pass = 0; pass < 2; pass++)
   {
      int n = (pass == 0) ? g_hResN[k] : g_hSupN[k];
      for(int t = 0; t < n; t++)
      {
         double p = (pass == 0) ? g_hResP[base + t] : g_hSupP[base + t];
         if(d == 1)
         {
            if(p > entry + minGap && (best == 0.0 || p < best)) best = p;
         }
         else
         {
            if(p < entry - minGap && (best == 0.0 || p > best)) best = p;
         }
      }
   }
   return best;
}

//+------------------------------------------------------------------+
//| 執行足ピボットの追加(固定長スタック)                                |
//+------------------------------------------------------------------+
#define E_CAP 40
void EAdd(double &eP[], int &eT[], int &eI[], int &eN, const int type, const double price, const int idx)
{
   if(eN > 0 && eT[eN - 1] == type)
   {
      bool better = (type == 1) ? (price > eP[eN - 1]) : (price < eP[eN - 1]);
      if(!better) return;
      eN--;
   }
   if(eN >= E_CAP)
   {
      for(int t = 1; t < E_CAP; t++) { eP[t - 1] = eP[t]; eT[t - 1] = eT[t]; eI[t - 1] = eI[t]; }
      eN = E_CAP - 1;
   }
   eP[eN] = price; eT[eN] = type; eI[eN] = idx;
   eN++;
}

//+------------------------------------------------------------------+
//| オブジェクト補助                                                  |
//+------------------------------------------------------------------+
void PutLabel(const string name, const int x, const int y, const string text, const color col, const int size)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_FONT, "Meiryo");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void PutTrend(const string name, const datetime t1, const double p1, const datetime t2, const double p2,
              const color col, const int style, const int width, const bool rayRight)
{
   ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, rayRight);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void PutText(const string name, const datetime t, const double p, const string text, const color col, const int size, const ENUM_ANCHOR_POINT anchor)
{
   ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Meiryo");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

string TypeName(const int ty)
{
   if(ty == 1) return "ダウ転換";
   if(ty == 2) return "ダブル";
   if(ty == 3) return "ピンバー";
   if(ty == 4) return "三尊";
   return "-";
}

string TfName(const ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);
   if(StringFind(s, "PERIOD_") == 0) s = StringSubstr(s, 7);
   return s;
}

//+------------------------------------------------------------------+
//| 重要な水平線: 上位足の高値・安値(確定ピボット)を集め、近い価格を1本に   |
//| まとめて点数づけし、点数の高い順に上位だけを残す                      |
//+------------------------------------------------------------------+
struct YLine
{
   double   price;
   double   score;
   int      pivots;      // まとめたピボット(高値・安値)の数
   int      episodes;    // ラインに触れた回数(連続して触れた足は1回)
   int      wicks;       // 目立つヒゲで付いたピボットの数
   int      age;         // 最後に触れてからの上位足の本数
   bool     isRound;     // キリ番
   bool     isDaily;     // 前日・前週の高値安値
   datetime firstTime;   // 最初のピボットの時刻(線の始点)
   int      tfMask;      // 含まれる時間足(ビット: 1=時間足1 2=時間足2 4=時間足3 8=時間足4 16=上位足のみ)
   int      nTf;         // 重なった時間足の数
   bool     forced;      // ★2026-11-20: 上側/下側の最低本数のために追加したライン(★の数が足りなくてもRR候補に使う)
   bool     fromCache;   // ★2026-11-21: 長期ライン(保存ファイル)から追加したライン
};
YLine  g_imp[];
int    g_impN = 0;
double g_hAtrLast = 0.0;
double g_impMax = 1.0;

// ★の数: 表示中のラインの最高点に対する割合(相場の値動きの大きさに左右されないように相対評価)
int StarsOf(const double sc)
{
   double r = (g_impMax > 0.0) ? sc / g_impMax : 0.0;
   if(r >= 0.75) return 5;
   if(r >= 0.55) return 4;
   if(r >= 0.40) return 3;
   if(r >= 0.25) return 2;
   return 1;
}

// 時間足ごとのデータ(上位足以外も含む)
MqlRates g_m0[];
MqlRates g_m1[];
MqlRates g_m2[];
MqlRates g_m3[];
int      g_mN[4] = {0, 0, 0, 0};
ENUM_TIMEFRAMES g_mTf[4];
double   g_mW[4];

// 候補(全時間足分)
double   g_cP[];
datetime g_cT[];
int      g_cW[];
double   g_cG[];
int      g_cB[];
int      g_cn = 0;

void InitMtfSlots()
{
   g_mTf[0] = InpMtfTF1; g_mTf[1] = InpMtfTF2; g_mTf[2] = InpMtfTF3; g_mTf[3] = InpMtfTF4;
   g_mW[0]  = InpMtfW1;  g_mW[1]  = InpMtfW2;  g_mW[2]  = InpMtfW3;  g_mW[3]  = InpMtfW4;
}

bool LoadMtfSlot(const int k)
{
   g_mN[k] = 0;
   if(!InpUseMtf || g_mW[k] <= 0.0) return false;
   int tfSec = PeriodSeconds(g_mTf[k]);
   if(tfSec <= 0) return false;
   int lbSec = MathMax(50, InpLineLookback) * PeriodSeconds(InpHigherTF);
   int want = lbSec / tfSec + 4 * MathMax(1, InpHtfSwing) + 40;
   want = MathMin(want, MathMax(100, InpMtfMaxBars));
   int avail = Bars(_Symbol, g_mTf[k]);
   if(avail < 40) return false;
   if(want > avail) want = avail;
   MqlRates tmp[];
   ArraySetAsSeries(tmp, false);
   int got = CopyRates(_Symbol, g_mTf[k], 0, want, tmp);
   if(got < 40) return false;
   switch(k)
   {
      case 0: ArrayResize(g_m0, got); ArrayCopy(g_m0, tmp, 0, 0, got); break;
      case 1: ArrayResize(g_m1, got); ArrayCopy(g_m1, tmp, 0, 0, got); break;
      case 2: ArrayResize(g_m2, got); ArrayCopy(g_m2, tmp, 0, 0, got); break;
      case 3: ArrayResize(g_m3, got); ArrayCopy(g_m3, tmp, 0, 0, got); break;
   }
   g_mN[k] = got;
   return true;
}

void BuildMtf()
{
   for(int k = 0; k < 4; k++) LoadMtfSlot(k);
}

// 時間足の足 j が、前後 W 本の中で最も高い(低い)か。範囲が履歴の外なら「該当しない」
bool IsExtremeArr(const MqlRates &rr[], const int j, const int W, const bool isHigh, const int last)
{
   if(j - W < 0 || j + W > last) return false;
   for(int t = j - W; t <= j + W; t++)
   {
      if(t == j) continue;
      if(isHigh) { if(rr[t].high > rr[j].high) return false; }
      else       { if(rr[t].low  < rr[j].low)  return false; }
   }
   return true;
}

// 1つの時間足から、確定したスイングの高値・安値を候補に追加(重み付き)
void CollectFromArray(const MqlRates &rr[], const int n, const int bit, const double w, const datetime fromTime)
{
   if(n < 40 || w <= 0.0) return;
   int R = MathMax(1, InpHtfSwing);
   int last = n - 2;                        // 最後の確定した足
   double sumTr = 0.0;
   int cnt = 0;
   for(int b = last; b > last - 14 && b >= 1; b--)
   {
      double tr = MathMax(rr[b].high - rr[b].low, MathMax(MathAbs(rr[b].high - rr[b - 1].close), MathAbs(rr[b].low - rr[b - 1].close)));
      sumTr += tr;
      cnt++;
   }
   if(cnt == 0) return;
   double atr = sumTr / cnt;
   if(atr <= 0.0) return;
   for(int j = R; j <= last - R; j++)
   {
      if(rr[j].time < fromTime) continue;
      bool isH = true, isL = true;
      for(int t = j - R; t <= j + R; t++)
      {
         if(t == j) continue;
         if(rr[t].high > rr[j].high) isH = false;
         if(rr[t].low  < rr[j].low)  isL = false;
      }
      if(!isH && !isL) continue;
      if(g_cn + 2 > ArraySize(g_cP))
      {
         int ns = ArraySize(g_cP) + 1024;
         ArrayResize(g_cP, ns); ArrayResize(g_cT, ns); ArrayResize(g_cW, ns); ArrayResize(g_cG, ns); ArrayResize(g_cB, ns);
      }
      double bodyHi = MathMax(rr[j].open, rr[j].close);
      double bodyLo = MathMin(rr[j].open, rr[j].close);
      if(isH)
      {
         int g = 1;
         if(IsExtremeArr(rr, j, InpMajorBars1, true, last)) g = 3;
         if(IsExtremeArr(rr, j, InpMajorBars2, true, last)) g = 6;
         g_cP[g_cn] = rr[j].high; g_cT[g_cn] = rr[j].time; g_cG[g_cn] = g; g_cB[g_cn] = bit;
         g_cW[g_cn] = ((rr[j].high - bodyHi) >= InpWickAtr * atr) ? 1 : 0;
         g_cn++;
      }
      if(isL)
      {
         int g = 1;
         if(IsExtremeArr(rr, j, InpMajorBars1, false, last)) g = 3;
         if(IsExtremeArr(rr, j, InpMajorBars2, false, last)) g = 6;
         g_cP[g_cn] = rr[j].low; g_cT[g_cn] = rr[j].time; g_cG[g_cn] = g; g_cB[g_cn] = bit;
         g_cW[g_cn] = ((bodyLo - rr[j].low) >= InpWickAtr * atr) ? 1 : 0;
         g_cn++;
      }
   }
}

int SlotOfBit(const int bit)
{
   if(bit == 1) return 0;
   if(bit == 2) return 1;
   if(bit == 4) return 2;
   if(bit == 8) return 3;
   return 4;
}

int PopCount(const int v)
{
   int c = 0;
   for(int b = 0; b < 4; b++) if((v & (1 << b)) != 0) c++;
   return c;
}

string TfListText(const int mask)
{
   if((mask & 16) != 0) return TfName(InpHigherTF);
   string r = "";
   for(int k = 0; k < 4; k++)
      if((mask & (1 << k)) != 0) r += (r == "" ? "" : "·") + TfName(g_mTf[k]);
   return r;
}

//+------------------------------------------------------------------+
//| ★2026-11-21 長期ライン: H4をスキャン → テキスト(CSV)に保存                   |
//| ★2026-11-21(6回目): 2つに分けて保存し、合算して使う                           |
//|   過去分 = InpArchiveFrom(例 2013年)〜 InpLongCacheFrom(例 2025.05)。一度だけスキャンして |
//|           保存し、ファイルがあれば二度と読まない(設定を変えた時だけ再スキャン)。        |
//|   最近分 = InpLongCacheFrom 〜 今。起動時にファイルが無い/古い時と、一定時間ごと(24時間)。|
//| 普段はメモリのラインを使うだけ(OnCalculateで履歴の再計算はしない)。                 |
//+------------------------------------------------------------------+
struct LcLine
{
   double   price;
   double   score;
   int      pivots;
   datetime firstT;
   datetime lastT;
};
struct LcMeta
{
   datetime scanT;     // スキャンした日時
   datetime firstT;    // 読み取った最初(最も古い)の足
   datetime lastT;     // 読み取った最後の足
   int      bars;      // 読み取った足の本数
};
LcLine   g_lc[];                // 使うライン(過去分+最近分の合算)
int      g_lcN        = 0;
LcLine   g_lcRec[];             // 最近分
int      g_lcRecN     = 0;
LcLine   g_lcArc[];             // 過去分
int      g_lcArcN     = 0;
LcMeta   g_mRec;
LcMeta   g_mArc;
datetime g_lcScanTime = 0;      // パネル用: 最近分の最後のスキャン日時
datetime g_lcFirstT   = 0;      // パネル用: 読み取った一番古い足(過去分があれば過去分の最初)
datetime g_lcLastT    = 0;      // パネル用: 読み取った最後の足
int      g_lcBars     = 0;
datetime g_lcNextTry  = 0;      // 最近分のスキャン失敗時の再試行時刻
datetime g_lcArcNextTry = 0;    // 過去分のスキャン失敗時の再試行時刻
string   g_lcStatus   = "";     // パネルに出す状態(失敗の理由など)
bool     g_lcLoaded   = false;
bool     g_lcForceRec = true;   // ★2026-11-21(7回目): 起動後の最初は、最近分を必ず読み直す

string LcFileName(const bool arc) { return "DokaKotsu_rr_lines\\" + _Symbol + (arc ? "_archive.csv" : "_longlines.csv"); }
int    LcFileFlags(const bool write)
{
   int fl = (write ? FILE_WRITE : (FILE_READ | FILE_SHARE_READ | FILE_SHARE_WRITE)) | FILE_TXT | FILE_ANSI;
   if(InpLongCacheCommon) fl |= FILE_COMMON;
   return fl;
}

// 読み取りの範囲を示すキー(ファイルの設定が今の設定と同じ時だけ、ファイルを使う)
long LcKeyFrom(const bool arc) { return arc ? (long)InpArchiveFrom : (long)InpLongCacheFrom; }
long LcKeyTo(const bool arc)   { return arc ? (long)InpLongCacheFrom : 0; }

// ファイルを読む(通貨・時間足・範囲・スイングが今の設定と同じ時だけ有効)
bool LcLoadFile(const bool arc)
{
   LcLine tmp[]; int tn = 0;
   LcMeta mt; ZeroMemory(mt);
   int h = FileOpen(LcFileName(arc), LcFileFlags(false));
   if(h == INVALID_HANDLE) return false;
   bool okHead = false;
   while(!FileIsEnding(h))
   {
      string ln = FileReadString(h);
      StringTrimLeft(ln); StringTrimRight(ln);
      if(ln == "") continue;
      string pt[];
      int np = StringSplit(ln, ',', pt);
      if(StringGetCharacter(ln, 0) == '#')
      {
         // #scan,<epoch>,<symbol>,<tf>,<from>,<swing>,<日時>,<first>,<bars>,first=…,<last>,<to>
         if(np >= 12 && pt[0] == "#scan" && pt[2] == _Symbol &&
            (int)StringToInteger(pt[3]) == (int)InpLongCacheTF &&
            StringToInteger(pt[4]) == LcKeyFrom(arc) &&
            (int)StringToInteger(pt[5]) == InpLongCacheSwing &&
            StringToInteger(pt[11]) == LcKeyTo(arc))
         {
            okHead = true;
            mt.scanT  = (datetime)StringToInteger(pt[1]);
            mt.firstT = (datetime)StringToInteger(pt[7]);
            mt.bars   = (int)StringToInteger(pt[8]);
            mt.lastT  = (datetime)StringToInteger(pt[10]);
         }
         continue;
      }
      if(!okHead || np < 5) continue;
      double pr = StringToDouble(pt[0]);
      if(pr <= 0.0) continue;
      ArrayResize(tmp, tn + 1);
      tmp[tn].price  = pr;
      tmp[tn].score  = StringToDouble(pt[1]);
      tmp[tn].pivots = (int)StringToInteger(pt[2]);
      tmp[tn].firstT = (datetime)StringToInteger(pt[3]);
      tmp[tn].lastT  = (datetime)StringToInteger(pt[4]);
      tn++;
   }
   FileClose(h);
   if(!okHead || mt.firstT == 0 || tn == 0) return false;
   if(arc) { ArrayResize(g_lcArc, tn); for(int k = 0; k < tn; k++) g_lcArc[k] = tmp[k]; g_lcArcN = tn; g_mArc = mt; }
   else    { ArrayResize(g_lcRec, tn); for(int k = 0; k < tn; k++) g_lcRec[k] = tmp[k]; g_lcRecN = tn; g_mRec = mt; }
   Print("[YDS] 長期ライン(", (arc ? "過去分" : "最近分"), "): ファイルを読みました ", tn, "本 (スキャン日時 ", TimeToString(mt.scanT, TIME_DATE | TIME_MINUTES),
         ") 読み取った最初の日 ", TimeToString(mt.firstT, TIME_DATE), " 足数 ", mt.bars);
   return true;
}

bool LcSaveFile(const bool arc)
{
   int h = FileOpen(LcFileName(arc), LcFileFlags(true));
   if(h == INVALID_HANDLE) { Print("[YDS] 長期ライン: 保存に失敗 err=", GetLastError()); return false; }
   LcMeta mt;
   if(arc) mt = g_mArc; else mt = g_mRec;
   int cnt = arc ? g_lcArcN : g_lcRecN;
   FileWriteString(h, "#DKRR_LONGLINES v2.07 " + (arc ? "archive" : "recent") + "\r\n");
   FileWriteString(h, "#scan," + IntegerToString((long)mt.scanT) + "," + _Symbol + "," +
                      IntegerToString((int)InpLongCacheTF) + "," + IntegerToString(LcKeyFrom(arc)) + "," +
                      IntegerToString(InpLongCacheSwing) + "," + TimeToString(mt.scanT, TIME_DATE | TIME_MINUTES) + "," +
                      IntegerToString((long)mt.firstT) + "," + IntegerToString(mt.bars) + "," +
                      "first=" + TimeToString(mt.firstT, TIME_DATE | TIME_MINUTES) + "," + IntegerToString((long)mt.lastT) + "," +
                      IntegerToString(LcKeyTo(arc)) + "\r\n");
   FileWriteString(h, "price,score,pivots,first_epoch,last_epoch,last_time\r\n");
   for(int k = 0; k < cnt; k++)
   {
      LcLine ln;
      if(arc) ln = g_lcArc[k]; else ln = g_lcRec[k];
      FileWriteString(h, DoubleToString(ln.price, _Digits) + "," + DoubleToString(ln.score, 2) + "," +
                         IntegerToString(ln.pivots) + "," + IntegerToString((long)ln.firstT) + "," +
                         IntegerToString((long)ln.lastT) + "," + TimeToString(ln.lastT, TIME_DATE | TIME_MINUTES) + "\r\n");
   }
   FileClose(h);
   return true;
}

// 範囲[from,to]のH4を読み、スイング高値・安値を集めて1本にまとめ、点数の高い順に最大maxN本(最高値・最安値は必ず含める)
bool LcScanRange(const datetime from, const datetime to, const int maxN, LcLine &out[], int &outN, LcMeta &mt, string &why)
{
   datetime nowT = TimeCurrent();
   MqlRates r[];
   ArraySetAsSeries(r, false);
   ResetLastError();
   int n = CopyRates(_Symbol, InpLongCacheTF, from, to, r);
   int err1 = GetLastError();
   if(n < 60)
   {
      // 期間指定で取れない時は、本数指定でもう一度(多めに取り、範囲外は捨てる)
      int ps = MathMax(60, PeriodSeconds(InpLongCacheTF));
      long want = (long)((double)(nowT - from) / ps * 0.8) + 100;
      if(want > 200000) want = 200000;
      ResetLastError();
      int n2 = CopyRates(_Symbol, InpLongCacheTF, 0, (int)want, r);
      int err2 = GetLastError();
      if(n2 < 60)
      {
         why = "スキャン失敗: " + TfName(InpLongCacheTF) + "の履歴が足りません(期間指定" + IntegerToString(n) + "本 err" + IntegerToString(err1) +
               " / 本数指定" + IntegerToString(n2) + "本 err" + IntegerToString(err2) + ")。" + TfName(InpLongCacheTF) + "のチャートを一度開いてください";
         return false;
      }
      int a0 = 0;  while(a0 < n2 && r[a0].time < from) a0++;
      int a1 = n2; while(a1 > a0 && r[a1 - 1].time > to) a1--;
      int mm = a1 - a0;
      if(mm < 60) { why = "スキャン失敗: 範囲内の足が" + IntegerToString(mm) + "本しかありません"; return false; }
      if(a0 > 0) for(int z = a0; z < a1; z++) r[z - a0] = r[z];
      ArrayResize(r, mm);
      n = mm;
   }
   int R = MathMax(1, InpLongCacheSwing);
   // ATR(14本の平均の値幅)。ラインをまとめる幅の基準(範囲の終わりの値動きで測る)
   double sumTr = 0.0; int cTr = 0;
   for(int b = n - 2; b > n - 16 && b >= 1; b--)
   {
      sumTr += MathMax(r[b].high - r[b].low, MathMax(MathAbs(r[b].high - r[b - 1].close), MathAbs(r[b].low - r[b - 1].close)));
      cTr++;
   }
   if(cTr == 0 || sumTr <= 0.0) { why = "スキャン失敗: 値幅を計算できません"; return false; }
   double atr = sumTr / cTr;
   double tol = InpClusterAtr * atr;
   double sep = InpMinSepAtr * atr;
   // スイング高値・安値(最後の足は使わない)
   double   pp[]; datetime pt[];
   int np = 0;
   double hiAll = -1.0, loAll = 1e18; datetime hiT = 0, loT = 0;
   for(int i = 0; i < n - 1; i++)
   {
      if(r[i].high > hiAll) { hiAll = r[i].high; hiT = r[i].time; }
      if(r[i].low  < loAll) { loAll = r[i].low;  loT = r[i].time; }
   }
   for(int i = R; i <= n - 2 - R; i++)
   {
      bool isH = true, isL = true;
      for(int k = 1; k <= R; k++)
      {
         if(r[i].high < r[i - k].high || r[i].high < r[i + k].high) isH = false;
         if(r[i].low  > r[i - k].low  || r[i].low  > r[i + k].low)  isL = false;
      }
      if(isH) { ArrayResize(pp, np + 1, 256); ArrayResize(pt, np + 1, 256); pp[np] = r[i].high; pt[np] = r[i].time; np++; }
      if(isL) { ArrayResize(pp, np + 1, 256); ArrayResize(pt, np + 1, 256); pp[np] = r[i].low;  pt[np] = r[i].time; np++; }
   }
   if(np == 0) { why = "スキャン失敗: スイングが見つかりません"; return false; }
   // 価格順に並べる(挿入ソート)
   for(int a = 1; a < np; a++)
   {
      double kp = pp[a]; datetime kt = pt[a];
      int w = a - 1;
      while(w >= 0 && pp[w] > kp) { pp[w + 1] = pp[w]; pt[w + 1] = pt[w]; w--; }
      pp[w + 1] = kp; pt[w + 1] = kt;
   }
   // 近い価格を1本にまとめる
   LcLine cl[]; int nc = 0;
   double span = (double)MathMax(1, (long)(r[n - 1].time - r[0].time));
   int a = 0;
   while(a < np)
   {
      double sum = pp[a]; int cnt = 1; datetime t0 = pt[a], t1 = pt[a];
      int b = a + 1;
      while(b < np && pp[b] - sum / cnt <= tol)
      {
         sum += pp[b]; cnt++;
         if(pt[b] < t0) t0 = pt[b];
         if(pt[b] > t1) t1 = pt[b];
         b++;
      }
      ArrayResize(cl, nc + 1, 256);
      cl[nc].price  = sum / cnt;
      cl[nc].pivots = cnt;
      cl[nc].firstT = t0;
      cl[nc].lastT  = t1;
      cl[nc].score  = cnt + (double)(t1 - r[0].time) / span;     // まとめた数 + 新しさ(0〜1)
      nc++;
      a = b;
   }
   // 範囲内の最高値・最安値のラインは必ず含める → 残りは点数の高い順(最小間隔を守る)
   LcLine res[]; int rn = 0;
   double ex[2]; ex[0] = hiAll; ex[1] = loAll;
   datetime ext[2]; ext[0] = hiT; ext[1] = loT;
   for(int e = 0; e < 2; e++)
   {
      ArrayResize(res, rn + 1);
      res[rn].price = ex[e]; res[rn].pivots = 1; res[rn].firstT = ext[e]; res[rn].lastT = ext[e];
      res[rn].score = 1.0;
      rn++;
   }
   bool usedC[]; ArrayResize(usedC, nc); ArrayInitialize(usedC, false);
   int lim = MathMax(2, maxN);
   while(rn < lim)
   {
      int best = -1; double bs = -1.0;
      for(int c = 0; c < nc; c++)
      {
         if(usedC[c] || cl[c].score <= bs) continue;
         bool nearC = false;
         for(int q = 0; q < rn; q++) if(MathAbs(res[q].price - cl[c].price) < sep) { nearC = true; break; }
         if(nearC) { usedC[c] = true; continue; }
         best = c; bs = cl[c].score;
      }
      if(best < 0) break;
      usedC[best] = true;
      ArrayResize(res, rn + 1);
      res[rn] = cl[best];
      rn++;
   }
   ArrayResize(out, rn);
   for(int k = 0; k < rn; k++) out[k] = res[k];
   outN = rn;
   mt.scanT  = TimeTradeServer();      // 週末など相場が止まっていても、サーバー時間が進む時刻を使う
   mt.firstT = r[0].time;
   mt.lastT  = r[n - 1].time;
   mt.bars   = n;
   return true;
}

// 過去分と最近分を合算して、使うライン(g_lc)とパネル用の値を作る
void LcMerge()
{
   int tot = g_lcRecN + g_lcArcN;
   ArrayResize(g_lc, tot);
   g_lcN = 0;
   for(int k = 0; k < g_lcRecN; k++) { g_lc[g_lcN] = g_lcRec[k]; g_lcN++; }
   for(int k = 0; k < g_lcArcN; k++) { g_lc[g_lcN] = g_lcArc[k]; g_lcN++; }
   g_lcScanTime = g_mRec.scanT;
   g_lcLastT    = (g_mRec.lastT > 0) ? g_mRec.lastT : g_mArc.lastT;
   g_lcBars     = g_mRec.bars + g_mArc.bars;
   g_lcFirstT   = (g_mArc.firstT > 0) ? g_mArc.firstT : g_mRec.firstT;     // 読み取った一番古い日付(過去分があれば過去分の最初)
}

// 新しい足ごとに呼ぶ(軽い判定だけ)。過去分=ファイルが無い時だけ一度 / 最近分=ファイルが無い/古い時と一定時間ごと
void LcService()
{
   if(!InpUseLongCache) return;
   datetime nowT = TimeTradeServer();      // TimeCurrentは相場が止まる週末は古いまま。TimeTradeServerは進む
   if(!g_lcLoaded)
   {
      g_lcLoaded = true;
      if(InpArchiveUse) LcLoadFile(true);
      LcLoadFile(false);
      LcMerge();
   }
   bool changed = false;
   string why = "";
   if(InpArchiveUse && g_mArc.firstT == 0 && g_lcArcNextTry <= nowT)
   {
      if(LcScanRange(InpArchiveFrom, InpLongCacheFrom, InpArchiveMax, g_lcArc, g_lcArcN, g_mArc, why))
      {
         LcSaveFile(true); changed = true;
         Print("[YDS] 長期ライン(過去分): ", TimeToString(g_mArc.firstT, TIME_DATE), "〜", TimeToString(g_mArc.lastT, TIME_DATE), " を一度だけスキャン(",
               g_mArc.bars, "本) → ", g_lcArcN, "本を保存。以後は読み取りません");
      }
      else { g_lcArcNextTry = nowT + 300; g_lcStatus = "過去分 " + why; Print("[YDS] 長期ライン(過去分): ", why); }
   }
   if(g_lcNextTry <= nowT)
   {
      bool due = g_lcForceRec || (g_mRec.scanT == 0) || (g_mRec.firstT == 0) || (nowT - g_mRec.scanT >= (datetime)((long)MathMax(1, InpLongCacheRefreshH) * 3600));
      if(due)
      {
         if(LcScanRange(InpLongCacheFrom, nowT, InpLongCacheMax, g_lcRec, g_lcRecN, g_mRec, why))
         {
            LcSaveFile(false); changed = true; g_lcStatus = ""; g_lcForceRec = false;
            Print("[YDS] 長期ライン(最近分): ", TimeToString(g_mRec.firstT, TIME_DATE), "〜 をスキャン(", g_mRec.bars, "本) → ", g_lcRecN, "本を保存");
         }
         else { g_lcNextTry = nowT + 120; g_lcStatus = why; Print("[YDS] 長期ライン(最近分): ", why, " / 2分後に再試行します"); }
      }
   }
   if(changed) LcMerge();
}

void ComputeImportantLines()
{
   g_impN = 0;
   int m = g_hM;
   if(m < 40 || ArraySize(g_hrr) < m) return;
   int R    = MathMax(1, InpHtfSwing);
   int last = m - 2;                         // 最後の確定した上位足
   // 上位足ATR(直近14本の真の値幅の平均)。ラインをまとめる幅・反発の判定の基準にする
   double sumTr = 0.0;
   int    cntTr = 0;
   for(int b = last; b > last - 14 && b >= 1; b--)
   {
      double tr = MathMax(g_hrr[b].high - g_hrr[b].low,
                  MathMax(MathAbs(g_hrr[b].high - g_hrr[b - 1].close), MathAbs(g_hrr[b].low - g_hrr[b - 1].close)));
      sumTr += tr;
      cntTr++;
   }
   if(cntTr == 0) return;
   double atrH = sumTr / cntTr;
   if(atrH <= 0.0) return;
   g_hAtrLast = atrH;
   double tolC = InpClusterAtr * atrH;
   double tolT = InpTouchAtr * atrH;
   int from = MathMax(R, last - MathMax(50, InpLineLookback));
   datetime fromTime = g_hrr[from].time;

   // (1) 候補: 複数の時間足から、確定したスイングの高値・安値を集める
   g_cn = 0;
   if(InpUseMtf)
   {
      for(int k = 0; k < 4; k++)
      {
         if(g_mN[k] < 40) continue;
         switch(k)
         {
            case 0: CollectFromArray(g_m0, g_mN[0], 1 << 0, g_mW[0], fromTime); break;
            case 1: CollectFromArray(g_m1, g_mN[1], 1 << 1, g_mW[1], fromTime); break;
            case 2: CollectFromArray(g_m2, g_mN[2], 1 << 2, g_mW[2], fromTime); break;
            case 3: CollectFromArray(g_m3, g_mN[3], 1 << 3, g_mW[3], fromTime); break;
         }
      }
   }
   if(g_cn == 0) CollectFromArray(g_hrr, m, 16, 1.0, fromTime);   // MTFを使わない/読めない時は上位足だけ(v4と同じ)
   if(g_cn == 0) return;

   // (2) 価格の低い順に並べる
   int ord[];
   ArrayResize(ord, g_cn);
   for(int s1 = 0; s1 < g_cn; s1++) ord[s1] = s1;
   for(int s2 = 1; s2 < g_cn; s2++)
   {
      int key = ord[s2];
      int w = s2 - 1;
      while(w >= 0 && g_cP[ord[w]] > g_cP[key]) { ord[w + 1] = ord[w]; w--; }
      ord[w + 1] = key;
   }

   // 前日・前週の高値安値
   double dl[4];
   int dn = 0;
   if(InpUseDailyLevels)
   {
      MqlRates d1[]; ArraySetAsSeries(d1, false);
      if(CopyRates(_Symbol, PERIOD_D1, 0, 3, d1) == 3) { dl[dn] = d1[1].high; dn++; dl[dn] = d1[1].low; dn++; }
      MqlRates w1[]; ArraySetAsSeries(w1, false);
      if(CopyRates(_Symbol, PERIOD_W1, 0, 3, w1) == 3) { dl[dn] = w1[1].high; dn++; dl[dn] = w1[1].low; dn++; }
   }

   // (3) 近い価格をまとめて1本にし、点数をつける
   int cq = 0;
   while(cq < g_cn)
   {
      double start = g_cP[ord[cq]];
      double sumP = 0.0;
      double gmax[5] = {0, 0, 0, 0, 0};
      int    gcnt[5] = {0, 0, 0, 0, 0};
      int np = 0, nw = 0, mask = 0;
      datetime firstT = g_cT[ord[cq]];
      int e = cq;
      while(e < g_cn && g_cP[ord[e]] - start <= tolC)
      {
         sumP += g_cP[ord[e]];
         np++;
         nw += g_cW[ord[e]];
         int sl = SlotOfBit(g_cB[ord[e]]);
         gcnt[sl]++;
         if(g_cG[ord[e]] > gmax[sl]) gmax[sl] = g_cG[ord[e]];
         mask |= g_cB[ord[e]];
         if(g_cT[ord[e]] < firstT) firstT = g_cT[ord[e]];
         e++;
      }
      cq = e;
      double lvl = sumP / np;
      // 時間足ごとに「最強のピボット + 繰り返しの小さな加点(上限あり)」を、その時間足の重みで合計する。
      // ピボットの数をそのまま足すと、低い時間足のピボットが多い混雑した価格帯が高得点になってしまうため。
      double sumG = 0.0;
      int confMask = 0;
      for(int sk = 0; sk < 5; sk++)
      {
         if(gcnt[sk] == 0) continue;
         double wk = (sk < 4) ? g_mW[sk] : 1.0;
         sumG += wk * (gmax[sk] + 0.5 * (double)MathMin(gcnt[sk] - 1, 6));
         if(gmax[sk] >= (double)InpConfMinG && sk < 4) confMask |= (1 << sk);
      }
      int nTf = PopCount(confMask);
      if(mask >= 16) { nTf = 1; confMask = 16; }

      // 反発の回数: ヒゲがラインの帯に入り、終値は帯の外(ヒゲと逆側)に戻った上位足。連続した足は1回
      int  episodes = 0;
      bool prevT = false;
      int  lastTouch = -1;
      for(int b = from; b <= last; b++)
      {
         bool rejUp = (g_hrr[b].high >= lvl - tolT && g_hrr[b].high <= lvl + tolT && g_hrr[b].close < lvl - tolT);
         bool rejDn = (g_hrr[b].low  <= lvl + tolT && g_hrr[b].low  >= lvl - tolT && g_hrr[b].close > lvl + tolT);
         bool touch = (rejUp || rejDn);
         if(touch && !prevT) episodes++;
         if(touch) lastTouch = b;
         prevT = touch;
      }
      int    age = (lastTouch >= 0) ? (last - lastTouch) : (last - from);
      double rec = 0.5 + 0.5 * MathExp(-(double)age / (double)MathMax(1, InpRecencyBars));
      bool isRound = false;
      if(InpRoundStep > 0.0)
      {
         double rn = MathRound(lvl / InpRoundStep) * InpRoundStep;
         if(MathAbs(lvl - rn) <= tolC) isRound = true;
      }
      bool isDaily = false;
      for(int z = 0; z < dn; z++) if(MathAbs(lvl - dl[z]) <= tolC) isDaily = true;

      double conf  = InpConfBonus * (double)MathMax(0, nTf - 1);
      double score = (sumG + conf + 0.3 * (double)MathMin(episodes, 10) + (double)MathMin(nw, 4) + (isRound ? 2.0 : 0.0) + (isDaily ? 2.0 : 0.0)) * rec;
      if(score < InpMinScore) continue;

      ArrayResize(g_imp, g_impN + 1);
      g_imp[g_impN].price     = lvl;
      g_imp[g_impN].score     = score;
      g_imp[g_impN].pivots    = np;
      g_imp[g_impN].episodes  = episodes;
      g_imp[g_impN].wicks     = nw;
      g_imp[g_impN].age       = age;
      g_imp[g_impN].isRound   = isRound;
      g_imp[g_impN].isDaily   = isDaily;
      g_imp[g_impN].firstTime = firstT;
      g_imp[g_impN].tfMask    = confMask;
      g_imp[g_impN].nTf       = nTf;
      g_imp[g_impN].forced    = false;
      g_imp[g_impN].fromCache = false;
      g_impN++;
   }
   if(g_impN == 0) return;

   // (4) 点数の高い順に並べ、近すぎるラインは点数の高い方だけを残して、上位を選ぶ
   for(int a = 1; a < g_impN; a++)
   {
      YLine kk = g_imp[a];
      int w = a - 1;
      while(w >= 0 && g_imp[w].score < kk.score) { g_imp[w + 1] = g_imp[w]; w--; }
      g_imp[w + 1] = kk;
   }
   double sepTol = InpMinSepAtr * atrH;
   int n0 = g_impN;
   YLine pool[]; ArrayResize(pool, n0);
   for(int a = 0; a < n0; a++) pool[a] = g_imp[a];            // 点数順の候補(コピー)
   bool used[]; ArrayResize(used, n0); ArrayInitialize(used, false);
   int kept = 0;
   for(int a = 0; a < n0 && kept < MathMax(1, InpImpLineMax); a++)
   {
      bool tooClose = false;
      for(int b2 = 0; b2 < kept; b2++) if(MathAbs(g_imp[b2].price - pool[a].price) < sepTol) { tooClose = true; break; }
      if(tooClose) continue;
      g_imp[kept] = pool[a]; used[a] = true;
      kept++;
   }
   // ★2026-11-20追加: 現在値の上側・下側のそれぞれに、最低InpImpMinPerSide本を残す(急な上げ下げで、片側にラインが無くなりRR候補がゼロになるのを防ぐ)
   if(InpImpMinPerSide > 0 && m >= 1)
   {
      double curP = g_hrr[m - 1].close;
      for(int sd = 0; sd < 2; sd++)
      {
         bool above = (sd == 0);
         int c = 0;
         for(int q = 0; q < kept; q++) if(above ? (g_imp[q].price > curP) : (g_imp[q].price < curP)) c++;
         for(int a = 0; a < n0 && c < InpImpMinPerSide; a++)
         {
            if(used[a]) continue;
            if(above ? !(pool[a].price > curP) : !(pool[a].price < curP)) continue;
            bool tooClose2 = false;
            for(int b3 = 0; b3 < kept; b3++) if(MathAbs(g_imp[b3].price - pool[a].price) < sepTol) { tooClose2 = true; break; }
            if(tooClose2) continue;
            g_imp[kept] = pool[a]; g_imp[kept].forced = true; used[a] = true;
            kept++; c++;
         }
      }
   }
   // ★2026-11-21追加: それでも足りない側は、長期ライン(保存ファイル)から、現在値に近い順に追加
   if(InpUseLongCache && g_lcN > 0 && InpImpMinPerSide > 0 && m >= 1)
   {
      double curP2 = g_hrr[m - 1].close;
      for(int sd = 0; sd < 2; sd++)
      {
         bool above = (sd == 0);
         int c = 0;
         for(int q = 0; q < kept; q++) if(above ? (g_imp[q].price > curP2) : (g_imp[q].price < curP2)) c++;
         while(c < InpImpMinPerSide)
         {
            int best = -1; double bd = 1e18;
            for(int a = 0; a < g_lcN; a++)
            {
               if(above ? !(g_lc[a].price > curP2) : !(g_lc[a].price < curP2)) continue;
               bool tooClose3 = false;
               for(int b4 = 0; b4 < kept; b4++) if(MathAbs(g_imp[b4].price - g_lc[a].price) < sepTol) { tooClose3 = true; break; }
               if(tooClose3) continue;
               double dd = MathAbs(g_lc[a].price - curP2);
               if(dd < bd) { bd = dd; best = a; }
            }
            if(best < 0) break;
            if(ArraySize(g_imp) <= kept) ArrayResize(g_imp, kept + 1);
            g_imp[kept].price     = g_lc[best].price;
            g_imp[kept].score     = g_imp[0].score * 0.3;        // ★2相当
            g_imp[kept].pivots    = g_lc[best].pivots;
            g_imp[kept].episodes  = g_lc[best].pivots;
            g_imp[kept].wicks     = 0;
            g_imp[kept].age       = 0;
            g_imp[kept].isRound   = false;
            g_imp[kept].isDaily   = false;
            g_imp[kept].firstTime = (g_lc[best].firstT > 0) ? g_lc[best].firstT : fromTime;
            g_imp[kept].tfMask    = 16;
            g_imp[kept].nTf       = 1;
            g_imp[kept].forced    = true;
            g_imp[kept].fromCache = true;
            kept++; c++;
         }
      }
   }
   g_impN = kept;
   g_impMax = g_imp[0].score;       // 点数順の先頭が最高点
   // 価格の低い順に並べ直す(隣のラインを使ったRR計算・一覧表示のため)
   for(int a = 1; a < g_impN; a++)
   {
      YLine kk = g_imp[a];
      int w = a - 1;
      while(w >= 0 && g_imp[w].price > kk.price) { g_imp[w + 1] = g_imp[w]; w--; }
      g_imp[w + 1] = kk;
   }
}

// そのラインで逆張りした場合のRR: 買い=SLをライン-幅、TPを1つ上のラインの手前 / 売り=その逆
string RrFromLine(const int n, const bool buy)
{
   double slDist = InpLineSlAtr * g_hAtrLast;
   double tpBuf  = InpLineTpBufAtr * g_hAtrLast;
   if(slDist <= 0.0) return "-";
   double p = g_imp[n].price;
   if(buy)
   {
      if(n + 1 >= g_impN) return "-";
      double tp = g_imp[n + 1].price - tpBuf;
      if(tp <= p) return "-";
      return DoubleToString((tp - p) / slDist, 1);
   }
   if(n <= 0) return "-";
   double tp = g_imp[n - 1].price + tpBuf;
   if(tp >= p) return "-";
   return DoubleToString((p - tp) / slDist, 1);
}

string ImpLineText(const int n, const double cur)
{
   double p = g_imp[n].price;
   bool above = (p > cur);
   string stars = StringSubstr("★★★★★", 0, StarsOf(g_imp[n].score));
   string tag = "";
   if(g_imp[n].isRound) tag += " キリ番";
   if(g_imp[n].isDaily) tag += " 前日/前週";
   if(g_imp[n].fromCache) tag += " (長期・保存)";
   string ov = "";
   if(g_imp[n].nTf >= 2) ov = "  重なり" + IntegerToString(g_imp[n].nTf) + "(" + TfListText(g_imp[n].tfMask) + ")";
   return stars + " " + (above ? "抵抗 " : "支持 ") + DoubleToString(p, _Digits) + ov +
          " (" + (above ? "+" : "-") + DoubleToString(MathAbs(p - cur), 1) + ")  反発" + IntegerToString(g_imp[n].episodes) +
          "回  買RR " + RrFromLine(n, true) + " / 売RR " + RrFromLine(n, false) + tag;
}

//+------------------------------------------------------------------+
//| MTF_SR方式のライン: 時間足ごとの「直近のフラクタル」を階段状に表示      |
//| (MTF_SR_Eli_MT5 の中身をこのインジに内蔵したもの)                    |
//+------------------------------------------------------------------+
bool     g_msrShow[4];
color    g_msrHi[4];
color    g_msrLo[4];

void InitMsr()
{
   g_msrShow[0] = InpMsrShow1; g_msrShow[1] = InpMsrShow2;
   g_msrHi[0] = InpMsrHi1; g_msrLo[0] = InpMsrLo1;
   g_msrHi[1] = InpMsrHi2; g_msrLo[1] = InpMsrLo2;
   // 時間足3(M15)・4(M5)は表示しない(色を持たない)
   g_msrShow[2] = false; g_msrShow[3] = false;
   g_msrHi[2] = clrNONE; g_msrLo[2] = clrNONE;
   g_msrHi[3] = clrNONE; g_msrLo[3] = clrNONE;
}

void MsrPutBuf(const int idx, const double &src[], const int count)
{
   switch(idx)
   {
      case 0: ArrayCopy(MB0, src, 0, 0, count); break;
      case 1: ArrayCopy(MB1, src, 0, 0, count); break;
      case 2: ArrayCopy(MB2, src, 0, 0, count); break;
      case 3: ArrayCopy(MB3, src, 0, 0, count); break;
      case 4: ArrayCopy(MB4, src, 0, 0, count); break;
      case 5: ArrayCopy(MB5, src, 0, 0, count); break;
      case 6: ArrayCopy(MB6, src, 0, 0, count); break;
      case 7: ArrayCopy(MB7, src, 0, 0, count); break;
   }
}

// 1つの時間足: フラクタルを探し、チャートの足ごとに「直近の高値/安値」を決める
bool MsrCalcTf(const int k, const int rates_total, const datetime &time[], const int first,
               double &outH[], double &outL[], double &lastH, double &lastL)
{
   ENUM_TIMEFRAMES tf = g_mTf[k];
   int tfSec    = PeriodSeconds(tf);
   int chartSec = PeriodSeconds(_Period);
   if(tfSec <= 0 || chartSec <= 0) return false;
   int side = MathMax(1, InpMsrFractal);

   double spanSec = (double)(time[rates_total - 1] - time[first]) + chartSec;
   int want = (int)(spanSec / tfSec) + 2 * side + 40;
   want = MathMin(want, MathMax(100, InpMsrMaxTfBars));
   int avail = Bars(_Symbol, tf);
   if(avail < 2 * side + 10) return false;
   if(want > avail) want = avail;

   MqlRates rr[];
   ArraySetAsSeries(rr, false);
   int got = CopyRates(_Symbol, tf, 0, want, rr);
   if(got < 2 * side + 10) return false;

   datetime evHT[]; double evHP[]; int nh = 0;
   datetime evLT[]; double evLP[]; int nl = 0;
   for(int j = side; j <= got - 2 - side; j++)
   {
      bool isH = true, isL = true;
      for(int t = 1; t <= side; t++)
      {
         if(!(rr[j].high > rr[j - t].high && rr[j].high > rr[j + t].high)) isH = false;
         if(!(rr[j].low  < rr[j - t].low  && rr[j].low  < rr[j + t].low))  isL = false;
      }
      if(!isH && !isL) continue;
      datetime act = InpMsrNoLookAhead ? (rr[j + side].time + (datetime)tfSec) : rr[j].time;
      if(isH) { ArrayResize(evHT, nh + 1); ArrayResize(evHP, nh + 1); evHT[nh] = act; evHP[nh] = rr[j].high; nh++; }
      if(isL) { ArrayResize(evLT, nl + 1); ArrayResize(evLP, nl + 1); evLT[nl] = act; evLP[nl] = rr[j].low;  nl++; }
   }

   int ph = 0, pl = 0;
   double curH = EMPTY_VALUE, curL = EMPTY_VALUE;
   for(int i = 0; i < first; i++) { outH[i] = EMPTY_VALUE; outL[i] = EMPTY_VALUE; }
   for(int i = first; i < rates_total; i++)
   {
      datetime closeT = time[i] + (datetime)chartSec;
      while(ph < nh && evHT[ph] <= closeT) { curH = evHP[ph]; ph++; }
      while(pl < nl && evLT[pl] <= closeT) { curL = evLP[pl]; pl++; }
      outH[i] = curH;
      outL[i] = curL;
   }
   lastH = curH;
   lastL = curL;
   return true;
}

void ComputeMsrLayer(const int rates_total, const datetime &time[])
{
   double emptyArr[];
   ArrayResize(emptyArr, rates_total);
   ArrayInitialize(emptyArr, EMPTY_VALUE);
   for(int p = 0; p < 8; p++) MsrPutBuf(p, emptyArr, rates_total);
   ObjectsDeleteAll(0, YDS_PFX + "MSR_");
   if(!InpShowMsr) return;
   int first = MathMax(0, rates_total - MathMax(100, InpMsrMaxBars));
   double tmpH[], tmpL[];
   ArrayResize(tmpH, rates_total);
   ArrayResize(tmpL, rates_total);
   datetime tLabel = time[rates_total - 1] + (datetime)(2 * PeriodSeconds(_Period));
   for(int k = 0; k < 4; k++)
   {
      if(!g_msrShow[k]) continue;
      double lh = EMPTY_VALUE, ll = EMPTY_VALUE;
      if(!MsrCalcTf(k, rates_total, time, first, tmpH, tmpL, lh, ll)) continue;
      MsrPutBuf(2 * k,     tmpH, rates_total);
      MsrPutBuf(2 * k + 1, tmpL, rates_total);
      if(InpMsrLabels)
      {
         string tf = TfName(g_mTf[k]);
         if(lh != EMPTY_VALUE && g_msrHi[k] != clrNONE)
            PutText(YDS_PFX + "MSR_L" + IntegerToString(k) + "H", tLabel, lh, tf + " 抵抗 " + DoubleToString(lh, _Digits), g_msrHi[k], 8, ANCHOR_LEFT);
         if(ll != EMPTY_VALUE && g_msrLo[k] != clrNONE)
            PutText(YDS_PFX + "MSR_L" + IntegerToString(k) + "L", tLabel, ll, tf + " 支持 " + DoubleToString(ll, _Digits), g_msrLo[k], 8, ANCHOR_LEFT);
      }
   }
}

// 重要なラインの色: 含まれる最上位の時間足(時間足1が最上位)の色。色なし(clrNONE)や該当なしは既定の色
color ImpLineColor(const int n, const bool above)
{
   color col = above ? InpResColor : InpSupColor;
   if(!InpImpColorByTf) return col;
   int mask = g_imp[n].tfMask;
   for(int k = 0; k < 4; k++)
   {
      if((mask & (1 << k)) == 0) continue;
      color c2 = above ? g_msrHi[k] : g_msrLo[k];
      if(c2 != clrNONE) col = c2;
      break;
   }
   return col;
}

//+------------------------------------------------------------------+
//| RR候補: 現在値の上下にある ★InpRrMinStars 以上のラインから、勝ちの線と負けの線を組み合わせる |
//|  買い: 勝ち=上のライン(近い方から)/負け=下のライン  売り: 勝ち=下のライン/負け=上のライン    |
//|  TP=勝ちの線の手前(InpLineTpBufAtr) / SL=負けの線の外側(InpLineSlAtr)。RR=勝ち幅÷負け幅     |
//+------------------------------------------------------------------+
struct YRc
{
   double rr;
   int    dir;        // +1=買い(上昇) / -1=売り(下降)
   double winP;       // 勝ちの水平線の値
   double loseP;      // 負けの水平線の値
   int    winS;       // 勝ちの線の★
   int    loseS;      // 負けの線の★
   double winPips;    // 勝ちの期待値(現在値からTPまで。pips=価格差×10)
   double losePips;   // 負けの期待値(現在値からSLまで)
   double sl;         // 損切りの価格(負けの線の外側)
   double tp;         // 利確の価格(勝ちの線の手前)
   int    winIdx;     // g_imp の番号
   int    loseIdx;
};
YRc    g_rc[];
int    g_rcN = 0;       // 作れた候補の数(全て)
int    g_rcShow = 0;    // 表示する候補の数(RRの高い順に InpRrCandMax 件まで)
int    g_rcBestB = -1;  // 買いの最良の候補の番号(g_rc内)
int    g_rcBestS = -1;  // 売りの最良の候補の番号
double g_pipSize = 0.1;

bool g_rcCapped = false;  // ★2026-11-21(9回目): 勝ちのpips上限(InpRrMaxWinPips)で除いた候補があった
bool g_rcRelax = false;   // ★2026-11-21(8回目): true=「遠すぎる勝ちの線を除く」制限を外して候補を作る(通常の候補がゼロの時だけ)
void AddRc(const int dir, const int wi, const int li, const double cur)
{
   double buf = InpLineSlAtr * g_hAtrLast;
   double tpb = InpLineTpBufAtr * g_hAtrLast;
   double wp = g_imp[wi].price, lp = g_imp[li].price;
   if(!g_rcRelax && InpRrMaxWinAtr > 0.0 && MathAbs(wp - cur) > InpRrMaxWinAtr * g_hAtrLast) return;   // 遠すぎる目標は除く(候補がゼロの時だけ外す)
   double tp, sl, rr;
   if(dir == 1)
   {
      tp = wp - tpb;  sl = lp - buf;
      if(!(tp > cur && sl < cur)) return;
      rr = (tp - cur) / (cur - sl);
   }
   else
   {
      tp = wp + tpb;  sl = lp + buf;
      if(!(tp < cur && sl > cur)) return;
      rr = (cur - tp) / (sl - cur);
   }
   if(InpRrMaxWinPips > 0.0 && MathAbs(tp - cur) / g_pipSize > InpRrMaxWinPips) { g_rcCapped = true; return; }   // 取得できるpipsが多すぎる候補は現実的でない
   ArrayResize(g_rc, g_rcN + 1);
   g_rc[g_rcN].rr = rr;               g_rc[g_rcN].dir = dir;
   g_rc[g_rcN].winP = wp;             g_rc[g_rcN].loseP = lp;
   g_rc[g_rcN].winS = StarsOf(g_imp[wi].score);   g_rc[g_rcN].loseS = StarsOf(g_imp[li].score);
   g_rc[g_rcN].winPips = MathAbs(tp - cur) / g_pipSize;
   g_rc[g_rcN].losePips = MathAbs(cur - sl) / g_pipSize;
   g_rc[g_rcN].sl = sl;               g_rc[g_rcN].tp = tp;
   g_rc[g_rcN].winIdx = wi;           g_rc[g_rcN].loseIdx = li;
   g_rcN++;
}

void BuildRrCandidates(const double cur)
{
   g_rcN = 0; g_rcShow = 0; g_rcBestB = -1; g_rcBestS = -1; g_rcCapped = false;
   g_pipSize = _Point * 10.0;
   if(g_impN == 0 || g_hAtrLast <= 0.0 || g_pipSize <= 0.0) return;
   // ★条件を満たす線を、現在値に近い順に並べる(上=価格の小さい方から / 下=価格の大きい方から)
   int up[], dn[];
   ArrayResize(up, g_impN); ArrayResize(dn, g_impN);
   int nu = 0, nd = 0;
   for(int n = 0; n < g_impN; n++)
      if((g_imp[n].forced || StarsOf(g_imp[n].score) >= InpRrMinStars) && g_imp[n].price > cur) { up[nu] = n; nu++; }   // ★2026-11-20: forced(最低本数のために追加)も対象
   for(int n = g_impN - 1; n >= 0; n--)
      if((g_imp[n].forced || StarsOf(g_imp[n].score) >= InpRrMinStars) && g_imp[n].price < cur) { dn[nd] = n; nd++; }
   int wl = MathMax(1, InpRrWinLines), ll = MathMax(1, InpRrLossLines);
   for(int pass = 0; pass < 2 && g_rcN == 0; pass++)
   {
      g_rcRelax = (pass == 1);         // 1回目=従来どおり / 2回目=候補がゼロの時だけ、遠い線の制限を外す
      // 買い: 勝ち=上 / 負け=下
      for(int w = 0; w < MathMin(wl, nu); w++)
         for(int l = 0; l < MathMin(ll, nd); l++) AddRc(1, up[w], dn[l], cur);
      // 売り: 勝ち=下 / 負け=上
      for(int w = 0; w < MathMin(wl, nd); w++)
         for(int l = 0; l < MathMin(ll, nu); l++) AddRc(-1, dn[w], up[l], cur);
   }
   if(g_rcN == 0) return;
   // RRの高い順に並べる
   for(int a = 1; a < g_rcN; a++)
   {
      YRc kk = g_rc[a];
      int w2 = a - 1;
      while(w2 >= 0 && g_rc[w2].rr < kk.rr) { g_rc[w2 + 1] = g_rc[w2]; w2--; }
      g_rc[w2 + 1] = kk;
   }
   for(int a = 0; a < g_rcN; a++)
   {
      if(g_rc[a].dir == 1  && g_rcBestB < 0) g_rcBestB = a;
      if(g_rc[a].dir == -1 && g_rcBestS < 0) g_rcBestS = a;
   }
   g_rcShow = MathMin(g_rcN, MathMax(1, InpRrCandMax));
}

string RcDirTxt(const int k)   // ★2026-11-05: 向きの文字(色を変える部分)
{
   return (g_rc[k].dir == 1) ? "▲上昇(買い)" : "▼下降(売り)";
}

color RcDirColor(const int k)
{
   return (g_rc[k].dir == 1) ? InpDirBuyColor : InpDirSellColor;
}

string RcText(const int k)
{
   string dirTxt = RcDirTxt(k);
   return "RR" + IntegerToString(k + 1) + "  " + IntegerToString((int)MathRound(g_rc[k].rr * 100.0)) + "%  " + dirTxt +
          "   勝ち +" + DoubleToString(g_rc[k].winPips, 0) + "pips → " + DoubleToString(g_rc[k].winP, _Digits) + " ★" + IntegerToString(g_rc[k].winS) +
          "   負け -" + DoubleToString(g_rc[k].losePips, 0) + "pips → " + DoubleToString(g_rc[k].loseP, _Digits) + " ★" + IntegerToString(g_rc[k].loseS) +
          ((InpRrMaxWinAtr > 0.0 && g_rc[k].winPips * g_pipSize > InpRrMaxWinAtr * g_hAtrLast) ? "  ※遠い線" : "");
}

color RcColor(const int k)
{
   return (g_rc[k].rr >= 1.0) ? InpRrOkColor : InpRrLowColor;
}

// この水平線(g_impの番号)が、表示中のRR候補の勝ち・負けの線として使われているか、使われ方の文字を返す(使われていなければ"")
string RcUseTag(const int n)
{
   string r = "";
   for(int k = 0; k < g_rcShow; k++)
   {
      if(g_rc[k].winIdx == n)  r += (r == "" ? "" : "・") + "RR" + IntegerToString(k + 1) + "勝ち";
      if(g_rc[k].loseIdx == n) r += (r == "" ? "" : "・") + "RR" + IntegerToString(k + 1) + "負け";
   }
   return r;
}

void DrawImportantLines(const datetime lastTime, const double cur)
{
   ObjectsDeleteAll(0, YDS_PFX + "IL_");
   if(g_impN == 0) return;
   int chartSec = PeriodSeconds(_Period);
   for(int n = 0; n < g_impN; n++)
   {
      string tag = RcUseTag(n);                       // RR候補の勝ち・負けの線として使われているか
      bool used = (tag != "");
      if(!InpShowLines && !used) continue;            // 勝ち・負けの線は、線の表示がオフでも必ず引く
      double p = g_imp[n].price;
      bool above = (p > cur);
      int  st = StarsOf(g_imp[n].score);
      color col = ImpLineColor(n, above);
      int width = (st >= 4) ? 3 : ((st >= 3) ? 2 : 1);
      int style = InpImpDots ? STYLE_DOT : ((st >= 3) ? STYLE_SOLID : STYLE_DASH);
      if(used) { width = MathMax(width, 2); style = STYLE_SOLID; }
      string nm = YDS_PFX + "IL_L" + IntegerToString(n);
      PutTrend(nm, g_imp[n].firstTime, p, lastTime, p, col, style, width, true);
      string txt = StringSubstr("★★★★★", 0, st) + " " + DoubleToString(p, _Digits);
      if(g_imp[n].fromCache) txt += "(長期)";
      if(used) txt = "決済対象(" + tag + ") " + txt;
      PutText(nm + "_T", lastTime + (datetime)(2 * chartSec), p, txt, col, 8, ANCHOR_LEFT);
   }
}

//+------------------------------------------------------------------+
//| 直近シグナルの RR 文字・SL線・TP線                                |
//+------------------------------------------------------------------+
void DrawSignals(const datetime &time[], const int rates_total)
{
   ObjectsDeleteAll(0, YDS_PFX + "SG_");
   int execSec = PeriodSeconds(_Period);
   int from = MathMax(0, g_sigN - InpMaxLabels);
   for(int s = from; s < g_sigN; s++)
   {
      int i = g_sigI[s];
      datetime t0 = time[i];
      datetime t1 = t0 + (datetime)(24 * execSec);
      string key = IntegerToString((long)t0);
      color  cc  = (g_sigDir[s] > 0) ? InpBuyColor : InpSellColor;
      string dtx = (g_sigDir[s] > 0) ? "買" : "売";
      double ap  = g_sigArrow[s];
      double off = MathAbs(g_sigEntry[s] - g_sigSL[s]) * 0.15;
      double ty  = (g_sigDir[s] > 0) ? ap - off : ap + off;
      PutText(YDS_PFX + "SG_RR_" + key, t0, ty,
              dtx + " RR " + DoubleToString(g_sigRR[s], 1) + " " + TypeName(g_sigType[s]),
              cc, 8, (g_sigDir[s] > 0) ? ANCHOR_UPPER : ANCHOR_LOWER);
      PutTrend(YDS_PFX + "SG_SL_" + key, t0, g_sigSL[s], t1, g_sigSL[s], clrTomato, STYLE_DOT, 1, false);
      PutTrend(YDS_PFX + "SG_TP_" + key, t0, g_sigTP[s], t1, g_sigTP[s], clrSpringGreen, STYLE_DOT, 1, false);
   }
}

//+------------------------------------------------------------------+
//| 情報パネル: RR候補の一覧(RRの高い順)。背景つき(DokaKotsu_Dashboardと同じ形式)  |
//+------------------------------------------------------------------+
string g_pnT[];
color  g_pnC[];
int    g_pnS[];
int    g_pnY[];
int    g_pnX[];   // ★2026-11-05: 行の左端からの位置(ピクセル)。向きの文字だけ色を変えるため、1行を複数の文字に分けて並べる
int    g_pnN = 0;

void PnAdd(const string text, const color col, const int size, const int y, const int xoff = 0)
{
   ArrayResize(g_pnT, g_pnN + 1); ArrayResize(g_pnC, g_pnN + 1);
   ArrayResize(g_pnS, g_pnN + 1); ArrayResize(g_pnY, g_pnN + 1); ArrayResize(g_pnX, g_pnN + 1);
   g_pnT[g_pnN] = text; g_pnC[g_pnN] = col; g_pnS[g_pnN] = size; g_pnY[g_pnN] = y; g_pnX[g_pnN] = xoff;
   g_pnN++;
}

// 文字の幅(ピクセル)を測る。測れない時は文字数からの概算
int PnTextW(const string text, const int size)
{
   uint tw = 0, th = 0;
   TextSetFont("Meiryo", -size * 10, 0, 0);
   if(TextGetSize(text, tw, th)) return (int)tw;
   return (int)(StringLen(text) * size * 1.4);
}

// text を、幅 maxW(ピクセル)を超えないように行に分ける。maxW<=0 なら折り返さない。
// 切る位置は、空白・「/」・「)」・句読点の後ろを優先(直前12文字以内にあれば)
int PnWrap(const string text, const int size, const int maxW, string &lines[])
{
   ArrayResize(lines, 0);
   int n = StringLen(text);
   if(maxW <= 0 || n == 0 || PnTextW(text, size) <= maxW)
   {
      ArrayResize(lines, 1); lines[0] = text; return 1;
   }
   int start = 0;
   while(start < n)
   {
      int lo = start + 1, hi = n, best = start + 1;       // 幅に収まる最大の長さを二分探索
      while(lo <= hi)
      {
         int mid = (lo + hi) / 2;
         if(PnTextW(StringSubstr(text, start, mid - start), size) <= maxW) { best = mid; lo = mid + 1; }
         else hi = mid - 1;
      }
      int cut = best;
      if(best < n)                                         // 残りがあるなら、切りやすい位置まで戻す
      {
         for(int k = best; k > MathMax(start + 1, best - 12); k--)
         {
            ushort c = StringGetCharacter(text, k - 1);
            if(c == ' ' || c == 0x3000 || c == '/' || c == ')' || c == 0xFF09 || c == 0x3001 || c == 0x3002) { cut = k; break; }
         }
      }
      ArrayResize(lines, ArraySize(lines) + 1);
      lines[ArraySize(lines) - 1] = StringSubstr(text, start, cut - start);
      start = cut;
   }
   return ArraySize(lines);
}

// 1つの行(折り返しがあれば複数行)を追加し、次の行のy座標を返す
int PnRow(const string text, const color col, const int size, const int y, const int step)
{
   string ls[];
   int n = PnWrap(text, size, InpPanelMaxW, ls);
   int cy = y;
   for(int k = 0; k < n; k++)
   {
      PnAdd(ls[k], col, size, cy);
      cy += (k < n - 1) ? (int)MathRound(step * 0.85) : step;   // 折り返しの続きは少し詰める
   }
   return cy;
}

// ★2026-11-05追加: 空白1つの幅(ピクセル)。前後に"|"を付けて測る(末尾の空白が測定から落ちても、正しく測れる)
int PnSpaceW(const int size)
{
   int a = PnTextW("|  |", size), b = PnTextW("||", size);
   int w = (a - b) / 2;
   return (w > 0) ? w : (int)MathRound(size * 0.7);
}

// ★2026-11-05追加: 向きの文字(dirTxt)だけ色を変える行。行を「前・向き・後ろ」の3つの文字に分け、
//   前の文字の幅(と空白の幅)を測って、向き・後ろの位置を決める。折り返しは PnRow と同じ(折り返した行ごとに探す)。
int PnRowDir(const string text, const color col, const int size, const int y, const int step,
             const string dirTxt, const color dirCol)
{
   string ls[];
   int n = PnWrap(text, size, InpPanelMaxW, ls);
   int cy = y;
   for(int k = 0; k < n; k++)
   {
      int p = StringFind(ls[k], dirTxt);
      if(p < 0) PnAdd(ls[k], col, size, cy);
      else
      {
         string pre  = StringSubstr(ls[k], 0, p);
         string post = StringSubstr(ls[k], p + StringLen(dirTxt));
         int sp1 = 0, sp2 = 0;
         while(StringLen(pre) > 0 && StringGetCharacter(pre, StringLen(pre) - 1) == ' ') { pre = StringSubstr(pre, 0, StringLen(pre) - 1); sp1++; }
         while(StringLen(post) > 0 && StringGetCharacter(post, 0) == ' ') { post = StringSubstr(post, 1); sp2++; }
         int sw = PnSpaceW(size);
         if(pre != "") PnAdd(pre, col, size, cy);
         int xDir = ((pre != "") ? PnTextW(pre, size) : 0) + sp1 * sw;
         PnAdd(dirTxt, dirCol, size, cy, xDir);
         int xPost = xDir + PnTextW(dirTxt, size) + sp2 * sw;
         if(post != "") PnAdd(post, col, size, cy, xPost);
      }
      cy += (k < n - 1) ? (int)MathRound(step * 0.85) : step;   // 折り返しの続きは少し詰める
   }
   return cy;
}

void DrawPanel(const datetime &time[], const double cur)
{
   ObjectsDeleteAll(0, YDS_PFX + "PN_");
   if(!InpShowPanel) return;
   string tf = TfName(InpHigherTF);
   string tr = "判定なし";
   if(g_hM >= 3)
   {
      int t = g_hTrend[g_hM - 2];
      tr = (t == 1) ? "上昇" : ((t == -1) ? "下降" : "レンジ/判定なし");
   }
   int fs   = MathMax(6, InpPanelFontSize);        // 見出し・候補の文字の大きさ
   int x0   = 10;
   int y0   = MathMax(0, InpPanelY);               // 画面の上からの表示位置(設定)
   int rowH = MathMax(10, InpPanelRowH);           // 行の間隔(設定)
   int y    = y0;
   g_pnN = 0;

   // (1) 行の内容を集める(まだ描かない。背景を先に作るため、大きさを測る)
   y = PnRow("DK Risk-Reward Ratio   現在値 " + DoubleToString(cur, _Digits) +
             "   上位足 " + tf + " トレンド: " + tr, InpPanelColor, fs, y, rowH);
   if(g_rcShow == 0)
      y = PnRow(g_rcCapped ? "現実的な候補はありません(勝ちが" + DoubleToString(InpRrMaxWinPips, 0) + "pips以内の線がありません)" : "候補なし(現在値の上下に★" + IntegerToString(InpRrMinStars) + "以上の水平線が必要。)", InpPanelColor, fs, y, rowH);
   for(int k = 0; k < g_rcShow; k++)
      y = PnRowDir(RcText(k), RcColor(k), fs, y, rowH, RcDirTxt(k), RcDirColor(k));   // ★2026-11-05: 向きの文字だけアクア/マゼンタ
   if(InpUseLongCache)
   {
      string lcTxt = (g_lcN > 0 && g_lcFirstT > 0)
         ? "読取 " + StringSubstr(TimeToString(g_lcFirstT, TIME_DATE), 0, 7) + "〜" + TimeToString((g_lcLastT > 0 ? g_lcLastT : g_lcScanTime), TIME_DATE) +
           "  スキャン " + TimeToString(g_lcScanTime + (datetime)((long)(TimeGMT() - TimeTradeServer()) + (long)InpDispUtcOffsetH * 3600), TIME_DATE | TIME_MINUTES)
         : ((g_lcStatus != "") ? "長期ライン " + g_lcStatus : "長期ライン 未読込(スキャン待ち)");
      y = PnRow(lcTxt, InpPanelColor, fs, y, rowH);
   }
   if(InpShowArrows && g_sigN > 0)
   {
      y += (int)MathRound(rowH * 0.25);
      int s = g_sigN - 1;
      y = PnRow("最新シグナル: " + ((g_sigDir[s] > 0) ? "買い(緑)" : "売り(紫)") + " " +
                TimeToString(time[g_sigI[s]], TIME_DATE | TIME_MINUTES) + "  " + TypeName(g_sigType[s]) +
                "  RR " + DoubleToString(g_sigRR[s], 1) + "  SL " + DoubleToString(g_sigSL[s], _Digits) + "  TP " + DoubleToString(g_sigTP[s], _Digits),
                InpPanelColor, fs, y, rowH);
   }

   // (2) 文字の幅と高さを測る(背景の大きさを文字に合わせる)
   int maxW = 0, bottom = y0;
   for(int i = 0; i < g_pnN; i++)
   {
      int w = g_pnX[i] + PnTextW(g_pnT[i], g_pnS[i]);   // ★2026-11-05: 分けた文字は、左端からの位置も足して、行の幅にする
      int h = g_pnS[i] * 2;
      if(w > maxW) maxW = w;
      if(g_pnY[i] + h > bottom) bottom = g_pnY[i] + h;
   }

   // (3) 背景(DokaKotsu_Dashboardと同じ形式)を、文字より先に作る(先に作ったものが後ろになる)
   if(InpPanelBgShow && g_pnN > 0)
   {
      int pad = MathMax(0, InpPanelPad);
      int bgW = (int)MathRound(maxW * MathMax(0.3, InpPanelWidthScale)) + 2 * pad + 6;
      string bg = YDS_PFX + "PN_BG";
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, MathMax(0, x0 - pad));
      ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, MathMax(0, y0 - pad));
      ObjectSetInteger(0, bg, OBJPROP_XSIZE, bgW);
      ObjectSetInteger(0, bg, OBJPROP_YSIZE, (bottom - y0) + 2 * pad);
      ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, InpPanelBgColor);
      ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bg, OBJPROP_COLOR, InpPanelBorderColor);
      ObjectSetInteger(0, bg, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, bg, OBJPROP_BACK, false);
      ObjectSetInteger(0, bg, OBJPROP_FILL, true);
      ObjectSetInteger(0, bg, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, bg, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, bg, OBJPROP_ZORDER, 100000000);
   }

   // (4) 文字を描く
   for(int i = 0; i < g_pnN; i++)
      PutLabel(YDS_PFX + "PN_" + IntegerToString(i), x0 + g_pnX[i], g_pnY[i], g_pnT[i], g_pnC[i], g_pnS[i]);
}

//+------------------------------------------------------------------+
//| EAへの受け渡し(グローバル変数)。BARは最後に書く                     |
//+------------------------------------------------------------------+
void PublishGV(const datetime &time[])
{
   if(!InpPublishGV) return;
   long cid = ChartID();
   GlobalVariableSet(StringFormat("YDS_RISK_%I64d",     cid), InpRiskPercent);
   GlobalVariableSet(StringFormat("YDS_MINRR_%I64d",    cid), InpMinRR);
   GlobalVariableSet(StringFormat("YDS_BE_USE_%I64d",   cid), InpUseBreakEven ? 1.0 : 0.0);
   GlobalVariableSet(StringFormat("YDS_BE_RATIO_%I64d", cid), InpBETriggerRatio);
   GlobalVariableSet(StringFormat("YDS_BE_OFF_%I64d",   cid), InpBEOffsetPoints * _Point);
   double bar = 0.0;
   if(g_sigN > 0)
   {
      int s = g_sigN - 1;
      GlobalVariableSet(StringFormat("YDS_SL_%I64d",    cid), g_sigSL[s]);
      GlobalVariableSet(StringFormat("YDS_TP_%I64d",    cid), g_sigTP[s]);
      GlobalVariableSet(StringFormat("YDS_RR_%I64d",    cid), g_sigRR[s]);
      GlobalVariableSet(StringFormat("YDS_TYPE_%I64d",  cid), (double)g_sigType[s]);
      GlobalVariableSet(StringFormat("YDS_ENTRY_%I64d", cid), g_sigEntry[s]);
      bar = (g_sigDir[s] > 0 ? 1.0 : -1.0) * (double)time[g_sigI[s]];
   }
   // RR候補(エントリーリーズンの記録用。足が新しくなるたびに更新)。R1=全体の最良(RR1) / RB=買いの最良 / RS=売りの最良
   GlobalVariableSet(StringFormat("YDS_RN_%I64d",    cid), (double)g_rcShow);
   for(int pass = 0; pass < 3; pass++)
   {
      int k = (pass == 0) ? 0 : ((pass == 1) ? g_rcBestB : g_rcBestS);
      string pf = (pass == 0) ? "R1" : ((pass == 1) ? "RB" : "RS");
      bool ok = (g_rcN > 0 && k >= 0 && k < g_rcN);
      GlobalVariableSet("YDS_" + pf + StringFormat("_%I64d",   cid), ok ? g_rc[k].rr : -1.0);
      GlobalVariableSet("YDS_" + pf + StringFormat("D_%I64d",  cid), ok ? (double)g_rc[k].dir : 0.0);
      GlobalVariableSet("YDS_" + pf + StringFormat("WP_%I64d", cid), ok ? g_rc[k].winP : 0.0);
      GlobalVariableSet("YDS_" + pf + StringFormat("WS_%I64d", cid), ok ? (double)g_rc[k].winS : 0.0);
      GlobalVariableSet("YDS_" + pf + StringFormat("LP_%I64d", cid), ok ? g_rc[k].loseP : 0.0);
      GlobalVariableSet("YDS_" + pf + StringFormat("LS_%I64d", cid), ok ? (double)g_rc[k].loseS : 0.0);
      GlobalVariableSet("YDS_" + pf + StringFormat("SL_%I64d", cid), ok ? g_rc[k].sl : 0.0);
      GlobalVariableSet("YDS_" + pf + StringFormat("TP_%I64d", cid), ok ? g_rc[k].tp : 0.0);
   }
   // 表示中のRR候補ごとの向き・SL・TP(最大6件)。EAがエントリー価格でRRを計算し直して記録する
   for(int ck = 0; ck < 6; ck++)
   {
      bool okc = (ck < g_rcShow);
      string ks = IntegerToString(ck + 1);
      GlobalVariableSet("YDS_C" + ks + StringFormat("D_%I64d",  cid), okc ? (double)g_rc[ck].dir : 0.0);
      GlobalVariableSet("YDS_C" + ks + StringFormat("SL_%I64d", cid), okc ? g_rc[ck].sl : 0.0);
      GlobalVariableSet("YDS_C" + ks + StringFormat("TP_%I64d", cid), okc ? g_rc[ck].tp : 0.0);
   }
   GlobalVariableSet(StringFormat("YDS_RRMIN_%I64d", cid), InpEntryMinRR);
   GlobalVariableSet(StringFormat("YDS_TREND_%I64d", cid), (g_hM >= 3) ? (double)g_hTrend[g_hM - 2] : 0.0);
   GlobalVariableSet(StringFormat("YDS_TS_%I64d",  cid), (double)TimeCurrent());
   GlobalVariableSet(StringFormat("YDS_BAR_%I64d", cid), bar);   // コミット(最後に書く)
}

//+------------------------------------------------------------------+
int OnInit()
{
   g_lm = MathMax(1, InpSigLineMax);
   g_lcLoaded = false; g_lcForceRec = true; g_lcN = 0; g_lcRecN = 0; g_lcArcN = 0; g_lcScanTime = 0; g_lcNextTry = 0; g_lcArcNextTry = 0;
   g_lcFirstT = 0; g_lcBars = 0; g_lcLastT = 0; g_lcStatus = ""; ZeroMemory(g_mRec); ZeroMemory(g_mArc);
   InitMtfSlots();
   // バッファの並び: 描画するもの(矢印2+MTFの線8)が先、計算用(6)があと
   SetIndexBuffer(0,  BufBuy,   INDICATOR_DATA);
   SetIndexBuffer(1,  BufSell,  INDICATOR_DATA);
   SetIndexBuffer(2,  MB0, INDICATOR_DATA);  SetIndexBuffer(3,  MB1, INDICATOR_DATA);
   SetIndexBuffer(4,  MB2, INDICATOR_DATA);  SetIndexBuffer(5,  MB3, INDICATOR_DATA);
   SetIndexBuffer(6,  MB4, INDICATOR_DATA);  SetIndexBuffer(7,  MB5, INDICATOR_DATA);
   SetIndexBuffer(8,  MB6, INDICATOR_DATA);  SetIndexBuffer(9,  MB7, INDICATOR_DATA);
   SetIndexBuffer(10, BufSL,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(11, BufTP,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(12, BufRR,    INDICATOR_CALCULATIONS);
   SetIndexBuffer(13, BufType,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(14, BufTrend, INDICATOR_CALCULATIONS);
   SetIndexBuffer(15, BufEntry, INDICATOR_CALCULATIONS);
   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpBuyColor);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpSellColor);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpArrowWidth);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpArrowWidth);
   if(!InpShowArrows) { PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE); PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE); }
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   // MTF_SR方式のライン(プロット2〜9): 色なし(clrNONE)・非表示の線は描画しない
   InitMsr();
   for(int mk = 0; mk < 4; mk++)
   {
      for(int ms = 0; ms < 2; ms++)
      {
         int pp = 2 + 2 * mk + ms;
         color lc = (ms == 0) ? g_msrHi[mk] : g_msrLo[mk];
         PlotIndexSetString(pp, PLOT_LABEL, TfName(g_mTf[mk]) + (ms == 0 ? " 抵抗(高値)" : " 支持(安値)"));
         PlotIndexSetDouble(pp, PLOT_EMPTY_VALUE, EMPTY_VALUE);
         PlotIndexSetInteger(pp, PLOT_LINE_COLOR, lc);
         PlotIndexSetInteger(pp, PLOT_LINE_WIDTH, MathMax(1, InpMsrWidth));
         if(!InpShowMsr || !g_msrShow[mk] || lc == clrNONE)
            PlotIndexSetInteger(pp, PLOT_DRAW_TYPE, DRAW_NONE);
         else if(InpMsrStyle == MSR_DOTS)
         {
            PlotIndexSetInteger(pp, PLOT_DRAW_TYPE, DRAW_ARROW);
            PlotIndexSetInteger(pp, PLOT_ARROW, 172 - mk);     // 元のMT4版: 時間足ごとに記号172〜169
         }
         else
            PlotIndexSetInteger(pp, PLOT_DRAW_TYPE, DRAW_LINE);
      }
   }
   IndicatorSetString(INDICATOR_SHORTNAME, "Dokakotsu_Risk-Reward Ratio 18");   // ★2026-11-21(4回目): 一覧の表示名(ファイル名と同じ・後ろの(  )なし)

   g_hAtr = iATR(_Symbol, _Period, MathMax(2, InpAtrPeriod));
   if(g_hAtr == INVALID_HANDLE)
   {
      Print("[YDS] ATRハンドルの作成に失敗しました err=", GetLastError());
      return(INIT_FAILED);
   }
   if(PeriodSeconds(InpHigherTF) <= PeriodSeconds(_Period))
      Print("[YDS] 警告: 上位足(", TfName(InpHigherTF), ")が執行足(", TfName((ENUM_TIMEFRAMES)_Period), ")以下です。執行足より長い時間足を指定してください。");
   Print("[YDS] 起動 Dokakotsu_Risk-Reward Ratio 執行足=", TfName((ENUM_TIMEFRAMES)_Period), " 上位足=", TfName(InpHigherTF));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, YDS_PFX);
   if(g_hAtr != INVALID_HANDLE) IndicatorRelease(g_hAtr);
   ChartRedraw(0);
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
   int ER = MathMax(1, InpExecSwing);
   if(rates_total < 60 + 2 * ER) return(0);

   // 同じ足の中のティックでは、確定した足の判定は変わらないので再計算しない
   datetime lastBar = time[rates_total - 1];
   if(prev_calculated > 0 && lastBar == g_lastBar)
   {
      if(InpPublishGV) GlobalVariableSet(StringFormat("YDS_TS_%I64d", ChartID()), (double)TimeCurrent());
      return(rates_total);
   }

   if(CopyBuffer(g_hAtr, 0, 0, rates_total, g_atr) <= 0) return(prev_calculated);
   if(ArraySize(g_atr) < rates_total) return(prev_calculated);
   if(!BuildHtf()) return(prev_calculated);
   g_lastBar = lastBar;

   int execSec = PeriodSeconds(_Period);
   int htfSec  = PeriodSeconds(InpHigherTF);
   int first   = MathMax(2 * ER + 2, rates_total - MathMax(200, InpCalcBars));

   // バッファ初期化
   for(int i = 0; i < rates_total; i++)
   {
      BufBuy[i] = EMPTY_VALUE;  BufSell[i] = EMPTY_VALUE;
      BufSL[i] = EMPTY_VALUE;   BufTP[i] = EMPTY_VALUE;  BufRR[i] = EMPTY_VALUE;
      BufType[i] = 0.0;         BufTrend[i] = 0.0;       BufEntry[i] = EMPTY_VALUE;
   }

   // シグナル記録の初期化
   g_sigN = 0;
   ArrayResize(g_sigI, 0); ArrayResize(g_sigDir, 0); ArrayResize(g_sigType, 0);
   ArrayResize(g_sigEntry, 0); ArrayResize(g_sigSL, 0); ArrayResize(g_sigTP, 0);
   ArrayResize(g_sigRR, 0); ArrayResize(g_sigArrow, 0);

   double eP[E_CAP]; int eT[E_CAP]; int eI[E_CAP]; int eN = 0;
   int kPtr = -1;
   int lastSigI = -100000;
   int lastSigDir = 0;
   double spr = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;

   for(int i = first; i <= rates_total - 2; i++)
   {
      // (1) 執行足のピボット確定: 右にER本そろった足 j
      int j = i - ER;
      if(j - ER >= 0)
      {
         bool isH = true, isL = true;
         for(int t = j - ER; t <= j + ER; t++)
         {
            if(t == j) continue;
            if(high[t] > high[j]) isH = false;
            if(low[t]  < low[j])  isL = false;
         }
         if(isH && isL)
         {
            if(eN > 0 && eT[eN - 1] == 1) isH = false; else isL = false;
         }
         if(isH)      EAdd(eP, eT, eI, eN, 1,  high[j], j);
         else if(isL) EAdd(eP, eT, eI, eN, -1, low[j],  j);
      }

      // (2) この足が閉じた時点で確定している上位足
      while(kPtr + 1 <= g_hM - 2 && g_hTime[kPtr + 1] + htfSec <= time[i] + execSec) kPtr++;
      if(kPtr < 0) continue;
      int trend = g_hTrend[kPtr];
      BufTrend[i] = (double)trend;
      if(trend == 0 || eN < 3) continue;
      if(i - lastSigI < InpCooldownBars && lastSigDir == trend) continue;
      double atr = g_atr[i];
      if(atr <= 0.0) continue;

      int d = trend;
      int sigType = 0;
      double slBase = 0.0;
      double nearDist = InpNearAtr * atr;
      int last = eN - 1;

      // (3) トレンド方向の直前スイング(買い目線=高値/売り目線=安値)=抜けるべき水準を探す
      int hiIdx = -1;
      for(int t = eN - 1; t >= 0; t--) { if(eT[t] == d) { hiIdx = t; break; } }
      if(hiIdx >= 0 && i - eI[hiIdx] <= InpMaxPullbackBars)
      {
         double brk    = eP[hiIdx];
         int    brkBar = eI[hiIdx];
         // 押し(戻し)の極値: 直前スイングの後〜この足までの最安値(最高値)。ピボット確定(右にER本)を待たずに
         // 使えるので、素早い反転(V字)でもシグナルを取りこぼさない。
         double extreme = (d == 1) ? low[brkBar + 1] : high[brkBar + 1];
         for(int t = brkBar + 1; t <= i; t++)
         {
            if(d == 1) { if(low[t] < extreme)  extreme = low[t]; }
            else       { if(high[t] > extreme) extreme = high[t]; }
         }
         bool nearOk = NearLine(kPtr, extreme, nearDist);

         // 三尊(売り)/逆三尊(買い): 確定ピボット5つ + 首のラインのブレイク
         if(InpUseHS && nearOk && eN >= 5 && eT[last] == -d)
         {
            double shL = eP[last - 4], head = eP[last - 2], shR = eP[last];
            bool shape = false;
            if(d == 1)  shape = (head < shL && head < shR);
            else        shape = (head > shL && head > shR);
            if(shape && MathAbs(shL - shR) <= InpHsTolAtr * atr && eI[last - 1] != eI[last - 3])
            {
               double nkA = eP[last - 3], nkB = eP[last - 1];
               double span = (double)(eI[last - 1] - eI[last - 3]);
               double neckI  = nkA + (nkB - nkA) * (double)(i     - eI[last - 3]) / span;
               double neckI1 = nkA + (nkB - nkA) * (double)(i - 1 - eI[last - 3]) / span;
               bool broke = (d == 1) ? (close[i] > neckI && close[i - 1] <= neckI1)
                                     : (close[i] < neckI && close[i - 1] >= neckI1);
               if(broke) { sigType = 4; slBase = head; }
            }
         }
         // ダウ転換 / ダブルトップ・ボトム(直前スイングを終値で初めてブレイク)
         if(sigType == 0 && nearOk && MathAbs(brk - extreme) >= InpPullbackAtr * atr)
         {
            bool broke = (d == 1) ? (close[i] > brk && close[i - 1] <= brk)
                                  : (close[i] < brk && close[i - 1] >= brk);
            if(broke)
            {
               double prevExt = 0.0;
               bool   havePrev = false;
               for(int t = hiIdx - 1; t >= 0; t--) { if(eT[t] == -d) { prevExt = eP[t]; havePrev = true; break; } }
               bool dbl = (InpUseDouble && havePrev && MathAbs(prevExt - extreme) <= InpDoubleTolAtr * atr);
               if(dbl)             { sigType = 2; slBase = extreme; }
               else if(InpUseDow)  { sigType = 1; slBase = extreme; }
            }
         }
      }

      // ピンバー(水平線に触れた長いヒゲ)
      if(sigType == 0 && InpUsePin)
      {
         double range = high[i] - low[i];
         if(range >= 0.5 * atr)
         {
            double body = MathAbs(close[i] - open[i]);
            if(d == 1)
            {
               double wick = MathMin(open[i], close[i]) - low[i];
               if(wick >= InpPinWick * range && body <= InpPinBody * range &&
                  close[i] >= low[i] + 0.5 * range && NearLine(kPtr, low[i], nearDist))
               { sigType = 3; slBase = low[i]; }
            }
            else
            {
               double wick = high[i] - MathMax(open[i], close[i]);
               if(wick >= InpPinWick * range && body <= InpPinBody * range &&
                  close[i] <= low[i] + 0.5 * range && NearLine(kPtr, high[i], nearDist))
               { sigType = 3; slBase = high[i]; }
            }
         }
      }
      if(sigType == 0) continue;

      // (4) SL・TP・RR
      double entry = close[i];
      double sl = (d == 1) ? slBase - InpSlBufferAtr * atr - spr : slBase + InpSlBufferAtr * atr + spr;
      if((d == 1 && sl >= entry) || (d == -1 && sl <= entry)) continue;
      double sld = MathAbs(entry - sl);
      if(sld < 0.3 * atr || sld > InpMaxSlAtr * atr) continue;

      double nl     = NextLine(kPtr, entry, d, 0.3 * atr);
      double tpLine = 0.0;
      if(nl > 0.0) tpLine = (d == 1) ? nl - InpTpLineBufAtr * atr : nl + InpTpLineBufAtr * atr;
      bool lineOk = (tpLine > 0.0 && ((d == 1 && tpLine > entry) || (d == -1 && tpLine < entry)) &&
                     MathAbs(tpLine - entry) / sld >= InpMinRR);
      double tp = 0.0;
      if(InpTpMode == YDS_TP_RR_FIXED)          tp = entry + d * sld * InpMinRR;
      else if(InpTpMode == YDS_TP_NEXTLINE_STR) { if(!lineOk) continue; tp = tpLine; }
      else                                      tp = lineOk ? tpLine : entry + d * sld * InpMinRR;
      double rr = MathAbs(tp - entry) / sld;

      // (5) 矢印とデータ
      double ap = (d == 1) ? low[i] - 0.4 * atr : high[i] + 0.4 * atr;
      if(d == 1) BufBuy[i] = ap; else BufSell[i] = ap;
      BufSL[i] = sl; BufTP[i] = tp; BufRR[i] = rr; BufType[i] = (double)sigType; BufEntry[i] = entry;

      int n = g_sigN + 1;
      ArrayResize(g_sigI, n);     ArrayResize(g_sigDir, n);   ArrayResize(g_sigType, n);
      ArrayResize(g_sigEntry, n); ArrayResize(g_sigSL, n);    ArrayResize(g_sigTP, n);
      ArrayResize(g_sigRR, n);    ArrayResize(g_sigArrow, n);
      g_sigI[g_sigN] = i;         g_sigDir[g_sigN] = d;       g_sigType[g_sigN] = sigType;
      g_sigEntry[g_sigN] = entry; g_sigSL[g_sigN] = sl;       g_sigTP[g_sigN] = tp;
      g_sigRR[g_sigN] = rr;       g_sigArrow[g_sigN] = ap;
      g_sigN = n;
      lastSigI = i;
      lastSigDir = d;
   }

   // 表示とEAへの受け渡し(足が新しくなった時だけ)
   ComputeMsrLayer(rates_total, time);
   double curPrice = close[rates_total - 1];
   BuildMtf();
   LcService();                      // ★2026-11-21: 長期ライン(ファイル読込/たまにスキャン)。軽い判定のみ
   ComputeImportantLines();
   BuildRrCandidates(curPrice);
   DrawImportantLines(time[rates_total - 1], curPrice);
   if(InpShowArrows) DrawSignals(time, rates_total);
   else              ObjectsDeleteAll(0, YDS_PFX + "SG_");
   DrawPanel(time, curPrice);
   PublishGV(time);
   ChartRedraw(0);
   return(rates_total);
}
//+------------------------------------------------------------------+
