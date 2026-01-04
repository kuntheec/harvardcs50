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
   int               bullishFVGCount;      // Number of active bullish FVGs
   int               bearishFVGCount;      // Number of active bearish FVGs
   int               mitigatedFVGCount;    // Number of mitigated (neutral) FVGs

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

   // Section 12: Risk Management
   double            recommendedLotSize;
   double            riskPercent;
   bool              canTrade;
   bool              inRecoveryMode;
   double            currentExposure;
   // Enhanced Risk Management fields
   double            accountBalance;
   double            accountEquity;
   double            accountFreeMargin;
   double            marginLevel;
   double            currentDrawdownPercent;
   double            dailyPnLPercent;
   double            maxRiskAmount;
   double            stopLossDistance;
   double            riskRewardRatio;
   string            riskStatus;              // "OK", "WARNING", "BLOCKED"
   string            blockReason;             // Reason if blocked
   int               openPositions;
   double            totalRiskExposure;       // Total risk across all positions
   bool              marginOK;                // Sufficient margin available
   bool              drawdownOK;              // Within drawdown limits
   bool              dailyLossOK;             // Within daily loss limits

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
   // Enhanced EMA fields
   int               emaCrossoverBarsAgo;      // Bars since last crossover
   double            emaTrendStrength;         // Trend strength 0-100 based on slope
   string            emaTrendStrengthLabel;    // "WEAK", "MODERATE", "STRONG"
   bool              emaStackedBullish;        // Price > Fast > Slow (stacked)
   bool              emaStackedBearish;        // Price < Fast < Slow (stacked)
   double            emaPriceDistance;         // Distance from price to nearest EMA
   double            emaPriceDistanceATR;      // Price distance as ATR multiple

   // Section 6: MACD/RSI Momentum Analysis
   double            macdMain;                 // MACD main line
   double            macdSignal;               // MACD signal line
   double            macdHistogram;            // MACD histogram (main - signal)
   bool              macdBullish;              // MACD above signal line
   bool              macdBearish;              // MACD below signal line
   bool              macdCrossoverBullish;     // Recent bullish crossover
   bool              macdCrossoverBearish;     // Recent bearish crossover
   bool              macdDivergenceBullish;    // Bullish divergence detected
   bool              macdDivergenceBearish;    // Bearish divergence detected
   double            rsiValue;                 // RSI value (0-100)
   bool              rsiOverbought;            // RSI > 70
   bool              rsiOversold;              // RSI < 30
   bool              rsiNeutral;               // RSI 30-70
   string            momentumBias;             // "BULLISH", "BEARISH", "NEUTRAL"
   bool              momentumAligned;          // Momentum aligns with trend

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
//| Section 7: Fair Value Gap Analysis (Aligned with Section07_FVG)   |
//+------------------------------------------------------------------+
class CFairValueGap
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;
   int               m_lookback;
   int               m_atrHandle;
   double            m_atrBuffer[];
   double            m_closeBuffer[];

   // Size limits (auto-detected by instrument + timeframe)
   double            m_minFVGSize;      // Min gap size in pips
   double            m_maxFVGSize;      // Max gap size in pips
   double            m_pipValue;
   string            m_instrumentType;
   bool              m_requireStrongMove;

   // FVG zone tracking (simplified - just counts)
   struct FVGZoneInfo
   {
      double highPrice;
      double lowPrice;
      bool   isBullish;
      bool   isMitigated;
   };
   FVGZoneInfo       m_zones[];
   int               m_maxZones;

