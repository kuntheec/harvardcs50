//+------------------------------------------------------------------+
//|                                       Section10_MTFAnalysis.mq5 |
//|                                      SwingTrader Pro EA          |
//|                    Section 10: Multi-Timeframe Analysis          |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "2.00"
#property description "Section 10: Multi-Timeframe Analysis v2.00"
#property description "SMC-Enhanced MTF with dynamic weighting"
#property description "Divergence penalty, stacked bias, ATR integration"

//+------------------------------------------------------------------+
//| Modification History                                              |
//+------------------------------------------------------------------+
// 2025.12.25 v2.00 - Major SMC enhancement based on Grok review:
//                    - RSI levels: 60/40 → 70/30 (industry standard)
//                    - Added instrument auto-detection (Gold/Forex)
//                    - Dynamic RSI levels for volatile instruments
//                    - Divergence penalty for conflicting TFs
//                    - Stacked bias requirement (D1 must lead)
//                    - ATR-based dynamic weighting
//                    - Error handling with retries for indicators
// 2025.12.23 v1.00 - Initial release with basic MTF analysis

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES InpTF_Entry     = PERIOD_H1;  // Entry Timeframe
input ENUM_TIMEFRAMES InpTF_Medium    = PERIOD_H4;  // Medium Timeframe
input ENUM_TIMEFRAMES InpTF_Higher    = PERIOD_D1;  // Higher Timeframe
input bool     InpUseWeekly           = false;      // Also Check Weekly

input group "=== EMA Settings ==="
input int      InpEMAFast             = 50;         // Fast EMA Period
input int      InpEMASlow             = 200;        // Slow EMA Period

input group "=== RSI Settings ==="
input int      InpRSIPeriod           = 14;         // RSI Period
input int      InpRSIUpper            = 70;         // RSI Upper Level (overbought)
input int      InpRSILower            = 30;         // RSI Lower Level (oversold)
input bool     InpDynamicRSI          = true;       // Auto-adjust RSI for Gold (wider levels)

input group "=== SMC Enhancement Settings ==="
input bool     InpUseDivergencePenalty = true;      // Penalize Conflicting TFs
input int      InpDivergencePenalty    = 20;        // Penalty Score for Divergence
input bool     InpRequireStackedBias   = true;      // Require D1→H4→H1 Sequential Alignment
input bool     InpUseATRWeighting      = true;      // Dynamic EMA/RSI Weights by Volatility

input group "=== ATR Settings (for Dynamic Weighting) ==="
input ENUM_TIMEFRAMES InpATRTimeframe  = PERIOD_D1; // ATR Timeframe
input int      InpATRPeriod            = 14;        // ATR Period
input double   InpLowVolATRRatio       = 0.7;       // Low Volatility Threshold (vs avg)
input double   InpHighVolATRRatio      = 1.3;       // High Volatility Threshold (vs avg)

