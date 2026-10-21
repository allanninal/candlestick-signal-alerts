//+------------------------------------------------------------------+
//|                                      CandlestickSignalAlerts.mq4 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| MT4 edition of Candlestick Signal Alerts: the same engine        |
//| (Cdl.mqh, an exact copy of the MT5 edition's Cdl.mqh).           |
//| 13 classic candlestick patterns, marked with an arrow and a short|
//| label on the closed bar that completes them. Patterns that need a|
//| prior trend use close vs EMA(20). Closed bars only. Alerts.      |
//| MT4 difference: the arrows sit a fraction of ATR(14) away from   |
//| the candle (MT4 has no pixel shift); the label sits between.     |
//| Buffers for iCustom match MT5: 0 bullish, 1 bearish, 2/3 masks.  |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property copyright "Copyright 2026, Allan Niñal <https://www.allanninal.dev/mql5>"
#property link      "https://www.allanninal.dev/mql5"
#property version   "1.00"
#property strict
#property description "13 candlestick patterns: engulfing, hammer, hanging man, shooting star, doji, stars, harami, piercing, dark cloud."
#property description "Closed bars only, never repaints. Arrow + label per pattern. Alerts: pop-up, sound, push, e-mail."
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_color1  C'38,166,98'
#property indicator_width1  1
#property indicator_color2  C'226,74,70'
#property indicator_width2  1

#include "Cdl.mqh"

input bool   InpEngulfing = true;    // Engulfing (bullish, bearish)
input bool   InpHammer    = true;    // Hammer and Hanging Man
input bool   InpInverted  = true;    // Inverted Hammer and Shooting Star
input bool   InpDoji      = true;    // Doji
input bool   InpStars     = true;    // Morning Star and Evening Star
input bool   InpHarami    = true;    // Harami (bullish, bearish)
input bool   InpPiercing  = true;    // Piercing Line and Dark Cloud Cover
input int    InpHistory   = 2000;    // Closed bars to scan on the chart (100-20000)
input bool   InpLabels    = true;    // Short labels
input color  InpColBull   = C'38,166,98';   // Bullish colour
input color  InpColBear   = C'226,74,70';   // Bearish colour
input int    InpFontSize  = 7;       // Label font size
input double InpArrowGap  = 0.5;     // Arrow distance from the candle (x ATR)

#include "SignalAlerts.mqh"

const string PRODUCT="Candlestick Signal Alerts";
const string PREFIX ="CDP_";

//--- series-indexed (0 = live bar), as every MT4 buffer
double   g_bull[],g_bear[],g_mbull[],g_mbear[];
bool     g_use[CD_NP];
CDState  g_s;
int      g_start=0,g_fed=0;                // oldest-based index of engine bar 0, bars fed so far
datetime g_alert_bar=0;

void Clear()
  {
   ObjectsDeleteAll(0,PREFIX);
   CDInit(g_s);
   g_fed=0;
  }

