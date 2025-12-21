//+------------------------------------------------------------------+
//|                                         Section01_ATRFilter.mq5  |
//|                                      SwingTrader Pro EA          |
//|                 Section 1: Base Framework + ATR Volatility Filter |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.12"
#property description "Section 1: ATR Volatility Filter"
#property description "Tests ATR-based market condition classification"
#property description "H4 timeframe analysis for market volatility"
#property description "Enhanced: Math functions for S/D zone detection"

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== ATR Filter Settings ==="
input int      InpATRPeriod           = 14;       // ATR Period
input double   InpATRQuietThreshold   = 60.0;     // Quiet Market Threshold (pips)
input double   InpATRExtremeThreshold = 250.0;    // Extreme Volatility Threshold (pips)
input ENUM_TIMEFRAMES InpATRTimeframe = PERIOD_H4; // ATR Calculation Timeframe

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;     // Show Info Panel on Chart
input bool     InpShowATRLine         = true;     // Show ATR History as Line
input color    InpQuietColor          = clrGray;  // Quiet Market Color
input color    InpNormalColor         = clrLimeGreen; // Normal Market Color
input color    InpExtremeColor        = clrRed;   // Extreme Market Color
input int      InpPanelX              = 20;       // Panel X Position
input int      InpPanelY              = 30;       // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;     // Print Report to Experts Tab
input int      InpReportBars          = 20;       // Number of Historical Bars to Report

input group "=== S/D Zone Math Settings ==="
input double   InpLegOutMultiplier    = 2.0;      // Leg-Out ATR Multiplier (min move >= X * ATR)
input double   InpBaseMaxMultiplier   = 0.5;      // Base ATR Multiplier (body <= X * ATR)
input int      InpATRHistoryBars      = 200;      // ATR History Bars to Cache

input group "=== ATR Advanced Settings ==="
input int      InpATRTrendBars        = 10;       // ATR Trend Calculation Bars
input int      InpATRPercentileBars   = 50;       // ATR Percentile Lookback Bars
input double   InpATRExpandThresh     = 1.2;      // ATR Expansion Threshold (1.2 = 20% above avg)
input double   InpATRContractThresh   = 0.8;      // ATR Contraction Threshold (0.8 = 20% below avg)
input double   InpATRSqueezeThresh    = 0.6;      // Volatility Squeeze Threshold (60% of normal)

input group "=== SL/TP ATR Multipliers (Section 12) ==="
input double   InpATRStopMultiplier   = 1.5;      // Stop Loss ATR Multiplier (SL = X × ATR)
input double   InpATRTP1Multiplier    = 2.0;      // TP1 ATR Multiplier (TP1 = X × ATR)
input double   InpATRTP2Multiplier    = 3.0;      // TP2 ATR Multiplier (TP2 = X × ATR)
input double   InpATRTP3Multiplier    = 4.5;      // TP3 ATR Multiplier (TP3 = X × ATR)

input group "=== Account Settings (Reference) ==="
input double   InpStartingBalance     = 500.0;    // Starting Balance ($)
input double   InpSpreadPips          = 0.8;      // Broker Spread (pips)
input string   InpBroker              = "BlackBull Markets NZ"; // Broker Name

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
int            g_atrHandle;                       // ATR indicator handle
double         g_atrBuffer[];                     // ATR values buffer
string         g_panelName = "ATRFilterPanel";    // Panel object prefix
ATRFilterResult g_currentResult;                  // Current ATR analysis result
int            g_digits;                          // Symbol digits
double         g_point;                           // Symbol point
double         g_pipValue;                        // Pip value for symbol
string         g_instrumentType;                  // Instrument type (GOLD, SILVER, JPY, FOREX)

// Advanced ATR Analysis Variables
double         g_atrAverage;                      // Average ATR over lookback period
double         g_atrPercentile;                   // Current ATR percentile (0-100)
double         g_atrTrendSlope;                   // ATR trend slope (positive = expanding)
double         g_normalizedATR;                   // ATR as % of price (NATR)
bool           g_volatilitySqueeze;               // Is volatility in squeeze?
bool           g_volatilityExpanding;             // Is volatility expanding?
bool           g_volatilityContracting;           // Is volatility contracting?
string         g_volatilityTrend;                 // "EXPANDING", "CONTRACTING", "STABLE"

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get symbol info
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Auto-detect instrument type and set correct pip value
   string sym = _Symbol;
   StringToUpper(sym);

   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
   {
      g_instrumentType = "GOLD";
      g_pipValue = 0.10;           // Gold: 1 pip = $0.10
      Print("AUTO-DETECT: Gold - pipValue=0.10");
   }
   else if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
   {
      g_instrumentType = "SILVER";
      g_pipValue = 0.01;           // Silver: 1 pip = $0.01
      Print("AUTO-DETECT: Silver - pipValue=0.01");
   }
   else if(StringFind(sym, "JPY") >= 0)
   {
      g_instrumentType = "JPY";
      g_pipValue = g_point * (g_digits == 3 ? 1 : 10);
      Print("AUTO-DETECT: JPY pair");
   }
   else
   {
      g_instrumentType = "FOREX";
      g_pipValue = GetPipValue(_Symbol);
      Print("AUTO-DETECT: Forex pair");
   }

   // Create ATR indicator handle
   g_atrHandle = iATR(_Symbol, InpATRTimeframe, InpATRPeriod);

   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR indicator handle");
      return(INIT_FAILED);
   }

   // Set buffer as series
   ArraySetAsSeries(g_atrBuffer, true);

   // Print initialization info
   PrintInitReport();

   // Create panel if enabled
   if(InpShowPanel)
      CreatePanel();

   // Run initial analysis
   AnalyzeATR();

   // FIX: Update panel after initial analysis
   if(InpShowPanel)
      UpdatePanel();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handle
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);

   // Remove panel objects
   DeletePanel();

   // Print exit report
   Print("=================================================");
   Print("ATR Filter EA Deinitialized");
   Print("Reason: ", GetDeinitReason(reason));
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar on ATR timeframe
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpATRTimeframe, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;

      // Perform ATR analysis
      AnalyzeATR();

      // Update panel
      if(InpShowPanel)
         UpdatePanel();
   }
}

