//+------------------------------------------------------------------+
//|                                               Section07_FVG.mq5 |
//|                                      SwingTrader Pro EA          |
//|                    Section 7: Fair Value Gap (FVG) Detection     |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.00"
#property description "Section 7: Fair Value Gap Detection"
#property description "Identifies price imbalances from rapid moves"
#property description "Smart Money Concept for entry timing"

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== FVG Detection Settings ==="
input int      InpFVGLookback         = 100;      // Lookback Bars for FVG Detection
input double   InpMinFVGSize          = 5.0;      // Minimum FVG Size (pips)
input double   InpMaxFVGSize          = 500.0;    // Maximum FVG Size (pips)
input int      InpMaxFVGCount         = 10;       // Maximum FVGs to Track
input bool     InpTrackMitigation     = true;     // Track FVG Mitigation
input ENUM_TIMEFRAMES InpFVGTimeframe = PERIOD_H4; // FVG Timeframe

input group "=== FVG Filtering ==="
input bool     InpRequireStrongMove   = true;     // Require Strong Move (2x ATR)
input int      InpATRPeriod           = 14;       // ATR Period for Filtering
input bool     InpFilterByTrend       = true;     // Only Show Trend-Aligned FVGs

input group "=== Visual Settings ==="
input bool     InpDrawFVG             = true;     // Draw FVG Rectangles
input color    InpBullishFVGColor     = clrDodgerBlue;  // Bullish FVG Color
input color    InpBearishFVGColor     = clrCrimson;     // Bearish FVG Color
input color    InpMitigatedColor      = clrDarkGray;    // Mitigated FVG Color
input int      InpFVGTransparency     = 70;       // FVG Transparency (0-100)

input group "=== Panel Settings ==="
input bool     InpShowPanel           = true;     // Show Info Panel
input int      InpPanelX              = 20;       // Panel X Position
input int      InpPanelY              = 30;       // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;     // Print Report to Experts Tab

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
// Note: ENUM_FVG_TYPE is defined in CommonStructures.mqh

enum ENUM_FVG_STATUS
{
   FVG_FRESH,              // Not touched yet
   FVG_PARTIALLY_FILLED,   // Price entered but didn't fill completely
   FVG_FULLY_MITIGATED     // Completely filled/mitigated
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct FVGZone
{
   ENUM_FVG_TYPE    type;
   ENUM_FVG_STATUS  status;
   double           highPrice;      // Top of FVG zone
   double           lowPrice;       // Bottom of FVG zone
   double           midPrice;       // Middle (50%) of FVG
   double           sizePips;       // Size in pips
   datetime         timeCreated;    // When FVG was created
   datetime         timeMitigated;  // When FVG was filled (if applicable)
   int              barIndex;       // Bar index when created
   string           objName;        // Chart object name
   bool             isValid;        // Is this zone still valid/tracked
};

struct FVGAnalysis
{
   FVGZone          zones[];              // Array of FVG zones
   int              bullishCount;         // Number of active bullish FVGs
   int              bearishCount;         // Number of active bearish FVGs
   int              mitigatedCount;       // Number of mitigated FVGs
   FVGZone          nearestBullish;       // Nearest bullish FVG to price
   FVGZone          nearestBearish;       // Nearest bearish FVG to price
   bool             priceInBullishFVG;    // Price currently in bullish FVG
   bool             priceInBearishFVG;    // Price currently in bearish FVG
   ENUM_TREND_BIAS  fvgBias;              // Overall bias from FVGs
   string           recommendation;
   datetime         lastUpdate;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
// Indicator handles
int               g_atrHandle;

// Buffers
double            g_highBuffer[];
double            g_lowBuffer[];
double            g_closeBuffer[];
double            g_openBuffer[];
double            g_atrBuffer[];

// Analysis result
FVGAnalysis       g_analysis;

// Panel
string            g_panelName = "FVGPanel";

// Symbol info
int               g_digits;
double            g_point;
double            g_pipValue;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get symbol info
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Calculate pip value
   if(g_digits == 3 || g_digits == 5)
      g_pipValue = g_point * 10;
   else if(g_digits == 2)  // Gold/JPY pairs
      g_pipValue = g_point;
   else
      g_pipValue = g_point;

