//+------------------------------------------------------------------+
//|                                       Section02_EMAAnalysis.mq5  |
//|                                      SwingTrader Pro EA          |
//|                    Section 2: EMA Trend Analysis (50/200)        |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "2.00"
#property description "Section 2: EMA Analysis (Improved)"
#property description "EMA 50/200 for H4 trend bias detection"
#property description "Includes crossover detection, slope analysis, and visual lines"
#property description "Fixed: Gold ATR calculation, optimized drawing, enhanced crossover"

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== EMA Settings ==="
input int      InpEMAFastPeriod       = 50;       // EMA Fast Period
input int      InpEMASlowPeriod       = 200;      // EMA Slow Period
input ENUM_TIMEFRAMES InpEMATimeframe = PERIOD_H4; // EMA Analysis Timeframe
input int      InpCrossoverLookback   = 10;       // Crossover Lookback (candles)
input ENUM_APPLIED_PRICE InpEMAPrice  = PRICE_CLOSE; // Applied Price
input int      InpSlopePeriod         = 5;        // Slope Calculation Period

input group "=== ATR Filter Settings ==="
input bool     InpUseATRFilter        = true;     // Enable ATR Filter
input int      InpATRPeriod           = 14;       // ATR Period
input double   InpATRQuietThreshold   = 60.0;     // Quiet Market Threshold (pips)
input double   InpATRExtremeThreshold = 250.0;    // Extreme Volatility Threshold (pips)

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;     // Show Info Panel on Chart
input bool     InpShowEMALines        = true;     // Show EMA Lines on Chart
input int      InpEMALineBars         = 100;      // EMA Lines History (bars) [Max 200]
input color    InpEMAFastColor        = clrDodgerBlue;  // EMA Fast Color
input color    InpEMASlowColor        = clrOrangeRed;   // EMA Slow Color
input int      InpEMALineWidth        = 2;        // EMA Line Width
input color    InpBullishColor        = clrLimeGreen;   // Bullish Trend Color
input color    InpBearishColor        = clrRed;         // Bearish Trend Color
input color    InpNeutralColor        = clrGray;        // Neutral Trend Color
input int      InpPanelX              = 20;       // Panel X Position
input int      InpPanelY              = 30;       // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;     // Print Report to Experts Tab
input int      InpHistoryBars         = 300;      // Historical Bars to Analyze

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
// Indicator handles
int            g_emaFastHandle;                   // EMA Fast handle
int            g_emaSlowHandle;                   // EMA Slow handle
int            g_atrHandle;                       // ATR handle

// Buffers
double         g_emaFastBuffer[];                 // EMA Fast values
double         g_emaSlowBuffer[];                 // EMA Slow values
double         g_atrBuffer[];                     // ATR values

// Results
EMAAnalysisResult g_emaResult;                    // Current EMA analysis
ATRFilterResult   g_atrResult;                    // Current ATR filter result

// Symbol Info
SymbolInfoCache   g_symbolInfo;                   // Cached symbol information

// Panel
string         g_panelName = "EMAAnalysisPanel";  // Panel object prefix

// Performance tracking
int            g_lastDrawnBars = 0;               // Track drawn bar count
datetime       g_lastAnalysisTime = 0;            // Last analysis timestamp

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize symbol info cache
   InitSymbolInfo(g_symbolInfo, _Symbol);

   PrintFormat("Symbol Detection: %s | Digits: %d | PipSize: %.5f | IsGold: %s",
               _Symbol, g_symbolInfo.digits, g_symbolInfo.pipSize,
               g_symbolInfo.isGold ? "YES" : "NO");

   // Create indicator handles
   g_emaFastHandle = iMA(_Symbol, InpEMATimeframe, InpEMAFastPeriod, 0, MODE_EMA, InpEMAPrice);
   g_emaSlowHandle = iMA(_Symbol, InpEMATimeframe, InpEMASlowPeriod, 0, MODE_EMA, InpEMAPrice);

   if(g_emaFastHandle == INVALID_HANDLE || g_emaSlowHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create EMA indicator handles");
      return(INIT_FAILED);
   }

   // Create ATR handle if filter enabled
   if(InpUseATRFilter)
   {
      g_atrHandle = iATR(_Symbol, InpEMATimeframe, InpATRPeriod);
      if(g_atrHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR indicator handle");
         return(INIT_FAILED);
      }
      ArraySetAsSeries(g_atrBuffer, true);
   }

   // Set buffers as series
   ArraySetAsSeries(g_emaFastBuffer, true);
   ArraySetAsSeries(g_emaSlowBuffer, true);

   // Print initialization
   PrintInitReport();

   // Create panel
   if(InpShowPanel)
      CreatePanel();

   // Wait for data then run initial analysis
   Sleep(500);

   if(!AnalyzeEMA())
   {
      Print("WARNING: Initial analysis incomplete - waiting for data");
   }

   // Draw EMA lines AFTER analysis
   if(InpShowEMALines)
      DrawEMALines();

   // Update panel with initial values (FIX: was missing this call)
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
   ObjectsDeleteAll(0, "EMA_");

   Print("=================================================");
   Print("EMA Analysis EA Deinitialized - Reason: ", GetDeinitReasonText(reason));
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Get Deinit Reason Text                                            |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
{
   switch(reason)
   {
      case REASON_PROGRAM:     return "Expert removed from chart";
      case REASON_REMOVE:      return "Expert removed from chart";
      case REASON_RECOMPILE:   return "Expert recompiled";
      case REASON_CHARTCHANGE: return "Symbol or timeframe changed";
      case REASON_CHARTCLOSE:  return "Chart closed";
      case REASON_PARAMETERS:  return "Input parameters changed";
      case REASON_ACCOUNT:     return "Account changed";
      case REASON_TEMPLATE:    return "Template applied";
      case REASON_INITFAILED:  return "Init failed";
      case REASON_CLOSE:       return "Terminal closed";
      default:                 return "Unknown reason";
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar on EMA timeframe
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpEMATimeframe, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;

      // Perform analysis
      if(AnalyzeEMA())
      {
         // Update visuals only on successful analysis
         if(InpShowPanel) UpdatePanel();
         if(InpShowEMALines) DrawEMALines();
      }
   }
}

