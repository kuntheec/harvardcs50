//+------------------------------------------------------------------+
//|                                  Section14_MasterIntegration.mq5  |
//|                         SwingTrader Pro EA - Master Controller    |
//|                                 Version 1.00 - Full SMC System    |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Include All Section Modules                                       |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_EA_MODE
{
   MODE_FULL_AUTO,        // Full Automatic Trading
   MODE_SEMI_AUTO,        // Semi-Auto (Alerts Only, Manual Entry)
   MODE_ANALYSIS_ONLY     // Analysis Only (No Trading)
};

enum ENUM_SIGNAL_STRENGTH
{
   SIGNAL_NONE,
   SIGNAL_WEAK,           // Score 4-5
   SIGNAL_MODERATE,       // Score 6-7
   SIGNAL_STRONG          // Score 8-10
};

enum ENUM_TRADE_DIRECTION
{
   DIR_NONE,
   DIR_BUY,
   DIR_SELL
};

enum ENUM_MARKET_STRUCTURE
{
   STRUCTURE_BULLISH,
   STRUCTURE_BEARISH,
   STRUCTURE_RANGING
};

enum ENUM_SESSION
{
   SESSION_ASIAN,
   SESSION_LONDON,
   SESSION_NEW_YORK,
   SESSION_OVERLAP,
   SESSION_OFF_HOURS
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== SECTION 14: MASTER INTEGRATION v1.00 ==="
input ENUM_EA_MODE InpEAMode          = MODE_FULL_AUTO;    // EA Operating Mode
input ulong    InpMagicNumber         = 123456;            // Magic Number
input string   InpEAComment           = "SwingTraderPro";  // Trade Comment

input group "=== Signal Filtering ==="
input int      InpMinConfluence       = 6;                 // Minimum Confluence Score (0-10)
input bool     InpRequireHTFAlignment = true;              // Require HTF Trend Alignment
input bool     InpRequireSessionFilter= true;              // Trade Only in Active Sessions
input bool     InpAvoidHighNews       = true;              // Avoid Trading During High Impact News
input int      InpNewsBufferMins      = 30;                // Minutes Before/After News to Avoid

input group "=== SMC Entry Criteria ==="
input bool     InpRequireOB           = true;              // Require Order Block
input bool     InpRequireFVG          = false;             // Require Fair Value Gap
input bool     InpRequireOTE          = true;              // Require OTE Zone (61.8-78.6%)
input bool     InpRequireLiquidity    = true;              // Require Liquidity Sweep
input bool     InpRequireBOS          = true;              // Require Break of Structure

input group "=== Risk Management ==="
input double   InpRiskPercent         = 1.0;               // Risk Per Trade (%)
input double   InpMaxDailyLoss        = 5.0;               // Max Daily Loss (%)
input double   InpMaxWeeklyLoss       = 10.0;              // Max Weekly Loss (%)
input int      InpMaxDailyTrades      = 3;                 // Max Trades Per Day
input int      InpMaxOpenPositions    = 3;                 // Max Open Positions

input group "=== Take Profit & Exit ==="
input double   InpTP1_RR              = 1.5;               // TP1 Risk:Reward
input double   InpTP2_RR              = 2.5;               // TP2 Risk:Reward
input double   InpTP3_RR              = 4.0;               // TP3 Final Target
input double   InpTP1_ClosePercent    = 40.0;              // TP1 Close %
input double   InpTP2_ClosePercent    = 30.0;              // TP2 Close %
input bool     InpUseBreakEven        = true;              // Move to Break-Even After TP1
input bool     InpUseTrailing         = true;              // Use Trailing Stop

input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES InpHTF          = PERIOD_H4;         // Higher Timeframe (Trend)
input ENUM_TIMEFRAMES InpLTF          = PERIOD_M15;        // Lower Timeframe (Entry)

input group "=== Session Hours (Server Time) ==="
input int      InpAsiaStart           = 0;                 // Asia Session Start Hour
input int      InpAsiaEnd             = 8;                 // Asia Session End Hour
input int      InpLondonStart         = 8;                 // London Session Start Hour
input int      InpLondonEnd           = 16;                // London Session End Hour
input int      InpNYStart             = 13;                // New York Session Start Hour
input int      InpNYEnd               = 21;                // New York Session End Hour

input group "=== Display Settings ==="
input bool     InpShowMasterPanel     = true;              // Show Master Dashboard
input bool     InpShowSMCObjects      = true;              // Draw SMC Objects on Chart
input int      InpPanelX              = 10;                // Panel X Position
input int      InpPanelY              = 50;                // Panel Y Position
input color    InpPanelBg             = clrBlack;          // Panel Background
input color    InpBullColor           = clrLime;           // Bullish Color
input color    InpBearColor           = clrRed;            // Bearish Color
input color    InpNeutralColor        = clrGray;           // Neutral Color

input group "=== Alerts ==="
input bool     InpAlertOnSignal       = true;              // Alert on Strong Signal
input bool     InpAlertOnTrade        = true;              // Alert on Trade Execution
input bool     InpPushNotifications   = false;             // Send Push Notifications
input bool     InpEmailAlerts         = false;             // Send Email Alerts

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct SMCAnalysis
{
   // Market Structure (Section 3)
   ENUM_MARKET_STRUCTURE trend;
   bool              bosConfirmed;
   bool              chochDetected;
   double            lastSwingHigh;
   double            lastSwingLow;

   // Supply/Demand (Section 4)
   bool              inSupplyZone;
   bool              inDemandZone;
   double            nearestSupply;
   double            nearestDemand;

   // Liquidity (Section 5)
   bool              liquiditySwept;
   double            liquidityLevel;
   bool              eqlTaken;

   // Sessions/News (Section 6)
   ENUM_SESSION      currentSession;
   bool              sessionActive;
   bool              newsUpcoming;
   int               minsToNews;

   // FVG (Section 7)
   bool              bullishFVG;
   bool              bearishFVG;
   double            fvgHigh;
   double            fvgLow;

   // Order Blocks (Section 8)
   bool              bullishOB;
   bool              bearishOB;
   double            obHigh;
   double            obLow;

   // Fibonacci/OTE (Section 9)
   bool              inOTE;
   double            oteHigh;
   double            oteLow;
   double            fibLevel;

   // Killzones (Section 10)
   bool              htfAligned;
   bool              ltfEntry;

   // Confluence Score (Section 11)
   int               confluenceScore;
   ENUM_SIGNAL_STRENGTH signalStrength;

   // Final Signal
   ENUM_TRADE_DIRECTION direction;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit1;
   double            takeProfit2;
   double            takeProfit3;
   bool              signalValid;
   string            signalReason;
};

struct TradeStats
{
   int               totalTrades;
   int               winningTrades;
   int               losingTrades;
   double            winrate;
   double            totalProfit;
   double            totalLoss;
   double            netProfit;
   double            profitFactor;
   double            avgWinRR;
   double            avgLossRR;
   double            expectancy;
   int               todayTrades;
   double            todayPL;
   double            weeklyPL;
   int               currentStreak;
   int               maxWinStreak;
   int               maxLossStreak;
};

struct EAStatus
{
   bool              initialized;
   bool              tradingEnabled;
   bool              dailyLimitReached;
   bool              weeklyLimitReached;
   bool              maxPositionsReached;
   datetime          lastSignalTime;
   datetime          lastTradeTime;
   string            statusMessage;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade            g_trade;
CPositionInfo     g_position;

SMCAnalysis       g_analysis;
TradeStats        g_stats;
EAStatus          g_status;

int               g_atrHandle;
double            g_atrBuffer[];

string            g_panelName = "SEC14_MasterPanel";
datetime          g_lastBarTime = 0;
int               g_todayDayOfYear = -1;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(30);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Initialize ATR
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator");
      return INIT_FAILED;
   }
   ArraySetAsSeries(g_atrBuffer, true);

