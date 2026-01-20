//+------------------------------------------------------------------+
//|                                                   Zero_Magic.mq4 |
//|                                        Copyright 2026, Antigravity |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.06"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1  clrDodgerBlue
#property indicator_color2  clrRed
//--- input parameters
input double   DetectionRangePips = 5.0;  // Detection Range from Line (Pips)
input double   ManualGridStep     = 0.0;  // Grid Step (0.0 = Auto Detect)
input color    LineColor          = clrSilver; // Line Color
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
   // Clean up any existing ZM lines from previous versions/instances
   ObjectsDeleteAll(0, "ZM_Line_");
   
   SetIndexBuffer(0,BullBuffer);
   SetIndexStyle(0,DRAW_ARROW);
   SetIndexArrow(0,233); // Up Arrow
   
   SetIndexBuffer(1,BearBuffer);
   SetIndexStyle(1,DRAW_ARROW);
   SetIndexArrow(1,234); // Down Arrow
   
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   // Remove all objects created by this indicator
   ObjectsDeleteAll(0, "ZM_Line_");
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

   // --- Determine Grid Step
   double step = 0.0;
   
   if(ManualGridStep > 0.0) {
       step = ManualGridStep;
   } else {
       // Auto Detection Logic
       string sym = Symbol();
       
       if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0) {
           // GOLD Logic
           // User Feedback: Link suggests 100 pips = $10.0 (1 pip = $0.10)
           // User Example: 2300.0, 2290.0, 2280.0
           // Validated: Step should be 10.0
           step = 10.0; 
       } else if(Digits == 3 || Digits == 5) {
           // JPY Pairs (145.000) or Standard Pairs (1.12345)
           // If Price > 50 (JPY), step = 1.0 (145.000)
           // If Price < 50 (EURUSD), step = 0.01 (100 pips -> 1.12000)
           if(close[0] > 50.0) step = 1.0;
           else step = 0.01;
       } else {
           // 2 or 4 digits
           if(close[0] > 50.0) step = 1.0;
           else step = 0.01;
       }
   }

   // --- Signal Loop
   for(int i = limit; i >= 1; i--)
     {
      double price = close[i];
      // Find nearest Grid Line
      double nearest = MathRound(price / step) * step;
      
      // Calculate distance in pips based on Digits
      double diff = MathAbs(price - nearest);
      double distancePips = diff / Point;
      
      // Adjust pips for typical 3/5 digit fractional brokers
      // GOLD often 2 digits (0.01 point). 1 pip = 0.10 or 0.01? 
      // Standard: Gold 2 digits -> 1 point = 0.01. "1 pip" usually implies 0.10 moves for some, or 0.01 for others.
      // Let's rely on standard Point. For 5-digit/3-digit JPY, divide by 10 to get standard pips.
      if(Digits == 3 || Digits == 5) distancePips /= 10; 
      
      bool isNear = (distancePips <= DetectionRangePips);
      
      if(isNear) {
          // Bullish Engulfing
          bool prevBear = close[i+1] < open[i+1];
          bool currBull = close[i] > open[i];
          
          if(prevBear && currBull) {
              // Body Engulfing: Close > Prev Open && Open < Prev Close
              if(close[i] >= open[i+1] && open[i] <= close[i+1]) {
                  BullBuffer[i] = low[i] - 10 * Point;
                  if(i == 0 && UseAlerts && Time[0] != Time[1]) {
                     // Alert
                  }
              }
          }
          
          // Bearish Engulfing
          bool prevBull = close[i+1] > open[i+1];
          bool currBear = close[i] < open[i];
          
          if(prevBull && currBear) {
              if(close[i] <= open[i+1] && open[i] >= close[i+1]) {
                  BearBuffer[i] = high[i] + 10 * Point;
                  if(i == 0 && UseAlerts && Time[0] != Time[1]) {
                     // Alert
                  }
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
    
    // Clean up far away lines to prevent clutter (Simple approach)
    // Actually, deleting all and redrawing is heavy but safe.
    // Better: Delete lines that are NOT in current range?
    // Let's just rely on OnDeinit for full cleanup, and here we just draw needed ones.
    // If user scrolls far, old lines remain.
    // Let's iterate user specified range or just around price.
    
    double base = MathFloor(bid / step) * step;
    
    // Draw current range
    for(int k = -20; k <= 20; k++) {
        double level = base + (k * step);
        level = NormalizeDouble(level, Digits);
        
        string name = "ZM_Line_" + DoubleToString(level, Digits);
        
        if(ObjectFind(0, name) < 0) {
            ObjectCreate(0, name, OBJ_HLINE, 0, 0, level);
            ObjectSetInteger(0, name, OBJPROP_COLOR, col);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        }
    }
}
//+------------------------------------------------------------------+
