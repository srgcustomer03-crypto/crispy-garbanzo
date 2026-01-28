//+------------------------------------------------------------------+
//|                                              Zero_Magic_EA.mq4 |
//|                                        Copyright 2026, Antigravity |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Antigravity"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

//--- Input Parameters
input double Lots          = 0.01;
input double StopLossPips  = 20.0;
input double TakeProfitPips= 30.0;
input int    MagicNumber   = 202602;
input double DetectionRangePips = 5.0;  // Pips from Line
input double ManualGridStep     = 10.0; 
input bool   UseCRT_Logic       = true; // Use Candle Range Theory (Sweep) Logic
// Internal Logic Variables
struct OrderBlock {
    double top;
    double bottom;
    bool isBull;
    bool active;
    int timeframe; // Debug info
};

OrderBlock activeOBs[]; 
int MaxActiveOBsPerTF = 5; 

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
   if(Bars < 10) return; 

   static datetime lastBar;
   bool newBar = (Time[0] != lastBar);
   
   // --- 1. MTF OB Detection (Refresh every tick for debug visual) ---
   ArrayResize(activeOBs, 0);
   
   // Check all required TFs
   CheckOBs(PERIOD_D1);
   CheckOBs(PERIOD_H4);
   CheckOBs(PERIOD_H1);
   CheckOBs(PERIOD_M30);
   CheckOBs(PERIOD_M15);
   CheckOBs(PERIOD_M5);
   
   // --- Debug Info ---
   int i = 1; 
   string debugMsg = "Zero Magic EA v2.0 (MTF)\n";
   debugMsg += "Last Bar: " + TimeToString(Time[1], TIME_MINUTES) + "\n";
   
   // Grid Logic
   double step = ManualGridStep;
    if(step == 0.0) {
       string sym = Symbol();
       if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0) step = 10.0;
       else if(Digits == 3 || Digits == 5) step = 1.0; else step = 0.01;
   }
   double price = Close[i];
   double nearest = MathRound(price / step) * step;
   double pointVal = Point;
   double pipVal = Point;
   if(Digits==3 || Digits==5) pipVal = Point * 10;
   if(Digits==2 && (StringFind(Symbol(),"XAU")>=0 || StringFind(Symbol(),"GOLD")>=0)) pipVal = Point * 10; 

   double gapPips = MathAbs(price - nearest) / pipVal;
   bool nearLine = (gapPips <= DetectionRangePips);
   
   debugMsg += "Lines: Gap " + DoubleToString(gapPips,1) + " (Limit " + DoubleToString(DetectionRangePips,1) + ")\n";

   // Zone Match
   bool inZone = false;
   bool zoneBull = false;
   string tfList = "";
   
   for(int k=0; k<ArraySize(activeOBs); k++) {
       if(activeOBs[k].active) {
           bool overlap = false;
           if(activeOBs[k].isBull) {
               if(Low[i] <= activeOBs[k].top && High[i] >= activeOBs[k].bottom) {
                   overlap = true;
                   zoneBull = true; 
               }
           } else {
               if(High[i] >= activeOBs[k].bottom && Low[i] <= activeOBs[k].top) {
                   overlap = true;
                   zoneBull = false; 
               }
           }
           
           if(overlap) {
               inZone = true;
               tfList += TFToString(activeOBs[k].timeframe) + " ";
           }
       }
   }
   debugMsg += "In Zone: " + (inZone ? "YES (" + tfList + ")" : "No") + "\n";
   debugMsg += "Total OBs: " + IntegerToString(ArraySize(activeOBs)) + "\n";
   
   // Signal
   // Raw detection (Body only)
   bool rawBull = (Close[i] > Open[i] && Close[i+1] < Open[i+1] && Close[i] >= Open[i+1] && Open[i] <= Close[i+1]);
   bool rawBear = (Close[i] < Open[i] && Close[i+1] > Open[i+1] && Close[i] <= Open[i+1] && Open[i] >= Close[i+1]);

   bool isBullEngulf = rawBull;
   bool isBearEngulf = rawBear;
   
   // --- CRT LOGIC INTEGRATION (Enhanced) ---
   bool sweepCondition = true;
   bool allowInsideHigh = false; // Flag to relax Strict Filter if Sweep was on Prev candle
   
   if(UseCRT_Logic) {
       // A. Current Candle Sweep (Key Reversal)
       bool currSweepBull = (Low[i] < Low[i+1]);
       bool currSweepBear = (High[i] > High[i+1]);
       
       // B. Previous Candle Sweep (Trap then Reversal)
       bool prevSweepBull = (Low[i+1] < Low[i+2]);
       bool prevSweepBear = (High[i+1] > High[i+2]);
       
       // Logic: Must have swept recently (A or B)
       if(rawBull) {
           if(!currSweepBull && !prevSweepBull) sweepCondition = false;
           if(prevSweepBull) allowInsideHigh = true; // If Prev swept, Current Low[i] can be > Low[i+1]
       }
       if(rawBear) {
           if(!currSweepBear && !prevSweepBear) sweepCondition = false;
           if(prevSweepBear) allowInsideHigh = true;
       }
   }
   
   if(!sweepCondition) {
       isBullEngulf = false;
       isBearEngulf = false;
   }
   
   // Apply High/Low Filter (Strict) 
   // Relaxed if 'allowInsideHigh' is true (Previous Sweep context)
   if(isBullEngulf) {
       if(!allowInsideHigh) {
           if(High[i] < High[i+1] || Low[i] > Low[i+1]) isBullEngulf = false; 
       } else {
           // If PrevSwept, we only care about Body Engulfing (already checked in rawBull).
           // But maybe ensure it's not a tiny inside bar? 
           // Standard Engulfing rules (Open/Close) are usually sufficient for CRT.
       }
   }
   if(isBearEngulf) {
       if(!allowInsideHigh) {
            if(High[i] < High[i+1] || Low[i] > Low[i+1]) isBearEngulf = false; 
       }
   }

   
   Comment(debugMsg);

   // --- DEBUG LOGGING FOR SKIPPED ENTRIES ---
   if(rawBull || rawBear) {
       string reason = "";
       string pat = rawBull ? "Bull" : "Bear";
       
       if(UseCRT_Logic) {
           if(rawBull && !sweepCondition) reason += "[CRT Fail: No Sweep found] ";
           if(rawBear && !sweepCondition) reason += "[CRT Fail: No Sweep found] ";
       }
       
       if(rawBull && !isBullEngulf && reason == "") reason += "[Strict Filter/Weak] ";
       if(rawBear && !isBearEngulf && reason == "") reason += "[Strict Filter/Weak] ";
       
       if(!nearLine) reason += "[Line Gap: " + DoubleToString(gapPips, 1) + " > " + DoubleToString(DetectionRangePips, 1) + "] ";
       
       if(!inZone) {
           reason += "[Not in Zone] ";
       } else {
           if(rawBull && !zoneBull) reason += "[Zone Mismatch: In Bear Zone] ";
           if(rawBear && zoneBull)  reason += "[Zone Mismatch: In Bull Zone] ";
       }
       
       if(reason != "") {
            // Only print if strict filter passed OR if user wants to see everything. 
            // Let's print if it was a valid strict engulf but failed other conditions
            if(isBullEngulf || isBearEngulf) {
                Print(">> SKIPPED ", pat, " Signal at ", TimeToString(Time[i], TIME_MINUTES), ": ", reason);
            } else {
                // Determine if we should spam 'Inside Bar' logs? Maybe useful once to prove it.
                // Print(">> SKIPPED (Weak) ", pat, " at ", TimeToString(Time[i]), ": ", reason);
            }
       }
   }

   if(!newBar) return;
   lastBar = Time[0];
   
   // Final filters before entry
   if(!nearLine) return;
   if(!inZone) return;

   if(isBullEngulf && zoneBull) {
       if(OrdersTotal() == 0) { 
           Print(">>> BUY ENTRY: Zone=", tfList, " Price=", Close[1], " PrevClose=", Close[2]);
           
           // SL: Foot of Candle (Low of trigger) - 3 pips
           double slPrice = Low[i] - 30 * Point; 
           
           // TP: Manual Rule "Sakunuki" (Quick Scalp)
           // Target the NEXT Grid or Half-Grid line (whichever is closer > 3 pips)
           // e.g. if Step=10.0, target 5.0 increments.
           double tpStep = step / 2.0; 
           double nextLine = (MathFloor(Ask / tpStep) + 1.0) * tpStep;
           double tpPrice = nextLine;
           
           // Safety: If next line is very close (< 30 Point / 3 pips), skip to next
           if(MathAbs(tpPrice - Ask) < 30*Point) tpPrice += tpStep;
           
           OrderSend(Symbol(), OP_BUY, Lots, Ask, 3, slPrice, tpPrice, "Zero Magic MTF Buy", MagicNumber, 0, clrBlue);
       }
   }
   if(isBearEngulf && !zoneBull) {
       if(OrdersTotal() == 0) {
           Print(">>> SELL ENTRY: Zone=", tfList, " Price=", Close[1], " PrevClose=", Close[2]);
           
           // SL: Head of Candle (High of trigger) + 3 pips
           double slPrice = High[i] + 30 * Point; 
           
           // TP: "Sakunuki"
           double tpStep = step / 2.0;
           double nextLine = (MathCeil(Bid / tpStep) - 1.0) * tpStep;
           double tpPrice = nextLine;
           
           // Safety
           if(MathAbs(Bid - tpPrice) < 30*Point) tpPrice -= tpStep;
           
           OrderSend(Symbol(), OP_SELL, Lots, Bid, 3, slPrice, tpPrice, "Zero Magic MTF Sell", MagicNumber, 0, clrRed);
       }
   }
  }

