//+------------------------------------------------------------------+
//|                                         Section03_BOSCHoCH.mq5   |
//|                                      SwingTrader Pro EA          |
//|                Section 3: BOS & CHoCH Detection (SMC/ICT)        |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.12"
#property description "Section 3: Break of Structure & Change of Character"
#property description "Smart Money Concepts (SMC/ICT) Structure Analysis"
#property description "Detects swing points, BOS, and CHoCH on H4"

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Structure Detection Settings ==="
input int      InpSwingLookback       = 3;        // Swing Detection Lookback (bars each side)
input int      InpBOSLookback         = 50;       // BOS/CHoCH Lookback (candles)
input bool     InpRequireClose        = true;     // Require Candle Close for Confirmation
input ENUM_TIMEFRAMES InpStructureTF  = PERIOD_H4; // Structure Analysis Timeframe
input int      InpMinSwingsForStructure = 3;      // Min Swings for Structure Confirmation (3-4)
input bool     InpRequireCHoCHConfirm = true;     // Require CHoCH Confirmation (pullback + BOS)

input group "=== Higher Timeframe Filter (Optional) ==="
input bool     InpUseHTFFilter        = false;    // Use D1 Trend Filter
input ENUM_TIMEFRAMES InpHTFTimeframe = PERIOD_D1; // Higher Timeframe

input group "=== Volume Confirmation (Optional) ==="
input bool     InpUseVolumeConfirm    = true;     // Use Volume Spike for CHoCH
input double   InpVolumeMultiplier    = 1.5;      // Volume Spike Multiplier (vs 20-period avg)
input int      InpVolumeLookback      = 20;       // Volume Average Lookback

input group "=== EMA Settings (from Section 2) ==="
input bool     InpUseEMAFilter        = true;     // Use EMA Trend Filter
input int      InpEMAFastPeriod       = 50;       // EMA Fast Period
input int      InpEMASlowPeriod       = 200;      // EMA Slow Period

input group "=== ATR Settings (from Section 1) ==="
input bool     InpUseATRFilter        = true;     // Use ATR Volatility Filter
input int      InpATRPeriod           = 14;       // ATR Period
input double   InpATRQuietThreshold   = 60.0;     // Quiet Market Threshold (pips)
input double   InpATRExtremeThreshold = 250.0;    // Extreme Volatility Threshold (pips)

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;     // Show Info Panel
input bool     InpShowSwingPoints     = true;     // Show Swing High/Low Markers
input bool     InpShowBOSLines        = true;     // Show BOS/CHoCH Lines
input color    InpSwingHighColor      = clrRed;   // Swing High Color
input color    InpSwingLowColor       = clrLimeGreen; // Swing Low Color
input color    InpBOSBullishColor     = clrDodgerBlue; // Bullish BOS Color
input color    InpBOSBearishColor     = clrOrangeRed;  // Bearish BOS Color
input color    InpCHoCHColor          = clrMagenta;    // CHoCH Color
input int      InpPanelX              = 20;       // Panel X Position
input int      InpPanelY              = 30;       // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;     // Print Report to Experts Tab
input int      InpMaxSwingPoints      = 20;       // Max Swing Points to Track

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

// Swing points storage
SwingPoint     g_swingHighs[];
SwingPoint     g_swingLows[];
int            g_swingHighCount = 0;
int            g_swingLowCount = 0;

// Structure tracking
ENUM_TREND_BIAS g_currentStructure = BIAS_NEUTRAL;  // Current market structure
ENUM_TREND_BIAS g_previousStructure = BIAS_NEUTRAL; // Previous structure
StructureBreak g_lastBOS;                           // Last BOS
StructureBreak g_lastCHoCH;                         // Last CHoCH
bool           g_hasBOS = false;
bool           g_hasCHoCH = false;

// Results from previous sections
EMAAnalysisResult g_emaResult;
ATRFilterResult   g_atrResult;

// Panel
string         g_panelName = "BOSCHoCHPanel";

// Symbol info
int            g_digits;
double         g_point;
double         g_pipSize;
string         g_instrumentType;

// Higher timeframe filter
int            g_htfEmaFastHandle;
int            g_htfEmaSlowHandle;
double         g_htfEmaFastBuffer[];
double         g_htfEmaSlowBuffer[];
ENUM_TREND_BIAS g_htfTrend = BIAS_NEUTRAL;

// CHoCH confirmation tracking
bool           g_chochPending = false;           // CHoCH waiting for confirmation
StructureBreak g_pendingCHoCH;                   // Pending CHoCH details
int            g_chochConfirmBars = 0;           // Bars since CHoCH

// Volume analysis
double         g_volumeBuffer[];
double         g_avgVolume = 0;
bool           g_hasVolumeSpike = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get symbol info
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Auto-detect instrument type and set pip size
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

   // Initialize arrays
   ArrayResize(g_swingHighs, InpMaxSwingPoints);
   ArrayResize(g_swingLows, InpMaxSwingPoints);
   ArraySetAsSeries(g_highBuffer, true);
   ArraySetAsSeries(g_lowBuffer, true);
   ArraySetAsSeries(g_closeBuffer, true);
   ArraySetAsSeries(g_timeBuffer, true);
   ArraySetAsSeries(g_volumeBuffer, true);

   // Create EMA handles if filter enabled
   if(InpUseEMAFilter)
   {
      g_emaFastHandle = iMA(_Symbol, InpStructureTF, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_emaSlowHandle = iMA(_Symbol, InpStructureTF, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);

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
      g_atrHandle = iATR(_Symbol, InpStructureTF, InpATRPeriod);
      if(g_atrHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR handle");
         return(INIT_FAILED);
      }
      ArraySetAsSeries(g_atrBuffer, true);
   }

   // Create HTF EMA handles if filter enabled
   if(InpUseHTFFilter)
   {
      g_htfEmaFastHandle = iMA(_Symbol, InpHTFTimeframe, InpEMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_htfEmaSlowHandle = iMA(_Symbol, InpHTFTimeframe, InpEMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);

      if(g_htfEmaFastHandle == INVALID_HANDLE || g_htfEmaSlowHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create HTF EMA handles");
         return(INIT_FAILED);
      }
      ArraySetAsSeries(g_htfEmaFastBuffer, true);
      ArraySetAsSeries(g_htfEmaSlowBuffer, true);
      Print("HTF Filter enabled: ", TimeframeToString(InpHTFTimeframe));
   }

   // Print initialization
   PrintInitReport();

   // Create panel
   if(InpShowPanel)
      CreatePanel();

   // Run initial analysis
   AnalyzeStructure();

   // Update panel with initial values (same fix as Section 4)
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
   ObjectsDeleteAll(0, "Swing_");
   ObjectsDeleteAll(0, "BOS_");
   ObjectsDeleteAll(0, "CHoCH_");

   Print("=================================================");
   Print("BOS/CHoCH Detection EA Deinitialized");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpStructureTF, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      AnalyzeStructure();

      if(InpShowPanel) UpdatePanel();
   }
}

