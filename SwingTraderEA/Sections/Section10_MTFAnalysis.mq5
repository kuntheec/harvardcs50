//+------------------------------------------------------------------+
//|                                       Section10_MTFAnalysis.mq5 |
//|                                      SwingTrader Pro EA          |
//|                    Section 10: Multi-Timeframe Analysis          |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.00"
#property description "Section 10: Multi-Timeframe Analysis"
#property description "Combines signals from multiple timeframes"
#property description "Higher timeframe trend confirmation"

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
input int      InpRSIUpper            = 60;         // RSI Upper Level
input int      InpRSILower            = 40;         // RSI Lower Level

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

// Buffers
double            g_buffer[];

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

   // Initialize buffer
   ArraySetAsSeries(g_buffer, true);

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
//| Analyze Single Timeframe                                          |
//+------------------------------------------------------------------+
void AnalyzeTimeframe(TimeframeBias &tf, ENUM_TIMEFRAMES timeframe,
                      int emaFastHandle, int emaSlowHandle, int rsiHandle)
{
   tf.timeframe = timeframe;
   tf.lastUpdate = TimeCurrent();

   // Get current price
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Get EMA values
   if(CopyBuffer(emaFastHandle, 0, 0, 1, g_buffer) < 1)
   {
      Print("WARNING: Failed to copy EMA Fast for ", TimeframeToString(timeframe));
      return;
   }
   tf.emaFast = g_buffer[0];

   if(CopyBuffer(emaSlowHandle, 0, 0, 1, g_buffer) < 1)
   {
      Print("WARNING: Failed to copy EMA Slow for ", TimeframeToString(timeframe));
      return;
   }
   tf.emaSlow = g_buffer[0];

   // Get RSI
   if(CopyBuffer(rsiHandle, 0, 0, 1, g_buffer) < 1)
   {
      Print("WARNING: Failed to copy RSI for ", TimeframeToString(timeframe));
      return;
   }
   tf.rsi = g_buffer[0];

   // Analyze position relative to EMAs
   tf.priceAboveEMAFast = (currentPrice > tf.emaFast);
   tf.priceAboveEMASlow = (currentPrice > tf.emaSlow);
   tf.emaFastAboveSlow = (tf.emaFast > tf.emaSlow);

   // Analyze RSI
   tf.rsiBullish = (tf.rsi > InpRSIUpper);
   tf.rsiBearish = (tf.rsi < InpRSILower);

   // Calculate bias score (-100 to +100)
   tf.biasScore = 0;

   // Price position relative to EMAs (40 points max)
   if(tf.priceAboveEMAFast && tf.priceAboveEMASlow)
      tf.biasScore += 40;
   else if(!tf.priceAboveEMAFast && !tf.priceAboveEMASlow)
      tf.biasScore -= 40;
   else if(tf.priceAboveEMAFast)
      tf.biasScore += 10;
   else if(tf.priceAboveEMASlow)
      tf.biasScore += 5;
   else
      tf.biasScore -= 10;

   // EMA alignment (30 points)
   if(tf.emaFastAboveSlow)
      tf.biasScore += 30;
   else
      tf.biasScore -= 30;

   // RSI (30 points)
   if(tf.rsiBullish)
      tf.biasScore += 30;
   else if(tf.rsiBearish)
      tf.biasScore -= 30;
   else if(tf.rsi > 50)
      tf.biasScore += 10;
   else
      tf.biasScore -= 10;

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

   // Check if minimum confluence is met
   int alignedCount = MathMax(g_analysis.bullishCount, g_analysis.bearishCount);
   g_analysis.confluenceMet = (alignedCount >= InpMinConfluence);

   // Apply higher TF requirement
   if(InpRequireHigherTF && !g_analysis.higherTFAligned)
      g_analysis.confluenceMet = false;
}

//+------------------------------------------------------------------+
//| Generate Recommendation                                           |
//+------------------------------------------------------------------+
void GenerateRecommendation()
{
   string rec = "";

   if(!g_analysis.confluenceMet)
   {
      rec = "NO TRADE - Insufficient TF confluence";
   }
   else if(InpRequireHigherTF && !g_analysis.higherTFAligned)
   {
      rec = "NO TRADE - Higher TF not aligned";
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

   // Add higher TF status
   if(g_analysis.higherTFAligned && g_analysis.confluenceMet)
   {
      rec += " [HTF OK]";
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
   Print("     MULTI-TIMEFRAME ANALYSIS (Section 10)       ");
   Print("=================================================");
   Print("Symbol: ", _Symbol);
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Current Price: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), g_digits));
   Print("-------------------------------------------------");

   // Entry TF
   Print("ENTRY TF (", TimeframeToString(InpTF_Entry), "):");
   Print("  Bias: ", TFBiasToString(g_analysis.entryTF.bias), " (Score: ", g_analysis.entryTF.biasScore, ")");
   Print("  EMA", InpEMAFast, ": ", DoubleToString(g_analysis.entryTF.emaFast, g_digits));
   Print("  EMA", InpEMASlow, ": ", DoubleToString(g_analysis.entryTF.emaSlow, g_digits));
   Print("  RSI: ", DoubleToString(g_analysis.entryTF.rsi, 2));
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
   Print("     SWING TRADER PRO - SECTION 10               ");
   Print("     MULTI-TIMEFRAME ANALYSIS                    ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol);
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
   Print("  RSI Upper: ", InpRSIUpper);
   Print("  RSI Lower: ", InpRSILower);
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
