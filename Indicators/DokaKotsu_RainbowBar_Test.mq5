//+------------------------------------------------------------------+
//|                              DokaKotsu_RainbowBar_Test.mq5        |
//|  「エントリータイミング」レインボーバーのCanvas試作版              |
//|  ・5色帯 → 滑らかな横グラデーション                                |
//|  ・直角 → 角丸（距離ベースのアンチエイリアス）                     |
//|  ・進捗マスクの境界 → フェザー（ぼかし）付き                       |
//|  ・針 → 淡いグロー効果                                             |
//|  ※ DokaKotsu_Dashboard.mq5には未統合。単体テスト用。               |
//+------------------------------------------------------------------+
#property copyright "DokaKotsu"
#property indicator_chart_window
#property indicator_plots   0
#property indicator_buffers 0

#include <Canvas\Canvas.mqh>

//--- 入力パラメータ（既存パネルの座標感に合わせて調整可）
input int    InpBarX      = 20;    // バーX位置
input int    InpBarY      = 150;   // バーY位置
input int    InpBarWidth  = 260;   // バー幅
input int    InpBarHeight = 22;    // バー高さ
input double InpProgress  = 0.12;  // 進捗(0.0〜1.0) ※WAIT!サンプル位置
input int    InpRadius    = 9;     // 角丸半径(px)

#define BAR_OBJ "DKD_RainbowBarTest"

CCanvas ExtCanvas;

//--- グラデーションの色ストップ（元の5色帯を両端に据えて滑らかに繋ぐ）
color GradStops[5] =
  {
   C'200,160,0',   // 黄（開始）
   C'74,138,74',
   C'45,122,45',
   C'0,96,128',
   C'0,74,112'     // 青（終了）
  };

//+------------------------------------------------------------------+
//| RGB線形補間                                                       |
//+------------------------------------------------------------------+
color LerpColor(color a,color b,double t)
  {
   if(t<0) t=0;
   if(t>1) t=1;
   int r =(int)MathRound((1-t)*((a>>0) &0xFF)+t*((b>>0) &0xFF));
   int g =(int)MathRound((1-t)*((a>>8) &0xFF)+t*((b>>8) &0xFF));
   int bl=(int)MathRound((1-t)*((a>>16)&0xFF)+t*((b>>16)&0xFF));
   return (color)((bl<<16)|(g<<8)|r);
  }

//+------------------------------------------------------------------+
//| t(0〜1)位置のグラデーション色を取得（5ストップ間を補間）           |
//+------------------------------------------------------------------+
color GradientAt(double t)
  {
   int n=3; // 区間数 = ストップ数-1 = 4 だが配列は5個 → 区間4
   n=4;
   double seg=1.0/n;
   int idx=(int)MathFloor(t/seg);
   if(idx>=n) idx=n-1;
   if(idx<0)  idx=0;
   double localT=(t-idx*seg)/seg;
   return LerpColor(GradStops[idx],GradStops[idx+1],localT);
  }

//+------------------------------------------------------------------+
//| 指定ピクセルのアルファ値だけを上書き（RGBは維持）                 |
//+------------------------------------------------------------------+
void SetPixelAlpha(int x,int y,int w,int h,uchar alpha)
  {
   if(x<0 || y<0 || x>=w || y>=h) return;
   uint cur=ExtCanvas.PixelGet(x,y);
   uint rgb=cur & 0x00FFFFFF;
   ExtCanvas.PixelSet(x,y,((uint)alpha<<24)|rgb);
  }

