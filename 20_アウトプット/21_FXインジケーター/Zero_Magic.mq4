//+------------------------------------------------------------------+
//|                                                   Zero_Magic.mq4 |
//|                                        Copyright 2026, Antigravity |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1  clrDodgerBlue
#property indicator_color2  clrRed
//--- input parameters
input double   DetectionRangePips = 5.0;  // Detection Range from 0.000 (Pips)
input color    LineColor          = clrSilver; // 0.000 Line Color
input int      HistoryBars        = 1000;      // Days to process (bars)
input bool     UseAlerts          = true;      // Enable Alerts

//--- indicator buffers
double         BullBuffer[];
double         BearBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- indicator buffers mapping
   SetIndexBuffer(0,BullBuffer);
   SetIndexStyle(0,DRAW_ARROW);
   SetIndexArrow(0,233); // Up Arrow
   
   SetIndexBuffer(1,BearBuffer);
   SetIndexStyle(1,DRAW_ARROW);
   SetIndexArrow(1,234); // Down Arrow
   
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
   if(limit > HistoryBars) limit = HistoryBars;
   
   // --- Main Loop
   for(int i = limit; i >= 1; i--)
     {
      // 1. Identify Nearest 0.000 Level
      double price = close[i];
      double nearest000 = MathRound(price * 1000) / 1000.0;
      
      // Calculate distance in pips
      double distance = MathAbs(price - nearest000) / Point;
      if(Digits == 3 || Digits == 5) distance /= 10; // Adjust for JPY pairs (digits=3) or 5-digit brokers
      
      // 2. Draw Line (Object) - Optimized to not redraw every tick
      string lineName = "ZM_Line_" + IntegerToString(Time[i]);
      if(ObjectFind(0, lineName) < 0) {
          // Only draw if we haven't already nearby
          // Simple logic: Draw lines at fixed intervals? 
          // For now, let's just check if we are 'near' a line and maintain lines there?
          // Actually, drawing ALL 0.000 lines is better done by loop.
          // Let's stick to SIGNAL logic here first.
      }
      
      // We will draw lines dynamically in a separate loop or just 'visualize' the concept by signals first.
      // To properly draw horizontal lines at x.000, we should use objects.
      
      // 3. Check for Engulfing Pattern
      bool isNear = (distance <= DetectionRangePips);
      
      if(isNear) {
          // Bullish Engulfing
          // Prev: Bearish, Curr: Bullish
          // Body(Curr) covers Body(Prev)
          bool prevBear = close[i+1] < open[i+1];
          bool currBull = close[i] > open[i];
          
          if(prevBear && currBull) {
              if(close[i] >= open[i+1] && open[i] <= close[i+1]) {
                  BullBuffer[i] = low[i] - 10 * Point;
                  if(i == 1 && UseAlerts && Time[0] != Time[1]) { // Alert on close of previous bar
                      // Simple alert logic for now, refining later
                  }
              }
          }
          
          // Bearish Engulfing
          bool prevBull = close[i+1] > open[i+1];
          bool currBear = close[i] < open[i];
          
          if(prevBull && currBear) {
              if(close[i] <= open[i+1] && open[i] >= close[i+1]) {
                  BearBuffer[i] = high[i] + 10 * Point;
              }
          }
      }
     }
     
   // --- Draw Horizontal Lines Management (Simple Version)
   // Delete old lines to prevent clutter or manage smarter?
   // For V1, let's keep it simple: Show arrows. 
   // Users often have grid indicators. But 'Zero Magic' needs lines.
   // Let's add a few lines near current price.
   
   double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
   double centerLine = MathRound(bid * 1000) / 1000.0;
   
   // Draw current, +1, -1 lines (3 lines total)
   DrawLine("ZM_Line_Center", centerLine, LineColor);
   DrawLine("ZM_Line_Upper", centerLine + 0.001, LineColor); // +10 pips? No, x.000 is every 100 pips usually or 10 pips?
   // Request said "0.000". Usually this means 1.12000, 1.13000 (1000 pips or 100 pips?)
   // "3304.000" in log implies full integer levels or significant levels.
   // Standard FX "000" usually means 100 pips (Big Figure).
   // But 0.000 format suggests 3 decimal places.
   // Let's assume 100 pips (0.010 interval) for standard pairs, or 1.000 for JPY?
   // "3304.000" implies a raw value.
   // Let's try to infer from "Round Numbers".
   // Convention: "00" or "000" usually means the "Big Figures".
   // I will use 0.01 (100 pips) steps for now, as that's standard support/resistance.
   
   DrawLine("ZM_Line_Up1", centerLine + 0.010, LineColor);
   DrawLine("ZM_Line_Dn1", centerLine - 0.010, LineColor);
   
   return(rates_total);
  }
  
void DrawLine(string name, double price, color col) {
    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, col);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
    } else {
        ObjectMove(0, name, 0, 0, price);
    }
}
//+------------------------------------------------------------------+