input group "=== Confluence Settings ==="
input int      InpMinConfluence       = 2;          // Minimum TF Confluence (1-4)
input bool     InpRequireHigherTF     = true;       // Require Higher TF Alignment
input int      InpConfluenceWeight    = 25;         // Weight per Aligned TF (%)

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;       // Show Info Panel
input color    InpBullishColor        = clrLimeGreen; // Bullish Color
input color    InpBearishColor        = clrRed;     // Bearish Color
input color    InpNeutralColor        = clrGray;    // Neutral Color
input int      InpPanelX              = 20;         // Panel X Position
input int      InpPanelY              = 30;         // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;       // Print Report to Experts Tab

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_TF_BIAS
{
   TF_STRONG_BULLISH,       // Strong bullish (EMA + RSI aligned)
   TF_BULLISH,              // Bullish (price above EMAs)
   TF_WEAK_BULLISH,         // Weak bullish
   TF_NEUTRAL,              // Neutral
   TF_WEAK_BEARISH,         // Weak bearish
   TF_BEARISH,              // Bearish (price below EMAs)
   TF_STRONG_BEARISH        // Strong bearish (EMA + RSI aligned)
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct TimeframeBias
{
   ENUM_TIMEFRAMES   timeframe;
   ENUM_TF_BIAS      bias;
   double            emaFast;
   double            emaSlow;
   double            rsi;
   bool              priceAboveEMAFast;
   bool              priceAboveEMASlow;
   bool              emaFastAboveSlow;
   bool              rsiBullish;
   bool              rsiBearish;
   int               biasScore;       // -100 to +100
   datetime          lastUpdate;
};

struct MTFAnalysis
{
   TimeframeBias     entryTF;
   TimeframeBias     mediumTF;
   TimeframeBias     higherTF;
   TimeframeBias     weeklyTF;
   int               bullishCount;    // TFs showing bullish
   int               bearishCount;    // TFs showing bearish
   int               confluenceScore; // Overall confluence (0-100)
   ENUM_TREND_BIAS   overallBias;     // Combined bias
   bool              confluenceMet;   // Min confluence achieved
   bool              higherTFAligned; // Higher TF confirms direction
   // v2.00 SMC enhancements
   bool              hasDivergence;   // TFs are conflicting
   int               divergencePenalty; // Applied penalty
   bool              stackedBiasOK;   // D1→H4→H1 sequential alignment
   double            currentATR;      // Current ATR value
   double            averageATR;      // Average ATR for comparison
   double            volatilityRatio; // Current/Average ATR
   int               emaWeight;       // Dynamic EMA weight (%)
   int               rsiWeight;       // Dynamic RSI weight (%)
   string            instrumentType;  // GOLD, FOREX, etc.
   int               effectiveRSIUpper; // Adjusted RSI upper (for Gold)
   int               effectiveRSILower; // Adjusted RSI lower (for Gold)
   string            recommendation;
   datetime          lastUpdate;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
// Indicator handles - Entry TF
int               g_emaFastHandle_Entry;
int               g_emaSlowHandle_Entry;
int               g_rsiHandle_Entry;

// Indicator handles - Medium TF
int               g_emaFastHandle_Medium;
int               g_emaSlowHandle_Medium;
int               g_rsiHandle_Medium;

// Indicator handles - Higher TF
int               g_emaFastHandle_Higher;
int               g_emaSlowHandle_Higher;
int               g_rsiHandle_Higher;

// Indicator handles - Weekly TF
int               g_emaFastHandle_Weekly;
int               g_emaSlowHandle_Weekly;
int               g_rsiHandle_Weekly;

// ATR handle for dynamic weighting
int               g_atrHandle;

// Buffers
double            g_buffer[];
double            g_atrBuffer[];

// Symbol info for auto-detection
SymbolInfoCache   g_symbolInfo;

// Analysis result
MTFAnalysis       g_analysis;

// Panel
string            g_panelName = "MTFPanel";

// Symbol info
int               g_digits;
double            g_point;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get symbol info
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Initialize SymbolInfoCache for auto-detection
   InitSymbolInfo(g_symbolInfo, _Symbol);

   // Set instrument type
   if(g_symbolInfo.isGold)
      g_analysis.instrumentType = "GOLD";
   else if(g_symbolInfo.isSilver)
      g_analysis.instrumentType = "SILVER";
   else if(g_symbolInfo.isJPY)
      g_analysis.instrumentType = "JPY";
   else
      g_analysis.instrumentType = "FOREX";

   // Set effective RSI levels (wider for volatile instruments like Gold)
   if(InpDynamicRSI && g_symbolInfo.isGold)
   {
      g_analysis.effectiveRSIUpper = 75;  // Gold: wider range due to volatility
      g_analysis.effectiveRSILower = 25;
      Print("AUTO-DETECT: Gold pair - using wider RSI levels (75/25)");
   }
   else if(InpDynamicRSI && g_symbolInfo.isSilver)
   {
      g_analysis.effectiveRSIUpper = 73;
      g_analysis.effectiveRSILower = 27;
      Print("AUTO-DETECT: Silver pair - using wider RSI levels (73/27)");
   }
   else
   {
      g_analysis.effectiveRSIUpper = InpRSIUpper;
      g_analysis.effectiveRSILower = InpRSILower;
   }

   // Initialize default weights (will be adjusted dynamically if ATR enabled)
   g_analysis.emaWeight = 70;
   g_analysis.rsiWeight = 30;

   // Initialize buffers
   ArraySetAsSeries(g_buffer, true);
   ArraySetAsSeries(g_atrBuffer, true);

   // Create indicator handles for Entry TF
   g_emaFastHandle_Entry = iMA(_Symbol, InpTF_Entry, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHandle_Entry = iMA(_Symbol, InpTF_Entry, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiHandle_Entry = iRSI(_Symbol, InpTF_Entry, InpRSIPeriod, PRICE_CLOSE);

   if(g_emaFastHandle_Entry == INVALID_HANDLE ||
      g_emaSlowHandle_Entry == INVALID_HANDLE ||
      g_rsiHandle_Entry == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create Entry TF indicators");
      return(INIT_FAILED);
   }

   // Create indicator handles for Medium TF
   g_emaFastHandle_Medium = iMA(_Symbol, InpTF_Medium, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHandle_Medium = iMA(_Symbol, InpTF_Medium, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiHandle_Medium = iRSI(_Symbol, InpTF_Medium, InpRSIPeriod, PRICE_CLOSE);

   if(g_emaFastHandle_Medium == INVALID_HANDLE ||
      g_emaSlowHandle_Medium == INVALID_HANDLE ||
      g_rsiHandle_Medium == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create Medium TF indicators");
      return(INIT_FAILED);
   }

   // Create indicator handles for Higher TF
   g_emaFastHandle_Higher = iMA(_Symbol, InpTF_Higher, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHandle_Higher = iMA(_Symbol, InpTF_Higher, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_rsiHandle_Higher = iRSI(_Symbol, InpTF_Higher, InpRSIPeriod, PRICE_CLOSE);

   if(g_emaFastHandle_Higher == INVALID_HANDLE ||
      g_emaSlowHandle_Higher == INVALID_HANDLE ||
      g_rsiHandle_Higher == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create Higher TF indicators");
      return(INIT_FAILED);
   }

   // Create indicator handles for Weekly TF (optional)
   if(InpUseWeekly)
   {
      g_emaFastHandle_Weekly = iMA(_Symbol, PERIOD_W1, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
      g_emaSlowHandle_Weekly = iMA(_Symbol, PERIOD_W1, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
      g_rsiHandle_Weekly = iRSI(_Symbol, PERIOD_W1, InpRSIPeriod, PRICE_CLOSE);

      if(g_emaFastHandle_Weekly == INVALID_HANDLE ||
         g_emaSlowHandle_Weekly == INVALID_HANDLE ||
         g_rsiHandle_Weekly == INVALID_HANDLE)
      {
         Print("WARNING: Failed to create Weekly TF indicators");
      }
   }

   // Create ATR handle for dynamic weighting
   if(InpUseATRWeighting)
   {
      g_atrHandle = iATR(_Symbol, InpATRTimeframe, InpATRPeriod);
      if(g_atrHandle == INVALID_HANDLE)
      {
         Print("WARNING: Failed to create ATR indicator - using default weights");
      }
   }

   // Print initialization
   PrintInitReport();

   // Create panel
   if(InpShowPanel)
      CreatePanel();

   // Run initial analysis
   AnalyzeMTF();

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
   if(g_emaFastHandle_Entry != INVALID_HANDLE) IndicatorRelease(g_emaFastHandle_Entry);
   if(g_emaSlowHandle_Entry != INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle_Entry);
   if(g_rsiHandle_Entry != INVALID_HANDLE) IndicatorRelease(g_rsiHandle_Entry);

   if(g_emaFastHandle_Medium != INVALID_HANDLE) IndicatorRelease(g_emaFastHandle_Medium);
   if(g_emaSlowHandle_Medium != INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle_Medium);
   if(g_rsiHandle_Medium != INVALID_HANDLE) IndicatorRelease(g_rsiHandle_Medium);

   if(g_emaFastHandle_Higher != INVALID_HANDLE) IndicatorRelease(g_emaFastHandle_Higher);
   if(g_emaSlowHandle_Higher != INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle_Higher);
   if(g_rsiHandle_Higher != INVALID_HANDLE) IndicatorRelease(g_rsiHandle_Higher);

   if(InpUseWeekly)
   {
      if(g_emaFastHandle_Weekly != INVALID_HANDLE) IndicatorRelease(g_emaFastHandle_Weekly);
      if(g_emaSlowHandle_Weekly != INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle_Weekly);
      if(g_rsiHandle_Weekly != INVALID_HANDLE) IndicatorRelease(g_rsiHandle_Weekly);
   }

   // Release ATR handle
   if(InpUseATRWeighting && g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);

   // Remove panel
   DeletePanel();

   Print("=================================================");
   Print("MTF Analysis EA Deinitialized");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpTF_Entry, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      AnalyzeMTF();

      if(InpShowPanel) UpdatePanel();
   }
}

//+------------------------------------------------------------------+
//| Main MTF Analysis Function                                        |
//+------------------------------------------------------------------+
void AnalyzeMTF()
{
   // Update ATR and dynamic weights first
   if(InpUseATRWeighting)
      UpdateATRWeights();

   // Analyze each timeframe
   AnalyzeTimeframe(g_analysis.entryTF, InpTF_Entry,
                    g_emaFastHandle_Entry, g_emaSlowHandle_Entry, g_rsiHandle_Entry);

   AnalyzeTimeframe(g_analysis.mediumTF, InpTF_Medium,
                    g_emaFastHandle_Medium, g_emaSlowHandle_Medium, g_rsiHandle_Medium);

   AnalyzeTimeframe(g_analysis.higherTF, InpTF_Higher,
                    g_emaFastHandle_Higher, g_emaSlowHandle_Higher, g_rsiHandle_Higher);

   if(InpUseWeekly)
   {
      AnalyzeTimeframe(g_analysis.weeklyTF, PERIOD_W1,
                       g_emaFastHandle_Weekly, g_emaSlowHandle_Weekly, g_rsiHandle_Weekly);
   }

   // Check for divergence (conflicting TFs)
   CheckDivergence();

   // Check stacked bias (D1→H4→H1 alignment)
   CheckStackedBias();

   // Calculate confluence
   CalculateConfluence();

   // Generate recommendation
   GenerateRecommendation();

   g_analysis.lastUpdate = TimeCurrent();

   // Print report
   if(InpPrintReport)
      PrintMTFReport();
}

//+------------------------------------------------------------------+
//| Update ATR and Dynamic Weights                                    |
//+------------------------------------------------------------------+
void UpdateATRWeights()
{
   if(g_atrHandle == INVALID_HANDLE)
   {
      g_analysis.emaWeight = 70;
      g_analysis.rsiWeight = 30;
      return;
   }

   // Get current ATR
   if(CopyBuffer(g_atrHandle, 0, 0, 1, g_atrBuffer) < 1)
   {
      g_analysis.emaWeight = 70;
      g_analysis.rsiWeight = 30;
      return;
   }
   g_analysis.currentATR = g_atrBuffer[0];

   // Get average ATR (last 20 periods)
   double atrSum = 0;
   if(CopyBuffer(g_atrHandle, 0, 0, 20, g_atrBuffer) >= 20)
   {
      for(int i = 0; i < 20; i++)
         atrSum += g_atrBuffer[i];
      g_analysis.averageATR = atrSum / 20.0;
   }
   else
   {
      g_analysis.averageATR = g_analysis.currentATR;
   }

   // Calculate volatility ratio
   if(g_analysis.averageATR > 0)
      g_analysis.volatilityRatio = g_analysis.currentATR / g_analysis.averageATR;
   else
      g_analysis.volatilityRatio = 1.0;

   // Adjust weights based on volatility
   // High volatility → more weight on EMA (trend following)
   // Low volatility → more weight on RSI (mean reversion)
   if(g_analysis.volatilityRatio >= InpHighVolATRRatio)
   {
      // High volatility: favor EMA
      g_analysis.emaWeight = 80;
      g_analysis.rsiWeight = 20;
   }
   else if(g_analysis.volatilityRatio <= InpLowVolATRRatio)
   {
      // Low volatility: favor RSI
      g_analysis.emaWeight = 60;
      g_analysis.rsiWeight = 40;
   }
   else
   {
      // Normal volatility: default weights
      g_analysis.emaWeight = 70;
      g_analysis.rsiWeight = 30;
   }
}

//+------------------------------------------------------------------+
//| Check for Divergence (Conflicting TFs)                            |
//+------------------------------------------------------------------+
void CheckDivergence()
{
   g_analysis.hasDivergence = false;
   g_analysis.divergencePenalty = 0;

   if(!InpUseDivergencePenalty)
      return;

   // Check if Higher TF conflicts with Entry TF (major divergence)
   bool higherBullish = (g_analysis.higherTF.biasScore > 20);
   bool higherBearish = (g_analysis.higherTF.biasScore < -20);
   bool entryBullish = (g_analysis.entryTF.biasScore > 20);
   bool entryBearish = (g_analysis.entryTF.biasScore < -20);

   // Higher TF bullish but Entry bearish = divergence (trap warning)
   if((higherBullish && entryBearish) || (higherBearish && entryBullish))
   {
      g_analysis.hasDivergence = true;
      g_analysis.divergencePenalty = InpDivergencePenalty;
   }

   // Also check Medium TF for secondary divergence
   bool mediumBullish = (g_analysis.mediumTF.biasScore > 20);
   bool mediumBearish = (g_analysis.mediumTF.biasScore < -20);

   if((higherBullish && mediumBearish) || (higherBearish && mediumBullish))
   {
      g_analysis.hasDivergence = true;
      g_analysis.divergencePenalty = MathMax(g_analysis.divergencePenalty, InpDivergencePenalty / 2);
   }
}

//+------------------------------------------------------------------+
//| Check Stacked Bias (D1 → H4 → H1 Sequential Alignment)            |
//+------------------------------------------------------------------+
void CheckStackedBias()
{
   g_analysis.stackedBiasOK = true;

   if(!InpRequireStackedBias)
      return;

   // For bullish setup: D1 must be bullish, then H4, then H1
   // For bearish setup: D1 must be bearish, then H4, then H1
   // The bias should "flow" from higher to lower TF

   bool higherBullish = (g_analysis.higherTF.biasScore > 0);
   bool higherBearish = (g_analysis.higherTF.biasScore < 0);
   bool mediumBullish = (g_analysis.mediumTF.biasScore > 0);
   bool mediumBearish = (g_analysis.mediumTF.biasScore < 0);
   bool entryBullish = (g_analysis.entryTF.biasScore > 0);
   bool entryBearish = (g_analysis.entryTF.biasScore < 0);

   // Check bullish stacking
   if(entryBullish)
   {
      // For bullish entry, higher TFs should also be bullish or neutral
      if(higherBearish || mediumBearish)
         g_analysis.stackedBiasOK = false;
   }
   // Check bearish stacking
   else if(entryBearish)
   {
      // For bearish entry, higher TFs should also be bearish or neutral
      if(higherBullish || mediumBullish)
         g_analysis.stackedBiasOK = false;
   }
   // Neutral entry is always OK
}

//+------------------------------------------------------------------+
//| Copy Buffer with Retry Logic                                      |
//+------------------------------------------------------------------+
bool CopyBufferWithRetry(int handle, int bufferIndex, int startPos, int count, double &buffer[], int maxRetries = 3)
{
   for(int attempt = 0; attempt < maxRetries; attempt++)
   {
      if(CopyBuffer(handle, bufferIndex, startPos, count, buffer) >= count)
         return true;

      if(attempt < maxRetries - 1)
         Sleep(50);  // Brief pause before retry
   }
   return false;
}

//+------------------------------------------------------------------+
//| Analyze Single Timeframe                                          |
//+------------------------------------------------------------------+
void AnalyzeTimeframe(TimeframeBias &tf, ENUM_TIMEFRAMES timeframe,
                      int emaFastHandle, int emaSlowHandle, int rsiHandle)
{
   tf.timeframe = timeframe;
   tf.lastUpdate = TimeCurrent();

   // Get current price
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Get EMA values with retry logic
   if(!CopyBufferWithRetry(emaFastHandle, 0, 0, 1, g_buffer))
   {
      Print("ERROR: Failed to copy EMA Fast for ", TimeframeToString(timeframe), " after retries");
      return;
   }
   tf.emaFast = g_buffer[0];

   if(!CopyBufferWithRetry(emaSlowHandle, 0, 0, 1, g_buffer))
   {
      Print("ERROR: Failed to copy EMA Slow for ", TimeframeToString(timeframe), " after retries");
      return;
   }
   tf.emaSlow = g_buffer[0];

   // Get RSI with retry logic
   if(!CopyBufferWithRetry(rsiHandle, 0, 0, 1, g_buffer))
   {
      Print("ERROR: Failed to copy RSI for ", TimeframeToString(timeframe), " after retries");
      return;
   }
   tf.rsi = g_buffer[0];

   // Analyze position relative to EMAs
   tf.priceAboveEMAFast = (currentPrice > tf.emaFast);
   tf.priceAboveEMASlow = (currentPrice > tf.emaSlow);
   tf.emaFastAboveSlow = (tf.emaFast > tf.emaSlow);

   // Analyze RSI using effective (dynamic) levels
   tf.rsiBullish = (tf.rsi > g_analysis.effectiveRSIUpper);
   tf.rsiBearish = (tf.rsi < g_analysis.effectiveRSILower);

   // Calculate bias score using dynamic weights
   tf.biasScore = 0;

   // EMA component (dynamic weight from ATR analysis)
   int emaMaxPoints = g_analysis.emaWeight;  // Dynamic: 60-80 based on volatility

   // Price position relative to EMAs
   if(tf.priceAboveEMAFast && tf.priceAboveEMASlow)
      tf.biasScore += (emaMaxPoints * 60) / 100;  // 60% of EMA weight
   else if(!tf.priceAboveEMAFast && !tf.priceAboveEMASlow)
      tf.biasScore -= (emaMaxPoints * 60) / 100;
   else if(tf.priceAboveEMAFast)
      tf.biasScore += (emaMaxPoints * 15) / 100;
   else if(tf.priceAboveEMASlow)
      tf.biasScore += (emaMaxPoints * 10) / 100;
   else
      tf.biasScore -= (emaMaxPoints * 15) / 100;

   // EMA alignment
   if(tf.emaFastAboveSlow)
      tf.biasScore += (emaMaxPoints * 40) / 100;  // 40% of EMA weight
   else
      tf.biasScore -= (emaMaxPoints * 40) / 100;

   // RSI component (dynamic weight from ATR analysis)
   int rsiMaxPoints = g_analysis.rsiWeight;  // Dynamic: 20-40 based on volatility

   if(tf.rsiBullish)
      tf.biasScore += rsiMaxPoints;
   else if(tf.rsiBearish)
      tf.biasScore -= rsiMaxPoints;
   else if(tf.rsi > 50)
      tf.biasScore += (rsiMaxPoints * 30) / 100;  // 30% of RSI weight
   else
      tf.biasScore -= (rsiMaxPoints * 30) / 100;

   // Determine bias
   if(tf.biasScore >= 70)
      tf.bias = TF_STRONG_BULLISH;
   else if(tf.biasScore >= 40)
      tf.bias = TF_BULLISH;
   else if(tf.biasScore >= 10)
      tf.bias = TF_WEAK_BULLISH;
   else if(tf.biasScore <= -70)
      tf.bias = TF_STRONG_BEARISH;
   else if(tf.biasScore <= -40)
      tf.bias = TF_BEARISH;
   else if(tf.biasScore <= -10)
      tf.bias = TF_WEAK_BEARISH;
   else
      tf.bias = TF_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Calculate Confluence                                              |
//+------------------------------------------------------------------+
void CalculateConfluence()
{
   g_analysis.bullishCount = 0;
   g_analysis.bearishCount = 0;

   // Count bullish/bearish timeframes
   int tfCount = InpUseWeekly ? 4 : 3;

   // Entry TF
   if(g_analysis.entryTF.biasScore > 20)
      g_analysis.bullishCount++;
   else if(g_analysis.entryTF.biasScore < -20)
      g_analysis.bearishCount++;

   // Medium TF
   if(g_analysis.mediumTF.biasScore > 20)
      g_analysis.bullishCount++;
   else if(g_analysis.mediumTF.biasScore < -20)
      g_analysis.bearishCount++;

   // Higher TF
   if(g_analysis.higherTF.biasScore > 20)
      g_analysis.bullishCount++;
   else if(g_analysis.higherTF.biasScore < -20)
      g_analysis.bearishCount++;

   // Weekly TF
   if(InpUseWeekly)
   {
      if(g_analysis.weeklyTF.biasScore > 20)
         g_analysis.bullishCount++;
      else if(g_analysis.weeklyTF.biasScore < -20)
         g_analysis.bearishCount++;
   }

   // Check higher TF alignment
   g_analysis.higherTFAligned = false;
   if(g_analysis.higherTF.biasScore > 0)
      g_analysis.higherTFAligned = (g_analysis.entryTF.biasScore > 0);
   else if(g_analysis.higherTF.biasScore < 0)
      g_analysis.higherTFAligned = (g_analysis.entryTF.biasScore < 0);
   else
      g_analysis.higherTFAligned = true;  // Neutral is always aligned

   // Calculate confluence score
   int maxScore = tfCount * InpConfluenceWeight;

   if(g_analysis.bullishCount > g_analysis.bearishCount)
   {
      g_analysis.confluenceScore = (g_analysis.bullishCount * InpConfluenceWeight * 100) / maxScore;
      g_analysis.overallBias = BIAS_BULLISH;
   }
   else if(g_analysis.bearishCount > g_analysis.bullishCount)
   {
      g_analysis.confluenceScore = (g_analysis.bearishCount * InpConfluenceWeight * 100) / maxScore;
      g_analysis.overallBias = BIAS_BEARISH;
   }
   else
   {
      g_analysis.confluenceScore = 50;
      g_analysis.overallBias = BIAS_NEUTRAL;
   }

   // Cap at 100
   if(g_analysis.confluenceScore > 100)
      g_analysis.confluenceScore = 100;

   // Apply divergence penalty
   if(g_analysis.hasDivergence && g_analysis.divergencePenalty > 0)
   {
      g_analysis.confluenceScore -= g_analysis.divergencePenalty;
      if(g_analysis.confluenceScore < 0)
         g_analysis.confluenceScore = 0;
   }

   // Check if minimum confluence is met
   int alignedCount = MathMax(g_analysis.bullishCount, g_analysis.bearishCount);
   g_analysis.confluenceMet = (alignedCount >= InpMinConfluence);

   // Apply higher TF requirement
   if(InpRequireHigherTF && !g_analysis.higherTFAligned)
      g_analysis.confluenceMet = false;

   // Apply stacked bias requirement
   if(InpRequireStackedBias && !g_analysis.stackedBiasOK)
      g_analysis.confluenceMet = false;
}

//+------------------------------------------------------------------+
//| Generate Recommendation                                           |
//+------------------------------------------------------------------+
void GenerateRecommendation()
{
   string rec = "";

   // Check for blocking conditions first
   if(!g_analysis.confluenceMet)
   {
      if(InpRequireStackedBias && !g_analysis.stackedBiasOK)
         rec = "NO TRADE - Stacked bias broken (TFs not sequential)";
      else if(InpRequireHigherTF && !g_analysis.higherTFAligned)
         rec = "NO TRADE - Higher TF not aligned";
      else
         rec = "NO TRADE - Insufficient TF confluence";
   }
   else if(g_analysis.hasDivergence)
   {
      // Trade allowed but with warning
      if(g_analysis.overallBias == BIAS_BULLISH)
         rec = "CAUTION BUY - TF divergence detected";
      else if(g_analysis.overallBias == BIAS_BEARISH)
         rec = "CAUTION SELL - TF divergence detected";
      else
         rec = "WAIT - Conflicting TF signals";
   }
   else if(g_analysis.overallBias == BIAS_BULLISH)
   {
      if(g_analysis.bullishCount >= 3)
         rec = "STRONG BUY - Multiple TF bullish confluence";
      else
         rec = "BUY - Bullish TF alignment";
   }
   else if(g_analysis.overallBias == BIAS_BEARISH)
   {
      if(g_analysis.bearishCount >= 3)
         rec = "STRONG SELL - Multiple TF bearish confluence";
      else
         rec = "SELL - Bearish TF alignment";
   }
   else
   {
      rec = "WAIT - Neutral TF consensus";
   }

   // Add status indicators
   if(g_analysis.confluenceMet)
   {
      if(g_analysis.higherTFAligned)
         rec += " [HTF]";
      if(g_analysis.stackedBiasOK)
         rec += " [STK]";
   }

   g_analysis.recommendation = rec;
}

//+------------------------------------------------------------------+
//| Convert TF Bias to String                                         |
//+------------------------------------------------------------------+
string TFBiasToString(ENUM_TF_BIAS bias)
{
   switch(bias)
   {
      case TF_STRONG_BULLISH:  return "STRONG BULL";
      case TF_BULLISH:         return "BULLISH";
      case TF_WEAK_BULLISH:    return "Weak Bull";
      case TF_NEUTRAL:         return "NEUTRAL";
      case TF_WEAK_BEARISH:    return "Weak Bear";
      case TF_BEARISH:         return "BEARISH";
      case TF_STRONG_BEARISH:  return "STRONG BEAR";
      default:                 return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Get color for bias                                                |
//+------------------------------------------------------------------+
color GetBiasColor(ENUM_TF_BIAS bias)
{
   switch(bias)
   {
      case TF_STRONG_BULLISH:
      case TF_BULLISH:
      case TF_WEAK_BULLISH:
         return InpBullishColor;
      case TF_STRONG_BEARISH:
      case TF_BEARISH:
      case TF_WEAK_BEARISH:
         return InpBearishColor;
      default:
         return InpNeutralColor;
   }
}

//+------------------------------------------------------------------+
//| Print MTF Report                                                  |
//+------------------------------------------------------------------+
void PrintMTFReport()
{
   Print("");
   Print("=================================================");
   Print("     MULTI-TIMEFRAME ANALYSIS (Section 10 v2.00) ");
   Print("=================================================");
   Print("Symbol: ", _Symbol, " (", g_analysis.instrumentType, ")");
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Current Price: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), g_digits));
   Print("-------------------------------------------------");

   // Entry TF
   Print("ENTRY TF (", TimeframeToString(InpTF_Entry), "):");
   Print("  Bias: ", TFBiasToString(g_analysis.entryTF.bias), " (Score: ", g_analysis.entryTF.biasScore, ")");
   Print("  EMA", InpEMAFast, ": ", DoubleToString(g_analysis.entryTF.emaFast, g_digits));
   Print("  EMA", InpEMASlow, ": ", DoubleToString(g_analysis.entryTF.emaSlow, g_digits));
   Print("  RSI: ", DoubleToString(g_analysis.entryTF.rsi, 2),
         " [", g_analysis.effectiveRSILower, "/", g_analysis.effectiveRSIUpper, "]");
   Print("-------------------------------------------------");

   // Medium TF
   Print("MEDIUM TF (", TimeframeToString(InpTF_Medium), "):");
   Print("  Bias: ", TFBiasToString(g_analysis.mediumTF.bias), " (Score: ", g_analysis.mediumTF.biasScore, ")");
   Print("  EMA", InpEMAFast, ": ", DoubleToString(g_analysis.mediumTF.emaFast, g_digits));
   Print("  EMA", InpEMASlow, ": ", DoubleToString(g_analysis.mediumTF.emaSlow, g_digits));
   Print("  RSI: ", DoubleToString(g_analysis.mediumTF.rsi, 2));
   Print("-------------------------------------------------");

   // Higher TF
   Print("HIGHER TF (", TimeframeToString(InpTF_Higher), "):");
   Print("  Bias: ", TFBiasToString(g_analysis.higherTF.bias), " (Score: ", g_analysis.higherTF.biasScore, ")");
   Print("  EMA", InpEMAFast, ": ", DoubleToString(g_analysis.higherTF.emaFast, g_digits));
   Print("  EMA", InpEMASlow, ": ", DoubleToString(g_analysis.higherTF.emaSlow, g_digits));
   Print("  RSI: ", DoubleToString(g_analysis.higherTF.rsi, 2));
   Print("-------------------------------------------------");

   // Weekly TF
   if(InpUseWeekly)
   {
      Print("WEEKLY TF:");
      Print("  Bias: ", TFBiasToString(g_analysis.weeklyTF.bias), " (Score: ", g_analysis.weeklyTF.biasScore, ")");
      Print("  RSI: ", DoubleToString(g_analysis.weeklyTF.rsi, 2));
      Print("-------------------------------------------------");
   }

   // SMC Analysis (v2.00)
   Print("SMC ANALYSIS:");
   if(InpUseATRWeighting)
   {
      Print("  Current ATR: ", DoubleToString(g_analysis.currentATR, g_digits));
      Print("  Average ATR: ", DoubleToString(g_analysis.averageATR, g_digits));
      Print("  Volatility: ", DoubleToString(g_analysis.volatilityRatio, 2), "x");
      Print("  Dynamic Weights: EMA ", g_analysis.emaWeight, "% / RSI ", g_analysis.rsiWeight, "%");
   }
   Print("  Divergence: ", g_analysis.hasDivergence ? "YES (penalty: -" + IntegerToString(g_analysis.divergencePenalty) + ")" : "NO");
   Print("  Stacked Bias: ", g_analysis.stackedBiasOK ? "OK (D1→H4→H1)" : "BROKEN");
   Print("-------------------------------------------------");

   // Confluence Summary
   Print("CONFLUENCE SUMMARY:");
   Print("  Bullish TFs: ", g_analysis.bullishCount);
   Print("  Bearish TFs: ", g_analysis.bearishCount);
   Print("  Confluence Score: ", g_analysis.confluenceScore, "%");
   Print("  Min Confluence Met: ", g_analysis.confluenceMet ? "YES" : "NO");
   Print("  Higher TF Aligned: ", g_analysis.higherTFAligned ? "YES" : "NO");
   Print("  Overall Bias: ", TrendBiasToString(g_analysis.overallBias));
   Print("-------------------------------------------------");

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
   Print("     SWING TRADER PRO - SECTION 10 (v2.00)       ");
   Print("     MULTI-TIMEFRAME ANALYSIS                    ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol);
   Print("Instrument Type: ", g_analysis.instrumentType);
   Print("-------------------------------------------------");
   Print("TIMEFRAME SETTINGS:");
   Print("  Entry TF: ", TimeframeToString(InpTF_Entry));
   Print("  Medium TF: ", TimeframeToString(InpTF_Medium));
   Print("  Higher TF: ", TimeframeToString(InpTF_Higher));
   Print("  Weekly TF: ", InpUseWeekly ? "Enabled" : "Disabled");
   Print("-------------------------------------------------");
   Print("INDICATOR SETTINGS:");
   Print("  Fast EMA: ", InpEMAFast);
   Print("  Slow EMA: ", InpEMASlow);
   Print("  RSI Period: ", InpRSIPeriod);
   Print("  RSI Upper: ", g_analysis.effectiveRSIUpper, InpDynamicRSI ? " (dynamic)" : "");
   Print("  RSI Lower: ", g_analysis.effectiveRSILower, InpDynamicRSI ? " (dynamic)" : "");
   Print("-------------------------------------------------");
   Print("SMC ENHANCEMENT SETTINGS:");
   Print("  Divergence Penalty: ", InpUseDivergencePenalty ? "Enabled (-" + IntegerToString(InpDivergencePenalty) + " pts)" : "Disabled");
   Print("  Stacked Bias: ", InpRequireStackedBias ? "Required (D1→H4→H1)" : "Not Required");
   Print("  ATR Weighting: ", InpUseATRWeighting ? "Enabled" : "Disabled");
   if(InpUseATRWeighting)
   {
      Print("    ATR TF: ", TimeframeToString(InpATRTimeframe));
      Print("    Low Vol Threshold: ", DoubleToString(InpLowVolATRRatio, 2), "x");
      Print("    High Vol Threshold: ", DoubleToString(InpHighVolATRRatio, 2), "x");
   }
   Print("-------------------------------------------------");
   Print("CONFLUENCE SETTINGS:");
   Print("  Min Confluence: ", InpMinConfluence, " TFs");
   Print("  Require Higher TF: ", InpRequireHigherTF ? "Yes" : "No");
   Print("  Weight per TF: ", InpConfluenceWeight, "%");
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
   int height = InpUseWeekly ? 320 : 280;

   CreateRectangle(g_panelName + "_bg", x, y, 280, height, clrBlack, 200);

   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "MULTI-TIMEFRAME", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "-----------------------------", clrGray, 8, "Courier New");

   int yOff = 40;

   // Entry TF
   string tfStr = TimeframeToString(InpTF_Entry);
   CreateLabel(g_panelName + "_entry_label", x + 10, y + yOff, tfStr + ":", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_entry_bias", x + 100, y + yOff, "--", clrYellow, 9, "Arial Bold");
   CreateLabel(g_panelName + "_entry_score", x + 200, y + yOff, "(--)", clrGray, 8, "Arial");
   yOff += 20;

   // Medium TF
   tfStr = TimeframeToString(InpTF_Medium);
   CreateLabel(g_panelName + "_medium_label", x + 10, y + yOff, tfStr + ":", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_medium_bias", x + 100, y + yOff, "--", clrYellow, 9, "Arial Bold");
   CreateLabel(g_panelName + "_medium_score", x + 200, y + yOff, "(--)", clrGray, 8, "Arial");
   yOff += 20;

   // Higher TF
   tfStr = TimeframeToString(InpTF_Higher);
   CreateLabel(g_panelName + "_higher_label", x + 10, y + yOff, tfStr + ":", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_higher_bias", x + 100, y + yOff, "--", clrYellow, 9, "Arial Bold");
   CreateLabel(g_panelName + "_higher_score", x + 200, y + yOff, "(--)", clrGray, 8, "Arial");
   yOff += 20;

   // Weekly TF
   if(InpUseWeekly)
   {
      CreateLabel(g_panelName + "_weekly_label", x + 10, y + yOff, "W1:", clrWhite, 9, "Arial");
      CreateLabel(g_panelName + "_weekly_bias", x + 100, y + yOff, "--", clrYellow, 9, "Arial Bold");
      CreateLabel(g_panelName + "_weekly_score", x + 200, y + yOff, "(--)", clrGray, 8, "Arial");
      yOff += 20;
   }

   yOff += 5;
   CreateLabel(g_panelName + "_sep2", x + 10, y + yOff,
               "-----------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Confluence
   CreateLabel(g_panelName + "_conf_label", x + 10, y + yOff, "Confluence:", clrCyan, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_bull_label", x + 20, y + yOff, "Bullish TFs:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_bull_value", x + 120, y + yOff, "0", clrLimeGreen, 8, "Arial");
   yOff += 16;

   CreateLabel(g_panelName + "_bear_label", x + 20, y + yOff, "Bearish TFs:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_bear_value", x + 120, y + yOff, "0", clrRed, 8, "Arial");
   yOff += 16;

   CreateLabel(g_panelName + "_score_label", x + 20, y + yOff, "Score:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_score_value", x + 120, y + yOff, "--%", clrYellow, 8, "Arial");
   yOff += 20;

   // Status
   CreateLabel(g_panelName + "_htf_label", x + 10, y + yOff, "HTF Aligned:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_htf_value", x + 120, y + yOff, "--", clrYellow, 9, "Arial Bold");
   yOff += 20;

   CreateLabel(g_panelName + "_sep3", x + 10, y + yOff,
               "-----------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Recommendation
   CreateLabel(g_panelName + "_rec_label", x + 10, y + yOff, "Signal:", clrWhite, 10, "Arial Bold");
   CreateLabel(g_panelName + "_rec_value", x + 10, y + yOff + 18, "ANALYZING...", clrYellow, 9, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel) return;

   // Entry TF
   ObjectSetString(0, g_panelName + "_entry_bias", OBJPROP_TEXT, TFBiasToString(g_analysis.entryTF.bias));
   ObjectSetInteger(0, g_panelName + "_entry_bias", OBJPROP_COLOR, GetBiasColor(g_analysis.entryTF.bias));
   ObjectSetString(0, g_panelName + "_entry_score", OBJPROP_TEXT, "(" + IntegerToString(g_analysis.entryTF.biasScore) + ")");

   // Medium TF
   ObjectSetString(0, g_panelName + "_medium_bias", OBJPROP_TEXT, TFBiasToString(g_analysis.mediumTF.bias));
   ObjectSetInteger(0, g_panelName + "_medium_bias", OBJPROP_COLOR, GetBiasColor(g_analysis.mediumTF.bias));
   ObjectSetString(0, g_panelName + "_medium_score", OBJPROP_TEXT, "(" + IntegerToString(g_analysis.mediumTF.biasScore) + ")");

   // Higher TF
   ObjectSetString(0, g_panelName + "_higher_bias", OBJPROP_TEXT, TFBiasToString(g_analysis.higherTF.bias));
   ObjectSetInteger(0, g_panelName + "_higher_bias", OBJPROP_COLOR, GetBiasColor(g_analysis.higherTF.bias));
   ObjectSetString(0, g_panelName + "_higher_score", OBJPROP_TEXT, "(" + IntegerToString(g_analysis.higherTF.biasScore) + ")");

   // Weekly TF
   if(InpUseWeekly)
   {
      ObjectSetString(0, g_panelName + "_weekly_bias", OBJPROP_TEXT, TFBiasToString(g_analysis.weeklyTF.bias));
      ObjectSetInteger(0, g_panelName + "_weekly_bias", OBJPROP_COLOR, GetBiasColor(g_analysis.weeklyTF.bias));
      ObjectSetString(0, g_panelName + "_weekly_score", OBJPROP_TEXT, "(" + IntegerToString(g_analysis.weeklyTF.biasScore) + ")");
   }

   // Confluence
   ObjectSetString(0, g_panelName + "_bull_value", OBJPROP_TEXT, IntegerToString(g_analysis.bullishCount));
   ObjectSetString(0, g_panelName + "_bear_value", OBJPROP_TEXT, IntegerToString(g_analysis.bearishCount));
   ObjectSetString(0, g_panelName + "_score_value", OBJPROP_TEXT, IntegerToString(g_analysis.confluenceScore) + "%");

   // HTF Aligned
   string htfStr = g_analysis.higherTFAligned ? "YES" : "NO";
   color htfColor = g_analysis.higherTFAligned ? InpBullishColor : InpBearishColor;
   ObjectSetString(0, g_panelName + "_htf_value", OBJPROP_TEXT, htfStr);
   ObjectSetInteger(0, g_panelName + "_htf_value", OBJPROP_COLOR, htfColor);

   // Recommendation
   color recColor = InpNeutralColor;
   if(StringFind(g_analysis.recommendation, "BUY") >= 0)
      recColor = InpBullishColor;
   else if(StringFind(g_analysis.recommendation, "SELL") >= 0)
      recColor = InpBearishColor;

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
ENUM_TREND_BIAS GetMTFBias() { return g_analysis.overallBias; }
int GetConfluenceScore() { return g_analysis.confluenceScore; }
bool IsConfluenceMet() { return g_analysis.confluenceMet; }
bool IsHigherTFAligned() { return g_analysis.higherTFAligned; }
int GetBullishTFCount() { return g_analysis.bullishCount; }
int GetBearishTFCount() { return g_analysis.bearishCount; }
string GetMTFRecommendation() { return g_analysis.recommendation; }

// Get specific TF bias
ENUM_TF_BIAS GetEntryTFBias() { return g_analysis.entryTF.bias; }
ENUM_TF_BIAS GetMediumTFBias() { return g_analysis.mediumTF.bias; }
ENUM_TF_BIAS GetHigherTFBias() { return g_analysis.higherTF.bias; }
int GetEntryTFScore() { return g_analysis.entryTF.biasScore; }
int GetMediumTFScore() { return g_analysis.mediumTF.biasScore; }
int GetHigherTFScore() { return g_analysis.higherTF.biasScore; }
//+------------------------------------------------------------------+
