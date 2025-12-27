//+------------------------------------------------------------------+
//|                                           CommonStructures.mqh   |
//|                                      SwingTrader Pro EA          |
//|                                   Multi-Timeframe SMC Strategy   |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.30"

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

// Slope Direction (for EMA momentum analysis)
enum ENUM_SLOPE_DIRECTION
{
   SLOPE_RISING,           // Slope is positive (rising)
   SLOPE_FALLING,          // Slope is negative (falling)
   SLOPE_FLAT              // Slope is near zero (flat)
};

// Crossover Type
enum ENUM_CROSSOVER_TYPE
{
   CROSS_NONE,             // No recent crossover
   CROSS_BULLISH,          // Golden Cross (fast above slow)
   CROSS_BEARISH           // Death Cross (fast below slow)
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

// Symbol Info Cache (for proper pip/point calculations)
struct SymbolInfoCache
{
   string            symbol;             // Symbol name
   int               digits;             // Symbol digits
   double            point;              // Symbol point value
   double            pipSize;            // Pip size (0.10 for Gold, 0.0001 for Forex)
   double            tickSize;           // Minimum tick size
   double            tickValue;          // Value of one tick
   bool              isGold;             // Is Gold/XAU pair
   bool              isSilver;           // Is Silver/XAG pair
   bool              isJPY;              // Is JPY pair
   bool              isCrypto;           // Is Crypto (BTC, ETH, etc.)
};

// ATR Filter Result
struct ATRFilterResult
{
   double            atrValue;           // ATR(14) value in pips
   double            atrPoints;          // ATR raw value in points
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
   double            emaGap;             // EMA50 - EMA200
   double            emaGapPercent;      // Gap as percentage
   ENUM_TREND_BIAS   trend;              // Current trend
   bool              priceAboveEMA50;    // Is price above EMA50?
   bool              priceAboveEMA200;   // Is price above EMA200?

   // Slope analysis
   double            ema50Slope;         // EMA50 slope percentage
   double            ema200Slope;        // EMA200 slope percentage
   ENUM_SLOPE_DIRECTION ema50SlopeDir;   // EMA50 slope direction
   ENUM_SLOPE_DIRECTION ema200SlopeDir;  // EMA200 slope direction
   double            slopeStrength;      // Combined slope strength

   // Crossover analysis
   bool              recentCrossover;    // Crossed within lookback candles?
   ENUM_CROSSOVER_TYPE crossoverType;    // Type of crossover
   int               candlesSinceCross;  // Candles since last cross
   bool              crossoverConfirmed; // Price action confirms crossover?

   datetime          timestamp;
   bool              isValid;            // Is data valid?
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
   double            strength;           // Zone strength score (legacy %)