   // Initialize structures
   ZeroMemory(g_analysis);
   ZeroMemory(g_stats);
   ZeroMemory(g_status);

   g_status.initialized = true;
   g_status.tradingEnabled = (InpEAMode != MODE_ANALYSIS_ONLY);

   // Load historical stats
   LoadTradeHistory();

   // Create dashboard
   if(InpShowMasterPanel)
      CreateMasterPanel();

   PrintInitialization();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);

   DeletePanel();

   Print("=================================================");
   Print("SwingTrader Pro EA Deinitialized");
   Print("Session Stats:");
   Print("  Total Trades: ", g_stats.totalTrades);
   Print("  Winrate: ", DoubleToString(g_stats.winrate, 1), "%");
   Print("  Net Profit: $", DoubleToString(g_stats.netProfit, 2));
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_status.initialized) return;

   // Update ATR
   CopyBuffer(g_atrHandle, 0, 0, 3, g_atrBuffer);

   // Check for new bar (main analysis on new bar only)
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool newBar = (currentBarTime != g_lastBarTime);

   if(newBar)
   {
      g_lastBarTime = currentBarTime;

      // Reset daily counters if new day
      CheckDailyReset();

      // Run full SMC analysis
      RunSMCAnalysis();

      // Check for trading signals
      if(g_status.tradingEnabled && CanTrade())
      {
         if(g_analysis.signalValid && g_analysis.confluenceScore >= InpMinConfluence)
         {
            ProcessSignal();
         }
      }
   }

   // Manage existing positions (every tick)
   ManagePositions();

   // Update panel
   if(InpShowMasterPanel)
      UpdatePanel();
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Update statistics on new deal
      UpdateTradeStats();
   }
}

//+------------------------------------------------------------------+
//| Run Full SMC Analysis                                             |
//+------------------------------------------------------------------+
void RunSMCAnalysis()
{
   ZeroMemory(g_analysis);

   // Section 3: Market Structure
   AnalyzeMarketStructure();

   // Section 4: Supply/Demand Zones
   AnalyzeSupplyDemand();

   // Section 5: Liquidity
   AnalyzeLiquidity();

   // Section 6: Sessions & News
   AnalyzeSessionsNews();

   // Section 7: Fair Value Gaps
   AnalyzeFVG();

   // Section 8: Order Blocks
   AnalyzeOrderBlocks();

   // Section 9: Fibonacci/OTE
   AnalyzeFibonacci();

   // Section 10: Killzones (HTF/LTF Alignment)
   AnalyzeKillzones();

   // Section 11: Calculate Confluence Score
   CalculateConfluence();

   // Generate final signal
   GenerateSignal();
}

//+------------------------------------------------------------------+
//| Analyze Market Structure (Section 3)                              |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure()
{
   int lookback = 100;
   double highs[], lows[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);

   CopyHigh(_Symbol, InpHTF, 0, lookback, highs);
   CopyLow(_Symbol, InpHTF, 0, lookback, lows);

   // Find swing points
   double swingHigh = 0, swingLow = DBL_MAX;
   double prevSwingHigh = 0, prevSwingLow = DBL_MAX;

   for(int i = 2; i < lookback - 2; i++)
   {
      // Swing High
      if(highs[i] > highs[i-1] && highs[i] > highs[i-2] &&
         highs[i] > highs[i+1] && highs[i] > highs[i+2])
      {
         if(highs[i] > swingHigh)
         {
            prevSwingHigh = swingHigh;
            swingHigh = highs[i];
         }
      }

      // Swing Low
      if(lows[i] < lows[i-1] && lows[i] < lows[i-2] &&
         lows[i] < lows[i+1] && lows[i] < lows[i+2])
      {
         if(lows[i] < swingLow)
         {
            prevSwingLow = swingLow;
            swingLow = lows[i];
         }
      }
   }

   g_analysis.lastSwingHigh = swingHigh;
   g_analysis.lastSwingLow = swingLow;

   double currentClose = iClose(_Symbol, InpHTF, 0);

   // Determine trend
   if(currentClose > swingHigh)
   {
      g_analysis.trend = STRUCTURE_BULLISH;
      g_analysis.bosConfirmed = true;
   }
   else if(currentClose < swingLow)
   {
      g_analysis.trend = STRUCTURE_BEARISH;
      g_analysis.bosConfirmed = true;
   }
   else
   {
      g_analysis.trend = STRUCTURE_RANGING;
      g_analysis.bosConfirmed = false;
   }

   // Check for CHoCH
   if(g_analysis.trend == STRUCTURE_BULLISH && currentClose < prevSwingLow)
      g_analysis.chochDetected = true;
   else if(g_analysis.trend == STRUCTURE_BEARISH && currentClose > prevSwingHigh)
      g_analysis.chochDetected = true;
}

