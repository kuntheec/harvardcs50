//+------------------------------------------------------------------+
//|                                     Section04_SupplyDemand.mq5   |
//|                                      SwingTrader Pro EA          |
//|                   Section 4: Supply & Demand Zone Detection      |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "2.00"
#property description "Section 4: Supply/Demand Zone Detection"
#property description "Mathematical ATR-based zone validation"
#property description "Scoring system with BOS/CHoCH correlation"
#property description "SMC Best Practice implementation"

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Zone Detection Settings ==="
input int      InpZoneLookback        = 100;      // Zone Detection Lookback (candles)
input int      InpMaxZones            = 10;       // Max Zones to Track
input ENUM_TIMEFRAMES InpZoneTimeframe = PERIOD_H4; // Zone Analysis Timeframe
input int      InpMinScoreToShow      = 5;        // Min Score to Show Zone (0-13)
input double   InpMaxZoneWidthATR     = 1.0;      // Max Zone Width (x ATR) - filter huge zones

input group "=== ATR Math Settings (SMC Best Practice) ==="
input double   InpLegOutMultiplier    = 2.0;      // Leg-Out: Move >= X * ATR
input double   InpBaseMaxMultiplier   = 0.5;      // Base: Body <= X * ATR
input int      InpBaseCandles         = 3;        // Max Candles in Base Area
input bool     InpDebugMode           = true;     // Debug Mode - Print Zone Detection Details

input group "=== Zone Filtering ==="
input bool     InpFilterByEMA         = true;     // Filter Zones by EMA Trend
input bool     InpShowFreshOnly       = false;    // Show Only Fresh (Untested) Zones
input int      InpMaxTouches          = 3;        // Max Touches Before Zone Invalid

input group "=== EMA Settings (from Section 2) ==="
input bool     InpUseEMAFilter        = true;     // Use EMA Trend Filter
input int      InpEMAFastPeriod       = 50;       // EMA Fast Period
input int      InpEMASlowPeriod       = 200;      // EMA Slow Period

input group "=== ATR Settings (from Section 1) ==="
input bool     InpUseATRFilter        = true;     // Use ATR Volatility Filter
input int      InpATRPeriod           = 14;       // ATR Period
input double   InpATRQuietThreshold   = 60.0;     // Quiet Market Threshold (pips)
input double   InpATRExtremeThreshold = 250.0;    // Extreme Volatility Threshold (pips)

input group "=== Alert Settings ==="
input bool     InpAlertOnZoneEntry    = true;     // Alert When Price Enters Zone
input bool     InpPushNotification    = false;    // Send Push Notifications

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;     // Show Info Panel
input bool     InpShowZones           = true;     // Show Zones on Chart
input color    InpDemandColor         = clrDodgerBlue;  // Demand Zone Color
input color    InpSupplyColor         = clrCrimson;     // Supply Zone Color
input color    InpTestedZoneColor     = clrGray;        // Tested Zone Color
input int      InpZoneTransparency    = 70;       // Zone Transparency (0-100)
input int      InpPanelX              = 20;       // Panel X Position
input int      InpPanelY              = 30;       // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;     // Print Report to Experts Tab

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
// Indicator handles
int            g_emaFastHandle;
int            g_emaSlowHandle;
int            g_atrHandle;

// Buffers
double         g_emaFastBuffer[];
double         g_emaSlowBuffer[];
double         g_atrBuffer[];
double         g_highBuffer[];
double         g_lowBuffer[];
double         g_openBuffer[];
double         g_closeBuffer[];
datetime       g_timeBuffer[];

// Zones storage
SDZone         g_demandZones[];
SDZone         g_supplyZones[];
int            g_demandCount = 0;
int            g_supplyCount = 0;

// Results from previous sections
EMAAnalysisResult g_emaResult;
ATRFilterResult   g_atrResult;

// Panel
string         g_panelName = "SDZonePanel";

// Symbol info
int            g_digits;
double         g_point;
double         g_pipSize;

// Auto-adaptive settings (based on instrument type)
double         g_minMovePercent;
int            g_minMoveCandles;
double         g_zoneExtendPercent;
string         g_instrumentType;

// Alert tracking
bool           g_wasInDemandZone = false;
bool           g_wasInSupplyZone = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get symbol info
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Auto-detect instrument type and set adaptive parameters
   string sym = _Symbol;
   StringToUpper(sym);

   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
   {
      g_instrumentType = "GOLD";
      g_minMovePercent = 0.5;        // Gold needs bigger moves
      g_minMoveCandles = 4;          // More candles for confirmation
      g_zoneExtendPercent = 5.0;     // Tighter zone extension
      g_pipSize = 0.10;              // Gold: 1 pip = $0.10
      Print("AUTO-DETECT: Gold pair - using stronger zone settings");
   }
   else if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
   {
      g_instrumentType = "SILVER";
      g_minMovePercent = 0.4;
      g_minMoveCandles = 4;
      g_zoneExtendPercent = 6.0;
      g_pipSize = 0.01;              // Silver: 1 pip = $0.01
      Print("AUTO-DETECT: Silver pair - using precious metal settings");
   }
   else if(StringFind(sym, "JPY") >= 0)
   {
      g_instrumentType = "JPY";
      g_minMovePercent = 0.3;        // JPY pairs move less %
      g_minMoveCandles = 3;
      g_zoneExtendPercent = 10.0;    // Wider extension for JPY
      g_pipSize = g_point * (g_digits == 3 ? 1 : 10);
      Print("AUTO-DETECT: JPY pair - using JPY-optimized settings");
   }
   else
   {
      g_instrumentType = "FOREX";
      g_minMovePercent = 0.4;        // Standard forex
      g_minMoveCandles = 3;
      g_zoneExtendPercent = 8.0;
      g_pipSize = g_point * (g_digits == 5 ? 10 : 1);
      Print("AUTO-DETECT: Standard forex pair - using balanced settings");
   }

   // Note: Legacy adaptive settings are now replaced by ATR-based math method
   // g_minMovePercent, g_minMoveCandles, g_zoneExtendPercent are kept for compatibility
   // but the new ATR-based detection uses InpLegOutMultiplier and InpBaseMaxMultiplier

   // Initialize arrays
   ArrayResize(g_demandZones, InpMaxZones);
   ArrayResize(g_supplyZones, InpMaxZones);
   ArraySetAsSeries(g_highBuffer, true);
   ArraySetAsSeries(g_lowBuffer, true);
   ArraySetAsSeries(g_openBuffer, true);
   ArraySetAsSeries(g_closeBuffer, true);
   ArraySetAsSeries(g_timeBuffer, true);

   // Create EMA handles if filter enabled
   if(InpUseEMAFilter)
   {
      g_emaFastHandle = iMA(_Symbol, InpZoneTimeframe, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_emaSlowHandle = iMA(_Symbol, InpZoneTimeframe, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);

      if(g_emaFastHandle == INVALID_HANDLE || g_emaSlowHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create EMA handles");
         return(INIT_FAILED);
      }
      ArraySetAsSeries(g_emaFastBuffer, true);
      ArraySetAsSeries(g_emaSlowBuffer, true);
   }

   // Create ATR handle if filter enabled
   if(InpUseATRFilter)
   {
      g_atrHandle = iATR(_Symbol, InpZoneTimeframe, InpATRPeriod);
      if(g_atrHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR handle");
         return(INIT_FAILED);
      }
      ArraySetAsSeries(g_atrBuffer, true);
   }

   // Print initialization
   PrintInitReport();

   // Create panel
   if(InpShowPanel)
      CreatePanel();

   // Run initial analysis
   AnalyzeZones();

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
   if(g_emaFastHandle != INVALID_HANDLE) IndicatorRelease(g_emaFastHandle);
   if(g_emaSlowHandle != INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);

   // Remove visual objects
   DeletePanel();
   ObjectsDeleteAll(0, "SDZone_");

   Print("=================================================");
   Print("Supply/Demand Zone EA Deinitialized");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpZoneTimeframe, 0);

   // Check for zone entry alerts on every tick
   if(InpAlertOnZoneEntry)
      CheckZoneEntryAlerts();

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      AnalyzeZones();

      if(InpShowPanel) UpdatePanel();
   }
}

