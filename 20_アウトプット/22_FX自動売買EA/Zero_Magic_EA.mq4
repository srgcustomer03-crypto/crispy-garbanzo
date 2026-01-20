//+------------------------------------------------------------------+
//|                                              Zero_Magic_EA.mq4 |
//|                                        Copyright 2026, Antigravity |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.02"
#property strict

//--- Input Parameters
input double Lots          = 0.01;
input double StopLossPips  = 20.0;
input double TakeProfitPips= 30.0;
input int    MagicNumber   = 202601;
input double DetectionRangePips = 5.0;  // Pips from Line
input double ManualGridStep     = 10.0; // Grid Step (Gold Default 10.0)

// Internal Logic Variables
struct OrderBlock {
    double top;
    double bottom;
    bool isBull;
    bool active;
};

OrderBlock activeOBs[];
int MaxActiveOBs = 10;
int HistoryBars = 200; 

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(Bars < HistoryBars + 5) return; // FIX: Ensure enough bars exist
   
   // A. Re-calculate OBs logic every tick
   static datetime lastBar;
   bool newBar = (Time[0] != lastBar);
   
   // Refresh OB List
   ArrayResize(activeOBs, 0);
   CalculateOBs();

   int i = 1; // Analyze completed bar

   // --- Debug Info on Chart ---
   string debugMsg = "Zero Magic EA v1.02 Running\n";
   debugMsg += "Last Bar: " + TimeToString(Time[1], TIME_MINUTES) + "\n";
   
   // 1. Grid Line Check
   double step = ManualGridStep;
    if(step == 0.0) {
       string sym = Symbol();
       if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0) step = 10.0;
       else if(Digits == 3 || Digits == 5) step = 1.0; 
       else step = 0.01;
   }
   
   double price = Close[i];
   double nearest = MathRound(price / step) * step;
   double diff = MathAbs(price - nearest);
   
   double pointVal = Point;
   double pipVal = Point;
   
   if(Digits==3 || Digits==5) pipVal = Point * 10;
   if(Digits==2 && (StringFind(Symbol(),"XAU")>=0 || StringFind(Symbol(),"GOLD")>=0)) pipVal = Point * 10; 

   double gapPips = diff / pipVal; // Gap in Pips
   
   bool nearLine = (gapPips <= DetectionRangePips);
   
   debugMsg += "Nearest Line: " + DoubleToString(nearest, Digits) + " (Gap: " + DoubleToString(gapPips, 1) + " pips)\n";

   // 2. Zone Check
   bool inZone = false;
   bool zoneBull = false;
   int zoneCount = 0;
   
   for(int k=0; k<ArraySize(activeOBs); k++) {
       if(activeOBs[k].active) zoneCount++;
       if(activeOBs[k].active) {
           if(activeOBs[k].isBull) {
               if(Low[i] <= activeOBs[k].top && High[i] >= activeOBs[k].bottom) {
                   inZone = true;
                   zoneBull = true;
               }
           } else {
                if(High[i] >= activeOBs[k].bottom && Low[i] <= activeOBs[k].top) {
                   inZone = true;
                   zoneBull = false; 
               }
           }
       }
   }
   debugMsg += "Active OB Zones: " + IntegerToString(zoneCount) + "\n";
   debugMsg += "In Zone? " + (inZone ? (zoneBull ? "YES (Buy Zone)" : "YES (Sell Zone)") : "No") + "\n";

   // 3. Engulfing Check
   bool isBullEngulf = (Close[i] > Open[i] && Close[i+1] < Open[i+1] && Close[i] >= Open[i+1] && Open[i] <= Close[i+1]);
   bool isBearEngulf = (Close[i] < Open[i] && Close[i+1] > Open[i+1] && Close[i] <= Open[i+1] && Open[i] >= Close[i+1]);
   
   string pat = "None";
   if(isBullEngulf) pat = "Bull Engulfing";
   if(isBearEngulf) pat = "Bear Engulfing";
   debugMsg += "Pattern: " + pat + "\n";
   
   if(nearLine && inZone && (isBullEngulf||isBearEngulf)) debugMsg += ">>> SIGNAL DETECTED! <<<\n";
   
   Comment(debugMsg); 

   // --- Trade Execution (New Bar Only) ---
   if(!newBar) return;
   lastBar = Time[0];
   
   if(!nearLine) return; // Must be near line
   if(!inZone) return;   // Must be in zone

   // Long
   if(isBullEngulf && zoneBull) {
       if(OrdersTotal() == 0) { 
           double sl = Ask - StopLossPips * pipVal;
           double tp = Ask + TakeProfitPips * pipVal;
           OrderSend(Symbol(), OP_BUY, Lots, Ask, 3, sl, tp, "Zero Magic Buy", MagicNumber, 0, clrBlue);
       }
   }
   
   // Short
   if(isBearEngulf && !zoneBull) {
       if(OrdersTotal() == 0) {
           double sl = Bid + StopLossPips * pipVal;
           double tp = Bid - TakeProfitPips * pipVal;
           OrderSend(Symbol(), OP_SELL, Lots, Bid, 3, sl, tp, "Zero Magic Sell", MagicNumber, 0, clrRed);
       }
   }
  }

//+------------------------------------------------------------------+
//| Calculate OBs helper                                             |
//+------------------------------------------------------------------+
void CalculateOBs() {
    int start = HistoryBars;
    if(start >= Bars - 5) start = Bars - 5; // FIX: Ensure not exceeding Bars

    for(int i = start; i >= 2; i--) {
        // Mitigation
        for(int k=ArraySize(activeOBs)-1; k>=0; k--) {
            if(activeOBs[k].isBull) {
                if(Close[i] < activeOBs[k].bottom) activeOBs[k].active = false;
            } else {
                if(Close[i] > activeOBs[k].top) activeOBs[k].active = false;
            }
        }
        
        // New OB - FIX: Ensure i+2 is accessing valid index. i is decreasing, so max index is 'start+2'.
        // if i=start, i+2 = start+2. 
        // We capped start at Bars-5, so start+2 = Bars-3. Safe.
        
        if(Low[i] > High[i+2]) { // Bull FVG
            if(Open[i+2] > Close[i+2]) { // Bear OB
                addOB(High[i+2], Low[i+2], true);
            }
        }
        if(High[i] < Low[i+2]) { // Bear FVG
            if(Close[i+2] > Open[i+2]) { // Bull OB
                addOB(High[i+2], Low[i+2], false);
            }
        }
    }
}

void addOB(double top, double bottom, bool bull) {
    OrderBlock newOB;
    newOB.top = top;
    newOB.bottom = bottom;
    newOB.isBull = bull;
    newOB.active = true;
    
    int s = ArraySize(activeOBs);
    ArrayResize(activeOBs, s+1);
    activeOBs[s] = newOB;
    
    if(s+1 > MaxActiveOBs) {
        // Shift left
        for(int m=0; m<s; m++) {
            activeOBs[m] = activeOBs[m+1];
        }
        // Resize down
        ArrayResize(activeOBs, s);
    }
}
//+------------------------------------------------------------------+
