//+------------------------------------------------------------------+
//|                                           Section06_MACD_RSI.mq5 |
//|                                      SwingTrader Pro EA          |
//|                    Section 6: MACD + RSI Momentum Indicators     |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.00"
#property description "Section 6: MACD + RSI Momentum Analysis"
#property description "MACD crossovers, RSI overbought/oversold"
#property description "Divergence detection for reversal signals"

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== MACD Settings ==="
input int      InpMACDFast            = 12;       // MACD Fast EMA Period
input int      InpMACDSlow            = 26;       // MACD Slow EMA Period
input int      InpMACDSignal          = 9;        // MACD Signal Period
input ENUM_APPLIED_PRICE InpMACDPrice = PRICE_CLOSE; // MACD Applied Price
input ENUM_TIMEFRAMES InpMACDTimeframe = PERIOD_H4;  // MACD Timeframe

input group "=== RSI Settings ==="
input int      InpRSIPeriod           = 14;       // RSI Period
input int      InpRSIOverbought       = 70;       // RSI Overbought Level
input int      InpRSIOversold         = 30;       // RSI Oversold Level
input ENUM_APPLIED_PRICE InpRSIPrice  = PRICE_CLOSE; // RSI Applied Price
input ENUM_TIMEFRAMES InpRSITimeframe = PERIOD_H4;   // RSI Timeframe

input group "=== Divergence Settings ==="
input bool     InpDetectDivergence    = true;     // Detect MACD/RSI Divergence
input int      InpDivergenceLookback  = 30;       // Divergence Lookback Bars
input int      InpSwingStrength       = 3;        // Swing Point Strength

input group "=== ATR Filter (from Section 1) ==="
input bool     InpUseATRFilter        = true;     // Use ATR Volatility Filter
input int      InpATRPeriod           = 14;       // ATR Period
input double   InpATRQuietThreshold   = 60.0;     // Quiet Market Threshold (pips)
input double   InpATRExtremeThreshold = 250.0;    // Extreme Volatility Threshold (pips)

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;     // Show Info Panel
input color    InpBullishColor        = clrLimeGreen; // Bullish Signal Color
input color    InpBearishColor        = clrRed;   // Bearish Signal Color
input color    InpNeutralColor        = clrGray;  // Neutral Color
input int      InpPanelX              = 20;       // Panel X Position
input int      InpPanelY              = 30;       // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;     // Print Report to Experts Tab

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_MACD_SIGNAL
{
   MACD_BULLISH_CROSS,      // Bullish crossover (MACD crosses above Signal)
   MACD_BEARISH_CROSS,      // Bearish crossover (MACD crosses below Signal)
   MACD_BULLISH_MOMENTUM,   // Bullish momentum (histogram increasing)
   MACD_BEARISH_MOMENTUM,   // Bearish momentum (histogram decreasing)
   MACD_ZERO_CROSS_UP,      // MACD crosses above zero
   MACD_ZERO_CROSS_DOWN,    // MACD crosses below zero
   MACD_NO_SIGNAL           // No significant signal
};

enum ENUM_RSI_CONDITION
{
   RSI_OVERBOUGHT,          // RSI above overbought level
   RSI_OVERSOLD,            // RSI below oversold level
   RSI_BULLISH,             // RSI between 50-70 (bullish zone)
   RSI_BEARISH,             // RSI between 30-50 (bearish zone)
   RSI_NEUTRAL              // RSI around 50
};

enum ENUM_DIVERGENCE_TYPE
{
   DIV_NONE,                // No divergence
   DIV_BULLISH_REGULAR,     // Regular bullish divergence (price lower low, indicator higher low)
   DIV_BEARISH_REGULAR,     // Regular bearish divergence (price higher high, indicator lower high)
   DIV_BULLISH_HIDDEN,      // Hidden bullish divergence (price higher low, indicator lower low)
   DIV_BEARISH_HIDDEN       // Hidden bearish divergence (price lower high, indicator higher high)
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct MACDResult
{
   double            macdMain;
   double            macdSignal;
   double            histogram;
   double            prevHistogram;
   ENUM_MACD_SIGNAL  signal;
   bool              aboveZero;
   datetime          timestamp;
};

struct RSIResult
{
   double            rsiValue;
   double            prevRSI;
   ENUM_RSI_CONDITION condition;
   bool              rising;
   datetime          timestamp;
};

struct DivergenceResult
{
   ENUM_DIVERGENCE_TYPE macdDivergence;
   ENUM_DIVERGENCE_TYPE rsiDivergence;
   int               barsAgo;
   datetime          timestamp;
};

struct MomentumAnalysis
{
   MACDResult        macd;
   RSIResult         rsi;
   DivergenceResult  divergence;
   ENUM_TREND_BIAS   overallBias;
   int               signalStrength;  // 0-100
   string            recommendation;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
// Indicator handles
int               g_macdHandle;
int               g_rsiHandle;
int               g_atrHandle;

// Buffers
double            g_macdMainBuffer[];
double            g_macdSignalBuffer[];
double            g_macdHistBuffer[];
double            g_rsiBuffer[];
double            g_atrBuffer[];
double            g_highBuffer[];
double            g_lowBuffer[];
double            g_closeBuffer[];

// Results
MomentumAnalysis  g_analysis;
ATRFilterResult   g_atrResult;

// Panel
string            g_panelName = "MACDRSIPanel";

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