//+------------------------------------------------------------------+
//| Check for zone entry and trigger alerts                           |
//+------------------------------------------------------------------+
void CheckZoneEntryAlerts()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool inDemandZone = false;
   bool inSupplyZone = false;

   // Check demand zones
   for(int i = 0; i < g_demandCount; i++)
   {
      if(g_demandZones[i].status != ZONE_BROKEN &&
         currentPrice <= g_demandZones[i].upperPrice &&
         currentPrice >= g_demandZones[i].lowerPrice)
      {
         inDemandZone = true;
         break;
      }
   }

   // Check supply zones
   for(int i = 0; i < g_supplyCount; i++)
   {
      if(g_supplyZones[i].status != ZONE_BROKEN &&
         currentPrice >= g_supplyZones[i].lowerPrice &&
         currentPrice <= g_supplyZones[i].upperPrice)
      {
         inSupplyZone = true;
         break;
      }
   }

   // Alert on demand zone entry (was not in, now is in)
   if(inDemandZone && !g_wasInDemandZone)
   {
      string alertMsg = _Symbol + " entered DEMAND zone at " + DoubleToString(currentPrice, g_digits);
      Alert(alertMsg);
      Print("ALERT: ", alertMsg);

      if(InpPushNotification)
         SendNotification(alertMsg);
   }

   // Alert on supply zone entry (was not in, now is in)
   if(inSupplyZone && !g_wasInSupplyZone)
   {
      string alertMsg = _Symbol + " entered SUPPLY zone at " + DoubleToString(currentPrice, g_digits);
      Alert(alertMsg);
      Print("ALERT: ", alertMsg);

      if(InpPushNotification)
         SendNotification(alertMsg);
   }

   // Update tracking
   g_wasInDemandZone = inDemandZone;
   g_wasInSupplyZone = inSupplyZone;
}

//+------------------------------------------------------------------+
//| Main Zone Analysis Function                                       |
//+------------------------------------------------------------------+
void AnalyzeZones()
{
   // Copy price data
   int barsNeeded = InpZoneLookback + g_minMoveCandles + 5;

   if(CopyHigh(_Symbol, InpZoneTimeframe, 0, barsNeeded, g_highBuffer) < barsNeeded) return;
   if(CopyLow(_Symbol, InpZoneTimeframe, 0, barsNeeded, g_lowBuffer) < barsNeeded) return;
   if(CopyOpen(_Symbol, InpZoneTimeframe, 0, barsNeeded, g_openBuffer) < barsNeeded) return;
   if(CopyClose(_Symbol, InpZoneTimeframe, 0, barsNeeded, g_closeBuffer) < barsNeeded) return;
   if(CopyTime(_Symbol, InpZoneTimeframe, 0, barsNeeded, g_timeBuffer) < barsNeeded) return;

   // Analyze ATR if enabled
   if(InpUseATRFilter)
      AnalyzeATR();

   // Analyze EMA if enabled
   if(InpUseEMAFilter)
      AnalyzeEMA();

   // Detect Supply and Demand zones
   DetectDemandZones();
   DetectSupplyZones();

   // Update zone statuses (test for price interaction)
   UpdateZoneStatuses();

   // Draw zones on chart
   if(InpShowZones)
      DrawZones();

   // Print report
   if(InpPrintReport)
      PrintZoneReport();
}

//+------------------------------------------------------------------+
//| Analyze ATR                                                       |
//+------------------------------------------------------------------+
void AnalyzeATR()
{
   if(CopyBuffer(g_atrHandle, 0, 0, 1, g_atrBuffer) < 1) return;

   double atrPoints = g_atrBuffer[0];
   double atrPips;

   // Convert ATR to pips based on instrument type
   if(g_instrumentType == "GOLD")
      atrPips = atrPoints * 10;
   else if(g_instrumentType == "SILVER")
      atrPips = atrPoints * 100;
   else
      atrPips = PointsToPips(_Symbol, atrPoints);

   g_atrResult.atrValue = atrPips;
   g_atrResult.timestamp = TimeCurrent();

   if(atrPips < InpATRQuietThreshold)
   {
      g_atrResult.condition = MARKET_QUIET;
      g_atrResult.tradingAllowed = false;
   }
   else if(atrPips > InpATRExtremeThreshold)
   {
      g_atrResult.condition = MARKET_EXTREME;
      g_atrResult.tradingAllowed = true;
   }
   else
   {
      g_atrResult.condition = MARKET_NORMAL;
      g_atrResult.tradingAllowed = true;
   }
}

