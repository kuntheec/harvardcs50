//+------------------------------------------------------------------+
//|                                                  SMCModules.mqh   |
//|                      SwingTrader Pro - SMC Analysis Modules       |
//|                              Unified Include for Section 14       |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property version   "1.00"

//+------------------------------------------------------------------+
//| Shared Enumerations                                               |
//+------------------------------------------------------------------+
enum ENUM_MARKET_TREND
{
   TREND_BULLISH,
   TREND_BEARISH,
   TREND_RANGING
};

enum ENUM_SIGNAL_DIRECTION
{
   DIRECTION_NONE,
   DIRECTION_BUY,
   DIRECTION_SELL
};

enum ENUM_ZONE_TYPE
{
   ZONE_SUPPLY,
   ZONE_DEMAND,
   ZONE_NONE
};

enum ENUM_SESSION_TYPE
{
   SESSION_ASIA,
   SESSION_LONDON,
   SESSION_NEWYORK,
   SESSION_OVERLAP,
   SESSION_OFFHOURS
};

//+------------------------------------------------------------------+
//| Section Results Structure - Data from All Sections                |
//+------------------------------------------------------------------+
struct SectionResults
{
   // Section 3: Market Structure
   ENUM_MARKET_TREND marketTrend;
   bool              bosConfirmed;
   bool              chochDetected;
   double            lastSwingHigh;
   double            lastSwingLow;
   double            bosLevel;

   // Section 4: Supply/Demand
   bool              inSupplyZone;
   bool              inDemandZone;
   double            supplyZoneHigh;
   double            supplyZoneLow;
   double            demandZoneHigh;
   double            demandZoneLow;
   int               supplyStrength;
   int               demandStrength;

   // Section 5: Liquidity
   bool              liquiditySwept;
   bool              eqlTaken;
   bool              eqhTaken;
   double            liquidityLevel;
   double            stopHuntDetected;

   // Section 6: Sessions & News
   ENUM_SESSION_TYPE currentSession;
   bool              sessionActive;
   bool              inKillzone;
   bool              newsUpcoming;
   bool              newsHighImpact;
   int               minsToNews;

   // Section 7: FVG
   bool              bullishFVGPresent;
   bool              bearishFVGPresent;
   bool              priceInFVG;
   double            fvgHigh;
   double            fvgLow;
   double            fvgMidpoint;
   int               fvgCount;

   // Section 8: Order Blocks
   bool              bullishOBPresent;
   bool              bearishOBPresent;
   bool              priceInOB;
   double            obHigh;
   double            obLow;
   int               obStrength;
   bool              obFresh;

   // Section 9: Fibonacci/OTE
   bool              inOTEZone;
   double            oteHigh;
   double            oteLow;
   double            currentFibLevel;
   double            goldenPocket618;
   double            goldenPocket65;

   // Section 10: Killzones
   bool              htfTrendBullish;
   bool              htfTrendBearish;
   bool              ltfEntryValid;
   bool              htfLtfAligned;
   double            htfPOI;

   // Section 11: Confluence
   int               confluenceScore;
   int               bullishFactors;
   int               bearishFactors;
   bool              signalStrong;
   bool              signalModerate;
   bool              signalWeak;

   // Section 12: Risk
   double            recommendedLotSize;
   double            riskPercent;
   bool              canTrade;
   bool              inRecoveryMode;
   double            currentExposure;

   // Section 1: ATR Filter (from Section01_ATRFilter.mq5)
   double            atrValue;
   double            atrPips;
   double            atrAverage;
   double            atrPercentile;
   double            normalizedATR;
   bool              volatilitySqueeze;
   bool              volatilityExpanding;
   bool              volatilityContracting;
   string            volatilityCondition;      // "QUIET", "NORMAL", "EXTREME"
   string            volatilityTrend;          // "EXPANDING", "CONTRACTING", "STABLE"
   bool              atrFilterPass;            // True if volatility is tradeable

   // Section 2: EMA Analysis (from Section02_EMAAnalysis.mq5)
   double            emaFast;                  // EMA 50
   double            emaSlow;                  // EMA 200
   double            emaSpread;                // Distance between EMAs
   double            emaSpreadPercent;         // Spread as % of price
   double            emaFastSlope;             // EMA 50 slope
   double            emaSlowSlope;             // EMA 200 slope
   bool              emaBullish;               // Price above both EMAs
   bool              emaBearish;               // Price below both EMAs
   bool              emaCrossoverBullish;      // Recent golden cross
   bool              emaCrossoverBearish;      // Recent death cross
   string            emaTrendBias;             // "BULLISH", "BEARISH", "NEUTRAL"

   // Final Signal
   ENUM_SIGNAL_DIRECTION signalDirection;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit1;
   double            takeProfit2;
   double            takeProfit3;
   string            signalReason;
};

//+------------------------------------------------------------------+
//| Global Section Results                                            |
//+------------------------------------------------------------------+
SectionResults g_sectionResults;