public:
   void Init(string symbol, ENUM_TIMEFRAMES tf, int lookback = 100, bool requireStrongMove = true)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_lookback = lookback;
      m_requireStrongMove = requireStrongMove;
      m_maxZones = 10;
      ArrayResize(m_zones, 0);
      ArraySetAsSeries(m_atrBuffer, true);
      ArraySetAsSeries(m_closeBuffer, true);

      // Auto-detect instrument type and pip value
      string sym = symbol;
      StringToUpper(sym);

      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

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
         m_pipValue = point * (digits == 3 ? 1 : 10);
      }
      else
      {
         m_instrumentType = "FOREX";
         m_pipValue = (digits == 3 || digits == 5) ? point * 10 : point;
      }

      // Auto-set FVG size limits by timeframe + instrument
      AutoSetFVGSizeLimits();

      // Create ATR handle for filtering
      if(m_requireStrongMove)
      {
         m_atrHandle = iATR(symbol, tf, 14);
      }
   }

   void AutoSetFVGSizeLimits()
   {
      // Base values for FOREX on each timeframe
      double minBase = 20.0;
      double maxBase = 200.0;

      switch(m_timeframe)
      {
         case PERIOD_M1:   minBase = 2.0;   maxBase = 20.0;   break;
         case PERIOD_M5:   minBase = 5.0;   maxBase = 50.0;   break;
         case PERIOD_M15:  minBase = 10.0;  maxBase = 100.0;  break;
         case PERIOD_M30:  minBase = 15.0;  maxBase = 150.0;  break;
         case PERIOD_H1:   minBase = 20.0;  maxBase = 200.0;  break;
         case PERIOD_H4:   minBase = 50.0;  maxBase = 500.0;  break;
         case PERIOD_D1:   minBase = 100.0; maxBase = 1000.0; break;
         case PERIOD_W1:   minBase = 200.0; maxBase = 2000.0; break;
         default:          minBase = 20.0;  maxBase = 200.0;  break;
      }

      // Scale by instrument
      double multiplier = 1.0;
      if(m_instrumentType == "SILVER")
         multiplier = 2.0;

      m_minFVGSize = minBase * multiplier;
      m_maxFVGSize = maxBase * multiplier;
   }

   void Analyze()
   {
      // Reset counts
      g_sectionResults.bullishFVGPresent = false;
      g_sectionResults.bearishFVGPresent = false;
      g_sectionResults.priceInFVG = false;
      g_sectionResults.fvgCount = 0;
      g_sectionResults.bullishFVGCount = 0;
      g_sectionResults.bearishFVGCount = 0;
      g_sectionResults.mitigatedFVGCount = 0;

      ArrayResize(m_zones, 0);

      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);

      // Copy close buffer for mitigation check (with error handling)
      int closeCopied = CopyClose(m_symbol, m_timeframe, 0, 10, m_closeBuffer);
      if(closeCopied <= 0)
      {
         Print("⚠ FVG: Failed to copy close buffer, error: ", GetLastError());
         return;  // Cannot analyze without price data
      }

      // Copy ATR for filtering (with error handling)
      double atrValues[];
      ArraySetAsSeries(atrValues, true);
      if(m_requireStrongMove && m_atrHandle != INVALID_HANDLE)
      {
         int atrCopied = CopyBuffer(m_atrHandle, 0, 0, m_lookback, atrValues);
         if(atrCopied <= 0)
         {
            Print("⚠ FVG: Failed to copy ATR buffer, continuing without ATR filter");
            m_requireStrongMove = false;  // Disable ATR filter if failed
         }
      }

      for(int i = 2; i < m_lookback - 2; i++)
      {
         // Get candle data (left=i+1, middle=i, right=i-1)
         double leftHigh = iHigh(m_symbol, m_timeframe, i + 1);
         double leftLow = iLow(m_symbol, m_timeframe, i + 1);
         double middleHigh = iHigh(m_symbol, m_timeframe, i);
         double middleLow = iLow(m_symbol, m_timeframe, i);
         double rightHigh = iHigh(m_symbol, m_timeframe, i - 1);
         double rightLow = iLow(m_symbol, m_timeframe, i - 1);

         // Check for Bullish FVG: rightLow > leftHigh
         if(rightLow > leftHigh)
         {
            double gapSize = (rightLow - leftHigh) / m_pipValue;

            // Size filter
            if(gapSize >= m_minFVGSize && gapSize <= m_maxFVGSize)
            {
               // ATR filter (optional strong move check)
               bool passATR = true;
               if(m_requireStrongMove && ArraySize(atrValues) > i)
               {
                  double atr = atrValues[i];
                  double moveSize = middleHigh - middleLow;
                  if(moveSize < atr)
                     passATR = false;
               }

               if(passATR)
               {
                  // Check if mitigated
                  bool isMitigated = false;
                  for(int j = 0; j < ArraySize(m_closeBuffer); j++)
                  {
                     if(m_closeBuffer[j] < leftHigh)
                     {
                        isMitigated = true;
                        break;
                     }
                  }

                  if(isMitigated)
                  {
                     g_sectionResults.mitigatedFVGCount++;
                  }
                  else
                  {
                     g_sectionResults.bullishFVGPresent = true;
                     g_sectionResults.bullishFVGCount++;

                     // Store nearest for reference
                     if(g_sectionResults.bullishFVGCount == 1)
                     {
                        g_sectionResults.fvgHigh = rightLow;
                        g_sectionResults.fvgLow = leftHigh;
                        g_sectionResults.fvgMidpoint = (rightLow + leftHigh) / 2;
                     }

                     // Check if price is in this FVG
                     if(currentPrice >= leftHigh && currentPrice <= rightLow)
                        g_sectionResults.priceInFVG = true;
                  }
                  g_sectionResults.fvgCount++;
               }
            }
         }

         // Check for Bearish FVG: rightHigh < leftLow
         if(rightHigh < leftLow)
         {
            double gapSize = (leftLow - rightHigh) / m_pipValue;

            // Size filter
            if(gapSize >= m_minFVGSize && gapSize <= m_maxFVGSize)
            {
               // ATR filter
               bool passATR = true;
               if(m_requireStrongMove && ArraySize(atrValues) > i)
               {
                  double atr = atrValues[i];
                  double moveSize = middleHigh - middleLow;
                  if(moveSize < atr)
                     passATR = false;
               }

               if(passATR)
               {
                  // Check if mitigated
                  bool isMitigated = false;
                  for(int j = 0; j < ArraySize(m_closeBuffer); j++)
                  {
                     if(m_closeBuffer[j] > leftLow)
                     {
                        isMitigated = true;
                        break;
                     }
                  }

                  if(isMitigated)
                  {
                     g_sectionResults.mitigatedFVGCount++;
                  }
                  else
                  {
                     g_sectionResults.bearishFVGPresent = true;
                     g_sectionResults.bearishFVGCount++;

                     // Store nearest for reference
                     if(g_sectionResults.bearishFVGCount == 1)
                     {
                        g_sectionResults.fvgHigh = leftLow;
                        g_sectionResults.fvgLow = rightHigh;
                        g_sectionResults.fvgMidpoint = (leftLow + rightHigh) / 2;
                     }

                     // Check if price is in this FVG
                     if(currentPrice >= rightHigh && currentPrice <= leftLow)
                        g_sectionResults.priceInFVG = true;
                  }
                  g_sectionResults.fvgCount++;
               }
            }
         }
      }
   }

   bool HasBullishFVG() { return g_sectionResults.bullishFVGPresent; }
   bool HasBearishFVG() { return g_sectionResults.bearishFVGPresent; }
   bool IsPriceInFVG() { return g_sectionResults.priceInFVG; }
   int GetBullishCount() { return g_sectionResults.bullishFVGCount; }
   int GetBearishCount() { return g_sectionResults.bearishFVGCount; }
   int GetMitigatedCount() { return g_sectionResults.mitigatedFVGCount; }
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

      // Error handling for CopyBuffer
      int copied = CopyBuffer(m_atrHandle, 0, 0, 3, m_atrBuffer);
      if(copied <= 0)
      {
         Print("⚠ OB: Failed to copy ATR buffer, error: ", GetLastError());
         return;
      }

      double atr = m_atrBuffer[0];
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);

      // Determine which OB type to prioritize based on market trend
      // Only show the dominant direction to avoid conflicting signals
      bool lookForBullish = (g_sectionResults.marketTrend == TREND_BULLISH ||
                             g_sectionResults.marketTrend == TREND_RANGING);
      bool lookForBearish = (g_sectionResults.marketTrend == TREND_BEARISH ||
                             g_sectionResults.marketTrend == TREND_RANGING);

      // In ranging market, pick first OB found and stop
      bool foundOB = false;

      for(int i = 1; i < m_lookback - 1 && !foundOB; i++)
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
         if(lookForBullish && close < open && nextClose > high && body > atr * 0.3)
         {
            g_sectionResults.bullishOBPresent = true;
            g_sectionResults.obHigh = open;
            g_sectionResults.obLow = close;
            g_sectionResults.obStrength = (int)((body / atr) * 10);
            g_sectionResults.obFresh = (i <= 5);

            if(currentPrice >= close && currentPrice <= open)
               g_sectionResults.priceInOB = true;

            // In bullish trend, we found our OB - stop looking
            if(g_sectionResults.marketTrend == TREND_BULLISH)
               foundOB = true;
            else if(g_sectionResults.marketTrend == TREND_RANGING && g_sectionResults.priceInOB)
               foundOB = true;  // In ranging, stop if price is in OB
         }

         // Bearish OB: Last bullish candle before strong bearish move
         if(lookForBearish && !foundOB && close > open && nextClose < low && body > atr * 0.3)
         {
            g_sectionResults.bearishOBPresent = true;
            g_sectionResults.obHigh = close;
            g_sectionResults.obLow = open;
            g_sectionResults.obStrength = (int)((body / atr) * 10);
            g_sectionResults.obFresh = (i <= 5);

            if(currentPrice >= open && currentPrice <= close)
               g_sectionResults.priceInOB = true;

            // In bearish trend, we found our OB - stop looking
            if(g_sectionResults.marketTrend == TREND_BEARISH)
               foundOB = true;
            else if(g_sectionResults.marketTrend == TREND_RANGING && g_sectionResults.priceInOB)
               foundOB = true;
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
      if(m_atrHandle == INVALID_HANDLE)
      {
         Print("⚠ ATR: Invalid handle, skipping analysis");
         return;
      }

      // Copy ATR buffer (with error handling)
      int copied = CopyBuffer(m_atrHandle, 0, 0, m_percentileBars + 10, m_atrBuffer);
      if(copied < m_percentileBars)
      {
         Print("⚠ ATR: Failed to copy buffer, got ", copied, " bars, need ", m_percentileBars);
         return;
      }

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

      // Crossover detection with bars ago tracking
      g_sectionResults.emaCrossoverBullish = false;
      g_sectionResults.emaCrossoverBearish = false;
      g_sectionResults.emaCrossoverBarsAgo = -1;  // -1 means no recent crossover

      for(int i = 0; i < m_crossoverLookback; i++)
      {
         // Golden cross: Fast crosses above Slow
         if(m_emaFastBuffer[i] > m_emaSlowBuffer[i] &&
            m_emaFastBuffer[i+1] <= m_emaSlowBuffer[i+1])
         {
            g_sectionResults.emaCrossoverBullish = true;
            g_sectionResults.emaCrossoverBarsAgo = i;
            break;
         }
         // Death cross: Fast crosses below Slow
         if(m_emaFastBuffer[i] < m_emaSlowBuffer[i] &&
            m_emaFastBuffer[i+1] >= m_emaSlowBuffer[i+1])
         {
            g_sectionResults.emaCrossoverBearish = true;
            g_sectionResults.emaCrossoverBarsAgo = i;
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

      // === Enhanced EMA Analysis ===

      // Stacked EMAs (strong trend confirmation)
      g_sectionResults.emaStackedBullish = (currentPrice > m_emaFastBuffer[0] &&
                                             m_emaFastBuffer[0] > m_emaSlowBuffer[0]);
      g_sectionResults.emaStackedBearish = (currentPrice < m_emaFastBuffer[0] &&
                                             m_emaFastBuffer[0] < m_emaSlowBuffer[0]);

      // Distance from price to nearest EMA
      double distToFast = MathAbs(currentPrice - m_emaFastBuffer[0]);
      double distToSlow = MathAbs(currentPrice - m_emaSlowBuffer[0]);
      g_sectionResults.emaPriceDistance = MathMin(distToFast, distToSlow);

      // Price distance as ATR multiple (if ATR is available)
      if(g_sectionResults.atrValue > 0)
         g_sectionResults.emaPriceDistanceATR = g_sectionResults.emaPriceDistance / g_sectionResults.atrValue;
      else
         g_sectionResults.emaPriceDistanceATR = 0;

      // Calculate trend strength based on EMA slope and alignment
      CalculateTrendStrength(currentPrice);
   }

private:
   void CalculateTrendStrength(double currentPrice)
   {
      // Trend strength factors:
      // 1. Slope magnitude (steeper = stronger)
      // 2. Both EMAs sloping same direction
      // 3. Price position (stacked EMAs)
      // 4. EMA spread (wider = stronger trend)

      double strengthScore = 0;

      // Normalize slopes to a comparable scale
      double slopeNorm = (MathAbs(g_sectionResults.emaFastSlope) + MathAbs(g_sectionResults.emaSlowSlope)) / 2;
      double slopeStrength = MathMin(slopeNorm / (g_sectionResults.atrValue > 0 ? g_sectionResults.atrValue * 0.01 : 0.0001), 1.0);
      strengthScore += slopeStrength * 30;  // Up to 30 points for slope

      // Both EMAs sloping same direction
      bool sameDirection = (g_sectionResults.emaFastSlope > 0 && g_sectionResults.emaSlowSlope > 0) ||
                           (g_sectionResults.emaFastSlope < 0 && g_sectionResults.emaSlowSlope < 0);
      if(sameDirection)
         strengthScore += 20;  // 20 points for alignment

      // Stacked EMAs (strongest confirmation)
      if(g_sectionResults.emaStackedBullish || g_sectionResults.emaStackedBearish)
         strengthScore += 30;  // 30 points for stacked

      // EMA spread contribution
      double spreadStrength = MathMin(MathAbs(g_sectionResults.emaSpreadPercent) / 0.5, 1.0);
      strengthScore += spreadStrength * 20;  // Up to 20 points for spread

      g_sectionResults.emaTrendStrength = MathMin(strengthScore, 100);

      // Label the strength
      if(g_sectionResults.emaTrendStrength >= 70)
         g_sectionResults.emaTrendStrengthLabel = "STRONG";
      else if(g_sectionResults.emaTrendStrength >= 40)
         g_sectionResults.emaTrendStrengthLabel = "MODERATE";
      else
         g_sectionResults.emaTrendStrengthLabel = "WEAK";
   }

public:

   // Getters
   double GetEMAFast() { return g_sectionResults.emaFast; }
   double GetEMASlow() { return g_sectionResults.emaSlow; }
   bool IsBullish() { return g_sectionResults.emaBullish; }
   bool IsBearish() { return g_sectionResults.emaBearish; }
   string GetTrendBias() { return g_sectionResults.emaTrendBias; }
   bool HasGoldenCross() { return g_sectionResults.emaCrossoverBullish; }
   bool HasDeathCross() { return g_sectionResults.emaCrossoverBearish; }
   // Enhanced getters
   int GetCrossoverBarsAgo() { return g_sectionResults.emaCrossoverBarsAgo; }
   double GetTrendStrength() { return g_sectionResults.emaTrendStrength; }
   string GetTrendStrengthLabel() { return g_sectionResults.emaTrendStrengthLabel; }
   bool IsStackedBullish() { return g_sectionResults.emaStackedBullish; }
   bool IsStackedBearish() { return g_sectionResults.emaStackedBearish; }
   double GetPriceDistanceATR() { return g_sectionResults.emaPriceDistanceATR; }
};

//+------------------------------------------------------------------+
//| Section 6: MACD/RSI Momentum Analysis                             |
//+------------------------------------------------------------------+
class CMACDRSIAnalysis
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   // MACD parameters
   int               m_macdFastPeriod;
   int               m_macdSlowPeriod;
   int               m_macdSignalPeriod;
   int               m_macdHandle;
   double            m_macdMainBuffer[];
   double            m_macdSignalBuffer[];

   // RSI parameters
   int               m_rsiPeriod;
   int               m_rsiHandle;
   double            m_rsiBuffer[];

   // Analysis settings
   int               m_crossoverLookback;
   int               m_divergenceLookback;
   double            m_rsiOverboughtLevel;
   double            m_rsiOversoldLevel;

public:
   void Init(string symbol, ENUM_TIMEFRAMES tf,
             int macdFast = 12, int macdSlow = 26, int macdSignal = 9,
             int rsiPeriod = 14, double rsiOB = 70.0, double rsiOS = 30.0)
   {
      m_symbol = symbol;
      m_timeframe = tf;

      // MACD settings
      m_macdFastPeriod = macdFast;
      m_macdSlowPeriod = macdSlow;
      m_macdSignalPeriod = macdSignal;

      // RSI settings
      m_rsiPeriod = rsiPeriod;
      m_rsiOverboughtLevel = rsiOB;
      m_rsiOversoldLevel = rsiOS;

      // Lookback periods
      m_crossoverLookback = 5;
      m_divergenceLookback = 20;

      // Create indicator handles
      m_macdHandle = iMACD(symbol, tf, m_macdFastPeriod, m_macdSlowPeriod, m_macdSignalPeriod, PRICE_CLOSE);
      m_rsiHandle = iRSI(symbol, tf, m_rsiPeriod, PRICE_CLOSE);

      // Set arrays as series
      ArraySetAsSeries(m_macdMainBuffer, true);
      ArraySetAsSeries(m_macdSignalBuffer, true);
      ArraySetAsSeries(m_rsiBuffer, true);
   }

   void Analyze()
   {
      // Reset all values
      g_sectionResults.macdMain = 0;
      g_sectionResults.macdSignal = 0;
      g_sectionResults.macdHistogram = 0;
      g_sectionResults.macdBullish = false;
      g_sectionResults.macdBearish = false;
      g_sectionResults.macdCrossoverBullish = false;
      g_sectionResults.macdCrossoverBearish = false;
      g_sectionResults.macdDivergenceBullish = false;
      g_sectionResults.macdDivergenceBearish = false;
      g_sectionResults.rsiValue = 50;
      g_sectionResults.rsiOverbought = false;
      g_sectionResults.rsiOversold = false;
      g_sectionResults.rsiNeutral = true;
      g_sectionResults.momentumBias = "NEUTRAL";
      g_sectionResults.momentumAligned = false;

      // Validate handles
      if(m_macdHandle == INVALID_HANDLE || m_rsiHandle == INVALID_HANDLE)
      {
         Print("⚠ MACD/RSI: Invalid indicator handles");
         return;
      }

      int bars = m_divergenceLookback + 5;

      // Copy MACD buffers (with error handling)
      int macdMainCopied = CopyBuffer(m_macdHandle, 0, 0, bars, m_macdMainBuffer);
      int macdSignalCopied = CopyBuffer(m_macdHandle, 1, 0, bars, m_macdSignalBuffer);
      if(macdMainCopied < bars || macdSignalCopied < bars)
      {
         Print("⚠ MACD: Failed to copy buffers, got ", macdMainCopied, "/", macdSignalCopied);
         return;
      }

      // Copy RSI buffer (with error handling)
      int rsiCopied = CopyBuffer(m_rsiHandle, 0, 0, bars, m_rsiBuffer);
      if(rsiCopied < bars)
      {
         Print("⚠ RSI: Failed to copy buffer, got ", rsiCopied);
         return;
      }

      // === MACD Analysis ===
      g_sectionResults.macdMain = m_macdMainBuffer[0];
      g_sectionResults.macdSignal = m_macdSignalBuffer[0];
      g_sectionResults.macdHistogram = m_macdMainBuffer[0] - m_macdSignalBuffer[0];

      // MACD position relative to signal
      g_sectionResults.macdBullish = (m_macdMainBuffer[0] > m_macdSignalBuffer[0]);
      g_sectionResults.macdBearish = (m_macdMainBuffer[0] < m_macdSignalBuffer[0]);

      // Check for recent MACD crossovers
      for(int i = 0; i < m_crossoverLookback; i++)
      {
         // Bullish crossover: MACD crosses above Signal
         if(m_macdMainBuffer[i] > m_macdSignalBuffer[i] &&
            m_macdMainBuffer[i+1] <= m_macdSignalBuffer[i+1])
         {
            g_sectionResults.macdCrossoverBullish = true;
            break;
         }
         // Bearish crossover: MACD crosses below Signal
         if(m_macdMainBuffer[i] < m_macdSignalBuffer[i] &&
            m_macdMainBuffer[i+1] >= m_macdSignalBuffer[i+1])
         {
            g_sectionResults.macdCrossoverBearish = true;
            break;
         }
      }

      // === RSI Analysis ===
      g_sectionResults.rsiValue = m_rsiBuffer[0];
      g_sectionResults.rsiOverbought = (m_rsiBuffer[0] > m_rsiOverboughtLevel);
      g_sectionResults.rsiOversold = (m_rsiBuffer[0] < m_rsiOversoldLevel);
      g_sectionResults.rsiNeutral = (!g_sectionResults.rsiOverbought && !g_sectionResults.rsiOversold);

      // === Divergence Detection ===
      DetectDivergence();

      // === Overall Momentum Bias ===
      DetermineMomentumBias();
   }

private:
   void DetectDivergence()
   {
      // Simple divergence detection: compare price highs/lows with MACD highs/lows
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);

      // Get recent swing highs/lows from price
      double priceHigh1 = 0, priceHigh2 = 0;
      double priceLow1 = DBL_MAX, priceLow2 = DBL_MAX;
      double macdHigh1 = -DBL_MAX, macdHigh2 = -DBL_MAX;
      double macdLow1 = DBL_MAX, macdLow2 = DBL_MAX;

      int swingCount = 0;
      for(int i = 2; i < m_divergenceLookback - 2 && swingCount < 4; i++)
      {
         double high = iHigh(m_symbol, m_timeframe, i);
         double low = iLow(m_symbol, m_timeframe, i);
         double high1 = iHigh(m_symbol, m_timeframe, i-1);
         double high2 = iHigh(m_symbol, m_timeframe, i+1);
         double low1 = iLow(m_symbol, m_timeframe, i-1);
         double low2 = iLow(m_symbol, m_timeframe, i+1);

         // Swing high
         if(high > high1 && high > high2)
         {
            if(priceHigh1 == 0)
            {
               priceHigh1 = high;
               macdHigh1 = m_macdMainBuffer[i];
            }
            else if(priceHigh2 == 0)
            {
               priceHigh2 = high;
               macdHigh2 = m_macdMainBuffer[i];
            }
            swingCount++;
         }

         // Swing low
         if(low < low1 && low < low2)
         {
            if(priceLow1 == DBL_MAX)
            {
               priceLow1 = low;
               macdLow1 = m_macdMainBuffer[i];
            }
            else if(priceLow2 == DBL_MAX)
            {
               priceLow2 = low;
               macdLow2 = m_macdMainBuffer[i];
            }
            swingCount++;
         }
      }

      // Bullish divergence: Price makes lower low, MACD makes higher low
      if(priceLow1 < priceLow2 && macdLow1 > macdLow2 && priceLow2 != DBL_MAX)
         g_sectionResults.macdDivergenceBullish = true;

      // Bearish divergence: Price makes higher high, MACD makes lower high
      if(priceHigh1 > priceHigh2 && macdHigh1 < macdHigh2 && priceHigh2 != 0)
         g_sectionResults.macdDivergenceBearish = true;
   }

   void DetermineMomentumBias()
   {
      int bullishScore = 0;
      int bearishScore = 0;

      // MACD contribution
      if(g_sectionResults.macdBullish) bullishScore += 2;
      if(g_sectionResults.macdBearish) bearishScore += 2;
      if(g_sectionResults.macdCrossoverBullish) bullishScore += 1;
      if(g_sectionResults.macdCrossoverBearish) bearishScore += 1;
      if(g_sectionResults.macdHistogram > 0) bullishScore += 1;
      if(g_sectionResults.macdHistogram < 0) bearishScore += 1;

      // RSI contribution
      if(g_sectionResults.rsiValue > 50) bullishScore += 1;
      if(g_sectionResults.rsiValue < 50) bearishScore += 1;
      if(g_sectionResults.rsiOversold) bullishScore += 1;  // Oversold = potential bullish reversal
      if(g_sectionResults.rsiOverbought) bearishScore += 1;  // Overbought = potential bearish reversal

      // Divergence contribution (stronger signal)
      if(g_sectionResults.macdDivergenceBullish) bullishScore += 2;
      if(g_sectionResults.macdDivergenceBearish) bearishScore += 2;

      // Determine overall bias
      if(bullishScore > bearishScore + 2)
         g_sectionResults.momentumBias = "BULLISH";
      else if(bearishScore > bullishScore + 2)
         g_sectionResults.momentumBias = "BEARISH";
      else
         g_sectionResults.momentumBias = "NEUTRAL";

      // Check if momentum aligns with market trend
      g_sectionResults.momentumAligned = false;
      if(g_sectionResults.marketTrend == TREND_BULLISH &&
         g_sectionResults.momentumBias == "BULLISH")
         g_sectionResults.momentumAligned = true;
      else if(g_sectionResults.marketTrend == TREND_BEARISH &&
              g_sectionResults.momentumBias == "BEARISH")
         g_sectionResults.momentumAligned = true;
   }