//+------------------------------------------------------------------+
//| Analyze ATR and determine market condition                        |
//+------------------------------------------------------------------+
void AnalyzeATR()
{
   // Copy ATR values
   int copied = CopyBuffer(g_atrHandle, 0, 0, InpReportBars + 1, g_atrBuffer);

   if(copied < 1)
   {
      Print("ERROR: Failed to copy ATR buffer. Copied: ", copied);
      return;
   }

   // Get current ATR value (in price points)
   double atrPoints = g_atrBuffer[0];

   // Convert to pips
   double atrPips = PointsToPips(_Symbol, atrPoints);

   // For gold (XAU/USD), ATR is in dollars, need special handling
   if(StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0)
   {
      // Gold: 1 pip = $0.10 for standard lot, ATR is in dollars
      // ATR of 30 means price can move $30, which is 300 pips (since $0.10 = 1 pip)
      atrPips = atrPoints * 10;  // Convert $ move to pips for gold
   }

   // Store result
   g_currentResult.atrValue = atrPips;
   g_currentResult.timestamp = TimeCurrent();

   // Classify market condition
   if(atrPips < InpATRQuietThreshold)
   {
      g_currentResult.condition = MARKET_QUIET;
      g_currentResult.tradingAllowed = false;
      g_currentResult.reason = "Market too quiet - ATR below " +
                               DoubleToString(InpATRQuietThreshold, 1) + " pips threshold";
   }
   else if(atrPips > InpATRExtremeThreshold)
   {
      g_currentResult.condition = MARKET_EXTREME;
      g_currentResult.tradingAllowed = true;  // Can trade but with adjustments
      g_currentResult.reason = "Extreme volatility - ATR above " +
                               DoubleToString(InpATRExtremeThreshold, 1) + " pips - Reduce position size";
   }
   else
   {
      g_currentResult.condition = MARKET_NORMAL;
      g_currentResult.tradingAllowed = true;
      g_currentResult.reason = "Normal market conditions - Trading allowed";
   }

   // Perform advanced ATR analysis
   AnalyzeATRAdvanced();

   // Print report if enabled
   if(InpPrintReport)
      PrintATRReport();
}

//+------------------------------------------------------------------+
//| Advanced ATR Analysis (Trend, Percentile, NATR)                   |
//+------------------------------------------------------------------+
void AnalyzeATRAdvanced()
{
   // Ensure we have enough data
   int barsNeeded = MathMax(InpATRTrendBars, InpATRPercentileBars) + 5;
   if(ArraySize(g_atrBuffer) < barsNeeded)
   {
      int copied = CopyBuffer(g_atrHandle, 0, 0, barsNeeded, g_atrBuffer);
      if(copied < barsNeeded)
      {
         Print("WARNING: AnalyzeATRAdvanced - Insufficient data");
         return;
      }
   }

   // 1. Calculate ATR Average (over percentile lookback)
   double sum = 0.0;
   int count = MathMin(InpATRPercentileBars, ArraySize(g_atrBuffer));
   for(int i = 0; i < count; i++)
      sum += g_atrBuffer[i];
   g_atrAverage = (count > 0) ? sum / count : g_atrBuffer[0];

   // 2. Calculate ATR Percentile (where does current ATR rank?)
   double currentATR = g_atrBuffer[0];
   int belowCount = 0;
   for(int i = 1; i < count; i++)
   {
      if(g_atrBuffer[i] < currentATR)
         belowCount++;
   }
   g_atrPercentile = (count > 1) ? (double)belowCount / (count - 1) * 100.0 : 50.0;

   // 3. Calculate ATR Trend Slope (is volatility expanding or contracting?)
   int trendBars = MathMin(InpATRTrendBars, ArraySize(g_atrBuffer));
   double startATR = g_atrBuffer[trendBars - 1];
   double endATR = g_atrBuffer[0];
   g_atrTrendSlope = (startATR > 0) ? (endATR - startATR) / startATR * 100.0 : 0.0;

   // 4. Calculate Normalized ATR (ATR as % of price)
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_normalizedATR = (currentPrice > 0) ? (g_atrBuffer[0] / currentPrice) * 100.0 : 0.0;

   // 5. Detect Volatility Squeeze (ATR below threshold of average)
   double atrRatio = (g_atrAverage > 0) ? currentATR / g_atrAverage : 1.0;
   g_volatilitySqueeze = (atrRatio < InpATRSqueezeThresh);

   // 6. Classify Volatility Trend
   if(atrRatio >= InpATRExpandThresh)
   {
      g_volatilityExpanding = true;
      g_volatilityContracting = false;
      g_volatilityTrend = "EXPANDING";
   }
   else if(atrRatio <= InpATRContractThresh)
   {
      g_volatilityExpanding = false;
      g_volatilityContracting = true;
      g_volatilityTrend = "CONTRACTING";
   }
   else
   {
      g_volatilityExpanding = false;
      g_volatilityContracting = false;
      g_volatilityTrend = "STABLE";
   }

   // Adjust trading condition based on volatility squeeze
   if(g_volatilitySqueeze && g_currentResult.condition == MARKET_QUIET)
   {
      g_currentResult.reason += " | VOLATILITY SQUEEZE detected - Breakout may follow";
   }
}