//+------------------------------------------------------------------+
//| Analyze EMA                                                       |
//+------------------------------------------------------------------+
void AnalyzeEMA()
{
   if(CopyBuffer(g_emaFastHandle, 0, 0, 1, g_emaFastBuffer) < 1) return;
   if(CopyBuffer(g_emaSlowHandle, 0, 0, 1, g_emaSlowBuffer) < 1) return;

   g_emaResult.ema50 = g_emaFastBuffer[0];
   g_emaResult.ema200 = g_emaSlowBuffer[0];
   g_emaResult.timestamp = TimeCurrent();

   if(g_emaFastBuffer[0] > g_emaSlowBuffer[0])
      g_emaResult.trend = BIAS_BULLISH;
   else if(g_emaFastBuffer[0] < g_emaSlowBuffer[0])
      g_emaResult.trend = BIAS_BEARISH;
   else
      g_emaResult.trend = BIAS_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Detect Demand Zones (bullish zones) - MATHEMATICAL METHOD         |
//| Uses ATR-based validation: Base <= 0.5×ATR, LegOut >= 2×ATR       |
//+------------------------------------------------------------------+
void DetectDemandZones()
{
   g_demandCount = 0;

   // Get ATR values for zone detection
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(g_atrHandle, 0, 0, InpZoneLookback + 10, atrBuffer) < InpZoneLookback)
   {
      Print("WARNING: Cannot copy ATR buffer for demand zone detection");
      return;
   }

   if(InpDebugMode)
   {
      Print("=== DEMAND ZONE DETECTION (Mathematical Method) ===");
      Print("Leg-Out Multiplier: ", InpLegOutMultiplier, "x ATR");
      Print("Base Max Multiplier: ", InpBaseMaxMultiplier, "x ATR");
      Print("Max Zone Width: ", InpMaxZoneWidthATR, "x ATR");
   }

   int zonesFound = 0;
   int filteredByLegOut = 0;
   int filteredByBase = 0;
   int filteredByWidth = 0;
   int filteredByScore = 0;

   // Look for BASE (consolidation) followed by LEG-OUT (strong bullish move)
   for(int i = InpBaseCandles + 3; i < InpZoneLookback - 5; i++)
   {
      if(g_demandCount >= InpMaxZones) break;

      double atr = atrBuffer[i];
      if(atr == 0) continue;

      // Step 1: Find potential BASE area (small candles)
      // Base = consolidation before the move (candles with body <= 0.5× ATR)
      double baseHigh = 0;
      double baseLow = DBL_MAX;
      double maxBaseBody = 0;
      bool validBase = true;

      for(int j = 0; j < InpBaseCandles; j++)
      {
         int idx = i + j;
         double bodySize = MathAbs(g_closeBuffer[idx] - g_openBuffer[idx]);
         double maxBody = InpBaseMaxMultiplier * atr;

         if(bodySize > maxBody)
         {
            validBase = false;
            break;
         }

         if(bodySize > maxBaseBody) maxBaseBody = bodySize;
         if(g_highBuffer[idx] > baseHigh) baseHigh = g_highBuffer[idx];
         if(g_lowBuffer[idx] < baseLow) baseLow = g_lowBuffer[idx];
      }

      if(!validBase)
      {
         filteredByBase++;
         continue;
      }

      // Step 2: Check for LEG-OUT (strong bullish move AFTER the base)
      // Measure the move from base to the next few candles
      double legOutDistance = 0;
      int legOutCandles = 3;  // Check next 3 candles for leg-out

      for(int j = 1; j <= legOutCandles; j++)
      {
         int idx = i - j;
         if(idx < 0) break;
         double moveUp = g_highBuffer[idx] - baseHigh;
         if(moveUp > legOutDistance) legOutDistance = moveUp;
      }

      double requiredLegOut = InpLegOutMultiplier * atr;
      if(legOutDistance < requiredLegOut)
      {
         filteredByLegOut++;
         continue;
      }

      // Step 3: Check zone width (should not be too large)
      double zoneWidth = baseHigh - baseLow;
      double maxZoneWidth = InpMaxZoneWidthATR * atr;
      if(zoneWidth > maxZoneWidth)
      {
         filteredByWidth++;
         continue;
      }

      // Step 4: Create the zone
      SDZone zone;
      zone.type = ZONE_DEMAND;
      zone.upperPrice = baseHigh;
      zone.lowerPrice = baseLow;
      zone.formationTime = g_timeBuffer[i];
      zone.barIndex = i;
      zone.status = ZONE_FRESH;
      zone.touchCount = 0;
      zone.legOutDistance = legOutDistance;
      zone.baseBodyMax = maxBaseBody;
      zone.atrAtFormation = atr;
      zone.causedBOS = false;  // TODO: Check Section 3 for BOS correlation
      zone.alignsWithFib = false;  // TODO: Check Section 5 for Fib alignment

      // Step 5: Calculate zone score
      zone.score = CalculateZoneScoreLocal(legOutDistance, maxBaseBody, true, false, false, atr);
      zone.strength = (double)zone.score / 13.0 * 100.0;  // Convert to percentage for legacy

      // Filter by minimum score
      if(zone.score < InpMinScoreToShow)
      {
         filteredByScore++;
         continue;
      }

      // Check if zone should be filtered by EMA
      if(InpFilterByEMA && InpUseEMAFilter)
      {
         if(g_emaResult.trend != BIAS_BULLISH)
            continue;
      }

      // Add zone
      g_demandZones[g_demandCount] = zone;
      g_demandCount++;
      zonesFound++;

      if(InpDebugMode && zonesFound <= 5)
      {
         Print("DEMAND ZONE ", zonesFound, " at bar ", i, ":");
         Print("  Range: ", DoubleToString(baseLow, g_digits), " - ", DoubleToString(baseHigh, g_digits));
         Print("  Width: $", DoubleToString(zoneWidth, 2), " (", DoubleToString(zoneWidth/atr, 2), "x ATR)");
         Print("  Leg-Out: $", DoubleToString(legOutDistance, 2), " (", DoubleToString(legOutDistance/atr, 2), "x ATR)");
         Print("  Base Body Max: $", DoubleToString(maxBaseBody, 2), " (", DoubleToString(maxBaseBody/atr, 2), "x ATR)");
         Print("  Score: ", zone.score, "/13");
      }
   }

   if(InpDebugMode)
   {
      Print("--- Demand Zone Summary ---");
      Print("Zones Found: ", zonesFound);
      Print("Filtered by Leg-Out (<", InpLegOutMultiplier, "x ATR): ", filteredByLegOut);
      Print("Filtered by Base (>", InpBaseMaxMultiplier, "x ATR): ", filteredByBase);
      Print("Filtered by Width (>", InpMaxZoneWidthATR, "x ATR): ", filteredByWidth);
      Print("Filtered by Score (<", InpMinScoreToShow, "): ", filteredByScore);
   }
}

