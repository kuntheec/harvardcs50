//+------------------------------------------------------------------+
//|                                           CommonStructures.mqh   |
//|                                      SwingTrader Pro EA          |
//|                                   Multi-Timeframe SMC Strategy   |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+

// Market Condition based on ATR
enum ENUM_MARKET_CONDITION
{
   MARKET_QUIET,           // ATR < 60 pips - Too quiet, skip trade
   MARKET_NORMAL,          // ATR 60-250 pips - Normal conditions
   MARKET_EXTREME          // ATR > 250 pips - Extreme volatility
};

// Trend Bias
enum ENUM_TREND_BIAS
{
   BIAS_BULLISH,           // Bullish trend
   BIAS_BEARISH,           // Bearish trend
   BIAS_NEUTRAL            // No clear trend / Mixed signals
};

// Structure Type (BOS/CHoCH)
enum ENUM_STRUCTURE_TYPE
{
   STRUCTURE_NONE,         // No structure break
   STRUCTURE_BOS,          // Break of Structure
   STRUCTURE_CHOCH         // Change of Character
};

// Zone Type
enum ENUM_ZONE_TYPE
{
   ZONE_DEMAND,            // Demand zone (bullish)
   ZONE_SUPPLY             // Supply zone (bearish)
};

// Zone Status
enum ENUM_ZONE_STATUS
{
   ZONE_FRESH,             // Not yet tested
   ZONE_TESTED,            // Tested once
   ZONE_BROKEN             // Broken/invalidated
};

// FVG Type
enum ENUM_FVG_TYPE
{
   FVG_BULLISH,            // Bullish imbalance
   FVG_BEARISH             // Bearish imbalance
};

// Entry Stage
enum ENUM_ENTRY_STAGE
{
   STAGE_NONE,             // No position
   STAGE_1,                // Initial entry (30%)
   STAGE_2,                // Confirmation entry (40%)
   STAGE_3                 // Profit pyramid (30%)
};

// Signal Strength
enum ENUM_SIGNAL_STRENGTH
{
   SIGNAL_NONE,            // No signal
   SIGNAL_WEAK,            // 1-2 confirmations
   SIGNAL_MODERATE,        // 3-4 confirmations
   SIGNAL_STRONG           // 5+ confirmations
};