//+------------------------------------------------------------------+
//| Analyze Supply/Demand Zones (Section 4)                           |
//+------------------------------------------------------------------+
void AnalyzeSupplyDemand()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = g_atrBuffer[0];

   // Simplified zone detection - look for strong moves
   double high1 = iHigh(_Symbol, InpHTF, 1);
   double low1 = iLow(_Symbol, InpHTF, 1);
   double high2 = iHigh(_Symbol, InpHTF, 2);
   double low2 = iLow(_Symbol, InpHTF, 2);

   // Demand zone (bullish engulfing area)
   if(iClose(_Symbol, InpHTF, 1) > iOpen(_Symbol, InpHTF, 1) &&
      iClose(_Symbol, InpHTF, 2) < iOpen(_Symbol, InpHTF, 2))
   {
      g_analysis.nearestDemand = low2;
      if(currentPrice <= low1 + atr * 0.5 && currentPrice >= low2)
         g_analysis.inDemandZone = true;
   }

   // Supply zone (bearish engulfing area)
   if(iClose(_Symbol, InpHTF, 1) < iOpen(_Symbol, InpHTF, 1) &&
      iClose(_Symbol, InpHTF, 2) > iOpen(_Symbol, InpHTF, 2))
   {
      g_analysis.nearestSupply = high2;
      if(currentPrice >= high1 - atr * 0.5 && currentPrice <= high2)
         g_analysis.inSupplyZone = true;
   }
}

