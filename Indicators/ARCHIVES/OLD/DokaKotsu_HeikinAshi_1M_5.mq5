//+------------------------------------------------------------------+
//|                        DokaKotsu_HeikinAshi_1M_5.mq5            |
//|   決済判定と完全に同じ平均足を、そのままチャートに表示する。     |
//|   自前では一切計算せず、DokaKotsu_indicator_1M_5.mq5が決済判定に |
//|   使っている平均足バッファ(BufHaOpen/High/Low/Close、buf16-19)  |
//|   をiCustom経由で読み取って描画するだけの「窓」になっている。    |
//|                                                                  |
//|   これにより「表示は緩やかなのに決済は速い(逆も然り)」といった  |
//|   表示側と決済側の平滑化の二重管理・食い違いが構造的に起きなく   |
//|   なる。前平滑化・後平滑化の期間や方式を変えたい場合は、この     |
//|   ファイルではなくDokaKotsu_indicator_1M_5.mq5側のInpHaPrePeriod |
//|   /InpHaPostPeriod/InpHaPreMethod/InpHaPostMethodを変更すること。|
//|   (「ロジックは全部インジ側、他は持たない」という設計方針を     |
//|   表示側にも適用したもの)                                       |
//|                                                                  |
//|   更新日: 2026-10-06                                             |
//|   変更履歴(2026-10-06):                                          |
//|     - 参照先インジがDokaKotsu_indicator_1M_5へ改名されたのに、    |
//|       本ファイルの参照先が1M_4のままだったため、ファイル名・     |
//|       参照先を1M_5に更新(Verを5に)。                            |
//|     - iCustomの第1引数にfalse(InpPublishSignalGV)を渡し、        |
//|       表示用の裏インスタンスが矢印GVを公開しないようにした。    |
//|   ---- 以下は2026-09-25の変更履歴 ----                          |
//|   変更履歴:                                                      |
//|     - ファイル名を DokaKotsu_HeikinAshi_1M_5.mq5 に変更(Verを4に)|
//|     - 前平滑化・後平滑化の自前計算(MAValue等)を全て撤去し、      |
//|       DokaKotsu_indicator_1M_5.mq5をiCustomで呼び出して          |
//|       決済用平均足バッファ(buf16-19)をそのまま描画する方式に     |
//|       作り直した。田島さんより「決済がおかしい、毎回1分で決済    |
//|       される」とのご指摘を受け、9/23に決済側を無平滑(1/1)に      |
//|       戻す対症療法が行われていたと判明。表示用インジ(本ファイル) |
//|       が決済側の平滑化(25/25)に追従できておらず見た目が違って    |
//|       見えていたことが根本原因だったため、二重管理の構造自体を   |
//|       解消し、以後は表示と決済が常に完全一致するようにした。     |
//|     - InpPrePeriod/InpPostPeriod等、前平滑化・後平滑化に関する   |
//|       入力パラメータは全て削除(決済側インジの入力が唯一の設定    |
//|       箇所になったため、本ファイルに重複する設定項目を持たない)。|
//|   ※2026-09-15付 旧版の変更履歴(参考): 決済を1分から5分の平均足に |
//|     変更/前後平滑化期間を25に変更/ファイル名を1M_3に変更         |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1M5.00"
#property indicator_chart_window
#property indicator_buffers 5
#property indicator_plots   1

//--- 平均足キャンドル(4値: Open High Low Close)＋色
#property indicator_label1  "DokaKotsu HA"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrMediumSeaGreen, clrOrange
#property indicator_width1  1

//=== 入力 =========================================================
// ★2026-09-25: 前平滑化・後平滑化の期間/方式は決済側インジ
//   (DokaKotsu_indicator_1M_5.mq5のInpHaPrePeriod等)が唯一の設定箇所。
//   本ファイルには重複させず、参照先インジ名と色だけを入力にしている。
input string InpDecisionIndicatorName = "DokaKotsu_indicator_1M_5"; // 決済用平均足を読み取る参照先インジ名
input color  InpBullColor   = clrMediumSeaGreen; // 陽線(上昇)の色
input color  InpBearColor   = clrOrange;         // 陰線(下降)の色

//=== バッファ =====================================================
double BufOpen[];
double BufHigh[];
double BufLow[];
double BufClose[];
double BufColor[];   // 0=陽線 / 1=陰線

int g_decHandle = INVALID_HANDLE;   // 決済用インジのハンドル
bool g_warnedOnce = false;          // ハンドル取得失敗の警告は一度だけ出す

