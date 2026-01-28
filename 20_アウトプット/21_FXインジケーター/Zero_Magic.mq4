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

   // 2. MTF OB Detection Logic (User Request: Exclude M1, show M5+ with labels)
   // Define TFs to scan
   int tfs[] = {PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1};
   
   // We will execute this heavy scan only on new bar to save performance
   static datetime lastScan;
   bool fullScan = (time[0] != lastScan);
   if(fullScan) lastScan = time[0];
   
   // Always redraw active objects? No, redraw on full scan.
   // To keep it simple for this fix: Just run the loop if fullScan.
   // But we need to keep objects alive.
   
   if(fullScan) {
       ObjectsDeleteAll(0, "ZM_OB_"); 
       int obCount = 0;
       
       for(int t=0; t<ArraySize(tfs); t++) {
           int tf = tfs[t];
           
           int bars = iBars(Symbol(), tf);
           int limitScan = 200; 
           if(limitScan > bars-5) limitScan = bars-5;
           
           OrderBlock tfOBs[];
           
           // Calculate OBs for this TF
           for(int i = limitScan; i >= 2; i--) {
               double hi = iHigh(Symbol(), tf, i);
               double lo = iLow(Symbol(), tf, i);
               double cl = iClose(Symbol(), tf, i);
               
               // Mitigation
               for(int k=ArraySize(tfOBs)-1; k>=0; k--) {
                   if(tfOBs[k].isBull) {
                        if(cl < tfOBs[k].bottom) tfOBs[k].active = false;
                   } else {
                        if(cl > tfOBs[k].top) tfOBs[k].active = false;
                   }
               }
               
               // New OB Detection
               double hi2 = iHigh(Symbol(), tf, i+2);
               double lo2 = iLow(Symbol(), tf, i+2);
               double op2 = iOpen(Symbol(), tf, i+2);
               double cl2 = iClose(Symbol(), tf, i+2);
               
               if(lo > hi2) { // Bull FVG
                   if(op2 > cl2) { // Bear Candle -> Bull OB
                       addOB(tfOBs, hi2, lo2, true, iTime(Symbol(), tf, i+2));
                   }
               }
               if(hi < lo2) { // Bear FVG
                   if(cl2 > op2) { // Bull Candle -> Bear OB
                       addOB(tfOBs, hi2, lo2, false, iTime(Symbol(), tf, i+2));
                   }
               }
           }
           
           // Draw Active Ones
           for(int k=0; k<ArraySize(tfOBs); k++) {
               if(tfOBs[k].active) {
                    string baseName = "ZM_OB_" + TFString(tf) + "_" + IntegerToString(obCount++);
                    color col = tfOBs[k].isBull ? BullOBColor : BearOBColor;
                    
                    // 1. Zone Rectangle
                    ObjectCreate(0, baseName, OBJ_RECTANGLE, 0, tfOBs[k].time, tfOBs[k].top, time[0], tfOBs[k].bottom);
                    ObjectSetInteger(0, baseName, OBJPROP_COLOR, col);
                    ObjectSetInteger(0, baseName, OBJPROP_FILL, true); 
                    ObjectSetInteger(0, baseName, OBJPROP_BACK, true); 
                    ObjectSetInteger(0, baseName, OBJPROP_WIDTH, 1); 
                    ObjectSetInteger(0, baseName, OBJPROP_RAY_RIGHT, true); // FIX: Extend infinite right
                    
                    // 2. Text Label (Enhanced Visibility)
                    string labelName = baseName + "_TXT";
                    ObjectCreate(0, labelName, OBJ_TEXT, 0, time[0], tfOBs[k].top);
                    ObjectSetString(0, labelName, OBJPROP_TEXT, TFString(tf) + " "); 
                    ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
                    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
                    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER); // Place inside chart left of price line
               }
           }
       }
   }
   
   // --- C. Signal Logic (Per timeframe or Current only?) ---
   // Signals (Arrows) should probably remain on CURRENT timeframe logic for now (M1 entry trigger)
   // But we need to check if current M1 price is inside ANY drawn MTF zone.
   // Calculating that "Is Inside" logic here is complex without storing global list.
   // For Indciator visual, let's keep Arrows relative to M1 lines for now as per V1.
   
   // [KEEPING ORIGINAL SIGNAL LOGIC BELOW for Arrows]
   limit = HistoryBars; 
   if(limit > rates_total - 20) limit = rates_total - 20;
   
   for(int i = limit; i >= 1; i--) {
       // ... existing signal logic ...
       double price = close[i];
       double nearest = MathRound(price / step) * step;
       double diff = MathAbs(price - nearest);
       
       double pVal = Point; 
       if(Digits==3||Digits==5) pVal*=10;
       if(Digits==2 && (StringFind(Symbol(),"XAU")>=0)) pVal*=10;
       
       if((diff/pVal) <= DetectionRangePips) {
           // Bullish Engulfing
           bool prevBear = close[i+1] < open[i+1];
           bool currBull = close[i] > open[i];
           if(prevBear && currBull && close[i] >= open[i+1] && open[i] <= close[i+1]) {
               BullBuffer[i] = low[i] - 10 * Point;
               if(i == 0 && UseAlerts && time[0] != time[1]) {}
           }
           // Bearish Engulfing
           bool prevBull = close[i+1] > open[i+1];
           bool currBear = close[i] < open[i];
           if(prevBull && currBear && close[i] <= open[i+1] && open[i] >= close[i+1]) {
               BearBuffer[i] = high[i] + 10 * Point;
           }
       }
   }
     
   DrawGridLines(step, LineColor);
   
   return(rates_total);
  }

//+------------------------------------------------------------------+
//| addOB Helper (MTF)                                               |
//+------------------------------------------------------------------+
void addOB(OrderBlock &arr[], double top, double bottom, bool bull, datetime time) {
    OrderBlock newOB;
    newOB.top = top;
    newOB.bottom = bottom;
    newOB.time = time; 
    newOB.isBull = bull;
    newOB.active = true;
    int s = ArraySize(arr);
    ArrayResize(arr, s+1);
    arr[s] = newOB;
}

string TFString(int tf) {
    if(tf==PERIOD_M1) return "M1";
    if(tf==PERIOD_M5) return "M5";
    if(tf==PERIOD_M15) return "M15";
    if(tf==PERIOD_M30) return "M30";
    if(tf==PERIOD_H1) return "H1";
    if(tf==PERIOD_H4) return "H4";
    if(tf==PERIOD_D1) return "D1";
    return "";
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
