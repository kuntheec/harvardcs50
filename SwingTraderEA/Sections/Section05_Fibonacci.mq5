//+------------------------------------------------------------------+
//|                                        Section05_Fibonacci.mq5   |
//|                                      SwingTrader Pro EA          |
//|                  Section 5: Fibonacci Retracement & OTE Zone     |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "2.00"
#property description "Section 5: Fibonacci Retracement with OTE Zone"
#property description "Auto-draws Fibonacci levels from swing points"
#property description "ICT/SMC: OTE Zone (61.8-78.6%) highlighted"
#property description "Level mitigation tracking for fresh vs touched levels"

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
input double   InpMinSwingATRMult     = 1.5;      // Min Swing Size (ATR multiplier)
input bool     InpShowRetracement     = true;     // Show Retracement Levels
input bool     InpShowExtension       = true;     // Show Extension Levels
input bool     InpShowOTEZone         = true;     // Show OTE Zone (61.8-78.6%)
input ENUM_TIMEFRAMES InpFibTimeframe = PERIOD_H4; // Fibonacci Timeframe

input group "=== Retracement Levels ==="
input bool     InpShow236             = true;     // Show 23.6% Level
input bool     InpShow382             = true;     // Show 38.2% Level
input bool     InpShow500             = true;     // Show 50.0% Level
input bool     InpShow618             = true;     // Show 61.8% Level (Golden Ratio)
input bool     InpShow786             = true;     // Show 78.6% Level
input bool     InpShow886             = true;     // Show 88.6% Level (Deep Retrace)

input group "=== Extension Levels ==="
input bool     InpShow1130            = false;    // Show 113.0% Level
input bool     InpShow1272            = true;     // Show 127.2% Level
input bool     InpShow1618            = true;     // Show 161.8% Level
input bool     InpShow2000            = false;    // Show 200.0% Level
input bool     InpShow2618            = false;    // Show 261.8% Level

input group "=== Level Mitigation ==="
input bool     InpUseMitigation       = true;     // Track Level Mitigation
input bool     InpRemoveMitigated     = false;    // Remove Mitigated Levels (vs gray out)
input double   InpMitigationBuffer    = 0.5;      // Mitigation Buffer (ATR multiplier)

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
input color    InpOTEZoneColor        = clrDarkOrange; // OTE Zone Color
input color    InpExtensionColor      = clrLimeGreen; // Extension Levels Color
input color    InpMitigatedColor      = clrDimGray; // Mitigated Level Color
input int      InpFibLineWidth        = 1;        // Line Width
input int      InpOTEZoneOpacity      = 30;       // OTE Zone Opacity (0-100)
input int      InpPanelX              = 20;       // Panel X Position
input int      InpPanelY              = 30;       // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;     // Print Report to Experts Tab

//+------------------------------------------------------------------+
//| Fib Level Structure with Mitigation Tracking                     |
//+------------------------------------------------------------------+
struct FibLevelInfo
{
   double      ratio;              // Fib ratio (0.236, 0.382, etc.)
   double      price;              // Price at this level
   string      label;              // Display label
   bool        isRetracement;      // true = retrace, false = extension
   bool        isMitigated;        // Has price touched this level?
   datetime    mitigationTime;     // When was it mitigated?
   bool        isOTE;              // Is part of OTE zone (61.8-78.6)?
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
// Symbol info cache
SymbolInfoCache g_symbolInfo;

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

// Fibonacci levels with mitigation
FibLevelInfo   g_fibLevels[];
int            g_fibLevelCount = 0;

// OTE Zone prices
double         g_oteUpperPrice;
double         g_oteLowerPrice;
bool           g_priceInOTE = false;

// ATR value
double         g_currentATR = 0;
double         g_currentATRPips = 0;

// Results from previous sections
EMAAnalysisResult g_emaResult;
ATRFilterResult   g_atrResult;

// Panel
string         g_panelName = "FibPanel";

// Performance tracking
datetime       g_lastFibUpdate = 0;
bool           g_fibNeedsRedraw = true;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize symbol info cache (auto-detects Gold/Silver/JPY)
   InitSymbolInfo(g_symbolInfo, _Symbol);

   // Print symbol detection
   string typeStr = "FOREX";
   if(g_symbolInfo.isGold) typeStr = "GOLD/XAU";
   else if(g_symbolInfo.isSilver) typeStr = "SILVER/XAG";
   else if(g_symbolInfo.isJPY) typeStr = "JPY PAIR";

   Print("Symbol Detection: ", _Symbol, " | Type: ", typeStr,
         " | Digits: ", g_symbolInfo.digits,
         " | PipSize: ", DoubleToString(g_symbolInfo.pipSize, 5));

   // Initialize arrays
   ArrayResize(g_fibLevels, 15);  // Max 15 levels
   ArraySetAsSeries(g_highBuffer, true);
   ArraySetAsSeries(g_lowBuffer, true);
   ArraySetAsSeries(g_closeBuffer, true);
   ArraySetAsSeries(g_timeBuffer, true);

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

   // Create ATR handle (always needed for swing validation)
   g_atrHandle = iATR(_Symbol, InpFibTimeframe, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR handle");
      return(INIT_FAILED);
   }
   ArraySetAsSeries(g_atrBuffer, true);

