//+------------------------------------------------------------------+
//|                                        DokaKotsu_Dashboard.mq5    |
//|  dokakotu_dashboard_v8_4.html のデザインをMT5チャート上に         |
//|  再現するパネル（第一段階：機能なし・表示のみ／固定サンプル値）   |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

//--- パネル位置・サイズ設定
input int InpPanelX          = 0;    // パネルX位置（左からの距離）＝売買ボタンの左端に合わせる
input int InpPanelY          = 120;  // パネルY位置（上からの距離）＝売買ボタンより下
input int InpPanelWidth      = 320;  // パネル幅＝売買ボタンの横幅に合わせる（環境により微調整）
input int InpPanelHeightPct  = 160;  // パネル縦幅（%）100=基準の詰まった表示／大きいほど縦に広がる

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

   // 上位足の方向
   CreateLabelText("dirlbl",x+pad,curY,"上位足の方向",COL_GRAY,7);
   curY+=(int)(20*sc);
   int dirboxH=(int)(32*sc);
   CreateRectLabel("dirbox",x+pad,curY,innerW,dirboxH,COL_CELL,COL_BORDER);
   CreateLabelText("dirarrow",x+pad+8,curY+(int)(5*sc),"↑",COL_GREEN,14);
   CreateLabelText("dirtext",x+pad+32,curY+(int)(9*sc),"上方向",COL_GREEN,9);
   CreateLabelText("dirstars",rightEdge-72,curY+(int)(10*sc),"★★★",COL_GREEN,10,"Arial",ANCHOR_RIGHT_UPPER);
   CreateButtonObj("closeall",rightEdge-58,curY+(int)(6*sc),58,20,"全決済",C'58,10,10',COL_RED,C'106,26,26');
   curY+=dirboxH+(int)(24*sc);

   // ボラティリティ（波形バー：静的サンプル）
   CreateLabelText("wavelbl",x+pad,curY,"ボラティリティ",COL_GRAY,7);
   curY+=(int)(20*sc);
   int waveboxH=(int)(36*sc);
   CreateRectLabel("wavebox",x+pad,curY,innerW,waveboxH,COL_CELL,COL_BORDER);
     {
      int barCount=16;
      int barAreaW=innerW-8;
      int barW=barAreaW/barCount;
      double h[16]={0.30,0.50,0.20,0.60,0.40,0.25,0.55,0.35,0.20,0.45,0.30,0.50,0.25,0.40,0.30,0.20};
      for(int i=0;i<barCount;i++)
        {
         int bh=(int)MathMax(4,(waveboxH-4)*h[i]);
         int bx=x+pad+4+i*barW;
         int by=curY+(waveboxH-bh)-2;
         CreateRectLabel("wavebar"+IntegerToString(i),bx,by,barW-1,bh,COL_YELLOW,COL_YELLOW,1);
        }
     }
   curY+=waveboxH+(int)(14*sc);
   CreateLabelText("wavestate",x+pad,curY,"LOW",COL_YELLOW,8);
   CreateLabelText("wavewarn",rightEdge,curY+1,"⚠ ボラ不足 — エントリー非推奨",COL_ORANGE,7,"Arial",ANCHOR_RIGHT_UPPER);
   curY+=(int)(32*sc);

   // エントリータイミング（レインボーバー）
   CreateLabelText("rblbl",x+pad,curY,"エントリータイミング",COL_GRAY,7);
   curY+=(int)(20*sc);
   int rbarH=(int)(20*sc);
     {
      int barX=x+pad;
      int barW=innerW-64;
      int barH=rbarH;
      int segW=barW/5;
      color segColors[5];
      segColors[0]=C'200,160,0';
      segColors[1]=C'74,138,74';
      segColors[2]=C'45,122,45';
      segColors[3]=C'0,96,128';
      segColors[4]=C'0,74,112';
      for(int i=0;i<5;i++)
         CreateRectLabel("rbseg"+IntegerToString(i),barX+i*segW,curY,segW+1,barH,segColors[i],segColors[i],1);
      double progress=0.12; // WAIT!状態のサンプル位置
      int maskX=barX+(int)(barW*progress);
      int maskW=barW-(int)(barW*progress);
      CreateRectLabel("rbmask",maskX,curY,maskW,barH,COL_DARKCELL,COL_DARKCELL,2);
      CreateRectLabel("rbneedle",maskX-1,curY,2,barH,clrWhite,clrWhite,3);
      CreateLabelText("rbstate",rightEdge,curY+barH/2-4,"WAIT!",C'184,134,11',8,"Arial",ANCHOR_RIGHT_UPPER);
     }
   curY+=rbarH+(int)(20*sc);

   // 決済目安（セグメント10分割）
   CreateLabelText("ailbl",x+pad,curY,"決済目安",COL_GRAY,7);
   curY+=(int)(20*sc);
   int segH=(int)(16*sc);
     {
      int segCount=10;
      int segAreaW=innerW-70;
      int segW=segAreaW/segCount;
      for(int i=0;i<segCount;i++)
        {
         color c=(i<2)?COL_GREEN:COL_DARKCELL;
         CreateRectLabel("aiseg"+IntegerToString(i),x+pad+i*segW,curY,segW-1,segH,c,c,1);
        }
      CreateLabelText("ailabel",rightEdge,curY+segH/2-6,"進行中",COL_GREEN,8,"Arial",ANCHOR_RIGHT_UPPER);
     }
   curY+=segH+(int)(20*sc);

   // アコーディオン見出し（第一段階では静的表示）
   int accH=(int)(20*sc);
   CreateRectLabel("accbox",x+pad,curY,innerW,accH,COL_BG,COL_BORDER,1);
   CreateLabelText("acclbl",x+pad+8,curY+accH/2-6,"▲ 本日の趣味レーション",COL_GRAY2,7);
   curY+=accH+(int)(12*sc);

   // 経済指標サンプル行
   int calH=(int)(18*sc);
   CreateRectLabel("calrow1",x+pad,curY,innerW,calH,COL_CELL,COL_CELL,1);
   CreateLabelText("cal1a",x+pad+6,curY+calH/2-6,"GDP",C'170,170,170',7);
   CreateLabelText("cal1b",rightEdge-4,curY+calH/2-6,"21:30",COL_GRAY2,7,"Arial",ANCHOR_RIGHT_UPPER);
   curY+=calH+(int)(8*sc);
   CreateRectLabel("calrow2",x+pad,curY,innerW,calH,COL_CELL,COL_CELL,1);
   CreateLabelText("cal2a",x+pad+6,curY+calH/2-6,"PCI",C'170,170,170',7);
   CreateLabelText("cal2b",rightEdge-4,curY+calH/2-6,"21:30",COL_GRAY2,7,"Arial",ANCHOR_RIGHT_UPPER);
   curY+=calH+(int)(14*sc);

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
   IndicatorSetString(INDICATOR_SHORTNAME,"DokaKotsu Dashboard");
   // 価格チャート（ローソク足・MA等の重ね書きインジケーター）がオブジェクトより
   // 前面に来ないようにする＝パネルが常に最前面に表示される
   ChartSetInteger(0,CHART_FOREGROUND,false);
   CreatePanel();
   EventSetMillisecondTimer(500);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| タイマー：他インジケーターが後から前面に出てきた場合に            |
//| パネルを再度最前面へ引き上げる                                    |
//+------------------------------------------------------------------+
void OnTimer()
  {
   CreatePanel();
  }

//+------------------------------------------------------------------+
//| 終了処理（オブジェクト全削除）                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectsDeleteAll(0,PFX);
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