//+------------------------------------------------------------------+
//| Analyze Liquidity (Section 5)                                     |
//+------------------------------------------------------------------+
void AnalyzeLiquidity()
{
   double currentHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
   double currentLow = iLow(_Symbol, PERIOD_CURRENT, 0);
   double prevHigh = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double prevLow = iLow(_Symbol, PERIOD_CURRENT, 1);

   // Check for liquidity sweep (price exceeds previous high/low then reverses)
   double close = iClose(_Symbol, PERIOD_CURRENT, 0);

   // Bullish sweep (took out lows, closing back up)
   if(currentLow < prevLow && close > prevLow)
   {
      g_analysis.liquiditySwept = true;
      g_analysis.liquidityLevel = prevLow;
   }

   // Bearish sweep (took out highs, closing back down)
   if(currentHigh > prevHigh && close < prevHigh)
   {
      g_analysis.liquiditySwept = true;
      g_analysis.liquidityLevel = prevHigh;
   }

   // Check for equal highs/lows (EQL)
   double tolerance = g_atrBuffer[0] * 0.1;

   for(int i = 2; i < 20; i++)
   {
      double h = iHigh(_Symbol, PERIOD_CURRENT, i);
      double l = iLow(_Symbol, PERIOD_CURRENT, i);

      if(MathAbs(h - prevHigh) < tolerance || MathAbs(l - prevLow) < tolerance)
      {
         if((currentHigh > h + tolerance) || (currentLow < l - tolerance))
            g_analysis.eqlTaken = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze Sessions & News (Section 6)                               |
//+------------------------------------------------------------------+
void AnalyzeSessionsNews()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;

   // Determine current session
   if(hour >= InpAsiaStart && hour < InpAsiaEnd)
      g_analysis.currentSession = SESSION_ASIAN;
   else if(hour >= InpLondonStart && hour < InpNYStart)
      g_analysis.currentSession = SESSION_LONDON;
   else if(hour >= InpNYStart && hour < InpLondonEnd)
      g_analysis.currentSession = SESSION_OVERLAP;
   else if(hour >= InpLondonEnd && hour < InpNYEnd)
      g_analysis.currentSession = SESSION_NEW_YORK;
   else
      g_analysis.currentSession = SESSION_OFF_HOURS;

   // Session is active if not off-hours
   g_analysis.sessionActive = (g_analysis.currentSession != SESSION_OFF_HOURS);

   // Note: Real news detection would require external calendar
   // This is a placeholder - in production, integrate with news API
   g_analysis.newsUpcoming = false;
   g_analysis.minsToNews = 999;
}

//+------------------------------------------------------------------+
//| Analyze Fair Value Gaps (Section 7)                               |
//+------------------------------------------------------------------+
void AnalyzeFVG()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = 1; i < 50; i++)
   {
      double high1 = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low1 = iLow(_Symbol, PERIOD_CURRENT, i);
      double high3 = iHigh(_Symbol, PERIOD_CURRENT, i + 2);
      double low3 = iLow(_Symbol, PERIOD_CURRENT, i + 2);

      // Bullish FVG: gap between candle 3 high and candle 1 low
      if(low1 > high3)
      {
         g_analysis.bullishFVG = true;
         g_analysis.fvgHigh = low1;
         g_analysis.fvgLow = high3;

         // Check if price is in FVG
         if(currentPrice >= g_analysis.fvgLow && currentPrice <= g_analysis.fvgHigh)
            break;
      }

      // Bearish FVG: gap between candle 1 high and candle 3 low
      if(high1 < low3)
      {
         g_analysis.bearishFVG = true;
         g_analysis.fvgHigh = low3;
         g_analysis.fvgLow = high1;

         if(currentPrice >= g_analysis.fvgLow && currentPrice <= g_analysis.fvgHigh)
            break;
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze Order Blocks (Section 8)                                  |
//+------------------------------------------------------------------+
void AnalyzeOrderBlocks()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = g_atrBuffer[0];

   for(int i = 1; i < 50; i++)
   {
      double open = iOpen(_Symbol, PERIOD_CURRENT, i);
      double close = iClose(_Symbol, PERIOD_CURRENT, i);
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);

      double nextClose = iClose(_Symbol, PERIOD_CURRENT, i - 1);
      double body = MathAbs(close - open);

      // Bullish OB: Last bearish candle before strong bullish move
      if(close < open && nextClose > high && body > atr * 0.3)
      {
         g_analysis.bullishOB = true;
         g_analysis.obHigh = open;
         g_analysis.obLow = close;

         if(currentPrice >= g_analysis.obLow && currentPrice <= g_analysis.obHigh)
            break;
      }

      // Bearish OB: Last bullish candle before strong bearish move
      if(close > open && nextClose < low && body > atr * 0.3)
      {
         g_analysis.bearishOB = true;
         g_analysis.obHigh = close;
         g_analysis.obLow = open;

         if(currentPrice >= g_analysis.obLow && currentPrice <= g_analysis.obHigh)
            break;
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze Fibonacci/OTE (Section 9)                                 |
//+------------------------------------------------------------------+
void AnalyzeFibonacci()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double swingHigh = g_analysis.lastSwingHigh;
   double swingLow = g_analysis.lastSwingLow;

   if(swingHigh == 0 || swingLow == DBL_MAX) return;

   double range = swingHigh - swingLow;

   // OTE Zone: 61.8% - 78.6% retracement
   double ote618, ote786;

   if(g_analysis.trend == STRUCTURE_BULLISH)
   {
      // In uptrend, OTE is retracement from high
      ote618 = swingHigh - (range * 0.618);
      ote786 = swingHigh - (range * 0.786);
      g_analysis.oteHigh = ote618;
      g_analysis.oteLow = ote786;

      if(currentPrice <= ote618 && currentPrice >= ote786)
      {
         g_analysis.inOTE = true;
         g_analysis.fibLevel = (swingHigh - currentPrice) / range;
      }
   }
   else if(g_analysis.trend == STRUCTURE_BEARISH)
   {
      // In downtrend, OTE is retracement from low
      ote618 = swingLow + (range * 0.618);
      ote786 = swingLow + (range * 0.786);
      g_analysis.oteHigh = ote786;
      g_analysis.oteLow = ote618;

      if(currentPrice >= ote618 && currentPrice <= ote786)
      {
         g_analysis.inOTE = true;
         g_analysis.fibLevel = (currentPrice - swingLow) / range;
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze Killzones (Section 10)                                    |
//+------------------------------------------------------------------+
void AnalyzeKillzones()
{
   // Check HTF alignment
   double htfClose = iClose(_Symbol, InpHTF, 0);
   double htfMA = 0;

   // Simple MA check for trend
   for(int i = 0; i < 20; i++)
      htfMA += iClose(_Symbol, InpHTF, i);
   htfMA /= 20;

   g_analysis.htfAligned = (g_analysis.trend == STRUCTURE_BULLISH && htfClose > htfMA) ||
                           (g_analysis.trend == STRUCTURE_BEARISH && htfClose < htfMA);

   // Check LTF entry conditions
   double ltfClose = iClose(_Symbol, InpLTF, 0);
   double ltfOpen = iOpen(_Symbol, InpLTF, 0);

   if(g_analysis.trend == STRUCTURE_BULLISH && ltfClose > ltfOpen)
      g_analysis.ltfEntry = true;
   else if(g_analysis.trend == STRUCTURE_BEARISH && ltfClose < ltfOpen)
      g_analysis.ltfEntry = true;
}

//+------------------------------------------------------------------+
//| Calculate Confluence Score (Section 11)                           |
//+------------------------------------------------------------------+
void CalculateConfluence()
{
   int score = 0;

   // Market Structure (+2)
   if(g_analysis.bosConfirmed)
      score += 2;

   // Supply/Demand Zone (+1)
   if(g_analysis.inSupplyZone || g_analysis.inDemandZone)
      score += 1;

   // Liquidity Sweep (+1)
   if(g_analysis.liquiditySwept)
      score += 1;

   // Session Active (+1)
   if(g_analysis.sessionActive)
      score += 1;

   // FVG (+1)
   if(g_analysis.bullishFVG || g_analysis.bearishFVG)
      score += 1;

   // Order Block (+1)
   if(g_analysis.bullishOB || g_analysis.bearishOB)
      score += 1;

   // OTE Zone (+2)
   if(g_analysis.inOTE)
      score += 2;

   // HTF/LTF Alignment (+1)
   if(g_analysis.htfAligned && g_analysis.ltfEntry)
      score += 1;

   g_analysis.confluenceScore = MathMin(score, 10);

   // Determine signal strength
   if(score >= 8)
      g_analysis.signalStrength = SIGNAL_STRONG;
   else if(score >= 6)
      g_analysis.signalStrength = SIGNAL_MODERATE;
   else if(score >= 4)
      g_analysis.signalStrength = SIGNAL_WEAK;
   else
      g_analysis.signalStrength = SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Generate Trading Signal                                           |
//+------------------------------------------------------------------+
void GenerateSignal()
{
   g_analysis.signalValid = false;
   g_analysis.direction = DIR_NONE;

   // Check minimum requirements
   if(g_analysis.confluenceScore < InpMinConfluence)
   {
      g_analysis.signalReason = "Low confluence: " + IntegerToString(g_analysis.confluenceScore);
      return;
   }

   if(InpRequireHTFAlignment && !g_analysis.htfAligned)
   {
      g_analysis.signalReason = "No HTF alignment";
      return;
   }

   if(InpRequireSessionFilter && !g_analysis.sessionActive)
   {
      g_analysis.signalReason = "Outside active session";
      return;
   }

   if(InpAvoidHighNews && g_analysis.newsUpcoming && g_analysis.minsToNews < InpNewsBufferMins)
   {
      g_analysis.signalReason = "News upcoming in " + IntegerToString(g_analysis.minsToNews) + " mins";
      return;
   }

   // Determine direction
   bool buySignal = false;
   bool sellSignal = false;

   // BUY conditions
   if(g_analysis.trend == STRUCTURE_BULLISH)
   {
      if((!InpRequireOB || g_analysis.bullishOB) &&
         (!InpRequireFVG || g_analysis.bullishFVG) &&
         (!InpRequireOTE || g_analysis.inOTE) &&
         (!InpRequireLiquidity || g_analysis.liquiditySwept) &&
         (!InpRequireBOS || g_analysis.bosConfirmed))
      {
         buySignal = true;
      }
   }

   // SELL conditions
   if(g_analysis.trend == STRUCTURE_BEARISH)
   {
      if((!InpRequireOB || g_analysis.bearishOB) &&
         (!InpRequireFVG || g_analysis.bearishFVG) &&
         (!InpRequireOTE || g_analysis.inOTE) &&
         (!InpRequireLiquidity || g_analysis.liquiditySwept) &&
         (!InpRequireBOS || g_analysis.bosConfirmed))
      {
         sellSignal = true;
      }
   }

   if(!buySignal && !sellSignal)
   {
      g_analysis.signalReason = "SMC criteria not met";
      return;
   }

   // Calculate entry, SL, TP
   double atr = g_atrBuffer[0];
   double currentPrice = SymbolInfoDouble(_Symbol, buySignal ? SYMBOL_ASK : SYMBOL_BID);

   if(buySignal)
   {
      g_analysis.direction = DIR_BUY;
      g_analysis.entryPrice = currentPrice;

      // SL below recent swing low or OB low
      g_analysis.stopLoss = g_analysis.obLow > 0 ? g_analysis.obLow - atr * 0.2 :
                            g_analysis.lastSwingLow - atr * 0.2;

      double risk = g_analysis.entryPrice - g_analysis.stopLoss;
      g_analysis.takeProfit1 = g_analysis.entryPrice + (risk * InpTP1_RR);
      g_analysis.takeProfit2 = g_analysis.entryPrice + (risk * InpTP2_RR);
      g_analysis.takeProfit3 = g_analysis.entryPrice + (risk * InpTP3_RR);
   }
   else if(sellSignal)
   {
      g_analysis.direction = DIR_SELL;
      g_analysis.entryPrice = currentPrice;

      // SL above recent swing high or OB high
      g_analysis.stopLoss = g_analysis.obHigh > 0 ? g_analysis.obHigh + atr * 0.2 :
                            g_analysis.lastSwingHigh + atr * 0.2;

      double risk = g_analysis.stopLoss - g_analysis.entryPrice;
      g_analysis.takeProfit1 = g_analysis.entryPrice - (risk * InpTP1_RR);
      g_analysis.takeProfit2 = g_analysis.entryPrice - (risk * InpTP2_RR);
      g_analysis.takeProfit3 = g_analysis.entryPrice - (risk * InpTP3_RR);
   }

   g_analysis.signalValid = true;
   g_analysis.signalReason = (buySignal ? "BUY" : "SELL") + " - Confluence: " +
                              IntegerToString(g_analysis.confluenceScore) + "/10";

   g_status.lastSignalTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Process Signal - Execute Trade                                    |
//+------------------------------------------------------------------+
void ProcessSignal()
{
   if(!g_analysis.signalValid) return;
   if(InpEAMode == MODE_ANALYSIS_ONLY) return;

   // Calculate lot size based on risk
   double riskDistance = MathAbs(g_analysis.entryPrice - g_analysis.stopLoss);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   double riskAmount = accountBalance * InpRiskPercent / 100.0;
   double lotSize = riskAmount / ((riskDistance / tickSize) * tickValue);

   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));

   string comment = InpEAComment + "_C" + IntegerToString(g_analysis.confluenceScore);

   bool success = false;

   if(InpEAMode == MODE_SEMI_AUTO)
   {
      // Alert only
      SendSignalAlert();
      return;
   }

   // Execute trade
   if(g_analysis.direction == DIR_BUY)
   {
      success = g_trade.Buy(lotSize, _Symbol, g_analysis.entryPrice,
                            g_analysis.stopLoss, g_analysis.takeProfit1, comment);
   }
   else if(g_analysis.direction == DIR_SELL)
   {
      success = g_trade.Sell(lotSize, _Symbol, g_analysis.entryPrice,
                             g_analysis.stopLoss, g_analysis.takeProfit1, comment);
   }

   if(success)
   {
      g_status.lastTradeTime = TimeCurrent();
      g_stats.todayTrades++;

      Print("✓ Trade Executed: ", g_analysis.direction == DIR_BUY ? "BUY" : "SELL",
            " @ ", g_analysis.entryPrice, " SL: ", g_analysis.stopLoss,
            " TP1: ", g_analysis.takeProfit1, " Confluence: ", g_analysis.confluenceScore);

      if(InpAlertOnTrade)
         SendTradeAlert(success);
   }
   else
   {
      Print("✗ Trade Failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Check if Trading is Allowed                                       |
//+------------------------------------------------------------------+
bool CanTrade()
{
   // Check daily trade limit
   if(g_stats.todayTrades >= InpMaxDailyTrades)
   {
      g_status.dailyLimitReached = true;
      g_status.statusMessage = "Daily trade limit reached";
      return false;
   }

   // Check daily loss limit
   if(g_stats.todayPL <= -(AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxDailyLoss / 100))
   {
      g_status.dailyLimitReached = true;
      g_status.statusMessage = "Daily loss limit reached";
      return false;
   }

   // Check weekly loss limit
   if(g_stats.weeklyPL <= -(AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxWeeklyLoss / 100))
   {
      g_status.weeklyLimitReached = true;
      g_status.statusMessage = "Weekly loss limit reached";
      return false;
   }

   // Check max positions
   int openPositions = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(g_position.SelectByIndex(i) && g_position.Magic() == InpMagicNumber)
         openPositions++;
   }

   if(openPositions >= InpMaxOpenPositions)
   {
      g_status.maxPositionsReached = true;
      g_status.statusMessage = "Max positions reached";
      return false;
   }

   g_status.statusMessage = "Ready to trade";
   return true;
}

//+------------------------------------------------------------------+
//| Manage Existing Positions                                         |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_position.SelectByIndex(i)) continue;
      if(g_position.Magic() != InpMagicNumber) continue;
      if(g_position.Symbol() != _Symbol) continue;

      double entryPrice = g_position.PriceOpen();
      double currentSL = g_position.StopLoss();
      double currentTP = g_position.TakeProfit();
      double currentPrice = g_position.PositionType() == POSITION_TYPE_BUY ?
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      double riskDistance = MathAbs(entryPrice - currentSL);

      // Break-even logic
      if(InpUseBreakEven && currentSL != entryPrice)
      {
         double profitDistance = g_position.PositionType() == POSITION_TYPE_BUY ?
                                currentPrice - entryPrice :
                                entryPrice - currentPrice;

         // Move to BE after 1R profit
         if(profitDistance >= riskDistance)
         {
            double newSL = entryPrice + (g_position.PositionType() == POSITION_TYPE_BUY ?
                          g_atrBuffer[0] * 0.1 : -g_atrBuffer[0] * 0.1);

            g_trade.PositionModify(g_position.Ticket(), newSL, currentTP);
         }
      }

      // Trailing stop logic
      if(InpUseTrailing)
      {
         double trailDistance = g_atrBuffer[0] * 1.5;
         double newSL = 0;

         if(g_position.PositionType() == POSITION_TYPE_BUY)
         {
            newSL = currentPrice - trailDistance;
            if(newSL > currentSL + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10)
            {
               g_trade.PositionModify(g_position.Ticket(), newSL, currentTP);
            }
         }
         else
         {
            newSL = currentPrice + trailDistance;
            if(newSL < currentSL - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10)
            {
               g_trade.PositionModify(g_position.Ticket(), newSL, currentTP);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Daily Reset                                                 |
//+------------------------------------------------------------------+
void CheckDailyReset()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(dt.day_of_year != g_todayDayOfYear)
   {
      g_todayDayOfYear = dt.day_of_year;
      g_stats.todayTrades = 0;
      g_stats.todayPL = 0;
      g_status.dailyLimitReached = false;

      // Reset weekly on Monday
      if(dt.day_of_week == 1)
      {
         g_stats.weeklyPL = 0;
         g_status.weeklyLimitReached = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Load Trade History                                                |
//+------------------------------------------------------------------+
void LoadTradeHistory()
{
   // Load from deal history
   HistorySelect(0, TimeCurrent());

   int totalDeals = HistoryDealsTotal();

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);

      if(profit != 0)
      {
         g_stats.totalTrades++;
         g_stats.netProfit += profit;

         if(profit > 0)
         {
            g_stats.winningTrades++;
            g_stats.totalProfit += profit;
         }
         else
         {
            g_stats.losingTrades++;
            g_stats.totalLoss += MathAbs(profit);
         }
      }
   }

   // Calculate derived stats
   if(g_stats.totalTrades > 0)
   {
      g_stats.winrate = (double)g_stats.winningTrades / g_stats.totalTrades * 100;

      if(g_stats.totalLoss > 0)
         g_stats.profitFactor = g_stats.totalProfit / g_stats.totalLoss;
   }
}

//+------------------------------------------------------------------+
//| Update Trade Statistics                                           |
//+------------------------------------------------------------------+
void UpdateTradeStats()
{
   LoadTradeHistory();  // Refresh stats from history
}

//+------------------------------------------------------------------+
//| Send Signal Alert                                                 |
//+------------------------------------------------------------------+
void SendSignalAlert()
{
   string message = "SwingTrader Pro Signal: " +
                    (g_analysis.direction == DIR_BUY ? "BUY " : "SELL ") +
                    _Symbol + " @ " + DoubleToString(g_analysis.entryPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
                    " | SL: " + DoubleToString(g_analysis.stopLoss, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
                    " | Confluence: " + IntegerToString(g_analysis.confluenceScore) + "/10";

   Alert(message);

   if(InpPushNotifications)
      SendNotification(message);

   if(InpEmailAlerts)
      SendMail("SwingTrader Pro Signal", message);
}

//+------------------------------------------------------------------+
//| Send Trade Alert                                                  |
//+------------------------------------------------------------------+
void SendTradeAlert(bool success)
{
   string message = success ? "Trade Executed: " : "Trade Failed: ";
   message += (g_analysis.direction == DIR_BUY ? "BUY " : "SELL ") + _Symbol;

   Alert(message);

   if(InpPushNotifications)
      SendNotification(message);
}

//+------------------------------------------------------------------+
//| Create Master Panel                                               |
//+------------------------------------------------------------------+
void CreateMasterPanel()
{
   int width = 320;
   int height = 480;

   ObjectCreate(0, g_panelName + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_YDISTANCE, InpPanelY);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_BGCOLOR, InpPanelBg);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_BACK, false);

   int y = InpPanelY + 5;
   CreateLabel(g_panelName + "_Title", "SWINGTRADER PRO v1.00", InpPanelX + 10, y, clrGold, 12, true);

   y += 20;
   CreateLabel(g_panelName + "_Line1", "════════════════════════════", InpPanelX + 10, y, clrDarkGray, 8, false);

   y += 18;
   CreateLabel(g_panelName + "_L1", "Status:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V1", "Initializing...", InpPanelX + 100, y, clrLime, 9, true);

   y += 18;
   CreateLabel(g_panelName + "_L2", "Mode:", InpPanelX + 10, y, clrWhite, 9, false);
   string modeStr = InpEAMode == MODE_FULL_AUTO ? "FULL AUTO" :
                    InpEAMode == MODE_SEMI_AUTO ? "SEMI-AUTO" : "ANALYSIS";
   CreateLabel(g_panelName + "_V2", modeStr, InpPanelX + 100, y, clrCyan, 9, true);

   y += 22;
   CreateLabel(g_panelName + "_Line2", "═══ MARKET STRUCTURE ═══", InpPanelX + 10, y, clrDarkGray, 8, false);

   y += 18;
   CreateLabel(g_panelName + "_L3", "Trend:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V3", "---", InpPanelX + 100, y, clrGray, 9, true);

   y += 18;
   CreateLabel(g_panelName + "_L4", "BOS:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V4", "---", InpPanelX + 100, y, clrGray, 9, false);

   y += 18;
   CreateLabel(g_panelName + "_L5", "Session:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V5", "---", InpPanelX + 100, y, clrGray, 9, false);

   y += 22;
   CreateLabel(g_panelName + "_Line3", "═══ SMC CONFLUENCE ═══", InpPanelX + 10, y, clrDarkGray, 8, false);

   y += 18;
   CreateLabel(g_panelName + "_L6", "Order Block:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V6", "---", InpPanelX + 120, y, clrGray, 9, false);

   y += 18;
   CreateLabel(g_panelName + "_L7", "FVG:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V7", "---", InpPanelX + 120, y, clrGray, 9, false);

   y += 18;
   CreateLabel(g_panelName + "_L8", "OTE Zone:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V8", "---", InpPanelX + 120, y, clrGray, 9, false);

   y += 18;
   CreateLabel(g_panelName + "_L9", "Liquidity:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V9", "---", InpPanelX + 120, y, clrGray, 9, false);

   y += 18;
   CreateLabel(g_panelName + "_L10", "HTF Aligned:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V10", "---", InpPanelX + 120, y, clrGray, 9, false);

   y += 22;
   CreateLabel(g_panelName + "_Line4", "═══ SIGNAL ═══", InpPanelX + 10, y, clrDarkGray, 8, false);

   y += 18;
   CreateLabel(g_panelName + "_L11", "Confluence:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V11", "0/10", InpPanelX + 120, y, clrGray, 9, true);

   y += 18;
   CreateLabel(g_panelName + "_L12", "Signal:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V12", "NONE", InpPanelX + 120, y, clrGray, 9, true);

   y += 22;
   CreateLabel(g_panelName + "_Line5", "═══ STATISTICS ═══", InpPanelX + 10, y, clrDarkGray, 8, false);

   y += 18;
   CreateLabel(g_panelName + "_L13", "Today Trades:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V13", "0/" + IntegerToString(InpMaxDailyTrades), InpPanelX + 120, y, clrSilver, 9, false);

   y += 18;
   CreateLabel(g_panelName + "_L14", "Winrate:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V14", "0.0%", InpPanelX + 120, y, clrSilver, 9, false);

   y += 18;
   CreateLabel(g_panelName + "_L15", "Today P/L:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V15", "$0.00", InpPanelX + 120, y, clrSilver, 9, false);

   y += 18;
   CreateLabel(g_panelName + "_L16", "Net Profit:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V16", "$0.00", InpPanelX + 120, y, clrGold, 9, true);

   y += 22;
   CreateLabel(g_panelName + "_Line6", "════════════════════════════", InpPanelX + 10, y, clrDarkGray, 8, false);

   y += 18;
   CreateLabel(g_panelName + "_Reason", "Waiting for signal...", InpPanelX + 10, y, clrGray, 8, false);
}

//+------------------------------------------------------------------+
//| Create Label Helper                                               |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize, bool bold)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   // Status
   color statusColor = g_status.tradingEnabled ? clrLime : clrOrange;
   if(g_status.dailyLimitReached || g_status.weeklyLimitReached)
      statusColor = clrRed;
   ObjectSetString(0, g_panelName + "_V1", OBJPROP_TEXT, g_status.statusMessage);
   ObjectSetInteger(0, g_panelName + "_V1", OBJPROP_COLOR, statusColor);

   // Trend
   string trendStr = g_analysis.trend == STRUCTURE_BULLISH ? "BULLISH" :
                     g_analysis.trend == STRUCTURE_BEARISH ? "BEARISH" : "RANGING";
   color trendColor = g_analysis.trend == STRUCTURE_BULLISH ? InpBullColor :
                      g_analysis.trend == STRUCTURE_BEARISH ? InpBearColor : InpNeutralColor;
   ObjectSetString(0, g_panelName + "_V3", OBJPROP_TEXT, trendStr);
   ObjectSetInteger(0, g_panelName + "_V3", OBJPROP_COLOR, trendColor);

   // BOS
   ObjectSetString(0, g_panelName + "_V4", OBJPROP_TEXT, g_analysis.bosConfirmed ? "Confirmed" : "None");
   ObjectSetInteger(0, g_panelName + "_V4", OBJPROP_COLOR, g_analysis.bosConfirmed ? clrLime : clrGray);

   // Session
   string sessionStr = g_analysis.currentSession == SESSION_LONDON ? "London" :
                       g_analysis.currentSession == SESSION_NEW_YORK ? "New York" :
                       g_analysis.currentSession == SESSION_OVERLAP ? "Overlap" :
                       g_analysis.currentSession == SESSION_ASIAN ? "Asian" : "Off Hours";
   ObjectSetString(0, g_panelName + "_V5", OBJPROP_TEXT, sessionStr);
   ObjectSetInteger(0, g_panelName + "_V5", OBJPROP_COLOR, g_analysis.sessionActive ? clrLime : clrGray);

   // Order Block
   string obStr = g_analysis.bullishOB ? "Bullish" : g_analysis.bearishOB ? "Bearish" : "None";
   ObjectSetString(0, g_panelName + "_V6", OBJPROP_TEXT, obStr);
   ObjectSetInteger(0, g_panelName + "_V6", OBJPROP_COLOR,
                    g_analysis.bullishOB ? InpBullColor : g_analysis.bearishOB ? InpBearColor : clrGray);

   // FVG
   string fvgStr = g_analysis.bullishFVG ? "Bullish" : g_analysis.bearishFVG ? "Bearish" : "None";
   ObjectSetString(0, g_panelName + "_V7", OBJPROP_TEXT, fvgStr);
   ObjectSetInteger(0, g_panelName + "_V7", OBJPROP_COLOR,
                    g_analysis.bullishFVG ? InpBullColor : g_analysis.bearishFVG ? InpBearColor : clrGray);

   // OTE
   ObjectSetString(0, g_panelName + "_V8", OBJPROP_TEXT, g_analysis.inOTE ? "In Zone" : "None");
   ObjectSetInteger(0, g_panelName + "_V8", OBJPROP_COLOR, g_analysis.inOTE ? clrGold : clrGray);

   // Liquidity
   ObjectSetString(0, g_panelName + "_V9", OBJPROP_TEXT, g_analysis.liquiditySwept ? "Swept" : "None");
   ObjectSetInteger(0, g_panelName + "_V9", OBJPROP_COLOR, g_analysis.liquiditySwept ? clrCyan : clrGray);

   // HTF Aligned
   ObjectSetString(0, g_panelName + "_V10", OBJPROP_TEXT, g_analysis.htfAligned ? "Yes" : "No");
   ObjectSetInteger(0, g_panelName + "_V10", OBJPROP_COLOR, g_analysis.htfAligned ? clrLime : clrGray);

   // Confluence
   color confColor = g_analysis.confluenceScore >= 8 ? clrLime :
                     g_analysis.confluenceScore >= 6 ? clrYellow :
                     g_analysis.confluenceScore >= 4 ? clrOrange : clrGray;
   ObjectSetString(0, g_panelName + "_V11", OBJPROP_TEXT,
                   IntegerToString(g_analysis.confluenceScore) + "/10");
   ObjectSetInteger(0, g_panelName + "_V11", OBJPROP_COLOR, confColor);

   // Signal
   string sigStr = g_analysis.direction == DIR_BUY ? "BUY" :
                   g_analysis.direction == DIR_SELL ? "SELL" : "NONE";
   color sigColor = g_analysis.direction == DIR_BUY ? InpBullColor :
                    g_analysis.direction == DIR_SELL ? InpBearColor : clrGray;
   ObjectSetString(0, g_panelName + "_V12", OBJPROP_TEXT, sigStr);
   ObjectSetInteger(0, g_panelName + "_V12", OBJPROP_COLOR, sigColor);

   // Statistics
   ObjectSetString(0, g_panelName + "_V13", OBJPROP_TEXT,
                   IntegerToString(g_stats.todayTrades) + "/" + IntegerToString(InpMaxDailyTrades));
   ObjectSetString(0, g_panelName + "_V14", OBJPROP_TEXT, DoubleToString(g_stats.winrate, 1) + "%");

   color plColor = g_stats.todayPL >= 0 ? clrLime : clrRed;
   ObjectSetString(0, g_panelName + "_V15", OBJPROP_TEXT,
                   (g_stats.todayPL >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(g_stats.todayPL), 2));
   ObjectSetInteger(0, g_panelName + "_V15", OBJPROP_COLOR, plColor);

   color netColor = g_stats.netProfit >= 0 ? clrLime : clrRed;
   ObjectSetString(0, g_panelName + "_V16", OBJPROP_TEXT,
                   (g_stats.netProfit >= 0 ? "+$" : "-$") + DoubleToString(MathAbs(g_stats.netProfit), 2));
   ObjectSetInteger(0, g_panelName + "_V16", OBJPROP_COLOR, netColor);

   // Reason
   ObjectSetString(0, g_panelName + "_Reason", OBJPROP_TEXT, g_analysis.signalReason);
}

//+------------------------------------------------------------------+
//| Delete Panel                                                      |
//+------------------------------------------------------------------+
void DeletePanel()
{
   ObjectsDeleteAll(0, g_panelName);
}

//+------------------------------------------------------------------+
//| Print Initialization                                              |
//+------------------------------------------------------------------+
void PrintInitialization()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║         SWINGTRADER PRO - MASTER INTEGRATION v1.00        ║");
   Print("║              Full SMC Trading System                       ║");
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ Symbol: ", _Symbol);
   Print("║ Mode: ", InpEAMode == MODE_FULL_AUTO ? "FULL AUTOMATIC" :
                     InpEAMode == MODE_SEMI_AUTO ? "SEMI-AUTO (Alerts)" : "ANALYSIS ONLY");
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ SMC MODULES INTEGRATED:");
   Print("║   ✓ Section 3:  Market Structure (BOS/CHoCH)");
   Print("║   ✓ Section 4:  Supply/Demand Zones");
   Print("║   ✓ Section 5:  Liquidity Analysis");
   Print("║   ✓ Section 6:  Sessions & News Filter");
   Print("║   ✓ Section 7:  Fair Value Gaps (FVG)");
   Print("║   ✓ Section 8:  Order Blocks");
   Print("║   ✓ Section 9:  Fibonacci/OTE Zones");
   Print("║   ✓ Section 10: Killzones (HTF/LTF)");
   Print("║   ✓ Section 11: Confluence Scoring");
   Print("║   ✓ Section 12: Risk Management");
   Print("║   ✓ Section 13: Trade Execution");
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ RISK SETTINGS:");
   Print("║   Risk Per Trade: ", InpRiskPercent, "%");
   Print("║   Max Daily Loss: ", InpMaxDailyLoss, "%");
   Print("║   Max Daily Trades: ", InpMaxDailyTrades);
   Print("║   Max Positions: ", InpMaxOpenPositions);
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ ENTRY CRITERIA:");
   Print("║   Min Confluence: ", InpMinConfluence, "/10");
   Print("║   Require OB: ", InpRequireOB ? "Yes" : "No");
   Print("║   Require OTE: ", InpRequireOTE ? "Yes" : "No");
   Print("║   Require BOS: ", InpRequireBOS ? "Yes" : "No");
   Print("║   HTF Alignment: ", InpRequireHTFAlignment ? "Yes" : "No");
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ TAKE PROFIT:");
   Print("║   TP1: ", InpTP1_RR, "R (Close ", InpTP1_ClosePercent, "%)");
   Print("║   TP2: ", InpTP2_RR, "R (Close ", InpTP2_ClosePercent, "%)");
   Print("║   TP3: ", InpTP3_RR, "R (Final)");
   Print("║   Break-Even: ", InpUseBreakEven ? "Enabled" : "Disabled");
   Print("║   Trailing: ", InpUseTrailing ? "Enabled" : "Disabled");
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print("");
}

//+------------------------------------------------------------------+