//+------------------------------------------------------------------+
//| 角丸マスク：四隅を距離ベースでアンチエイリアスしながら透明化       |
//+------------------------------------------------------------------+
void ApplyRoundedMask(int w,int h,int r)
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
            continue; // 完全に内側→そのまま
         else
            if(dist>=r+0.0)
               alphaF=0.0; // 完全に外側→透明
            else
               alphaF=1.0-(dist-(r-1.0)); // 境界1px幅でフェード

         uchar a=(uchar)MathRound(255*alphaF);
         SetPixelAlpha(cx,       cy,       w,h,a);
         SetPixelAlpha(w-1-cx,   cy,       w,h,a);
         SetPixelAlpha(cx,       h-1-cy,   w,h,a);
         SetPixelAlpha(w-1-cx,   h-1-cy,   w,h,a);
        }
     }
  }

//+------------------------------------------------------------------+
//| バー本体の描画                                                    |
//+------------------------------------------------------------------+
void DrawRainbowBar()
  {
   int w=InpBarWidth;
   int h=InpBarHeight;
   int r=InpRadius;
   if(r*2>h) r=h/2; // 半径がバー高さを超えないよう安全策

   //--- 透明でクリア
   ExtCanvas.Erase(0x00000000);

   //--- 1) 横方向に1pxずつグラデーション色を敷く
   for(int x=0;x<w;x++)
     {
      double t=(double)x/(double)(w-1);
      color  c=GradientAt(t);
      uint   argb=ColorToARGB(c,255);
      ExtCanvas.LineVertical(x,0,h-1,argb);
     }

   //--- 2) 進捗マスク：未到達部分を暗くする（境界をフェザー処理でぼかす）
   double progress=InpProgress;
   double maskStartPx=w*progress;
   int    featherPx=6; // ぼかし幅

   color darkOverlay=C'28,31,38'; // COL_DARKCELL相当
   for(int x=0;x<w;x++)
     {
      if(x<maskStartPx-featherPx)
         continue; // 手前（進捗済み）はグラデーションのまま

      double distIntoMask=x-(maskStartPx-featherPx);
      double blend=distIntoMask/(double)(featherPx*2);
      if(blend<0) blend=0;
      if(blend>1) blend=1;

      double t=(double)x/(double)(w-1);
      color  base=GradientAt(t);
      color  mixed=LerpColor(base,darkOverlay,blend);
      uint   argb=ColorToARGB(mixed,255);
      ExtCanvas.LineVertical(x,0,h-1,argb);
     }

   //--- 3) 角丸マスク適用
   ApplyRoundedMask(w,h,r);

   //--- 4) 針（進捗位置）を淡いグロー付きで描画
   int needleX=(int)MathRound(maskStartPx);
   for(int d=3;d>=0;d--)
     {
      int   alpha=(d==0)?255:(90-d*20);
      if(alpha<0) alpha=0;
      uint  glowArgb=ColorToARGB(clrWhite,(uchar)alpha);
      int   nx=needleX-d;
      if(nx>=0 && nx<w) ExtCanvas.LineVertical(nx,0,h-1,glowArgb);
      int   nx2=needleX+d;
      if(d>0 && nx2>=0 && nx2<w) ExtCanvas.LineVertical(nx2,0,h-1,glowArgb);
     }

   ExtCanvas.Update();
  }

//+------------------------------------------------------------------+
//| 初期化                                                            |
//+------------------------------------------------------------------+
int OnInit()
  {
   IndicatorSetString(INDICATOR_SHORTNAME,"DokaKotsu RainbowBar Test");

   if(!ExtCanvas.CreateBitmapLabel(0,0,BAR_OBJ,InpBarX,InpBarY,InpBarWidth,InpBarHeight,COLOR_FORMAT_ARGB_NORMALIZE))
     {
      Print("Canvas作成失敗: ",GetLastError());
      return(INIT_FAILED);
     }
   ObjectSetInteger(0,BAR_OBJ,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,BAR_OBJ,OBJPROP_BACK,false);
   ObjectSetInteger(0,BAR_OBJ,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,BAR_OBJ,OBJPROP_HIDDEN,true);

   DrawRainbowBar();
   ChartRedraw(0);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| 終了処理                                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ExtCanvas.Destroy();
   ObjectDelete(0,BAR_OBJ);
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