//+------------------------------------------------------------------+
//| Detect Supply Zones (bearish zones) - MATHEMATICAL METHOD         |
//| Uses ATR-based validation: Base <= 0.5×ATR, LegOut >= 2×ATR       |
//+------------------------------------------------------------------+
void DetectSupplyZones()
{
   g_supplyCount = 0;

   // Get ATR values for zone detection
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(g_atrHandle, 0, 0, InpZoneLookback + 10, atrBuffer) < InpZoneLookback)
   {
      Print("WARNING: Cannot copy ATR buffer for supply zone detection");
      return;
   }

   if(InpDebugMode)
   {
      Print("=== SUPPLY ZONE DETECTION (Mathematical Method) ===");
   }

   int zonesFound = 0;
   int filteredByLegOut = 0;
   int filteredByBase = 0;
   int filteredByWidth = 0;
   int filteredByScore = 0;

   // Look for BASE (consolidation) followed by LEG-OUT (strong bearish move)
   for(int i = InpBaseCandles + 3; i < InpZoneLookback - 5; i++)
   {
      if(g_supplyCount >= InpMaxZones) break;

      double atr = atrBuffer[i];
      if(atr == 0) continue;

      // Step 1: Find potential BASE area (small candles)
      double baseHigh = 0;
      double baseLow = DBL_MAX;
      double maxBaseBody = 0;
      bool validBase = true;

      for(int j = 0; j < InpBaseCandles; j++)
      {
         int idx = i + j;
         double bodySize = MathAbs(g_closeBuffer[idx] - g_openBuffer[idx]);
         double maxBody = InpBaseMaxMultiplier * atr;

         if(bodySize > maxBody)
         {
            validBase = false;
            break;
         }

         if(bodySize > maxBaseBody) maxBaseBody = bodySize;
         if(g_highBuffer[idx] > baseHigh) baseHigh = g_highBuffer[idx];
         if(g_lowBuffer[idx] < baseLow) baseLow = g_lowBuffer[idx];
      }

      if(!validBase)
      {
         filteredByBase++;
         continue;
      }

      // Step 2: Check for LEG-OUT (strong bearish move AFTER the base)
      double legOutDistance = 0;
      int legOutCandles = 3;

      for(int j = 1; j <= legOutCandles; j++)
      {
         int idx = i - j;
         if(idx < 0) break;
         double moveDown = baseLow - g_lowBuffer[idx];
         if(moveDown > legOutDistance) legOutDistance = moveDown;
      }

      double requiredLegOut = InpLegOutMultiplier * atr;
      if(legOutDistance < requiredLegOut)
      {
         filteredByLegOut++;
         continue;
      }

      // Step 3: Check zone width
      double zoneWidth = baseHigh - baseLow;
      double maxZoneWidth = InpMaxZoneWidthATR * atr;
      if(zoneWidth > maxZoneWidth)
      {
         filteredByWidth++;
         continue;
      }

      // Step 4: Create the zone
      SDZone zone;
      zone.type = ZONE_SUPPLY;
      zone.upperPrice = baseHigh;
      zone.lowerPrice = baseLow;
      zone.formationTime = g_timeBuffer[i];
      zone.barIndex = i;
      zone.status = ZONE_FRESH;
      zone.touchCount = 0;
      zone.legOutDistance = legOutDistance;
      zone.baseBodyMax = maxBaseBody;
      zone.atrAtFormation = atr;
      zone.causedBOS = false;
      zone.alignsWithFib = false;

      // Step 5: Calculate zone score
      zone.score = CalculateZoneScoreLocal(legOutDistance, maxBaseBody, true, false, false, atr);
      zone.strength = (double)zone.score / 13.0 * 100.0;

      // Filter by minimum score
      if(zone.score < InpMinScoreToShow)
      {
         filteredByScore++;
         continue;
      }

      // Check if zone should be filtered by EMA
      if(InpFilterByEMA && InpUseEMAFilter)
      {
         if(g_emaResult.trend != BIAS_BEARISH)
            continue;
      }

      // Add zone
      g_supplyZones[g_supplyCount] = zone;
      g_supplyCount++;
      zonesFound++;

      if(InpDebugMode && zonesFound <= 5)
      {
         Print("SUPPLY ZONE ", zonesFound, " at bar ", i, ":");
         Print("  Range: ", DoubleToString(baseLow, g_digits), " - ", DoubleToString(baseHigh, g_digits));
         Print("  Width: $", DoubleToString(zoneWidth, 2), " (", DoubleToString(zoneWidth/atr, 2), "x ATR)");
         Print("  Leg-Out: $", DoubleToString(legOutDistance, 2), " (", DoubleToString(legOutDistance/atr, 2), "x ATR)");
         Print("  Score: ", zone.score, "/13");
      }
   }

   if(InpDebugMode)
   {
      Print("--- Supply Zone Summary ---");
      Print("Zones Found: ", zonesFound);
      Print("Filtered by Leg-Out: ", filteredByLegOut);
      Print("Filtered by Base: ", filteredByBase);
      Print("Filtered by Width: ", filteredByWidth);
      Print("Filtered by Score: ", filteredByScore);
   }
}

//+------------------------------------------------------------------+
//| Calculate Zone Score (Local version) - 0 to 13 points             |
//| Scoring breakdown:                                                 |
//|   - Leg-Out >= 2x ATR: +3 points                                   |
//|   - Base body <= 0.5x ATR: +2 points                               |
//|   - Fresh zone (untested): +5 points (or +2 if tested)             |
//|   - Aligns with Fibonacci level: +1 point                          |
//|   - Caused BOS/CHoCH: +2 points                                    |
//+------------------------------------------------------------------+
int CalculateZoneScoreLocal(double legOutDistance, double baseBodyMax,
                            bool isFresh, bool alignsWithFib,
                            bool causedBOS, double atr)
{
   int score = 0;

   if(atr <= 0) return 0;  // Safety check

   // 1. Leg-Out strength (max 3 points)
   double legOutRatio = legOutDistance / atr;
   if(legOutRatio >= InpLegOutMultiplier)
   {
      score += 3;
      if(InpDebugMode)
         Print("  Score +3: Leg-Out ", DoubleToString(legOutRatio, 2), "x ATR (req: ", InpLegOutMultiplier, "x)");
   }

   // 2. Base quality (max 2 points)
   double baseRatio = baseBodyMax / atr;
   if(baseRatio <= InpBaseMaxMultiplier)
   {
      score += 2;
      if(InpDebugMode)
         Print("  Score +2: Base body ", DoubleToString(baseRatio, 2), "x ATR (max: ", InpBaseMaxMultiplier, "x)");
   }

   // 3. Freshness (max 5 points)
   if(isFresh)
   {
      score += 5;
      if(InpDebugMode)
         Print("  Score +5: Fresh zone (untested)");
   }
   else
   {
      score += 2;
      if(InpDebugMode)
         Print("  Score +2: Tested zone");
   }

   // 4. Fibonacci alignment (max 1 point)
   if(alignsWithFib)
   {
      score += 1;
      if(InpDebugMode)
         Print("  Score +1: Aligns with Fibonacci level");
   }

   // 5. Caused BOS/CHoCH (max 2 points)
   if(causedBOS)
   {
      score += 2;
      if(InpDebugMode)
         Print("  Score +2: Zone caused BOS/CHoCH");
   }

   return score;  // Maximum possible: 13 points
}

//+------------------------------------------------------------------+
//| Check if candle is bullish                                        |
//+------------------------------------------------------------------+
bool IsBullishCandle(int index)
{
   return g_closeBuffer[index] > g_openBuffer[index];
}

//+------------------------------------------------------------------+
//| Check if candle is bearish                                        |
//+------------------------------------------------------------------+
bool IsBearishCandle(int index)
{
   return g_closeBuffer[index] < g_openBuffer[index];
}