//+------------------------------------------------------------------+
//| Section 3: Market Structure Analysis                              |
//+------------------------------------------------------------------+
class CMarketStructure
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_lookback;

   double            m_swingHighs[];
   double            m_swingLows[];
   int               m_swingHighBars[];
   int               m_swingLowBars[];

public:
   void Init(string symbol, ENUM_TIMEFRAMES tf, int lookback = 100)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_lookback = lookback;
   }

   void Analyze()
   {
      FindSwingPoints();
      DetermineTrend();
      DetectBOS();
      DetectCHoCH();
   }

   void FindSwingPoints()
   {
      ArrayResize(m_swingHighs, 0);
      ArrayResize(m_swingLows, 0);
      ArrayResize(m_swingHighBars, 0);
      ArrayResize(m_swingLowBars, 0);

      for(int i = 2; i < m_lookback - 2; i++)
      {
         double high = iHigh(m_symbol, m_timeframe, i);
         double low = iLow(m_symbol, m_timeframe, i);

         // Swing High: higher than 2 bars on each side
         if(high > iHigh(m_symbol, m_timeframe, i-1) &&
            high > iHigh(m_symbol, m_timeframe, i-2) &&
            high > iHigh(m_symbol, m_timeframe, i+1) &&
            high > iHigh(m_symbol, m_timeframe, i+2))
         {
            int size = ArraySize(m_swingHighs);
            ArrayResize(m_swingHighs, size + 1);
            ArrayResize(m_swingHighBars, size + 1);
            m_swingHighs[size] = high;
            m_swingHighBars[size] = i;
         }

         // Swing Low
         if(low < iLow(m_symbol, m_timeframe, i-1) &&
            low < iLow(m_symbol, m_timeframe, i-2) &&
            low < iLow(m_symbol, m_timeframe, i+1) &&
            low < iLow(m_symbol, m_timeframe, i+2))
         {
            int size = ArraySize(m_swingLows);
            ArrayResize(m_swingLows, size + 1);
            ArrayResize(m_swingLowBars, size + 1);
            m_swingLows[size] = low;
            m_swingLowBars[size] = i;
         }
      }

      // Store most recent swings
      if(ArraySize(m_swingHighs) > 0)
         g_sectionResults.lastSwingHigh = m_swingHighs[0];
      if(ArraySize(m_swingLows) > 0)
         g_sectionResults.lastSwingLow = m_swingLows[0];
   }

   void DetermineTrend()
   {
      if(ArraySize(m_swingHighs) < 2 || ArraySize(m_swingLows) < 2)
      {
         g_sectionResults.marketTrend = TREND_RANGING;
         return;
      }

      // Higher highs and higher lows = Bullish
      bool higherHighs = m_swingHighs[0] > m_swingHighs[1];
      bool higherLows = m_swingLows[0] > m_swingLows[1];

      // Lower highs and lower lows = Bearish
      bool lowerHighs = m_swingHighs[0] < m_swingHighs[1];
      bool lowerLows = m_swingLows[0] < m_swingLows[1];

      if(higherHighs && higherLows)
         g_sectionResults.marketTrend = TREND_BULLISH;
      else if(lowerHighs && lowerLows)
         g_sectionResults.marketTrend = TREND_BEARISH;
      else
         g_sectionResults.marketTrend = TREND_RANGING;
   }

   void DetectBOS()
   {
      g_sectionResults.bosConfirmed = false;

      double close = iClose(m_symbol, m_timeframe, 0);

      if(ArraySize(m_swingHighs) > 0 && ArraySize(m_swingLows) > 0)
      {
         // Bullish BOS: Close above previous swing high
         if(close > m_swingHighs[0] && g_sectionResults.marketTrend == TREND_BULLISH)
         {
            g_sectionResults.bosConfirmed = true;
            g_sectionResults.bosLevel = m_swingHighs[0];
         }
         // Bearish BOS: Close below previous swing low
         else if(close < m_swingLows[0] && g_sectionResults.marketTrend == TREND_BEARISH)
         {
            g_sectionResults.bosConfirmed = true;
            g_sectionResults.bosLevel = m_swingLows[0];
         }
      }
   }

   void DetectCHoCH()
   {
      g_sectionResults.chochDetected = false;

      double close = iClose(m_symbol, m_timeframe, 0);

      if(ArraySize(m_swingLows) >= 2 && ArraySize(m_swingHighs) >= 2)
      {
         // Bullish CHoCH: Was bearish, now breaking above swing high
         if(g_sectionResults.marketTrend == TREND_BEARISH && close > m_swingHighs[0])
            g_sectionResults.chochDetected = true;
         // Bearish CHoCH: Was bullish, now breaking below swing low
         else if(g_sectionResults.marketTrend == TREND_BULLISH && close < m_swingLows[0])
            g_sectionResults.chochDetected = true;
      }
   }

   // Getters
   ENUM_MARKET_TREND GetTrend() { return g_sectionResults.marketTrend; }
   bool IsBOSConfirmed() { return g_sectionResults.bosConfirmed; }
   bool IsCHoCHDetected() { return g_sectionResults.chochDetected; }
   double GetLastSwingHigh() { return g_sectionResults.lastSwingHigh; }
   double GetLastSwingLow() { return g_sectionResults.lastSwingLow; }
};

