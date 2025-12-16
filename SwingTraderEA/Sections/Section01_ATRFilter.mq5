//+------------------------------------------------------------------+
//|                                         Section01_ATRFilter.mq5  |
//|                                      SwingTrader Pro EA          |
//|                 Section 1: Base Framework + ATR Volatility Filter |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.10"
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

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get symbol info
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_pipValue = GetPipValue(_Symbol);

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

   // Print report if enabled
   if(InpPrintReport)
      PrintATRReport();
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
   Print("  Symbol: ", _Symbol);
   Print("  Digits: ", g_digits);
   Print("  Point: ", DoubleToString(g_point, g_digits));
   Print("  Pip Value: ", DoubleToString(g_pipValue, g_digits));
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
   Print("NEW PUBLIC FUNCTIONS:");
   Print("  GetATRPriceAtBar(bar) - ATR in price units");
   Print("  GetATRPipsAtBar(bar)  - ATR in pips");
   Print("  IsValidLegOut(move, bar) - Check leg-out >= 2x ATR");
   Print("  IsValidBase(body, bar)   - Check base <= 0.5x ATR");
   Print("  CalculateZoneScore()     - Zone quality score (0-13)");
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

   // Background rectangle
   CreateRectangle(g_panelName + "_bg", x, y, 280, 180, clrBlack, 200);

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

   // Time
   CreateLabel(g_panelName + "_time", x + 10, y + 165,
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