//+------------------------------------------------------------------+
//| Check for strong bullish move                                     |
//+------------------------------------------------------------------+
bool IsStrongBullishMove(int startIndex, int numCandles)
{
   if(startIndex < 0 || startIndex + numCandles >= ArraySize(g_closeBuffer))
      return false;

   int bullishCount = 0;
   double totalMove = 0;
   double startPrice = g_openBuffer[startIndex + numCandles - 1];

   // Count bullish candles and calculate move
   for(int i = 0; i < numCandles; i++)
   {
      int idx = startIndex + numCandles - 1 - i;
      if(idx < 0) break;

      if(IsBullishCandle(idx))
         bullishCount++;

      if(i == numCandles - 1)
         totalMove = g_closeBuffer[startIndex] - startPrice;
   }

   // Check if move is significant
   double movePercent = (totalMove / startPrice) * 100;

   // Strong move = majority bullish candles AND significant price move
   // Uses adaptive g_minMovePercent based on instrument type
   return (bullishCount >= (numCandles * 2 / 3)) && (movePercent >= g_minMovePercent);
}

//+------------------------------------------------------------------+
//| Check for strong bearish move                                     |
//+------------------------------------------------------------------+
bool IsStrongBearishMove(int startIndex, int numCandles)
{
   if(startIndex < 0 || startIndex + numCandles >= ArraySize(g_closeBuffer))
      return false;

   int bearishCount = 0;
   double totalMove = 0;
   double startPrice = g_openBuffer[startIndex + numCandles - 1];

   // Count bearish candles and calculate move
   for(int i = 0; i < numCandles; i++)
   {
      int idx = startIndex + numCandles - 1 - i;
      if(idx < 0) break;

      if(IsBearishCandle(idx))
         bearishCount++;

      if(i == numCandles - 1)
         totalMove = startPrice - g_closeBuffer[startIndex];
   }

   // Check if move is significant
   double movePercent = (totalMove / startPrice) * 100;

   // Strong move = majority bearish candles AND significant price move
   // Uses adaptive g_minMovePercent based on instrument type
   return (bearishCount >= (numCandles * 2 / 3)) && (movePercent >= g_minMovePercent);
}

//+------------------------------------------------------------------+
//| Calculate move size                                               |
//+------------------------------------------------------------------+
double CalculateMoveSize(int startIndex, int numCandles, bool bullish)
{
   if(startIndex < 0 || startIndex + numCandles >= ArraySize(g_closeBuffer))
      return 0;

   double startPrice = g_openBuffer[startIndex + numCandles - 1];
   double endPrice = g_closeBuffer[startIndex];

   if(bullish)
      return ((endPrice - startPrice) / startPrice) * 100;
   else
      return ((startPrice - endPrice) / startPrice) * 100;
}