// Timeframe Analysis Level
enum ENUM_TF_LEVEL
{
   TF_HIGHER,              // H4 - Market structure
   TF_INTERMEDIATE,        // H1 - Confirmation
   TF_ENTRY,               // M15 - Entry zone
   TF_PRECISION            // M5 - Precision entry
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+

// ATR Filter Result
struct ATRFilterResult
{
   double            atrValue;           // ATR(14) value in pips
   ENUM_MARKET_CONDITION condition;      // Market condition
   bool              tradingAllowed;     // Can we trade?
   string            reason;             // Explanation
   datetime          timestamp;          // When calculated
};

// EMA Analysis Result
struct EMAAnalysisResult
{
   double            ema50;              // EMA 50 value
   double            ema200;             // EMA 200 value
   ENUM_TREND_BIAS   trend;              // Current trend
   bool              recentCrossover;    // Crossed within 10 candles?
   int               candlesSinceCross;  // Candles since last cross
   datetime          timestamp;
};

// Swing Point
struct SwingPoint
{
   double            price;              // Price level
   datetime          time;               // Time of swing
   int               barIndex;           // Bar index
   bool              isHigh;             // true = swing high, false = swing low
   bool              isValid;            // Still valid?
};

// Structure Break (BOS/CHoCH)
struct StructureBreak
{
   ENUM_STRUCTURE_TYPE type;             // BOS or CHoCH
   ENUM_TREND_BIAS   direction;          // Bullish or Bearish
   double            breakLevel;         // Price level broken
   datetime          breakTime;          // When it broke
   int               barIndex;           // Bar index
   bool              confirmed;          // Close confirmed?
};

// Supply/Demand Zone
struct SDZone
{
   ENUM_ZONE_TYPE    type;               // Supply or Demand
   double            upperPrice;         // Zone high
   double            lowerPrice;         // Zone low
   datetime          formationTime;      // When formed
   int               barIndex;           // Bar index when formed
   ENUM_ZONE_STATUS  status;             // Fresh/Tested/Broken
   int               touchCount;         // Times price touched zone
   double            strength;           // Zone strength score
};

// Fibonacci Level
struct FibLevel
{
   double            ratio;              // Fib ratio (0.236, 0.382, etc.)
   double            price;              // Price at this level
   string            label;              // Display label
   bool              isRetracement;      // true = retrace, false = extension
};

// Fibonacci Analysis
struct FibAnalysis
{
   double            swingHigh;          // Swing high price
   double            swingLow;           // Swing low price
   datetime          swingHighTime;      // Swing high time
   datetime          swingLowTime;       // Swing low time
   ENUM_TREND_BIAS   fibDirection;       // Direction of fib
   FibLevel          levels[12];         // All fib levels
   int               levelCount;         // Number of levels
};

// Fair Value Gap
struct FVGap
{
   ENUM_FVG_TYPE     type;               // Bullish or Bearish
   double            upperPrice;         // Gap high
   double            lowerPrice;         // Gap low
   double            midPrice;           // Gap midpoint (50%)
   datetime          formationTime;      // When formed
   int               barIndex;           // Bar index
   bool              filled;             // Has gap been filled?
   double            fillPercent;        // How much filled (0-100)
};

// Volume Profile Level
struct VolumeLevel
{
   double            price;              // Price level
   double            volume;             // Volume at level
   bool              isPOC;              // Point of Control?
   bool              isVAH;              // Value Area High?
   bool              isVAL;              // Value Area Low?
};

// Order Block
struct OrderBlock
{
   ENUM_ZONE_TYPE    type;               // Bullish or Bearish OB
   double            upperPrice;         // OB high
   double            lowerPrice;         // OB low
   datetime          formationTime;      // When formed
   double            volume;             // Volume in OB
   bool              mitigated;          // Has been mitigated?
};

// News Event
struct NewsEvent
{
   datetime          eventTime;          // Event time
   string            eventName;          // Event name
   string            currency;           // Affected currency
   int               impact;             // 1=Low, 2=Medium, 3=High
   bool              passed;             // Event has passed?
};

// Trade Signal
struct TradeSignal
{
   ENUM_TREND_BIAS   direction;          // Buy or Sell
   ENUM_SIGNAL_STRENGTH strength;        // Signal strength
   double            entryPrice;         // Suggested entry
   double            stopLoss;           // Suggested SL
   double            takeProfit1;        // TP1
   double            takeProfit2;        // TP2
   double            takeProfit3;        // TP3
   double            riskRewardRatio;    // R:R ratio
   string            reason;             // Signal explanation
   datetime          signalTime;         // When generated
   bool              isValid;            // Still valid?
};

// Position Stage Info
struct PositionStage
{
   ENUM_ENTRY_STAGE  stage;              // Current stage
   double            lots;               // Lots for this stage
   double            entryPrice;         // Entry price
   datetime          entryTime;          // Entry time
   bool              filled;             // Position opened?
};

// Complete Trade Setup
struct TradeSetup
{
   // Analysis results
   ATRFilterResult   atrFilter;
   EMAAnalysisResult emaAnalysis;
   StructureBreak    latestBOS;
   StructureBreak    latestCHoCH;
   SDZone            relevantZone;
   FibAnalysis       fibAnalysis;
   FVGap             targetFVG;
   OrderBlock        stopLossOB;

   // Combined bias
   ENUM_TREND_BIAS   h4Bias;
   ENUM_TREND_BIAS   h1Bias;
   ENUM_TREND_BIAS   overallBias;

   // Final signal
   TradeSignal       signal;

   // Position management
   PositionStage     stages[3];
   int               currentStage;
   double            totalLots;
   double            breakEvenPrice;

   // Risk info
   double            riskAmount;
   double            riskPercent;

