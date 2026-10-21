//+------------------------------------------------------------------+
//|                                                  CandlesDump.mq4 |
//|                                      Copyright 2026, Allan Niñal |
//|                                  https://www.allanninal.dev/mql5 |
//+------------------------------------------------------------------+
//| Test EA (not shipped): dumps the MT4 Candlestick Signal Alerts   |
//| buffers and checks repainting in the Strategy Tester (Dump4.mqh).|
//+------------------------------------------------------------------+
// SPDX-License-Identifier: LicenseRef-PolyForm-Noncommercial-1.0.0 (see LICENSE)
#property strict

#define DUMP4_BUFFERS "0,1,2,3"
#define DUMP4_PROBE   "0,1"
#define DUMP4_LIVE                     // the indicator scans only its last InpHistory bars

input bool InpDoji    = true;
input int  InpHistory = 2000;

double IndValue(const int buf,const int shift)
  {
   return(iCustom(NULL,0,"CandlestickSignalAlerts\\CandlestickSignalAlerts",true,true,true,InpDoji,true,true,true,InpHistory,false,
                  C'38,166,98',C'226,74,70',7,0.5,false,false,"alert.wav",false,false,buf,shift));
  }

#include <IndTest4/Dump4.mqh>
//+------------------------------------------------------------------+