//+------------------------------------------------------------------+
//| Update zone statuses based on price interaction                   |
//+------------------------------------------------------------------+
void UpdateZoneStatuses()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Update demand zones
   for(int i = 0; i < g_demandCount; i++)
   {
      if(g_demandZones[i].status == ZONE_BROKEN)
         continue;

      // Check if price entered the zone
      if(currentPrice <= g_demandZones[i].upperPrice &&
         currentPrice >= g_demandZones[i].lowerPrice)
      {
         if(g_demandZones[i].status == ZONE_FRESH)
         {
            g_demandZones[i].status = ZONE_TESTED;
            g_demandZones[i].touchCount = 1;
         }
         else
         {
            g_demandZones[i].touchCount++;
         }
      }

      // Check if price broke through the zone
      if(currentPrice < g_demandZones[i].lowerPrice)
      {
         g_demandZones[i].status = ZONE_BROKEN;
      }

      // Check max touches
      if(g_demandZones[i].touchCount > InpMaxTouches)
      {
         g_demandZones[i].status = ZONE_BROKEN;
      }
   }

   // Update supply zones
   for(int i = 0; i < g_supplyCount; i++)
   {
      if(g_supplyZones[i].status == ZONE_BROKEN)
         continue;

      // Check if price entered the zone
      if(currentPrice >= g_supplyZones[i].lowerPrice &&
         currentPrice <= g_supplyZones[i].upperPrice)
      {
         if(g_supplyZones[i].status == ZONE_FRESH)
         {
            g_supplyZones[i].status = ZONE_TESTED;
            g_supplyZones[i].touchCount = 1;
         }
         else
         {
            g_supplyZones[i].touchCount++;
         }
      }

      // Check if price broke through the zone
      if(currentPrice > g_supplyZones[i].upperPrice)
      {
         g_supplyZones[i].status = ZONE_BROKEN;
      }

      // Check max touches
      if(g_supplyZones[i].touchCount > InpMaxTouches)
      {
         g_supplyZones[i].status = ZONE_BROKEN;
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Zones on Chart                                               |
//+------------------------------------------------------------------+
void DrawZones()
{
   // Remove old zone objects
   ObjectsDeleteAll(0, "SDZone_");

   datetime chartStart = iTime(_Symbol, InpZoneTimeframe, InpZoneLookback);
   datetime chartEnd = TimeCurrent() + PeriodSeconds(InpZoneTimeframe) * 20;

   // Draw Demand Zones
   for(int i = 0; i < g_demandCount; i++)
   {
      if(InpShowFreshOnly && g_demandZones[i].status != ZONE_FRESH)
         continue;

      if(g_demandZones[i].status == ZONE_BROKEN)
         continue;

      string name = "SDZone_Demand_" + IntegerToString(i);
      color zoneColor = (g_demandZones[i].status == ZONE_FRESH) ?
                        InpDemandColor : InpTestedZoneColor;

      // Create rectangle
      ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                   g_demandZones[i].formationTime, g_demandZones[i].upperPrice,
                   chartEnd, g_demandZones[i].lowerPrice);
      ObjectSetInteger(0, name, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);

      // Add label with score
      string labelName = "SDZone_Demand_Label_" + IntegerToString(i);
      ObjectCreate(0, labelName, OBJ_TEXT, 0,
                   g_demandZones[i].formationTime, g_demandZones[i].upperPrice);
      string labelText = "DEMAND [" + IntegerToString(g_demandZones[i].score) + "/13]";
      if(g_demandZones[i].status == ZONE_TESTED)
         labelText += " T:" + IntegerToString(g_demandZones[i].touchCount);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   }

   // Draw Supply Zones
   for(int i = 0; i < g_supplyCount; i++)
   {
      if(InpShowFreshOnly && g_supplyZones[i].status != ZONE_FRESH)
         continue;

      if(g_supplyZones[i].status == ZONE_BROKEN)
         continue;

      string name = "SDZone_Supply_" + IntegerToString(i);
      color zoneColor = (g_supplyZones[i].status == ZONE_FRESH) ?
                        InpSupplyColor : InpTestedZoneColor;

      // Create rectangle
      ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                   g_supplyZones[i].formationTime, g_supplyZones[i].upperPrice,
                   chartEnd, g_supplyZones[i].lowerPrice);
      ObjectSetInteger(0, name, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);

      // Add label with score
      string labelName = "SDZone_Supply_Label_" + IntegerToString(i);
      ObjectCreate(0, labelName, OBJ_TEXT, 0,
                   g_supplyZones[i].formationTime, g_supplyZones[i].lowerPrice);
      string labelText = "SUPPLY [" + IntegerToString(g_supplyZones[i].score) + "/13]";
      if(g_supplyZones[i].status == ZONE_TESTED)
         labelText += " T:" + IntegerToString(g_supplyZones[i].touchCount);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Get nearest demand zone to current price                          |
//+------------------------------------------------------------------+
SDZone GetNearestDemandZone()
{
   SDZone nearest;
   nearest.strength = 0;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double minDistance = DBL_MAX;

   for(int i = 0; i < g_demandCount; i++)
   {
      if(g_demandZones[i].status == ZONE_BROKEN)
         continue;

      double distance = currentPrice - g_demandZones[i].upperPrice;
      if(distance > 0 && distance < minDistance)
      {
         minDistance = distance;
         nearest = g_demandZones[i];
      }
   }

   return nearest;
}

//+------------------------------------------------------------------+
//| Get nearest supply zone to current price                          |
//+------------------------------------------------------------------+
SDZone GetNearestSupplyZone()
{
   SDZone nearest;
   nearest.strength = 0;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double minDistance = DBL_MAX;

   for(int i = 0; i < g_supplyCount; i++)
   {
      if(g_supplyZones[i].status == ZONE_BROKEN)
         continue;

      double distance = g_supplyZones[i].lowerPrice - currentPrice;
      if(distance > 0 && distance < minDistance)
      {
         minDistance = distance;
         nearest = g_supplyZones[i];
      }
   }

   return nearest;
}

//+------------------------------------------------------------------+
//| Print Zone Report                                                 |
//+------------------------------------------------------------------+
void PrintZoneReport()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   Print("");
   Print("=================================================");
   Print("    SUPPLY/DEMAND ZONE REPORT (Section 4)        ");
   Print("=================================================");
   Print("Symbol: ", _Symbol, " (", g_instrumentType, ")");
   Print("Timeframe: ", TimeframeToString(InpZoneTimeframe));
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Current Price: ", DoubleToString(currentPrice, g_digits));
   Print("-------------------------------------------------");

   // ATR Math Settings
   Print("ATR MATH SETTINGS:");
   Print("  Leg-Out Required: >= ", InpLegOutMultiplier, "x ATR");
   Print("  Base Body Max: <= ", InpBaseMaxMultiplier, "x ATR");
   Print("  Max Zone Width: <= ", InpMaxZoneWidthATR, "x ATR");
   Print("  Min Score Required: ", InpMinScoreToShow, "/13");
   Print("-------------------------------------------------");

   // ATR Status
   if(InpUseATRFilter)
   {
      Print("ATR FILTER:");
      Print("  ATR Value: ", DoubleToString(g_atrResult.atrValue, 2), " pips");
      Print("  Condition: ", MarketConditionToString(g_atrResult.condition));
      Print("-------------------------------------------------");
   }

   // EMA Status
   if(InpUseEMAFilter)
   {
      Print("EMA TREND:");
      Print("  EMA 50: ", DoubleToString(g_emaResult.ema50, g_digits));
      Print("  EMA 200: ", DoubleToString(g_emaResult.ema200, g_digits));
      Print("  Trend: ", TrendBiasToString(g_emaResult.trend));
      Print("-------------------------------------------------");
   }

   // Demand Zones
   Print("DEMAND ZONES (Buy Zones):");
   int freshDemand = 0, testedDemand = 0;
   for(int i = 0; i < g_demandCount; i++)
   {
      if(g_demandZones[i].status == ZONE_FRESH) freshDemand++;
      else if(g_demandZones[i].status == ZONE_TESTED) testedDemand++;
   }
   Print("  Total: ", g_demandCount, " (Fresh: ", freshDemand, ", Tested: ", testedDemand, ")");

   for(int i = 0; i < g_demandCount && i < 5; i++)
   {
      if(g_demandZones[i].status == ZONE_BROKEN) continue;
      string statusStr = (g_demandZones[i].status == ZONE_FRESH) ? "FRESH" : "TESTED";
      double zoneWidth = g_demandZones[i].upperPrice - g_demandZones[i].lowerPrice;
      Print("  Zone ", i+1, ": ", DoubleToString(g_demandZones[i].lowerPrice, g_digits),
            " - ", DoubleToString(g_demandZones[i].upperPrice, g_digits), " [", statusStr, "]");
      Print("    Score: ", g_demandZones[i].score, "/13 | Width: $", DoubleToString(zoneWidth, 2));
      Print("    Leg-Out: $", DoubleToString(g_demandZones[i].legOutDistance, 2),
            " (", DoubleToString(g_demandZones[i].legOutDistance / g_demandZones[i].atrAtFormation, 2), "x ATR)");
      Print("    Base Body: $", DoubleToString(g_demandZones[i].baseBodyMax, 2),
            " (", DoubleToString(g_demandZones[i].baseBodyMax / g_demandZones[i].atrAtFormation, 2), "x ATR)");
   }
   Print("-------------------------------------------------");

   // Supply Zones
   Print("SUPPLY ZONES (Sell Zones):");
   int freshSupply = 0, testedSupply = 0;
   for(int i = 0; i < g_supplyCount; i++)
   {
      if(g_supplyZones[i].status == ZONE_FRESH) freshSupply++;
      else if(g_supplyZones[i].status == ZONE_TESTED) testedSupply++;
   }
   Print("  Total: ", g_supplyCount, " (Fresh: ", freshSupply, ", Tested: ", testedSupply, ")");

   for(int i = 0; i < g_supplyCount && i < 5; i++)
   {
      if(g_supplyZones[i].status == ZONE_BROKEN) continue;
      string statusStr = (g_supplyZones[i].status == ZONE_FRESH) ? "FRESH" : "TESTED";
      double zoneWidth = g_supplyZones[i].upperPrice - g_supplyZones[i].lowerPrice;
      Print("  Zone ", i+1, ": ", DoubleToString(g_supplyZones[i].lowerPrice, g_digits),
            " - ", DoubleToString(g_supplyZones[i].upperPrice, g_digits), " [", statusStr, "]");
      Print("    Score: ", g_supplyZones[i].score, "/13 | Width: $", DoubleToString(zoneWidth, 2));
      Print("    Leg-Out: $", DoubleToString(g_supplyZones[i].legOutDistance, 2),
            " (", DoubleToString(g_supplyZones[i].legOutDistance / g_supplyZones[i].atrAtFormation, 2), "x ATR)");
      Print("    Base Body: $", DoubleToString(g_supplyZones[i].baseBodyMax, 2),
            " (", DoubleToString(g_supplyZones[i].baseBodyMax / g_supplyZones[i].atrAtFormation, 2), "x ATR)");
   }
   Print("-------------------------------------------------");

   // Nearest Zones
   SDZone nearestDemand = GetNearestDemandZone();
   SDZone nearestSupply = GetNearestSupplyZone();

   Print("NEAREST ZONES:");
   if(nearestDemand.strength > 0)
   {
      double distDemand = currentPrice - nearestDemand.upperPrice;
      Print("  Nearest Demand: ", DoubleToString(nearestDemand.upperPrice, g_digits),
            " (", DoubleToString(distDemand, g_digits), " away)");
   }
   else
      Print("  Nearest Demand: None found");

   if(nearestSupply.strength > 0)
   {
      double distSupply = nearestSupply.lowerPrice - currentPrice;
      Print("  Nearest Supply: ", DoubleToString(nearestSupply.lowerPrice, g_digits),
            " (", DoubleToString(distSupply, g_digits), " away)");
   }
   else
      Print("  Nearest Supply: None found");

   Print("-------------------------------------------------");

   // Trading Recommendation
   Print("TRADING RECOMMENDATION:");
   PrintTradingRecommendation(nearestDemand, nearestSupply, currentPrice);
   Print("=================================================");
   Print("");
}

//+------------------------------------------------------------------+
//| Print Trading Recommendation                                      |
//+------------------------------------------------------------------+
void PrintTradingRecommendation(SDZone &demandZone, SDZone &supplyZone, double currentPrice)
{
   // Check ATR filter
   if(InpUseATRFilter && !g_atrResult.tradingAllowed)
   {
      Print("  STATUS: NO TRADE");
      Print("  REASON: Market too quiet (ATR filter)");
      return;
   }

   // Check if price is in a zone
   bool inDemandZone = false;
   bool inSupplyZone = false;

   for(int i = 0; i < g_demandCount; i++)
   {
      if(g_demandZones[i].status != ZONE_BROKEN &&
         currentPrice <= g_demandZones[i].upperPrice &&
         currentPrice >= g_demandZones[i].lowerPrice)
      {
         inDemandZone = true;
         break;
      }
   }

   for(int i = 0; i < g_supplyCount; i++)
   {
      if(g_supplyZones[i].status != ZONE_BROKEN &&
         currentPrice >= g_supplyZones[i].lowerPrice &&
         currentPrice <= g_supplyZones[i].upperPrice)
      {
         inSupplyZone = true;
         break;
      }
   }

   if(inDemandZone)
   {
      Print("  STATUS: POTENTIAL BUY ZONE");
      Print("  REASON: Price is in demand zone");
      Print("  ACTION: Look for bullish confirmation (BOS, engulfing, etc.)");
      if(InpUseEMAFilter && g_emaResult.trend == BIAS_BULLISH)
         Print("  CONFLUENCE: EMA trend aligns (Bullish)");
      return;
   }

   if(inSupplyZone)
   {
      Print("  STATUS: POTENTIAL SELL ZONE");
      Print("  REASON: Price is in supply zone");
      Print("  ACTION: Look for bearish confirmation (BOS, engulfing, etc.)");
      if(InpUseEMAFilter && g_emaResult.trend == BIAS_BEARISH)
         Print("  CONFLUENCE: EMA trend aligns (Bearish)");
      return;
   }

   // Price not in any zone
   Print("  STATUS: WAIT FOR ZONE");
   Print("  REASON: Price not at key S/D level");

   if(demandZone.strength > 0)
      Print("  WATCH: Demand zone at ", DoubleToString(demandZone.upperPrice, g_digits));
   if(supplyZone.strength > 0)
      Print("  WATCH: Supply zone at ", DoubleToString(supplyZone.lowerPrice, g_digits));
}

//+------------------------------------------------------------------+
//| Print Initialization Report                                       |
//+------------------------------------------------------------------+
void PrintInitReport()
{
   Print("");
   Print("=================================================");
   Print("     SWING TRADER PRO - SECTION 4                ");
   Print("     SUPPLY/DEMAND ZONE DETECTION                ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol, " (", g_instrumentType, ")");
   Print("TIMEFRAME: ", TimeframeToString(InpZoneTimeframe));
   Print("-------------------------------------------------");
   Print("INSTRUMENT SETTINGS:");
   Print("  Instrument Type: ", g_instrumentType);
   Print("  Pip Size: ", DoubleToString(g_pipSize, 4));
   Print("-------------------------------------------------");
   Print("ATR MATH SETTINGS (SMC Best Practice):");
   Print("  Leg-Out Required: >= ", InpLegOutMultiplier, "x ATR");
   Print("  Base Body Max: <= ", InpBaseMaxMultiplier, "x ATR");
   Print("  Max Zone Width: <= ", InpMaxZoneWidthATR, "x ATR");
   Print("  Base Candles: ", InpBaseCandles);
   Print("  Min Score to Show: ", InpMinScoreToShow, "/13");
   Print("-------------------------------------------------");
   Print("ZONE DETECTION SETTINGS:");
   Print("  Lookback: ", InpZoneLookback, " candles");
   Print("  Max Zones: ", InpMaxZones);
   Print("-------------------------------------------------");
   Print("SCORING SYSTEM (0-13 points):");
   Print("  +3: Leg-Out >= ", InpLegOutMultiplier, "x ATR");
   Print("  +2: Base body <= ", InpBaseMaxMultiplier, "x ATR");
   Print("  +5: Fresh zone (untested)");
   Print("  +2: Tested zone");
   Print("  +1: Aligns with Fibonacci");
   Print("  +2: Caused BOS/CHoCH");
   Print("-------------------------------------------------");
   Print("ALERT SETTINGS:");
   Print("  Zone Entry Alerts: ", InpAlertOnZoneEntry ? "ON" : "OFF");
   Print("  Push Notifications: ", InpPushNotification ? "ON" : "OFF");
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

   CreateRectangle(g_panelName + "_bg", x, y, 320, 280, clrBlack, 200);

   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "SUPPLY/DEMAND ZONES", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "------------------------------------", clrGray, 8, "Courier New");

   int yOff = 40;

   // Instrument Type
   CreateLabel(g_panelName + "_inst_label", x + 10, y + yOff, "Instrument:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_inst_value", x + 120, y + yOff, g_instrumentType, clrCyan, 9, "Arial Bold");
   yOff += 20;

   // ATR Status
   if(InpUseATRFilter)
   {
      CreateLabel(g_panelName + "_atr_label", x + 10, y + yOff, "ATR:", clrWhite, 9, "Arial");
      CreateLabel(g_panelName + "_atr_value", x + 120, y + yOff, "-- pips", clrYellow, 9, "Arial");
      CreateLabel(g_panelName + "_atr_status", x + 220, y + yOff, "[--]", clrGray, 9, "Arial Bold");
      yOff += 20;
   }

   // EMA Status
   if(InpUseEMAFilter)
   {
      CreateLabel(g_panelName + "_ema_label", x + 10, y + yOff, "EMA Trend:", clrWhite, 9, "Arial");
      CreateLabel(g_panelName + "_ema_value", x + 120, y + yOff, "--", clrYellow, 9, "Arial Bold");
      yOff += 20;
   }

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Current Price
   CreateLabel(g_panelName + "_price_label", x + 10, y + yOff, "Price:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_price_value", x + 120, y + yOff, "--", clrWhite, 9, "Arial Bold");
   yOff += 20;

   // Demand Zones
   CreateLabel(g_panelName + "_demand_label", x + 10, y + yOff, "Demand Zones:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_demand_value", x + 150, y + yOff, "0", InpDemandColor, 9, "Arial Bold");
   yOff += 20;

   // Supply Zones
   CreateLabel(g_panelName + "_supply_label", x + 10, y + yOff, "Supply Zones:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_supply_value", x + 150, y + yOff, "0", InpSupplyColor, 9, "Arial Bold");
   yOff += 20;

   CreateLabel(g_panelName + "_sep3", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Nearest Demand
   CreateLabel(g_panelName + "_nd_label", x + 10, y + yOff, "Near Demand:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_nd_value", x + 120, y + yOff, "--", InpDemandColor, 9, "Arial");
   yOff += 20;

   // Nearest Supply
   CreateLabel(g_panelName + "_ns_label", x + 10, y + yOff, "Near Supply:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_ns_value", x + 120, y + yOff, "--", InpSupplyColor, 9, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_sep4", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Zone Status
   CreateLabel(g_panelName + "_zone_label", x + 10, y + yOff, "Price in Zone:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_zone_value", x + 120, y + yOff, "NO", clrGray, 9, "Arial Bold");
   yOff += 20;

   // Recommendation
   CreateLabel(g_panelName + "_rec_label", x + 10, y + yOff, "Action:", clrWhite, 10, "Arial Bold");
   CreateLabel(g_panelName + "_rec_value", x + 120, y + yOff, "ANALYZING...", clrYellow, 10, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel) return;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Update ATR
   if(InpUseATRFilter)
   {
      ObjectSetString(0, g_panelName + "_atr_value", OBJPROP_TEXT,
                      DoubleToString(g_atrResult.atrValue, 1) + " pips");

      string atrStatus = "";
      color atrColor = clrGray;
      switch(g_atrResult.condition)
      {
         case MARKET_QUIET:   atrStatus = "[QUIET]";   atrColor = clrGray; break;
         case MARKET_NORMAL:  atrStatus = "[NORMAL]";  atrColor = clrLimeGreen; break;
         case MARKET_EXTREME: atrStatus = "[EXTREME]"; atrColor = clrOrange; break;
      }
      ObjectSetString(0, g_panelName + "_atr_status", OBJPROP_TEXT, atrStatus);
      ObjectSetInteger(0, g_panelName + "_atr_status", OBJPROP_COLOR, atrColor);
   }

   // Update EMA
   if(InpUseEMAFilter)
   {
      string emaTrend = TrendBiasToString(g_emaResult.trend);
      color emaColor = clrGray;
      if(g_emaResult.trend == BIAS_BULLISH) emaColor = clrLimeGreen;
      else if(g_emaResult.trend == BIAS_BEARISH) emaColor = clrRed;

      ObjectSetString(0, g_panelName + "_ema_value", OBJPROP_TEXT, emaTrend);
      ObjectSetInteger(0, g_panelName + "_ema_value", OBJPROP_COLOR, emaColor);
   }

   // Update price
   ObjectSetString(0, g_panelName + "_price_value", OBJPROP_TEXT,
                   DoubleToString(currentPrice, g_digits));

   // Update zone counts
   int activeDemand = 0, activeSupply = 0;
   for(int i = 0; i < g_demandCount; i++)
      if(g_demandZones[i].status != ZONE_BROKEN) activeDemand++;
   for(int i = 0; i < g_supplyCount; i++)
      if(g_supplyZones[i].status != ZONE_BROKEN) activeSupply++;

   ObjectSetString(0, g_panelName + "_demand_value", OBJPROP_TEXT, IntegerToString(activeDemand));
   ObjectSetString(0, g_panelName + "_supply_value", OBJPROP_TEXT, IntegerToString(activeSupply));

   // Update nearest zones with scores
   SDZone nearestDemand = GetNearestDemandZone();
   SDZone nearestSupply = GetNearestSupplyZone();

   if(nearestDemand.strength > 0 || nearestDemand.score > 0)
   {
      string demandText = DoubleToString(nearestDemand.upperPrice, g_digits) +
                          " [" + IntegerToString(nearestDemand.score) + "]";
      ObjectSetString(0, g_panelName + "_nd_value", OBJPROP_TEXT, demandText);
   }
   else
      ObjectSetString(0, g_panelName + "_nd_value", OBJPROP_TEXT, "None");

   if(nearestSupply.strength > 0 || nearestSupply.score > 0)
   {
      string supplyText = DoubleToString(nearestSupply.lowerPrice, g_digits) +
                          " [" + IntegerToString(nearestSupply.score) + "]";
      ObjectSetString(0, g_panelName + "_ns_value", OBJPROP_TEXT, supplyText);
   }
   else
      ObjectSetString(0, g_panelName + "_ns_value", OBJPROP_TEXT, "None");

   // Check if price is in zone
   bool inDemand = false, inSupply = false;
   for(int i = 0; i < g_demandCount; i++)
   {
      if(g_demandZones[i].status != ZONE_BROKEN &&
         currentPrice <= g_demandZones[i].upperPrice &&
         currentPrice >= g_demandZones[i].lowerPrice)
      {
         inDemand = true;
         break;
      }
   }
   for(int i = 0; i < g_supplyCount; i++)
   {
      if(g_supplyZones[i].status != ZONE_BROKEN &&
         currentPrice >= g_supplyZones[i].lowerPrice &&
         currentPrice <= g_supplyZones[i].upperPrice)
      {
         inSupply = true;
         break;
      }
   }

   string zoneText = "NO";
   color zoneColor = clrGray;
   if(inDemand)
   {
      zoneText = "DEMAND";
      zoneColor = InpDemandColor;
   }
   else if(inSupply)
   {
      zoneText = "SUPPLY";
      zoneColor = InpSupplyColor;
   }

   ObjectSetString(0, g_panelName + "_zone_value", OBJPROP_TEXT, zoneText);
   ObjectSetInteger(0, g_panelName + "_zone_value", OBJPROP_COLOR, zoneColor);

   // Update recommendation
   string recText = "";
   color recColor = clrGray;

   if(InpUseATRFilter && !g_atrResult.tradingAllowed)
   {
      recText = "NO TRADE (ATR)";
      recColor = clrGray;
   }
   else if(inDemand)
   {
      recText = "BUY ZONE - Confirm";
      recColor = InpDemandColor;
   }
   else if(inSupply)
   {
      recText = "SELL ZONE - Confirm";
      recColor = InpSupplyColor;
   }
   else
   {
      recText = "WAIT FOR ZONE";
      recColor = clrYellow;
   }

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
int GetDemandZoneCount() { return g_demandCount; }
int GetSupplyZoneCount() { return g_supplyCount; }
SDZone GetDemandZone(int index) { return (index < g_demandCount) ? g_demandZones[index] : g_demandZones[0]; }
SDZone GetSupplyZone(int index) { return (index < g_supplyCount) ? g_supplyZones[index] : g_supplyZones[0]; }
bool IsPriceInDemandZone() { return g_wasInDemandZone; }
bool IsPriceInSupplyZone() { return g_wasInSupplyZone; }
string GetInstrumentType() { return g_instrumentType; }
//+------------------------------------------------------------------+