//+------------------------------------------------------------------+
//| Section 7: Fair Value Gap Analysis                                |
//+------------------------------------------------------------------+
class CFairValueGap
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_lookback;
   double            m_minGapATR;

public:
   void Init(string symbol, ENUM_TIMEFRAMES tf, int lookback = 50, double minGapATR = 0.1)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_lookback = lookback;
      m_minGapATR = minGapATR;
   }

   void Analyze()
   {
      g_sectionResults.bullishFVGPresent = false;
      g_sectionResults.bearishFVGPresent = false;
      g_sectionResults.priceInFVG = false;
      g_sectionResults.fvgCount = 0;

      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);

      for(int i = 1; i < m_lookback - 2; i++)
      {
         double high1 = iHigh(m_symbol, m_timeframe, i);
         double low1 = iLow(m_symbol, m_timeframe, i);
         double high3 = iHigh(m_symbol, m_timeframe, i + 2);
         double low3 = iLow(m_symbol, m_timeframe, i + 2);

         // Bullish FVG: Gap between candle 3 high and candle 1 low
         if(low1 > high3)
         {
            g_sectionResults.bullishFVGPresent = true;
            g_sectionResults.fvgHigh = low1;
            g_sectionResults.fvgLow = high3;
            g_sectionResults.fvgMidpoint = (low1 + high3) / 2;
            g_sectionResults.fvgCount++;

            if(currentPrice >= high3 && currentPrice <= low1)
            {
               g_sectionResults.priceInFVG = true;
               break;
            }
         }

         // Bearish FVG: Gap between candle 1 high and candle 3 low
         if(high1 < low3)
         {
            g_sectionResults.bearishFVGPresent = true;
            g_sectionResults.fvgHigh = low3;
            g_sectionResults.fvgLow = high1;
            g_sectionResults.fvgMidpoint = (low3 + high1) / 2;
            g_sectionResults.fvgCount++;

            if(currentPrice >= high1 && currentPrice <= low3)
            {
               g_sectionResults.priceInFVG = true;
               break;
            }
         }
      }
   }

   bool HasBullishFVG() { return g_sectionResults.bullishFVGPresent; }
   bool HasBearishFVG() { return g_sectionResults.bearishFVGPresent; }
   bool IsPriceInFVG() { return g_sectionResults.priceInFVG; }
};

//+------------------------------------------------------------------+
//| Section 8: Order Block Analysis                                   |
//+------------------------------------------------------------------+
class COrderBlock
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_lookback;
   int               m_atrHandle;
   double            m_atrBuffer[];

public:
   void Init(string symbol, ENUM_TIMEFRAMES tf, int lookback = 50)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_lookback = lookback;
      m_atrHandle = iATR(symbol, tf, 14);
      ArraySetAsSeries(m_atrBuffer, true);
   }

   void Analyze()
   {
      g_sectionResults.bullishOBPresent = false;
      g_sectionResults.bearishOBPresent = false;
      g_sectionResults.priceInOB = false;
      g_sectionResults.obFresh = false;

      CopyBuffer(m_atrHandle, 0, 0, 3, m_atrBuffer);
      double atr = m_atrBuffer[0];
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);

      for(int i = 1; i < m_lookback - 1; i++)
      {
         double open = iOpen(m_symbol, m_timeframe, i);
         double close = iClose(m_symbol, m_timeframe, i);
         double high = iHigh(m_symbol, m_timeframe, i);
         double low = iLow(m_symbol, m_timeframe, i);
         double nextClose = iClose(m_symbol, m_timeframe, i - 1);
         double nextHigh = iHigh(m_symbol, m_timeframe, i - 1);
         double nextLow = iLow(m_symbol, m_timeframe, i - 1);
         double body = MathAbs(close - open);

         // Bullish OB: Last bearish candle before strong bullish move
         if(close < open && nextClose > high && body > atr * 0.3)
         {
            g_sectionResults.bullishOBPresent = true;
            g_sectionResults.obHigh = open;
            g_sectionResults.obLow = close;
            g_sectionResults.obStrength = (int)((body / atr) * 10);
            g_sectionResults.obFresh = (i <= 5);

            if(currentPrice >= close && currentPrice <= open)
            {
               g_sectionResults.priceInOB = true;
               break;
            }
         }

         // Bearish OB: Last bullish candle before strong bearish move
         if(close > open && nextClose < low && body > atr * 0.3)
         {
            g_sectionResults.bearishOBPresent = true;
            g_sectionResults.obHigh = close;
            g_sectionResults.obLow = open;
            g_sectionResults.obStrength = (int)((body / atr) * 10);
            g_sectionResults.obFresh = (i <= 5);

            if(currentPrice >= open && currentPrice <= close)
            {
               g_sectionResults.priceInOB = true;
               break;
            }
         }
      }
   }

   bool HasBullishOB() { return g_sectionResults.bullishOBPresent; }
   bool HasBearishOB() { return g_sectionResults.bearishOBPresent; }
   bool IsPriceInOB() { return g_sectionResults.priceInOB; }
};