void Label(const string name,const datetime t,const double p,const string txt,const string tip,const color clr,const bool below)
  {
   if(ObjectFind(0,name)>=0)
      return;
   ObjectCreate(0,name,OBJ_TEXT,0,t,p);
   ObjectSetString(0,name,OBJPROP_TEXT,txt);
   ObjectSetString(0,name,OBJPROP_TOOLTIP,tip);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,InpFontSize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,below ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

int OnInit()
  {
   ArrayInitialize(g_use,false);
   g_use[0]=g_use[1]=InpEngulfing;
   g_use[2]=g_use[3]=InpHammer;
   g_use[4]=g_use[5]=InpInverted;
   g_use[6]=InpDoji;
   g_use[7]=g_use[8]=InpStars;
   g_use[9]=g_use[10]=InpHarami;
   g_use[11]=g_use[12]=InpPiercing;
   bool any=false;
   for(int i=0; i<CD_NP; i++)
      any|=g_use[i];
   if(!any || InpHistory<100 || InpHistory>20000 || InpFontSize<6 || InpFontSize>14 || InpArrowGap<0)
     {
      Print(PRODUCT,": switch on at least one pattern; history 100-20000; font 6-14");
      return(INIT_PARAMETERS_INCORRECT);
     }
   SetIndexBuffer(0,g_bull);
   SetIndexBuffer(1,g_bear);
   SetIndexBuffer(2,g_mbull);
   SetIndexBuffer(3,g_mbear);
   SetIndexStyle(0,DRAW_ARROW,EMPTY,EMPTY,InpColBull);
   SetIndexStyle(1,DRAW_ARROW,EMPTY,EMPTY,InpColBear);
   SetIndexArrow(0,233);
   SetIndexArrow(1,234);
   SetIndexStyle(2,DRAW_NONE);
   SetIndexStyle(3,DRAW_NONE);
   SetIndexLabel(0,"Bullish pattern");
   SetIndexLabel(1,"Bearish pattern");
   SetIndexLabel(2,"Bullish patterns (bit mask)");
   SetIndexLabel(3,"Bearish patterns (bit mask)");
   for(int b=0; b<4; b++)
      SetIndexEmptyValue(b,EMPTY_VALUE);
   IndicatorShortName(PRODUCT);
   Clear();
   return(INIT_SUCCEEDED);
  }

void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0,PREFIX);
  }

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],
                const double &open[],const double &high[],const double &low[],const double &close[],
                const long &tick_volume[],const long &volume[],const int &spread[])
  {
   if(rates_total<30)
      return(0);
   ArraySetAsSeries(time,true);
   ArraySetAsSeries(open,true);
   ArraySetAsSeries(high,true);
   ArraySetAsSeries(low,true);
   ArraySetAsSeries(close,true);
   if(prev_calculated==0)
     {
      Clear();
      g_start=MathMax(0,rates_total-1-InpHistory);
      ArrayInitialize(g_bull,EMPTY_VALUE); ArrayInitialize(g_bear,EMPTY_VALUE);
      ArrayInitialize(g_mbull,EMPTY_VALUE); ArrayInitialize(g_mbear,EMPTY_VALUE);
     }
   else
      for(int s=rates_total-1-(g_start+g_fed); s>=0; s--)
        { g_bull[s]=EMPTY_VALUE; g_bear[s]=EMPTY_VALUE; g_mbull[s]=EMPTY_VALUE; g_mbear[s]=EMPTY_VALUE; }
   bool live=(prev_calculated>0);
   string events="";
//--- feed every closed bar not fed yet, oldest first (i counts from the oldest bar, s is the series index)
   for(int i=g_start+g_fed; i<=rates_total-2; i++)
     {
      int s=rates_total-1-i;
      bool ev=CDFeed(g_s,g_use,open[s],high[s],low[s],close[s]);
      g_fed++;
      if(!ev)
         continue;
      int mb=0,ms=0;
      string lb="",ls="";
      for(int p=0; p<CD_NP; p++)
         if((g_s.ev_mask&(1<<p))!=0)
           {
            if(g_s.ev_dir[p]>0)
              { mb|=(1<<p); lb+=(lb=="" ? "" : " ")+CDShort(p); }
            else
              { ms|=(1<<p); ls+=(ls=="" ? "" : " ")+CDShort(p); }
           }
      string id=PREFIX+IntegerToString((long)time[s]);
      double gap=InpArrowGap*iATR(NULL,0,14,s);
      if(mb>0)
        {
         g_bull[s]=low[s]-gap; g_mbull[s]=mb;
         if(InpLabels)
            Label(id+"b",time[s],low[s],lb,CDNames(g_s,mb,1),InpColBull,true);
        }
      if(ms>0)
        {
         g_bear[s]=high[s]+gap; g_mbear[s]=ms;
         if(InpLabels)
            Label(id+"s",time[s],high[s],ls,CDNames(g_s,ms,-1),InpColBear,false);
        }
      if(live && i==rates_total-2 && time[s]>g_alert_bar)
        {
         g_alert_bar=time[s];
         if(mb>0)
            events=StringFormat("Bullish %s on %s %s",CDNames(g_s,mb,1),_Symbol,TfName());
         if(ms>0)
            events+=(events=="" ? "" : "; ")+StringFormat("Bearish %s on %s %s",CDNames(g_s,ms,-1),_Symbol,TfName());
        }
     }
   if(events!="")
      SignalAlertMessage(PRODUCT,events);
   return(rates_total);
  }
//+------------------------------------------------------------------+