public:
   // Getters
   double GetMACD() { return g_sectionResults.macdMain; }
   double GetMACDSignal() { return g_sectionResults.macdSignal; }
   double GetMACDHistogram() { return g_sectionResults.macdHistogram; }
   double GetRSI() { return g_sectionResults.rsiValue; }
   bool IsMACDBullish() { return g_sectionResults.macdBullish; }
   bool IsMACDBearish() { return g_sectionResults.macdBearish; }
   bool IsRSIOverbought() { return g_sectionResults.rsiOverbought; }
   bool IsRSIOversold() { return g_sectionResults.rsiOversold; }
   string GetMomentumBias() { return g_sectionResults.momentumBias; }
   bool IsMomentumAligned() { return g_sectionResults.momentumAligned; }
   bool HasBullishDivergence() { return g_sectionResults.macdDivergenceBullish; }
   bool HasBearishDivergence() { return g_sectionResults.macdDivergenceBearish; }
};

//+------------------------------------------------------------------+
//| Section 12: Risk Management Module                                |
//+------------------------------------------------------------------+
class CRiskManagement
{
private:
   string            m_symbol;
   ENUM_TIMEFRAMES   m_timeframe;

   // Risk parameters
   double            m_baseRiskPercent;
   double            m_maxRiskPercent;
   double            m_minRiskPercent;
   double            m_maxDailyLossPercent;
   double            m_maxDrawdownPercent;
   double            m_minLots;
   double            m_maxLots;