   // Timestamps
   datetime          setupTime;
   datetime          lastUpdate;
   bool              isActive;
};

//+------------------------------------------------------------------+
//| Global Settings Structure                                         |
//+------------------------------------------------------------------+
struct EASettings
{
   // Account settings
   double            startingBalance;    // Starting balance
   double            riskPercent;        // Risk per trade (%)
   double            maxDrawdownPercent; // Max drawdown (%)
   int               leverage;           // Account leverage

   // ATR Filter settings
   int               atrPeriod;          // ATR period
   double            atrQuietThreshold;  // Quiet market threshold (pips)
   double            atrExtremeThreshold;// Extreme market threshold (pips)

   // EMA settings
   int               emaPeriodFast;      // EMA fast period
   int               emaPeriodSlow;      // EMA slow period
   int               crossoverLookback;  // Candles to check for crossover

   // Structure settings
   int               swingLookback;      // Candles for swing detection
   int               bosLookback;        // Candles for BOS detection

   // Zone settings
   int               minCandlesForZone;  // Min candles for strong move
   double            zoneExtendPercent;  // Zone extension %

   // Fibonacci settings
   bool              useFibFan;          // Use Fib Fan?

   // News filter settings
   bool              useNewsFilter;      // Enable news filter?
   int               newsBufferMinutes;  // Minutes before/after news

   // Entry settings
   double            stage1Percent;      // Stage 1 position %
   double            stage2Percent;      // Stage 2 position %
   double            stage3Percent;      // Stage 3 position %
   int               maxEntryTimeMinutes;// Max time for Stage 1-2

   // Visual settings
   bool              showZones;          // Show S/D zones on chart
   bool              showFib;            // Show Fibonacci on chart
   bool              showFVG;            // Show FVG on chart
   bool              showBOS;            // Show BOS/CHoCH on chart
};

//+------------------------------------------------------------------+
//| Helper Functions                                                  |
//+------------------------------------------------------------------+

// Convert pips to points
double PipsToPoints(string symbol, double pips)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   if(digits == 3 || digits == 5)
      return pips * 10 * point;
   else
      return pips * point;
}

double PointsToPips(string symbol, double points)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   if(digits == 3 || digits == 5)
      return points / (10 * point);
   else
      return points / point;
}

double GetPipValue(string symbol)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

   if(digits == 3 || digits == 5)
      return 10 * point;
   else
      return point;
}

string FormatPrice(double price, int digits)
{
   return DoubleToString(price, digits);
}

string FormatLots(double lots)
{
   return DoubleToString(lots, 2);
}

string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H2:  return "H2";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default:         return "Unknown";
   }
}

string MarketConditionToString(ENUM_MARKET_CONDITION condition)
{
   switch(condition)
   {
      case MARKET_QUIET:   return "QUIET (Skip Trade)";
      case MARKET_NORMAL:  return "NORMAL (Proceed)";
      case MARKET_EXTREME: return "EXTREME (Adjust Strategy)";
      default:             return "Unknown";
   }
}

string TrendBiasToString(ENUM_TREND_BIAS bias)
{
   switch(bias)
   {
      case BIAS_BULLISH: return "BULLISH";
      case BIAS_BEARISH: return "BEARISH";
      case BIAS_NEUTRAL: return "NEUTRAL";
      default:           return "Unknown";
   }
}

string StructureTypeToString(ENUM_STRUCTURE_TYPE type)
{
   switch(type)
   {
      case STRUCTURE_NONE:  return "NONE";
      case STRUCTURE_BOS:   return "BOS";
      case STRUCTURE_CHOCH: return "CHoCH";
      default:              return "Unknown";
   }
}

string SignalStrengthToString(ENUM_SIGNAL_STRENGTH strength)
{
   switch(strength)
   {
      case SIGNAL_NONE:     return "NONE";
      case SIGNAL_WEAK:     return "WEAK";
      case SIGNAL_MODERATE: return "MODERATE";
      case SIGNAL_STRONG:   return "STRONG";
      default:              return "Unknown";
   }
}
//+------------------------------------------------------------------+