   // Initialize arrays as series
   ArraySetAsSeries(g_highBuffer, true);
   ArraySetAsSeries(g_lowBuffer, true);
   ArraySetAsSeries(g_closeBuffer, true);
   ArraySetAsSeries(g_openBuffer, true);
   ArraySetAsSeries(g_atrBuffer, true);

   // Initialize FVG zones array
   ArrayResize(g_analysis.zones, 0);

   // Create ATR handle for filtering
   if(InpRequireStrongMove)
   {
      g_atrHandle = iATR(_Symbol, InpFVGTimeframe, InpATRPeriod);
      if(g_atrHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR handle");
         return(INIT_FAILED);
      }
   }

   // Print initialization
   PrintInitReport();

   // Create panel
   if(InpShowPanel)
      CreatePanel();

   // Run initial analysis
   AnalyzeFVG();

   // Update panel with initial values
   if(InpShowPanel)
      UpdatePanel();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release handles
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);

   // Remove FVG drawings
   DeleteAllFVGObjects();

   // Remove panel
   DeletePanel();

   Print("=================================================");
   Print("FVG Detection EA Deinitialized");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpFVGTimeframe, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      AnalyzeFVG();

      if(InpShowPanel) UpdatePanel();
   }
   else if(InpTrackMitigation)
   {
      // Check mitigation on every tick for real-time tracking
      CheckFVGMitigation();
   }
}

//+------------------------------------------------------------------+
//| Main FVG Analysis Function                                        |
//+------------------------------------------------------------------+
void AnalyzeFVG()
{
   int barsNeeded = InpFVGLookback + 5;
   int minBars = 10;

   // Copy price data
   int copied = CopyHigh(_Symbol, InpFVGTimeframe, 0, barsNeeded, g_highBuffer);
   if(copied < minBars)
   {
      Print("WARNING: Price data not ready (copied: ", copied, ")");
      return;
   }

   if(CopyLow(_Symbol, InpFVGTimeframe, 0, copied, g_lowBuffer) < minBars) return;
   if(CopyClose(_Symbol, InpFVGTimeframe, 0, copied, g_closeBuffer) < minBars) return;
   if(CopyOpen(_Symbol, InpFVGTimeframe, 0, copied, g_openBuffer) < minBars) return;

   // Copy ATR for filtering
   if(InpRequireStrongMove)
   {
      if(CopyBuffer(g_atrHandle, 0, 0, copied, g_atrBuffer) < minBars)
      {
         Print("WARNING: ATR data not ready");
         return;
      }
   }

   // Detect new FVGs
   DetectNewFVGs(copied);

   // Check mitigation of existing FVGs
   if(InpTrackMitigation)
      CheckFVGMitigation();

   // Update visual objects
   if(InpDrawFVG)
      UpdateFVGDrawings();

   // Calculate analysis
   CalculateFVGAnalysis();

   // Generate recommendation
   GenerateRecommendation();

   g_analysis.lastUpdate = TimeCurrent();

   // Print report
   if(InpPrintReport)
      PrintFVGReport();
}