//+------------------------------------------------------------------+
//| Section 5: Liquidity Analysis                                     |
//+------------------------------------------------------------------+
class CLiquidity
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_lookback;

public:
   void Init(string symbol, ENUM_TIMEFRAMES tf, int lookback = 50)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_lookback = lookback;
   }

   void Analyze()
   {
      g_sectionResults.liquiditySwept = false;
      g_sectionResults.eqlTaken = false;
      g_sectionResults.eqhTaken = false;

      double currentHigh = iHigh(m_symbol, m_timeframe, 0);
      double currentLow = iLow(m_symbol, m_timeframe, 0);
      double prevHigh = iHigh(m_symbol, m_timeframe, 1);
      double prevLow = iLow(m_symbol, m_timeframe, 1);
      double close = iClose(m_symbol, m_timeframe, 0);

      // Liquidity sweep: Price exceeds level then reverses
      // Bullish sweep (took lows, closing back up)
      if(currentLow < prevLow && close > prevLow)
      {
         g_sectionResults.liquiditySwept = true;
         g_sectionResults.liquidityLevel = prevLow;
      }

      // Bearish sweep (took highs, closing back down)
      if(currentHigh > prevHigh && close < prevHigh)
      {
         g_sectionResults.liquiditySwept = true;
         g_sectionResults.liquidityLevel = prevHigh;
      }

      // Check for equal highs/lows
      double tolerance = (currentHigh - currentLow) * 0.1;

      for(int i = 2; i < m_lookback; i++)
      {
         double h = iHigh(m_symbol, m_timeframe, i);
         double l = iLow(m_symbol, m_timeframe, i);

         // Equal highs taken
         if(MathAbs(h - prevHigh) < tolerance && currentHigh > h + tolerance)
         {
            g_sectionResults.eqhTaken = true;
            g_sectionResults.liquiditySwept = true;
         }

         // Equal lows taken
         if(MathAbs(l - prevLow) < tolerance && currentLow < l - tolerance)
         {
            g_sectionResults.eqlTaken = true;
            g_sectionResults.liquiditySwept = true;
         }
      }
   }

   bool IsLiquiditySwept() { return g_sectionResults.liquiditySwept; }
   bool IsEQLTaken() { return g_sectionResults.eqlTaken; }
   bool IsEQHTaken() { return g_sectionResults.eqhTaken; }
};

//+------------------------------------------------------------------+
//| Section 9: Fibonacci/OTE Analysis                                 |
//+------------------------------------------------------------------+
class CFibonacci
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

public:
   void Init(string symbol, ENUM_TIMEFRAMES tf)
   {
      m_symbol = symbol;
      m_timeframe = tf;
   }

   void Analyze()
   {
      g_sectionResults.inOTEZone = false;

      double swingHigh = g_sectionResults.lastSwingHigh;
      double swingLow = g_sectionResults.lastSwingLow;

      if(swingHigh == 0 || swingLow == 0) return;

      double range = swingHigh - swingLow;
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);

      // OTE Zone: 61.8% - 78.6% retracement
      if(g_sectionResults.marketTrend == TREND_BULLISH)
      {
         // Uptrend: OTE is retracement from high
         g_sectionResults.goldenPocket618 = swingHigh - (range * 0.618);
         g_sectionResults.goldenPocket65 = swingHigh - (range * 0.65);
         g_sectionResults.oteHigh = swingHigh - (range * 0.618);
         g_sectionResults.oteLow = swingHigh - (range * 0.786);

         if(currentPrice <= g_sectionResults.oteHigh && currentPrice >= g_sectionResults.oteLow)
         {
            g_sectionResults.inOTEZone = true;
            g_sectionResults.currentFibLevel = (swingHigh - currentPrice) / range;
         }
      }
      else if(g_sectionResults.marketTrend == TREND_BEARISH)
      {
         // Downtrend: OTE is retracement from low
         g_sectionResults.goldenPocket618 = swingLow + (range * 0.618);
         g_sectionResults.goldenPocket65 = swingLow + (range * 0.65);
         g_sectionResults.oteHigh = swingLow + (range * 0.786);
         g_sectionResults.oteLow = swingLow + (range * 0.618);

         if(currentPrice >= g_sectionResults.oteLow && currentPrice <= g_sectionResults.oteHigh)
         {
            g_sectionResults.inOTEZone = true;
            g_sectionResults.currentFibLevel = (currentPrice - swingLow) / range;
         }
      }
   }

   bool IsInOTE() { return g_sectionResults.inOTEZone; }
   double GetFibLevel() { return g_sectionResults.currentFibLevel; }
};

