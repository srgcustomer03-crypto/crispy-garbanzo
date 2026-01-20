//+------------------------------------------------------------------+
//|                                                   Zero_Magic.mq4 |
//|                                        Copyright 2026, Antigravity |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.01"
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

   // 1. Determine Step Size for "0.000" (Round Numbers)
   // Standard FX (EURUSD, GBPUSD) -> 0.01 (100 pips) implies 1.1200, 1.1300
   // JPY Pairs (USDJPY) -> 1.0 (100 pips) implies 145.00, 146.00
   double step = 0.01;
   if(Digits == 3 || Digits == 2) step = 1.0; 

   // --- Signal Loop
   for(int i = limit; i >= 1; i--)
     {
      double price = close[i];
      // Find nearest Round Number
      double nearest000 = MathRound(price / step) * step;
      
      // Calculate distance in pips
      double distance = MathAbs(price - nearest000) / Point;
      // Adjust pips for 3/5 digit brokers
      if(Digits == 3 || Digits == 5) distance /= 10; 
      
      bool isNear = (distance <= DetectionRangePips);
      
      if(isNear) {
          // Bullish Engulfing
          bool prevBear = close[i+1] < open[i+1];
          bool currBull = close[i] > open[i];
          
          if(prevBear && currBull) {
              if(close[i] >= open[i+1] && open[i] <= close[i+1]) {
                  BullBuffer[i] = low[i] - 10 * Point;
                  if(i == 0 && UseAlerts && Time[0] != Time[1]) {
                     // Realtime alert logic here
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
     
   // --- Draw Static Horizontal Lines
   DrawGridLines(step, LineColor);
   
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Draw Grid Lines Function                                         |
//+------------------------------------------------------------------+
void DrawGridLines(double step, color col) {
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    
    // Find a base level near price
    double base = MathFloor(bid / step) * step;
    
    // Draw 10 lines above and 10 lines below
    for(int k = -10; k <= 10; k++) {
        double level = base + (k * step);
        // Normalize double to avoid weird float names
        level = NormalizeDouble(level, Digits);
        
        string name = "ZM_Line_" + DoubleToString(level, Digits);
        
        if(ObjectFind(0, name) < 0) {
            ObjectCreate(0, name, OBJ_HLINE, 0, 0, level);
            ObjectSetInteger(0, name, OBJPROP_COLOR, col);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true); // Hide from object list if preferred
        }
    }
    
    // Optional: Cleanup output objects that are too far? 
    // For now, allow accumulation or user can clear objects. 
    // To be cleaner, we could delete objects not in range, but that's expensive.
}
//+------------------------------------------------------------------+
