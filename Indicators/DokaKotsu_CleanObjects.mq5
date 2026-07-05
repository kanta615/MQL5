//+------------------------------------------------------------------+
//|                       DokaKotsu_CleanObjects.mq5               |
//|   DokaKotsu系インジが残したチャートオブジェクトを一掃する       |
//|   掃除スクリプト。                                               |
//|                                                                  |
//|   背景色・時刻目盛り・ラベル・矢印などの「残骸」が              |
//|   インジを外しても消えない時に、チャートにドラッグするだけで    |
//|   きれいに削除する。                                            |
//|                                                                  |
//|   使い方: ナビゲーター→スクリプト→チャートにドラッグ           |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property version   "1.00"

//=== 入力 =========================================================
input bool InpAlsoSubwindows = true;  // サブウィンドウのオブジェクトも消す

//+------------------------------------------------------------------+
//| 指定プレフィックスで始まるオブジェクトを全削除し、件数を返す    |
//+------------------------------------------------------------------+
int DeleteByPrefix(string prefix)
{
   int cnt = 0;
   int total = ObjectsTotal(0, -1, -1);   // 全ウィンドウ・全種類
   // 後ろから走査(削除でインデックスがずれるため)
   for(int i = total-1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, prefix) == 0)      // 先頭一致
      {
         if(ObjectDelete(0, nm)) cnt++;
      }
   }
   return cnt;
}

//+------------------------------------------------------------------+
void OnStart()
{
   // DokaKotsu系インジが使う全プレフィックス(過去版含む)
   string prefixes[] = {
      "DKsess_",     // セッション背景色・ラベル
      "DKsess_label",// セッション名ラベル
      "DKjst_",      // 旧JST目盛り(削除済み版の残骸)
      "DKjstax_",    // JST目盛り(サブ窓版・旧名)
      "DKjstsub_",   // JST目盛り(サブ窓版)
      "DK_"          // その他DokaKotsu系の保険
   };

   int totalDeleted = 0;
   string report = "";
   for(int p = 0; p < ArraySize(prefixes); p++)
   {
      int c = DeleteByPrefix(prefixes[p]);
      totalDeleted += c;
      if(c > 0)
         report += StringFormat("  %s : %d件\n", prefixes[p], c);
   }

   ChartRedraw(0);

   string msg;
   if(totalDeleted > 0)
      msg = StringFormat("DokaKotsuオブジェクトを %d件 削除しました。\n%s",
                         totalDeleted, report);
   else
      msg = "削除対象のオブジェクトはありませんでした。\n(既にきれいな状態です)";

   Print(msg);
   Alert(msg);
}
//+------------------------------------------------------------------+