//+------------------------------------------------------------------+
//| Section 6: Session Analysis                                       |
//+------------------------------------------------------------------+
class CSessionAnalysis
{
private:
   int m_asiaStart, m_asiaEnd;
   int m_londonStart, m_londonEnd;
   int m_nyStart, m_nyEnd;

public:
   void Init(int asiaStart = 0, int asiaEnd = 8,
             int londonStart = 8, int londonEnd = 16,
             int nyStart = 13, int nyEnd = 21)
   {
      m_asiaStart = asiaStart;
      m_asiaEnd = asiaEnd;
      m_londonStart = londonStart;
      m_londonEnd = londonEnd;
      m_nyStart = nyStart;
      m_nyEnd = nyEnd;
   }

   void Analyze()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      int hour = dt.hour;

      if(hour >= m_asiaStart && hour < m_asiaEnd)
      {
         g_sectionResults.currentSession = SESSION_ASIA;
         g_sectionResults.sessionActive = true;
      }
      else if(hour >= m_londonStart && hour < m_nyStart)
      {
         g_sectionResults.currentSession = SESSION_LONDON;
         g_sectionResults.sessionActive = true;
         g_sectionResults.inKillzone = true;
      }
      else if(hour >= m_nyStart && hour < m_londonEnd)
      {
         g_sectionResults.currentSession = SESSION_OVERLAP;
         g_sectionResults.sessionActive = true;
         g_sectionResults.inKillzone = true;
      }
      else if(hour >= m_londonEnd && hour < m_nyEnd)
      {
         g_sectionResults.currentSession = SESSION_NEWYORK;
         g_sectionResults.sessionActive = true;
      }
      else
      {
         g_sectionResults.currentSession = SESSION_OFFHOURS;
         g_sectionResults.sessionActive = false;
      }
   }

   bool IsSessionActive() { return g_sectionResults.sessionActive; }
   bool IsInKillzone() { return g_sectionResults.inKillzone; }
   ENUM_SESSION_TYPE GetCurrentSession() { return g_sectionResults.currentSession; }
};

//+------------------------------------------------------------------+
//| Section 1: ATR Filter (from Section01_ATRFilter.mq5)              |
//+------------------------------------------------------------------+
class CATRFilter
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_atrHandle;
   int               m_atrPeriod;
   double            m_atrBuffer[];
   double            m_pipValue;
   string            m_instrumentType;

   // Thresholds
   double            m_quietThreshold;
   double            m_extremeThreshold;
   double            m_expandThresh;
   double            m_contractThresh;
   double            m_squeezeThresh;
   int               m_trendBars;
   int               m_percentileBars;

