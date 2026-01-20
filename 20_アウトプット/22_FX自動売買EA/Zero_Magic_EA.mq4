//+------------------------------------------------------------------+
//|                                              Zero_Magic_EA.mq4 |
//|                                        Copyright 2026, Antigravity |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//--- Input Parameters
input double Lots          = 0.01;
input double StopLossPips  = 20.0;
input double TakeProfitPips= 30.0;
input int    MagicNumber   = 202601;
input double DetectionRangePips = 5.0;  // Pips from Line
input double ManualGridStep     = 10.0; // Grid Step (Gold Default 10.0)

// Internal Logic Variables (Copied from Indicator)
struct OrderBlock {
    double top;
    double bottom;
    bool isBull;
    bool active;
};

OrderBlock activeOBs[];
int MaxActiveOBs = 10;
int HistoryBars = 200; // Lookback for EA is shorter for speed

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
   if(Bars < HistoryBars) return;
   
   // --- 1. Update Logic (Recalculate OBs) ---
   // Note: In EA, we should only check signal on Candle Close (New Bar)
   // to avoid repainting/flickering signals.
   static datetime lastBar;
   if(Time[0] == lastBar) return;
   lastBar = Time[0];
   
   // Refresh OB List
   ArrayResize(activeOBs, 0);
   CalculateOBs();

   // --- 2. Check Signal at Close of [1] ---
   int i = 1; // Analyze completed bar
   
   // A. Check Engulfing
   bool isBullEngulf = (Close[i] > Open[i] && Close[i+1] < Open[i+1] && Close[i] >= Open[i+1] && Open[i] <= Close[i+1]);
   bool isBearEngulf = (Close[i] < Open[i] && Close[i+1] > Open[i+1] && Close[i] <= Open[i+1] && Open[i] >= Close[i+1]);
   
   if(!isBullEngulf && !isBearEngulf) return;

   // B. Check Grid Line Overlap
   double step = ManualGridStep;
    if(step == 0.0) {
       string sym = Symbol();
       if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0) step = 10.0;
       else if(Digits == 3 || Digits == 5) {
           if(Close[0] > 50.0) step = 1.0; else step = 0.01;
       } else {
           if(Close[0] > 50.0) step = 1.0; else step = 0.01;
       }
   }
   
   double price = Close[i];
   double nearest = MathRound(price / step) * step;
   double diff = MathAbs(price - nearest);
   double gap = diff / Point;
   if(Digits==3 || Digits==5) gap /= 10;
   
   bool nearLine = (gap <= DetectionRangePips);
   if(!nearLine) return; // Must be near line

   // C. Check OB Zone Overlap (Crucial for Strategy)
   bool inZone = false;
   bool zoneBull = false;
   
   for(int k=0; k<ArraySize(activeOBs); k++) {
       if(activeOBs[k].active) {
           if(activeOBs[k].isBull) {
               // Bull Zone: Price Low matches Zone Top? 
               // Loosely: If candle body is inside or touching?
               if(Low[i] <= activeOBs[k].top && High[i] >= activeOBs[k].bottom) {
                   inZone = true;
                   zoneBull = true;
               }
           } else {
               // Bear Zone
                if(High[i] >= activeOBs[k].bottom && Low[i] <= activeOBs[k].top) {
                   inZone = true;
                   zoneBull = false; // Bear
               }
           }
       }
   }
   
   if(!inZone) return; // No OB Trace -> No Trade

   // --- 3. Execute Trade ---
   
   // Long Entry
   if(isBullEngulf && zoneBull) {
       // Filter: Don't trade if already have pos?
       if(OrdersTotal() == 0) { // Simple 1 pos limit
           double sl = Ask - StopLossPips * Point * (Digits==3||Digits==5?10:1);
           double tp = Ask + TakeProfitPips * Point * (Digits==3||Digits==5?10:1);
           OrderSend(Symbol(), OP_BUY, Lots, Ask, 3, sl, tp, "Zero Magic Buy", MagicNumber, 0, clrBlue);
       }
   }
   
   // Short Entry
   if(isBearEngulf && !zoneBull) {
       if(OrdersTotal() == 0) {
           double sl = Bid + StopLossPips * Point * (Digits==3||Digits==5?10:1);
           double tp = Bid - TakeProfitPips * Point * (Digits==3||Digits==5?10:1);
           OrderSend(Symbol(), OP_SELL, Lots, Bid, 3, sl, tp, "Zero Magic Sell", MagicNumber, 0, clrRed);
       }
   }
  }

//+------------------------------------------------------------------+
//| Calculate OBs helper                                             |
//+------------------------------------------------------------------+
void CalculateOBs() {
    // Mini Logic of Indicator
    for(int i = HistoryBars; i >= 2; i--) {
        // Mitigation Check
        for(int k=ArraySize(activeOBs)-1; k>=0; k--) {
            if(activeOBs[k].isBull) {
                if(Close[i] < activeOBs[k].bottom) activeOBs[k].active = false;
            } else {
                if(Close[i] > activeOBs[k].top) activeOBs[k].active = false;
            }
        }
        
        // New OB Check
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
    
    // Limit
    if(s+1 > MaxActiveOBs) {
        for(int m=0; m<s; m++) activeOBs[m] = activeOBs[m+1];
        ArrayResize(activeOBs, s);
    }
}
//+------------------------------------------------------------------+
