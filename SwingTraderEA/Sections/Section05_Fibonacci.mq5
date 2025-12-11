//+------------------------------------------------------------------+
//|                                        Section05_Fibonacci.mq5   |
//|                                      SwingTrader Pro EA          |
//|                  Section 5: Fibonacci Retracement & Fan          |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.00"
#property description "Section 5: Fibonacci Retracement & Fan"
#property description "Auto-draws Fibonacci levels from swing points"
#property description "Key levels: 23.6%, 38.2%, 50%, 61.8%, 78.6%"

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Fibonacci Settings ==="
input int      InpFibLookback         = 100;      // Lookback for Swing Detection (candles)
input int      InpSwingStrength       = 5;        // Swing Strength (bars each side)
input bool     InpShowRetracement     = true;     // Show Retracement Levels
input bool     InpShowExtension       = true;     // Show Extension Levels
input bool     InpShowFibFan          = false;    // Show Fibonacci Fan
input ENUM_TIMEFRAMES InpFibTimeframe = PERIOD_H4; // Fibonacci Timeframe

input group "=== Retracement Levels ==="
input bool     InpShow236             = true;     // Show 23.6% Level
input bool     InpShow382             = true;     // Show 38.2% Level
input bool     InpShow500             = true;     // Show 50.0% Level
input bool     InpShow618             = true;     // Show 61.8% Level (Golden Ratio)
input bool     InpShow786             = true;     // Show 78.6% Level

input group "=== Extension Levels ==="
input bool     InpShow1272            = true;     // Show 127.2% Level
input bool     InpShow1618            = true;     // Show 161.8% Level
input bool     InpShow2000            = false;    // Show 200.0% Level
input bool     InpShow2618            = false;    // Show 261.8% Level

input group "=== EMA Settings (from Section 2) ==="
input bool     InpUseEMAFilter        = true;     // Use EMA for Fib Direction
input int      InpEMAFastPeriod       = 50;       // EMA Fast Period
input int      InpEMASlowPeriod       = 200;      // EMA Slow Period

input group "=== ATR Settings (from Section 1) ==="
input bool     InpUseATRFilter        = true;     // Use ATR Volatility Filter
input int      InpATRPeriod           = 14;       // ATR Period
input double   InpATRQuietThreshold   = 60.0;     // Quiet Market Threshold (pips)
input double   InpATRExtremeThreshold = 250.0;    // Extreme Volatility Threshold (pips)

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;     // Show Info Panel
input color    InpFibColor            = clrGold;  // Fibonacci Lines Color
input color    InpFib618Color         = clrOrange; // 61.8% Level Color (highlight)
input color    InpExtensionColor      = clrLimeGreen; // Extension Levels Color
input color    InpFanColor            = clrDodgerBlue; // Fan Lines Color
input int      InpFibLineWidth        = 1;        // Line Width
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
double         g_closeBuffer[];
datetime       g_timeBuffer[];

// Fibonacci data
double         g_fibSwingHigh;
double         g_fibSwingLow;
datetime       g_fibSwingHighTime;
datetime       g_fibSwingLowTime;
int            g_fibSwingHighBar;
int            g_fibSwingLowBar;
ENUM_TREND_BIAS g_fibDirection;
bool           g_fibValid = false;

// Fibonacci levels
double         g_fibLevels[];
string         g_fibLabels[];
int            g_fibLevelCount = 0;

// Results from previous sections
EMAAnalysisResult g_emaResult;
ATRFilterResult   g_atrResult;

// Panel
string         g_panelName = "FibPanel";

// Symbol info
int            g_digits;
double         g_point;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get symbol info
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Initialize arrays
   ArraySetAsSeries(g_highBuffer, true);
   ArraySetAsSeries(g_lowBuffer, true);
   ArraySetAsSeries(g_closeBuffer, true);
   ArraySetAsSeries(g_timeBuffer, true);

   // Initialize Fib levels array (max 12 levels)
   ArrayResize(g_fibLevels, 12);
   ArrayResize(g_fibLabels, 12);

   // Create EMA handles if filter enabled
   if(InpUseEMAFilter)
   {
      g_emaFastHandle = iMA(_Symbol, InpFibTimeframe, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_emaSlowHandle = iMA(_Symbol, InpFibTimeframe, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);

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
      g_atrHandle = iATR(_Symbol, InpFibTimeframe, InpATRPeriod);
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
   AnalyzeFibonacci();

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
   ObjectsDeleteAll(0, "Fib_");

   Print("=================================================");
   Print("Fibonacci EA Deinitialized");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpFibTimeframe, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      AnalyzeFibonacci();

      if(InpShowPanel) UpdatePanel();
   }
}