   // Account tracking
   double            m_startingBalance;
   double            m_dailyStartBalance;
   datetime          m_lastDayCheck;

public:
   void Init(string symbol, ENUM_TIMEFRAMES tf,
             double baseRisk = 1.0, double maxRisk = 2.0, double minRisk = 0.5,
             double maxDailyLoss = 5.0, double maxDrawdown = 20.0)
   {
      m_symbol = symbol;
      m_timeframe = tf;
      m_baseRiskPercent = baseRisk;
      m_maxRiskPercent = maxRisk;
      m_minRiskPercent = minRisk;
      m_maxDailyLossPercent = maxDailyLoss;
      m_maxDrawdownPercent = maxDrawdown;

      // Get lot constraints from symbol
      m_minLots = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      m_maxLots = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);

      // Initialize balance tracking
      m_startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      m_dailyStartBalance = m_startingBalance;
      m_lastDayCheck = TimeCurrent();
   }

   void Analyze()
   {
      // Reset risk status
      g_sectionResults.canTrade = true;
      g_sectionResults.riskStatus = "OK";
      g_sectionResults.blockReason = "";

      // Get account info
      g_sectionResults.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_sectionResults.accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_sectionResults.accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

      // Calculate margin level
      double marginUsed = AccountInfoDouble(ACCOUNT_MARGIN);
      if(marginUsed > 0)
         g_sectionResults.marginLevel = (g_sectionResults.accountEquity / marginUsed) * 100;
      else
         g_sectionResults.marginLevel = 9999;  // No margin used

      // Check for day reset
      CheckDayReset();

      // Calculate drawdown
      g_sectionResults.currentDrawdownPercent = 0;
      if(m_startingBalance > 0)
      {
         double maxBalance = MathMax(m_startingBalance, g_sectionResults.accountBalance);
         g_sectionResults.currentDrawdownPercent =
            ((maxBalance - g_sectionResults.accountEquity) / maxBalance) * 100;
      }

      // Calculate daily P&L
      g_sectionResults.dailyPnLPercent = 0;
      if(m_dailyStartBalance > 0)
      {
         g_sectionResults.dailyPnLPercent =
            ((g_sectionResults.accountBalance - m_dailyStartBalance) / m_dailyStartBalance) * 100;
      }

      // Count open positions and calculate exposure
      g_sectionResults.openPositions = PositionsTotal();
      CalculateExposure();

      // Determine risk percent based on confluence score
      DetermineRiskPercent();

      // Calculate recommended lot size
      CalculateLotSize();

      // Check all risk limits
      CheckRiskLimits();

      // Final validation
      ValidateMargin();
   }