   // Initialize arrays as series
   ArraySetAsSeries(g_macdMainBuffer, true);
   ArraySetAsSeries(g_macdSignalBuffer, true);
   ArraySetAsSeries(g_macdHistBuffer, true);
   ArraySetAsSeries(g_rsiBuffer, true);
   ArraySetAsSeries(g_atrBuffer, true);
   ArraySetAsSeries(g_highBuffer, true);
   ArraySetAsSeries(g_lowBuffer, true);
   ArraySetAsSeries(g_closeBuffer, true);

   // Create MACD handle
   g_macdHandle = iMACD(_Symbol, InpMACDTimeframe, InpMACDFast, InpMACDSlow, InpMACDSignal, InpMACDPrice);
   if(g_macdHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create MACD handle");
      return(INIT_FAILED);
   }

   // Create RSI handle
   g_rsiHandle = iRSI(_Symbol, InpRSITimeframe, InpRSIPeriod, InpRSIPrice);
   if(g_rsiHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create RSI handle");
      return(INIT_FAILED);
   }

   // Create ATR handle if filter enabled
   if(InpUseATRFilter)
   {
      g_atrHandle = iATR(_Symbol, InpMACDTimeframe, InpATRPeriod);
      if(g_atrHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR handle");
         return(INIT_FAILED);
      }
   }

   // Print initialization
   PrintInitReport();

   // Create panel
   if(InpShowPanel)
      CreatePanel();

   // Run initial analysis
   AnalyzeMomentum();

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
   if(g_macdHandle != INVALID_HANDLE) IndicatorRelease(g_macdHandle);
   if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);

   // Remove panel
   DeletePanel();

   Print("=================================================");
   Print("MACD/RSI EA Deinitialized");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpMACDTimeframe, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      AnalyzeMomentum();

      if(InpShowPanel) UpdatePanel();
   }
}