   // Print initialization
   PrintInitReport();

   // Create panel
   if(InpShowPanel)
      CreatePanel();

   // Run initial analysis
   AnalyzeFibonacci();

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
   CleanupFibObjects();

   Print("=================================================");
   Print("Fibonacci EA v2.00 Deinitialized");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpFibTimeframe, 0);

   // Check for new bar
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      g_fibNeedsRedraw = true;
      AnalyzeFibonacci();

      if(InpShowPanel) UpdatePanel();
   }
   else if(InpUseMitigation)
   {
      // Check mitigation on every tick
      CheckLevelMitigation();
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

   // Get ATR (always needed for swing validation)
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

      // Check initial mitigation status
      if(InpUseMitigation)
         CheckLevelMitigation();

      // Draw Fibonacci levels
      if(g_fibNeedsRedraw)
      {
         DrawFibonacci();
         g_fibNeedsRedraw = false;
      }
   }

   // Print report
   if(InpPrintReport)
      PrintFibReport();
}

//+------------------------------------------------------------------+
//| Analyze ATR with proper symbol detection                         |
//+------------------------------------------------------------------+
void AnalyzeATR()
{
   if(CopyBuffer(g_atrHandle, 0, 0, 1, g_atrBuffer) < 1) return;

   double atrPoints = g_atrBuffer[0];
   g_currentATR = atrPoints;

   // Convert to pips using SymbolInfoCache
   g_currentATRPips = PointsToPips(g_symbolInfo, atrPoints);

   g_atrResult.atrValue = g_currentATRPips;
   g_atrResult.atrPoints = atrPoints;
   g_atrResult.timestamp = TimeCurrent();

   if(g_currentATRPips < InpATRQuietThreshold)
   {
      g_atrResult.condition = MARKET_QUIET;
      g_atrResult.tradingAllowed = false;
      g_atrResult.reason = "Market too quiet - skip trading";
   }
   else if(g_currentATRPips > InpATRExtremeThreshold)
   {
      g_atrResult.condition = MARKET_EXTREME;
      g_atrResult.tradingAllowed = true;
      g_atrResult.reason = "Extreme volatility - reduce position size";
   }
   else
   {
      g_atrResult.condition = MARKET_NORMAL;
      g_atrResult.tradingAllowed = true;
      g_atrResult.reason = "Normal conditions - proceed";
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

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_emaResult.priceAboveEMA50 = currentPrice > g_emaResult.ema50;
   g_emaResult.priceAboveEMA200 = currentPrice > g_emaResult.ema200;

   if(g_emaFastBuffer[0] > g_emaSlowBuffer[0])
      g_emaResult.trend = BIAS_BULLISH;
   else if(g_emaFastBuffer[0] < g_emaSlowBuffer[0])
      g_emaResult.trend = BIAS_BEARISH;
   else
      g_emaResult.trend = BIAS_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Find Swing Points for Fibonacci with ATR validation              |
//+------------------------------------------------------------------+
void FindFibonacciSwings()
{
   g_fibValid = false;

   // Find the most significant swing high and swing low
   double highestHigh = 0;
   double lowestLow = DBL_MAX;
   int highestBar = -1;
   int lowestBar = -1;

   // Minimum swing size based on ATR
   double minSwingSize = g_currentATR * InpMinSwingATRMult;

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
      if(InpPrintReport)
         Print("Fibonacci: Could not find valid swing points");
      return;
   }

   // Validate minimum swing size
   double swingRange = highestHigh - lowestLow;
   if(swingRange < minSwingSize)
   {
      if(InpPrintReport)
         Print("Fibonacci: Swing too small (", DoubleToString(swingRange, g_symbolInfo.digits),
               " < ", DoubleToString(minSwingSize, g_symbolInfo.digits), " ATR req)");
      return;
   }

   // Store swing points
   g_fibSwingHigh = highestHigh;
   g_fibSwingLow = lowestLow;
   g_fibSwingHighBar = highestBar;
   g_fibSwingLowBar = lowestBar;
   g_fibSwingHighTime = g_timeBuffer[highestBar];
   g_fibSwingLowTime = g_timeBuffer[lowestBar];

   // Determine Fibonacci direction based on EMA or swing timing
   if(InpUseEMAFilter)
   {
      g_fibDirection = g_emaResult.trend;
   }
   else
   {
      // More recent swing determines direction
      if(highestBar < lowestBar)
         g_fibDirection = BIAS_BEARISH;  // High is more recent - bearish retracement
      else
         g_fibDirection = BIAS_BULLISH;  // Low is more recent - bullish retracement
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
//| Calculate Fibonacci Levels with OTE Zone                         |
//+------------------------------------------------------------------+
void CalculateFibLevels()
{
   g_fibLevelCount = 0;
   double range = g_fibSwingHigh - g_fibSwingLow;

   // Reset OTE zone
   g_oteUpperPrice = 0;
   g_oteLowerPrice = 0;

   if(g_fibDirection == BIAS_BULLISH)
   {
      // Bullish: Draw from low to high
      // Retracement levels are below current price

      // 0% (swing low)
      AddFibLevel(0.0, g_fibSwingLow, "0.0%", true, false);

      // Retracement levels
      if(InpShowRetracement)
      {
         if(InpShow236) AddFibLevel(0.236, g_fibSwingHigh - range * 0.236, "23.6%", true, false);
         if(InpShow382) AddFibLevel(0.382, g_fibSwingHigh - range * 0.382, "38.2%", true, false);
         if(InpShow500) AddFibLevel(0.500, g_fibSwingHigh - range * 0.500, "50.0%", true, false);
         if(InpShow618) AddFibLevel(0.618, g_fibSwingHigh - range * 0.618, "61.8%", true, true);  // OTE
         if(InpShow786) AddFibLevel(0.786, g_fibSwingHigh - range * 0.786, "78.6%", true, true);  // OTE
         if(InpShow886) AddFibLevel(0.886, g_fibSwingHigh - range * 0.886, "88.6%", true, false);
      }

      // 100% (swing high)
      AddFibLevel(1.0, g_fibSwingHigh, "100%", true, false);

      // Extension levels
      if(InpShowExtension)
      {
         if(InpShow1130) AddFibLevel(1.130, g_fibSwingLow + range * 1.130, "113%", false, false);
         if(InpShow1272) AddFibLevel(1.272, g_fibSwingLow + range * 1.272, "127.2%", false, false);
         if(InpShow1618) AddFibLevel(1.618, g_fibSwingLow + range * 1.618, "161.8%", false, false);
         if(InpShow2000) AddFibLevel(2.000, g_fibSwingLow + range * 2.000, "200%", false, false);
         if(InpShow2618) AddFibLevel(2.618, g_fibSwingLow + range * 2.618, "261.8%", false, false);
      }

      // Calculate OTE zone (61.8% - 78.6%)
      g_oteUpperPrice = g_fibSwingHigh - range * 0.618;
      g_oteLowerPrice = g_fibSwingHigh - range * 0.786;
   }
   else // BEARISH
   {
      // Bearish: Draw from high to low
      // Retracement levels are above current price

      // 0% (swing high)
      AddFibLevel(0.0, g_fibSwingHigh, "0.0%", true, false);

      // Retracement levels
      if(InpShowRetracement)
      {
         if(InpShow236) AddFibLevel(0.236, g_fibSwingLow + range * 0.236, "23.6%", true, false);
         if(InpShow382) AddFibLevel(0.382, g_fibSwingLow + range * 0.382, "38.2%", true, false);
         if(InpShow500) AddFibLevel(0.500, g_fibSwingLow + range * 0.500, "50.0%", true, false);
         if(InpShow618) AddFibLevel(0.618, g_fibSwingLow + range * 0.618, "61.8%", true, true);  // OTE
         if(InpShow786) AddFibLevel(0.786, g_fibSwingLow + range * 0.786, "78.6%", true, true);  // OTE
         if(InpShow886) AddFibLevel(0.886, g_fibSwingLow + range * 0.886, "88.6%", true, false);
      }

      // 100% (swing low)
      AddFibLevel(1.0, g_fibSwingLow, "100%", true, false);

      // Extension levels
      if(InpShowExtension)
      {
         if(InpShow1130) AddFibLevel(1.130, g_fibSwingHigh - range * 1.130, "113%", false, false);
         if(InpShow1272) AddFibLevel(1.272, g_fibSwingHigh - range * 1.272, "127.2%", false, false);
         if(InpShow1618) AddFibLevel(1.618, g_fibSwingHigh - range * 1.618, "161.8%", false, false);
         if(InpShow2000) AddFibLevel(2.000, g_fibSwingHigh - range * 2.000, "200%", false, false);
         if(InpShow2618) AddFibLevel(2.618, g_fibSwingHigh - range * 2.618, "261.8%", false, false);
      }

      // Calculate OTE zone (61.8% - 78.6%)
      g_oteLowerPrice = g_fibSwingLow + range * 0.618;
      g_oteUpperPrice = g_fibSwingLow + range * 0.786;
   }
}

//+------------------------------------------------------------------+
//| Add Fibonacci Level                                               |
//+------------------------------------------------------------------+
void AddFibLevel(double ratio, double price, string label, bool isRetrace, bool isOTE)
{
   if(g_fibLevelCount < 15)
   {
      g_fibLevels[g_fibLevelCount].ratio = ratio;
      g_fibLevels[g_fibLevelCount].price = price;
      g_fibLevels[g_fibLevelCount].label = label;
      g_fibLevels[g_fibLevelCount].isRetracement = isRetrace;
      g_fibLevels[g_fibLevelCount].isMitigated = false;
      g_fibLevels[g_fibLevelCount].mitigationTime = 0;
      g_fibLevels[g_fibLevelCount].isOTE = isOTE;
      g_fibLevelCount++;
   }
}

//+------------------------------------------------------------------+
//| Check Level Mitigation                                            |
//+------------------------------------------------------------------+
void CheckLevelMitigation()
{
   if(!InpUseMitigation || !g_fibValid)
      return;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double buffer = g_currentATR * InpMitigationBuffer;
   bool needsRedraw = false;

   for(int i = 0; i < g_fibLevelCount; i++)
   {
      if(g_fibLevels[i].isMitigated)
         continue;

      // Check if price has touched/crossed this level
      double levelPrice = g_fibLevels[i].price;

      if(MathAbs(currentPrice - levelPrice) <= buffer)
      {
         g_fibLevels[i].isMitigated = true;
         g_fibLevels[i].mitigationTime = TimeCurrent();
         needsRedraw = true;

         if(InpPrintReport)
            Print("Level Mitigated: ", g_fibLevels[i].label, " at ",
                  DoubleToString(levelPrice, g_symbolInfo.digits));
      }
   }

   // Check if price is in OTE zone
   if(g_oteUpperPrice > 0 && g_oteLowerPrice > 0)
   {
      bool wasInOTE = g_priceInOTE;
      g_priceInOTE = (currentPrice >= g_oteLowerPrice && currentPrice <= g_oteUpperPrice);

      if(g_priceInOTE && !wasInOTE && InpPrintReport)
         Print(">>> PRICE ENTERED OTE ZONE (61.8-78.6%) <<<");
   }

   if(needsRedraw)
   {
      g_fibNeedsRedraw = true;
      DrawFibonacci();
   }
}

//+------------------------------------------------------------------+
//| Draw Fibonacci on Chart                                           |
//+------------------------------------------------------------------+
void DrawFibonacci()
{
   // Remove old Fib objects
   CleanupFibObjects();

   if(!g_fibValid) return;

   datetime startTime = (g_fibDirection == BIAS_BULLISH) ? g_fibSwingLowTime : g_fibSwingHighTime;
   datetime endTime = TimeCurrent() + PeriodSeconds(InpFibTimeframe) * 20;

   // Draw OTE Zone Rectangle first (so it's behind lines)
   if(InpShowOTEZone && g_oteUpperPrice > 0 && g_oteLowerPrice > 0)
   {
      DrawOTEZone(startTime, endTime);
   }

   // Draw Fibonacci levels
   for(int i = 0; i < g_fibLevelCount; i++)
   {
      // Skip mitigated levels if removal is enabled
      if(InpRemoveMitigated && g_fibLevels[i].isMitigated)
         continue;

      string lineName = "Fib_Level_" + IntegerToString(i);
      string labelName = "Fib_Label_" + IntegerToString(i);

      // Determine color based on level type and mitigation status
      color lineColor = GetLevelColor(i);
      int lineWidth = InpFibLineWidth;
      ENUM_LINE_STYLE lineStyle = STYLE_SOLID;

      // Highlight OTE levels
      if(g_fibLevels[i].isOTE && !g_fibLevels[i].isMitigated)
      {
         lineWidth = InpFibLineWidth + 1;
      }

      // Mitigated levels are dashed
      if(g_fibLevels[i].isMitigated)
      {
         lineStyle = STYLE_DOT;
         lineColor = InpMitigatedColor;
      }

      // Draw horizontal line
      ObjectCreate(0, lineName, OBJ_TREND, 0, startTime, g_fibLevels[i].price, endTime, g_fibLevels[i].price);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, lineWidth);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, lineStyle);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);

      // Add label
      string labelText = g_fibLevels[i].label + " (" + DoubleToString(g_fibLevels[i].price, g_symbolInfo.digits) + ")";
      if(g_fibLevels[i].isMitigated)
         labelText += " [M]";
      if(g_fibLevels[i].isOTE && !g_fibLevels[i].isMitigated)
         labelText += " [OTE]";

      ObjectCreate(0, labelName, OBJ_TEXT, 0, endTime, g_fibLevels[i].price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
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

   // Draw swing point markers
   DrawSwingMarkers();

   ChartRedraw();
   g_lastFibUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Draw OTE Zone Rectangle                                           |
//+------------------------------------------------------------------+
void DrawOTEZone(datetime startTime, datetime endTime)
{
   string zoneName = "Fib_OTE_Zone";

   ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, startTime, g_oteUpperPrice, endTime, g_oteLowerPrice);
   ObjectSetInteger(0, zoneName, OBJPROP_COLOR, InpOTEZoneColor);
   ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
   ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
   ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);

   // Add OTE label
   string oteLabel = "Fib_OTE_Label";
   double midPrice = (g_oteUpperPrice + g_oteLowerPrice) / 2;
   ObjectCreate(0, oteLabel, OBJ_TEXT, 0, startTime, midPrice);
   ObjectSetString(0, oteLabel, OBJPROP_TEXT, "OTE ZONE");
   ObjectSetInteger(0, oteLabel, OBJPROP_COLOR, InpOTEZoneColor);
   ObjectSetInteger(0, oteLabel, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, oteLabel, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, oteLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

//+------------------------------------------------------------------+
//| Draw Swing Point Markers                                          |
//+------------------------------------------------------------------+
void DrawSwingMarkers()
{
   // Swing High marker
   string highMarker = "Fib_SwingHigh";
   ObjectCreate(0, highMarker, OBJ_ARROW, 0, g_fibSwingHighTime, g_fibSwingHigh);
   ObjectSetInteger(0, highMarker, OBJPROP_ARROWCODE, 218);  // Down arrow
   ObjectSetInteger(0, highMarker, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, highMarker, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, highMarker, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
   ObjectSetInteger(0, highMarker, OBJPROP_SELECTABLE, false);

   // Swing Low marker
   string lowMarker = "Fib_SwingLow";
   ObjectCreate(0, lowMarker, OBJ_ARROW, 0, g_fibSwingLowTime, g_fibSwingLow);
   ObjectSetInteger(0, lowMarker, OBJPROP_ARROWCODE, 217);  // Up arrow
   ObjectSetInteger(0, lowMarker, OBJPROP_COLOR, clrLimeGreen);
   ObjectSetInteger(0, lowMarker, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, lowMarker, OBJPROP_ANCHOR, ANCHOR_TOP);
   ObjectSetInteger(0, lowMarker, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Get Level Color                                                   |
//+------------------------------------------------------------------+
color GetLevelColor(int index)
{
   if(g_fibLevels[index].isMitigated)
      return InpMitigatedColor;

   // 61.8% highlight
   if(StringFind(g_fibLevels[index].label, "61.8") >= 0)
      return InpFib618Color;

   // Extension levels
   if(!g_fibLevels[index].isRetracement)
      return InpExtensionColor;

   // OTE zone levels
   if(g_fibLevels[index].isOTE)
      return InpFib618Color;

   // Default
   return InpFibColor;
}

//+------------------------------------------------------------------+
//| Cleanup Fibonacci Objects                                         |
//+------------------------------------------------------------------+
void CleanupFibObjects()
{
   ObjectsDeleteAll(0, "Fib_");
}

//+------------------------------------------------------------------+
//| Get price position relative to Fibonacci levels                   |
//+------------------------------------------------------------------+
string GetPriceFibPosition(double price)
{
   if(!g_fibValid || g_fibLevelCount < 2)
      return "N/A";

   // Check if in OTE zone
   if(g_priceInOTE)
      return "IN OTE ZONE (61.8-78.6%)";

   // Find the nearest level ABOVE and BELOW current price
   double nearestAbove = DBL_MAX;
   double nearestBelow = -DBL_MAX;
   string labelAbove = "";
   string labelBelow = "";

   for(int i = 0; i < g_fibLevelCount; i++)
   {
      if(g_fibLevels[i].price >= price && g_fibLevels[i].price < nearestAbove)
      {
         nearestAbove = g_fibLevels[i].price;
         labelAbove = g_fibLevels[i].label;
      }
      if(g_fibLevels[i].price <= price && g_fibLevels[i].price > nearestBelow)
      {
         nearestBelow = g_fibLevels[i].price;
         labelBelow = g_fibLevels[i].label;
      }
   }

   if(MathAbs(nearestAbove - nearestBelow) < g_symbolInfo.point * 10)
      return "At " + labelAbove;

   if(nearestAbove == DBL_MAX)
      return "Above " + labelBelow;

   if(nearestBelow == -DBL_MAX)
      return "Below " + labelAbove;

   return "Between " + labelBelow + " and " + labelAbove;
}

//+------------------------------------------------------------------+
//| Get nearest Fibonacci level                                       |
//+------------------------------------------------------------------+
double GetNearestFibLevel(double price, string &levelLabel, bool &isMitigated)
{
   if(!g_fibValid || g_fibLevelCount == 0)
   {
      levelLabel = "N/A";
      isMitigated = false;
      return 0;
   }

   double nearestLevel = g_fibLevels[0].price;
   double minDistance = MathAbs(price - g_fibLevels[0].price);
   levelLabel = g_fibLevels[0].label;
   isMitigated = g_fibLevels[0].isMitigated;

   for(int i = 1; i < g_fibLevelCount; i++)
   {
      double dist = MathAbs(price - g_fibLevels[i].price);
      if(dist < minDistance)
      {
         minDistance = dist;
         nearestLevel = g_fibLevels[i].price;
         levelLabel = g_fibLevels[i].label;
         isMitigated = g_fibLevels[i].isMitigated;
      }
   }

   return nearestLevel;
}

//+------------------------------------------------------------------+
//| Count Fresh (non-mitigated) Levels                                |
//+------------------------------------------------------------------+
int CountFreshLevels()
{
   int count = 0;
   for(int i = 0; i < g_fibLevelCount; i++)
   {
      if(!g_fibLevels[i].isMitigated)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Print Fibonacci Report                                            |
//+------------------------------------------------------------------+
void PrintFibReport()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   Print("");
   Print("=================================================");
   Print("       FIBONACCI REPORT (Section 5 v2.0)         ");
   Print("=================================================");
   Print("Symbol: ", _Symbol, " (", (g_symbolInfo.isGold ? "GOLD" : g_symbolInfo.isSilver ? "SILVER" : "FOREX"), ")");
   Print("Timeframe: ", TimeframeToString(InpFibTimeframe));
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Current Price: ", DoubleToString(currentPrice, g_symbolInfo.digits));
   Print("-------------------------------------------------");

   // ATR Status
   Print("ATR FILTER:");
   Print("  ATR Value: ", DoubleToString(g_atrResult.atrValue, 2), " pips");
   Print("  ATR Raw: ", DoubleToString(g_currentATR, g_symbolInfo.digits), " points");
   Print("  Condition: ", MarketConditionToString(g_atrResult.condition));
   Print("-------------------------------------------------");

   // EMA Status
   if(InpUseEMAFilter)
   {
      Print("EMA TREND:");
      Print("  EMA 50: ", DoubleToString(g_emaResult.ema50, g_symbolInfo.digits));
      Print("  EMA 200: ", DoubleToString(g_emaResult.ema200, g_symbolInfo.digits));
      Print("  Trend: ", TrendBiasToString(g_emaResult.trend));
      Print("-------------------------------------------------");
   }

   // Fibonacci Data
   Print("FIBONACCI SWING POINTS:");
   if(g_fibValid)
   {
      Print("  Swing High: ", DoubleToString(g_fibSwingHigh, g_symbolInfo.digits),
            " at ", TimeToString(g_fibSwingHighTime, TIME_DATE|TIME_MINUTES));
      Print("  Swing Low: ", DoubleToString(g_fibSwingLow, g_symbolInfo.digits),
            " at ", TimeToString(g_fibSwingLowTime, TIME_DATE|TIME_MINUTES));
      Print("  Range: ", DoubleToString(g_fibSwingHigh - g_fibSwingLow, g_symbolInfo.digits));
      Print("  Direction: ", TrendBiasToString(g_fibDirection));
   }
   else
   {
      Print("  Status: No valid swing points found");
   }
   Print("-------------------------------------------------");

   // OTE Zone
   if(InpShowOTEZone && g_fibValid)
   {
      Print("OTE ZONE (Optimal Trade Entry):");
      Print("  Upper: ", DoubleToString(g_oteUpperPrice, g_symbolInfo.digits), " (61.8%)");
      Print("  Lower: ", DoubleToString(g_oteLowerPrice, g_symbolInfo.digits), " (78.6%)");
      Print("  Price in OTE: ", g_priceInOTE ? ">>> YES <<<" : "NO");
      Print("-------------------------------------------------");
   }

   // Fibonacci Levels with Mitigation Status
   Print("FIBONACCI LEVELS (Fresh: ", CountFreshLevels(), "/", g_fibLevelCount, "):");
   if(g_fibValid)
   {
      for(int i = 0; i < g_fibLevelCount; i++)
      {
         string marker = "";
         double dist = currentPrice - g_fibLevels[i].price;

         if(MathAbs(dist) < (g_fibSwingHigh - g_fibSwingLow) * 0.02)
            marker = " <-- PRICE HERE";

         string status = g_fibLevels[i].isMitigated ? " [MITIGATED]" : " [FRESH]";
         string ote = g_fibLevels[i].isOTE ? " *OTE*" : "";

         Print("  ", g_fibLevels[i].label, ": ",
               DoubleToString(g_fibLevels[i].price, g_symbolInfo.digits),
               status, ote, marker);
      }
   }
   Print("-------------------------------------------------");

   // Price Position
   Print("PRICE POSITION:");
   Print("  Location: ", GetPriceFibPosition(currentPrice));

   string nearestLabel;
   bool nearestMitigated;
   double nearestLevel = GetNearestFibLevel(currentPrice, nearestLabel, nearestMitigated);
   if(nearestLevel > 0)
   {
      double distToNearest = currentPrice - nearestLevel;
      Print("  Nearest Level: ", nearestLabel, " (", DoubleToString(nearestLevel, g_symbolInfo.digits), ")");
      Print("  Distance: ", DoubleToString(distToNearest, g_symbolInfo.digits));
      Print("  Level Status: ", nearestMitigated ? "MITIGATED" : "FRESH");
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

   // Check if in OTE zone
   if(g_priceInOTE)
   {
      if(g_fibDirection == BIAS_BULLISH)
      {
         Print("  STATUS: >>> OPTIMAL BUY ZONE <<<");
         Print("  REASON: Price in OTE zone (61.8-78.6%) in bullish trend");
         Print("  ACTION: Look for bullish confirmation (BOS/CHoCH on lower TF)");
         Print("  SL: Below 88.6% or swing low");
         Print("  TP1: Swing high (100%)");
         Print("  TP2: 127.2% extension");
      }
      else
      {
         Print("  STATUS: >>> OPTIMAL SELL ZONE <<<");
         Print("  REASON: Price in OTE zone (61.8-78.6%) in bearish trend");
         Print("  ACTION: Look for bearish confirmation (BOS/CHoCH on lower TF)");
         Print("  SL: Above 88.6% or swing high");
         Print("  TP1: Swing low (100%)");
         Print("  TP2: 127.2% extension");
      }

      // Caution for extreme ATR
      if(g_atrResult.condition == MARKET_EXTREME)
         Print("  CAUTION: High volatility - reduce position size");

      return;
   }

   // Standard recommendations based on price position
   double range = g_fibSwingHigh - g_fibSwingLow;
   double fib236 = (g_fibDirection == BIAS_BULLISH) ?
                   g_fibSwingHigh - range * 0.236 : g_fibSwingLow + range * 0.236;
   double fib382 = (g_fibDirection == BIAS_BULLISH) ?
                   g_fibSwingHigh - range * 0.382 : g_fibSwingLow + range * 0.382;

   if(g_fibDirection == BIAS_BULLISH)
   {
      if(currentPrice > g_fibSwingHigh)
      {
         Print("  STATUS: BREAKOUT");
         Print("  REASON: Price above swing high");
         Print("  ACTION: Look for extension targets (127.2%, 161.8%)");
      }
      else if(currentPrice >= fib236)
      {
         Print("  STATUS: SHALLOW PULLBACK");
         Print("  REASON: Price at 0-38.2% retracement");
         Print("  ACTION: Wait for deeper pullback to OTE zone (61.8-78.6%)");
      }
      else if(currentPrice >= fib382 && currentPrice < g_oteUpperPrice)
      {
         Print("  STATUS: APPROACHING OTE");
         Print("  REASON: Price at 38.2-61.8% retracement");
         Print("  ACTION: Prepare for entry as price approaches OTE zone");
      }
      else if(currentPrice < g_oteLowerPrice)
      {
         Print("  STATUS: DEEP PULLBACK");
         Print("  REASON: Price below 78.6% - risky entry");
         Print("  ACTION: Wait for structure confirmation or skip trade");
      }
   }
   else // BEARISH
   {
      if(currentPrice < g_fibSwingLow)
      {
         Print("  STATUS: BREAKOUT");
         Print("  REASON: Price below swing low");
         Print("  ACTION: Look for extension targets (127.2%, 161.8%)");
      }
      else if(currentPrice <= fib236)
      {
         Print("  STATUS: SHALLOW PULLBACK");
         Print("  REASON: Price at 0-38.2% retracement");
         Print("  ACTION: Wait for deeper pullback to OTE zone (61.8-78.6%)");
      }
      else if(currentPrice <= fib382 && currentPrice > g_oteLowerPrice)
      {
         Print("  STATUS: APPROACHING OTE");
         Print("  REASON: Price at 38.2-61.8% retracement");
         Print("  ACTION: Prepare for entry as price approaches OTE zone");
      }
      else if(currentPrice > g_oteUpperPrice)
      {
         Print("  STATUS: DEEP PULLBACK");
         Print("  REASON: Price above 78.6% - risky entry");
         Print("  ACTION: Wait for structure confirmation or skip trade");
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
   Print("     SWING TRADER PRO - SECTION 5 (v2.0)         ");
   Print("     FIBONACCI RETRACEMENT & OTE ZONE            ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL DETECTION:");
   Print("  Symbol: ", _Symbol);
   string typeStr = "Standard Forex";
   if(g_symbolInfo.isGold) typeStr = "GOLD/XAU";
   else if(g_symbolInfo.isSilver) typeStr = "SILVER/XAG";
   else if(g_symbolInfo.isJPY) typeStr = "JPY Pair";
   Print("  Type: ", typeStr);
   Print("  Digits: ", g_symbolInfo.digits);
   Print("  Pip Size: ", DoubleToString(g_symbolInfo.pipSize, 5));
   Print("-------------------------------------------------");
   Print("TIMEFRAME: ", TimeframeToString(InpFibTimeframe));
   Print("-------------------------------------------------");
   Print("FIBONACCI SETTINGS:");
   Print("  Lookback: ", InpFibLookback, " candles");
   Print("  Swing Strength: ", InpSwingStrength, " bars");
   Print("  Min Swing Size: ", DoubleToString(InpMinSwingATRMult, 1), "x ATR");
   Print("  Show Retracement: ", InpShowRetracement ? "YES" : "NO");
   Print("  Show Extension: ", InpShowExtension ? "YES" : "NO");
   Print("  Show OTE Zone: ", InpShowOTEZone ? "YES" : "NO");
   Print("-------------------------------------------------");
   Print("LEVEL MITIGATION:");
   Print("  Track Mitigation: ", InpUseMitigation ? "YES" : "NO");
   Print("  Remove Mitigated: ", InpRemoveMitigated ? "YES (delete)" : "NO (gray out)");
   Print("  Mitigation Buffer: ", DoubleToString(InpMitigationBuffer, 1), "x ATR");
   Print("-------------------------------------------------");
   Print("KEY LEVELS:");
   Print("  Retracement: 23.6%, 38.2%, 50%, 61.8%, 78.6%, 88.6%");
   Print("  Extension: 113%, 127.2%, 161.8%, 200%, 261.8%");
   Print("  OTE Zone: 61.8% - 78.6% (Optimal Trade Entry)");
   Print("-------------------------------------------------");
   Print("ICT/SMC CONCEPTS:");
   Print("  OTE = Optimal Trade Entry (61.8-78.6%)");
   Print("  Fresh levels = Not yet touched by price");
   Print("  Mitigated levels = Already touched (weaker)");
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

   CreateRectangle(g_panelName + "_bg", x, y, 320, 340, clrBlack, 200);

   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "FIBONACCI ANALYSIS v2.0", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "------------------------------------", clrGray, 8, "Courier New");

   int yOff = 40;

   // Symbol Type
   CreateLabel(g_panelName + "_sym_label", x + 10, y + yOff, "Symbol:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_sym_value", x + 120, y + yOff, _Symbol, clrCyan, 9, "Arial Bold");
   yOff += 20;

   // ATR Status
   CreateLabel(g_panelName + "_atr_label", x + 10, y + yOff, "ATR:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_atr_value", x + 120, y + yOff, "-- pips", clrYellow, 9, "Arial");
   yOff += 20;

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

   // OTE Zone
   CreateLabel(g_panelName + "_ote_label", x + 10, y + yOff, "OTE Zone:", clrWhite, 9, "Arial Bold");
   CreateLabel(g_panelName + "_ote_value", x + 120, y + yOff, "--", InpOTEZoneColor, 9, "Arial Bold");
   yOff += 20;

   CreateLabel(g_panelName + "_ote_range", x + 10, y + yOff, "  Range:", clrGray, 8, "Arial");
   CreateLabel(g_panelName + "_ote_range_val", x + 120, y + yOff, "--", clrGray, 8, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_sep4", x + 10, y + yOff,
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

   // Levels Status
   CreateLabel(g_panelName + "_lvl_label", x + 10, y + yOff, "Fresh Levels:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_lvl_value", x + 120, y + yOff, "--", clrLimeGreen, 9, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_sep5", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Recommendation
   CreateLabel(g_panelName + "_rec_label", x + 10, y + yOff, "Status:", clrWhite, 10, "Arial Bold");
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
   ObjectSetString(0, g_panelName + "_atr_value", OBJPROP_TEXT,
                   DoubleToString(g_atrResult.atrValue, 1) + " pips");
   color atrColor = clrYellow;
   if(g_atrResult.condition == MARKET_QUIET) atrColor = clrGray;
   else if(g_atrResult.condition == MARKET_EXTREME) atrColor = clrOrange;
   ObjectSetInteger(0, g_panelName + "_atr_value", OBJPROP_COLOR, atrColor);

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
                      DoubleToString(g_fibSwingHigh, g_symbolInfo.digits));
      ObjectSetString(0, g_panelName + "_low_value", OBJPROP_TEXT,
                      DoubleToString(g_fibSwingLow, g_symbolInfo.digits));
      ObjectSetString(0, g_panelName + "_range_value", OBJPROP_TEXT,
                      DoubleToString(g_fibSwingHigh - g_fibSwingLow, g_symbolInfo.digits));
   }

   // Update OTE Zone
   if(g_oteUpperPrice > 0 && g_oteLowerPrice > 0)
   {
      string oteText = g_priceInOTE ? ">>> IN ZONE <<<" : "Outside";
      color oteColor = g_priceInOTE ? clrLimeGreen : clrGray;
      ObjectSetString(0, g_panelName + "_ote_value", OBJPROP_TEXT, oteText);
      ObjectSetInteger(0, g_panelName + "_ote_value", OBJPROP_COLOR, oteColor);

      ObjectSetString(0, g_panelName + "_ote_range_val", OBJPROP_TEXT,
                      DoubleToString(g_oteLowerPrice, 0) + " - " + DoubleToString(g_oteUpperPrice, 0));
   }

   // Update price
   ObjectSetString(0, g_panelName + "_price_value", OBJPROP_TEXT,
                   DoubleToString(currentPrice, g_symbolInfo.digits));

   // Update position
   string posText = GetPriceFibPosition(currentPrice);
   if(StringLen(posText) > 25)
      posText = StringSubstr(posText, 0, 25) + "...";
   ObjectSetString(0, g_panelName + "_pos_value", OBJPROP_TEXT, posText);

   // Update fresh levels count
   int freshCount = CountFreshLevels();
   ObjectSetString(0, g_panelName + "_lvl_value", OBJPROP_TEXT,
                   IntegerToString(freshCount) + "/" + IntegerToString(g_fibLevelCount));

   // Update recommendation
   string recText = "";
   color recColor = clrGray;

   if(!g_fibValid)
   {
      recText = "NO DATA";
      recColor = clrGray;
   }
   else if(!g_atrResult.tradingAllowed)
   {
      recText = "NO TRADE (ATR)";
      recColor = clrGray;
   }
   else if(g_priceInOTE)
   {
      recText = g_fibDirection == BIAS_BULLISH ? "OTE BUY ZONE" : "OTE SELL ZONE";
      recColor = clrLimeGreen;
   }
   else if((g_fibDirection == BIAS_BULLISH && currentPrice > g_fibSwingHigh) ||
           (g_fibDirection == BIAS_BEARISH && currentPrice < g_fibSwingLow))
   {
      recText = "BREAKOUT";
      recColor = InpExtensionColor;
   }
   else
   {
      recText = "WAIT FOR OTE";
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
bool IsFibValid() { return g_fibValid; }
double GetFibSwingHigh() { return g_fibSwingHigh; }
double GetFibSwingLow() { return g_fibSwingLow; }
datetime GetFibSwingHighTime() { return g_fibSwingHighTime; }
datetime GetFibSwingLowTime() { return g_fibSwingLowTime; }
ENUM_TREND_BIAS GetFibDirection() { return g_fibDirection; }
bool IsPriceInOTE() { return g_priceInOTE; }
double GetOTEUpperPrice() { return g_oteUpperPrice; }
double GetOTELowerPrice() { return g_oteLowerPrice; }
int GetFreshLevelCount() { return CountFreshLevels(); }
double GetATRPips() { return g_currentATRPips; }

// Get specific fib level by ratio
double GetFibLevelByRatio(double ratio)
{
   for(int i = 0; i < g_fibLevelCount; i++)
   {
      if(MathAbs(g_fibLevels[i].ratio - ratio) < 0.001)
         return g_fibLevels[i].price;
   }
   return 0;
}

// Check if specific level is mitigated
bool IsLevelMitigated(double ratio)
{
   for(int i = 0; i < g_fibLevelCount; i++)
   {
      if(MathAbs(g_fibLevels[i].ratio - ratio) < 0.001)
         return g_fibLevels[i].isMitigated;
   }
   return false;
}
//+------------------------------------------------------------------+
