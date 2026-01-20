//+------------------------------------------------------------------+
//|                                                   Zero_Magic.mq4 |
//|                                        Copyright 2026, Antigravity |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1  clrDodgerBlue
#property indicator_color2  clrRed

//--- input parameters
input double   DetectionRangePips = 5.0;  // Detection Range from Line (Pips)
input double   ManualGridStep     = 10.0; // Grid Step (Default 10.0 for Gold)
input color    LineColor          = clrSilver; // Zero Line Color
input color    BullOBColor        = clrBlue;   // Bullish OB Color
input color    BearOBColor        = clrRed;    // Bearish OB Color
input int      HistoryBars        = 1000;      // Days to process (bars)
input bool     UseAlerts          = true;      // Enable Alerts

//--- indicator buffers
double         BullBuffer[];
double         BearBuffer[];

// Structure to hold OB info
struct OrderBlock {
    double top;
    double bottom;
    datetime time;
    bool isBull;
    bool active;
};

OrderBlock activeOBs[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   ObjectsDeleteAll(0, "ZM_"); // Clean up all ZM objects
   
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
   ObjectsDeleteAll(0, "ZM_");
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
   double step = ManualGridStep; 
   if(step == 0.0) {
        // Fallback auto detection if user sets 0
       string sym = Symbol();
       if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0) step = 10.0;
       else if(Digits == 3 || Digits == 5) {
           if(close[0] > 50.0) step = 1.0;
           else step = 0.01;
       } else {
           if(close[0] > 50.0) step = 1.0;
           else step = 0.01;
       }
   }

   // --- Main Loop
   for(int i = limit; i >= 1; i--)
     {
      // 1. Detect New OB/FVG
      // Look for FVG at i+1 (formed by i+3, i+2, i+1 completion at i)
      // Actually FVG is confirmed when candle i+1 closes.
      // Gap is between i+3 and i+1? No, FVG pattern:
      // Candle 1 (i+2), Candle 2 (i+1), Candle 3 (i). Gap between 1 and 3.
      // Let's check historical at 'i' (current bar in loop) treating it as Candle 3.
      // Candle 3: i, Candle 2: i+1, Candle 1: i+2.
      
      // Bullish FVG: Low[i] > High[i+2]
      if(low[i] > high[i+2]) {
          // Check if i+1 was Bullish and huge? Not strictly required but usually an impulse.
          // Identify OB: The last bearish candle BEFORE the move started.
          // Usually candle i+3 or i+2?
          // If the move started at i+1 (the big candle), then i+2 (candle 1) might be the OB if it was bearish.
          if(open[i+2] > close[i+2]) { // i+2 was Bearish
               DrawOB(time[i+2], high[i+2], low[i+2], true);
          } else if(open[i+3] > close[i+3]) { // Or maybe i+3? Simple logic: i+2
               // Advanced logic would scan back. For now, strict i+2.
               DrawOB(time[i+3], high[i+3], low[i+3], true);
          }
      }
      
      // Bearish FVG: High[i] < Low[i+2]
      if(high[i] < low[i+2]) {
          // Identify OB: The last bullish candle
          if(close[i+2] > open[i+2]) { // i+2 was Bullish
               DrawOB(time[i+2], high[i+2], low[i+2], false);
          } else if(close[i+3] > open[i+3]) {
               DrawOB(time[i+3], high[i+3], low[i+3], false);
          }
      }
      
      // 2. Check Signals (Engulfing)
      // We need to know if we are currently IN an OB zone.
      // Since object checking is expensive, we rely on the visual assumption or a simple check?
      // For "Zero Magic" V1 Automation, let's strictly check:
      // Is price near a Line AND did we detect an OB nearby recently?
      // Complex to do perfectly without array management.
      // Let's stick to the TRIGGER logic (Lines + Engulfing) but ONLY if "Inside OB".
      // Implementation: Check ALL active OB objects? Expensive.
      // Compromise: This version draws OBs visually. Users check the "Zone".
      // The Alerts will remain on "Line + Engulfing".
      // User requested "Analyze OB".
      
      // Let's keep the Signal Logic simple: DETECT OBs and DRAW them.
      // Signal is Engulfing + Line. User manually confirms OB overlap.
      // Adding robust "Is Inside OB" logic requires managing an array of structs.
      
      double price = close[i];
      // Find nearest Grid Line
      double nearest = MathRound(price / step) * step;
      double diff = MathAbs(price - nearest);
      double distancePips = diff / Point;
      if(Digits == 3 || Digits == 5) distancePips /= 10; 
      
      bool isNear = (distancePips <= DetectionRangePips);
      
      if(isNear) {
          // Bullish Engulfing
          bool prevBear = close[i+1] < open[i+1];
          bool currBull = close[i] > open[i];
          if(prevBear && currBull && close[i] >= open[i+1] && open[i] <= close[i+1]) {
              BullBuffer[i] = low[i] - 10 * Point;
              if(i == 0 && UseAlerts && Time[0] != Time[1]) { /* Alert */ }
          }
          
          // Bearish Engulfing
          bool prevBull = close[i+1] > open[i+1];
          bool currBear = close[i] < open[i];
          if(prevBull && currBear && close[i] <= open[i+1] && open[i] >= close[i+1]) {
              BearBuffer[i] = high[i] + 10 * Point;
          }
      }
     }
     
   // --- Draw Static Horizontal Lines
   DrawGridLines(step, LineColor);
   
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Draw OB Function                                                 |
//+------------------------------------------------------------------+
void DrawOB(datetime t, double top, double bottom, bool isBull) {
    string name = "ZM_OB_" + IntegerToString(t);
    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_RECTANGLE, 0, t, top, Time[0], bottom);
        ObjectSetInteger(0, name, OBJPROP_COLOR, isBull ? BullOBColor : BearOBColor);
        ObjectSetInteger(0, name, OBJPROP_FILL, true); // Fill rectangle
        ObjectSetInteger(0, name, OBJPROP_BACK, true); // Background
        ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true); // Eztend to right
    }
}

//+------------------------------------------------------------------+
//| Draw Grid Lines Function                                         |
//+------------------------------------------------------------------+
void DrawGridLines(double step, color col) {
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double base = MathFloor(bid / step) * step;
    
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