//+------------------------------------------------------------------+
//| Main Structure Analysis Function                                  |
//+------------------------------------------------------------------+
void AnalyzeStructure()
{
   // Copy price data
   int barsNeeded = InpBOSLookback + InpSwingLookback * 2 + 10;

   if(CopyHigh(_Symbol, InpStructureTF, 0, barsNeeded, g_highBuffer) < barsNeeded) return;
   if(CopyLow(_Symbol, InpStructureTF, 0, barsNeeded, g_lowBuffer) < barsNeeded) return;
   if(CopyClose(_Symbol, InpStructureTF, 0, barsNeeded, g_closeBuffer) < barsNeeded) return;
   if(CopyTime(_Symbol, InpStructureTF, 0, barsNeeded, g_timeBuffer) < barsNeeded) return;

   // Analyze ATR if enabled
   if(InpUseATRFilter)
      AnalyzeATR();

   // Analyze EMA if enabled
   if(InpUseEMAFilter)
      AnalyzeEMA();

   // Analyze Higher Timeframe trend if enabled
   if(InpUseHTFFilter)
      AnalyzeHTFTrend();

   // Analyze Volume for CHoCH confirmation
   if(InpUseVolumeConfirm)
      AnalyzeVolume();

   // Detect swing points
   DetectSwingPoints();

   // Detect BOS and CHoCH
   DetectBOSandCHoCH();

   // Draw visual elements
   if(InpShowSwingPoints) DrawSwingPoints();
   if(InpShowBOSLines) DrawBOSLines();

   // Print report
   if(InpPrintReport)
      PrintStructureReport();
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
   if(CopyBuffer(g_emaFastHandle, 0, 0, InpBOSLookback, g_emaFastBuffer) < InpBOSLookback) return;
   if(CopyBuffer(g_emaSlowHandle, 0, 0, InpBOSLookback, g_emaSlowBuffer) < InpBOSLookback) return;

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
//| Sort swing points by barIndex (ascending = oldest first)          |
//| After sort: index 0 = most recent (smallest barIndex)             |
//+------------------------------------------------------------------+
void SortSwingPoints(SwingPoint &arr[], int count)
{
   // Simple bubble sort by barIndex ascending (smallest barIndex = most recent)
   for(int i = 0; i < count - 1; i++)
   {
      for(int j = 0; j < count - i - 1; j++)
      {
         if(arr[j].barIndex > arr[j + 1].barIndex)
         {
            // Swap
            SwingPoint temp = arr[j];
            arr[j] = arr[j + 1];
            arr[j + 1] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Swing High and Swing Low Points                            |
//+------------------------------------------------------------------+
void DetectSwingPoints()
{
   g_swingHighCount = 0;
   g_swingLowCount = 0;

   // Look for swing points (need InpSwingLookback bars on each side)
   for(int i = InpSwingLookback; i < InpBOSLookback - InpSwingLookback; i++)
   {
      // Check for Swing High
      if(IsSwingHigh(i))
      {
         if(g_swingHighCount < InpMaxSwingPoints)
         {
            g_swingHighs[g_swingHighCount].price = g_highBuffer[i];
            g_swingHighs[g_swingHighCount].time = g_timeBuffer[i];
            g_swingHighs[g_swingHighCount].barIndex = i;
            g_swingHighs[g_swingHighCount].isHigh = true;
            g_swingHighs[g_swingHighCount].isValid = true;
            g_swingHighCount++;
         }
      }

      // Check for Swing Low
      if(IsSwingLow(i))
      {
         if(g_swingLowCount < InpMaxSwingPoints)
         {
            g_swingLows[g_swingLowCount].price = g_lowBuffer[i];
            g_swingLows[g_swingLowCount].time = g_timeBuffer[i];
            g_swingLows[g_swingLowCount].barIndex = i;
            g_swingLows[g_swingLowCount].isHigh = false;
            g_swingLows[g_swingLowCount].isValid = true;
            g_swingLowCount++;
         }
      }
   }

   // CRITICAL FIX: Sort by barIndex ascending so index 0 = most recent swing
   SortSwingPoints(g_swingHighs, g_swingHighCount);
   SortSwingPoints(g_swingLows, g_swingLowCount);
}

//+------------------------------------------------------------------+
//| Check if bar is a Swing High                                      |
//+------------------------------------------------------------------+
bool IsSwingHigh(int index)
{
   double currentHigh = g_highBuffer[index];

   // Check left side (bars before)
   for(int i = 1; i <= InpSwingLookback; i++)
   {
      if(g_highBuffer[index + i] >= currentHigh)
         return false;
   }

   // Check right side (bars after)
   for(int i = 1; i <= InpSwingLookback; i++)
   {
      if(g_highBuffer[index - i] >= currentHigh)
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

   // Check left side (bars before)
   for(int i = 1; i <= InpSwingLookback; i++)
   {
      if(g_lowBuffer[index + i] <= currentLow)
         return false;
   }

   // Check right side (bars after)
   for(int i = 1; i <= InpSwingLookback; i++)
   {
      if(g_lowBuffer[index - i] <= currentLow)
         return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Detect BOS and CHoCH                                              |
//| IMPROVED: CHoCH requires confirmation (pullback + new BOS)        |
//+------------------------------------------------------------------+
void DetectBOSandCHoCH()
{
   g_hasBOS = false;
   g_hasCHoCH = false;

   if(g_swingHighCount < 2 || g_swingLowCount < 2)
      return;

   // Get most recent swing points
   double lastSwingHigh = g_swingHighs[0].price;
   double lastSwingLow = g_swingLows[0].price;
   double prevSwingHigh = g_swingHighs[1].price;
   double prevSwingLow = g_swingLows[1].price;

   // Current price (most recent close)
   double currentClose = g_closeBuffer[0];
   double currentHigh = g_highBuffer[0];
   double currentLow = g_lowBuffer[0];

   // Determine previous structure based on swing points (uses 3-4 swings now)
   DeterminePreviousStructure();

   // Check for pending CHoCH confirmation
   if(g_chochPending && InpRequireCHoCHConfirm)
   {
      g_chochConfirmBars++;

      // CHoCH confirmed if we get a BOS in the new direction
      if(g_pendingCHoCH.direction == BIAS_BULLISH)
      {
         // Bullish CHoCH confirmed by breaking above the high after the CHoCH break
         if(CheckBreakAbove(lastSwingHigh) && lastSwingHigh > g_pendingCHoCH.breakLevel)
         {
            g_hasCHoCH = true;
            g_lastCHoCH = g_pendingCHoCH;
            g_lastCHoCH.confirmed = true;
            g_currentStructure = BIAS_BULLISH;
            g_previousStructure = BIAS_BULLISH;
            g_chochPending = false;
            Print("CHoCH CONFIRMED: Bullish reversal validated by new BOS");
         }
      }
      else if(g_pendingCHoCH.direction == BIAS_BEARISH)
      {
         // Bearish CHoCH confirmed by breaking below the low after the CHoCH break
         if(CheckBreakBelow(lastSwingLow) && lastSwingLow < g_pendingCHoCH.breakLevel)
         {
            g_hasCHoCH = true;
            g_lastCHoCH = g_pendingCHoCH;
            g_lastCHoCH.confirmed = true;
            g_currentStructure = BIAS_BEARISH;
            g_previousStructure = BIAS_BEARISH;
            g_chochPending = false;
            Print("CHoCH CONFIRMED: Bearish reversal validated by new BOS");
         }
      }

      // Cancel pending CHoCH if price moves back to original structure
      if(g_chochConfirmBars > 10)  // Timeout after 10 bars
      {
         Print("CHoCH CANCELLED: Timeout - no confirmation within 10 bars");
         g_chochPending = false;
      }
   }

   // Bullish BOS: Price breaks above last swing high (in bullish structure)
   if(g_previousStructure == BIAS_BULLISH)
   {
      // In bullish structure, breaking above swing high = BOS (continuation)
      if(CheckBreakAbove(lastSwingHigh))
      {
         g_hasBOS = true;
         g_lastBOS.type = STRUCTURE_BOS;
         g_lastBOS.direction = BIAS_BULLISH;
         g_lastBOS.breakLevel = lastSwingHigh;
         g_lastBOS.breakTime = g_timeBuffer[0];
         g_lastBOS.barIndex = 0;
         g_lastBOS.confirmed = InpRequireClose ? (currentClose > lastSwingHigh) : true;
         g_currentStructure = BIAS_BULLISH;

         // Cancel any pending bearish CHoCH
         if(g_chochPending && g_pendingCHoCH.direction == BIAS_BEARISH)
         {
            Print("Pending CHoCH cancelled - bullish BOS continuation");
            g_chochPending = false;
         }
      }
      // In bullish structure, breaking below swing low = CHoCH (potential reversal)
      else if(CheckBreakBelow(lastSwingLow))
      {
         // Check volume confirmation if enabled
         bool volumeOK = HasVolumeConfirmation();

         if(InpRequireCHoCHConfirm)
         {
            // Set as pending CHoCH, wait for confirmation
            // Volume spike adds credibility but doesn't block pending status
            g_chochPending = true;
            g_chochConfirmBars = 0;
            g_pendingCHoCH.type = STRUCTURE_CHOCH;
            g_pendingCHoCH.direction = BIAS_BEARISH;
            g_pendingCHoCH.breakLevel = lastSwingLow;
            g_pendingCHoCH.breakTime = g_timeBuffer[0];
            g_pendingCHoCH.barIndex = 0;
            g_pendingCHoCH.confirmed = false;
            g_currentStructure = BIAS_NEUTRAL;

            string volMsg = volumeOK ? " [VOLUME SPIKE]" : " [Low Volume - watch carefully]";
            Print("CHoCH PENDING: Bearish break detected, waiting for confirmation", volMsg);
         }
         else if(volumeOK)
         {
            // Immediate CHoCH (requires volume confirmation if enabled)
            g_hasCHoCH = true;
            g_lastCHoCH.type = STRUCTURE_CHOCH;
            g_lastCHoCH.direction = BIAS_BEARISH;
            g_lastCHoCH.breakLevel = lastSwingLow;
            g_lastCHoCH.breakTime = g_timeBuffer[0];
            g_lastCHoCH.barIndex = 0;
            g_lastCHoCH.confirmed = InpRequireClose ? (currentClose < lastSwingLow) : true;
            g_currentStructure = BIAS_NEUTRAL;
            Print("CHoCH IMMEDIATE: Bearish break with volume confirmation");
         }
         else
         {
            // Volume check failed - treat as weak signal, set as pending
            Print("CHoCH WEAK: Bearish break but LOW VOLUME - treating as pending");
            g_chochPending = true;
            g_chochConfirmBars = 0;
            g_pendingCHoCH.type = STRUCTURE_CHOCH;
            g_pendingCHoCH.direction = BIAS_BEARISH;
            g_pendingCHoCH.breakLevel = lastSwingLow;
            g_pendingCHoCH.breakTime = g_timeBuffer[0];
            g_pendingCHoCH.barIndex = 0;
            g_pendingCHoCH.confirmed = false;
            g_currentStructure = BIAS_NEUTRAL;
         }
      }
   }
   // Bearish BOS: Price breaks below last swing low (in bearish structure)
   else if(g_previousStructure == BIAS_BEARISH)
   {
      // In bearish structure, breaking below swing low = BOS (continuation)
      if(CheckBreakBelow(lastSwingLow))
      {
         g_hasBOS = true;
         g_lastBOS.type = STRUCTURE_BOS;
         g_lastBOS.direction = BIAS_BEARISH;
         g_lastBOS.breakLevel = lastSwingLow;
         g_lastBOS.breakTime = g_timeBuffer[0];
         g_lastBOS.barIndex = 0;
         g_lastBOS.confirmed = InpRequireClose ? (currentClose < lastSwingLow) : true;
         g_currentStructure = BIAS_BEARISH;

         // Cancel any pending bullish CHoCH
         if(g_chochPending && g_pendingCHoCH.direction == BIAS_BULLISH)
         {
            Print("Pending CHoCH cancelled - bearish BOS continuation");
            g_chochPending = false;
         }
      }
      // In bearish structure, breaking above swing high = CHoCH (potential reversal)
      else if(CheckBreakAbove(lastSwingHigh))
      {
         // Check volume confirmation if enabled
         bool volumeOK = HasVolumeConfirmation();

         if(InpRequireCHoCHConfirm)
         {
            // Set as pending CHoCH, wait for confirmation
            // Volume spike adds credibility but doesn't block pending status
            g_chochPending = true;
            g_chochConfirmBars = 0;
            g_pendingCHoCH.type = STRUCTURE_CHOCH;
            g_pendingCHoCH.direction = BIAS_BULLISH;
            g_pendingCHoCH.breakLevel = lastSwingHigh;
            g_pendingCHoCH.breakTime = g_timeBuffer[0];
            g_pendingCHoCH.barIndex = 0;
            g_pendingCHoCH.confirmed = false;
            g_currentStructure = BIAS_NEUTRAL;

            string volMsg = volumeOK ? " [VOLUME SPIKE]" : " [Low Volume - watch carefully]";
            Print("CHoCH PENDING: Bullish break detected, waiting for confirmation", volMsg);
         }
         else if(volumeOK)
         {
            // Immediate CHoCH (requires volume confirmation if enabled)
            g_hasCHoCH = true;
            g_lastCHoCH.type = STRUCTURE_CHOCH;
            g_lastCHoCH.direction = BIAS_BULLISH;
            g_lastCHoCH.breakLevel = lastSwingHigh;
            g_lastCHoCH.breakTime = g_timeBuffer[0];
            g_lastCHoCH.barIndex = 0;
            g_lastCHoCH.confirmed = InpRequireClose ? (currentClose > lastSwingHigh) : true;
            g_currentStructure = BIAS_NEUTRAL;
            Print("CHoCH IMMEDIATE: Bullish break with volume confirmation");
         }
         else
         {
            // Volume check failed - treat as weak signal, set as pending
            Print("CHoCH WEAK: Bullish break but LOW VOLUME - treating as pending");
            g_chochPending = true;
            g_chochConfirmBars = 0;
            g_pendingCHoCH.type = STRUCTURE_CHOCH;
            g_pendingCHoCH.direction = BIAS_BULLISH;
            g_pendingCHoCH.breakLevel = lastSwingHigh;
            g_pendingCHoCH.breakTime = g_timeBuffer[0];
            g_pendingCHoCH.barIndex = 0;
            g_pendingCHoCH.confirmed = false;
            g_currentStructure = BIAS_NEUTRAL;
         }
      }
   }
   else // NEUTRAL - determining initial structure
   {
      // Check which way structure is breaking
      if(CheckBreakAbove(lastSwingHigh))
      {
         g_hasBOS = true;
         g_lastBOS.type = STRUCTURE_BOS;
         g_lastBOS.direction = BIAS_BULLISH;
         g_lastBOS.breakLevel = lastSwingHigh;
         g_lastBOS.breakTime = g_timeBuffer[0];
         g_lastBOS.barIndex = 0;
         g_lastBOS.confirmed = InpRequireClose ? (currentClose > lastSwingHigh) : true;
         g_currentStructure = BIAS_BULLISH;
         g_previousStructure = BIAS_BULLISH;
      }
      else if(CheckBreakBelow(lastSwingLow))
      {
         g_hasBOS = true;
         g_lastBOS.type = STRUCTURE_BOS;
         g_lastBOS.direction = BIAS_BEARISH;
         g_lastBOS.breakLevel = lastSwingLow;
         g_lastBOS.breakTime = g_timeBuffer[0];
         g_lastBOS.barIndex = 0;
         g_lastBOS.confirmed = InpRequireClose ? (currentClose < lastSwingLow) : true;
         g_currentStructure = BIAS_BEARISH;
         g_previousStructure = BIAS_BEARISH;
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze Higher Timeframe Trend (D1)                               |
//+------------------------------------------------------------------+
void AnalyzeHTFTrend()
{
   if(!InpUseHTFFilter)
   {
      g_htfTrend = BIAS_NEUTRAL;
      return;
   }

   if(CopyBuffer(g_htfEmaFastHandle, 0, 0, 1, g_htfEmaFastBuffer) < 1) return;
   if(CopyBuffer(g_htfEmaSlowHandle, 0, 0, 1, g_htfEmaSlowBuffer) < 1) return;

   if(g_htfEmaFastBuffer[0] > g_htfEmaSlowBuffer[0])
      g_htfTrend = BIAS_BULLISH;
   else if(g_htfEmaFastBuffer[0] < g_htfEmaSlowBuffer[0])
      g_htfTrend = BIAS_BEARISH;
   else
      g_htfTrend = BIAS_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Analyze Volume for CHoCH Confirmation                             |
//| Checks if current bar has volume spike (above average)            |
//+------------------------------------------------------------------+
void AnalyzeVolume()
{
   g_hasVolumeSpike = false;

   if(!InpUseVolumeConfirm)
      return;

   // Copy volume data
   int volumeNeeded = InpVolumeLookback + 1;
   if(CopyTickVolume(_Symbol, InpStructureTF, 0, volumeNeeded, g_volumeBuffer) < volumeNeeded)
      return;

   // Calculate average volume (excluding current bar)
   double totalVolume = 0;
   for(int i = 1; i <= InpVolumeLookback; i++)
   {
      totalVolume += (double)g_volumeBuffer[i];
   }
   g_avgVolume = totalVolume / InpVolumeLookback;

   // Check if current bar has volume spike
   double currentVolume = (double)g_volumeBuffer[0];
   if(g_avgVolume > 0 && currentVolume >= g_avgVolume * InpVolumeMultiplier)
   {
      g_hasVolumeSpike = true;
      if(InpPrintReport)
         Print("VOLUME SPIKE: ", DoubleToString(currentVolume, 0),
               " vs Avg: ", DoubleToString(g_avgVolume, 0),
               " (", DoubleToString(currentVolume / g_avgVolume, 2), "x)");
   }
}

//+------------------------------------------------------------------+
//| Check if CHoCH has Volume Confirmation                            |
//| Returns true if volume check passes or is disabled                 |
//+------------------------------------------------------------------+
bool HasVolumeConfirmation()
{
   if(!InpUseVolumeConfirm)
      return true;  // If disabled, always passes

   return g_hasVolumeSpike;
}

//+------------------------------------------------------------------+
//| Determine Previous Structure from Swing Points                    |
//| IMPROVED: Uses 3-4 swings for proper HH/HL/LH/LL confirmation     |
//+------------------------------------------------------------------+
void DeterminePreviousStructure()
{
   int minSwings = InpMinSwingsForStructure;  // Default 3

   if(g_swingHighCount < minSwings || g_swingLowCount < minSwings)
   {
      g_previousStructure = BIAS_NEUTRAL;
      return;
   }

   // Count HH/LH patterns in swing highs (use last 3-4 swings)
   int hhCount = 0;  // Higher High count
   int lhCount = 0;  // Lower High count

   for(int i = 0; i < minSwings - 1 && i < g_swingHighCount - 1; i++)
   {
      if(g_swingHighs[i].price > g_swingHighs[i + 1].price)
         hhCount++;  // Higher High
      else if(g_swingHighs[i].price < g_swingHighs[i + 1].price)
         lhCount++;  // Lower High
   }

   // Count HL/LL patterns in swing lows (use last 3-4 swings)
   int hlCount = 0;  // Higher Low count
   int llCount = 0;  // Lower Low count

   for(int i = 0; i < minSwings - 1 && i < g_swingLowCount - 1; i++)
   {
      if(g_swingLows[i].price > g_swingLows[i + 1].price)
         hlCount++;  // Higher Low
      else if(g_swingLows[i].price < g_swingLows[i + 1].price)
         llCount++;  // Lower Low
   }

   // Determine structure:
   // BULLISH = Majority HH + Majority HL
   // BEARISH = Majority LH + Majority LL
   // NEUTRAL = Mixed signals

   int threshold = (minSwings - 1) / 2;  // At least half must agree

   bool bullishHighs = (hhCount > threshold);
   bool bullishLows = (hlCount > threshold);
   bool bearishHighs = (lhCount > threshold);
   bool bearishLows = (llCount > threshold);

   if(bullishHighs && bullishLows)
      g_previousStructure = BIAS_BULLISH;
   else if(bearishHighs && bearishLows)
      g_previousStructure = BIAS_BEARISH;
   else
      g_previousStructure = BIAS_NEUTRAL;

   // Debug output
   if(InpPrintReport)
   {
      Print("Structure Analysis: HH=", hhCount, " LH=", lhCount, " HL=", hlCount, " LL=", llCount);
      Print("Result: ", TrendBiasToString(g_previousStructure));
   }
}

//+------------------------------------------------------------------+
//| Check if price broke above level                                  |
//+------------------------------------------------------------------+
bool CheckBreakAbove(double level)
{
   if(InpRequireClose)
      return g_closeBuffer[0] > level;
   else
      return g_highBuffer[0] > level;
}

//+------------------------------------------------------------------+
//| Check if price broke below level                                  |
//+------------------------------------------------------------------+
bool CheckBreakBelow(double level)
{
   if(InpRequireClose)
      return g_closeBuffer[0] < level;
   else
      return g_lowBuffer[0] < level;
}

//+------------------------------------------------------------------+
//| Draw Swing Points on Chart - DYNAMIC LABELS (HH/LH, HL/LL)        |
//+------------------------------------------------------------------+
void DrawSwingPoints()
{
   // Remove old swing markers
   ObjectsDeleteAll(0, "Swing_");

   // Draw Swing Highs with dynamic HH/LH labels
   for(int i = 0; i < g_swingHighCount; i++)
   {
      string name = "Swing_High_" + IntegerToString(i);
      ObjectCreate(0, name, OBJ_ARROW, 0, g_swingHighs[i].time, g_swingHighs[i].price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 218); // Down arrow
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpSwingHighColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);

      // Determine label: HH (Higher High) or LH (Lower High)
      string labelText = "SH";  // Default: Swing High
      if(i < g_swingHighCount - 1)
      {
         if(g_swingHighs[i].price > g_swingHighs[i + 1].price)
            labelText = "HH";  // Higher High (current > previous)
         else
            labelText = "LH";  // Lower High (current < previous)
      }

      string labelName = "Swing_High_Label_" + IntegerToString(i);
      ObjectCreate(0, labelName, OBJ_TEXT, 0, g_swingHighs[i].time, g_swingHighs[i].price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, InpSwingHighColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LOWER);
   }

   // Draw Swing Lows with dynamic HL/LL labels
   for(int i = 0; i < g_swingLowCount; i++)
   {
      string name = "Swing_Low_" + IntegerToString(i);
      ObjectCreate(0, name, OBJ_ARROW, 0, g_swingLows[i].time, g_swingLows[i].price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 217); // Up arrow
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpSwingLowColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);

      // Determine label: HL (Higher Low) or LL (Lower Low)
      string labelText = "SL";  // Default: Swing Low
      if(i < g_swingLowCount - 1)
      {
         if(g_swingLows[i].price > g_swingLows[i + 1].price)
            labelText = "HL";  // Higher Low (current > previous)
         else
            labelText = "LL";  // Lower Low (current < previous)
      }

      string labelName = "Swing_Low_Label_" + IntegerToString(i);
      ObjectCreate(0, labelName, OBJ_TEXT, 0, g_swingLows[i].time, g_swingLows[i].price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, InpSwingLowColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_UPPER);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Draw BOS and CHoCH Lines                                          |
//+------------------------------------------------------------------+
void DrawBOSLines()
{
   // Remove old lines
   ObjectsDeleteAll(0, "BOS_");
   ObjectsDeleteAll(0, "CHoCH_");

   // Draw BOS line if exists
   if(g_hasBOS)
   {
      string bosName = "BOS_Line";
      datetime startTime = g_lastBOS.breakTime - PeriodSeconds(InpStructureTF) * 10;
      datetime endTime = g_lastBOS.breakTime + PeriodSeconds(InpStructureTF) * 5;

      ObjectCreate(0, bosName, OBJ_TREND, 0, startTime, g_lastBOS.breakLevel, endTime, g_lastBOS.breakLevel);

      color bosColor = (g_lastBOS.direction == BIAS_BULLISH) ? InpBOSBullishColor : InpBOSBearishColor;
      ObjectSetInteger(0, bosName, OBJPROP_COLOR, bosColor);
      ObjectSetInteger(0, bosName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, bosName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, bosName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, bosName, OBJPROP_SELECTABLE, false);

      // Add BOS label
      string bosLabel = "BOS_Label";
      ObjectCreate(0, bosLabel, OBJ_TEXT, 0, g_lastBOS.breakTime, g_lastBOS.breakLevel);
      string labelText = "BOS " + (g_lastBOS.direction == BIAS_BULLISH ? "↑" : "↓");
      if(!g_lastBOS.confirmed) labelText += " (?)";
      ObjectSetString(0, bosLabel, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, bosLabel, OBJPROP_COLOR, bosColor);
      ObjectSetInteger(0, bosLabel, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, bosLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }

   // Draw CHoCH line if exists
   if(g_hasCHoCH)
   {
      string chochName = "CHoCH_Line";
      datetime startTime = g_lastCHoCH.breakTime - PeriodSeconds(InpStructureTF) * 10;
      datetime endTime = g_lastCHoCH.breakTime + PeriodSeconds(InpStructureTF) * 5;

      ObjectCreate(0, chochName, OBJ_TREND, 0, startTime, g_lastCHoCH.breakLevel, endTime, g_lastCHoCH.breakLevel);
      ObjectSetInteger(0, chochName, OBJPROP_COLOR, InpCHoCHColor);
      ObjectSetInteger(0, chochName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, chochName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, chochName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, chochName, OBJPROP_SELECTABLE, false);

      // Add CHoCH label
      string chochLabel = "CHoCH_Label";
      ObjectCreate(0, chochLabel, OBJ_TEXT, 0, g_lastCHoCH.breakTime, g_lastCHoCH.breakLevel);
      string labelText = "CHoCH " + (g_lastCHoCH.direction == BIAS_BULLISH ? "↑" : "↓");
      if(!g_lastCHoCH.confirmed) labelText += " (?)";
      ObjectSetString(0, chochLabel, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, chochLabel, OBJPROP_COLOR, InpCHoCHColor);
      ObjectSetInteger(0, chochLabel, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, chochLabel, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Print Structure Report                                            |
//+------------------------------------------------------------------+
void PrintStructureReport()
{
   Print("");
   Print("=================================================");
   Print("      BOS/CHoCH STRUCTURE REPORT (Section 3)     ");
   Print("=================================================");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", TimeframeToString(InpStructureTF));
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
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

   // Swing Points
   Print("SWING POINTS DETECTED:");
   Print("  Swing Highs: ", g_swingHighCount);
   Print("  Swing Lows: ", g_swingLowCount);

   if(g_swingHighCount > 0)
      Print("  Last Swing High: ", DoubleToString(g_swingHighs[0].price, g_digits),
            " at ", TimeToString(g_swingHighs[0].time, TIME_DATE|TIME_MINUTES));
   if(g_swingLowCount > 0)
      Print("  Last Swing Low: ", DoubleToString(g_swingLows[0].price, g_digits),
            " at ", TimeToString(g_swingLows[0].time, TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");

   // Structure Analysis
   Print("MARKET STRUCTURE:");
   Print("  Previous Structure: ", TrendBiasToString(g_previousStructure));
   Print("  Current Structure: ", TrendBiasToString(g_currentStructure));
   Print("-------------------------------------------------");

   // BOS Detection
   Print("BREAK OF STRUCTURE (BOS):");
   if(g_hasBOS)
   {
      Print("  BOS Detected: YES");
      Print("  Direction: ", TrendBiasToString(g_lastBOS.direction));
      Print("  Break Level: ", DoubleToString(g_lastBOS.breakLevel, g_digits));
      Print("  Confirmed: ", g_lastBOS.confirmed ? "YES" : "NO (wait for close)");
   }
   else
   {
      Print("  BOS Detected: NO");
   }
   Print("-------------------------------------------------");

   // CHoCH Detection
   Print("CHANGE OF CHARACTER (CHoCH):");
   if(g_hasCHoCH)
   {
      Print("  CHoCH Detected: YES - POTENTIAL REVERSAL!");
      Print("  New Direction: ", TrendBiasToString(g_lastCHoCH.direction));
      Print("  Break Level: ", DoubleToString(g_lastCHoCH.breakLevel, g_digits));
      Print("  Confirmed: ", g_lastCHoCH.confirmed ? "YES" : "NO (wait for close)");
      Print("  WARNING: Don't trade against H4 CHoCH!");
   }
   else
   {
      Print("  CHoCH Detected: NO");
   }
   Print("-------------------------------------------------");

   // Trading Recommendation
   Print("TRADING RECOMMENDATION:");
   PrintTradingRecommendation();
   Print("=================================================");
   Print("");
}

//+------------------------------------------------------------------+
//| Print Trading Recommendation                                      |
//+------------------------------------------------------------------+
void PrintTradingRecommendation()
{
   // Check ATR filter
   if(InpUseATRFilter && !g_atrResult.tradingAllowed)
   {
      Print("  STATUS: NO TRADE");
      Print("  REASON: Market too quiet (ATR filter)");
      return;
   }

   // Check for CHoCH warning
   if(g_hasCHoCH)
   {
      Print("  STATUS: CAUTION - POTENTIAL REVERSAL");
      Print("  REASON: CHoCH detected on H4");
      Print("  ACTION: Wait for new structure to form");
      Print("  DO NOT: Trade against the CHoCH direction");
      return;
   }

   // Check structure alignment with EMA
   if(InpUseEMAFilter)
   {
      bool aligned = (g_currentStructure == g_emaResult.trend) ||
                     (g_currentStructure == BIAS_NEUTRAL);

      if(!aligned)
      {
         Print("  STATUS: WAIT");
         Print("  REASON: Structure conflicts with EMA trend");
         Print("  Structure: ", TrendBiasToString(g_currentStructure));
         Print("  EMA Trend: ", TrendBiasToString(g_emaResult.trend));
         return;
      }
   }

   // Give trading direction based on structure
   if(g_currentStructure == BIAS_BULLISH)
   {
      Print("  STATUS: LOOK FOR BUYS");
      Print("  REASON: Bullish structure confirmed");
      if(g_hasBOS && g_lastBOS.confirmed)
         Print("  BOS: Bullish BOS confirmed - trend continuation");
      Print("  NEXT: Look for demand zone entry on H1/M15");
   }
   else if(g_currentStructure == BIAS_BEARISH)
   {
      Print("  STATUS: LOOK FOR SELLS");
      Print("  REASON: Bearish structure confirmed");
      if(g_hasBOS && g_lastBOS.confirmed)
         Print("  BOS: Bearish BOS confirmed - trend continuation");
      Print("  NEXT: Look for supply zone entry on H1/M15");
   }
   else
   {
      Print("  STATUS: WAIT");
      Print("  REASON: No clear structure - neutral market");
      Print("  ACTION: Wait for BOS to establish direction");
   }
}

//+------------------------------------------------------------------+
//| Print Initialization Report                                       |
//+------------------------------------------------------------------+
void PrintInitReport()
{
   Print("");
   Print("=================================================");
   Print("     SWING TRADER PRO - SECTION 3                ");
   Print("     BOS/CHoCH STRUCTURE DETECTION               ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol);
   Print("TIMEFRAME: ", TimeframeToString(InpStructureTF));
   Print("-------------------------------------------------");
   Print("STRUCTURE DETECTION SETTINGS:");
   Print("  Swing Lookback: ", InpSwingLookback, " bars each side");
   Print("  BOS Lookback: ", InpBOSLookback, " candles");
   Print("  Require Close: ", InpRequireClose ? "YES" : "NO");
   Print("  CHoCH Confirmation: ", InpRequireCHoCHConfirm ? "YES (wait for BOS)" : "NO (immediate)");
   Print("-------------------------------------------------");
   Print("CHoCH CONFIRMATION METHODS:");
   Print("  1. Candle Close: ", InpRequireClose ? "YES" : "NO");
   Print("  2. Volume Spike: ", InpUseVolumeConfirm ? ("YES (" + DoubleToString(InpVolumeMultiplier, 1) + "x avg)") : "NO");
   Print("  3. HTF Filter: ", InpUseHTFFilter ? ("YES (" + TimeframeToString(InpHTFTimeframe) + ")") : "NO");
   Print("  4. Retest/BOS: ", InpRequireCHoCHConfirm ? "YES" : "NO");
   Print("-------------------------------------------------");
   Print("DEFINITIONS:");
   Print("  BOS (Break of Structure): Trend continuation");
   Print("    - Bullish BOS: Break above swing high in uptrend");
   Print("    - Bearish BOS: Break below swing low in downtrend");
   Print("");
   Print("  CHoCH (Change of Character): Potential reversal");
   Print("    - Bullish CHoCH: Break above high in downtrend");
   Print("    - Bearish CHoCH: Break below low in uptrend");
   Print("    - WARNING: Don't trade against H4 CHoCH!");
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

   CreateRectangle(g_panelName + "_bg", x, y, 320, 300, clrBlack, 200);

   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "BOS/CHoCH STRUCTURE ANALYSIS", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "------------------------------------", clrGray, 8, "Courier New");

   // ATR Status
   int yOff = 40;
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

   // Volume Status
   if(InpUseVolumeConfirm)
   {
      CreateLabel(g_panelName + "_vol_label", x + 10, y + yOff, "Volume:", clrWhite, 9, "Arial");
      CreateLabel(g_panelName + "_vol_value", x + 120, y + yOff, "--", clrGray, 9, "Arial Bold");
      yOff += 20;
   }

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Swing Points
   CreateLabel(g_panelName + "_swing_label", x + 10, y + yOff, "Swing Points:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_swing_value", x + 120, y + yOff, "H:-- L:--", clrCyan, 9, "Arial");
   yOff += 20;

   // Last Swing High
   CreateLabel(g_panelName + "_sh_label", x + 10, y + yOff, "Last High:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_sh_value", x + 120, y + yOff, "--", clrRed, 9, "Arial");
   yOff += 20;

   // Last Swing Low
   CreateLabel(g_panelName + "_sl_label", x + 10, y + yOff, "Last Low:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_sl_value", x + 120, y + yOff, "--", clrLimeGreen, 9, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_sep3", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Structure
   CreateLabel(g_panelName + "_struct_label", x + 10, y + yOff, "Structure:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_struct_value", x + 120, y + yOff, "--", clrYellow, 9, "Arial Bold");
   yOff += 20;

   // BOS Status
   CreateLabel(g_panelName + "_bos_label", x + 10, y + yOff, "BOS:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_bos_value", x + 120, y + yOff, "None", clrGray, 9, "Arial Bold");
   yOff += 20;

   // CHoCH Status
   CreateLabel(g_panelName + "_choch_label", x + 10, y + yOff, "CHoCH:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_choch_value", x + 120, y + yOff, "None", clrGray, 9, "Arial Bold");
   yOff += 20;

   CreateLabel(g_panelName + "_sep4", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

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

   // Update Volume
   if(InpUseVolumeConfirm)
   {
      string volText = "";
      color volColor = clrGray;

      if(g_hasVolumeSpike)
      {
         volText = "SPIKE!";
         volColor = clrLimeGreen;
      }
      else if(g_avgVolume > 0)
      {
         volText = "Normal";
         volColor = clrGray;
      }
      else
      {
         volText = "--";
         volColor = clrGray;
      }

      ObjectSetString(0, g_panelName + "_vol_value", OBJPROP_TEXT, volText);
      ObjectSetInteger(0, g_panelName + "_vol_value", OBJPROP_COLOR, volColor);
   }

   // Update Swing Points
   ObjectSetString(0, g_panelName + "_swing_value", OBJPROP_TEXT,
                   "H:" + IntegerToString(g_swingHighCount) + " L:" + IntegerToString(g_swingLowCount));

   if(g_swingHighCount > 0)
      ObjectSetString(0, g_panelName + "_sh_value", OBJPROP_TEXT,
                      DoubleToString(g_swingHighs[0].price, g_digits));

   if(g_swingLowCount > 0)
      ObjectSetString(0, g_panelName + "_sl_value", OBJPROP_TEXT,
                      DoubleToString(g_swingLows[0].price, g_digits));

   // Update Structure
   string structText = TrendBiasToString(g_currentStructure);
   color structColor = clrGray;
   if(g_currentStructure == BIAS_BULLISH) structColor = clrLimeGreen;
   else if(g_currentStructure == BIAS_BEARISH) structColor = clrRed;

   ObjectSetString(0, g_panelName + "_struct_value", OBJPROP_TEXT, structText);
   ObjectSetInteger(0, g_panelName + "_struct_value", OBJPROP_COLOR, structColor);

   // Update BOS
   if(g_hasBOS)
   {
      string bosText = (g_lastBOS.direction == BIAS_BULLISH ? "BULLISH ↑" : "BEARISH ↓");
      if(!g_lastBOS.confirmed) bosText += " (?)";
      color bosColor = (g_lastBOS.direction == BIAS_BULLISH) ? clrLimeGreen : clrRed;

      ObjectSetString(0, g_panelName + "_bos_value", OBJPROP_TEXT, bosText);
      ObjectSetInteger(0, g_panelName + "_bos_value", OBJPROP_COLOR, bosColor);
   }
   else
   {
      ObjectSetString(0, g_panelName + "_bos_value", OBJPROP_TEXT, "None");
      ObjectSetInteger(0, g_panelName + "_bos_value", OBJPROP_COLOR, clrGray);
   }

   // Update CHoCH
   if(g_hasCHoCH)
   {
      string chochText = "REVERSAL " + (g_lastCHoCH.direction == BIAS_BULLISH ? "↑" : "↓");
      ObjectSetString(0, g_panelName + "_choch_value", OBJPROP_TEXT, chochText);
      ObjectSetInteger(0, g_panelName + "_choch_value", OBJPROP_COLOR, clrMagenta);
   }
   else
   {
      ObjectSetString(0, g_panelName + "_choch_value", OBJPROP_TEXT, "None");
      ObjectSetInteger(0, g_panelName + "_choch_value", OBJPROP_COLOR, clrGray);
   }

   // Update Recommendation
   string recText = "";
   color recColor = clrGray;

   if(InpUseATRFilter && !g_atrResult.tradingAllowed)
   {
      recText = "NO TRADE (ATR)";
      recColor = clrGray;
   }
   else if(g_hasCHoCH)
   {
      recText = "CAUTION - CHoCH!";
      recColor = clrMagenta;
   }
   else if(g_currentStructure == BIAS_BULLISH)
   {
      recText = "LOOK FOR BUYS";
      recColor = clrLimeGreen;
   }
   else if(g_currentStructure == BIAS_BEARISH)
   {
      recText = "LOOK FOR SELLS";
      recColor = clrRed;
   }
   else
   {
      recText = "WAIT";
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
ENUM_TREND_BIAS GetCurrentStructure() { return g_currentStructure; }
bool HasBOS() { return g_hasBOS; }
bool HasCHoCH() { return g_hasCHoCH; }
StructureBreak GetLastBOS() { return g_lastBOS; }
StructureBreak GetLastCHoCH() { return g_lastCHoCH; }
int GetSwingHighCount() { return g_swingHighCount; }
int GetSwingLowCount() { return g_swingLowCount; }
//+------------------------------------------------------------------+