   // NEW: Mathematical scoring fields (ATR-based)
   double            legOutDistance;     // Leg-out move distance in price units
   double            baseBodyMax;        // Max candle body in base area
   int               score;              // Zone quality score (0-13)
   bool              causedBOS;          // Did this zone lead to a BOS?
   bool              alignsWithFib;      // Does zone align with Fib level?
   double            atrAtFormation;     // ATR value when zone formed
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

string SlopeDirectionToString(ENUM_SLOPE_DIRECTION slope)
{
   switch(slope)
   {
      case SLOPE_RISING:  return "RISING";
      case SLOPE_FALLING: return "FALLING";
      case SLOPE_FLAT:    return "FLAT";
      default:            return "Unknown";
   }
}

string CrossoverTypeToString(ENUM_CROSSOVER_TYPE cross)
{
   switch(cross)
   {
      case CROSS_NONE:    return "NONE";
      case CROSS_BULLISH: return "GOLDEN CROSS";
      case CROSS_BEARISH: return "DEATH CROSS";
      default:            return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Initialize Symbol Info Cache                                      |
//| Properly detects Gold/Silver/JPY/Crypto and sets pip size         |
//+------------------------------------------------------------------+
void InitSymbolInfo(SymbolInfoCache &info, string symbol)
{
   info.symbol = symbol;
   info.digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   info.point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   info.tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   info.tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);

   // Convert symbol to uppercase for comparison
   string sym = symbol;
   StringToUpper(sym);

   // Detect Gold (XAU)
   info.isGold = (StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0);

   // Detect Silver (XAG)
   info.isSilver = (StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0);

   // Detect JPY pairs
   info.isJPY = (StringFind(sym, "JPY") >= 0);

   // Detect Crypto (BTC, ETH, LTC, XRP, etc.)
   info.isCrypto = (StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 ||
                    StringFind(sym, "LTC") >= 0 || StringFind(sym, "XRP") >= 0 ||
                    StringFind(sym, "BITCOIN") >= 0 || StringFind(sym, "CRYPTO") >= 0);

   // Set pip size based on instrument type
   if(info.isGold)
   {
      info.pipSize = 0.10;  // Gold: 1 pip = $0.10
   }
   else if(info.isSilver)
   {
      info.pipSize = 0.01;  // Silver: 1 pip = $0.01
   }
   else if(info.isCrypto)
   {
      // Crypto: varies by pair, typically 1.0 for BTC
      info.pipSize = 1.0;
   }
   else if(info.isJPY)
   {
      // JPY pairs: 2 or 3 digits
      info.pipSize = (info.digits == 3) ? 0.01 : 0.01;
   }
   else
   {
      // Standard Forex: 4 or 5 digits
      info.pipSize = (info.digits == 5) ? 0.0001 : 0.0001;
   }
}

//+------------------------------------------------------------------+
//| Convert Points to Pips using SymbolInfoCache                      |
//+------------------------------------------------------------------+
double PointsToPips(const SymbolInfoCache &info, double points)
{
   if(info.pipSize > 0)
      return points / info.pipSize;
   else
      return points / info.point;
}

//+------------------------------------------------------------------+
//| Convert Pips to Points using SymbolInfoCache                      |
//+------------------------------------------------------------------+
double PipsToPoints(const SymbolInfoCache &info, double pips)
{
   if(info.pipSize > 0)
      return pips * info.pipSize;
   else
      return pips * info.point;
}

//+------------------------------------------------------------------+
//| Instrument Profile Structure                                      |
//| Centralized settings that auto-adjust by instrument type          |
//+------------------------------------------------------------------+
struct InstrumentProfile
{
   // Instrument identification
   string            instrumentType;     // GOLD, SILVER, JPY, FOREX

   // RSI Settings (dynamic by volatility)
   int               rsiPeriod;          // RSI period (consistent: 14)
   int               rsiUpper;           // Overbought level
   int               rsiLower;           // Oversold level
   int               rsiNeutralUpper;    // Upper neutral zone
   int               rsiNeutralLower;    // Lower neutral zone

   // ATR Thresholds (for market condition)
   double            atrQuiet;           // Below = too quiet, skip
   double            atrNormal;          // Normal trading range
   double            atrExtreme;         // Above = extreme volatility

   // Zone Sizes (S/D, OB, FVG)
   double            minZonePips;        // Minimum zone size
   double            maxZonePips;        // Maximum zone size
   double            zoneBufferATR;      // Zone buffer as ATR multiplier

   // EMA Settings (consistent across instruments)
   int               emaFast;            // Fast EMA (50)
   int               emaSlow;            // Slow EMA (200)

   // Spread limits
   double            maxSpreadPips;      // Maximum acceptable spread

   // Fibonacci OTE zone
   double            oteUpperFib;        // OTE upper (61.8%)
   double            oteLowerFib;        // OTE lower (78.6%)
};

//+------------------------------------------------------------------+
//| Get Instrument Profile based on SymbolInfoCache                   |
//| Returns optimized settings for the detected instrument type       |
//+------------------------------------------------------------------+
InstrumentProfile GetInstrumentProfile(const SymbolInfoCache &info)
{
   InstrumentProfile p;

   // === CONSISTENT SETTINGS (same for all instruments) ===
   p.rsiPeriod = 14;           // Industry standard
   p.emaFast = 50;             // Standard fast EMA
   p.emaSlow = 200;            // Standard slow EMA
   p.oteUpperFib = 61.8;       // OTE zone upper
   p.oteLowerFib = 78.6;       // OTE zone lower
   p.zoneBufferATR = 0.2;      // 20% ATR buffer for zones

   // === DYNAMIC SETTINGS (vary by instrument) ===
   if(info.isCrypto)
   {
      p.instrumentType = "CRYPTO";
      // RSI: Very wide levels for extreme volatility
      p.rsiUpper = 80;         // Crypto can run further
      p.rsiLower = 20;
      p.rsiNeutralUpper = 65;
      p.rsiNeutralLower = 35;
      // ATR: Very high thresholds for Crypto volatility
      p.atrQuiet = 500;        // BTC < 500 = quiet
      p.atrNormal = 2000;      // Normal around 1000-2000
      p.atrExtreme = 5000;     // BTC > 5000 = extreme
      // Zones: Very large for Crypto
      p.minZonePips = 100;
      p.maxZonePips = 2000;
      // Spread: Crypto typically has variable spread
      p.maxSpreadPips = 50.0;
   }
   else if(info.isGold)
   {
      p.instrumentType = "GOLD";
      // RSI: Wider levels for high volatility
      p.rsiUpper = 75;
      p.rsiLower = 25;
      p.rsiNeutralUpper = 60;
      p.rsiNeutralLower = 40;
      // ATR: Much higher thresholds for Gold
      p.atrQuiet = 100;        // Gold < 100 pips = quiet
      p.atrNormal = 250;       // Normal around 150-250
      p.atrExtreme = 500;      // Gold > 500 = extreme
      // Zones: Larger for Gold volatility
      p.minZonePips = 20;
      p.maxZonePips = 300;
      // Spread: Gold typically has wider spread
      p.maxSpreadPips = 5.0;
   }
   else if(info.isSilver)
   {
      p.instrumentType = "SILVER";
      // RSI: Slightly wider than Forex
      p.rsiUpper = 73;
      p.rsiLower = 27;
      p.rsiNeutralUpper = 58;
      p.rsiNeutralLower = 42;
      // ATR: Silver is volatile but less than Gold
      p.atrQuiet = 50;
      p.atrNormal = 150;
      p.atrExtreme = 300;
      // Zones
      p.minZonePips = 15;
      p.maxZonePips = 200;
      // Spread
      p.maxSpreadPips = 4.0;
   }
   else if(info.isJPY)
   {
      p.instrumentType = "JPY";
      // RSI: Standard levels
      p.rsiUpper = 70;
      p.rsiLower = 30;
      p.rsiNeutralUpper = 55;
      p.rsiNeutralLower = 45;
      // ATR: JPY pairs moderate volatility
      p.atrQuiet = 40;
      p.atrNormal = 100;
      p.atrExtreme = 200;
      // Zones
      p.minZonePips = 10;
      p.maxZonePips = 150;
      // Spread
      p.maxSpreadPips = 3.0;
   }
   else  // Standard FOREX
   {
      p.instrumentType = "FOREX";
      // RSI: Standard levels
      p.rsiUpper = 70;
      p.rsiLower = 30;
      p.rsiNeutralUpper = 55;
      p.rsiNeutralLower = 45;
      // ATR: Standard Forex thresholds
      p.atrQuiet = 30;
      p.atrNormal = 80;
      p.atrExtreme = 150;
      // Zones
      p.minZonePips = 5;
      p.maxZonePips = 100;
      // Spread
      p.maxSpreadPips = 2.0;
   }

   return p;
}

//+------------------------------------------------------------------+
//| Check if RSI is in overbought zone                                |
//+------------------------------------------------------------------+
bool IsRSIOverbought(double rsi, const InstrumentProfile &profile)
{
   return (rsi >= profile.rsiUpper);
}

//+------------------------------------------------------------------+
//| Check if RSI is in oversold zone                                  |
//+------------------------------------------------------------------+
bool IsRSIOversold(double rsi, const InstrumentProfile &profile)
{
   return (rsi <= profile.rsiLower);
}

//+------------------------------------------------------------------+
//| Check if RSI is in neutral zone (good for entries)                |
//+------------------------------------------------------------------+
bool IsRSINeutral(double rsi, const InstrumentProfile &profile)
{
   return (rsi >= profile.rsiNeutralLower && rsi <= profile.rsiNeutralUpper);
}

//+------------------------------------------------------------------+
//| Check if ATR indicates quiet market                               |
//+------------------------------------------------------------------+
bool IsMarketQuiet(double atrPips, const InstrumentProfile &profile)
{
   return (atrPips < profile.atrQuiet);
}

//+------------------------------------------------------------------+
//| Check if ATR indicates extreme volatility                         |
//+------------------------------------------------------------------+
bool IsMarketExtreme(double atrPips, const InstrumentProfile &profile)
{
   return (atrPips > profile.atrExtreme);
}

//+------------------------------------------------------------------+
//| Check if ATR is in normal trading range                           |
//+------------------------------------------------------------------+
bool IsMarketNormal(double atrPips, const InstrumentProfile &profile)
{
   return (atrPips >= profile.atrQuiet && atrPips <= profile.atrExtreme);
}

//+------------------------------------------------------------------+
//| Check if spread is acceptable                                     |
//+------------------------------------------------------------------+
bool IsSpreadAcceptable(double spreadPips, const InstrumentProfile &profile)
{
   return (spreadPips <= profile.maxSpreadPips);
}

//+------------------------------------------------------------------+
//| Section Results Structure                                         |
//| Shared data structure for inter-section communication             |
//| Each section populates its results here for consolidation         |
//+------------------------------------------------------------------+
struct SectionResults
{
   // === Section 1: ATR Filter ===
   ATRFilterResult       atr;
   bool                  atrValid;

   // === Section 2: EMA Analysis ===
   EMAAnalysisResult     ema;
   bool                  emaValid;

   // === Section 3: Market Structure (BOS/CHoCH) ===
   StructureBreak        latestBOS;
   StructureBreak        latestCHoCH;
   ENUM_TREND_BIAS       structureBias;
   bool                  structureValid;

   // === Section 4: Supply/Demand Zones ===
   SDZone                activeZones[10];    // Up to 10 active zones
   int                   activeZoneCount;
   SDZone                nearestZone;        // Nearest to current price
   bool                  priceAtZone;
   bool                  sdValid;

   // === Section 5: Fibonacci ===
   FibAnalysis           fib;
   bool                  priceInOTE;         // In 61.8-78.6% zone
   double                nearestFibLevel;
   bool                  fibValid;

   // === Section 6: Momentum (RSI/MACD) ===
   double                rsiValue;
   double                macdMain;
   double                macdSignal;
   double                macdHistogram;
   bool                  rsiOverbought;
   bool                  rsiOversold;
   bool                  macdBullish;
   bool                  macdBearish;
   bool                  momentumValid;

   // === Section 7: Fair Value Gaps ===
   FVGap                 activeFVGs[10];     // Up to 10 active FVGs
   int                   activeFVGCount;
   FVGap                 nearestFVG;         // Nearest to current price
   bool                  priceAtFVG;
   bool                  fvgValid;

   // === Section 8: Order Blocks ===
   OrderBlock            activeOBs[10];      // Up to 10 active OBs
   int                   activeOBCount;
   OrderBlock            nearestOB;          // Nearest to current price
   bool                  priceAtOB;
   bool                  obValid;

   // === Section 9: News Filter ===
   bool                  newsImpactHigh;     // High-impact news nearby
   bool                  newsImpactMedium;
   int                   minutesToNews;      // Minutes until next news
   bool                  tradingAllowed;     // News filter allows trading
   bool                  newsValid;

   // === Section 10: MTF Analysis ===
   ENUM_TREND_BIAS       h4Bias;
   ENUM_TREND_BIAS       h1Bias;
   ENUM_TREND_BIAS       m15Bias;
   ENUM_TREND_BIAS       overallBias;
   int                   mtfScore;           // Combined MTF score
   bool                  mtfAligned;         // All timeframes aligned
   bool                  mtfValid;

   // === Combined Results ===
   ENUM_TREND_BIAS       masterBias;         // Final consolidated bias
   int                   confluenceScore;    // 0-10 score
   bool                  entryReady;         // All conditions met for entry

   // === Timestamps ===
   datetime              lastUpdateTime;
   datetime              section1Time;
   datetime              section2Time;
   datetime              section3Time;
   datetime              section4Time;
   datetime              section5Time;
   datetime              section6Time;
   datetime              section7Time;
   datetime              section8Time;
   datetime              section9Time;
   datetime              section10Time;
};

//+------------------------------------------------------------------+
//| Initialize Section Results to Default Values                      |
//+------------------------------------------------------------------+
void InitSectionResults(SectionResults &results)
{
   // Reset all validity flags
   results.atrValid = false;
   results.emaValid = false;
   results.structureValid = false;
   results.sdValid = false;
   results.fibValid = false;
   results.momentumValid = false;
   results.fvgValid = false;
   results.obValid = false;
   results.newsValid = false;
   results.mtfValid = false;

   // Reset counts
   results.activeZoneCount = 0;
   results.activeFVGCount = 0;
   results.activeOBCount = 0;

   // Reset flags
   results.priceAtZone = false;
   results.priceInOTE = false;
   results.priceAtFVG = false;
   results.priceAtOB = false;
   results.newsImpactHigh = false;
   results.newsImpactMedium = false;
   results.tradingAllowed = true;
   results.mtfAligned = false;
   results.entryReady = false;

   // Reset scores
   results.mtfScore = 0;
   results.confluenceScore = 0;

   // Reset biases
   results.structureBias = BIAS_NEUTRAL;
   results.h4Bias = BIAS_NEUTRAL;
   results.h1Bias = BIAS_NEUTRAL;
   results.m15Bias = BIAS_NEUTRAL;
   results.overallBias = BIAS_NEUTRAL;
   results.masterBias = BIAS_NEUTRAL;

   // Reset timestamps
   results.lastUpdateTime = 0;
   results.section1Time = 0;
   results.section2Time = 0;
   results.section3Time = 0;
   results.section4Time = 0;
   results.section5Time = 0;
   results.section6Time = 0;
   results.section7Time = 0;
   results.section8Time = 0;
   results.section9Time = 0;
   results.section10Time = 0;
}

//+------------------------------------------------------------------+
//| Calculate Confluence Score from Section Results                   |
//| Returns 0-10 score based on how many conditions are met           |
//+------------------------------------------------------------------+
int CalculateConfluenceFromResults(const SectionResults &results)
{
   int score = 0;

   // 1. ATR conditions OK (not quiet, not extreme)
   if(results.atrValid && results.atr.tradingAllowed)
      score++;

   // 2. EMA trend aligned
   if(results.emaValid && results.ema.trend != BIAS_NEUTRAL)
      score++;

   // 3. Structure break confirmed
   if(results.structureValid &&
      (results.latestBOS.type != STRUCTURE_NONE || results.latestCHoCH.type != STRUCTURE_NONE))
      score++;

   // 4. Price at S/D zone
   if(results.sdValid && results.priceAtZone)
      score++;

   // 5. Price in OTE zone
   if(results.fibValid && results.priceInOTE)
      score++;

   // 6. RSI confirms (not extreme)
   if(results.momentumValid && !results.rsiOverbought && !results.rsiOversold)
      score++;

   // 7. MACD aligned with bias
   if(results.momentumValid && (results.macdBullish || results.macdBearish))
      score++;

   // 8. Price at FVG
   if(results.fvgValid && results.priceAtFVG)
      score++;

   // 9. Price at Order Block
   if(results.obValid && results.priceAtOB)
      score++;

   // 10. MTF aligned
   if(results.mtfValid && results.mtfAligned)
      score++;

   return score;
}

//+------------------------------------------------------------------+
//| Check if Entry Conditions are Met                                 |
//+------------------------------------------------------------------+
bool IsEntryReady(const SectionResults &results, int minConfluence = 6)
{
   // Must have valid data from key sections
   if(!results.atrValid || !results.emaValid || !results.mtfValid)
      return false;

   // News must allow trading
   if(results.newsValid && !results.tradingAllowed)
      return false;

   // ATR must allow trading
   if(!results.atr.tradingAllowed)
      return false;

   // Confluence must meet minimum
   if(results.confluenceScore < minConfluence)
      return false;

   // Must have a clear bias
   if(results.masterBias == BIAS_NEUTRAL)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Get Signal Strength from Confluence Score                         |
//+------------------------------------------------------------------+
ENUM_SIGNAL_STRENGTH GetStrengthFromConfluence(int confluenceScore)
{
   if(confluenceScore >= 8)
      return SIGNAL_STRONG;
   else if(confluenceScore >= 6)
      return SIGNAL_MODERATE;
   else if(confluenceScore >= 4)
      return SIGNAL_WEAK;
   else
      return SIGNAL_NONE;
}

//+------------------------------------------------------------------+