// 決済側のバッファ番号(DokaKotsu_indicator_1M_5.mq5のSetIndexBuffer登録順と一致させる)
#define DEC_BUF_HA_OPEN  16
#define DEC_BUF_HA_HIGH  17
#define DEC_BUF_HA_LOW   18
#define DEC_BUF_HA_CLOSE 19

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BufOpen,  INDICATOR_DATA);
   SetIndexBuffer(1, BufHigh,  INDICATOR_DATA);
   SetIndexBuffer(2, BufLow,   INDICATOR_DATA);
   SetIndexBuffer(3, BufClose, INDICATOR_DATA);
   SetIndexBuffer(4, BufColor, INDICATOR_COLOR_INDEX);

   PlotIndexSetInteger(0, PLOT_COLOR_INDEXES, 2);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpBullColor);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpBearColor);

   IndicatorSetString(INDICATOR_SHORTNAME, "DokaKotsu HA (決済連動:" + InpDecisionIndicatorName + ")");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   // ★2026-09-25追加: 決済用インジのハンドルを取得。パラメータは一切渡さず、
   //   決済側インジ自身のinput既定値(InpHaPrePeriod等)をそのまま使わせることで、
   //   平滑化の設定を本当に1箇所(決済側インジ)だけに一元化する。
   g_decHandle = iCustom(_Symbol, PERIOD_CURRENT, InpDecisionIndicatorName, false);   // ★2026-10-06: 第1引数=InpPublishSignalGV=false(表示用の裏インスタンスは矢印GVを公開しない)
   if(g_decHandle == INVALID_HANDLE)
   {
      Print("[HeikinAshi_1M_5] 警告: 決済用インジ(", InpDecisionIndicatorName,
            ")のハンドル生成失敗。チャートにDokaKotsu_indicator_1M_5がアタッチされているか確認してください。err=", GetLastError());
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_decHandle != INVALID_HANDLE) IndicatorRelease(g_decHandle);
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
   if(rates_total < 2) return(0);

   // ★2026-09-25追加: ハンドルが無効(未アタッチ等)ならインジがまだ準備できていないので、
   //   一度だけ警告を出し、今回は何もせず前回の描画をそのまま残す(異常終了させない)。
   if(g_decHandle == INVALID_HANDLE)
   {
      // 再アタッチ等で後から有効になるケースもあるため、毎回リトライする。
      g_decHandle = iCustom(_Symbol, PERIOD_CURRENT, InpDecisionIndicatorName, false);   // ★2026-10-06: 第1引数=InpPublishSignalGV=false(表示用の裏インスタンスは矢印GVを公開しない)
      if(g_decHandle == INVALID_HANDLE)
      {
         if(!g_warnedOnce)
         {
            Print("[HeikinAshi_1M_5] 決済用インジが見つからないため表示を保留中です。DokaKotsu_indicator_1M_5をチャートにアタッチしてください。");
            g_warnedOnce = true;
         }
         return(0);
      }
   }

   double tmpO[], tmpH[], tmpL[], tmpC[];
   ArraySetAsSeries(tmpO, true);
   ArraySetAsSeries(tmpH, true);
   ArraySetAsSeries(tmpL, true);
   ArraySetAsSeries(tmpC, true);

   int gotO = CopyBuffer(g_decHandle, DEC_BUF_HA_OPEN,  0, rates_total, tmpO);
   int gotH = CopyBuffer(g_decHandle, DEC_BUF_HA_HIGH,  0, rates_total, tmpH);
   int gotL = CopyBuffer(g_decHandle, DEC_BUF_HA_LOW,   0, rates_total, tmpL);
   int gotC = CopyBuffer(g_decHandle, DEC_BUF_HA_CLOSE, 0, rates_total, tmpC);

   // ★決済側インジがまだ計算中(起動直後の状態ログ読込中等)でバッファが揃っていない場合は
   //   今回はスキップし、次のOnCalculateで再取得する(異常値を描画しない)。
   if(gotO <= 0 || gotH <= 0 || gotL <= 0 || gotC <= 0) return(0);

   int n = MathMin(MathMin(gotO, gotH), MathMin(gotL, gotC));

   for(int k = 0; k < n; k++)
   {
      int i = rates_total - 1 - k;   // series(0=最新)→本バッファの昇順indexへ変換
      if(i < 0) continue;

      BufOpen[i]  = tmpO[k];
      BufHigh[i]  = tmpH[k];
      BufLow[i]   = tmpL[k];
      BufClose[i] = tmpC[k];
      BufColor[i] = (tmpC[k] >= tmpO[k]) ? 0 : 1;   // 0=陽線 / 1=陰線
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