//+------------------------------------------------------------------+
//| MTF Check Helper                                                 |
//+------------------------------------------------------------------+
void CheckOBs(int limitTF) {
    // 1. Get Bars count for that TF
    int bars = iBars(Symbol(), limitTF);
    if(bars < 10) return;
    
    // Scan last N bars of that TF
    int scan = 100; 
    if(scan > bars-5) scan = bars-5;
    
    OrderBlock tfOBs[]; 
    
    for(int i = scan; i >= 2; i--) {
        double hi = iHigh(Symbol(), limitTF, i);
        double lo = iLow(Symbol(), limitTF, i);
        double cl = iClose(Symbol(), limitTF, i);
        
        // Mitigation Check
        for(int k=ArraySize(tfOBs)-1; k>=0; k--) {
            if(tfOBs[k].isBull) {
                if(cl < tfOBs[k].bottom) tfOBs[k].active = false; 
            } else {
                if(cl > tfOBs[k].top) tfOBs[k].active = false;
            }
        }
        
        // New OB
        double lo2 = iLow(Symbol(), limitTF, i+2);
        double hi2 = iHigh(Symbol(), limitTF, i+2);
        double op2 = iOpen(Symbol(), limitTF, i+2);
        double cl2 = iClose(Symbol(), limitTF, i+2);
        
        if(lo > hi2) { // Bull FVG
            if(op2 > cl2) { // Bear OB
                addTempOB(tfOBs, hi2, lo2, true, limitTF);
            }
        }
        double hi0 = iHigh(Symbol(), limitTF, i);
        
        if(hi0 < lo2) { // Bear FVG
            if(cl2 > op2) { // Bull OB
                addTempOB(tfOBs, hi2, lo2, false, limitTF);
            }
        }
    }
    
    // Add Valid ones to Global
    for(int k=0; k<ArraySize(tfOBs); k++) {
        if(tfOBs[k].active) {
            int s = ArraySize(activeOBs);
            ArrayResize(activeOBs, s+1);
            activeOBs[s] = tfOBs[k];
        }
    }
}

void addTempOB(OrderBlock &arr[], double top, double bottom, bool bull, int tf) {
    OrderBlock newOB;
    newOB.top = top;
    newOB.bottom = bottom;
    newOB.isBull = bull;
    newOB.active = true;
    newOB.timeframe = tf;
    
    int s = ArraySize(arr);
    ArrayResize(arr, s+1);
    arr[s] = newOB;
    
    if(s+1 > MaxActiveOBsPerTF) {
        for(int m=0; m<s; m++) arr[m] = arr[m+1];
        ArrayResize(arr, s);
    }
}

string TFToString(int tf) {
    if(tf == PERIOD_D1) return "D1";
    if(tf == PERIOD_H4) return "H4";
    if(tf == PERIOD_H1) return "H1";
    if(tf == PERIOD_M30) return "M30";
    if(tf == PERIOD_M15) return "M15";
    if(tf == PERIOD_M5) return "M5";
    return "";
}
//+------------------------------------------------------------------+
