//+------------------------------------------------------------------+
//|                                       Section02_EMAAnalysis.mq5  |
//|                                      SwingTrader Pro EA          |
//|                    Section 2: EMA Trend Analysis (50/200)        |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.10"
#property description "Section 2: EMA Analysis"
#property description "EMA 50/200 for H4 trend bias detection"
#property description "Includes crossover detection and visual lines"

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

input group "=== ATR Filter Settings (from Section 1) ==="
input bool     InpUseATRFilter        = true;     // Enable ATR Filter
input int      InpATRPeriod           = 14;       // ATR Period
input double   InpATRQuietThreshold   = 60.0;     // Quiet Market Threshold (pips)
input double   InpATRExtremeThreshold = 250.0;    // Extreme Volatility Threshold (pips)

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;     // Show Info Panel on Chart
input bool     InpShowEMALines        = true;     // Show EMA Lines on Chart
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

// Panel
string         g_panelName = "EMAAnalysisPanel";  // Panel object prefix

// Symbol info
int            g_digits;
double         g_point;
double         g_pipValue;
double         g_pipSize;
string         g_instrumentType;

// EMA Slope (momentum strength)
double         g_emaFastSlope = 0;        // EMA50 slope (% change)
double         g_emaSlowSlope = 0;        // EMA200 slope (% change)
bool           g_slopeConfirmed = false;  // Both slopes align with trend

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get symbol info
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_pipValue = GetPipValue(_Symbol);

   // Auto-detect instrument type and set pip size (same as Section 3)
   string sym = _Symbol;
   StringToUpper(sym);

   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
   {
      g_instrumentType = "GOLD";
      g_pipSize = 0.10;  // Gold: 1 pip = $0.10
      Print("AUTO-DETECT: Gold pair - pip size = 0.10");
   }
   else if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
   {
      g_instrumentType = "SILVER";
      g_pipSize = 0.01;
      Print("AUTO-DETECT: Silver pair - pip size = 0.01");
   }
   else if(StringFind(sym, "JPY") >= 0)
   {
      g_instrumentType = "JPY";
      g_pipSize = g_point * (g_digits == 3 ? 1 : 10);
      Print("AUTO-DETECT: JPY pair");
   }
   else
   {
      g_instrumentType = "FOREX";
      g_pipSize = g_point * (g_digits == 5 ? 10 : 1);
      Print("AUTO-DETECT: Standard forex pair");
   }

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

   // Run initial analysis FIRST (fills buffers)
   AnalyzeEMA();

   // Update panel with initial values (same fix as Section 3/4)
   if(InpShowPanel)
      UpdatePanel();

   // Draw EMA lines AFTER analysis
   if(InpShowEMALines)
      DrawEMALines();

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
   Print("EMA Analysis EA Deinitialized");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check for new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpEMATimeframe, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;

      // Perform analysis
      AnalyzeEMA();

      // Update visuals
      if(InpShowPanel) UpdatePanel();
      if(InpShowEMALines) DrawEMALines();
   }
}

//+------------------------------------------------------------------+
//| Main EMA Analysis Function                                        |
//+------------------------------------------------------------------+
void AnalyzeEMA()
{
   // Copy EMA buffers
   int copied1 = CopyBuffer(g_emaFastHandle, 0, 0, InpHistoryBars, g_emaFastBuffer);
   int copied2 = CopyBuffer(g_emaSlowHandle, 0, 0, InpHistoryBars, g_emaSlowBuffer);

   if(copied1 < InpCrossoverLookback + 1 || copied2 < InpCrossoverLookback + 1)
   {
      Print("ERROR: Failed to copy EMA buffers. Fast:", copied1, " Slow:", copied2);
      return;
   }

   // ATR Filter check
   if(InpUseATRFilter)
   {
      AnalyzeATR();
   }

   // Store current values
   g_emaResult.ema50 = g_emaFastBuffer[0];
   g_emaResult.ema200 = g_emaSlowBuffer[0];
   g_emaResult.timestamp = TimeCurrent();

   // Determine trend bias
   DetermineTrendBias();

   // Calculate EMA slopes (momentum strength)
   CalculateEMASlope();

   // Check for recent crossover (with price confirmation)
   DetectCrossover();

   // Print report
   if(InpPrintReport)
      PrintEMAReport();
}