private:
   void CheckDayReset()
   {
      MqlDateTime currentTime, lastCheck;
      TimeToStruct(TimeCurrent(), currentTime);
      TimeToStruct(m_lastDayCheck, lastCheck);

      if(currentTime.day != lastCheck.day || currentTime.mon != lastCheck.mon)
      {
         m_dailyStartBalance = g_sectionResults.accountBalance;
         m_lastDayCheck = TimeCurrent();
      }
   }

   void CalculateExposure()
   {
      g_sectionResults.currentExposure = 0;
      g_sectionResults.totalRiskExposure = 0;

      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionSelectByTicket(PositionGetTicket(i)))
         {
            double positionRisk = PositionGetDouble(POSITION_VOLUME) *
                                  SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_TRADE_CONTRACT_SIZE);
            g_sectionResults.currentExposure += positionRisk;

            // Estimate risk based on SL distance if available
            double sl = PositionGetDouble(POSITION_SL);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            if(sl > 0 && openPrice > 0)
            {
               double riskPips = MathAbs(openPrice - sl) / SymbolInfoDouble(m_symbol, SYMBOL_POINT);
               double pipValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
               g_sectionResults.totalRiskExposure +=
                  PositionGetDouble(POSITION_VOLUME) * riskPips * pipValue;
            }
         }
      }

      // Convert to percentage of balance
      if(g_sectionResults.accountBalance > 0)
         g_sectionResults.totalRiskExposure =
            (g_sectionResults.totalRiskExposure / g_sectionResults.accountBalance) * 100;
   }

   void DetermineRiskPercent()
   {
      // Base risk adjusted by confluence score
      double riskPercent = m_baseRiskPercent;

      // Confluence-based adjustment
      if(g_sectionResults.signalStrong)
         riskPercent = m_maxRiskPercent;
      else if(g_sectionResults.signalModerate)
         riskPercent = m_baseRiskPercent;
      else if(g_sectionResults.signalWeak)
         riskPercent = m_minRiskPercent;
      else
         riskPercent = m_minRiskPercent * 0.5;  // Very weak signal

      // Reduce risk in recovery mode
      if(g_sectionResults.inRecoveryMode)
         riskPercent *= 0.5;

      // Reduce risk if already exposed
      if(g_sectionResults.openPositions > 0)
         riskPercent *= 0.75;

      // Clamp to limits
      g_sectionResults.riskPercent = MathMax(m_minRiskPercent * 0.5,
                                              MathMin(riskPercent, m_maxRiskPercent));

      // Calculate max risk amount in currency
      g_sectionResults.maxRiskAmount = g_sectionResults.accountBalance *
                                        (g_sectionResults.riskPercent / 100);
   }

   void CalculateLotSize()
   {
      // Use ATR for stop loss distance if available
      if(g_sectionResults.atrValue > 0)
         g_sectionResults.stopLossDistance = g_sectionResults.atrValue * 1.5;  // 1.5x ATR
      else
         g_sectionResults.stopLossDistance = 50 * SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      // Calculate pip value
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double pipValue = tickValue * (SymbolInfoDouble(m_symbol, SYMBOL_POINT) / tickSize);

      // Calculate stop loss in pips
      double slPips = g_sectionResults.stopLossDistance / SymbolInfoDouble(m_symbol, SYMBOL_POINT);

      // Calculate lot size: Risk Amount / (SL pips * pip value)
      double lots = 0;
      if(slPips > 0 && pipValue > 0)
         lots = g_sectionResults.maxRiskAmount / (slPips * pipValue);

      // Normalize to lot step
      double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
      lots = MathFloor(lots / lotStep) * lotStep;

      // Clamp to min/max
      g_sectionResults.recommendedLotSize = MathMax(m_minLots, MathMin(lots, m_maxLots));

      // Calculate actual R:R if we have TP targets
      if(g_sectionResults.stopLossDistance > 0 && g_sectionResults.atrValue > 0)
         g_sectionResults.riskRewardRatio = (g_sectionResults.atrValue * 2.0) /
                                             g_sectionResults.stopLossDistance;  // 2x ATR as TP1
   }

   void CheckRiskLimits()
   {
      g_sectionResults.marginOK = true;
      g_sectionResults.drawdownOK = true;
      g_sectionResults.dailyLossOK = true;

      // Check drawdown limit
      if(g_sectionResults.currentDrawdownPercent >= m_maxDrawdownPercent)
      {
         g_sectionResults.drawdownOK = false;
         g_sectionResults.canTrade = false;
         g_sectionResults.riskStatus = "BLOCKED";
         g_sectionResults.blockReason = "Max drawdown exceeded: " +
            DoubleToString(g_sectionResults.currentDrawdownPercent, 1) + "%";
         return;
      }
      else if(g_sectionResults.currentDrawdownPercent >= m_maxDrawdownPercent * 0.8)
      {
         g_sectionResults.riskStatus = "WARNING";
      }

      // Check daily loss limit
      if(g_sectionResults.dailyPnLPercent <= -m_maxDailyLossPercent)
      {
         g_sectionResults.dailyLossOK = false;
         g_sectionResults.canTrade = false;
         g_sectionResults.riskStatus = "BLOCKED";
         g_sectionResults.blockReason = "Daily loss limit: " +
            DoubleToString(g_sectionResults.dailyPnLPercent, 1) + "%";
         return;
      }
      else if(g_sectionResults.dailyPnLPercent <= -m_maxDailyLossPercent * 0.8)
      {
         if(g_sectionResults.riskStatus != "BLOCKED")
            g_sectionResults.riskStatus = "WARNING";
      }

      // Check margin level (warning at 200%, block at 150%)
      if(g_sectionResults.marginLevel < 150 && g_sectionResults.marginLevel > 0)
      {
         g_sectionResults.marginOK = false;
         g_sectionResults.canTrade = false;
         g_sectionResults.riskStatus = "BLOCKED";
         g_sectionResults.blockReason = "Low margin level: " +
            DoubleToString(g_sectionResults.marginLevel, 0) + "%";
      }
      else if(g_sectionResults.marginLevel < 200 && g_sectionResults.marginLevel > 0)
      {
         if(g_sectionResults.riskStatus == "OK")
            g_sectionResults.riskStatus = "WARNING";
      }
   }

   void ValidateMargin()
   {
      if(!g_sectionResults.canTrade) return;

      // Check if we have enough free margin for the calculated lot size
      double marginRequired = 0;
      if(!OrderCalcMargin(ORDER_TYPE_BUY, m_symbol, g_sectionResults.recommendedLotSize,
                          SymbolInfoDouble(m_symbol, SYMBOL_ASK), marginRequired))
      {
         g_sectionResults.marginOK = false;
         return;
      }

      if(marginRequired > g_sectionResults.accountFreeMargin * 0.8)
      {
         // Reduce lot size to fit available margin
         double maxAffordableLots = (g_sectionResults.accountFreeMargin * 0.8) /
                                     (marginRequired / g_sectionResults.recommendedLotSize);
         double lotStep = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);
         maxAffordableLots = MathFloor(maxAffordableLots / lotStep) * lotStep;
         g_sectionResults.recommendedLotSize = MathMax(m_minLots, maxAffordableLots);

         if(g_sectionResults.recommendedLotSize < m_minLots)
         {
            g_sectionResults.marginOK = false;
            g_sectionResults.canTrade = false;
            g_sectionResults.riskStatus = "BLOCKED";
            g_sectionResults.blockReason = "Insufficient margin";
         }
      }
   }