//+------------------------------------------------------------------+
//| Main EMA Analysis Function                                        |
//+------------------------------------------------------------------+
bool AnalyzeEMA()
{
   // Determine how many bars we actually need
   int barsNeeded = MathMax(InpHistoryBars, InpCrossoverLookback + InpSlopePeriod + 5);

   // Copy EMA buffers
   int copied1 = CopyBuffer(g_emaFastHandle, 0, 0, barsNeeded, g_emaFastBuffer);
   int copied2 = CopyBuffer(g_emaSlowHandle, 0, 0, barsNeeded, g_emaSlowBuffer);

   // Validate data
   int minRequired = InpCrossoverLookback + InpSlopePeriod + 2;
   if(copied1 < minRequired || copied2 < minRequired)
   {
      PrintFormat("WARNING: Insufficient EMA data. Fast: %d, Slow: %d, Required: %d",
                  copied1, copied2, minRequired);
      g_emaResult.isValid = false;
      return false;
   }

   // ATR Filter check
   if(InpUseATRFilter)
   {
      if(!AnalyzeATR())
      {
         Print("WARNING: ATR analysis failed");
      }
   }

   // Store current values
   g_emaResult.ema50 = g_emaFastBuffer[0];
   g_emaResult.ema200 = g_emaSlowBuffer[0];
   g_emaResult.emaGap = g_emaResult.ema50 - g_emaResult.ema200;
   g_emaResult.emaGapPercent = (g_emaResult.emaGap / g_emaResult.ema200) * 100.0;
   g_emaResult.timestamp = TimeCurrent();
   g_emaResult.isValid = true;

   // Get current price for position analysis
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_emaResult.priceAboveEMA50 = (currentPrice > g_emaResult.ema50);
   g_emaResult.priceAboveEMA200 = (currentPrice > g_emaResult.ema200);

   // Calculate slopes
   CalculateSlopes();

   // Determine trend bias
   DetermineTrendBias(currentPrice);

   // Check for recent crossover (enhanced)
   DetectCrossover();

   // Mark analysis time
   g_lastAnalysisTime = TimeCurrent();

   // Print report
   if(InpPrintReport)
      PrintEMAReport();

   return true;
}

//+------------------------------------------------------------------+
//| Analyze ATR - FIXED for Gold/Silver                               |
//+------------------------------------------------------------------+
bool AnalyzeATR()
{
   int copied = CopyBuffer(g_atrHandle, 0, 0, 1, g_atrBuffer);

   if(copied < 1)
   {
      Print("ERROR: Failed to copy ATR buffer");
      g_atrResult.tradingAllowed = false;
      g_atrResult.reason = "ATR data unavailable";
      return false;
   }

   // Store raw ATR in points
   g_atrResult.atrPoints = g_atrBuffer[0];

   // Convert to pips using proper symbol-aware calculation
   g_atrResult.atrValue = PointsToPips(g_symbolInfo, g_atrResult.atrPoints);
   g_atrResult.timestamp = TimeCurrent();

   // Debug output for verification
   static datetime lastDebug = 0;
   if(TimeCurrent() - lastDebug > 3600) // Once per hour
   {
      PrintFormat("ATR Debug: Raw=%.5f, PipSize=%.5f, ATR_Pips=%.2f",
                  g_atrResult.atrPoints, g_symbolInfo.pipSize, g_atrResult.atrValue);
      lastDebug = TimeCurrent();
   }

   // Classify market condition
   if(g_atrResult.atrValue < InpATRQuietThreshold)
   {
      g_atrResult.condition = MARKET_QUIET;
      g_atrResult.tradingAllowed = false;
      g_atrResult.reason = StringFormat("Market too quiet (ATR %.1f < %.1f pips)",
                                        g_atrResult.atrValue, InpATRQuietThreshold);
   }
   else if(g_atrResult.atrValue > InpATRExtremeThreshold)
   {
      g_atrResult.condition = MARKET_EXTREME;
      g_atrResult.tradingAllowed = true;
      g_atrResult.reason = StringFormat("Extreme volatility (ATR %.1f) - reduce position size",
                                        g_atrResult.atrValue);
   }
   else
   {
      g_atrResult.condition = MARKET_NORMAL;
      g_atrResult.tradingAllowed = true;
      g_atrResult.reason = "Normal market conditions";
   }

   return true;
}

