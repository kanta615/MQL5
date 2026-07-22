//+------------------------------------------------------------------+
//|                                     DokaKotsu_VolScore_Sub.mq5    |
//|  ボラティリティ(VolScore)専用のサブチャート表示インジ(表示専用)   |
//|                                                                    |
//|  ■ 更新日: 2026-07-21  新規作成                                   |
//|    DokaKotsu_Dashboard.mq5のComputeVolScore()と同じ式を、          |
//|    全バーぶんの時系列としてヒストグラム表示するために新設。        |
//|      CurrentVol = EMA(High-Low, 5)                                |
//|      VolScore   = (CurrentVol - EMA(CurrentVol,20)) / EMA(それ,20) |
//|    4段階の閾値もDashboardと同じ考え方(グレー/イエロー/ライム/     |
//|    レッド)。ただし今回の田島さんのご要望により既定値を変更:        |
//|      InpVolScoreLowPct  既定 -40 → 0 (グレー境界=ゼロライン。      |
//|        ゼロ以下は全てグレー=将来的にエントリー禁止の目印にする想定)|
//|      InpVolScoreMidPct  既定 30  (変更なし)                        |
//|      InpVolScoreHighPct 既定 120 (変更なし)                        |
//|    ★本ファイルは表示専用。エントリー禁止の判定ロジックは持たない  |
//|    (絶対ルール1に従い、実装する場合はDokaKotsu_indicator_15側に    |
//|    一本化する。今回はまずサブチャートで挙動を確認する段階)。       |
//|    ★注意: 計算式(k5=2/6, k20=2/21)はDashboard側と同一だが、       |
//|    ファイルを分けているため物理的には別コード(共有.mqh化していない)。|
//|    将来どちらかの式を変える場合はもう片方も手動で合わせること。    |
//|                                                                    |
//|  ■ 更新日: 2026-07-21(2回目)  修正内容                            |
//|    閾値の既定値を変更: グレー境界 0→10 / イエロー境界 30→40。      |
//|    ハイ境界(120)は変更なし。あわせて、グレー境界のレベルラインが   |
//|    0.0固定になっていたバグを修正し、InpVolScoreLowPctに連動するよう|
//|    修正(ラベル文言も動的表記に変更)。                             |
//+------------------------------------------------------------------+
#property copyright   "DokaKotsu"
#property version     "1.01"
#property indicator_separate_window
#property indicator_buffers 4
#property indicator_plots   1

#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  C'85,85,85',C'230,184,0',C'0,255,0',C'244,67,54'
#property indicator_width1  2
#property indicator_style1  STYLE_SOLID
#property indicator_label1  "VolScore(%)"

//--- 入力パラメータ(Dashboard側のInpVolScoreLow/Mid/HighPctと同じ役割・同じ既定値の考え方)
input double InpVolScoreLowPct  = 10.0;   // グレー境界(2026-07-21(2回目): 0→10。これ未満=グレー)
input double InpVolScoreMidPct  = 40.0;   // これ未満=イエロー(2026-07-21(2回目): 30→40)
input double InpVolScoreHighPct = 120.0;  // これ未満=ライム。これ以上=レッド

//--- 表示バッファ(0=値,1=色インデックス) ＋ 計算専用バッファ(2=vol5,3=vol20・非表示)
double g_val[];
double g_col[];
double g_vol5[];
double g_vol20[];

//+------------------------------------------------------------------+
//| 初期化                                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, g_val,  INDICATOR_DATA);
   SetIndexBuffer(1, g_col,  INDICATOR_COLOR_INDEX);
   SetIndexBuffer(2, g_vol5,  INDICATOR_CALCULATIONS);
   SetIndexBuffer(3, g_vol20, INDICATOR_CALCULATIONS);

   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu_VolScore_Sub");
   IndicatorSetInteger(INDICATOR_DIGITS, 1);

   //--- 3本の閾値ライン(0%/Mid%/High%)。inputで動かせるよう実行時に設定
   IndicatorSetInteger(INDICATOR_LEVELS, 3);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, InpVolScoreLowPct);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, InpVolScoreMidPct);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 2, InpVolScoreHighPct);
   IndicatorSetString(INDICATOR_LEVELTEXT, 0, StringFormat("%.0f%%(グレー境界)", InpVolScoreLowPct));
   IndicatorSetString(INDICATOR_LEVELTEXT, 1, StringFormat("%.0f%%", InpVolScoreMidPct));
   IndicatorSetString(INDICATOR_LEVELTEXT, 2, StringFormat("%.0f%%", InpVolScoreHighPct));
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, clrDimGray);

   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| 計算(全バー分をEMA2段階で再帰計算。式はDashboard側と同一)          |
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
   if(rates_total < 2) return 0;

   double k5  = 2.0 / (5.0  + 1.0);
   double k20 = 2.0 / (20.0 + 1.0);

   //--- 再計算が必要な開始位置(初回は0から、以降は直前バーから再計算してEMAのつながりを保つ)
   int start = (prev_calculated > 1) ? prev_calculated - 1 : 0;

   for(int i = start; i < rates_total; i++)
     {
      double rng = high[i] - low[i];

      if(i == 0)
         g_vol5[i] = rng;
      else
         g_vol5[i] = rng * k5 + g_vol5[i-1] * (1.0 - k5);

      if(i == 0)
         g_vol20[i] = g_vol5[i];
      else
         g_vol20[i] = g_vol5[i] * k20 + g_vol20[i-1] * (1.0 - k20);

      double score = (g_vol20[i] > 0.0) ? (g_vol5[i] - g_vol20[i]) / g_vol20[i] * 100.0 : 0.0;
      g_val[i] = score;

      if(score < InpVolScoreLowPct)
         g_col[i] = 0;   // グレー(禁止想定ゾーン)
      else if(score < InpVolScoreMidPct)
         g_col[i] = 1;   // イエロー
      else if(score < InpVolScoreHighPct)
         g_col[i] = 2;   // ライム
      else
         g_col[i] = 3;   // レッド
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