public:
   // Getters
   double GetRecommendedLots() { return g_sectionResults.recommendedLotSize; }
   double GetRiskPercent() { return g_sectionResults.riskPercent; }
   bool CanTrade() { return g_sectionResults.canTrade; }
   string GetRiskStatus() { return g_sectionResults.riskStatus; }
   double GetDrawdownPercent() { return g_sectionResults.currentDrawdownPercent; }
   double GetDailyPnLPercent() { return g_sectionResults.dailyPnLPercent; }
   double GetMarginLevel() { return g_sectionResults.marginLevel; }
   bool IsMarginOK() { return g_sectionResults.marginOK; }
   bool IsDrawdownOK() { return g_sectionResults.drawdownOK; }
   bool IsDailyLossOK() { return g_sectionResults.dailyLossOK; }

   // Recovery mode management
   void EnterRecoveryMode() { g_sectionResults.inRecoveryMode = true; }
   void ExitRecoveryMode() { g_sectionResults.inRecoveryMode = false; }
   bool IsInRecoveryMode() { return g_sectionResults.inRecoveryMode; }
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

      // EMA Trend Alignment (+1) - Added per Grok's recommendation
      // Add point if EMA confirms the market trend direction
      if(g_sectionResults.marketTrend == TREND_BULLISH && g_sectionResults.emaBullish)
      {
         score += 1;
         g_sectionResults.bullishFactors++;
      }
      else if(g_sectionResults.marketTrend == TREND_BEARISH && g_sectionResults.emaBearish)
      {
         score += 1;
         g_sectionResults.bearishFactors++;
      }

      // MACD/RSI Momentum Alignment (+1) - Section 6 integration
      // Add point if momentum confirms the market trend direction
      if(g_sectionResults.momentumAligned)
      {
         score += 1;
         if(g_sectionResults.marketTrend == TREND_BULLISH)
            g_sectionResults.bullishFactors++;
         else if(g_sectionResults.marketTrend == TREND_BEARISH)
            g_sectionResults.bearishFactors++;
      }

      // Divergence bonus (+1) - Strong reversal signal
      if((g_sectionResults.macdDivergenceBullish && g_sectionResults.marketTrend == TREND_BULLISH) ||
         (g_sectionResults.macdDivergenceBearish && g_sectionResults.marketTrend == TREND_BEARISH))
      {
         score += 1;
      }

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

   // Section 6: MACD/RSI Momentum
   CMACDRSIAnalysis  m_macdRsi;

   // Section 12: Risk Management
   CRiskManagement   m_riskMgmt;

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

      // Initialize Section 6: MACD/RSI Momentum (using HTF for trend confirmation)
      m_macdRsi.Init(symbol, htf, 12, 26, 9, 14, 70.0, 30.0);

      // Initialize Section 12: Risk Management
      m_riskMgmt.Init(symbol, htf, 1.0, 2.0, 0.5, 5.0, 20.0);

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

      // Section 2: EMA Analysis (enhanced with trend strength)
      m_emaAnalysis.Analyze();

      // Run all SMC section analyses
      m_structure.Analyze();    // Section 3 - Must run before MACD/RSI for trend data
      m_fvg.Analyze();          // Section 7
      m_orderBlock.Analyze();   // Section 8
      m_liquidity.Analyze();    // Section 5
      m_fibonacci.Analyze();    // Section 9
      m_session.Analyze();      // Session Analysis

      // Section 6: MACD/RSI Momentum (after structure for trend alignment check)
      m_macdRsi.Analyze();

      // Calculate HTF/LTF alignment (now uses EMA data)
      AnalyzeHTFLTFAlignment();

      // Calculate confluence score (includes momentum now)
      m_confluence.Calculate(); // Section 11

      // Section 12: Risk Management (after confluence for risk adjustment)
      m_riskMgmt.Analyze();
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
   // Enhanced EMA Getters
   double GetEMATrendStrength() { return g_sectionResults.emaTrendStrength; }
   string GetEMATrendStrengthLabel() { return g_sectionResults.emaTrendStrengthLabel; }
   bool IsEMAStackedBullish() { return g_sectionResults.emaStackedBullish; }
   bool IsEMAStackedBearish() { return g_sectionResults.emaStackedBearish; }
   int GetCrossoverBarsAgo() { return g_sectionResults.emaCrossoverBarsAgo; }

   // Section 6: MACD/RSI Getters
   double GetMACD() { return g_sectionResults.macdMain; }
   double GetMACDSignal() { return g_sectionResults.macdSignal; }
   double GetMACDHistogram() { return g_sectionResults.macdHistogram; }
   double GetRSI() { return g_sectionResults.rsiValue; }
   bool IsMACDBullish() { return g_sectionResults.macdBullish; }
   bool IsMACDBearish() { return g_sectionResults.macdBearish; }
   bool IsRSIOverbought() { return g_sectionResults.rsiOverbought; }
   bool IsRSIOversold() { return g_sectionResults.rsiOversold; }
   string GetMomentumBias() { return g_sectionResults.momentumBias; }
   bool IsMomentumAligned() { return g_sectionResults.momentumAligned; }
   bool HasBullishDivergence() { return g_sectionResults.macdDivergenceBullish; }
   bool HasBearishDivergence() { return g_sectionResults.macdDivergenceBearish; }

   // Section 12: Risk Management Getters
   double GetRecommendedLots() { return g_sectionResults.recommendedLotSize; }
   double GetRiskPercent() { return g_sectionResults.riskPercent; }
   bool CanTrade() { return g_sectionResults.canTrade; }
   string GetRiskStatus() { return g_sectionResults.riskStatus; }
   double GetDrawdownPercent() { return g_sectionResults.currentDrawdownPercent; }
   double GetDailyPnLPercent() { return g_sectionResults.dailyPnLPercent; }
   double GetMarginLevel() { return g_sectionResults.marginLevel; }
   bool IsMarginOK() { return g_sectionResults.marginOK; }
   bool IsDrawdownOK() { return g_sectionResults.drawdownOK; }
   bool IsDailyLossOK() { return g_sectionResults.dailyLossOK; }
   bool IsInRecoveryMode() { return g_sectionResults.inRecoveryMode; }
};

//+------------------------------------------------------------------+