public:
   void Init(string symbol, ENUM_TIMEFRAMES tf, int period = 14,
             double quietThresh = 60.0, double extremeThresh = 250.0)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_atrPeriod = period;
      m_quietThreshold = quietThresh;
      m_extremeThreshold = extremeThresh;
      m_expandThresh = 1.2;
      m_contractThresh = 0.8;
      m_squeezeThresh = 0.6;
      m_trendBars = 10;
      m_percentileBars = 50;

      // Create ATR handle
      m_atrHandle = iATR(symbol, tf, period);
      ArraySetAsSeries(m_atrBuffer, true);

      // Auto-detect instrument type for pip value
      string sym = symbol;
      StringToUpper(sym);

      if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
      {
         m_instrumentType = "GOLD";
         m_pipValue = 0.10;
      }
      else if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
      {
         m_instrumentType = "SILVER";
         m_pipValue = 0.01;
      }
      else if(StringFind(sym, "JPY") >= 0)
      {
         m_instrumentType = "JPY";
         int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         m_pipValue = SymbolInfoDouble(symbol, SYMBOL_POINT) * (digits == 3 ? 1 : 10);
      }
      else
      {
         m_instrumentType = "FOREX";
         int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         m_pipValue = SymbolInfoDouble(symbol, SYMBOL_POINT) * (digits == 5 ? 10 : 1);
      }
   }

   void Analyze()
   {
      if(m_atrHandle == INVALID_HANDLE) return;

      // Copy ATR buffer
      int copied = CopyBuffer(m_atrHandle, 0, 0, m_percentileBars + 10, m_atrBuffer);
      if(copied < m_percentileBars) return;

      // Current ATR value
      g_sectionResults.atrValue = m_atrBuffer[0];
      g_sectionResults.atrPips = m_atrBuffer[0] / m_pipValue;

      // Normalized ATR (as % of price)
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      g_sectionResults.normalizedATR = (m_atrBuffer[0] / currentPrice) * 100;

      // Calculate ATR average
      double atrSum = 0;
      for(int i = 0; i < m_percentileBars; i++)
         atrSum += m_atrBuffer[i];
      g_sectionResults.atrAverage = atrSum / m_percentileBars;

      // Calculate ATR percentile
      int countBelow = 0;
      for(int i = 1; i < m_percentileBars; i++)
      {
         if(m_atrBuffer[i] < m_atrBuffer[0])
            countBelow++;
      }
      g_sectionResults.atrPercentile = ((double)countBelow / (m_percentileBars - 1)) * 100;

      // Volatility condition
      if(g_sectionResults.atrPips < m_quietThreshold)
      {
         g_sectionResults.volatilityCondition = "QUIET";
         g_sectionResults.atrFilterPass = false;  // Don't trade in quiet markets
      }
      else if(g_sectionResults.atrPips > m_extremeThreshold)
      {
         g_sectionResults.volatilityCondition = "EXTREME";
         g_sectionResults.atrFilterPass = false;  // Don't trade in extreme volatility
      }
      else
      {
         g_sectionResults.volatilityCondition = "NORMAL";
         g_sectionResults.atrFilterPass = true;   // Good to trade
      }

      // Volatility trend (expanding/contracting)
      double ratio = m_atrBuffer[0] / g_sectionResults.atrAverage;

      if(ratio >= m_expandThresh)
      {
         g_sectionResults.volatilityExpanding = true;
         g_sectionResults.volatilityContracting = false;
         g_sectionResults.volatilityTrend = "EXPANDING";
      }
      else if(ratio <= m_contractThresh)
      {
         g_sectionResults.volatilityExpanding = false;
         g_sectionResults.volatilityContracting = true;
         g_sectionResults.volatilityTrend = "CONTRACTING";
      }
      else
      {
         g_sectionResults.volatilityExpanding = false;
         g_sectionResults.volatilityContracting = false;
         g_sectionResults.volatilityTrend = "STABLE";
      }

      // Volatility squeeze detection
      g_sectionResults.volatilitySqueeze = (ratio <= m_squeezeThresh);
   }

   // Getters
   double GetATR() { return g_sectionResults.atrValue; }
   double GetATRPips() { return g_sectionResults.atrPips; }
   bool IsFilterPass() { return g_sectionResults.atrFilterPass; }
   string GetVolatilityCondition() { return g_sectionResults.volatilityCondition; }
   string GetInstrumentType() { return m_instrumentType; }
   double GetPipValue() { return m_pipValue; }
};

//+------------------------------------------------------------------+
//| Section 2: EMA Analysis (from Section02_EMAAnalysis.mq5)          |
//+------------------------------------------------------------------+
class CEMAAnalysis
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_emaFastHandle;
   int               m_emaSlowHandle;
   int               m_fastPeriod;
   int               m_slowPeriod;
   int               m_slopePeriod;
   int               m_crossoverLookback;
   double            m_emaFastBuffer[];
   double            m_emaSlowBuffer[];