//+------------------------------------------------------------------+
//| Main Fibonacci Analysis Function                                  |
//+------------------------------------------------------------------+
void AnalyzeFibonacci()
{
   // Copy price data
   int barsNeeded = InpFibLookback + InpSwingStrength + 5;

   if(CopyHigh(_Symbol, InpFibTimeframe, 0, barsNeeded, g_highBuffer) < barsNeeded) return;
   if(CopyLow(_Symbol, InpFibTimeframe, 0, barsNeeded, g_lowBuffer) < barsNeeded) return;
   if(CopyClose(_Symbol, InpFibTimeframe, 0, barsNeeded, g_closeBuffer) < barsNeeded) return;
   if(CopyTime(_Symbol, InpFibTimeframe, 0, barsNeeded, g_timeBuffer) < barsNeeded) return;

   // Analyze ATR if enabled
   if(InpUseATRFilter)
      AnalyzeATR();

   // Analyze EMA if enabled
   if(InpUseEMAFilter)
      AnalyzeEMA();

   // Find swing points for Fibonacci
   FindFibonacciSwings();

   // Calculate Fibonacci levels
   if(g_fibValid)
   {
      CalculateFibLevels();
      DrawFibonacci();
   }

   // Print report
   if(InpPrintReport)
      PrintFibReport();
}