//+------------------------------------------------------------------+
//| Analyze ATR (from Section 1)                                      |
//+------------------------------------------------------------------+
void AnalyzeATR()
{
   int copied = CopyBuffer(g_atrHandle, 0, 0, 1, g_atrBuffer);

   if(copied < 1)
   {
      Print("ERROR: Failed to copy ATR buffer");
      return;
   }

   double atrPoints = g_atrBuffer[0];
   double atrPips;

   // Convert ATR to pips using auto-detected pip size
   // FIX: Use proper pip size instead of hardcoded *10 for Gold
   if(g_pipSize > 0)
      atrPips = atrPoints / g_pipSize;
   else
      atrPips = PointsToPips(_Symbol, atrPoints);

   g_atrResult.atrValue = atrPips;
   g_atrResult.timestamp = TimeCurrent();

   // Classify market condition
   if(atrPips < InpATRQuietThreshold)
   {
      g_atrResult.condition = MARKET_QUIET;
      g_atrResult.tradingAllowed = false;
      g_atrResult.reason = "Market too quiet";
   }
   else if(atrPips > InpATRExtremeThreshold)
   {
      g_atrResult.condition = MARKET_EXTREME;
      g_atrResult.tradingAllowed = true;
      g_atrResult.reason = "Extreme volatility - adjust position size";
   }
   else
   {
      g_atrResult.condition = MARKET_NORMAL;
      g_atrResult.tradingAllowed = true;
      g_atrResult.reason = "Normal conditions";
   }
}