//+------------------------------------------------------------------+
//| Calculate EMA Slopes                                              |
//+------------------------------------------------------------------+
void CalculateSlopes()
{
   int bufferSize = ArraySize(g_emaFastBuffer);

   if(bufferSize < InpSlopePeriod + 1)
   {
      g_emaResult.ema50Slope = 0;
      g_emaResult.ema200Slope = 0;
      g_emaResult.ema50SlopeDir = SLOPE_FLAT;
      g_emaResult.ema200SlopeDir = SLOPE_FLAT;
      return;
   }

   // Calculate EMA50 slope (percentage change over period)
   double ema50Change = g_emaFastBuffer[0] - g_emaFastBuffer[InpSlopePeriod];
   g_emaResult.ema50Slope = (ema50Change / g_emaFastBuffer[InpSlopePeriod]) * 100.0;

   // Calculate EMA200 slope
   double ema200Change = g_emaSlowBuffer[0] - g_emaSlowBuffer[InpSlopePeriod];
   g_emaResult.ema200Slope = (ema200Change / g_emaSlowBuffer[InpSlopePeriod]) * 100.0;

   // Define slope threshold (0.05% is considered flat)
   double slopeThreshold = 0.05;

   // Classify EMA50 slope direction
   if(g_emaResult.ema50Slope > slopeThreshold)
      g_emaResult.ema50SlopeDir = SLOPE_RISING;
   else if(g_emaResult.ema50Slope < -slopeThreshold)
      g_emaResult.ema50SlopeDir = SLOPE_FALLING;
   else
      g_emaResult.ema50SlopeDir = SLOPE_FLAT;

   // Classify EMA200 slope direction
   if(g_emaResult.ema200Slope > slopeThreshold)
      g_emaResult.ema200SlopeDir = SLOPE_RISING;
   else if(g_emaResult.ema200Slope < -slopeThreshold)
      g_emaResult.ema200SlopeDir = SLOPE_FALLING;
   else
      g_emaResult.ema200SlopeDir = SLOPE_FLAT;

   // Combined slope strength (average of absolute slopes)
   g_emaResult.slopeStrength = (MathAbs(g_emaResult.ema50Slope) + MathAbs(g_emaResult.ema200Slope)) / 2.0;
}

