//+------------------------------------------------------------------+
//|  DokaKotsu_FilePathCheck.mq5                                      |
//|  ★診断専用スクリプト(2026-07-08作成)                             |
//|  目的: DokaKotsu_US_Calendar_v3.mq5が書き出すはずのファイルの     |
//|        実際の保存先パスと、書き込みが本当に成功するかを確認する。 |
//+------------------------------------------------------------------+
#property script_show_inputs

#define CAL_FILE      "DokaKotsu_Calendar_Today.txt"
#define CAL_JSON_FILE "mt5_calendar_today.json"

void TestWrite(string filename)
{
   ResetLastError();
   int h = FileOpen(filename, FILE_WRITE|FILE_TXT|FILE_UNICODE|FILE_COMMON);
   if(h == INVALID_HANDLE)
   {
      Print("  ★書き込み失敗: ", filename, "  err=", GetLastError());
      return;
   }
   FileWrite(h, "DokaKotsu診断スクリプトによるテスト書き込み: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
   FileClose(h);
   Print("  ✔書き込み成功: ", filename);

   // 読み直して存在確認
   ResetLastError();
   int h2 = FileOpen(filename, FILE_READ|FILE_TXT|FILE_UNICODE|FILE_COMMON);
   if(h2 == INVALID_HANDLE)
   {
      Print("    → ただし読み直しに失敗  err=", GetLastError());
   }
   else
   {
      string line = FileReadString(h2);
      FileClose(h2);
      Print("    → 読み直し確認OK: \"", line, "\"");
   }
}

void OnStart()
{
   Print("===== DokaKotsu 共通フォルダ診断 =====");
   Print("TERMINAL_COMMONDATA_PATH = ", TerminalInfoString(TERMINAL_COMMONDATA_PATH));
   Print("  (この直下の Files フォルダに DokaKotsu_Calendar_Today.txt / mt5_calendar_today.json が出るはず)");
   Print("TERMINAL_DATA_PATH       = ", TerminalInfoString(TERMINAL_DATA_PATH));
   Print("--- 既存ファイルの有無 ---");
   Print("  ", CAL_FILE, " 存在: ", FileIsExist(CAL_FILE, FILE_COMMON) ? "あり" : "なし");
   Print("  ", CAL_JSON_FILE, " 存在: ", FileIsExist(CAL_JSON_FILE, FILE_COMMON) ? "あり" : "なし");
   Print("--- 書き込みテスト(このスクリプト自身が同じ方式で試す) ---");
   TestWrite(CAL_FILE);
   TestWrite(CAL_JSON_FILE);
   Print("===== 診断ここまで =====");
   Alert("パス診断完了。「エキスパート」タブを確認してください。");
}