//+------------------------------------------------------------------+
//| Print ATR Analysis Report                                         |
//+------------------------------------------------------------------+
void PrintATRReport()
{
   Print("");
   Print("=================================================");
   Print("       ATR VOLATILITY FILTER REPORT              ");
   Print("=================================================");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", TimeframeToString(InpATRTimeframe));
   Print("ATR Period: ", InpATRPeriod);
   Print("Analysis Time: ", TimeToString(g_currentResult.timestamp, TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("CURRENT ATR: ", DoubleToString(g_currentResult.atrValue, 2), " pips");
   Print("-------------------------------------------------");
   Print("Quiet Threshold: < ", DoubleToString(InpATRQuietThreshold, 1), " pips");
   Print("Normal Range: ", DoubleToString(InpATRQuietThreshold, 1), " - ",
         DoubleToString(InpATRExtremeThreshold, 1), " pips");
   Print("Extreme Threshold: > ", DoubleToString(InpATRExtremeThreshold, 1), " pips");
   Print("-------------------------------------------------");
   Print("MARKET CONDITION: ", MarketConditionToString(g_currentResult.condition));
   Print("TRADING ALLOWED: ", g_currentResult.tradingAllowed ? "YES" : "NO");
   Print("REASON: ", g_currentResult.reason);
   Print("-------------------------------------------------");
   Print("");
   Print("=== ADVANCED ATR ANALYSIS ===");
   Print("-------------------------------------------------");
   Print("ATR Average (", InpATRPercentileBars, " bars): ", DoubleToString(GetATRPipsFromPrice(g_atrAverage), 2), " pips");
   Print("ATR vs Average: ", DoubleToString((g_atrAverage > 0 ? g_atrBuffer[0] / g_atrAverage * 100.0 : 100.0), 1), "%");
   Print("ATR Percentile: ", DoubleToString(g_atrPercentile, 1), "% (higher = more volatile than usual)");
   Print("ATR Trend Slope: ", DoubleToString(g_atrTrendSlope, 2), "% (", (g_atrTrendSlope > 0 ? "rising" : "falling"), ")");
   Print("Normalized ATR (NATR): ", DoubleToString(g_normalizedATR, 4), "% of price");
   Print("-------------------------------------------------");
   Print("VOLATILITY TREND: ", g_volatilityTrend);
   Print("Volatility Expanding: ", g_volatilityExpanding ? "YES" : "NO");
   Print("Volatility Squeeze: ", g_volatilitySqueeze ? "YES - Breakout Alert!" : "NO");
   Print("-------------------------------------------------");

   // Print historical ATR values
   Print("");
   Print("ATR HISTORY (Last ", InpReportBars, " bars on ", TimeframeToString(InpATRTimeframe), "):");
   Print("-------------------------------------------------");

   for(int i = 0; i < MathMin(InpReportBars, ArraySize(g_atrBuffer)); i++)
   {
      double atrPips = g_atrBuffer[i];

      // Gold adjustment
      if(StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0)
         atrPips = atrPips * 10;
      else
         atrPips = PointsToPips(_Symbol, g_atrBuffer[i]);

      datetime barTime = iTime(_Symbol, InpATRTimeframe, i);
      string condition = "";

      if(atrPips < InpATRQuietThreshold)
         condition = "[QUIET]";
      else if(atrPips > InpATRExtremeThreshold)
         condition = "[EXTREME]";
      else
         condition = "[NORMAL]";

      Print("Bar ", i, " (", TimeToString(barTime, TIME_DATE|TIME_MINUTES), "): ",
            DoubleToString(atrPips, 2), " pips ", condition);
   }

   Print("-------------------------------------------------");
   Print("=== END ATR REPORT ===");
   Print("");
}

//+------------------------------------------------------------------+
//| Print Initialization Report                                       |
//+------------------------------------------------------------------+
void PrintInitReport()
{
   Print("");
   Print("=================================================");
   Print("     SWING TRADER PRO - SECTION 1                ");
   Print("     ATR VOLATILITY FILTER                       ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("ACCOUNT INFORMATION:");
   Print("  Broker: ", InpBroker);
   Print("  Starting Balance: $", DoubleToString(InpStartingBalance, 2));
   Print("  Spread: ", DoubleToString(InpSpreadPips, 1), " pips");
   Print("-------------------------------------------------");
   Print("SYMBOL INFORMATION:");
   Print("  Symbol: ", _Symbol, " (", g_instrumentType, ")");
   Print("  Digits: ", g_digits);
   Print("  Point: ", DoubleToString(g_point, g_digits));
   Print("  Pip Value: ", DoubleToString(g_pipValue, 4), " (", g_instrumentType, ")");
   Print("  Bid: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), g_digits));
   Print("  Ask: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), g_digits));
   Print("  Spread (current): ", DoubleToString(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * g_point / g_pipValue, 2), " pips");
   Print("-------------------------------------------------");
   Print("ATR FILTER SETTINGS:");
   Print("  ATR Period: ", InpATRPeriod);
   Print("  Analysis Timeframe: ", TimeframeToString(InpATRTimeframe));
   Print("  Quiet Threshold: ", DoubleToString(InpATRQuietThreshold, 1), " pips");
   Print("  Extreme Threshold: ", DoubleToString(InpATRExtremeThreshold, 1), " pips");
   Print("-------------------------------------------------");
   Print("PURPOSE:");
   Print("  This section tests the ATR volatility filter");
   Print("  which determines if market conditions are");
   Print("  suitable for swing trading.");
   Print("-------------------------------------------------");
   Print("EXPECTED BEHAVIOR:");
   Print("  - ATR < ", InpATRQuietThreshold, " pips: SKIP trade (too quiet)");
   Print("  - ATR ", InpATRQuietThreshold, "-", InpATRExtremeThreshold, " pips: PROCEED (normal)");
   Print("  - ATR > ", InpATRExtremeThreshold, " pips: ADJUST (extreme)");
   Print("-------------------------------------------------");
   Print("S/D ZONE MATH SETTINGS (for Section 4):");
   Print("  Leg-Out Multiplier: ", InpLegOutMultiplier, "x ATR (move >= ", InpLegOutMultiplier, " x ATR)");
   Print("  Base Max Multiplier: ", InpBaseMaxMultiplier, "x ATR (body <= ", InpBaseMaxMultiplier, " x ATR)");
   Print("  ATR History Bars: ", InpATRHistoryBars);
   Print("-------------------------------------------------");
   Print("ATR-BASED SL/TP SETTINGS (for Section 12):");
   Print("  Stop Loss: ", InpATRStopMultiplier, "x ATR");
   Print("  TP1: ", InpATRTP1Multiplier, "x ATR (R:R = ", DoubleToString(InpATRTP1Multiplier/InpATRStopMultiplier, 2), ")");
   Print("  TP2: ", InpATRTP2Multiplier, "x ATR (R:R = ", DoubleToString(InpATRTP2Multiplier/InpATRStopMultiplier, 2), ")");
   Print("  TP3: ", InpATRTP3Multiplier, "x ATR (R:R = ", DoubleToString(InpATRTP3Multiplier/InpATRStopMultiplier, 2), ")");
   Print("-------------------------------------------------");
   Print("ADVANCED ATR SETTINGS:");
   Print("  ATR Trend Bars: ", InpATRTrendBars);
   Print("  ATR Percentile Lookback: ", InpATRPercentileBars);
   Print("  Expansion Threshold: ", InpATRExpandThresh, "x (", (InpATRExpandThresh-1)*100, "% above avg)");
   Print("  Contraction Threshold: ", InpATRContractThresh, "x (", (1-InpATRContractThresh)*100, "% below avg)");
   Print("  Squeeze Threshold: ", InpATRSqueezeThresh, "x (", InpATRSqueezeThresh*100, "% of avg)");
   Print("-------------------------------------------------");
   Print("PUBLIC FUNCTIONS (for other sections):");
   Print("  GetATRPriceAtBar(bar) - ATR in price units");
   Print("  GetATRPipsAtBar(bar)  - ATR in pips");
   Print("  IsValidLegOut(move, bar) - Check leg-out >= 2x ATR");
   Print("  IsValidBase(body, bar)   - Check base <= 0.5x ATR");
   Print("  CalculateZoneScore()     - Zone quality score (0-13)");
   Print("-------------------------------------------------");
   Print("NEW ADVANCED FUNCTIONS:");
   Print("  GetATRAverage()     - Average ATR over lookback");
   Print("  GetATRPercentile()  - Current ATR percentile (0-100)");
   Print("  GetATRTrendSlope()  - ATR trend (+expanding/-contracting)");
   Print("  GetNormalizedATR()  - ATR as % of price (NATR)");
   Print("  IsVolatilitySqueeze() - Breakout alert");
   Print("  GetVolatilityTrend()  - EXPANDING/CONTRACTING/STABLE");
   Print("-------------------------------------------------");
   Print("SL/TP FUNCTIONS (for Section 12):");
   Print("  CalculateATRStopLoss() - SL distance in price");
   Print("  CalculateATRTP1/2/3()  - TP distances in price");
   Print("  GetATRBasedLevels()    - All levels at once");
   Print("  GetVolatilityPositionMultiplier() - Position size adj");
   Print("  IsGoodSwingConditions()  - Combined volatility check");
   Print("=================================================");
   Print("");
}

//+------------------------------------------------------------------+
//| Create Info Panel on Chart                                        |
//+------------------------------------------------------------------+
void CreatePanel()
{
   int x = InpPanelX;
   int y = InpPanelY;

   // Background rectangle (expanded for advanced analysis)
   CreateRectangle(g_panelName + "_bg", x, y, 300, 290, clrBlack, 200);

   // Title
   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "ATR VOLATILITY FILTER", clrGold, 10, "Arial Bold");

   // Separator
   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "----------------------------", clrGray, 8, "Courier New");

   // ATR Value
   CreateLabel(g_panelName + "_atr_label", x + 10, y + 40,
               "ATR Value:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_atr_value", x + 150, y + 40,
               "-- pips", clrYellow, 9, "Arial Bold");

   // Timeframe
   CreateLabel(g_panelName + "_tf_label", x + 10, y + 60,
               "Timeframe:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_tf_value", x + 150, y + 60,
               TimeframeToString(InpATRTimeframe), clrCyan, 9, "Arial");

   // Separator
   CreateLabel(g_panelName + "_sep2", x + 10, y + 80,
               "----------------------------", clrGray, 8, "Courier New");

   // Condition
   CreateLabel(g_panelName + "_cond_label", x + 10, y + 95,
               "Condition:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_cond_value", x + 150, y + 95,
               "ANALYZING...", clrYellow, 9, "Arial Bold");

   // Trading Status
   CreateLabel(g_panelName + "_trade_label", x + 10, y + 115,
               "Trading:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_trade_value", x + 150, y + 115,
               "WAIT", clrYellow, 9, "Arial Bold");

   // Separator
   CreateLabel(g_panelName + "_sep3", x + 10, y + 135,
               "----------------------------", clrGray, 8, "Courier New");

   // Thresholds
   CreateLabel(g_panelName + "_thresh", x + 10, y + 150,
               "Quiet: <" + DoubleToString(InpATRQuietThreshold, 0) +
               " | Extreme: >" + DoubleToString(InpATRExtremeThreshold, 0),
               clrGray, 8, "Arial");

   // Separator for Advanced Section
   CreateLabel(g_panelName + "_sep4", x + 10, y + 165,
               "----------------------------", clrGray, 8, "Courier New");

   // Advanced ATR Analysis Section
   CreateLabel(g_panelName + "_adv_title", x + 10, y + 180,
               "ADVANCED ATR ANALYSIS", clrCyan, 9, "Arial Bold");

   // ATR vs Average
   CreateLabel(g_panelName + "_avg_label", x + 10, y + 198,
               "ATR vs Avg:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_avg_value", x + 150, y + 198,
               "-- %", clrYellow, 8, "Arial");

   // ATR Percentile
   CreateLabel(g_panelName + "_pct_label", x + 10, y + 213,
               "Percentile:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_pct_value", x + 150, y + 213,
               "-- %", clrYellow, 8, "Arial");

   // Volatility Trend
   CreateLabel(g_panelName + "_trend_label", x + 10, y + 228,
               "Vol Trend:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_trend_value", x + 150, y + 228,
               "ANALYZING", clrYellow, 8, "Arial Bold");

   // Squeeze Alert
   CreateLabel(g_panelName + "_squeeze_label", x + 10, y + 243,
               "Squeeze Alert:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_squeeze_value", x + 150, y + 243,
               "--", clrYellow, 8, "Arial");

   // Swing Conditions
   CreateLabel(g_panelName + "_swing_label", x + 10, y + 258,
               "Swing Ready:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_swing_value", x + 150, y + 258,
               "--", clrYellow, 8, "Arial Bold");

   // Time
   CreateLabel(g_panelName + "_time", x + 10, y + 275,
               "Last Update: --", clrGray, 8, "Arial");
}

//+------------------------------------------------------------------+
//| Update Info Panel                                                 |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel) return;

   // Update ATR value
   ObjectSetString(0, g_panelName + "_atr_value", OBJPROP_TEXT,
                   DoubleToString(g_currentResult.atrValue, 2) + " pips");

   // Update condition with color
   string condText = "";
   color condColor = clrWhite;

   switch(g_currentResult.condition)
   {
      case MARKET_QUIET:
         condText = "QUIET";
         condColor = InpQuietColor;
         break;
      case MARKET_NORMAL:
         condText = "NORMAL";
         condColor = InpNormalColor;
         break;
      case MARKET_EXTREME:
         condText = "EXTREME";
         condColor = InpExtremeColor;
         break;
   }

   ObjectSetString(0, g_panelName + "_cond_value", OBJPROP_TEXT, condText);
   ObjectSetInteger(0, g_panelName + "_cond_value", OBJPROP_COLOR, condColor);

   // Update trading status
   string tradeText = g_currentResult.tradingAllowed ? "ALLOWED" : "BLOCKED";
   color tradeColor = g_currentResult.tradingAllowed ? clrLimeGreen : clrRed;

   ObjectSetString(0, g_panelName + "_trade_value", OBJPROP_TEXT, tradeText);
   ObjectSetInteger(0, g_panelName + "_trade_value", OBJPROP_COLOR, tradeColor);

   // Update Advanced ATR Analysis fields
   // ATR vs Average
   double atrRatio = (g_atrAverage > 0) ? g_atrBuffer[0] / g_atrAverage * 100.0 : 100.0;
   ObjectSetString(0, g_panelName + "_avg_value", OBJPROP_TEXT,
                   DoubleToString(atrRatio, 1) + "%");
   color ratioColor = (atrRatio > 120) ? clrOrange : (atrRatio < 80) ? clrAqua : clrLimeGreen;
   ObjectSetInteger(0, g_panelName + "_avg_value", OBJPROP_COLOR, ratioColor);

   // ATR Percentile
   ObjectSetString(0, g_panelName + "_pct_value", OBJPROP_TEXT,
                   DoubleToString(g_atrPercentile, 1) + "%");
   color pctColor = (g_atrPercentile > 80) ? clrOrange : (g_atrPercentile < 20) ? clrAqua : clrYellow;
   ObjectSetInteger(0, g_panelName + "_pct_value", OBJPROP_COLOR, pctColor);

   // Volatility Trend
   ObjectSetString(0, g_panelName + "_trend_value", OBJPROP_TEXT, g_volatilityTrend);
   color trendColor = clrYellow;
   if(g_volatilityTrend == "EXPANDING")
      trendColor = clrOrange;
   else if(g_volatilityTrend == "CONTRACTING")
      trendColor = clrAqua;
   else
      trendColor = clrLimeGreen;
   ObjectSetInteger(0, g_panelName + "_trend_value", OBJPROP_COLOR, trendColor);

   // Squeeze Alert
   string squeezeText = g_volatilitySqueeze ? "YES - Breakout!" : "NO";
   color squeezeColor = g_volatilitySqueeze ? clrMagenta : clrGray;
   ObjectSetString(0, g_panelName + "_squeeze_value", OBJPROP_TEXT, squeezeText);
   ObjectSetInteger(0, g_panelName + "_squeeze_value", OBJPROP_COLOR, squeezeColor);

   // Swing Ready
   bool swingReady = IsGoodSwingConditions();
   string swingText = swingReady ? "YES" : "NO";
   color swingColor = swingReady ? clrLimeGreen : clrRed;
   ObjectSetString(0, g_panelName + "_swing_value", OBJPROP_TEXT, swingText);
   ObjectSetInteger(0, g_panelName + "_swing_value", OBJPROP_COLOR, swingColor);

   // Update time
   ObjectSetString(0, g_panelName + "_time", OBJPROP_TEXT,
                   "Last Update: " + TimeToString(g_currentResult.timestamp, TIME_MINUTES));

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete Panel Objects                                              |
//+------------------------------------------------------------------+
void DeletePanel()
{
   ObjectsDeleteAll(0, g_panelName);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create Rectangle Label                                            |
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
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Create Text Label                                                 |
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
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Get Deinitialization Reason                                       |
//+------------------------------------------------------------------+
string GetDeinitReason(int reason)
{
   switch(reason)
   {
      case REASON_PROGRAM:     return "Program removed from chart";
      case REASON_REMOVE:      return "Expert removed from chart";
      case REASON_RECOMPILE:   return "Expert recompiled";
      case REASON_CHARTCHANGE: return "Symbol or timeframe changed";
      case REASON_CHARTCLOSE:  return "Chart closed";
      case REASON_PARAMETERS:  return "Input parameters changed";
      case REASON_ACCOUNT:     return "Account changed";
      case REASON_TEMPLATE:    return "New template applied";
      case REASON_INITFAILED:  return "Initialization failed";
      case REASON_CLOSE:       return "Terminal closed";
      default:                 return "Unknown reason";
   }
}

//+------------------------------------------------------------------+
//| Get ATR Filter Result (for external use)                          |
//+------------------------------------------------------------------+
ATRFilterResult GetATRFilterResult()
{
   return g_currentResult;
}

//+------------------------------------------------------------------+
//| Check if Trading is Allowed                                       |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   return g_currentResult.tradingAllowed;
}

//+------------------------------------------------------------------+
//| Get Current ATR in Pips                                           |
//+------------------------------------------------------------------+
double GetCurrentATRPips()
{
   return g_currentResult.atrValue;
}

//+------------------------------------------------------------------+
//| Get Market Condition                                              |
//+------------------------------------------------------------------+
ENUM_MARKET_CONDITION GetMarketCondition()
{
   return g_currentResult.condition;
}

//+------------------------------------------------------------------+
//| NEW: Get ATR in PRICE UNITS at specific bar index                 |
//| Returns raw ATR value (not converted to pips)                     |
//| Used for direct comparison with candle body sizes                 |
//+------------------------------------------------------------------+
double GetATRPriceAtBar(int barIndex = 0)
{
   // Ensure we have data
   if(ArraySize(g_atrBuffer) <= barIndex || barIndex < 0)
   {
      // Try to copy more data
      int copied = CopyBuffer(g_atrHandle, 0, 0, barIndex + 10, g_atrBuffer);
      if(copied <= barIndex)
      {
         Print("WARNING: GetATRPriceAtBar - Cannot get ATR at bar ", barIndex);
         return 0.0;
      }
   }

   // Return raw ATR in price units
   return g_atrBuffer[barIndex];
}

//+------------------------------------------------------------------+
//| NEW: Get ATR in PIPS at specific bar index                        |
//| Converts ATR to pips for display purposes                         |
//+------------------------------------------------------------------+
double GetATRPipsAtBar(int barIndex = 0)
{
   double atrPrice = GetATRPriceAtBar(barIndex);
   if(atrPrice == 0.0) return 0.0;

   // Convert to pips
   // Gold: ATR is in dollars, 1 pip = $0.10, so multiply by 10
   if(StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0)
      return atrPrice * 10.0;
   else
      return PointsToPips(_Symbol, atrPrice);
}

//+------------------------------------------------------------------+
//| NEW: Validate Leg-Out Move (for S/D Zone Detection)               |
//| Rule: Leg-Out distance must be >= LegOutMultiplier × ATR          |
//| Returns true if move is strong enough to create valid zone        |
//+------------------------------------------------------------------+
bool IsValidLegOut(double moveDistance, int barIndex = 0)
{
   double atr = GetATRPriceAtBar(barIndex);
   if(atr == 0.0) return false;

   double requiredMove = InpLegOutMultiplier * atr;
   return (moveDistance >= requiredMove);
}

//+------------------------------------------------------------------+
//| NEW: Validate Base Candle (for S/D Zone Detection)                |
//| Rule: Base candle body must be <= BaseMaxMultiplier × ATR         |
//| Returns true if candle is small enough for valid base             |
//+------------------------------------------------------------------+
bool IsValidBase(double bodySize, int barIndex = 0)
{
   double atr = GetATRPriceAtBar(barIndex);
   if(atr == 0.0) return false;

   double maxBodySize = InpBaseMaxMultiplier * atr;
   return (bodySize <= maxBodySize);
}

//+------------------------------------------------------------------+
//| NEW: Calculate Zone Score (for S/D Zone Quality)                  |
//| Mathematical scoring system for zone quality                       |
//| Returns score 0-10 (trade zones with score >= 7)                  |
//+------------------------------------------------------------------+
int CalculateZoneScore(double legOutDistance, double baseBodyMax,
                       bool isFresh, bool alignsWithFib,
                       bool causedBOS, int barIndex = 0)
{
   int score = 0;
   double atr = GetATRPriceAtBar(barIndex);
   if(atr == 0.0) return 0;

   // Leg-Out Score: Is move >= 2× ATR? (+3 points)
   if(legOutDistance >= InpLegOutMultiplier * atr)
      score += 3;
   else if(legOutDistance >= 1.5 * atr)  // Partial credit for 1.5× ATR
      score += 1;

   // Base Score: Are base candles <= 0.5× ATR? (+2 points)
   if(baseBodyMax <= InpBaseMaxMultiplier * atr)
      score += 2;
   else if(baseBodyMax <= 0.75 * atr)  // Partial credit
      score += 1;

   // Freshness Score: Never tested? (+5 points if fresh, +2 if tested once)
   if(isFresh)
      score += 5;
   else
      score += 2;  // Tested once still has some value

   // Fibonacci Alignment (+1 point)
   if(alignsWithFib)
      score += 1;

   // BOS/CHoCH Correlation (+2 points) - from Section 3
   if(causedBOS)
      score += 2;

   return score;  // Max possible: 13 points
}

//+------------------------------------------------------------------+
//| NEW: Get Leg-Out Threshold (for display/debug)                    |
//+------------------------------------------------------------------+
double GetLegOutThreshold(int barIndex = 0)
{
   return InpLegOutMultiplier * GetATRPriceAtBar(barIndex);
}

//+------------------------------------------------------------------+
//| NEW: Get Base Max Threshold (for display/debug)                   |
//+------------------------------------------------------------------+
double GetBaseMaxThreshold(int barIndex = 0)
{
   return InpBaseMaxMultiplier * GetATRPriceAtBar(barIndex);
}

//+------------------------------------------------------------------+
//| NEW: Get ATR Multiplier Settings                                  |
//+------------------------------------------------------------------+
double GetLegOutMultiplier() { return InpLegOutMultiplier; }
double GetBaseMaxMultiplier() { return InpBaseMaxMultiplier; }

//+------------------------------------------------------------------+
//| NEW: Refresh ATR Buffer (load history)                            |
//| Call this to ensure ATR history is loaded for zone detection      |
//+------------------------------------------------------------------+
bool RefreshATRBuffer(int barsNeeded = 0)
{
   if(barsNeeded <= 0) barsNeeded = InpATRHistoryBars;

   int copied = CopyBuffer(g_atrHandle, 0, 0, barsNeeded, g_atrBuffer);
   if(copied < barsNeeded)
   {
      Print("WARNING: RefreshATRBuffer - Only copied ", copied, " of ", barsNeeded, " bars");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| NEW: Convert ATR Price to Pips (helper for display)               |
//+------------------------------------------------------------------+
double GetATRPipsFromPrice(double atrPrice)
{
   if(atrPrice == 0.0) return 0.0;

   // Gold: ATR is in dollars, 1 pip = $0.10, so multiply by 10
   if(StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0)
      return atrPrice * 10.0;
   else
      return PointsToPips(_Symbol, atrPrice);
}

//+------------------------------------------------------------------+
//| NEW: Get ATR Average (for external use)                           |
//+------------------------------------------------------------------+
double GetATRAverage() { return g_atrAverage; }

//+------------------------------------------------------------------+
//| NEW: Get ATR Percentile (0-100, higher = more volatile than usual)|
//+------------------------------------------------------------------+
double GetATRPercentile() { return g_atrPercentile; }

//+------------------------------------------------------------------+
//| NEW: Get ATR Trend Slope (positive = expanding volatility)        |
//+------------------------------------------------------------------+
double GetATRTrendSlope() { return g_atrTrendSlope; }

//+------------------------------------------------------------------+
//| NEW: Get Normalized ATR (ATR as % of price)                       |
//+------------------------------------------------------------------+
double GetNormalizedATR() { return g_normalizedATR; }

//+------------------------------------------------------------------+
//| NEW: Is Volatility in Squeeze? (potential breakout)               |
//+------------------------------------------------------------------+
bool IsVolatilitySqueeze() { return g_volatilitySqueeze; }

//+------------------------------------------------------------------+
//| NEW: Is Volatility Expanding?                                     |
//+------------------------------------------------------------------+
bool IsVolatilityExpanding() { return g_volatilityExpanding; }

//+------------------------------------------------------------------+
//| NEW: Get Volatility Trend ("EXPANDING", "CONTRACTING", "STABLE")  |
//+------------------------------------------------------------------+
string GetVolatilityTrend() { return g_volatilityTrend; }

//+------------------------------------------------------------------+
//| NEW: Calculate Stop Loss Distance in Price (for Section 12)       |
//| Returns SL distance in price units based on ATR                   |
//+------------------------------------------------------------------+
double CalculateATRStopLoss(int barIndex = 0)
{
   double atr = GetATRPriceAtBar(barIndex);
   return atr * InpATRStopMultiplier;
}

//+------------------------------------------------------------------+
//| NEW: Calculate Take Profit 1 Distance in Price (for Section 12)   |
//+------------------------------------------------------------------+
double CalculateATRTP1(int barIndex = 0)
{
   double atr = GetATRPriceAtBar(barIndex);
   return atr * InpATRTP1Multiplier;
}

//+------------------------------------------------------------------+
//| NEW: Calculate Take Profit 2 Distance in Price (for Section 12)   |
//+------------------------------------------------------------------+
double CalculateATRTP2(int barIndex = 0)
{
   double atr = GetATRPriceAtBar(barIndex);
   return atr * InpATRTP2Multiplier;
}

//+------------------------------------------------------------------+
//| NEW: Calculate Take Profit 3 Distance in Price (for Section 12)   |
//+------------------------------------------------------------------+
double CalculateATRTP3(int barIndex = 0)
{
   double atr = GetATRPriceAtBar(barIndex);
   return atr * InpATRTP3Multiplier;
}

//+------------------------------------------------------------------+
//| NEW: Get All TP/SL Levels at Once (for Section 12)                |
//| Calculates actual price levels from entry price                   |
//+------------------------------------------------------------------+
void GetATRBasedLevels(double entryPrice, bool isBuy,
                       double &slPrice, double &tp1Price,
                       double &tp2Price, double &tp3Price, int barIndex = 0)
{
   double atr = GetATRPriceAtBar(barIndex);

   double slDist = atr * InpATRStopMultiplier;
   double tp1Dist = atr * InpATRTP1Multiplier;
   double tp2Dist = atr * InpATRTP2Multiplier;
   double tp3Dist = atr * InpATRTP3Multiplier;

   if(isBuy)
   {
      slPrice = entryPrice - slDist;
      tp1Price = entryPrice + tp1Dist;
      tp2Price = entryPrice + tp2Dist;
      tp3Price = entryPrice + tp3Dist;
   }
   else
   {
      slPrice = entryPrice + slDist;
      tp1Price = entryPrice - tp1Dist;
      tp2Price = entryPrice - tp2Dist;
      tp3Price = entryPrice - tp3Dist;
   }
}

//+------------------------------------------------------------------+
//| NEW: Get SL/TP Multipliers (for display/reference)                |
//+------------------------------------------------------------------+
double GetSLMultiplier() { return InpATRStopMultiplier; }
double GetTP1Multiplier() { return InpATRTP1Multiplier; }
double GetTP2Multiplier() { return InpATRTP2Multiplier; }
double GetTP3Multiplier() { return InpATRTP3Multiplier; }

//+------------------------------------------------------------------+
//| NEW: Calculate Risk:Reward Ratio for Each TP Level                |
//+------------------------------------------------------------------+
double GetRiskRewardTP1() { return InpATRTP1Multiplier / InpATRStopMultiplier; }
double GetRiskRewardTP2() { return InpATRTP2Multiplier / InpATRStopMultiplier; }
double GetRiskRewardTP3() { return InpATRTP3Multiplier / InpATRStopMultiplier; }

//+------------------------------------------------------------------+
//| NEW: Adjust Position Size Based on Volatility (for Section 11)    |
//| Returns multiplier: 1.0 = normal, <1 = reduce, >1 = increase      |
//+------------------------------------------------------------------+
double GetVolatilityPositionMultiplier()
{
   // In extreme volatility, reduce position size
   if(g_currentResult.condition == MARKET_EXTREME)
      return 0.5;  // Half size in extreme conditions

   // In high percentile (>80), reduce slightly
   if(g_atrPercentile > 80.0)
      return 0.75;

   // In very low volatility/squeeze, can increase slightly
   if(g_volatilitySqueeze)
      return 0.8;  // Still cautious during squeeze

   // Normal conditions
   return 1.0;
}

//+------------------------------------------------------------------+
//| NEW: Is Market Suitable for Swing Trading?                        |
//| Combined check of all volatility conditions                       |
//+------------------------------------------------------------------+
bool IsGoodSwingConditions()
{
   // Not suitable if market too quiet
   if(g_currentResult.condition == MARKET_QUIET && !g_volatilitySqueeze)
      return false;

   // Suitable if normal conditions
   if(g_currentResult.condition == MARKET_NORMAL)
      return true;

   // Extreme but within reasonable percentile is OK with caution
   if(g_currentResult.condition == MARKET_EXTREME && g_atrPercentile < 95.0)
      return true;

   // Squeeze conditions are good for breakout setups
   if(g_volatilitySqueeze)
      return true;

   return false;
}
//+------------------------------------------------------------------+
