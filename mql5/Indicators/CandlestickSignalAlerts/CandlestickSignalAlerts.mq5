//+------------------------------------------------------------------+
//|                                      CandlestickSignalAlerts.mq5 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| 13 classic candlestick patterns on one chart, marked with an     |
//| arrow and a short label on the closed bar that completes them.   |
//| Patterns that need a prior trend use close vs EMA(20). Never     |
//| repaints: closed bars only. Alerts.                              |
//| Engine: Cdl.mqh (same folder). Rules: tests/reference.py.        |
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property copyright "Copyright 2026, Allan Niñal <https://www.allanninal.dev/mql5>"
#property link      "https://www.allanninal.dev/mql5"
#property version   "1.00"
#property description "13 candlestick patterns: engulfing, hammer, hanging man, shooting star, doji, stars, harami, piercing, dark cloud."
#property description "Closed bars only, never repaints. Arrow + label per pattern. Alerts: pop-up, sound, push, e-mail."
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4
#property indicator_label1  "Bullish pattern"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  C'38,166,98'
#property indicator_width1  1
#property indicator_label2  "Bearish pattern"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  C'226,74,70'
#property indicator_width2  1
#property indicator_label3  "Bullish patterns (bit mask)"
#property indicator_type3   DRAW_NONE
#property indicator_label4  "Bearish patterns (bit mask)"
#property indicator_type4   DRAW_NONE

#include "Cdl.mqh"

input group "Patterns"
input bool   InpEngulfing = true;    // Engulfing (bullish, bearish)
input bool   InpHammer    = true;    // Hammer and Hanging Man
input bool   InpInverted  = true;    // Inverted Hammer and Shooting Star
input bool   InpDoji      = true;    // Doji
input bool   InpStars     = true;    // Morning Star and Evening Star
input bool   InpHarami    = true;    // Harami (bullish, bearish)
input bool   InpPiercing  = true;    // Piercing Line and Dark Cloud Cover
input group "Display"
input int    InpHistory   = 2000;    // Closed bars to scan on the chart (100-20000)
input bool   InpLabels    = true;    // Short labels
input color  InpColBull   = C'38,166,98';   // Bullish colour
input color  InpColBear   = C'226,74,70';   // Bearish colour
input int    InpFontSize  = 7;       // Label font size

#include "SignalAlerts.mqh"

const string PRODUCT="Candlestick Signal Alerts";
const string PREFIX ="CDP_";

double   g_bull[],g_bear[],g_mbull[],g_mbear[];
bool     g_use[CD_NP];
CDState  g_s;
int      g_start=0,g_fed=0;
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
   if(!any || InpHistory<100 || InpHistory>20000 || InpFontSize<6 || InpFontSize>14)
     {
      Print(PRODUCT,": switch on at least one pattern; history 100-20000; font 6-14");
      return(INIT_PARAMETERS_INCORRECT);
     }
   SetIndexBuffer(0,g_bull,INDICATOR_DATA);
   SetIndexBuffer(1,g_bear,INDICATOR_DATA);
   SetIndexBuffer(2,g_mbull,INDICATOR_DATA);
   SetIndexBuffer(3,g_mbear,INDICATOR_DATA);
   PlotIndexSetInteger(0,PLOT_ARROW,233);
   PlotIndexSetInteger(1,PLOT_ARROW,234);
   PlotIndexSetInteger(0,PLOT_ARROW_SHIFT,26);
   PlotIndexSetInteger(1,PLOT_ARROW_SHIFT,-26);
   PlotIndexSetInteger(0,PLOT_LINE_COLOR,InpColBull);
   PlotIndexSetInteger(1,PLOT_LINE_COLOR,InpColBear);
   for(int i=0; i<4; i++)
      PlotIndexSetDouble(i,PLOT_EMPTY_VALUE,EMPTY_VALUE);
   IndicatorSetString(INDICATOR_SHORTNAME,PRODUCT);
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
   ArraySetAsSeries(time,false);
   ArraySetAsSeries(open,false);
   ArraySetAsSeries(high,false);
   ArraySetAsSeries(low,false);
   ArraySetAsSeries(close,false);
   if(prev_calculated==0)
     {
      Clear();
      g_start=MathMax(0,rates_total-1-InpHistory);
      ArrayInitialize(g_bull,EMPTY_VALUE); ArrayInitialize(g_bear,EMPTY_VALUE);
      ArrayInitialize(g_mbull,EMPTY_VALUE); ArrayInitialize(g_mbear,EMPTY_VALUE);
     }
   else
      for(int i=MathMax(prev_calculated-1,0); i<rates_total; i++)
         if(i>=g_start+g_fed)
           { g_bull[i]=EMPTY_VALUE; g_bear[i]=EMPTY_VALUE; g_mbull[i]=EMPTY_VALUE; g_mbear[i]=EMPTY_VALUE; }
   bool live=(prev_calculated>0);
   string events="";
   for(int i=g_start+g_fed; i<=rates_total-2; i++)
     {
      bool ev=CDFeed(g_s,g_use,open[i],high[i],low[i],close[i]);
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
      string id=PREFIX+IntegerToString((long)time[i]);
      if(mb>0)
        {
         g_bull[i]=low[i]; g_mbull[i]=mb;
         if(InpLabels)
            Label(id+"b",time[i],low[i],lb,CDNames(g_s,mb,1),InpColBull,true);
        }
      if(ms>0)
        {
         g_bear[i]=high[i]; g_mbear[i]=ms;
         if(InpLabels)
            Label(id+"s",time[i],high[i],ls,CDNames(g_s,ms,-1),InpColBear,false);
        }
      if(live && i==rates_total-2 && time[i]>g_alert_bar)
        {
         g_alert_bar=time[i];
         string tf=StringSubstr(EnumToString((ENUM_TIMEFRAMES)_Period),7);
         if(mb>0)
            events=StringFormat("Bullish %s on %s %s",CDNames(g_s,mb,1),_Symbol,tf);
         if(ms>0)
            events+=(events=="" ? "" : "; ")+StringFormat("Bearish %s on %s %s",CDNames(g_s,ms,-1),_Symbol,tf);
        }
     }
   if(events!="")
      SignalAlertMessage(PRODUCT,events);
   return(rates_total);
  }
//+------------------------------------------------------------------+