//+------------------------------------------------------------------+
//| Determine Trend Bias                                              |
//+------------------------------------------------------------------+
void DetermineTrendBias()
{
   double emaFast = g_emaFastBuffer[0];
   double emaSlow = g_emaSlowBuffer[0];
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Calculate EMA difference as percentage
   double emaDiff = (emaFast - emaSlow) / emaSlow * 100;
   double priceToFast = (currentPrice - emaFast) / emaFast * 100;

   // Determine bias
   // Bullish: EMA50 > EMA200 AND price above EMA50
   // Bearish: EMA50 < EMA200 AND price below EMA50
   // Neutral: Mixed signals or EMAs too close

   double threshold = 0.1; // 0.1% threshold for "too close"

   if(MathAbs(emaDiff) < threshold)
   {
      // EMAs are too close - neutral/consolidation
      g_emaResult.trend = BIAS_NEUTRAL;
   }
   else if(emaFast > emaSlow)
   {
      // EMA50 above EMA200
      if(currentPrice >= emaFast)
      {
         // Price above both EMAs - strong bullish
         g_emaResult.trend = BIAS_BULLISH;
      }
      else if(currentPrice >= emaSlow)
      {
         // Price between EMAs - weak bullish (potential pullback)
         g_emaResult.trend = BIAS_BULLISH;
      }
      else
      {
         // Price below both but fast > slow - potential reversal
         g_emaResult.trend = BIAS_NEUTRAL;
      }
   }
   else
   {
      // EMA50 below EMA200
      if(currentPrice <= emaFast)
      {
         // Price below both EMAs - strong bearish
         g_emaResult.trend = BIAS_BEARISH;
      }
      else if(currentPrice <= emaSlow)
      {
         // Price between EMAs - weak bearish (potential pullback)
         g_emaResult.trend = BIAS_BEARISH;
      }
      else
      {
         // Price above both but fast < slow - potential reversal
         g_emaResult.trend = BIAS_NEUTRAL;
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate EMA Slope (momentum strength)                           |
//| Slope = % change over last 5 bars                                 |
//+------------------------------------------------------------------+
void CalculateEMASlope()
{
   int slopeBars = 5;  // Calculate slope over 5 bars

   if(ArraySize(g_emaFastBuffer) < slopeBars + 1 ||
      ArraySize(g_emaSlowBuffer) < slopeBars + 1)
   {
      g_emaFastSlope = 0;
      g_emaSlowSlope = 0;
      g_slopeConfirmed = false;
      return;
   }

   // EMA50 slope: (current - 5 bars ago) / 5 bars ago * 100
   g_emaFastSlope = (g_emaFastBuffer[0] - g_emaFastBuffer[slopeBars]) /
                     g_emaFastBuffer[slopeBars] * 100;

   // EMA200 slope: (current - 5 bars ago) / 5 bars ago * 100
   g_emaSlowSlope = (g_emaSlowBuffer[0] - g_emaSlowBuffer[slopeBars]) /
                     g_emaSlowBuffer[slopeBars] * 100;

   // Check if slopes confirm trend
   // Bullish: Both slopes positive
   // Bearish: Both slopes negative
   if(g_emaResult.trend == BIAS_BULLISH)
      g_slopeConfirmed = (g_emaFastSlope > 0 && g_emaSlowSlope > 0);
   else if(g_emaResult.trend == BIAS_BEARISH)
      g_slopeConfirmed = (g_emaFastSlope < 0 && g_emaSlowSlope < 0);
   else
      g_slopeConfirmed = false;
}

//+------------------------------------------------------------------+
//| Detect Recent Crossover with Price Confirmation                   |
//| IMPROVED: Also checks if price reacted after crossover            |
//+------------------------------------------------------------------+
void DetectCrossover()
{
   g_emaResult.recentCrossover = false;
   g_emaResult.candlesSinceCross = -1;

   // Look for crossover in recent candles
   for(int i = 0; i < InpCrossoverLookback; i++)
   {
      if(i + 1 >= ArraySize(g_emaFastBuffer) || i + 1 >= ArraySize(g_emaSlowBuffer))
         break;

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

         // Check for price confirmation after crossover
         // Price should move in crossover direction
         if(i > 0)
         {
            double priceAtCross = iClose(_Symbol, InpEMATimeframe, i);
            double priceNow = iClose(_Symbol, InpEMATimeframe, 0);

            bool priceConfirmed = false;
            if(bullishCross && priceNow > priceAtCross)
               priceConfirmed = true;
            else if(bearishCross && priceNow < priceAtCross)
               priceConfirmed = true;

            // If crossover is old (5+ bars) and price confirmed, treat as established
            if(i >= 5 && priceConfirmed)
            {
               // Crossover is confirmed, treat trend as established
               g_emaResult.recentCrossover = false;
               if(InpPrintReport)
                  Print("Crossover CONFIRMED: Price reaction validates the ", bullishCross ? "bullish" : "bearish", " cross");
            }
         }
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Print EMA Analysis Report                                         |
//+------------------------------------------------------------------+
void PrintEMAReport()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double distanceToEMA50 = currentPrice - g_emaResult.ema50;
   double distanceToEMA200 = currentPrice - g_emaResult.ema200;
   double emaGap = g_emaResult.ema50 - g_emaResult.ema200;

   Print("");
   Print("=================================================");
   Print("         EMA ANALYSIS REPORT (Section 2)         ");
   Print("=================================================");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", TimeframeToString(InpEMATimeframe));
   Print("Analysis Time: ", TimeToString(g_emaResult.timestamp, TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");

   // ATR Filter Status (if enabled)
   if(InpUseATRFilter)
   {
      Print("ATR FILTER STATUS:");
      Print("  ATR Value: ", DoubleToString(g_atrResult.atrValue, 2), " pips");
      Print("  Condition: ", MarketConditionToString(g_atrResult.condition));
      Print("  Trading: ", g_atrResult.tradingAllowed ? "ALLOWED" : "BLOCKED");
      Print("-------------------------------------------------");
   }

   Print("EMA VALUES:");
   Print("  EMA ", InpEMAFastPeriod, ": ", DoubleToString(g_emaResult.ema50, g_digits));
   Print("  EMA ", InpEMASlowPeriod, ": ", DoubleToString(g_emaResult.ema200, g_digits));
   Print("  EMA Gap: ", DoubleToString(emaGap, g_digits),
         " (", DoubleToString(emaGap/g_emaResult.ema200*100, 2), "%)");
   Print("-------------------------------------------------");

   Print("EMA MOMENTUM (Slope):");
   Print("  EMA", InpEMAFastPeriod, " Slope: ", DoubleToString(g_emaFastSlope, 4), "% (5 bars)");
   Print("  EMA", InpEMASlowPeriod, " Slope: ", DoubleToString(g_emaSlowSlope, 4), "% (5 bars)");
   Print("  Slope Confirms Trend: ", g_slopeConfirmed ? "YES" : "NO");
   Print("-------------------------------------------------");

   Print("PRICE POSITION:");
   Print("  Current Price: ", DoubleToString(currentPrice, g_digits));
   Print("  Distance to EMA", InpEMAFastPeriod, ": ", DoubleToString(distanceToEMA50, g_digits),
         " (", distanceToEMA50 > 0 ? "ABOVE" : "BELOW", ")");
   Print("  Distance to EMA", InpEMASlowPeriod, ": ", DoubleToString(distanceToEMA200, g_digits),
         " (", distanceToEMA200 > 0 ? "ABOVE" : "BELOW", ")");
   Print("-------------------------------------------------");

   Print("TREND ANALYSIS:");
   Print("  EMA Alignment: ", g_emaResult.ema50 > g_emaResult.ema200 ?
         "BULLISH (EMA50 > EMA200)" : "BEARISH (EMA50 < EMA200)");
   Print("  Price vs EMAs: ", GetPricePositionDescription(currentPrice));
   Print("-------------------------------------------------");

   Print("H4 BIAS: ", TrendBiasToString(g_emaResult.trend));

   // Crossover info
   Print("-------------------------------------------------");
   Print("CROSSOVER DETECTION:");
   if(g_emaResult.recentCrossover)
   {
      string crossType = g_emaFastBuffer[g_emaResult.candlesSinceCross] >
                         g_emaSlowBuffer[g_emaResult.candlesSinceCross] ?
                         "BULLISH (Golden Cross)" : "BEARISH (Death Cross)";
      Print("  Recent Crossover: YES");
      Print("  Type: ", crossType);
      Print("  Candles Ago: ", g_emaResult.candlesSinceCross);
      Print("  WARNING: Trade with caution - recent trend change!");
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
   Print("=== END EMA REPORT ===");
   Print("");
}

//+------------------------------------------------------------------+
//| Get Price Position Description                                    |
//+------------------------------------------------------------------+
string GetPricePositionDescription(double price)
{
   if(price > g_emaResult.ema50 && price > g_emaResult.ema200)
      return "Above both EMAs (Strong Bullish)";
   else if(price < g_emaResult.ema50 && price < g_emaResult.ema200)
      return "Below both EMAs (Strong Bearish)";
   else if(price > g_emaResult.ema200 && price < g_emaResult.ema50)
      return "Between EMAs, below EMA50 (Bullish Pullback)";
   else if(price < g_emaResult.ema200 && price > g_emaResult.ema50)
      return "Between EMAs, above EMA50 (Bearish Pullback)";
   else
      return "At EMA level";
}

//+------------------------------------------------------------------+
//| Print Trading Recommendation                                      |
//+------------------------------------------------------------------+
void PrintTradingRecommendation()
{
   // Check ATR filter first
   if(InpUseATRFilter && !g_atrResult.tradingAllowed)
   {
      Print("  STATUS: NO TRADE");
      Print("  REASON: Market too quiet (ATR filter)");
      return;
   }

   // Check for recent crossover
   if(g_emaResult.recentCrossover && g_emaResult.candlesSinceCross < 3)
   {
      Print("  STATUS: WAIT");
      Print("  REASON: Very recent crossover - wait for confirmation");
      return;
   }

   // Based on trend bias
   switch(g_emaResult.trend)
   {
      case BIAS_BULLISH:
         Print("  STATUS: LOOK FOR BUYS");
         Print("  REASON: EMA50 > EMA200, price in bullish position");
         Print("  ACTION: Wait for BOS/CHoCH confirmation on H4");
         Print("  ENTRY: Look for demand zone + bullish structure on H1/M15");
         break;

      case BIAS_BEARISH:
         Print("  STATUS: LOOK FOR SELLS");
         Print("  REASON: EMA50 < EMA200, price in bearish position");
         Print("  ACTION: Wait for BOS/CHoCH confirmation on H4");
         Print("  ENTRY: Look for supply zone + bearish structure on H1/M15");
         break;

      case BIAS_NEUTRAL:
         Print("  STATUS: NO TRADE");
         Print("  REASON: Mixed signals - EMAs too close or conflicting");
         Print("  ACTION: Wait for clear trend establishment");
         break;
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
   Print("     EMA TREND ANALYSIS                          ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol);
   Print("TIMEFRAME: ", TimeframeToString(InpEMATimeframe));
   Print("-------------------------------------------------");
   Print("EMA SETTINGS:");
   Print("  Fast EMA Period: ", InpEMAFastPeriod);
   Print("  Slow EMA Period: ", InpEMASlowPeriod);
   Print("  Applied Price: ", EnumToString(InpEMAPrice));
   Print("  Crossover Lookback: ", InpCrossoverLookback, " candles");
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
   Print("TREND BIAS RULES:");
   Print("  BULLISH: EMA50 > EMA200 + Price above demand");
   Print("  BEARISH: EMA50 < EMA200 + Price below supply");
   Print("  NEUTRAL: Mixed signals or recent crossover");
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

   // Background (increased height for slope row)
   CreateRectangle(g_panelName + "_bg", x, y, 300, 260, clrBlack, 200);

   // Title
   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "EMA TREND ANALYSIS", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "--------------------------------", clrGray, 8, "Courier New");

   // ATR Status (if enabled)
   if(InpUseATRFilter)
   {
      CreateLabel(g_panelName + "_atr_label", x + 10, y + 40, "ATR Filter:", clrWhite, 9, "Arial");
      CreateLabel(g_panelName + "_atr_value", x + 150, y + 40, "-- pips", clrYellow, 9, "Arial");
      CreateLabel(g_panelName + "_atr_status", x + 220, y + 40, "[--]", clrGray, 9, "Arial Bold");
   }

   // EMA Values
   int yOffset = InpUseATRFilter ? 60 : 40;

   CreateLabel(g_panelName + "_ema50_label", x + 10, y + yOffset,
               "EMA " + IntegerToString(InpEMAFastPeriod) + ":", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_ema50_value", x + 150, y + yOffset, "--", clrDodgerBlue, 9, "Arial Bold");

   CreateLabel(g_panelName + "_ema200_label", x + 10, y + yOffset + 20,
               "EMA " + IntegerToString(InpEMASlowPeriod) + ":", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_ema200_value", x + 150, y + yOffset + 20, "--", clrOrangeRed, 9, "Arial Bold");

   CreateLabel(g_panelName + "_gap_label", x + 10, y + yOffset + 40, "EMA Gap:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_gap_value", x + 150, y + yOffset + 40, "--", clrYellow, 9, "Arial");

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOffset + 60,
               "--------------------------------", clrGray, 8, "Courier New");

   // Price Position
   CreateLabel(g_panelName + "_price_label", x + 10, y + yOffset + 75, "Price:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_price_value", x + 150, y + yOffset + 75, "--", clrWhite, 9, "Arial Bold");

   CreateLabel(g_panelName + "_position_label", x + 10, y + yOffset + 95, "Position:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_position_value", x + 150, y + yOffset + 95, "--", clrYellow, 9, "Arial");

   CreateLabel(g_panelName + "_sep3", x + 10, y + yOffset + 115,
               "--------------------------------", clrGray, 8, "Courier New");

   // Trend Bias
   CreateLabel(g_panelName + "_bias_label", x + 10, y + yOffset + 130, "H4 BIAS:", clrWhite, 10, "Arial Bold");
   CreateLabel(g_panelName + "_bias_value", x + 150, y + yOffset + 130, "ANALYZING...", clrYellow, 10, "Arial Bold");

   // Crossover
   CreateLabel(g_panelName + "_cross_label", x + 10, y + yOffset + 150, "Crossover:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_cross_value", x + 150, y + yOffset + 150, "--", clrGray, 9, "Arial");

   // Slope (momentum)
   CreateLabel(g_panelName + "_slope_label", x + 10, y + yOffset + 170, "Momentum:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_slope_value", x + 150, y + yOffset + 170, "--", clrGray, 9, "Arial");

   // Recommendation
   CreateLabel(g_panelName + "_sep4", x + 10, y + yOffset + 190,
               "--------------------------------", clrGray, 8, "Courier New");
   CreateLabel(g_panelName + "_rec_label", x + 10, y + yOffset + 205, "Action:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_rec_value", x + 100, y + yOffset + 205, "WAIT", clrYellow, 9, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel) return;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double emaGap = g_emaResult.ema50 - g_emaResult.ema200;

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

   // Update EMA values
   ObjectSetString(0, g_panelName + "_ema50_value", OBJPROP_TEXT,
                   DoubleToString(g_emaResult.ema50, g_digits));
   ObjectSetString(0, g_panelName + "_ema200_value", OBJPROP_TEXT,
                   DoubleToString(g_emaResult.ema200, g_digits));
   ObjectSetString(0, g_panelName + "_gap_value", OBJPROP_TEXT,
                   DoubleToString(emaGap, g_digits));

   // Update price
   ObjectSetString(0, g_panelName + "_price_value", OBJPROP_TEXT,
                   DoubleToString(currentPrice, g_digits));

   // Update position
   string posText = "";
   if(currentPrice > g_emaResult.ema50 && currentPrice > g_emaResult.ema200)
      posText = "Above Both";
   else if(currentPrice < g_emaResult.ema50 && currentPrice < g_emaResult.ema200)
      posText = "Below Both";
   else
      posText = "Between EMAs";
   ObjectSetString(0, g_panelName + "_position_value", OBJPROP_TEXT, posText);

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
      ObjectSetString(0, g_panelName + "_cross_value", OBJPROP_TEXT,
                      "YES (" + IntegerToString(g_emaResult.candlesSinceCross) + " bars ago)");
      ObjectSetInteger(0, g_panelName + "_cross_value", OBJPROP_COLOR, clrOrange);
   }
   else
   {
      ObjectSetString(0, g_panelName + "_cross_value", OBJPROP_TEXT, "No (Trend OK)");
      ObjectSetInteger(0, g_panelName + "_cross_value", OBJPROP_COLOR, clrLimeGreen);
   }

   // Update slope (momentum)
   string slopeText = "";
   color slopeColor = clrGray;

   if(g_slopeConfirmed)
   {
      slopeText = "STRONG";
      slopeColor = (g_emaResult.trend == BIAS_BULLISH) ? clrLimeGreen : clrRed;
   }
   else if(g_emaFastSlope != 0 || g_emaSlowSlope != 0)
   {
      slopeText = "WEAK";
      slopeColor = clrYellow;
   }
   else
   {
      slopeText = "--";
   }
   ObjectSetString(0, g_panelName + "_slope_value", OBJPROP_TEXT, slopeText);
   ObjectSetInteger(0, g_panelName + "_slope_value", OBJPROP_COLOR, slopeColor);

   // Update recommendation
   string recText = "";
   color recColor = clrGray;

   if(InpUseATRFilter && !g_atrResult.tradingAllowed)
   {
      recText = "NO TRADE (ATR)";
      recColor = clrGray;
   }
   else if(g_emaResult.recentCrossover && g_emaResult.candlesSinceCross < 3)
   {
      recText = "WAIT (Crossover)";
      recColor = clrOrange;
   }
   else
   {
      switch(g_emaResult.trend)
      {
         case BIAS_BULLISH: recText = "LOOK FOR BUYS"; recColor = clrLimeGreen; break;
         case BIAS_BEARISH: recText = "LOOK FOR SELLS"; recColor = clrRed; break;
         case BIAS_NEUTRAL: recText = "NO TRADE"; recColor = clrGray; break;
      }
   }
   ObjectSetString(0, g_panelName + "_rec_value", OBJPROP_TEXT, recText);
   ObjectSetInteger(0, g_panelName + "_rec_value", OBJPROP_COLOR, recColor);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw EMA Lines on Chart                                           |
//| OPTIMIZED: Limits to 100 bars to reduce lag                       |
//+------------------------------------------------------------------+
void DrawEMALines()
{
   if(!InpShowEMALines) return;

   // Check if buffers have data
   int fastSize = ArraySize(g_emaFastBuffer);
   int slowSize = ArraySize(g_emaSlowBuffer);

   if(fastSize < 2 || slowSize < 2)
   {
      Print("DrawEMALines: Waiting for buffer data...");
      return;
   }

   // OPTIMIZATION: Limit to 100 bars max to reduce lag (was InpHistoryBars = 300)
   int maxBarsForLines = 100;
   int barsToShow = MathMin(maxBarsForLines, MathMin(fastSize, slowSize));

   // Remove old lines
   ObjectsDeleteAll(0, "EMA_Line_");
   ObjectDelete(0, "EMA_Label_Fast");
   ObjectDelete(0, "EMA_Label_Slow");

   // Draw EMA lines using trend lines between points
   for(int i = 0; i < barsToShow - 1; i++)
   {
      datetime time1 = iTime(_Symbol, InpEMATimeframe, i);
      datetime time2 = iTime(_Symbol, InpEMATimeframe, i + 1);

      // EMA Fast line segment
      string fastName = "EMA_Line_Fast_" + IntegerToString(i);
      ObjectCreate(0, fastName, OBJ_TREND, 0, time2, g_emaFastBuffer[i+1], time1, g_emaFastBuffer[i]);
      ObjectSetInteger(0, fastName, OBJPROP_COLOR, InpEMAFastColor);
      ObjectSetInteger(0, fastName, OBJPROP_WIDTH, InpEMALineWidth);
      ObjectSetInteger(0, fastName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, fastName, OBJPROP_BACK, true);
      ObjectSetInteger(0, fastName, OBJPROP_SELECTABLE, false);

      // EMA Slow line segment
      string slowName = "EMA_Line_Slow_" + IntegerToString(i);
      ObjectCreate(0, slowName, OBJ_TREND, 0, time2, g_emaSlowBuffer[i+1], time1, g_emaSlowBuffer[i]);
      ObjectSetInteger(0, slowName, OBJPROP_COLOR, InpEMASlowColor);
      ObjectSetInteger(0, slowName, OBJPROP_WIDTH, InpEMALineWidth);
      ObjectSetInteger(0, slowName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, slowName, OBJPROP_BACK, true);
      ObjectSetInteger(0, slowName, OBJPROP_SELECTABLE, false);
   }

   // Add labels for EMAs
   datetime labelTime = iTime(_Symbol, InpEMATimeframe, 0);

   ObjectCreate(0, "EMA_Label_Fast", OBJ_TEXT, 0, labelTime, g_emaFastBuffer[0]);
   ObjectSetString(0, "EMA_Label_Fast", OBJPROP_TEXT, "EMA" + IntegerToString(InpEMAFastPeriod));
   ObjectSetInteger(0, "EMA_Label_Fast", OBJPROP_COLOR, InpEMAFastColor);
   ObjectSetInteger(0, "EMA_Label_Fast", OBJPROP_FONTSIZE, 8);

   ObjectCreate(0, "EMA_Label_Slow", OBJ_TEXT, 0, labelTime, g_emaSlowBuffer[0]);
   ObjectSetString(0, "EMA_Label_Slow", OBJPROP_TEXT, "EMA" + IntegerToString(InpEMASlowPeriod));
   ObjectSetInteger(0, "EMA_Label_Slow", OBJPROP_COLOR, InpEMASlowColor);
   ObjectSetInteger(0, "EMA_Label_Slow", OBJPROP_FONTSIZE, 8);

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
EMAAnalysisResult GetEMAResult() { return g_emaResult; }
ATRFilterResult GetATRResult() { return g_atrResult; }
ENUM_TREND_BIAS GetH4Bias() { return g_emaResult.trend; }
bool IsTrendEstablished() { return !g_emaResult.recentCrossover; }
bool IsTradingAllowed() { return (!InpUseATRFilter || g_atrResult.tradingAllowed) &&
                                 g_emaResult.trend != BIAS_NEUTRAL; }
//+------------------------------------------------------------------+