public:
   void Init(string symbol, ENUM_TIMEFRAMES tf, int fastPeriod = 50, int slowPeriod = 200,
             int slopePeriod = 5, int crossoverLookback = 10)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_fastPeriod = fastPeriod;
      m_slowPeriod = slowPeriod;
      m_slopePeriod = slopePeriod;
      m_crossoverLookback = crossoverLookback;

      // Create EMA handles
      m_emaFastHandle = iMA(symbol, tf, fastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      m_emaSlowHandle = iMA(symbol, tf, slowPeriod, 0, MODE_EMA, PRICE_CLOSE);

      ArraySetAsSeries(m_emaFastBuffer, true);
      ArraySetAsSeries(m_emaSlowBuffer, true);
   }

   void Analyze()
   {
      if(m_emaFastHandle == INVALID_HANDLE || m_emaSlowHandle == INVALID_HANDLE) return;

      // Copy EMA buffers
      int bars = m_crossoverLookback + m_slopePeriod + 5;
      if(CopyBuffer(m_emaFastHandle, 0, 0, bars, m_emaFastBuffer) < bars) return;
      if(CopyBuffer(m_emaSlowHandle, 0, 0, bars, m_emaSlowBuffer) < bars) return;

      // Current EMA values
      g_sectionResults.emaFast = m_emaFastBuffer[0];
      g_sectionResults.emaSlow = m_emaSlowBuffer[0];

      // EMA spread
      g_sectionResults.emaSpread = m_emaFastBuffer[0] - m_emaSlowBuffer[0];
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      g_sectionResults.emaSpreadPercent = (g_sectionResults.emaSpread / currentPrice) * 100;

      // Calculate EMA slopes
      g_sectionResults.emaFastSlope = (m_emaFastBuffer[0] - m_emaFastBuffer[m_slopePeriod]) / m_slopePeriod;
      g_sectionResults.emaSlowSlope = (m_emaSlowBuffer[0] - m_emaSlowBuffer[m_slopePeriod]) / m_slopePeriod;

      // Price position relative to EMAs
      g_sectionResults.emaBullish = (currentPrice > m_emaFastBuffer[0] && currentPrice > m_emaSlowBuffer[0]);
      g_sectionResults.emaBearish = (currentPrice < m_emaFastBuffer[0] && currentPrice < m_emaSlowBuffer[0]);

      // Crossover detection
      g_sectionResults.emaCrossoverBullish = false;
      g_sectionResults.emaCrossoverBearish = false;

      for(int i = 0; i < m_crossoverLookback; i++)
      {
         // Golden cross: Fast crosses above Slow
         if(m_emaFastBuffer[i] > m_emaSlowBuffer[i] &&
            m_emaFastBuffer[i+1] <= m_emaSlowBuffer[i+1])
         {
            g_sectionResults.emaCrossoverBullish = true;
            break;
         }
         // Death cross: Fast crosses below Slow
         if(m_emaFastBuffer[i] < m_emaSlowBuffer[i] &&
            m_emaFastBuffer[i+1] >= m_emaSlowBuffer[i+1])
         {
            g_sectionResults.emaCrossoverBearish = true;
            break;
         }
      }

      // Overall trend bias
      if(g_sectionResults.emaBullish && m_emaFastBuffer[0] > m_emaSlowBuffer[0])
         g_sectionResults.emaTrendBias = "BULLISH";
      else if(g_sectionResults.emaBearish && m_emaFastBuffer[0] < m_emaSlowBuffer[0])
         g_sectionResults.emaTrendBias = "BEARISH";
      else
         g_sectionResults.emaTrendBias = "NEUTRAL";
   }

   // Getters
   double GetEMAFast() { return g_sectionResults.emaFast; }
   double GetEMASlow() { return g_sectionResults.emaSlow; }
   bool IsBullish() { return g_sectionResults.emaBullish; }
   bool IsBearish() { return g_sectionResults.emaBearish; }
   string GetTrendBias() { return g_sectionResults.emaTrendBias; }
   bool HasGoldenCross() { return g_sectionResults.emaCrossoverBullish; }
   bool HasDeathCross() { return g_sectionResults.emaCrossoverBearish; }
};

//+------------------------------------------------------------------+
//| Section 11: Confluence Calculator                                 |
//+------------------------------------------------------------------+
class CConfluence
{
public:
   void Calculate()
   {
      int score = 0;
      g_sectionResults.bullishFactors = 0;
      g_sectionResults.bearishFactors = 0;

      // Market Structure (+2)
      if(g_sectionResults.bosConfirmed)
         score += 2;

      // In Zone (+1 each)
      if(g_sectionResults.inSupplyZone)
      {
         score += 1;
         g_sectionResults.bearishFactors++;
      }
      if(g_sectionResults.inDemandZone)
      {
         score += 1;
         g_sectionResults.bullishFactors++;
      }

      // Liquidity Swept (+1)
      if(g_sectionResults.liquiditySwept)
         score += 1;

      // Session Active (+1)
      if(g_sectionResults.sessionActive)
         score += 1;

      // FVG (+1)
      if(g_sectionResults.priceInFVG || g_sectionResults.bullishFVGPresent || g_sectionResults.bearishFVGPresent)
         score += 1;

      // Order Block (+1)
      if(g_sectionResults.priceInOB || g_sectionResults.bullishOBPresent || g_sectionResults.bearishOBPresent)
         score += 1;

      // OTE Zone (+2)
      if(g_sectionResults.inOTEZone)
         score += 2;

      // HTF/LTF Alignment (+1)
      if(g_sectionResults.htfLtfAligned)
         score += 1;

      g_sectionResults.confluenceScore = MathMin(score, 10);

      // Signal strength
      g_sectionResults.signalStrong = (score >= 8);
      g_sectionResults.signalModerate = (score >= 6 && score < 8);
      g_sectionResults.signalWeak = (score >= 4 && score < 6);
   }

   int GetScore() { return g_sectionResults.confluenceScore; }
   bool IsStrong() { return g_sectionResults.signalStrong; }
   bool IsModerate() { return g_sectionResults.signalModerate; }
};

//+------------------------------------------------------------------+
//| Master SMC Analyzer - Calls All Modules                           |
//+------------------------------------------------------------------+
class CMasterSMC
{
private:
   // Section 1 & 2: ATR and EMA
   CATRFilter        m_atrFilter;
   CEMAAnalysis      m_emaAnalysis;

   // Section 3-11: SMC Modules
   CMarketStructure  m_structure;
   CFairValueGap     m_fvg;
   COrderBlock       m_orderBlock;
   CLiquidity        m_liquidity;
   CFibonacci        m_fibonacci;
   CSessionAnalysis  m_session;
   CConfluence       m_confluence;

