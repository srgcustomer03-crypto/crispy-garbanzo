//+------------------------------------------------------------------+
//|                                                   Zero_Magic.mq4 |
//|                                        Copyright 2026, Antigravity |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#property version   "2.01"
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_color1  clrDodgerBlue
#property indicator_color2  clrRed

//--- input parameters
input double   DetectionRangePips = 5.0;  // Detection Range from Line (Pips)
input double   ManualGridStep     = 10.0; // Grid Step (Default 10.0 for Gold)
input color    LineColor          = clrSilver; // Zero Line Color
input color    BullOBColor        = clrSeaGreen; // Bullish OB Color (Green)
input color    BearOBColor        = clrRed;    // Bearish OB Color (Red)
input int      HistoryBars        = 500;       // Bars to scan (Reduce for performance)
input int      MaxActiveOBs       = 10;        // Max Active OBs to display
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
    string name;
};

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   ObjectsDeleteAll(0, "ZM_"); // Clean up all ZM objects
   
   SetIndexBuffer(0,BullBuffer);
   SetIndexStyle(0,DRAW_ARROW);
   SetIndexArrow(0,233); // Up Arrow
   SetIndexLabel(0, "Bull Engulfing");
   
   SetIndexBuffer(1,BearBuffer);
   SetIndexStyle(1,DRAW_ARROW);
   SetIndexArrow(1,234); // Down Arrow
   SetIndexLabel(1, "Bear Engulfing");
   
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
   // Refresh Strategy on new Bar or Init
   // Since managing arrays of objects in OnCalculate is complex, 
   // we will do a full scan of the last 'HistoryBars' ONLY when a new bar arrives 
   // to ensure we track mitigation correctly from past to present.
   
   if(prev_calculated == rates_total) return(rates_total); // No new data, skip (lightweight)
   
   // Clean up objects to redraw accurate state
   ObjectsDeleteAll(0, "ZM_OB_"); 
   
   int limit = HistoryBars;
   if(limit > rates_total - 20) limit = rates_total - 20;

   // Determine Step
   double step = ManualGridStep; 
   if(step == 0.0) {
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
   
   // List to hold potential OBs
   OrderBlock obs[];
   ArrayResize(obs, 0);

   // 1. Scan History for OB creation (Oldest to Newest)
   // We scan from 'limit' down to 1. 
   // But to track mitigation, we should scan forward? 
   // Actually, simpler: Scan backward to find OBs, then check validity?
   // Best: Scan Forward from (rates_total - limit) to 0.
   
   int start = rates_total - limit;
   if(start < 0) start = 0;
   
   for(int i = start; i < rates_total - 2; i++) {
        // Bar i is current in this loop. We look at FVG formed partially by i.
        // FVG pattern: Candle A(i), B(i+1), C(i+2).
        // Wait, array index: 0 is newest. 
        // So iterating i from Old (Big Index) to New (Small Index). 
        // Let's stick to standard: i from limit down to 0.
   }
   
   // Let's use standard reverse loop: i = limit down to 0.
   // But we need to maintain a list of Active OBs and verify mitigation at each step.
   // This is O(N*M). With MaxActiveOBs=10, it's fast.
   
   OrderBlock activeList[];
   ArrayResize(activeList, 0);
   
   for(int i = limit; i >= 1; i--) {
       // A. Check Mitigation of existing Active OBs by Current Candle i
       int total = ArraySize(activeList);
       for(int k = total - 1; k >= 0; k--) {
           bool broken = false;
           // If Bull OB, and Price drops below bottom? Or just touches?
           // "Mitigation" means price touches the zone to pick up orders. 
           // Usually, valid OB is one that HAS NOT been touched yet?
           // Or one that IS touched and bounces?
           // Strategy: "Fresh" OBs are best. Once touched/pierced substantially, remove.
           // User manual implies: Zone is good until broken.
           
           if(activeList[k].isBull) {
               // If price closes below bottom, invalidate
               if(close[i] < activeList[k].bottom) activeList[k].active = false;
               // If price touches it? It might be a bounce. Keep it until broken?
               // Let's simplify: Invalidate if Close < Bottom.
           } else {
               // Bear OB
               if(close[i] > activeList[k].top) activeList[k].active = false;
           }
           
           if(!activeList[k].active) {
               // Remove from list (inefficient array strict, but OK for small size)
               // Just mark inactive, we filter later
           }
       }
       
       // B. Detect NEW OB at this bar?
       // FVG Check: Candle i (Right), i+1 (Mid), i+2 (Left)
       // Standard MQL4 indexing: i is *later* time than i+1.
       // So gap is between i (Low/High) and i+2 (High/Low).
       
       // Bullish FVG: Low[i] > High[i+2]
       if(low[i] > high[i+2]) {
           // OB is i+2 (or i+3). We take i+2.
           // It must be Bearish (Red) to be a Bullish OB (Sell to Buy).
           if(open[i+2] > close[i+2]) {
               OrderBlock newOB;
               newOB.top = high[i+2];
               newOB.bottom = low[i+2];
               newOB.time = time[i+2];
               newOB.isBull = true;
               newOB.active = true;
               newOB.name = "ZM_OB_" + IntegerToString(time[i+2]);
               
               // Add to list
               int s = ArraySize(activeList);
               ArrayResize(activeList, s + 1);
               activeList[s] = newOB;
               
               // Limit total active
               if(s + 1 > MaxActiveOBs) {
                   // Remove oldest (Index 0)
                   for(int m = 0; m < s; m++) activeList[m] = activeList[m+1];
                   ArrayResize(activeList, s);
               }
           }
       }
       
       // Bearish FVG: High[i] < Low[i+2]
       if(high[i] < low[i+2]) {
           // OB is i+2, Bullish (Buy to Sell)
           if(close[i+2] > open[i+2]) {
               OrderBlock newOB;
               newOB.top = high[i+2];
               newOB.bottom = low[i+2];
               newOB.time = time[i+2];
               newOB.isBull = false;
               newOB.active = true;
               newOB.name = "ZM_OB_" + IntegerToString(time[i+2]);
               
               int s = ArraySize(activeList);
               ArrayResize(activeList, s + 1);
               activeList[s] = newOB;
               
               if(s + 1 > MaxActiveOBs) {
                   for(int m = 0; m < s; m++) activeList[m] = activeList[m+1];
                   ArrayResize(activeList, s);
               }
           }
       }
       
       // C. Signal Logic (Engulfing)
       // Needs to be INSIDE an Active OB.
       double price = close[i];
       
       // Check if price is in ANY active OB
       bool inZone = false;
       for(int k=0; k<ArraySize(activeList); k++) {
           if(activeList[k].active) {
                // Check overlap
                if(activeList[k].isBull) {
                    if(low[i] <= activeList[k].top && high[i] >= activeList[k].bottom) inZone = true;
                } else {
                    if(high[i] >= activeList[k].bottom && low[i] <= activeList[k].top) inZone = true;
                }
           }
       }
       
       // Grid Line Logic
       double nearest = MathRound(price / step) * step;
       double diff = MathAbs(price - nearest);
       double distancePips = diff / Point;
       if(Digits == 3 || Digits == 5) distancePips /= 10; 
       bool isNearLine = (distancePips <= DetectionRangePips);
       
       if(isNearLine) { // Removed 'inZone' requirement for Signals to keep it responsive?
           // Or strictly require both? 
           // User Request: "OB + FVG" is trace. "Line" is Price.
           // Let's require BOTH for a "Perfect" signal, or just Line for now?
           // V2 Goal: Show OB. Let's keep signals based on Lines for now (v1 logic) to avoid "No Signals" issue.
           // But we DRAW the OBs so user can filter.
           
           // Bullish Engulfing
           bool prevBear = close[i+1] < open[i+1];
           bool currBull = close[i] > open[i];
           if(prevBear && currBull && close[i] >= open[i+1] && open[i] <= close[i+1]) {
               BullBuffer[i] = low[i] - 10 * Point;
               if(i == 0 && UseAlerts && Time[0] != Time[1]) {}
           }
           
           // Bearish Engulfing
           bool prevBull = close[i+1] > open[i+1];
           bool currBear = close[i] < open[i];
           if(prevBull && currBear && close[i] <= open[i+1] && open[i] >= close[i+1]) {
               BearBuffer[i] = high[i] + 10 * Point;
           }
       }
   }
   
   // Draw Active OBs from the final list
   for(int k=0; k<ArraySize(activeList); k++) {
       if(activeList[k].active) {
           DrawOB(activeList[k]);
       }
   }
     
   DrawGridLines(step, LineColor);
   
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| Draw OB Function                                                 |
//+------------------------------------------------------------------+
void DrawOB(OrderBlock &ob) {
    if(ObjectFind(0, ob.name) < 0) {
        ObjectCreate(0, ob.name, OBJ_RECTANGLE, 0, ob.time, ob.top, Time[0] + PeriodSeconds()*5, ob.bottom);
        ObjectSetInteger(0, ob.name, OBJPROP_COLOR, ob.isBull ? BullOBColor : BearOBColor);
        ObjectSetInteger(0, ob.name, OBJPROP_FILL, true); 
        ObjectSetInteger(0, ob.name, OBJPROP_BACK, true); 
        ObjectSetInteger(0, ob.name, OBJPROP_RAY_RIGHT, true); // Keep Ray for active ones
        ObjectSetInteger(0, ob.name, OBJPROP_WIDTH, 1);
    } else {
        // Update Time[0]
        // ObjectSetInteger(0, ob.name, OBJPROP_TIME2, Time[0] + PeriodSeconds()*5);
    }
}

//+------------------------------------------------------------------+
//| Draw Grid Lines Function                                         |
//+------------------------------------------------------------------+
void DrawGridLines(double step, color col) {
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double base = MathFloor(bid / step) * step;
    for(int k = -10; k <= 10; k++) { // Reduce range to clean up
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
