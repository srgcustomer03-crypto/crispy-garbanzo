//+------------------------------------------------------------------+
//|                                              Zero_Magic_EA.mq4 |
//|                                        Copyright 2026, Antigravity |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#property version   "1.01"
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
   if(Bars < HistoryBars) return;
   
   // A. Re-calculate OBs logic every tick (for verification visuals)
   // But only Trade on New Bar
   static datetime lastBar;
   bool newBar = (Time[0] != lastBar);
   
   // Refresh OB List
   ArrayResize(activeOBs, 0);
   CalculateOBs();

   int i = 1; // Analyze completed bar

   // --- Debug Info on Chart ---
   string debugMsg = "Zero Magic EA Running\n";
   debugMsg += "Last Bar Time: " + TimeToString(Time[1], TIME_MINUTES) + "\n";
   
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
   
   // FIX: Pip Calculation
   // Gold (Digits=2): 100 pips = $10.0 -> 1 pip = $0.10 (10 Points)
   // Standard 5/3 digits: 1 pip = 10 Points
   double pointVal = Point;
   double pipVal = Point;
   
   if(Digits==3 || Digits==5) pipVal = Point * 10;
   if(Digits==2 && (StringFind(Symbol(),"XAU")>=0 || StringFind(Symbol(),"GOLD")>=0)) pipVal = Point * 10; 

   double gapPips = diff / pipVal; // Gap in Pips
   
   bool nearLine = (gapPips <= DetectionRangePips);
   
   debugMsg += "Nearest Line: " + DoubleToString(nearest, Digits) + " (Gap: " + DoubleToString(gapPips, 1) + " pips)\n";
   debugMsg += "Near Line Condition: " + (nearLine ? "OK" : "Too Far") + "\n";

   // 2. Zone Check
   bool inZone = false;
   bool zoneBull = false;
   int zoneCount = 0;
   
   // Debug OBs
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
   debugMsg += "Active OBs: " + IntegerToString(zoneCount) + "\n";
   debugMsg += "In Zone Condition: " + (inZone ? (zoneBull ? "YES (Bull)" : "YES (Bear)") : "No") + "\n";

   // 3. Engulfing Check
   bool isBullEngulf = (Close[i] > Open[i] && Close[i+1] < Open[i+1] && Close[i] >= Open[i+1] && Open[i] <= Close[i+1]);
   bool isBearEngulf = (Close[i] < Open[i] && Close[i+1] > Open[i+1] && Close[i] <= Open[i+1] && Open[i] >= Close[i+1]);
   
   debugMsg += "Engulfing: " + (isBullEngulf ? "Bull" : (isBearEngulf ? "Bear" : "None")) + "\n";
   
   Comment(debugMsg); // Show on Chart

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
    for(int i = HistoryBars; i >= 2; i--) {
        // Mitigation
        for(int k=ArraySize(activeOBs)-1; k>=0; k--) {
            if(activeOBs[k].isBull) {
                if(Close[i] < activeOBs[k].bottom) activeOBs[k].active = false;
            } else {
                if(Close[i] > activeOBs[k].top) activeOBs[k].active = false;
            }
        }
        // New OB
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
        for(int m=0; m<s; m++) activeOBs[m] = activeOBs[m+1];
        ArrayResize(activeOBs, s);
    }
}
//+------------------------------------------------------------------+