   string            m_symbol;
   ENUM_TIMEFRAMES   m_htf;
   ENUM_TIMEFRAMES   m_ltf;

public:
   void Init(string symbol, ENUM_TIMEFRAMES htf, ENUM_TIMEFRAMES ltf)
   {
      m_symbol = symbol;
      m_htf = htf;
      m_ltf = ltf;

      // Initialize Section 1: ATR Filter (using HTF timeframe)
      m_atrFilter.Init(symbol, htf, 14, 60.0, 250.0);

      // Initialize Section 2: EMA Analysis (using HTF timeframe)
      m_emaAnalysis.Init(symbol, htf, 50, 200, 5, 10);

      // Initialize SMC modules
      m_structure.Init(symbol, htf);
      m_fvg.Init(symbol, ltf);
      m_orderBlock.Init(symbol, htf);
      m_liquidity.Init(symbol, ltf);
      m_fibonacci.Init(symbol, htf);
      m_session.Init();
   }

   void RunFullAnalysis()
   {
      // Clear previous results
      ZeroMemory(g_sectionResults);

      // Section 1: ATR Filter Analysis
      m_atrFilter.Analyze();

      // Section 2: EMA Analysis
      m_emaAnalysis.Analyze();

      // Run all SMC section analyses
      m_structure.Analyze();    // Section 3
      m_fvg.Analyze();          // Section 7
      m_orderBlock.Analyze();   // Section 8
      m_liquidity.Analyze();    // Section 5
      m_fibonacci.Analyze();    // Section 9
      m_session.Analyze();      // Section 6

      // Calculate HTF/LTF alignment (now uses EMA data)
      AnalyzeHTFLTFAlignment();

      // Calculate confluence score
      m_confluence.Calculate(); // Section 11
   }

   void AnalyzeHTFLTFAlignment()
   {
      // HTF trend - enhanced with EMA confirmation
      g_sectionResults.htfTrendBullish = (g_sectionResults.marketTrend == TREND_BULLISH);
      g_sectionResults.htfTrendBearish = (g_sectionResults.marketTrend == TREND_BEARISH);

      // LTF entry confirmation
      double ltfClose = iClose(m_symbol, m_ltf, 0);
      double ltfOpen = iOpen(m_symbol, m_ltf, 0);

      // Enhanced: Consider EMA alignment for stronger confirmation
      bool emaBullishConfirm = g_sectionResults.emaBullish && g_sectionResults.emaFast > g_sectionResults.emaSlow;
      bool emaBearishConfirm = g_sectionResults.emaBearish && g_sectionResults.emaFast < g_sectionResults.emaSlow;

      if(g_sectionResults.htfTrendBullish && ltfClose > ltfOpen && emaBullishConfirm)
         g_sectionResults.ltfEntryValid = true;
      else if(g_sectionResults.htfTrendBearish && ltfClose < ltfOpen && emaBearishConfirm)
         g_sectionResults.ltfEntryValid = true;
      else if(g_sectionResults.htfTrendBullish && ltfClose > ltfOpen)
         g_sectionResults.ltfEntryValid = true;  // Allow without EMA but less weight
      else if(g_sectionResults.htfTrendBearish && ltfClose < ltfOpen)
         g_sectionResults.ltfEntryValid = true;

      g_sectionResults.htfLtfAligned = g_sectionResults.ltfEntryValid &&
                                        (g_sectionResults.htfTrendBullish || g_sectionResults.htfTrendBearish);
   }

   // Getters for results
   int GetConfluenceScore() { return g_sectionResults.confluenceScore; }
   ENUM_MARKET_TREND GetTrend() { return g_sectionResults.marketTrend; }
   bool IsBOSConfirmed() { return g_sectionResults.bosConfirmed; }
   bool IsInOTE() { return g_sectionResults.inOTEZone; }
   bool HasOrderBlock() { return g_sectionResults.bullishOBPresent || g_sectionResults.bearishOBPresent; }
   bool HasFVG() { return g_sectionResults.bullishFVGPresent || g_sectionResults.bearishFVGPresent; }
   bool IsLiquiditySwept() { return g_sectionResults.liquiditySwept; }
   bool IsHTFLTFAligned() { return g_sectionResults.htfLtfAligned; }
   bool IsSessionActive() { return g_sectionResults.sessionActive; }

   // Section 1 & 2 Getters
   double GetATR() { return g_sectionResults.atrValue; }
   double GetATRPips() { return g_sectionResults.atrPips; }
   bool IsATRFilterPass() { return g_sectionResults.atrFilterPass; }
   string GetVolatilityCondition() { return g_sectionResults.volatilityCondition; }
   double GetEMAFast() { return g_sectionResults.emaFast; }
   double GetEMASlow() { return g_sectionResults.emaSlow; }
   string GetEMATrendBias() { return g_sectionResults.emaTrendBias; }
   bool IsEMABullish() { return g_sectionResults.emaBullish; }
   bool IsEMABearish() { return g_sectionResults.emaBearish; }
};

//+------------------------------------------------------------------+