//+------------------------------------------------------------------+
//| Main Momentum Analysis Function                                   |
//+------------------------------------------------------------------+
void AnalyzeMomentum()
{
   int barsNeeded = InpDivergenceLookback + 10;
   int minBars = 5;  // Minimum bars needed for basic analysis

   // Copy MACD data - try with minimum bars if full copy fails
   int macdCopied = CopyBuffer(g_macdHandle, 0, 0, barsNeeded, g_macdMainBuffer);
   if(macdCopied < minBars)
   {
      Print("WARNING: MACD data not ready yet (copied: ", macdCopied, ")");
      return;
   }

   if(CopyBuffer(g_macdHandle, 1, 0, macdCopied, g_macdSignalBuffer) < minBars) return;
   if(CopyBuffer(g_macdHandle, 2, 0, macdCopied, g_macdHistBuffer) < minBars) return;

   // Copy RSI data
   int rsiCopied = CopyBuffer(g_rsiHandle, 0, 0, macdCopied, g_rsiBuffer);
   if(rsiCopied < minBars)
   {
      Print("WARNING: RSI data not ready yet (copied: ", rsiCopied, ")");
      return;
   }

   // Copy price data for divergence detection
   if(CopyHigh(_Symbol, InpMACDTimeframe, 0, macdCopied, g_highBuffer) < minBars) return;
   if(CopyLow(_Symbol, InpMACDTimeframe, 0, macdCopied, g_lowBuffer) < minBars) return;
   if(CopyClose(_Symbol, InpMACDTimeframe, 0, macdCopied, g_closeBuffer) < minBars) return;

   // Analyze ATR if enabled
   if(InpUseATRFilter)
      AnalyzeATR();

   // Analyze MACD
   AnalyzeMACD();

   // Analyze RSI
   AnalyzeRSI();

   // Detect divergences
   if(InpDetectDivergence)
      DetectDivergences();

   // Calculate overall bias and signal strength
   CalculateOverallBias();

   // Print report
   if(InpPrintReport)
      PrintMomentumReport();
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
//| Analyze MACD                                                      |
//+------------------------------------------------------------------+
void AnalyzeMACD()
{
   g_analysis.macd.macdMain = g_macdMainBuffer[0];
   g_analysis.macd.macdSignal = g_macdSignalBuffer[0];
   g_analysis.macd.histogram = g_macdHistBuffer[0];
   g_analysis.macd.prevHistogram = g_macdHistBuffer[1];
   g_analysis.macd.aboveZero = g_macdMainBuffer[0] > 0;
   g_analysis.macd.timestamp = TimeCurrent();

   // Determine MACD signal
   double prevMACD = g_macdMainBuffer[1];
   double prevSignal = g_macdSignalBuffer[1];
   double currMACD = g_macdMainBuffer[0];
   double currSignal = g_macdSignalBuffer[0];

   // Check for crossovers
   if(prevMACD <= prevSignal && currMACD > currSignal)
   {
      g_analysis.macd.signal = MACD_BULLISH_CROSS;
   }
   else if(prevMACD >= prevSignal && currMACD < currSignal)
   {
      g_analysis.macd.signal = MACD_BEARISH_CROSS;
   }
   // Check for zero line crossovers
   else if(g_macdMainBuffer[1] <= 0 && g_macdMainBuffer[0] > 0)
   {
      g_analysis.macd.signal = MACD_ZERO_CROSS_UP;
   }
   else if(g_macdMainBuffer[1] >= 0 && g_macdMainBuffer[0] < 0)
   {
      g_analysis.macd.signal = MACD_ZERO_CROSS_DOWN;
   }
   // Check momentum (histogram direction)
   else if(g_analysis.macd.histogram > g_analysis.macd.prevHistogram && g_analysis.macd.histogram > 0)
   {
      g_analysis.macd.signal = MACD_BULLISH_MOMENTUM;
   }
   else if(g_analysis.macd.histogram < g_analysis.macd.prevHistogram && g_analysis.macd.histogram < 0)
   {
      g_analysis.macd.signal = MACD_BEARISH_MOMENTUM;
   }
   else
   {
      g_analysis.macd.signal = MACD_NO_SIGNAL;
   }
}

//+------------------------------------------------------------------+
//| Analyze RSI                                                       |
//+------------------------------------------------------------------+
void AnalyzeRSI()
{
   g_analysis.rsi.rsiValue = g_rsiBuffer[0];
   g_analysis.rsi.prevRSI = g_rsiBuffer[1];
   g_analysis.rsi.rising = g_rsiBuffer[0] > g_rsiBuffer[1];
   g_analysis.rsi.timestamp = TimeCurrent();

   // Determine RSI condition
   if(g_analysis.rsi.rsiValue >= InpRSIOverbought)
   {
      g_analysis.rsi.condition = RSI_OVERBOUGHT;
   }
   else if(g_analysis.rsi.rsiValue <= InpRSIOversold)
   {
      g_analysis.rsi.condition = RSI_OVERSOLD;
   }
   else if(g_analysis.rsi.rsiValue > 50 && g_analysis.rsi.rsiValue < InpRSIOverbought)
   {
      g_analysis.rsi.condition = RSI_BULLISH;
   }
   else if(g_analysis.rsi.rsiValue < 50 && g_analysis.rsi.rsiValue > InpRSIOversold)
   {
      g_analysis.rsi.condition = RSI_BEARISH;
   }
   else
   {
      g_analysis.rsi.condition = RSI_NEUTRAL;
   }
}

//+------------------------------------------------------------------+
//| Detect Divergences                                                |
//+------------------------------------------------------------------+
void DetectDivergences()
{
   g_analysis.divergence.macdDivergence = DIV_NONE;
   g_analysis.divergence.rsiDivergence = DIV_NONE;
   g_analysis.divergence.barsAgo = 0;
   g_analysis.divergence.timestamp = TimeCurrent();

   // Find swing highs and lows in price and indicators
   int priceSwingHighBar1 = -1, priceSwingHighBar2 = -1;
   int priceSwingLowBar1 = -1, priceSwingLowBar2 = -1;

   // Find two most recent swing highs
   int swingCount = 0;
   for(int i = InpSwingStrength; i < InpDivergenceLookback - InpSwingStrength && swingCount < 2; i++)
   {
      if(IsSwingHigh(i, g_highBuffer, InpSwingStrength))
      {
         if(priceSwingHighBar1 == -1)
            priceSwingHighBar1 = i;
         else if(priceSwingHighBar2 == -1)
         {
            priceSwingHighBar2 = i;
            swingCount++;
         }
      }
   }

   // Find two most recent swing lows
   swingCount = 0;
   for(int i = InpSwingStrength; i < InpDivergenceLookback - InpSwingStrength && swingCount < 2; i++)
   {
      if(IsSwingLow(i, g_lowBuffer, InpSwingStrength))
      {
         if(priceSwingLowBar1 == -1)
            priceSwingLowBar1 = i;
         else if(priceSwingLowBar2 == -1)
         {
            priceSwingLowBar2 = i;
            swingCount++;
         }
      }
   }

   // Check for MACD divergence at swing lows (bullish divergence)
   if(priceSwingLowBar1 > 0 && priceSwingLowBar2 > 0)
   {
      double priceLow1 = g_lowBuffer[priceSwingLowBar1];
      double priceLow2 = g_lowBuffer[priceSwingLowBar2];
      double macdLow1 = g_macdHistBuffer[priceSwingLowBar1];
      double macdLow2 = g_macdHistBuffer[priceSwingLowBar2];
      double rsiLow1 = g_rsiBuffer[priceSwingLowBar1];
      double rsiLow2 = g_rsiBuffer[priceSwingLowBar2];

      // Regular bullish divergence: price lower low, indicator higher low
      if(priceLow1 < priceLow2 && macdLow1 > macdLow2)
      {
         g_analysis.divergence.macdDivergence = DIV_BULLISH_REGULAR;
         g_analysis.divergence.barsAgo = priceSwingLowBar1;
      }
      if(priceLow1 < priceLow2 && rsiLow1 > rsiLow2)
      {
         g_analysis.divergence.rsiDivergence = DIV_BULLISH_REGULAR;
         g_analysis.divergence.barsAgo = priceSwingLowBar1;
      }

      // Hidden bullish divergence: price higher low, indicator lower low
      if(priceLow1 > priceLow2 && macdLow1 < macdLow2)
      {
         g_analysis.divergence.macdDivergence = DIV_BULLISH_HIDDEN;
         g_analysis.divergence.barsAgo = priceSwingLowBar1;
      }
      if(priceLow1 > priceLow2 && rsiLow1 < rsiLow2)
      {
         g_analysis.divergence.rsiDivergence = DIV_BULLISH_HIDDEN;
         g_analysis.divergence.barsAgo = priceSwingLowBar1;
      }
   }

   // Check for MACD divergence at swing highs (bearish divergence)
   if(priceSwingHighBar1 > 0 && priceSwingHighBar2 > 0)
   {
      double priceHigh1 = g_highBuffer[priceSwingHighBar1];
      double priceHigh2 = g_highBuffer[priceSwingHighBar2];
      double macdHigh1 = g_macdHistBuffer[priceSwingHighBar1];
      double macdHigh2 = g_macdHistBuffer[priceSwingHighBar2];
      double rsiHigh1 = g_rsiBuffer[priceSwingHighBar1];
      double rsiHigh2 = g_rsiBuffer[priceSwingHighBar2];

      // Regular bearish divergence: price higher high, indicator lower high
      if(priceHigh1 > priceHigh2 && macdHigh1 < macdHigh2)
      {
         g_analysis.divergence.macdDivergence = DIV_BEARISH_REGULAR;
         g_analysis.divergence.barsAgo = priceSwingHighBar1;
      }
      if(priceHigh1 > priceHigh2 && rsiHigh1 < rsiHigh2)
      {
         g_analysis.divergence.rsiDivergence = DIV_BEARISH_REGULAR;
         g_analysis.divergence.barsAgo = priceSwingHighBar1;
      }

      // Hidden bearish divergence: price lower high, indicator higher high
      if(priceHigh1 < priceHigh2 && macdHigh1 > macdHigh2)
      {
         g_analysis.divergence.macdDivergence = DIV_BEARISH_HIDDEN;
         g_analysis.divergence.barsAgo = priceSwingHighBar1;
      }
      if(priceHigh1 < priceHigh2 && rsiHigh1 > rsiHigh2)
      {
         g_analysis.divergence.rsiDivergence = DIV_BEARISH_HIDDEN;
         g_analysis.divergence.barsAgo = priceSwingHighBar1;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if bar is a Swing High                                      |
//+------------------------------------------------------------------+
bool IsSwingHigh(int index, double &buffer[], int strength)
{
   if(index < strength || index >= ArraySize(buffer) - strength)
      return false;

   double val = buffer[index];
   for(int i = 1; i <= strength; i++)
   {
      if(buffer[index - i] >= val || buffer[index + i] >= val)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Check if bar is a Swing Low                                       |
//+------------------------------------------------------------------+
bool IsSwingLow(int index, double &buffer[], int strength)
{
   if(index < strength || index >= ArraySize(buffer) - strength)
      return false;

   double val = buffer[index];
   for(int i = 1; i <= strength; i++)
   {
      if(buffer[index - i] <= val || buffer[index + i] <= val)
         return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Overall Bias and Signal Strength                        |
//+------------------------------------------------------------------+
void CalculateOverallBias()
{
   int bullishPoints = 0;
   int bearishPoints = 0;

   // MACD analysis (weight: 30 points max)
   switch(g_analysis.macd.signal)
   {
      case MACD_BULLISH_CROSS:     bullishPoints += 30; break;
      case MACD_BEARISH_CROSS:     bearishPoints += 30; break;
      case MACD_ZERO_CROSS_UP:     bullishPoints += 25; break;
      case MACD_ZERO_CROSS_DOWN:   bearishPoints += 25; break;
      case MACD_BULLISH_MOMENTUM:  bullishPoints += 15; break;
      case MACD_BEARISH_MOMENTUM:  bearishPoints += 15; break;
      default: break;
   }

   // MACD position relative to zero (weight: 10 points)
   if(g_analysis.macd.aboveZero)
      bullishPoints += 10;
   else
      bearishPoints += 10;

   // RSI analysis (weight: 30 points max)
   switch(g_analysis.rsi.condition)
   {
      case RSI_OVERSOLD:    bullishPoints += 25; break;  // Potential reversal up
      case RSI_OVERBOUGHT:  bearishPoints += 25; break;  // Potential reversal down
      case RSI_BULLISH:     bullishPoints += 15; break;
      case RSI_BEARISH:     bearishPoints += 15; break;
      default: break;
   }

   // RSI direction (weight: 10 points)
   if(g_analysis.rsi.rising)
      bullishPoints += 10;
   else
      bearishPoints += 10;

   // Divergence analysis (weight: 20 points max)
   switch(g_analysis.divergence.macdDivergence)
   {
      case DIV_BULLISH_REGULAR:  bullishPoints += 20; break;
      case DIV_BEARISH_REGULAR:  bearishPoints += 20; break;
      case DIV_BULLISH_HIDDEN:   bullishPoints += 15; break;
      case DIV_BEARISH_HIDDEN:   bearishPoints += 15; break;
      default: break;
   }

   switch(g_analysis.divergence.rsiDivergence)
   {
      case DIV_BULLISH_REGULAR:  bullishPoints += 15; break;
      case DIV_BEARISH_REGULAR:  bearishPoints += 15; break;
      case DIV_BULLISH_HIDDEN:   bullishPoints += 10; break;
      case DIV_BEARISH_HIDDEN:   bearishPoints += 10; break;
      default: break;
   }

   // Calculate overall bias
   int totalPoints = bullishPoints + bearishPoints;
   if(totalPoints == 0) totalPoints = 1;  // Avoid division by zero

   if(bullishPoints > bearishPoints + 20)
   {
      g_analysis.overallBias = BIAS_BULLISH;
      g_analysis.signalStrength = (bullishPoints * 100) / (totalPoints + 50);
   }
   else if(bearishPoints > bullishPoints + 20)
   {
      g_analysis.overallBias = BIAS_BEARISH;
      g_analysis.signalStrength = (bearishPoints * 100) / (totalPoints + 50);
   }
   else
   {
      g_analysis.overallBias = BIAS_NEUTRAL;
      g_analysis.signalStrength = 50 - MathAbs(bullishPoints - bearishPoints);
   }

   // Cap signal strength at 100
   if(g_analysis.signalStrength > 100) g_analysis.signalStrength = 100;
   if(g_analysis.signalStrength < 0) g_analysis.signalStrength = 0;

   // Generate recommendation
   GenerateRecommendation();
}

//+------------------------------------------------------------------+
//| Generate Trading Recommendation                                   |
//+------------------------------------------------------------------+
void GenerateRecommendation()
{
   // Check ATR filter first
   if(InpUseATRFilter && !g_atrResult.tradingAllowed)
   {
      g_analysis.recommendation = "NO TRADE - Market too quiet";
      return;
   }

   string rec = "";
   double rsiVal = g_analysis.rsi.rsiValue;
   bool bullishCross = (g_analysis.macd.signal == MACD_BULLISH_CROSS);
   bool bearishCross = (g_analysis.macd.signal == MACD_BEARISH_CROSS);

   // === CROSSOVER-BASED SIGNALS (Highest Priority) ===

   // Strong bullish: Bullish cross + RSI < 40 (Grok's recommendation)
   if(bullishCross && rsiVal < 40)
   {
      rec = "STRONG BUY - MACD bullish cross + RSI low (<40)";
   }
   // Strong bullish: Bullish cross + Divergence
   else if(bullishCross && g_analysis.divergence.macdDivergence == DIV_BULLISH_REGULAR)
   {
      rec = "STRONG BUY - MACD bullish cross + Bullish divergence";
   }
   // Standard bullish cross
   else if(bullishCross)
   {
      rec = "BUY - MACD bullish crossover";
   }
   // Strong bearish: Bearish cross + RSI > 60 (Grok's recommendation)
   else if(bearishCross && rsiVal > 60)
   {
      rec = "STRONG SELL - MACD bearish cross + RSI high (>60)";
   }
   // Strong bearish: Bearish cross + Divergence
   else if(bearishCross && g_analysis.divergence.macdDivergence == DIV_BEARISH_REGULAR)
   {
      rec = "STRONG SELL - MACD bearish cross + Bearish divergence";
   }
   // Standard bearish cross
   else if(bearishCross)
   {
      rec = "SELL - MACD bearish crossover";
   }

   // === ZERO LINE CROSSOVERS ===
   else if(g_analysis.macd.signal == MACD_ZERO_CROSS_UP)
   {
      rec = "BULLISH - MACD crossed above zero line";
   }
   else if(g_analysis.macd.signal == MACD_ZERO_CROSS_DOWN)
   {
      rec = "BEARISH - MACD crossed below zero line";
   }

   // === MOMENTUM SIGNALS (Grok's recommendation) ===
   // Bullish momentum: MACD > 0 && RSI > 50
   else if(g_analysis.macd.aboveZero && rsiVal > 50)
   {
      rec = "BULLISH MOMENTUM - MACD positive + RSI >50";
   }
   // Bearish momentum: MACD < 0 && RSI < 50
   else if(!g_analysis.macd.aboveZero && rsiVal < 50)
   {
      rec = "BEARISH MOMENTUM - MACD negative + RSI <50";
   }

   // === EXTREME RSI WARNINGS ===
   else if(g_analysis.rsi.condition == RSI_OVERBOUGHT)
   {
      rec = "CAUTION - RSI overbought (>" + IntegerToString(InpRSIOverbought) + ")";
   }
   else if(g_analysis.rsi.condition == RSI_OVERSOLD)
   {
      rec = "CAUTION - RSI oversold (<" + IntegerToString(InpRSIOversold) + ")";
   }

   // === DIVERGENCE ALERTS ===
   else if(g_analysis.divergence.macdDivergence == DIV_BULLISH_REGULAR ||
           g_analysis.divergence.rsiDivergence == DIV_BULLISH_REGULAR)
   {
      rec = "WATCH - Bullish divergence detected";
   }
   else if(g_analysis.divergence.macdDivergence == DIV_BEARISH_REGULAR ||
           g_analysis.divergence.rsiDivergence == DIV_BEARISH_REGULAR)
   {
      rec = "WATCH - Bearish divergence detected";
   }

   // === HISTOGRAM MOMENTUM ===
   else if(g_analysis.macd.signal == MACD_BULLISH_MOMENTUM)
   {
      rec = "HOLD LONG - Bullish momentum increasing";
   }
   else if(g_analysis.macd.signal == MACD_BEARISH_MOMENTUM)
   {
      rec = "HOLD SHORT - Bearish momentum increasing";
   }
   else
   {
      rec = "WAIT - No clear signal";
   }

   g_analysis.recommendation = rec;
}

//+------------------------------------------------------------------+
//| Print Momentum Report                                             |
//+------------------------------------------------------------------+
void PrintMomentumReport()
{
   Print("");
   Print("=================================================");
   Print("       MACD + RSI MOMENTUM REPORT (Section 6)    ");
   Print("=================================================");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", TimeframeToString(InpMACDTimeframe));
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Current Price: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), g_digits));
   Print("-------------------------------------------------");

   // ATR Status
   if(InpUseATRFilter)
   {
      Print("ATR FILTER:");
      Print("  ATR Value: ", DoubleToString(g_atrResult.atrValue, 2), " pips");
      Print("  Condition: ", MarketConditionToString(g_atrResult.condition));
      Print("-------------------------------------------------");
   }

   // MACD Analysis
   Print("MACD ANALYSIS:");
   Print("  MACD Line: ", DoubleToString(g_analysis.macd.macdMain, 5));
   Print("  Signal Line: ", DoubleToString(g_analysis.macd.macdSignal, 5));
   Print("  Histogram: ", DoubleToString(g_analysis.macd.histogram, 5));
   Print("  Position: ", g_analysis.macd.aboveZero ? "Above Zero" : "Below Zero");
   Print("  Signal: ", MACDSignalToString(g_analysis.macd.signal));
   Print("-------------------------------------------------");

   // RSI Analysis
   Print("RSI ANALYSIS:");
   Print("  RSI Value: ", DoubleToString(g_analysis.rsi.rsiValue, 2));
   Print("  Condition: ", RSIConditionToString(g_analysis.rsi.condition));
   Print("  Direction: ", g_analysis.rsi.rising ? "Rising" : "Falling");
   Print("-------------------------------------------------");

   // Divergence Analysis
   if(InpDetectDivergence)
   {
      Print("DIVERGENCE ANALYSIS:");
      Print("  MACD Divergence: ", DivergenceToString(g_analysis.divergence.macdDivergence));
      Print("  RSI Divergence: ", DivergenceToString(g_analysis.divergence.rsiDivergence));
      if(g_analysis.divergence.barsAgo > 0)
         Print("  Bars Ago: ", g_analysis.divergence.barsAgo);
      Print("-------------------------------------------------");
   }

   // Overall Analysis
   Print("OVERALL MOMENTUM:");
   Print("  Bias: ", TrendBiasToString(g_analysis.overallBias));
   Print("  Signal Strength: ", g_analysis.signalStrength, "%");
   Print("-------------------------------------------------");

   // Recommendation
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
   Print("     SWING TRADER PRO - SECTION 6                ");
   Print("     MACD + RSI MOMENTUM INDICATORS              ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol);
   Print("TIMEFRAME: ", TimeframeToString(InpMACDTimeframe));
   Print("-------------------------------------------------");
   Print("MACD SETTINGS:");
   Print("  Fast EMA: ", InpMACDFast);
   Print("  Slow EMA: ", InpMACDSlow);
   Print("  Signal: ", InpMACDSignal);
   Print("-------------------------------------------------");
   Print("RSI SETTINGS:");
   Print("  Period: ", InpRSIPeriod);
   Print("  Overbought: ", InpRSIOverbought);
   Print("  Oversold: ", InpRSIOversold);
   Print("-------------------------------------------------");
   Print("SIGNAL INTERPRETATION:");
   Print("  MACD Bullish Cross + RSI Oversold = STRONG BUY");
   Print("  MACD Bearish Cross + RSI Overbought = STRONG SELL");
   Print("  Divergence + Crossover = High probability signal");
   Print("=================================================");
   Print("");
}

//+------------------------------------------------------------------+
//| Convert MACD Signal to String                                     |
//+------------------------------------------------------------------+
string MACDSignalToString(ENUM_MACD_SIGNAL signal)
{
   switch(signal)
   {
      case MACD_BULLISH_CROSS:     return "BULLISH CROSSOVER";
      case MACD_BEARISH_CROSS:     return "BEARISH CROSSOVER";
      case MACD_BULLISH_MOMENTUM:  return "Bullish Momentum";
      case MACD_BEARISH_MOMENTUM:  return "Bearish Momentum";
      case MACD_ZERO_CROSS_UP:     return "Zero Line Cross UP";
      case MACD_ZERO_CROSS_DOWN:   return "Zero Line Cross DOWN";
      default:                     return "No Signal";
   }
}

//+------------------------------------------------------------------+
//| Convert RSI Condition to String                                   |
//+------------------------------------------------------------------+
string RSIConditionToString(ENUM_RSI_CONDITION condition)
{
   switch(condition)
   {
      case RSI_OVERBOUGHT:  return "OVERBOUGHT (>" + IntegerToString(InpRSIOverbought) + ")";
      case RSI_OVERSOLD:    return "OVERSOLD (<" + IntegerToString(InpRSIOversold) + ")";
      case RSI_BULLISH:     return "Bullish Zone (50-70)";
      case RSI_BEARISH:     return "Bearish Zone (30-50)";
      default:              return "Neutral (~50)";
   }
}

//+------------------------------------------------------------------+
//| Convert Divergence Type to String                                 |
//+------------------------------------------------------------------+
string DivergenceToString(ENUM_DIVERGENCE_TYPE div)
{
   switch(div)
   {
      case DIV_BULLISH_REGULAR:  return "REGULAR BULLISH (Reversal Up)";
      case DIV_BEARISH_REGULAR:  return "REGULAR BEARISH (Reversal Down)";
      case DIV_BULLISH_HIDDEN:   return "Hidden Bullish (Trend Continuation)";
      case DIV_BEARISH_HIDDEN:   return "Hidden Bearish (Trend Continuation)";
      default:                   return "None";
   }
}

//+------------------------------------------------------------------+
//| Create Panel                                                      |
//+------------------------------------------------------------------+
void CreatePanel()
{
   int x = InpPanelX;
   int y = InpPanelY;

   CreateRectangle(g_panelName + "_bg", x, y, 320, 320, clrBlack, 200);

   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "MACD + RSI MOMENTUM", clrGold, 10, "Arial Bold");

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

   // MACD Section
   CreateLabel(g_panelName + "_macd_title", x + 10, y + yOff, "MACD:", clrCyan, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_macd_line", x + 20, y + yOff, "Line:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_macd_line_val", x + 120, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 16;

   CreateLabel(g_panelName + "_macd_signal", x + 20, y + yOff, "Signal:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_macd_signal_val", x + 120, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 16;

   CreateLabel(g_panelName + "_macd_hist", x + 20, y + yOff, "Histogram:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_macd_hist_val", x + 120, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 16;

   CreateLabel(g_panelName + "_macd_status", x + 20, y + yOff, "Status:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_macd_status_val", x + 120, y + yOff, "--", clrYellow, 8, "Arial Bold");
   yOff += 20;

   // RSI Section
   CreateLabel(g_panelName + "_rsi_title", x + 10, y + yOff, "RSI:", clrCyan, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_rsi_value", x + 20, y + yOff, "Value:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_rsi_value_val", x + 120, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 16;

   CreateLabel(g_panelName + "_rsi_cond", x + 20, y + yOff, "Condition:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_rsi_cond_val", x + 120, y + yOff, "--", clrYellow, 8, "Arial Bold");
   yOff += 20;

   // Divergence Section
   CreateLabel(g_panelName + "_div_title", x + 10, y + yOff, "DIVERGENCE:", clrCyan, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_macd_div", x + 20, y + yOff, "MACD:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_macd_div_val", x + 120, y + yOff, "None", clrGray, 8, "Arial");
   yOff += 16;

   CreateLabel(g_panelName + "_rsi_div", x + 20, y + yOff, "RSI:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_rsi_div_val", x + 120, y + yOff, "None", clrGray, 8, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Overall
   CreateLabel(g_panelName + "_bias_label", x + 10, y + yOff, "Bias:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_bias_value", x + 120, y + yOff, "--", clrYellow, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_strength_label", x + 10, y + yOff, "Strength:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_strength_value", x + 120, y + yOff, "--%", clrYellow, 9, "Arial");
   yOff += 20;

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

   // Update ATR
   if(InpUseATRFilter)
   {
      ObjectSetString(0, g_panelName + "_atr_value", OBJPROP_TEXT,
                      DoubleToString(g_atrResult.atrValue, 1) + " pips");
   }

   // Update MACD
   ObjectSetString(0, g_panelName + "_macd_line_val", OBJPROP_TEXT,
                   DoubleToString(g_analysis.macd.macdMain, 4));
   ObjectSetString(0, g_panelName + "_macd_signal_val", OBJPROP_TEXT,
                   DoubleToString(g_analysis.macd.macdSignal, 4));

   color histColor = g_analysis.macd.histogram > 0 ? InpBullishColor : InpBearishColor;
   ObjectSetString(0, g_panelName + "_macd_hist_val", OBJPROP_TEXT,
                   DoubleToString(g_analysis.macd.histogram, 4));
   ObjectSetInteger(0, g_panelName + "_macd_hist_val", OBJPROP_COLOR, histColor);

   string macdStatus = MACDSignalToString(g_analysis.macd.signal);
   color macdStatusColor = clrGray;
   if(g_analysis.macd.signal == MACD_BULLISH_CROSS || g_analysis.macd.signal == MACD_ZERO_CROSS_UP)
      macdStatusColor = InpBullishColor;
   else if(g_analysis.macd.signal == MACD_BEARISH_CROSS || g_analysis.macd.signal == MACD_ZERO_CROSS_DOWN)
      macdStatusColor = InpBearishColor;

   ObjectSetString(0, g_panelName + "_macd_status_val", OBJPROP_TEXT, macdStatus);
   ObjectSetInteger(0, g_panelName + "_macd_status_val", OBJPROP_COLOR, macdStatusColor);

   // Update RSI
   ObjectSetString(0, g_panelName + "_rsi_value_val", OBJPROP_TEXT,
                   DoubleToString(g_analysis.rsi.rsiValue, 2));

   string rsiCond = "";
   color rsiColor = clrGray;
   switch(g_analysis.rsi.condition)
   {
      case RSI_OVERBOUGHT:
         rsiCond = "OVERBOUGHT";
         rsiColor = InpBearishColor;
         break;
      case RSI_OVERSOLD:
         rsiCond = "OVERSOLD";
         rsiColor = InpBullishColor;
         break;
      case RSI_BULLISH:
         rsiCond = "Bullish";
         rsiColor = InpBullishColor;
         break;
      case RSI_BEARISH:
         rsiCond = "Bearish";
         rsiColor = InpBearishColor;
         break;
      default:
         rsiCond = "Neutral";
         rsiColor = InpNeutralColor;
   }
   ObjectSetString(0, g_panelName + "_rsi_cond_val", OBJPROP_TEXT, rsiCond);
   ObjectSetInteger(0, g_panelName + "_rsi_cond_val", OBJPROP_COLOR, rsiColor);

   // Update Divergence
   string macdDiv = "None";
   color macdDivColor = clrGray;
   if(g_analysis.divergence.macdDivergence == DIV_BULLISH_REGULAR ||
      g_analysis.divergence.macdDivergence == DIV_BULLISH_HIDDEN)
   {
      macdDiv = (g_analysis.divergence.macdDivergence == DIV_BULLISH_REGULAR) ? "BULLISH" : "Hidden Bull";
      macdDivColor = InpBullishColor;
   }
   else if(g_analysis.divergence.macdDivergence == DIV_BEARISH_REGULAR ||
           g_analysis.divergence.macdDivergence == DIV_BEARISH_HIDDEN)
   {
      macdDiv = (g_analysis.divergence.macdDivergence == DIV_BEARISH_REGULAR) ? "BEARISH" : "Hidden Bear";
      macdDivColor = InpBearishColor;
   }
   ObjectSetString(0, g_panelName + "_macd_div_val", OBJPROP_TEXT, macdDiv);
   ObjectSetInteger(0, g_panelName + "_macd_div_val", OBJPROP_COLOR, macdDivColor);

   string rsiDiv = "None";
   color rsiDivColor = clrGray;
   if(g_analysis.divergence.rsiDivergence == DIV_BULLISH_REGULAR ||
      g_analysis.divergence.rsiDivergence == DIV_BULLISH_HIDDEN)
   {
      rsiDiv = (g_analysis.divergence.rsiDivergence == DIV_BULLISH_REGULAR) ? "BULLISH" : "Hidden Bull";
      rsiDivColor = InpBullishColor;
   }
   else if(g_analysis.divergence.rsiDivergence == DIV_BEARISH_REGULAR ||
           g_analysis.divergence.rsiDivergence == DIV_BEARISH_HIDDEN)
   {
      rsiDiv = (g_analysis.divergence.rsiDivergence == DIV_BEARISH_REGULAR) ? "BEARISH" : "Hidden Bear";
      rsiDivColor = InpBearishColor;
   }
   ObjectSetString(0, g_panelName + "_rsi_div_val", OBJPROP_TEXT, rsiDiv);
   ObjectSetInteger(0, g_panelName + "_rsi_div_val", OBJPROP_COLOR, rsiDivColor);

   // Update Overall Bias
   string biasText = TrendBiasToString(g_analysis.overallBias);
   color biasColor = InpNeutralColor;
   if(g_analysis.overallBias == BIAS_BULLISH)
      biasColor = InpBullishColor;
   else if(g_analysis.overallBias == BIAS_BEARISH)
      biasColor = InpBearishColor;

   ObjectSetString(0, g_panelName + "_bias_value", OBJPROP_TEXT, biasText);
   ObjectSetInteger(0, g_panelName + "_bias_value", OBJPROP_COLOR, biasColor);

   ObjectSetString(0, g_panelName + "_strength_value", OBJPROP_TEXT,
                   IntegerToString(g_analysis.signalStrength) + "%");

   // Update Recommendation
   color recColor = InpNeutralColor;
   if(StringFind(g_analysis.recommendation, "BUY") >= 0 ||
      StringFind(g_analysis.recommendation, "BULLISH") >= 0)
      recColor = InpBullishColor;
   else if(StringFind(g_analysis.recommendation, "SELL") >= 0 ||
           StringFind(g_analysis.recommendation, "BEARISH") >= 0)
      recColor = InpBearishColor;

   // Truncate recommendation for panel
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
MACDResult GetMACDResult() { return g_analysis.macd; }
RSIResult GetRSIResult() { return g_analysis.rsi; }
DivergenceResult GetDivergenceResult() { return g_analysis.divergence; }
ENUM_TREND_BIAS GetMomentumBias() { return g_analysis.overallBias; }
int GetSignalStrength() { return g_analysis.signalStrength; }
string GetRecommendation() { return g_analysis.recommendation; }
//+------------------------------------------------------------------+