//+------------------------------------------------------------------+
//| Analyze ATR                                                       |
//+------------------------------------------------------------------+
void AnalyzeATR()
{
   if(CopyBuffer(g_atrHandle, 0, 0, 1, g_atrBuffer) < 1) return;

   double atrPoints = g_atrBuffer[0];
   double atrPips;

   if(StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0)
      atrPips = atrPoints * 10;
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
//| Find Swing Points for Fibonacci                                   |
//+------------------------------------------------------------------+
void FindFibonacciSwings()
{
   g_fibValid = false;

   // Find the most significant swing high and swing low
   double highestHigh = 0;
   double lowestLow = DBL_MAX;
   int highestBar = -1;
   int lowestBar = -1;

   // Scan for swing highs and lows
   for(int i = InpSwingStrength; i < InpFibLookback - InpSwingStrength; i++)
   {
      // Check for swing high
      if(IsSwingHigh(i))
      {
         if(g_highBuffer[i] > highestHigh)
         {
            highestHigh = g_highBuffer[i];
            highestBar = i;
         }
      }

      // Check for swing low
      if(IsSwingLow(i))
      {
         if(g_lowBuffer[i] < lowestLow)
         {
            lowestLow = g_lowBuffer[i];
            lowestBar = i;
         }
      }
   }

   // Validate swing points found
   if(highestBar == -1 || lowestBar == -1)
   {
      Print("Fibonacci: Could not find valid swing points");
      return;
   }

   // Store swing points
   g_fibSwingHigh = highestHigh;
   g_fibSwingLow = lowestLow;
   g_fibSwingHighBar = highestBar;
   g_fibSwingLowBar = lowestBar;
   g_fibSwingHighTime = g_timeBuffer[highestBar];
   g_fibSwingLowTime = g_timeBuffer[lowestBar];

   // Determine Fibonacci direction based on which swing is more recent
   // and EMA trend
   if(InpUseEMAFilter)
   {
      // Use EMA to determine direction
      g_fibDirection = g_emaResult.trend;
   }
   else
   {
      // Use swing point timing - more recent swing determines direction
      if(highestBar < lowestBar)
      {
         // High is more recent - bearish retracement (price went up then pulling back)
         g_fibDirection = BIAS_BEARISH;
      }
      else
      {
         // Low is more recent - bullish retracement (price went down then bouncing)
         g_fibDirection = BIAS_BULLISH;
      }
   }

   g_fibValid = true;
}

//+------------------------------------------------------------------+
//| Check if bar is a Swing High                                      |
//+------------------------------------------------------------------+
bool IsSwingHigh(int index)
{
   double currentHigh = g_highBuffer[index];

   for(int i = 1; i <= InpSwingStrength; i++)
   {
      if(index + i >= ArraySize(g_highBuffer) || index - i < 0)
         return false;

      if(g_highBuffer[index + i] >= currentHigh || g_highBuffer[index - i] >= currentHigh)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is a Swing Low                                       |
//+------------------------------------------------------------------+
bool IsSwingLow(int index)
{
   double currentLow = g_lowBuffer[index];

   for(int i = 1; i <= InpSwingStrength; i++)
   {
      if(index + i >= ArraySize(g_lowBuffer) || index - i < 0)
         return false;

      if(g_lowBuffer[index + i] <= currentLow || g_lowBuffer[index - i] <= currentLow)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Fibonacci Levels                                        |
//+------------------------------------------------------------------+
void CalculateFibLevels()
{
   g_fibLevelCount = 0;
   double range = g_fibSwingHigh - g_fibSwingLow;

   if(g_fibDirection == BIAS_BULLISH)
   {
      // Bullish: Draw from low to high
      // Retracement levels are below current price
      // Extension levels are above swing high

      // Add 0% (swing low)
      AddFibLevel(g_fibSwingLow, "0.0%");

      // Retracement levels
      if(InpShowRetracement)
      {
         if(InpShow236) AddFibLevel(g_fibSwingHigh - range * 0.236, "23.6%");
         if(InpShow382) AddFibLevel(g_fibSwingHigh - range * 0.382, "38.2%");
         if(InpShow500) AddFibLevel(g_fibSwingHigh - range * 0.500, "50.0%");
         if(InpShow618) AddFibLevel(g_fibSwingHigh - range * 0.618, "61.8%");
         if(InpShow786) AddFibLevel(g_fibSwingHigh - range * 0.786, "78.6%");
      }

      // Add 100% (swing high)
      AddFibLevel(g_fibSwingHigh, "100%");

      // Extension levels
      if(InpShowExtension)
      {
         if(InpShow1272) AddFibLevel(g_fibSwingLow + range * 1.272, "127.2%");
         if(InpShow1618) AddFibLevel(g_fibSwingLow + range * 1.618, "161.8%");
         if(InpShow2000) AddFibLevel(g_fibSwingLow + range * 2.000, "200%");
         if(InpShow2618) AddFibLevel(g_fibSwingLow + range * 2.618, "261.8%");
      }
   }
   else // BEARISH
   {
      // Bearish: Draw from high to low
      // Retracement levels are above current price
      // Extension levels are below swing low

      // Add 0% (swing high)
      AddFibLevel(g_fibSwingHigh, "0.0%");

      // Retracement levels
      if(InpShowRetracement)
      {
         if(InpShow236) AddFibLevel(g_fibSwingLow + range * 0.236, "23.6%");
         if(InpShow382) AddFibLevel(g_fibSwingLow + range * 0.382, "38.2%");
         if(InpShow500) AddFibLevel(g_fibSwingLow + range * 0.500, "50.0%");
         if(InpShow618) AddFibLevel(g_fibSwingLow + range * 0.618, "61.8%");
         if(InpShow786) AddFibLevel(g_fibSwingLow + range * 0.786, "78.6%");
      }

      // Add 100% (swing low)
      AddFibLevel(g_fibSwingLow, "100%");

      // Extension levels
      if(InpShowExtension)
      {
         if(InpShow1272) AddFibLevel(g_fibSwingHigh - range * 1.272, "127.2%");
         if(InpShow1618) AddFibLevel(g_fibSwingHigh - range * 1.618, "161.8%");
         if(InpShow2000) AddFibLevel(g_fibSwingHigh - range * 2.000, "200%");
         if(InpShow2618) AddFibLevel(g_fibSwingHigh - range * 2.618, "261.8%");
      }
   }
}

//+------------------------------------------------------------------+
//| Add Fibonacci Level                                               |
//+------------------------------------------------------------------+
void AddFibLevel(double price, string label)
{
   if(g_fibLevelCount < 12)
   {
      g_fibLevels[g_fibLevelCount] = price;
      g_fibLabels[g_fibLevelCount] = label;
      g_fibLevelCount++;
   }
}

//+------------------------------------------------------------------+
//| Draw Fibonacci on Chart                                           |
//+------------------------------------------------------------------+
void DrawFibonacci()
{
   // Remove old Fib objects
   ObjectsDeleteAll(0, "Fib_");

   if(!g_fibValid) return;

   datetime startTime = (g_fibDirection == BIAS_BULLISH) ? g_fibSwingLowTime : g_fibSwingHighTime;
   datetime endTime = TimeCurrent() + PeriodSeconds(InpFibTimeframe) * 20;

   // Draw Fibonacci levels
   for(int i = 0; i < g_fibLevelCount; i++)
   {
      string lineName = "Fib_Level_" + IntegerToString(i);
      string labelName = "Fib_Label_" + IntegerToString(i);

      // Determine color
      color lineColor = InpFibColor;
      if(StringFind(g_fibLabels[i], "61.8") >= 0)
         lineColor = InpFib618Color;
      else if(StringFind(g_fibLabels[i], "127") >= 0 ||
              StringFind(g_fibLabels[i], "161") >= 0 ||
              StringFind(g_fibLabels[i], "200") >= 0 ||
              StringFind(g_fibLabels[i], "261") >= 0)
         lineColor = InpExtensionColor;

      // Draw horizontal line
      ObjectCreate(0, lineName, OBJ_TREND, 0, startTime, g_fibLevels[i], endTime, g_fibLevels[i]);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, InpFibLineWidth);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);

      // Highlight 61.8% line
      if(StringFind(g_fibLabels[i], "61.8") >= 0)
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, InpFibLineWidth + 1);

      // Add label
      ObjectCreate(0, labelName, OBJ_TEXT, 0, endTime, g_fibLevels[i]);
      ObjectSetString(0, labelName, OBJPROP_TEXT,
                      g_fibLabels[i] + " (" + DoubleToString(g_fibLevels[i], g_digits) + ")");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }

   // Draw connecting line between swing points
   string swingLine = "Fib_SwingLine";
   ObjectCreate(0, swingLine, OBJ_TREND, 0,
                g_fibSwingLowTime, g_fibSwingLow,
                g_fibSwingHighTime, g_fibSwingHigh);
   ObjectSetInteger(0, swingLine, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, swingLine, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, swingLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, swingLine, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, swingLine, OBJPROP_SELECTABLE, false);

   // Draw Fibonacci Fan if enabled
   if(InpShowFibFan)
      DrawFibFan();

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw Fibonacci Fan                                                |
//+------------------------------------------------------------------+
void DrawFibFan()
{
   double range = g_fibSwingHigh - g_fibSwingLow;
   datetime startTime, endTime;
   double startPrice;

   if(g_fibDirection == BIAS_BULLISH)
   {
      startTime = g_fibSwingLowTime;
      startPrice = g_fibSwingLow;
      endTime = g_fibSwingHighTime;
   }
   else
   {
      startTime = g_fibSwingHighTime;
      startPrice = g_fibSwingHigh;
      endTime = g_fibSwingLowTime;
   }

   // Calculate time difference
   int barsDiff = MathAbs(g_fibSwingHighBar - g_fibSwingLowBar);
   datetime futureTime = TimeCurrent() + PeriodSeconds(InpFibTimeframe) * barsDiff * 2;

   // Fan levels: 38.2%, 50%, 61.8%
   double fanLevels[] = {0.382, 0.500, 0.618};
   string fanLabels[] = {"38.2%", "50%", "61.8%"};

   for(int i = 0; i < 3; i++)
   {
      string fanName = "Fib_Fan_" + IntegerToString(i);

      double endPrice;
      if(g_fibDirection == BIAS_BULLISH)
         endPrice = g_fibSwingLow + range * fanLevels[i];
      else
         endPrice = g_fibSwingHigh - range * fanLevels[i];

      // Project the fan line forward
      double slope = (endPrice - startPrice) / barsDiff;
      double futurePrice = startPrice + slope * barsDiff * 3;

      ObjectCreate(0, fanName, OBJ_TREND, 0, startTime, startPrice, futureTime, futurePrice);
      ObjectSetInteger(0, fanName, OBJPROP_COLOR, InpFanColor);
      ObjectSetInteger(0, fanName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, fanName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, fanName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, fanName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Get price position relative to Fibonacci levels                   |
//+------------------------------------------------------------------+
string GetPriceFibPosition(double price)
{
   if(!g_fibValid || g_fibLevelCount < 2)
      return "N/A";

   // Find the nearest level ABOVE and BELOW current price
   double nearestAbove = DBL_MAX;
   double nearestBelow = -DBL_MAX;
   string labelAbove = "";
   string labelBelow = "";

   for(int i = 0; i < g_fibLevelCount; i++)
   {
      if(g_fibLevels[i] >= price && g_fibLevels[i] < nearestAbove)
      {
         nearestAbove = g_fibLevels[i];
         labelAbove = g_fibLabels[i];
      }
      if(g_fibLevels[i] <= price && g_fibLevels[i] > nearestBelow)
      {
         nearestBelow = g_fibLevels[i];
         labelBelow = g_fibLabels[i];
      }
   }

   // Check if price is exactly at a level
   if(MathAbs(nearestAbove - nearestBelow) < g_point * 10)
      return "At " + labelAbove;

   // Check if above all levels
   if(nearestAbove == DBL_MAX)
      return "Above " + labelBelow;

   // Check if below all levels
   if(nearestBelow == -DBL_MAX)
      return "Below " + labelAbove;

   // Price is between two levels
   return "Between " + labelBelow + " and " + labelAbove;
}

//+------------------------------------------------------------------+
//| Get nearest Fibonacci level                                       |
//+------------------------------------------------------------------+
double GetNearestFibLevel(double price, string &levelLabel)
{
   if(!g_fibValid || g_fibLevelCount == 0)
   {
      levelLabel = "N/A";
      return 0;
   }

   double nearestLevel = g_fibLevels[0];
   double minDistance = MathAbs(price - g_fibLevels[0]);
   levelLabel = g_fibLabels[0];

   for(int i = 1; i < g_fibLevelCount; i++)
   {
      double dist = MathAbs(price - g_fibLevels[i]);
      if(dist < minDistance)
      {
         minDistance = dist;
         nearestLevel = g_fibLevels[i];
         levelLabel = g_fibLabels[i];
      }
   }

   return nearestLevel;
}

//+------------------------------------------------------------------+
//| Print Fibonacci Report                                            |
//+------------------------------------------------------------------+
void PrintFibReport()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   Print("");
   Print("=================================================");
   Print("       FIBONACCI REPORT (Section 5)              ");
   Print("=================================================");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", TimeframeToString(InpFibTimeframe));
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Current Price: ", DoubleToString(currentPrice, g_digits));
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

   // Fibonacci Data
   Print("FIBONACCI SWING POINTS:");
   if(g_fibValid)
   {
      Print("  Swing High: ", DoubleToString(g_fibSwingHigh, g_digits),
            " at ", TimeToString(g_fibSwingHighTime, TIME_DATE|TIME_MINUTES));
      Print("  Swing Low: ", DoubleToString(g_fibSwingLow, g_digits),
            " at ", TimeToString(g_fibSwingLowTime, TIME_DATE|TIME_MINUTES));
      Print("  Range: ", DoubleToString(g_fibSwingHigh - g_fibSwingLow, g_digits));
      Print("  Direction: ", TrendBiasToString(g_fibDirection));
   }
   else
   {
      Print("  Status: No valid swing points found");
   }
   Print("-------------------------------------------------");

   // Fibonacci Levels
   Print("FIBONACCI LEVELS:");
   if(g_fibValid)
   {
      for(int i = 0; i < g_fibLevelCount; i++)
      {
         string marker = "";
         double dist = currentPrice - g_fibLevels[i];

         if(MathAbs(dist) < (g_fibSwingHigh - g_fibSwingLow) * 0.02)
            marker = " <-- PRICE HERE";

         Print("  ", g_fibLabels[i], ": ", DoubleToString(g_fibLevels[i], g_digits), marker);
      }
   }
   Print("-------------------------------------------------");

   // Price Position
   Print("PRICE POSITION:");
   Print("  Location: ", GetPriceFibPosition(currentPrice));

   string nearestLabel;
   double nearestLevel = GetNearestFibLevel(currentPrice, nearestLabel);
   if(nearestLevel > 0)
   {
      double distToNearest = currentPrice - nearestLevel;
      Print("  Nearest Level: ", nearestLabel, " (", DoubleToString(nearestLevel, g_digits), ")");
      Print("  Distance: ", DoubleToString(distToNearest, g_digits));
   }
   Print("-------------------------------------------------");

   // Trading Recommendation
   Print("TRADING RECOMMENDATION:");
   PrintTradingRecommendation(currentPrice);
   Print("=================================================");
   Print("");
}

//+------------------------------------------------------------------+
//| Print Trading Recommendation                                      |
//+------------------------------------------------------------------+
void PrintTradingRecommendation(double currentPrice)
{
   if(!g_fibValid)
   {
      Print("  STATUS: NO FIB DATA");
      Print("  REASON: Could not find valid swing points");
      return;
   }

   // Check ATR filter
   if(InpUseATRFilter && !g_atrResult.tradingAllowed)
   {
      Print("  STATUS: NO TRADE");
      Print("  REASON: Market too quiet (ATR filter)");
      return;
   }

   double range = g_fibSwingHigh - g_fibSwingLow;
   double fib236 = (g_fibDirection == BIAS_BULLISH) ?
                   g_fibSwingHigh - range * 0.236 : g_fibSwingLow + range * 0.236;
   double fib382 = (g_fibDirection == BIAS_BULLISH) ?
                   g_fibSwingHigh - range * 0.382 : g_fibSwingLow + range * 0.382;
   double fib618 = (g_fibDirection == BIAS_BULLISH) ?
                   g_fibSwingHigh - range * 0.618 : g_fibSwingLow + range * 0.618;
   double fib786 = (g_fibDirection == BIAS_BULLISH) ?
                   g_fibSwingHigh - range * 0.786 : g_fibSwingLow + range * 0.786;

   if(g_fibDirection == BIAS_BULLISH)
   {
      // Bullish: Look for buy entries at retracement levels
      if(currentPrice > g_fibSwingHigh)
      {
         Print("  STATUS: BREAKOUT");
         Print("  REASON: Price above swing high");
         Print("  ACTION: Look for extension targets (127.2%, 161.8%)");
      }
      else if(currentPrice >= fib236 && currentPrice <= g_fibSwingHigh)
      {
         Print("  STATUS: VERY SHALLOW PULLBACK");
         Print("  REASON: Price at 0-23.6% retracement");
         Print("  ACTION: Strong trend, wait for deeper pullback or breakout");
      }
      else if(currentPrice >= fib382 && currentPrice < fib236)
      {
         Print("  STATUS: SHALLOW PULLBACK");
         Print("  REASON: Price at 23.6-38.2% retracement");
         Print("  ACTION: Approaching buy zone, prepare for entry");
      }
      else if(currentPrice >= fib618 && currentPrice < fib382)
      {
         Print("  STATUS: POTENTIAL BUY ZONE");
         Print("  REASON: Price at 38.2-61.8% retracement (Golden Zone)");
         Print("  ACTION: Look for bullish confirmation to enter long");
      }
      else if(currentPrice >= fib786 && currentPrice < fib618)
      {
         Print("  STATUS: DEEP PULLBACK");
         Print("  REASON: Price at 61.8-78.6% retracement");
         Print("  ACTION: High risk entry, need strong confirmation");
      }
      else if(currentPrice < fib786)
      {
         Print("  STATUS: CAUTION");
         Print("  REASON: Price below 78.6% - trend may be reversing");
         Print("  ACTION: Wait for structure confirmation");
      }
   }
   else // BEARISH
   {
      // Bearish: Look for sell entries at retracement levels
      if(currentPrice < g_fibSwingLow)
      {
         Print("  STATUS: BREAKOUT");
         Print("  REASON: Price below swing low");
         Print("  ACTION: Look for extension targets (127.2%, 161.8%)");
      }
      else if(currentPrice <= fib236 && currentPrice >= g_fibSwingLow)
      {
         Print("  STATUS: VERY SHALLOW PULLBACK");
         Print("  REASON: Price at 0-23.6% retracement");
         Print("  ACTION: Strong trend, wait for deeper pullback or breakout");
      }
      else if(currentPrice <= fib382 && currentPrice > fib236)
      {
         Print("  STATUS: SHALLOW PULLBACK");
         Print("  REASON: Price at 23.6-38.2% retracement");
         Print("  ACTION: Approaching sell zone, prepare for entry");
      }
      else if(currentPrice <= fib618 && currentPrice > fib382)
      {
         Print("  STATUS: POTENTIAL SELL ZONE");
         Print("  REASON: Price at 38.2-61.8% retracement (Golden Zone)");
         Print("  ACTION: Look for bearish confirmation to enter short");
      }
      else if(currentPrice <= fib786 && currentPrice > fib618)
      {
         Print("  STATUS: DEEP PULLBACK");
         Print("  REASON: Price at 61.8-78.6% retracement");
         Print("  ACTION: High risk entry, need strong confirmation");
      }
      else if(currentPrice > fib786)
      {
         Print("  STATUS: CAUTION");
         Print("  REASON: Price above 78.6% - trend may be reversing");
         Print("  ACTION: Wait for structure confirmation");
      }
   }
}

//+------------------------------------------------------------------+
//| Print Initialization Report                                       |
//+------------------------------------------------------------------+
void PrintInitReport()
{
   Print("");
   Print("=================================================");
   Print("     SWING TRADER PRO - SECTION 5                ");
   Print("     FIBONACCI RETRACEMENT & FAN                 ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol);
   Print("TIMEFRAME: ", TimeframeToString(InpFibTimeframe));
   Print("-------------------------------------------------");
   Print("FIBONACCI SETTINGS:");
   Print("  Lookback: ", InpFibLookback, " candles");
   Print("  Swing Strength: ", InpSwingStrength, " bars");
   Print("  Show Retracement: ", InpShowRetracement ? "YES" : "NO");
   Print("  Show Extension: ", InpShowExtension ? "YES" : "NO");
   Print("  Show Fan: ", InpShowFibFan ? "YES" : "NO");
   Print("-------------------------------------------------");
   Print("KEY LEVELS:");
   Print("  Retracement: 23.6%, 38.2%, 50%, 61.8%, 78.6%");
   Print("  Extension: 127.2%, 161.8%, 200%, 261.8%");
   Print("  Golden Zone: 38.2% - 61.8% (Best entries)");
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
               "FIBONACCI ANALYSIS", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "------------------------------------", clrGray, 8, "Courier New");

   int yOff = 40;

   // ATR Status
   if(InpUseATRFilter)
   {
      CreateLabel(g_panelName + "_atr_label", x + 10, y + yOff, "ATR:", clrWhite, 9, "Arial");
      CreateLabel(g_panelName + "_atr_value", x + 120, y + yOff, "-- pips", clrYellow, 9, "Arial");
      yOff += 20;
   }

   // EMA/Direction
   CreateLabel(g_panelName + "_dir_label", x + 10, y + yOff, "Fib Direction:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_dir_value", x + 120, y + yOff, "--", clrYellow, 9, "Arial Bold");
   yOff += 20;

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Swing Points
   CreateLabel(g_panelName + "_high_label", x + 10, y + yOff, "Swing High:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_high_value", x + 120, y + yOff, "--", clrRed, 9, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_low_label", x + 10, y + yOff, "Swing Low:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_low_value", x + 120, y + yOff, "--", clrLimeGreen, 9, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_range_label", x + 10, y + yOff, "Range:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_range_value", x + 120, y + yOff, "--", clrCyan, 9, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_sep3", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Current Price
   CreateLabel(g_panelName + "_price_label", x + 10, y + yOff, "Price:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_price_value", x + 120, y + yOff, "--", clrWhite, 9, "Arial Bold");
   yOff += 20;

   // Price Position
   CreateLabel(g_panelName + "_pos_label", x + 10, y + yOff, "Position:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_pos_value", x + 120, y + yOff, "--", clrYellow, 9, "Arial");
   yOff += 20;

   // Nearest Level
   CreateLabel(g_panelName + "_near_label", x + 10, y + yOff, "Nearest:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_near_value", x + 120, y + yOff, "--", InpFibColor, 9, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_sep4", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Recommendation
   CreateLabel(g_panelName + "_rec_label", x + 10, y + yOff, "Zone:", clrWhite, 10, "Arial Bold");
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
   }

   // Update direction
   string dirText = TrendBiasToString(g_fibDirection);
   color dirColor = (g_fibDirection == BIAS_BULLISH) ? clrLimeGreen :
                    (g_fibDirection == BIAS_BEARISH) ? clrRed : clrGray;
   ObjectSetString(0, g_panelName + "_dir_value", OBJPROP_TEXT, dirText);
   ObjectSetInteger(0, g_panelName + "_dir_value", OBJPROP_COLOR, dirColor);

   // Update swing points
   if(g_fibValid)
   {
      ObjectSetString(0, g_panelName + "_high_value", OBJPROP_TEXT,
                      DoubleToString(g_fibSwingHigh, g_digits));
      ObjectSetString(0, g_panelName + "_low_value", OBJPROP_TEXT,
                      DoubleToString(g_fibSwingLow, g_digits));
      ObjectSetString(0, g_panelName + "_range_value", OBJPROP_TEXT,
                      DoubleToString(g_fibSwingHigh - g_fibSwingLow, g_digits));
   }

   // Update price
   ObjectSetString(0, g_panelName + "_price_value", OBJPROP_TEXT,
                   DoubleToString(currentPrice, g_digits));

   // Update position
   string posText = GetPriceFibPosition(currentPrice);
   // Truncate if too long
   if(StringLen(posText) > 20)
      posText = StringSubstr(posText, 0, 20) + "...";
   ObjectSetString(0, g_panelName + "_pos_value", OBJPROP_TEXT, posText);

   // Update nearest level
   string nearLabel;
   double nearLevel = GetNearestFibLevel(currentPrice, nearLabel);
   ObjectSetString(0, g_panelName + "_near_value", OBJPROP_TEXT,
                   nearLabel + " (" + DoubleToString(nearLevel, 0) + ")");

   // Update recommendation
   string recText = "";
   color recColor = clrGray;

   if(!g_fibValid)
   {
      recText = "NO DATA";
      recColor = clrGray;
   }
   else if(InpUseATRFilter && !g_atrResult.tradingAllowed)
   {
      recText = "NO TRADE (ATR)";
      recColor = clrGray;
   }
   else
   {
      double range = g_fibSwingHigh - g_fibSwingLow;
      double fib382 = (g_fibDirection == BIAS_BULLISH) ?
                      g_fibSwingHigh - range * 0.382 : g_fibSwingLow + range * 0.382;
      double fib618 = (g_fibDirection == BIAS_BULLISH) ?
                      g_fibSwingHigh - range * 0.618 : g_fibSwingLow + range * 0.618;

      bool inGoldenZone = false;
      if(g_fibDirection == BIAS_BULLISH)
         inGoldenZone = (currentPrice >= fib618 && currentPrice <= fib382);
      else
         inGoldenZone = (currentPrice <= fib618 && currentPrice >= fib382);

      if(inGoldenZone)
      {
         recText = "GOLDEN ZONE";
         recColor = InpFib618Color;
      }
      else if((g_fibDirection == BIAS_BULLISH && currentPrice > g_fibSwingHigh) ||
              (g_fibDirection == BIAS_BEARISH && currentPrice < g_fibSwingLow))
      {
         recText = "BREAKOUT";
         recColor = InpExtensionColor;
      }
      else
      {
         recText = "WAIT";
         recColor = clrYellow;
      }
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
bool IsFibValid() { return g_fibValid; }
double GetFibSwingHigh() { return g_fibSwingHigh; }
double GetFibSwingLow() { return g_fibSwingLow; }
ENUM_TREND_BIAS GetFibDirection() { return g_fibDirection; }
double GetFibLevel(int index) { return (index < g_fibLevelCount) ? g_fibLevels[index] : 0; }
int GetFibLevelCount() { return g_fibLevelCount; }
//+------------------------------------------------------------------+