//+------------------------------------------------------------------+
//| Detect New FVGs                                                   |
//+------------------------------------------------------------------+
void DetectNewFVGs(int barCount)
{
   // Start from bar 2 (need 3 bars: i-2, i-1, i for FVG)
   // We check from bar 2 going back, looking for FVGs
   int maxCheck = MathMin(barCount - 3, InpFVGLookback);

   for(int i = 2; i < maxCheck; i++)
   {
      // Check if this bar already has an FVG recorded
      if(HasFVGAtBar(i)) continue;

      // Get candle data (bar i is the middle candle)
      // FVG forms between candle i-1 (left), i (middle), i+1 (right)
      // In our array: [0]=current, [1]=previous, etc.
      // So for bar i: left=i+1, middle=i, right=i-1

      double leftHigh = g_highBuffer[i + 1];
      double leftLow = g_lowBuffer[i + 1];
      double middleHigh = g_highBuffer[i];
      double middleLow = g_lowBuffer[i];
      double rightHigh = g_highBuffer[i - 1];
      double rightLow = g_lowBuffer[i - 1];

      // Check for Bullish FVG
      // Gap: Low of right candle > High of left candle
      if(rightLow > leftHigh)
      {
         double gapSize = (rightLow - leftHigh) / g_pipValue;

         if(gapSize >= InpMinFVGSize && gapSize <= InpMaxFVGSize)
         {
            // Optional: Check for strong move
            if(InpRequireStrongMove)
            {
               double atr = g_atrBuffer[i];
               double moveSize = middleHigh - middleLow;
               if(moveSize < atr * 1.5) continue;  // Not strong enough
            }

            // Add bullish FVG
            AddFVGZone(FVG_BULLISH, rightLow, leftHigh, i);
         }
      }

      // Check for Bearish FVG
      // Gap: High of right candle < Low of left candle
      if(rightHigh < leftLow)
      {
         double gapSize = (leftLow - rightHigh) / g_pipValue;

         if(gapSize >= InpMinFVGSize && gapSize <= InpMaxFVGSize)
         {
            // Optional: Check for strong move
            if(InpRequireStrongMove)
            {
               double atr = g_atrBuffer[i];
               double moveSize = middleHigh - middleLow;
               if(moveSize < atr * 1.5) continue;  // Not strong enough
            }

            // Add bearish FVG
            AddFVGZone(FVG_BEARISH, leftLow, rightHigh, i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if FVG exists at bar                                        |
//+------------------------------------------------------------------+
bool HasFVGAtBar(int barIndex)
{
   datetime barTime = iTime(_Symbol, InpFVGTimeframe, barIndex);
   int count = ArraySize(g_analysis.zones);

   for(int i = 0; i < count; i++)
   {
      if(g_analysis.zones[i].timeCreated == barTime)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Add FVG Zone                                                      |
//+------------------------------------------------------------------+
void AddFVGZone(ENUM_FVG_TYPE type, double high, double low, int barIndex)
{
   // Check if we've reached max count
   int count = ArraySize(g_analysis.zones);
   if(count >= InpMaxFVGCount)
   {
      // Remove oldest fully mitigated FVG
      RemoveOldestMitigatedFVG();
      count = ArraySize(g_analysis.zones);

      // If still at max, remove oldest regardless
      if(count >= InpMaxFVGCount)
      {
         RemoveOldestFVG();
         count = ArraySize(g_analysis.zones);
      }
   }

   // Resize array
   ArrayResize(g_analysis.zones, count + 1);

   // Fill zone data
   FVGZone zone;
   zone.type = type;
   zone.status = FVG_FRESH;
   zone.highPrice = high;
   zone.lowPrice = low;
   zone.midPrice = (high + low) / 2.0;
   zone.sizePips = (high - low) / g_pipValue;
   zone.timeCreated = iTime(_Symbol, InpFVGTimeframe, barIndex);
   zone.timeMitigated = 0;
   zone.barIndex = barIndex;
   zone.objName = "FVG_" + IntegerToString(zone.timeCreated);
   zone.isValid = true;

   g_analysis.zones[count] = zone;
}

//+------------------------------------------------------------------+
//| Remove Oldest Mitigated FVG                                       |
//+------------------------------------------------------------------+
void RemoveOldestMitigatedFVG()
{
   int count = ArraySize(g_analysis.zones);
   int oldestIdx = -1;
   datetime oldestTime = TimeCurrent();

   for(int i = 0; i < count; i++)
   {
      if(g_analysis.zones[i].status == FVG_FULLY_MITIGATED &&
         g_analysis.zones[i].timeCreated < oldestTime)
      {
         oldestTime = g_analysis.zones[i].timeCreated;
         oldestIdx = i;
      }
   }

   if(oldestIdx >= 0)
      RemoveFVGAtIndex(oldestIdx);
}

//+------------------------------------------------------------------+
//| Remove Oldest FVG                                                 |
//+------------------------------------------------------------------+
void RemoveOldestFVG()
{
   int count = ArraySize(g_analysis.zones);
   if(count == 0) return;

   int oldestIdx = 0;
   datetime oldestTime = g_analysis.zones[0].timeCreated;

   for(int i = 1; i < count; i++)
   {
      if(g_analysis.zones[i].timeCreated < oldestTime)
      {
         oldestTime = g_analysis.zones[i].timeCreated;
         oldestIdx = i;
      }
   }

   RemoveFVGAtIndex(oldestIdx);
}

//+------------------------------------------------------------------+
//| Remove FVG at Index                                               |
//+------------------------------------------------------------------+
void RemoveFVGAtIndex(int index)
{
   int count = ArraySize(g_analysis.zones);
   if(index < 0 || index >= count) return;

   // Delete chart object
   ObjectDelete(0, g_analysis.zones[index].objName);

   // Shift array elements
   for(int i = index; i < count - 1; i++)
   {
      g_analysis.zones[i] = g_analysis.zones[i + 1];
   }

   // Resize array
   ArrayResize(g_analysis.zones, count - 1);
}

//+------------------------------------------------------------------+
//| Check FVG Mitigation                                              |
//+------------------------------------------------------------------+
void CheckFVGMitigation()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int count = ArraySize(g_analysis.zones);

   for(int i = 0; i < count; i++)
   {
      if(g_analysis.zones[i].status == FVG_FULLY_MITIGATED) continue;

      // Check if price is inside the FVG
      if(currentPrice >= g_analysis.zones[i].lowPrice &&
         currentPrice <= g_analysis.zones[i].highPrice)
      {
         if(g_analysis.zones[i].status == FVG_FRESH)
            g_analysis.zones[i].status = FVG_PARTIALLY_FILLED;
      }

      // Check for full mitigation
      // Bullish FVG: mitigated when price closes below the low
      // Bearish FVG: mitigated when price closes above the high
      if(g_analysis.zones[i].type == FVG_BULLISH)
      {
         // Check if any recent candle closed below FVG low
         for(int j = 0; j < 5; j++)
         {
            if(g_closeBuffer[j] < g_analysis.zones[i].lowPrice)
            {
               g_analysis.zones[i].status = FVG_FULLY_MITIGATED;
               g_analysis.zones[i].timeMitigated = TimeCurrent();
               break;
            }
         }
      }
      else // Bearish FVG
      {
         // Check if any recent candle closed above FVG high
         for(int j = 0; j < 5; j++)
         {
            if(g_closeBuffer[j] > g_analysis.zones[i].highPrice)
            {
               g_analysis.zones[i].status = FVG_FULLY_MITIGATED;
               g_analysis.zones[i].timeMitigated = TimeCurrent();
               break;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate FVG Analysis                                            |
//+------------------------------------------------------------------+
void CalculateFVGAnalysis()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int count = ArraySize(g_analysis.zones);

   // Reset counters
   g_analysis.bullishCount = 0;
   g_analysis.bearishCount = 0;
   g_analysis.mitigatedCount = 0;
   g_analysis.priceInBullishFVG = false;
   g_analysis.priceInBearishFVG = false;

   // Initialize nearest zones
   double nearestBullishDist = DBL_MAX;
   double nearestBearishDist = DBL_MAX;
   bool foundBullish = false;
   bool foundBearish = false;

   for(int i = 0; i < count; i++)
   {
      FVGZone zone = g_analysis.zones[i];

      // Count by type and status
      if(zone.status != FVG_FULLY_MITIGATED)
      {
         if(zone.type == FVG_BULLISH)
            g_analysis.bullishCount++;
         else
            g_analysis.bearishCount++;

         // Check if price is in this zone
         if(currentPrice >= zone.lowPrice && currentPrice <= zone.highPrice)
         {
            if(zone.type == FVG_BULLISH)
               g_analysis.priceInBullishFVG = true;
            else
               g_analysis.priceInBearishFVG = true;
         }

         // Find nearest zones
         double distToMid = MathAbs(currentPrice - zone.midPrice);

         if(zone.type == FVG_BULLISH && distToMid < nearestBullishDist)
         {
            nearestBullishDist = distToMid;
            g_analysis.nearestBullish = zone;
            foundBullish = true;
         }
         else if(zone.type == FVG_BEARISH && distToMid < nearestBearishDist)
         {
            nearestBearishDist = distToMid;
            g_analysis.nearestBearish = zone;
            foundBearish = true;
         }
      }
      else
      {
         g_analysis.mitigatedCount++;
      }
   }

   // Determine overall bias
   if(g_analysis.bullishCount > g_analysis.bearishCount + 2)
      g_analysis.fvgBias = BIAS_BULLISH;
   else if(g_analysis.bearishCount > g_analysis.bullishCount + 2)
      g_analysis.fvgBias = BIAS_BEARISH;
   else
      g_analysis.fvgBias = BIAS_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Generate Recommendation                                           |
//+------------------------------------------------------------------+
void GenerateRecommendation()
{
   string rec = "";
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Priority 1: Price is inside an FVG
   if(g_analysis.priceInBullishFVG)
   {
      rec = "BUY ZONE - Price in Bullish FVG (demand)";
   }
   else if(g_analysis.priceInBearishFVG)
   {
      rec = "SELL ZONE - Price in Bearish FVG (supply)";
   }
   // Priority 2: Price approaching nearest FVG
   else if(g_analysis.bullishCount > 0 || g_analysis.bearishCount > 0)
   {
      // Check distance to nearest bullish FVG (below price)
      if(g_analysis.bullishCount > 0 &&
         g_analysis.nearestBullish.highPrice < currentPrice)
      {
         double distPips = (currentPrice - g_analysis.nearestBullish.highPrice) / g_pipValue;
         if(distPips < 50)
         {
            rec = "WATCH BUY - Approaching Bullish FVG (" +
                  DoubleToString(distPips, 1) + " pips)";
         }
      }

      // Check distance to nearest bearish FVG (above price)
      if(rec == "" && g_analysis.bearishCount > 0 &&
         g_analysis.nearestBearish.lowPrice > currentPrice)
      {
         double distPips = (g_analysis.nearestBearish.lowPrice - currentPrice) / g_pipValue;
         if(distPips < 50)
         {
            rec = "WATCH SELL - Approaching Bearish FVG (" +
                  DoubleToString(distPips, 1) + " pips)";
         }
      }

      // Default: report FVG counts
      if(rec == "")
      {
         if(g_analysis.fvgBias == BIAS_BULLISH)
            rec = "BULLISH BIAS - More demand FVGs active";
         else if(g_analysis.fvgBias == BIAS_BEARISH)
            rec = "BEARISH BIAS - More supply FVGs active";
         else
            rec = "NEUTRAL - FVGs balanced";
      }
   }
   else
   {
      rec = "NO FVGs - Clean price action";
   }

   g_analysis.recommendation = rec;
}

//+------------------------------------------------------------------+
//| Update FVG Drawings                                               |
//+------------------------------------------------------------------+
void UpdateFVGDrawings()
{
   int count = ArraySize(g_analysis.zones);

   for(int i = 0; i < count; i++)
   {
      FVGZone zone = g_analysis.zones[i];

      // Determine color based on type and status
      color zoneColor;
      if(zone.status == FVG_FULLY_MITIGATED)
         zoneColor = InpMitigatedColor;
      else if(zone.type == FVG_BULLISH)
         zoneColor = InpBullishFVGColor;
      else
         zoneColor = InpBearishFVGColor;

      // Create or update rectangle
      datetime endTime = TimeCurrent() + PeriodSeconds(InpFVGTimeframe) * 20;

      if(ObjectFind(0, zone.objName) < 0)
      {
         ObjectCreate(0, zone.objName, OBJ_RECTANGLE, 0,
                     zone.timeCreated, zone.highPrice,
                     endTime, zone.lowPrice);
      }

      ObjectSetInteger(0, zone.objName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, zone.objName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, zone.objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, zone.objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, zone.objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, zone.objName, OBJPROP_SELECTABLE, false);

      // Extend rectangle to current time
      ObjectSetInteger(0, zone.objName, OBJPROP_TIME, 1, endTime);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete All FVG Objects                                            |
//+------------------------------------------------------------------+
void DeleteAllFVGObjects()
{
   int count = ArraySize(g_analysis.zones);
   for(int i = 0; i < count; i++)
   {
      ObjectDelete(0, g_analysis.zones[i].objName);
   }

   // Also delete any orphaned FVG objects
   ObjectsDeleteAll(0, "FVG_");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Print FVG Report                                                  |
//+------------------------------------------------------------------+
void PrintFVGReport()
{
   Print("");
   Print("=================================================");
   Print("       FAIR VALUE GAP (FVG) REPORT (Section 7)   ");
   Print("=================================================");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", TimeframeToString(InpFVGTimeframe));
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Current Price: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), g_digits));
   Print("-------------------------------------------------");

   Print("FVG SUMMARY:");
   Print("  Active Bullish FVGs: ", g_analysis.bullishCount);
   Print("  Active Bearish FVGs: ", g_analysis.bearishCount);
   Print("  Mitigated FVGs: ", g_analysis.mitigatedCount);
   Print("  Overall Bias: ", TrendBiasToString(g_analysis.fvgBias));
   Print("-------------------------------------------------");

   // Print active FVG zones
   int count = ArraySize(g_analysis.zones);
   if(count > 0)
   {
      Print("ACTIVE FVG ZONES:");
      for(int i = 0; i < count; i++)
      {
         if(g_analysis.zones[i].status != FVG_FULLY_MITIGATED)
         {
            string typeStr = (g_analysis.zones[i].type == FVG_BULLISH) ? "BULLISH" : "BEARISH";
            string statusStr = (g_analysis.zones[i].status == FVG_FRESH) ? "Fresh" : "Partially Filled";
            Print("  ", typeStr, " FVG:");
            Print("    Range: ", DoubleToString(g_analysis.zones[i].lowPrice, g_digits),
                  " - ", DoubleToString(g_analysis.zones[i].highPrice, g_digits));
            Print("    Size: ", DoubleToString(g_analysis.zones[i].sizePips, 1), " pips");
            Print("    Status: ", statusStr);
            Print("    Created: ", TimeToString(g_analysis.zones[i].timeCreated, TIME_DATE|TIME_MINUTES));
         }
      }
      Print("-------------------------------------------------");
   }

   // Price position relative to FVGs
   Print("PRICE POSITION:");
   if(g_analysis.priceInBullishFVG)
      Print("  >> Price is INSIDE a Bullish FVG (demand zone)");
   else if(g_analysis.priceInBearishFVG)
      Print("  >> Price is INSIDE a Bearish FVG (supply zone)");
   else
      Print("  Price is outside all FVG zones");
   Print("-------------------------------------------------");

   // Recommendation
   Print("RECOMMENDATION:");
   Print("  ", g_analysis.recommendation);
   Print("=================================================");
   Print("");
}

//+------------------------------------------------------------------+
//| Print Initialization Report                                       |
//+------------------------------------------------------------------+
void PrintInitReport()
{
   Print("");
   Print("=================================================");
   Print("     SWING TRADER PRO - SECTION 7                ");
   Print("     FAIR VALUE GAP (FVG) DETECTION              ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol);
   Print("TIMEFRAME: ", TimeframeToString(InpFVGTimeframe));
   Print("-------------------------------------------------");
   Print("FVG SETTINGS:");
   Print("  Lookback Bars: ", InpFVGLookback);
   Print("  Min FVG Size: ", InpMinFVGSize, " pips");
   Print("  Max FVG Size: ", InpMaxFVGSize, " pips");
   Print("  Max FVGs Tracked: ", InpMaxFVGCount);
   Print("  Strong Move Required: ", InpRequireStrongMove ? "Yes" : "No");
   Print("-------------------------------------------------");
   Print("FVG INTERPRETATION:");
   Print("  Bullish FVG = Demand imbalance (buy zone)");
   Print("  Bearish FVG = Supply imbalance (sell zone)");
   Print("  Fresh FVG = High probability entry zone");
   Print("  Mitigated FVG = Zone has been filled");
   Print("=================================================");
   Print("");
}

//+------------------------------------------------------------------+
//| Create Panel                                                      |
//+------------------------------------------------------------------+
void CreatePanel()
{
   int x = InpPanelX;
   int y = InpPanelY;

   CreateRectangle(g_panelName + "_bg", x, y, 300, 240, clrBlack, 200);

   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "FAIR VALUE GAP (FVG)", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "--------------------------------", clrGray, 8, "Courier New");

   int yOff = 40;

   // FVG Counts
   CreateLabel(g_panelName + "_bull_label", x + 10, y + yOff, "Bullish FVGs:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_bull_value", x + 150, y + yOff, "0", clrLimeGreen, 9, "Arial Bold");
   yOff += 20;

   CreateLabel(g_panelName + "_bear_label", x + 10, y + yOff, "Bearish FVGs:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_bear_value", x + 150, y + yOff, "0", clrRed, 9, "Arial Bold");
   yOff += 20;

   CreateLabel(g_panelName + "_mit_label", x + 10, y + yOff, "Mitigated:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_mit_value", x + 150, y + yOff, "0", clrGray, 9, "Arial");
   yOff += 25;

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOff,
               "--------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Price Position
   CreateLabel(g_panelName + "_pos_label", x + 10, y + yOff, "Price Position:", clrCyan, 9, "Arial Bold");
   yOff += 18;
   CreateLabel(g_panelName + "_pos_value", x + 20, y + yOff, "Outside FVGs", clrYellow, 9, "Arial");
   yOff += 25;

   // Nearest FVG
   CreateLabel(g_panelName + "_near_label", x + 10, y + yOff, "Nearest FVG:", clrCyan, 9, "Arial Bold");
   yOff += 18;
   CreateLabel(g_panelName + "_near_value", x + 20, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 25;

   CreateLabel(g_panelName + "_sep3", x + 10, y + yOff,
               "--------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Bias and Recommendation
   CreateLabel(g_panelName + "_bias_label", x + 10, y + yOff, "FVG Bias:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_bias_value", x + 150, y + yOff, "NEUTRAL", clrGray, 9, "Arial Bold");
   yOff += 25;

   CreateLabel(g_panelName + "_rec_label", x + 10, y + yOff, "Signal:", clrWhite, 10, "Arial Bold");
   CreateLabel(g_panelName + "_rec_value", x + 10, y + yOff + 18, "ANALYZING...", clrYellow, 9, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel) return;

   // Update counts
   ObjectSetString(0, g_panelName + "_bull_value", OBJPROP_TEXT,
                   IntegerToString(g_analysis.bullishCount));
   ObjectSetString(0, g_panelName + "_bear_value", OBJPROP_TEXT,
                   IntegerToString(g_analysis.bearishCount));
   ObjectSetString(0, g_panelName + "_mit_value", OBJPROP_TEXT,
                   IntegerToString(g_analysis.mitigatedCount));

   // Update price position
   string posText;
   color posColor;
   if(g_analysis.priceInBullishFVG)
   {
      posText = "IN BULLISH FVG";
      posColor = clrLimeGreen;
   }
   else if(g_analysis.priceInBearishFVG)
   {
      posText = "IN BEARISH FVG";
      posColor = clrRed;
   }
   else
   {
      posText = "Outside FVGs";
      posColor = clrGray;
   }
   ObjectSetString(0, g_panelName + "_pos_value", OBJPROP_TEXT, posText);
   ObjectSetInteger(0, g_panelName + "_pos_value", OBJPROP_COLOR, posColor);

   // Update nearest FVG
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string nearText = "--";

   if(g_analysis.bullishCount > 0 || g_analysis.bearishCount > 0)
   {
      double bullDist = DBL_MAX;
      double bearDist = DBL_MAX;

      if(g_analysis.bullishCount > 0)
         bullDist = MathAbs(currentPrice - g_analysis.nearestBullish.midPrice);
      if(g_analysis.bearishCount > 0)
         bearDist = MathAbs(currentPrice - g_analysis.nearestBearish.midPrice);

      if(bullDist < bearDist && g_analysis.bullishCount > 0)
      {
         double pips = bullDist / g_pipValue;
         nearText = "Bull @ " + DoubleToString(g_analysis.nearestBullish.midPrice, g_digits) +
                   " (" + DoubleToString(pips, 0) + " pips)";
      }
      else if(g_analysis.bearishCount > 0)
      {
         double pips = bearDist / g_pipValue;
         nearText = "Bear @ " + DoubleToString(g_analysis.nearestBearish.midPrice, g_digits) +
                   " (" + DoubleToString(pips, 0) + " pips)";
      }
   }
   ObjectSetString(0, g_panelName + "_near_value", OBJPROP_TEXT, nearText);

   // Update bias
   string biasText = TrendBiasToString(g_analysis.fvgBias);
   color biasColor = clrGray;
   if(g_analysis.fvgBias == BIAS_BULLISH)
      biasColor = clrLimeGreen;
   else if(g_analysis.fvgBias == BIAS_BEARISH)
      biasColor = clrRed;

   ObjectSetString(0, g_panelName + "_bias_value", OBJPROP_TEXT, biasText);
   ObjectSetInteger(0, g_panelName + "_bias_value", OBJPROP_COLOR, biasColor);

   // Update recommendation
   color recColor = clrGray;
   if(StringFind(g_analysis.recommendation, "BUY") >= 0 ||
      StringFind(g_analysis.recommendation, "BULLISH") >= 0)
      recColor = clrLimeGreen;
   else if(StringFind(g_analysis.recommendation, "SELL") >= 0 ||
           StringFind(g_analysis.recommendation, "BEARISH") >= 0)
      recColor = clrRed;

   string recText = g_analysis.recommendation;
   if(StringLen(recText) > 35)
      recText = StringSubstr(recText, 0, 35) + "...";

   ObjectSetString(0, g_panelName + "_rec_value", OBJPROP_TEXT, recText);
   ObjectSetInteger(0, g_panelName + "_rec_value", OBJPROP_COLOR, recColor);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete Panel                                                      |
//+------------------------------------------------------------------+
void DeletePanel()
{
   ObjectsDeleteAll(0, g_panelName);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create Rectangle                                                  |
//+------------------------------------------------------------------+
void CreateRectangle(string name, int x, int y, int width, int height, color clr, int transparency)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDarkGray);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Create Label                                                      |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize, string fontName)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, fontName);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Public Functions for External Use                                 |
//+------------------------------------------------------------------+
int GetFVGCount() { return ArraySize(g_analysis.zones); }
int GetBullishFVGCount() { return g_analysis.bullishCount; }
int GetBearishFVGCount() { return g_analysis.bearishCount; }
bool IsPriceInBullishFVG() { return g_analysis.priceInBullishFVG; }
bool IsPriceInBearishFVG() { return g_analysis.priceInBearishFVG; }
ENUM_TREND_BIAS GetFVGBias() { return g_analysis.fvgBias; }
string GetFVGRecommendation() { return g_analysis.recommendation; }

// Get nearest FVG zone to current price
bool GetNearestBullishFVG(double &high, double &low, double &mid)
{
   if(g_analysis.bullishCount == 0) return false;
   high = g_analysis.nearestBullish.highPrice;
   low = g_analysis.nearestBullish.lowPrice;
   mid = g_analysis.nearestBullish.midPrice;
   return true;
}

bool GetNearestBearishFVG(double &high, double &low, double &mid)
{
   if(g_analysis.bearishCount == 0) return false;
   high = g_analysis.nearestBearish.highPrice;
   low = g_analysis.nearestBearish.lowPrice;
   mid = g_analysis.nearestBearish.midPrice;
   return true;
}
//+------------------------------------------------------------------+