//+------------------------------------------------------------------+
//| Determine Trend Bias                                              |
//+------------------------------------------------------------------+
void DetermineTrendBias(double currentPrice)
{
   double emaFast = g_emaResult.ema50;
   double emaSlow = g_emaResult.ema200;

   // Calculate EMA difference as percentage
   double emaDiffPercent = MathAbs(g_emaResult.emaGapPercent);

   // Threshold for "too close" - EMAs within 0.1% considered neutral
   double threshold = 0.1;

   if(emaDiffPercent < threshold)
   {
      // EMAs are too close - consolidation/neutral
      g_emaResult.trend = BIAS_NEUTRAL;
   }
   else if(emaFast > emaSlow)
   {
      // EMA50 above EMA200 - potential bullish
      if(currentPrice >= emaFast)
      {
         // Price above both EMAs - confirmed bullish
         g_emaResult.trend = BIAS_BULLISH;
      }
      else if(currentPrice >= emaSlow)
      {
         // Price between EMAs - pullback but still bullish context
         // Check slope for confirmation
         if(g_emaResult.ema50SlopeDir == SLOPE_RISING)
            g_emaResult.trend = BIAS_BULLISH;
         else
            g_emaResult.trend = BIAS_NEUTRAL; // Weakening
      }
      else
      {
         // Price below both but fast > slow - potential reversal or deep pullback
         g_emaResult.trend = BIAS_NEUTRAL;
      }
   }
   else
   {
      // EMA50 below EMA200 - potential bearish
      if(currentPrice <= emaFast)
      {
         // Price below both EMAs - confirmed bearish
         g_emaResult.trend = BIAS_BEARISH;
      }
      else if(currentPrice <= emaSlow)
      {
         // Price between EMAs - pullback but still bearish context
         // Check slope for confirmation
         if(g_emaResult.ema50SlopeDir == SLOPE_FALLING)
            g_emaResult.trend = BIAS_BEARISH;
         else
            g_emaResult.trend = BIAS_NEUTRAL; // Weakening
      }
      else
      {
         // Price above both but fast < slow - potential reversal or deep pullback
         g_emaResult.trend = BIAS_NEUTRAL;
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Recent Crossover (Enhanced with Confirmation)              |
//+------------------------------------------------------------------+
void DetectCrossover()
{
   g_emaResult.recentCrossover = false;
   g_emaResult.crossoverType = CROSS_NONE;
   g_emaResult.candlesSinceCross = -1;
   g_emaResult.crossoverConfirmed = false;

   int bufferSize = MathMin(ArraySize(g_emaFastBuffer), ArraySize(g_emaSlowBuffer));
   int maxLookback = MathMin(InpCrossoverLookback, bufferSize - 2);

   // Look for crossover in recent candles
   for(int i = 0; i < maxLookback; i++)
   {
      double fastCurrent = g_emaFastBuffer[i];
      double slowCurrent = g_emaSlowBuffer[i];
      double fastPrev = g_emaFastBuffer[i + 1];
      double slowPrev = g_emaSlowBuffer[i + 1];

      // Bullish crossover: Fast crosses above Slow
      bool bullishCross = (fastPrev <= slowPrev) && (fastCurrent > slowCurrent);

      // Bearish crossover: Fast crosses below Slow
      bool bearishCross = (fastPrev >= slowPrev) && (fastCurrent < slowCurrent);

      if(bullishCross || bearishCross)
      {
         g_emaResult.recentCrossover = true;
         g_emaResult.candlesSinceCross = i;
         g_emaResult.crossoverType = bullishCross ? CROSS_BULLISH : CROSS_BEARISH;

         // Check for confirmation (price action after crossover)
         if(i >= 1) // Need at least one bar after cross to confirm
         {
            double closeAtCross = iClose(_Symbol, InpEMATimeframe, i);
            double closeAfter = iClose(_Symbol, InpEMATimeframe, i - 1);
            double highAfter = iHigh(_Symbol, InpEMATimeframe, i - 1);
            double lowAfter = iLow(_Symbol, InpEMATimeframe, i - 1);

            if(bullishCross)
            {
               // Bullish confirmation: price made higher close AND stayed above cross point
               if(closeAfter > closeAtCross && lowAfter > slowCurrent)
                  g_emaResult.crossoverConfirmed = true;
            }
            else
            {
               // Bearish confirmation: price made lower close AND stayed below cross point
               if(closeAfter < closeAtCross && highAfter < slowCurrent)
                  g_emaResult.crossoverConfirmed = true;
            }
         }

         // For very recent crosses (0-1 bars), mark as unconfirmed (need time)
         if(i <= 1)
            g_emaResult.crossoverConfirmed = false;

         break; // Found most recent crossover
      }
   }
}

//+------------------------------------------------------------------+
//| Print EMA Analysis Report                                         |
//+------------------------------------------------------------------+
void PrintEMAReport()
{
   if(!g_emaResult.isValid)
   {
      Print("EMA Report: Analysis data not valid");
      return;
   }

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   Print("");
   Print("=================================================");
   Print("         EMA ANALYSIS REPORT (Section 2)         ");
   Print("                  Version 2.0                    ");
   Print("=================================================");
   Print("Symbol: ", _Symbol, " (", g_symbolInfo.isGold ? "GOLD" : "FOREX", ")");
   Print("Timeframe: ", TimeframeToString(InpEMATimeframe));
   Print("Analysis Time: ", TimeToString(g_emaResult.timestamp, TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");

   // ATR Filter Status (if enabled)
   if(InpUseATRFilter)
   {
      Print("ATR FILTER STATUS:");
      Print("  ATR Value: ", DoubleToString(g_atrResult.atrValue, 2), " pips");
      Print("  ATR Raw: ", DoubleToString(g_atrResult.atrPoints, g_symbolInfo.digits), " points");
      Print("  Condition: ", MarketConditionToString(g_atrResult.condition));
      Print("  Trading: ", g_atrResult.tradingAllowed ? "ALLOWED" : "BLOCKED");
      Print("  Reason: ", g_atrResult.reason);
      Print("-------------------------------------------------");
   }

   Print("EMA VALUES:");
   Print("  EMA ", InpEMAFastPeriod, ": ", DoubleToString(g_emaResult.ema50, g_symbolInfo.digits));
   Print("  EMA ", InpEMASlowPeriod, ": ", DoubleToString(g_emaResult.ema200, g_symbolInfo.digits));
   Print("  EMA Gap: ", DoubleToString(g_emaResult.emaGap, g_symbolInfo.digits),
         " (", DoubleToString(g_emaResult.emaGapPercent, 3), "%)");
   Print("-------------------------------------------------");

   Print("SLOPE ANALYSIS:");
   Print("  EMA", InpEMAFastPeriod, " Slope: ", DoubleToString(g_emaResult.ema50Slope, 4), "% ",
         "(", SlopeDirectionToString(g_emaResult.ema50SlopeDir), ")");
   Print("  EMA", InpEMASlowPeriod, " Slope: ", DoubleToString(g_emaResult.ema200Slope, 4), "% ",
         "(", SlopeDirectionToString(g_emaResult.ema200SlopeDir), ")");
   Print("  Slope Strength: ", DoubleToString(g_emaResult.slopeStrength, 4), "%");
   Print("-------------------------------------------------");

   Print("PRICE POSITION:");
   Print("  Current Price: ", DoubleToString(currentPrice, g_symbolInfo.digits));
   Print("  vs EMA", InpEMAFastPeriod, ": ", g_emaResult.priceAboveEMA50 ? "ABOVE" : "BELOW");
   Print("  vs EMA", InpEMASlowPeriod, ": ", g_emaResult.priceAboveEMA200 ? "ABOVE" : "BELOW");
   Print("  Position: ", GetPricePositionDescription(currentPrice));
   Print("-------------------------------------------------");

   Print("TREND ANALYSIS:");
   Print("  EMA Alignment: ", g_emaResult.ema50 > g_emaResult.ema200 ?
         "BULLISH (EMA50 > EMA200)" : "BEARISH (EMA50 < EMA200)");
   Print("-------------------------------------------------");

   Print("H4 BIAS: >>> ", TrendBiasToString(g_emaResult.trend), " <<<");

   // Crossover info
   Print("-------------------------------------------------");
   Print("CROSSOVER DETECTION:");
   if(g_emaResult.recentCrossover)
   {
      Print("  Recent Crossover: YES");
      Print("  Type: ", CrossoverTypeToString(g_emaResult.crossoverType));
      Print("  Candles Ago: ", g_emaResult.candlesSinceCross);
      Print("  Confirmed: ", g_emaResult.crossoverConfirmed ? "YES" : "NO (wait for confirmation)");

      if(g_emaResult.candlesSinceCross < 3)
         Print("  WARNING: Very recent crossover - trade with caution!");
   }
   else
   {
      Print("  Recent Crossover: NO (within ", InpCrossoverLookback, " candles)");
      Print("  Trend Established: YES");
   }

   Print("-------------------------------------------------");

   // Trading recommendation
   Print("TRADING RECOMMENDATION:");
   PrintTradingRecommendation();

   Print("=================================================");
   Print("");
}

//+------------------------------------------------------------------+
//| Get Price Position Description                                    |
//+------------------------------------------------------------------+
string GetPricePositionDescription(double price)
{
   if(price > g_emaResult.ema50 && price > g_emaResult.ema200)
      return "Above both EMAs (Strong Bullish Zone)";
   else if(price < g_emaResult.ema50 && price < g_emaResult.ema200)
      return "Below both EMAs (Strong Bearish Zone)";
   else if(g_emaResult.ema50 > g_emaResult.ema200)
   {
      if(price < g_emaResult.ema50 && price > g_emaResult.ema200)
         return "Between EMAs (Bullish Pullback Zone)";
   }
   else
   {
      if(price > g_emaResult.ema50 && price < g_emaResult.ema200)
         return "Between EMAs (Bearish Pullback Zone)";
   }
   return "At EMA level (Decision Point)";
}

//+------------------------------------------------------------------+
//| Print Trading Recommendation                                      |
//+------------------------------------------------------------------+
void PrintTradingRecommendation()
{
   // Check ATR filter first
   if(InpUseATRFilter && !g_atrResult.tradingAllowed)
   {
      Print("  STATUS: >>> NO TRADE <<<");
      Print("  REASON: ", g_atrResult.reason);
      return;
   }

   // Check for very recent unconfirmed crossover
   if(g_emaResult.recentCrossover && g_emaResult.candlesSinceCross < 3 && !g_emaResult.crossoverConfirmed)
   {
      Print("  STATUS: >>> WAIT <<<");
      Print("  REASON: Very recent ", CrossoverTypeToString(g_emaResult.crossoverType),
            " - wait for confirmation");
      Print("  ACTION: Monitor for price confirmation in direction of cross");
      return;
   }

   // Check slope alignment
   bool slopesAligned = false;
   string slopeNote = "";

   if(g_emaResult.trend == BIAS_BULLISH)
   {
      slopesAligned = (g_emaResult.ema50SlopeDir == SLOPE_RISING);
      if(!slopesAligned) slopeNote = " (WEAK - EMA50 not rising)";
   }
   else if(g_emaResult.trend == BIAS_BEARISH)
   {
      slopesAligned = (g_emaResult.ema50SlopeDir == SLOPE_FALLING);
      if(!slopesAligned) slopeNote = " (WEAK - EMA50 not falling)";
   }

   // Based on trend bias
   switch(g_emaResult.trend)
   {
      case BIAS_BULLISH:
         Print("  STATUS: >>> LOOK FOR BUYS <<<", slopeNote);
         Print("  REASON: EMA50 > EMA200, price in bullish position");
         if(g_emaResult.recentCrossover && g_emaResult.crossoverConfirmed)
            Print("  NOTE: Recent confirmed Golden Cross - potential new trend");
         Print("  ACTION: Wait for BOS/CHoCH confirmation on H4");
         Print("  ENTRY: Look for demand zone + bullish structure on H1/M15");
         break;

      case BIAS_BEARISH:
         Print("  STATUS: >>> LOOK FOR SELLS <<<", slopeNote);
         Print("  REASON: EMA50 < EMA200, price in bearish position");
         if(g_emaResult.recentCrossover && g_emaResult.crossoverConfirmed)
            Print("  NOTE: Recent confirmed Death Cross - potential new trend");
         Print("  ACTION: Wait for BOS/CHoCH confirmation on H4");
         Print("  ENTRY: Look for supply zone + bearish structure on H1/M15");
         break;

      case BIAS_NEUTRAL:
         Print("  STATUS: >>> NO TRADE <<<");
         Print("  REASON: Mixed signals - EMAs too close or conflicting position");
         Print("  ACTION: Wait for clear trend establishment");
         Print("  WATCH: EMA separation > 0.1% and price alignment");
         break;
   }

   // Add volatility note if extreme
   if(InpUseATRFilter && g_atrResult.condition == MARKET_EXTREME)
   {
      Print("  CAUTION: High volatility - consider reduced position size");
   }
}

//+------------------------------------------------------------------+
//| Print Initialization Report                                       |
//+------------------------------------------------------------------+
void PrintInitReport()
{
   Print("");
   Print("=================================================");
   Print("     SWING TRADER PRO - SECTION 2                ");
   Print("     EMA TREND ANALYSIS (v2.0)                   ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL DETECTION:");
   Print("  Symbol: ", _Symbol);
   Print("  Type: ", g_symbolInfo.isGold ? "GOLD/XAU" : (g_symbolInfo.isSilver ? "SILVER/XAG" :
                    (g_symbolInfo.isJPY ? "JPY Pair" : "Standard Forex")));
   Print("  Digits: ", g_symbolInfo.digits);
   Print("  Point: ", DoubleToString(g_symbolInfo.point, g_symbolInfo.digits));
   Print("  Pip Size: ", DoubleToString(g_symbolInfo.pipSize, 5));
   Print("-------------------------------------------------");
   Print("TIMEFRAME: ", TimeframeToString(InpEMATimeframe));
   Print("-------------------------------------------------");
   Print("EMA SETTINGS:");
   Print("  Fast EMA Period: ", InpEMAFastPeriod);
   Print("  Slow EMA Period: ", InpEMASlowPeriod);
   Print("  Applied Price: ", EnumToString(InpEMAPrice));
   Print("  Crossover Lookback: ", InpCrossoverLookback, " candles");
   Print("  Slope Period: ", InpSlopePeriod, " candles");
   Print("-------------------------------------------------");
   if(InpUseATRFilter)
   {
      Print("ATR FILTER: ENABLED");
      Print("  ATR Period: ", InpATRPeriod);
      Print("  Quiet Threshold: ", DoubleToString(InpATRQuietThreshold, 1), " pips");
      Print("  Extreme Threshold: ", DoubleToString(InpATRExtremeThreshold, 1), " pips");
   }
   else
   {
      Print("ATR FILTER: DISABLED");
   }
   Print("-------------------------------------------------");
   Print("DISPLAY SETTINGS:");
   Print("  Panel: ", InpShowPanel ? "ON" : "OFF");
   Print("  EMA Lines: ", InpShowEMALines ? "ON" : "OFF");
   Print("  EMA Line History: ", InpEMALineBars, " bars");
   Print("-------------------------------------------------");
   Print("TREND BIAS RULES:");
   Print("  BULLISH: EMA50 > EMA200 + Price above EMA50 + Rising slope");
   Print("  BEARISH: EMA50 < EMA200 + Price below EMA50 + Falling slope");
   Print("  NEUTRAL: Mixed signals, recent unconfirmed cross, or EMAs too close");
   Print("=================================================");
   Print("");
}

//+------------------------------------------------------------------+
//| Create Info Panel                                                 |
//+------------------------------------------------------------------+
void CreatePanel()
{
   int x = InpPanelX;
   int y = InpPanelY;
   int panelHeight = InpUseATRFilter ? 280 : 250;

   // Background
   CreateRectangle(g_panelName + "_bg", x, y, 320, panelHeight, clrBlack, 200);

   // Title
   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "EMA TREND ANALYSIS v2.0", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "--------------------------------------", clrGray, 8, "Courier New");

   int yOffset = 40;

   // ATR Status (if enabled)
   if(InpUseATRFilter)
   {
      CreateLabel(g_panelName + "_atr_label", x + 10, y + yOffset, "ATR Filter:", clrWhite, 9, "Arial");
      CreateLabel(g_panelName + "_atr_value", x + 150, y + yOffset, "-- pips", clrYellow, 9, "Arial");
      CreateLabel(g_panelName + "_atr_status", x + 240, y + yOffset, "[--]", clrGray, 9, "Arial Bold");
      yOffset += 20;
   }

   // EMA Values
   CreateLabel(g_panelName + "_ema50_label", x + 10, y + yOffset,
               "EMA " + IntegerToString(InpEMAFastPeriod) + ":", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_ema50_value", x + 150, y + yOffset, "--", clrDodgerBlue, 9, "Arial Bold");
   CreateLabel(g_panelName + "_ema50_slope", x + 260, y + yOffset, "[--]", clrGray, 8, "Arial");

   CreateLabel(g_panelName + "_ema200_label", x + 10, y + yOffset + 20,
               "EMA " + IntegerToString(InpEMASlowPeriod) + ":", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_ema200_value", x + 150, y + yOffset + 20, "--", clrOrangeRed, 9, "Arial Bold");
   CreateLabel(g_panelName + "_ema200_slope", x + 260, y + yOffset + 20, "[--]", clrGray, 8, "Arial");

   CreateLabel(g_panelName + "_gap_label", x + 10, y + yOffset + 40, "EMA Gap:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_gap_value", x + 150, y + yOffset + 40, "--", clrYellow, 9, "Arial");

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOffset + 60,
               "--------------------------------------", clrGray, 8, "Courier New");

   // Price Position
   CreateLabel(g_panelName + "_price_label", x + 10, y + yOffset + 75, "Price:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_price_value", x + 150, y + yOffset + 75, "--", clrWhite, 9, "Arial Bold");

   CreateLabel(g_panelName + "_position_label", x + 10, y + yOffset + 95, "Position:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_position_value", x + 150, y + yOffset + 95, "--", clrYellow, 9, "Arial");

   CreateLabel(g_panelName + "_sep3", x + 10, y + yOffset + 115,
               "--------------------------------------", clrGray, 8, "Courier New");

   // Trend Bias
   CreateLabel(g_panelName + "_bias_label", x + 10, y + yOffset + 130, "H4 BIAS:", clrWhite, 10, "Arial Bold");
   CreateLabel(g_panelName + "_bias_value", x + 150, y + yOffset + 130, "ANALYZING...", clrYellow, 10, "Arial Bold");

   // Crossover
   CreateLabel(g_panelName + "_cross_label", x + 10, y + yOffset + 150, "Crossover:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_cross_value", x + 150, y + yOffset + 150, "--", clrGray, 9, "Arial");

   // Slope Strength
   CreateLabel(g_panelName + "_strength_label", x + 10, y + yOffset + 170, "Momentum:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_strength_value", x + 150, y + yOffset + 170, "--", clrGray, 9, "Arial");

   // Recommendation
   CreateLabel(g_panelName + "_sep4", x + 10, y + yOffset + 190,
               "--------------------------------------", clrGray, 8, "Courier New");
   CreateLabel(g_panelName + "_rec_label", x + 10, y + yOffset + 205, "Action:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_rec_value", x + 100, y + yOffset + 205, "WAIT", clrYellow, 9, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel || !g_emaResult.isValid) return;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Update ATR (if enabled)
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

   // Update EMA values with slopes
   ObjectSetString(0, g_panelName + "_ema50_value", OBJPROP_TEXT,
                   DoubleToString(g_emaResult.ema50, g_symbolInfo.digits));
   ObjectSetString(0, g_panelName + "_ema200_value", OBJPROP_TEXT,
                   DoubleToString(g_emaResult.ema200, g_symbolInfo.digits));

   // Slope indicators
   string slope50Text = "";
   color slope50Color = clrGray;
   switch(g_emaResult.ema50SlopeDir)
   {
      case SLOPE_RISING:  slope50Text = "[^]"; slope50Color = clrLimeGreen; break;
      case SLOPE_FALLING: slope50Text = "[v]"; slope50Color = clrRed; break;
      case SLOPE_FLAT:    slope50Text = "[-]"; slope50Color = clrGray; break;
   }
   ObjectSetString(0, g_panelName + "_ema50_slope", OBJPROP_TEXT, slope50Text);
   ObjectSetInteger(0, g_panelName + "_ema50_slope", OBJPROP_COLOR, slope50Color);

   string slope200Text = "";
   color slope200Color = clrGray;
   switch(g_emaResult.ema200SlopeDir)
   {
      case SLOPE_RISING:  slope200Text = "[^]"; slope200Color = clrLimeGreen; break;
      case SLOPE_FALLING: slope200Text = "[v]"; slope200Color = clrRed; break;
      case SLOPE_FLAT:    slope200Text = "[-]"; slope200Color = clrGray; break;
   }
   ObjectSetString(0, g_panelName + "_ema200_slope", OBJPROP_TEXT, slope200Text);
   ObjectSetInteger(0, g_panelName + "_ema200_slope", OBJPROP_COLOR, slope200Color);

   // Gap
   ObjectSetString(0, g_panelName + "_gap_value", OBJPROP_TEXT,
                   DoubleToString(g_emaResult.emaGap, g_symbolInfo.digits) +
                   " (" + DoubleToString(g_emaResult.emaGapPercent, 2) + "%)");

   // Update price
   ObjectSetString(0, g_panelName + "_price_value", OBJPROP_TEXT,
                   DoubleToString(currentPrice, g_symbolInfo.digits));

   // Update position
   string posText = "";
   color posColor = clrYellow;
   if(g_emaResult.priceAboveEMA50 && g_emaResult.priceAboveEMA200)
   {
      posText = "Above Both";
      posColor = clrLimeGreen;
   }
   else if(!g_emaResult.priceAboveEMA50 && !g_emaResult.priceAboveEMA200)
   {
      posText = "Below Both";
      posColor = clrRed;
   }
   else
   {
      posText = "Between EMAs";
      posColor = clrOrange;
   }
   ObjectSetString(0, g_panelName + "_position_value", OBJPROP_TEXT, posText);
   ObjectSetInteger(0, g_panelName + "_position_value", OBJPROP_COLOR, posColor);

   // Update bias
   string biasText = TrendBiasToString(g_emaResult.trend);
   color biasColor = clrGray;
   switch(g_emaResult.trend)
   {
      case BIAS_BULLISH: biasColor = InpBullishColor; break;
      case BIAS_BEARISH: biasColor = InpBearishColor; break;
      case BIAS_NEUTRAL: biasColor = InpNeutralColor; break;
   }
   ObjectSetString(0, g_panelName + "_bias_value", OBJPROP_TEXT, biasText);
   ObjectSetInteger(0, g_panelName + "_bias_value", OBJPROP_COLOR, biasColor);

   // Update crossover
   if(g_emaResult.recentCrossover)
   {
      string crossText = CrossoverTypeToString(g_emaResult.crossoverType);
      crossText += " (" + IntegerToString(g_emaResult.candlesSinceCross) + " bars)";
      if(g_emaResult.crossoverConfirmed)
         crossText += " OK";
      else
         crossText += " ?";

      ObjectSetString(0, g_panelName + "_cross_value", OBJPROP_TEXT, crossText);
      ObjectSetInteger(0, g_panelName + "_cross_value", OBJPROP_COLOR,
                       g_emaResult.crossoverConfirmed ? clrLimeGreen : clrOrange);
   }
   else
   {
      ObjectSetString(0, g_panelName + "_cross_value", OBJPROP_TEXT, "None (Trend OK)");
      ObjectSetInteger(0, g_panelName + "_cross_value", OBJPROP_COLOR, clrLimeGreen);
   }

   // Update slope strength
   string strengthText = "";
   color strengthColor = clrGray;
   if(g_emaResult.slopeStrength < 0.05)
   {
      strengthText = "WEAK";
      strengthColor = clrGray;
   }
   else if(g_emaResult.slopeStrength < 0.15)
   {
      strengthText = "MODERATE";
      strengthColor = clrYellow;
   }
   else
   {
      strengthText = "STRONG";
      strengthColor = clrLimeGreen;
   }
   strengthText += " (" + DoubleToString(g_emaResult.slopeStrength, 3) + "%)";
   ObjectSetString(0, g_panelName + "_strength_value", OBJPROP_TEXT, strengthText);
   ObjectSetInteger(0, g_panelName + "_strength_value", OBJPROP_COLOR, strengthColor);

   // Update recommendation
   string recText = "";
   color recColor = clrGray;

   if(InpUseATRFilter && !g_atrResult.tradingAllowed)
   {
      recText = "NO TRADE (ATR)";
      recColor = clrGray;
   }
   else if(g_emaResult.recentCrossover && g_emaResult.candlesSinceCross < 3 && !g_emaResult.crossoverConfirmed)
   {
      recText = "WAIT (Confirm Cross)";
      recColor = clrOrange;
   }
   else
   {
      switch(g_emaResult.trend)
      {
         case BIAS_BULLISH:
            recText = "LOOK FOR BUYS";
            recColor = clrLimeGreen;
            break;
         case BIAS_BEARISH:
            recText = "LOOK FOR SELLS";
            recColor = clrRed;
            break;
         case BIAS_NEUTRAL:
            recText = "NO TRADE";
            recColor = clrGray;
            break;
      }
   }
   ObjectSetString(0, g_panelName + "_rec_value", OBJPROP_TEXT, recText);
   ObjectSetInteger(0, g_panelName + "_rec_value", OBJPROP_COLOR, recColor);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw EMA Lines on Chart (Optimized)                               |
//+------------------------------------------------------------------+
void DrawEMALines()
{
   if(!InpShowEMALines) return;

   // Limit bars to draw for performance
   int maxBars = MathMin(InpEMALineBars, 200);
   int bufferSize = MathMin(ArraySize(g_emaFastBuffer), ArraySize(g_emaSlowBuffer));
   int barsToShow = MathMin(maxBars, bufferSize - 1);

   if(barsToShow < 2) return;

   // Only recreate objects if bar count changed significantly
   if(MathAbs(barsToShow - g_lastDrawnBars) > 10 || g_lastDrawnBars == 0)
   {
      ObjectsDeleteAll(0, "EMA_Line_");
      g_lastDrawnBars = barsToShow;
   }

   // Draw/update EMA line segments
   for(int i = 0; i < barsToShow; i++)
   {
      datetime time1 = iTime(_Symbol, InpEMATimeframe, i);
      datetime time2 = iTime(_Symbol, InpEMATimeframe, i + 1);

      if(time1 == 0 || time2 == 0) continue;

      // EMA Fast line segment
      string fastName = "EMA_Line_Fast_" + IntegerToString(i);
      if(ObjectFind(0, fastName) < 0)
      {
         ObjectCreate(0, fastName, OBJ_TREND, 0, time2, g_emaFastBuffer[i+1], time1, g_emaFastBuffer[i]);
         ObjectSetInteger(0, fastName, OBJPROP_COLOR, InpEMAFastColor);
         ObjectSetInteger(0, fastName, OBJPROP_WIDTH, InpEMALineWidth);
         ObjectSetInteger(0, fastName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, fastName, OBJPROP_BACK, true);
         ObjectSetInteger(0, fastName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, fastName, OBJPROP_HIDDEN, true);
      }
      else
      {
         // Update coordinates only
         ObjectMove(0, fastName, 0, time2, g_emaFastBuffer[i+1]);
         ObjectMove(0, fastName, 1, time1, g_emaFastBuffer[i]);
      }

      // EMA Slow line segment
      string slowName = "EMA_Line_Slow_" + IntegerToString(i);
      if(ObjectFind(0, slowName) < 0)
      {
         ObjectCreate(0, slowName, OBJ_TREND, 0, time2, g_emaSlowBuffer[i+1], time1, g_emaSlowBuffer[i]);
         ObjectSetInteger(0, slowName, OBJPROP_COLOR, InpEMASlowColor);
         ObjectSetInteger(0, slowName, OBJPROP_WIDTH, InpEMALineWidth);
         ObjectSetInteger(0, slowName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, slowName, OBJPROP_BACK, true);
         ObjectSetInteger(0, slowName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, slowName, OBJPROP_HIDDEN, true);
      }
      else
      {
         ObjectMove(0, slowName, 0, time2, g_emaSlowBuffer[i+1]);
         ObjectMove(0, slowName, 1, time1, g_emaSlowBuffer[i]);
      }
   }

   // Add/update labels for EMAs at current bar
   datetime labelTime = iTime(_Symbol, InpEMATimeframe, 0);

   if(ObjectFind(0, "EMA_Label_Fast") < 0)
   {
      ObjectCreate(0, "EMA_Label_Fast", OBJ_TEXT, 0, labelTime, g_emaFastBuffer[0]);
      ObjectSetString(0, "EMA_Label_Fast", OBJPROP_TEXT, "EMA" + IntegerToString(InpEMAFastPeriod));
      ObjectSetInteger(0, "EMA_Label_Fast", OBJPROP_COLOR, InpEMAFastColor);
      ObjectSetInteger(0, "EMA_Label_Fast", OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, "EMA_Label_Fast", OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   else
   {
      ObjectMove(0, "EMA_Label_Fast", 0, labelTime, g_emaFastBuffer[0]);
   }

   if(ObjectFind(0, "EMA_Label_Slow") < 0)
   {
      ObjectCreate(0, "EMA_Label_Slow", OBJ_TEXT, 0, labelTime, g_emaSlowBuffer[0]);
      ObjectSetString(0, "EMA_Label_Slow", OBJPROP_TEXT, "EMA" + IntegerToString(InpEMASlowPeriod));
      ObjectSetInteger(0, "EMA_Label_Slow", OBJPROP_COLOR, InpEMASlowColor);
      ObjectSetInteger(0, "EMA_Label_Slow", OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, "EMA_Label_Slow", OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   else
   {
      ObjectMove(0, "EMA_Label_Slow", 0, labelTime, g_emaSlowBuffer[0]);
   }

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

// Get full EMA analysis result
EMAAnalysisResult GetEMAResult()
{
   return g_emaResult;
}

// Get ATR filter result
ATRFilterResult GetATRResult()
{
   return g_atrResult;
}

// Get H4 trend bias
ENUM_TREND_BIAS GetH4Bias()
{
   return g_emaResult.trend;
}

// Check if trend is established (no recent unconfirmed crossover)
bool IsTrendEstablished()
{
   if(!g_emaResult.recentCrossover)
      return true;

   // Crossover exists but is confirmed
   if(g_emaResult.crossoverConfirmed)
      return true;

   // Recent unconfirmed crossover - trend not established
   return false;
}

// Check if trading is allowed based on all filters
bool IsTradingAllowed()
{
   // ATR filter check
   if(InpUseATRFilter && !g_atrResult.tradingAllowed)
      return false;

   // Neutral bias - no trade
   if(g_emaResult.trend == BIAS_NEUTRAL)
      return false;

   // Very recent unconfirmed crossover - wait
   if(g_emaResult.recentCrossover &&
      g_emaResult.candlesSinceCross < 3 &&
      !g_emaResult.crossoverConfirmed)
      return false;

   return true;
}

// Get current EMA values
double GetEMA50() { return g_emaResult.ema50; }
double GetEMA200() { return g_emaResult.ema200; }
double GetEMAGap() { return g_emaResult.emaGap; }
double GetEMAGapPercent() { return g_emaResult.emaGapPercent; }

// Get slope information
double GetEMA50Slope() { return g_emaResult.ema50Slope; }
double GetEMA200Slope() { return g_emaResult.ema200Slope; }
ENUM_SLOPE_DIRECTION GetEMA50SlopeDirection() { return g_emaResult.ema50SlopeDir; }
ENUM_SLOPE_DIRECTION GetEMA200SlopeDirection() { return g_emaResult.ema200SlopeDir; }
double GetSlopeStrength() { return g_emaResult.slopeStrength; }

// Get crossover information
bool HasRecentCrossover() { return g_emaResult.recentCrossover; }
ENUM_CROSSOVER_TYPE GetCrossoverType() { return g_emaResult.crossoverType; }
int GetCandlesSinceCrossover() { return g_emaResult.candlesSinceCross; }
bool IsCrossoverConfirmed() { return g_emaResult.crossoverConfirmed; }

// Check if data is valid
bool IsDataValid() { return g_emaResult.isValid; }

//+------------------------------------------------------------------+
