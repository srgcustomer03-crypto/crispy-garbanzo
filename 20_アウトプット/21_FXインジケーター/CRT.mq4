//+------------------------------------------------------------------+
//|                                                          CRT.mq4 |
//|                                        Copyright 2026, Antigravity |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1  clrGold
#property indicator_color2  clrDarkViolet

//--- input parameters
input int      LookbackBars       = 1;   // Bars to check for Sweep (1=Prev Candle)
input bool     UseAlerts          = true;  // Enable Alerts

//--- indicator buffers
double         BullCRT[];
double         BearCRT[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,BullCRT);
   SetIndexStyle(0,DRAW_ARROW);
   SetIndexArrow(0,233); // Up Arrow
   SetIndexLabel(0,"Bullish CRT");
   
   SetIndexBuffer(1,BearCRT);
   SetIndexStyle(1,DRAW_ARROW);
   SetIndexArrow(1,234); // Down Arrow
   SetIndexLabel(1,"Bearish CRT");
   
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   int limit = rates_total - prev_calculated;
   if(prev_calculated > 0) limit++;
   
   for(int i = limit; i >= 1; i--) { // Start from 1 to have i+1
      if(i >= rates_total - 2) continue; // Safety
      
      // LOGIC: Liquidity Sweep + Denial (Engulfing)
      
      // 1. Definition of "Prev Candle" (The one being swept)
      // Usually i+1.
      
      // --- BEARISH CRT (Short) ---
      // Pattern: Price goes ABOVE High[i+1], then Closes BELOW Open[i+1] (or Low[i+1])
      // And must remain Bearish Candle.
      
      bool isBearishCandle = (close[i] < open[i]);
      bool sweptHigh       = (high[i] > high[i+1]); // Updated High
      
      // "Denial" / Engulfing Logic:
      // Must engulf the previous BODY at least?
      // Logic A: Open[i] < Close[i+1] (Gap down) - Rare
      // Logic B: Close[i] < Open[i+1] (Close below prev Open) - Standard Engulfing
      
      bool engulfsBody     = (close[i] < open[i+1] && open[i] > close[i+1]); // Standard Bear Engulf
      // Plus Alpha: The SWEEP happened.
      
      if(isBearishCandle && sweptHigh && engulfsBody) {
          BearCRT[i] = high[i] + 10 * Point;
          if(i == 0 && UseAlerts && time[0] != time[1]) {
              // PlaySound("alert.wav");
          }
      }
      
      // --- BULLISH CRT (Long) ---
      // Pattern: Price goes BELOW Low[i+1], then Closes ABOVE Open[i+1]
      
      bool isBullishCandle = (close[i] > open[i]);
      bool sweptLow        = (low[i] < low[i+1]); // Updated Low
      
      bool engulfsBodyBull = (close[i] > open[i+1] && open[i] < close[i+1]); // Standard Bull Engulf
      
      if(isBullishCandle && sweptLow && engulfsBodyBull) {
          BullCRT[i] = low[i] - 10 * Point;
      }
   }
   
   return(rates_total);
  }
//+------------------------------------------------------------------+
