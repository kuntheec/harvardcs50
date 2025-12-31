//+------------------------------------------------------------------+
//|                                     Section12_RiskManagement.mq5 |
//|                                      SwingTrader Pro EA          |
//|                    Section 12: Risk Management                   |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.01"
#property description "Section 12: Risk Management v1.01"
#property description "SMC-aligned position sizing, confluence-based risk"
#property description "Dynamic ATR, correlation limits, edge tracking"

//+------------------------------------------------------------------+
//| Modification History                                              |
//+------------------------------------------------------------------+
// 2025.12.31 v1.01 - SMC Enhancements (Grok Review):
//                    - Confluence-based risk adjustment (Section 11 link)
//                    - Replaced martingale with SMC recovery mode
//                    - Dynamic ATR multipliers per instrument profile
//                    - Correlation/exposure limits per currency group
//                    - Enhanced tracking: winrate, R:R, edge metrics
//                    - Free margin validation before sizing
//                    - OnTradeTransaction for real-time P&L updates
//                    - News impact risk reduction (Section 9 link)
// 2025.12.29 v1.00 - Initial release

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Account Risk Settings ==="
input double   InpBaseRiskPercent     = 1.0;         // Base Risk Per Trade (%)
input double   InpMaxRiskPercent      = 2.0;         // Maximum Risk Per Trade (%)
input double   InpMinRiskPercent      = 0.5;         // Minimum Risk Per Trade (%)
input double   InpMaxDailyLoss        = 5.0;         // Max Daily Loss (% of Balance)
input double   InpMaxWeeklyLoss       = 10.0;        // Max Weekly Loss (% of Balance)
input double   InpMaxDrawdown         = 20.0;        // Max Drawdown (% of Starting Balance)

input group "=== SMC Confluence Risk Adjustment ==="
input bool     InpUseConfluenceRisk   = true;        // Adjust Risk by Confluence Score
input double   InpStrongSignalRisk    = 2.0;         // Risk % for Strong Signal (8-10)
input double   InpModerateSignalRisk  = 1.0;         // Risk % for Moderate Signal (6-7)
input double   InpWeakSignalRisk      = 0.5;         // Risk % for Weak Signal (4-5)
input bool     InpReduceOnNews        = true;        // Reduce Risk During News (50%)

input group "=== Position Sizing Settings ==="
input double   InpMinLots             = 0.01;        // Minimum Lot Size
input double   InpMaxLots             = 10.0;        // Maximum Lot Size
input double   InpLotStep             = 0.01;        // Lot Size Step
input bool     InpUseATRForSL         = true;        // Use ATR for Stop Loss Calculation
input double   InpFixedSLPips         = 50.0;        // Fixed SL (pips) if not using ATR

input group "=== Dynamic ATR Multipliers (per Profile) ==="
input double   InpATRMultForex        = 1.5;         // ATR Multiplier - Forex
input double   InpATRMultGold         = 2.0;         // ATR Multiplier - Gold
input double   InpATRMultSilver       = 1.8;         // ATR Multiplier - Silver
input double   InpATRMultJPY          = 1.5;         // ATR Multiplier - JPY Pairs
input double   InpATRMultCrypto       = 2.5;         // ATR Multiplier - Crypto

input group "=== Correlation & Exposure Limits ==="
input bool     InpUseCorrelationLimit = true;        // Enable Correlation Limits
input double   InpMaxUSDExposure      = 5.0;         // Max Exposure on USD Pairs (%)
input double   InpMaxEURExposure      = 5.0;         // Max Exposure on EUR Pairs (%)
input double   InpMaxGBPExposure      = 5.0;         // Max Exposure on GBP Pairs (%)
input double   InpMaxGoldExposure     = 3.0;         // Max Exposure on Gold (%)
input double   InpMaxPerInstrument    = 2.0;         // Max Risk Per Single Instrument (%)

input group "=== SMC Recovery Mode (Replaces Martingale) ==="
input bool     InpUseSMCRecovery      = true;        // Enable SMC Recovery After Loss
input bool     InpWaitForOTE          = true;        // Wait for OTE Zone After Loss
input bool     InpWaitForFVG          = true;        // Wait for FVG After Loss
input int      InpRecoveryBarsWait    = 10;          // Bars to Wait Before Recovery Entry

input group "=== Scaling Settings ==="
input bool     InpUseScaling          = true;        // Enable Position Scaling
input double   InpStage1Percent       = 30.0;        // Stage 1 Entry (% of position)
input double   InpStage2Percent       = 40.0;        // Stage 2 Entry (% of position)
input double   InpStage3Percent       = 30.0;        // Stage 3 Entry (% of position)

input group "=== Edge Tracking & Metrics ==="
input bool     InpTrackEdgeMetrics    = true;        // Track Winrate & R:R
input double   InpMinWinrateToTrade   = 40.0;        // Minimum Winrate % to Continue Trading
input double   InpMinAvgRRToTrade     = 1.0;         // Minimum Avg R:R to Continue Trading
input int      InpMinTradesForMetrics = 10;          // Min Trades Before Applying Metrics

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;        // Show Risk Panel
input int      InpPanelX              = 350;         // Panel X Position
input int      InpPanelY              = 30;          // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;        // Print Report to Experts Tab
input bool     InpAlertOnRiskLimit    = true;        // Alert When Risk Limit Hit

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_RISK_STATUS
{
   RISK_OK,                 // Risk within limits
   RISK_WARNING,            // Approaching limits
   RISK_BLOCKED,            // Trading blocked
   RISK_RECOVERY            // In SMC recovery mode
};

enum ENUM_CURRENCY_GROUP
{
   GROUP_USD,
   GROUP_EUR,
   GROUP_GBP,
   GROUP_JPY,
   GROUP_AUD,
   GROUP_CAD,
   GROUP_CHF,
   GROUP_NZD,
   GROUP_GOLD,
   GROUP_SILVER,
   GROUP_CRYPTO,
   GROUP_OTHER
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct EdgeMetrics
{
   int               totalTrades;
   int               winningTrades;
   int               losingTrades;
   double            winrate;

   double            totalRRWins;
   double            totalRRLosses;
   double            avgWinRR;
   double            avgLossRR;
   double            expectancy;

   int               currentStreak;
   int               maxWinStreak;
   int               maxLossStreak;

   bool              hasEdge;
   string            edgeStatus;
};

struct RiskMetrics
{
   double            accountBalance;
   double            accountEquity;
   double            accountFreeMargin;
   double            startingBalance;
   double            marginLevel;

   double            currentDrawdown;
   double            currentDrawdownPercent;
   double            maxDrawdownHit;

   double            dailyStartBalance;
   double            dailyPnL;
   double            dailyPnLPercent;
   int               dailyTrades;
   int               dailyWins;
   int               dailyLosses;

   double            weeklyStartBalance;
   double            weeklyPnL;
   double            weeklyPnLPercent;
   int               weeklyTrades;

   ENUM_RISK_STATUS  status;
   bool              tradingAllowed;
   string            blockReason;

   int               openPositions;
   double            totalExposure;
   double            totalRiskAmount;

   double            usdExposure;
   double            eurExposure;
   double            gbpExposure;
   double            goldExposure;

   bool              inRecoveryMode;
   int               barsSinceLoss;
   bool              waitingForOTE;
   bool              waitingForFVG;

   int               lastConfluenceScore;
   ENUM_SIGNAL_STRENGTH lastSignalStrength;
   bool              newsImpactActive;

   EdgeMetrics       edge;

   datetime          lastUpdate;
   datetime          dayStartTime;
   datetime          weekStartTime;
   datetime          lastLossTime;
};

struct LotCalculation
{
   double            calculatedLots;
   double            adjustedLots;
   double            riskAmount;
   double            riskPercent;
   double            stopLossPips;
   double            stopLossPrice;
   double            pipValue;
   double            atrMultiplier;
   bool              isValid;
   string            reason;
   bool              marginOK;
};

struct ScaledPosition
{
   double            stage1Lots;
   double            stage2Lots;
   double            stage3Lots;
   double            totalLots;
   double            avgEntryPrice;
   int               currentStage;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
SymbolInfoCache   g_symbolInfo;
InstrumentProfile g_profile;
int               g_digits;
double            g_point;

RiskMetrics       g_riskMetrics;
LotCalculation    g_lastCalc;
ScaledPosition    g_scaledPos;

double            g_startingBalance;
double            g_dailyStartBalance;
double            g_weeklyStartBalance;
datetime          g_lastDayCheck;
datetime          g_lastWeekCheck;

string            g_panelName = "RiskPanel";

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   InitSymbolInfo(g_symbolInfo, _Symbol);
   g_digits = g_symbolInfo.digits;
   g_point = g_symbolInfo.point;

   g_profile = GetInstrumentProfile(g_symbolInfo);

   g_startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyStartBalance = g_startingBalance;
   g_weeklyStartBalance = g_startingBalance;
   g_lastDayCheck = TimeCurrent();
   g_lastWeekCheck = TimeCurrent();

   InitRiskMetrics();
   PrintInitReport();

   if(InpShowPanel)
      CreatePanel();

   UpdateRiskMetrics();

   if(InpShowPanel)
      UpdatePanel();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeletePanel();

   Print("=================================================");
   Print("Risk Management EA Deinitialized");
   Print("Final Drawdown: ", DoubleToString(g_riskMetrics.currentDrawdownPercent, 2), "%");
   Print("Edge - Winrate: ", DoubleToString(g_riskMetrics.edge.winrate, 1),
         "% | Expectancy: ", DoubleToString(g_riskMetrics.edge.expectancy, 2), "R");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_M15, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      CheckDayWeekReset();
      UpdateRiskMetrics();

      if(g_riskMetrics.inRecoveryMode)
         g_riskMetrics.barsSinceLoss++;

      if(InpShowPanel)
         UpdatePanel();
   }
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler - Real-time P&L Updates                 |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      if(dealTicket > 0)
      {
         if(HistoryDealSelect(dealTicket))
         {
            ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

            if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
            {
               double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
               double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
               double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
               double netPnL = profit + commission + swap;

               bool isWin = (netPnL > 0);
               RegisterTradeResult(isWin, netPnL);
               UpdateRiskMetrics();

               if(InpShowPanel)
                  UpdatePanel();

               Print("TRADE CLOSED: ", isWin ? "WIN" : "LOSS",
                     " | P&L: $", DoubleToString(netPnL, 2));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Initialize Risk Metrics                                           |
//+------------------------------------------------------------------+
void InitRiskMetrics()
{
   g_riskMetrics.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_riskMetrics.accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_riskMetrics.accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   g_riskMetrics.startingBalance = g_startingBalance;
   g_riskMetrics.marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   g_riskMetrics.currentDrawdown = 0;
   g_riskMetrics.currentDrawdownPercent = 0;
   g_riskMetrics.maxDrawdownHit = 0;

   g_riskMetrics.dailyStartBalance = g_dailyStartBalance;
   g_riskMetrics.dailyPnL = 0;
   g_riskMetrics.dailyPnLPercent = 0;
   g_riskMetrics.dailyTrades = 0;
   g_riskMetrics.dailyWins = 0;
   g_riskMetrics.dailyLosses = 0;

   g_riskMetrics.weeklyStartBalance = g_weeklyStartBalance;
   g_riskMetrics.weeklyPnL = 0;
   g_riskMetrics.weeklyPnLPercent = 0;
   g_riskMetrics.weeklyTrades = 0;

   g_riskMetrics.status = RISK_OK;
   g_riskMetrics.tradingAllowed = true;
   g_riskMetrics.blockReason = "";

   g_riskMetrics.openPositions = 0;
   g_riskMetrics.totalExposure = 0;
   g_riskMetrics.totalRiskAmount = 0;

   g_riskMetrics.usdExposure = 0;
   g_riskMetrics.eurExposure = 0;
   g_riskMetrics.gbpExposure = 0;
   g_riskMetrics.goldExposure = 0;

   g_riskMetrics.inRecoveryMode = false;
   g_riskMetrics.barsSinceLoss = 0;
   g_riskMetrics.waitingForOTE = false;
   g_riskMetrics.waitingForFVG = false;

   g_riskMetrics.lastConfluenceScore = 0;
   g_riskMetrics.lastSignalStrength = SIGNAL_NONE;
   g_riskMetrics.newsImpactActive = false;

   InitEdgeMetrics();

   g_riskMetrics.lastUpdate = TimeCurrent();
   g_riskMetrics.dayStartTime = TimeCurrent();
   g_riskMetrics.weekStartTime = TimeCurrent();
   g_riskMetrics.lastLossTime = 0;
}

//+------------------------------------------------------------------+
//| Initialize Edge Metrics                                           |
//+------------------------------------------------------------------+
void InitEdgeMetrics()
{
   g_riskMetrics.edge.totalTrades = 0;
   g_riskMetrics.edge.winningTrades = 0;
   g_riskMetrics.edge.losingTrades = 0;
   g_riskMetrics.edge.winrate = 0;

   g_riskMetrics.edge.totalRRWins = 0;
   g_riskMetrics.edge.totalRRLosses = 0;
   g_riskMetrics.edge.avgWinRR = 0;
   g_riskMetrics.edge.avgLossRR = 0;
   g_riskMetrics.edge.expectancy = 0;

   g_riskMetrics.edge.currentStreak = 0;
   g_riskMetrics.edge.maxWinStreak = 0;
   g_riskMetrics.edge.maxLossStreak = 0;

   g_riskMetrics.edge.hasEdge = true;
   g_riskMetrics.edge.edgeStatus = "Collecting data...";
}

//+------------------------------------------------------------------+
//| Update Risk Metrics                                               |
//+------------------------------------------------------------------+
void UpdateRiskMetrics()
{
   g_riskMetrics.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_riskMetrics.accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_riskMetrics.accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   g_riskMetrics.marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   g_riskMetrics.currentDrawdown = g_startingBalance - g_riskMetrics.accountEquity;
   if(g_startingBalance > 0)
      g_riskMetrics.currentDrawdownPercent = (g_riskMetrics.currentDrawdown / g_startingBalance) * 100;

   if(g_riskMetrics.currentDrawdownPercent > g_riskMetrics.maxDrawdownHit)
      g_riskMetrics.maxDrawdownHit = g_riskMetrics.currentDrawdownPercent;

   g_riskMetrics.dailyPnL = g_riskMetrics.accountBalance - g_dailyStartBalance;
   if(g_dailyStartBalance > 0)
      g_riskMetrics.dailyPnLPercent = (g_riskMetrics.dailyPnL / g_dailyStartBalance) * 100;

   g_riskMetrics.weeklyPnL = g_riskMetrics.accountBalance - g_weeklyStartBalance;
   if(g_weeklyStartBalance > 0)
      g_riskMetrics.weeklyPnLPercent = (g_riskMetrics.weeklyPnL / g_weeklyStartBalance) * 100;

   CountOpenPositions();
   CalculateCurrencyExposure();
   UpdateEdgeMetrics();
   CheckRiskLimits();

   if(g_riskMetrics.inRecoveryMode)
      CheckRecoveryConditions();

   g_riskMetrics.lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Count Open Positions                                              |
//+------------------------------------------------------------------+
void CountOpenPositions()
{
   g_riskMetrics.openPositions = 0;
   g_riskMetrics.totalExposure = 0;
   g_riskMetrics.totalRiskAmount = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            g_riskMetrics.openPositions++;
            g_riskMetrics.totalExposure += PositionGetDouble(POSITION_VOLUME);

            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            double lots = PositionGetDouble(POSITION_VOLUME);

            if(sl > 0)
            {
               double slDistance = MathAbs(openPrice - sl);
               double pipValue = GetPipValueForLot(lots);
               double slPips = slDistance / g_symbolInfo.pipSize;
               g_riskMetrics.totalRiskAmount += slPips * pipValue;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Currency Exposure                                       |
//+------------------------------------------------------------------+
void CalculateCurrencyExposure()
{
   g_riskMetrics.usdExposure = 0;
   g_riskMetrics.eurExposure = 0;
   g_riskMetrics.gbpExposure = 0;
   g_riskMetrics.goldExposure = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         double riskPct = CalculatePositionRiskPercent(ticket);

         ENUM_CURRENCY_GROUP group = GetCurrencyGroup(symbol);

         switch(group)
         {
            case GROUP_USD:   g_riskMetrics.usdExposure += riskPct; break;
            case GROUP_EUR:   g_riskMetrics.eurExposure += riskPct; break;
            case GROUP_GBP:   g_riskMetrics.gbpExposure += riskPct; break;
            case GROUP_GOLD:  g_riskMetrics.goldExposure += riskPct; break;
            default: break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get Currency Group                                                |
//+------------------------------------------------------------------+
ENUM_CURRENCY_GROUP GetCurrencyGroup(string symbol)
{
   string sym = symbol;
   StringToUpper(sym);

   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
      return GROUP_GOLD;
   if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
      return GROUP_SILVER;
   if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0)
      return GROUP_CRYPTO;
   if(StringFind(sym, "USD") >= 0)
      return GROUP_USD;
   if(StringFind(sym, "EUR") >= 0)
      return GROUP_EUR;
   if(StringFind(sym, "GBP") >= 0)
      return GROUP_GBP;
   if(StringFind(sym, "JPY") >= 0)
      return GROUP_JPY;

   return GROUP_OTHER;
}

//+------------------------------------------------------------------+
//| Calculate Position Risk Percent                                   |
//+------------------------------------------------------------------+
double CalculatePositionRiskPercent(ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return 0;

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double lots = PositionGetDouble(POSITION_VOLUME);

   if(sl <= 0) return 0;

   double slDistance = MathAbs(openPrice - sl);
   double pipValue = GetPipValueForLot(lots);
   double slPips = slDistance / g_symbolInfo.pipSize;
   double riskAmount = slPips * pipValue;

   if(g_riskMetrics.accountBalance > 0)
      return (riskAmount / g_riskMetrics.accountBalance) * 100;

   return 0;
}

//+------------------------------------------------------------------+
//| Update Edge Metrics                                               |
//+------------------------------------------------------------------+
void UpdateEdgeMetrics()
{
   if(g_riskMetrics.edge.totalTrades > 0)
      g_riskMetrics.edge.winrate = (double)g_riskMetrics.edge.winningTrades / g_riskMetrics.edge.totalTrades * 100;

   if(g_riskMetrics.edge.winningTrades > 0)
      g_riskMetrics.edge.avgWinRR = g_riskMetrics.edge.totalRRWins / g_riskMetrics.edge.winningTrades;
   if(g_riskMetrics.edge.losingTrades > 0)
      g_riskMetrics.edge.avgLossRR = g_riskMetrics.edge.totalRRLosses / g_riskMetrics.edge.losingTrades;

   double winPct = g_riskMetrics.edge.winrate / 100.0;
   double lossPct = 1.0 - winPct;
   g_riskMetrics.edge.expectancy = (winPct * g_riskMetrics.edge.avgWinRR) - (lossPct * g_riskMetrics.edge.avgLossRR);

   if(g_riskMetrics.edge.totalTrades >= InpMinTradesForMetrics)
   {
      g_riskMetrics.edge.hasEdge = (g_riskMetrics.edge.winrate >= InpMinWinrateToTrade &&
                                     g_riskMetrics.edge.avgWinRR >= InpMinAvgRRToTrade);

      g_riskMetrics.edge.edgeStatus = g_riskMetrics.edge.hasEdge ? "EDGE CONFIRMED" : "NO EDGE - Review";
   }
   else
   {
      g_riskMetrics.edge.edgeStatus = "Collecting (" + IntegerToString(g_riskMetrics.edge.totalTrades) +
                                       "/" + IntegerToString(InpMinTradesForMetrics) + ")";
   }
}

//+------------------------------------------------------------------+
//| Check Risk Limits                                                 |
//+------------------------------------------------------------------+
void CheckRiskLimits()
{
   g_riskMetrics.status = RISK_OK;
   g_riskMetrics.tradingAllowed = true;
   g_riskMetrics.blockReason = "";

   if(g_riskMetrics.currentDrawdownPercent >= InpMaxDrawdown)
   {
      g_riskMetrics.status = RISK_BLOCKED;
      g_riskMetrics.tradingAllowed = false;
      g_riskMetrics.blockReason = "Max DD: " + DoubleToString(g_riskMetrics.currentDrawdownPercent, 1) + "%";
      if(InpAlertOnRiskLimit) Alert("RISK: ", g_riskMetrics.blockReason);
      return;
   }

   if(g_riskMetrics.dailyPnLPercent <= -InpMaxDailyLoss)
   {
      g_riskMetrics.status = RISK_BLOCKED;
      g_riskMetrics.tradingAllowed = false;
      g_riskMetrics.blockReason = "Daily limit: " + DoubleToString(MathAbs(g_riskMetrics.dailyPnLPercent), 1) + "%";
      if(InpAlertOnRiskLimit) Alert("RISK: ", g_riskMetrics.blockReason);
      return;
   }

   if(g_riskMetrics.weeklyPnLPercent <= -InpMaxWeeklyLoss)
   {
      g_riskMetrics.status = RISK_BLOCKED;
      g_riskMetrics.tradingAllowed = false;
      g_riskMetrics.blockReason = "Weekly limit: " + DoubleToString(MathAbs(g_riskMetrics.weeklyPnLPercent), 1) + "%";
      if(InpAlertOnRiskLimit) Alert("RISK: ", g_riskMetrics.blockReason);
      return;
   }

   if(InpTrackEdgeMetrics &&
      g_riskMetrics.edge.totalTrades >= InpMinTradesForMetrics &&
      !g_riskMetrics.edge.hasEdge)
   {
      g_riskMetrics.status = RISK_WARNING;
      g_riskMetrics.blockReason = "No edge - reduce size";
   }

   if(g_riskMetrics.inRecoveryMode)
   {
      g_riskMetrics.status = RISK_RECOVERY;
      g_riskMetrics.blockReason = "SMC Recovery mode";
   }

   if(g_riskMetrics.currentDrawdownPercent >= InpMaxDrawdown * 0.8 ||
      g_riskMetrics.dailyPnLPercent <= -InpMaxDailyLoss * 0.8)
   {
      if(g_riskMetrics.status == RISK_OK)
      {
         g_riskMetrics.status = RISK_WARNING;
         g_riskMetrics.blockReason = "Approaching limits (80%)";
      }
   }
}

//+------------------------------------------------------------------+
//| Check SMC Recovery Conditions                                     |
//+------------------------------------------------------------------+
void CheckRecoveryConditions()
{
   if(g_riskMetrics.barsSinceLoss < InpRecoveryBarsWait)
      return;

   if(InpWaitForOTE)
      g_riskMetrics.waitingForOTE = CheckOTEZonePresent();

   if(InpWaitForFVG)
      g_riskMetrics.waitingForFVG = CheckFVGPresent();

   bool canExitRecovery = true;
   if(InpWaitForOTE && !g_riskMetrics.waitingForOTE) canExitRecovery = false;
   if(InpWaitForFVG && !g_riskMetrics.waitingForFVG) canExitRecovery = false;

   if(canExitRecovery)
   {
      g_riskMetrics.inRecoveryMode = false;
      g_riskMetrics.barsSinceLoss = 0;
      Print("SMC RECOVERY: Conditions met, trading resumed");
   }
}

//+------------------------------------------------------------------+
//| Check OTE Zone Present                                            |
//+------------------------------------------------------------------+
bool CheckOTEZonePresent()
{
   double swingHigh = 0, swingLow = 999999;

   for(int i = 1; i <= 50; i++)
   {
      double high = iHigh(_Symbol, PERIOD_H1, i);
      double low = iLow(_Symbol, PERIOD_H1, i);
      if(high > swingHigh) swingHigh = high;
      if(low < swingLow) swingLow = low;
   }

   double range = swingHigh - swingLow;
   double oteUpper = swingHigh - (range * 0.618);
   double oteLower = swingHigh - (range * 0.786);
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   return (price >= oteLower && price <= oteUpper);
}

//+------------------------------------------------------------------+
//| Check FVG Present                                                 |
//+------------------------------------------------------------------+
bool CheckFVGPresent()
{
   for(int i = 2; i <= 10; i++)
   {
      double high1 = iHigh(_Symbol, PERIOD_H1, i);
      double low3 = iLow(_Symbol, PERIOD_H1, i-2);

      if(low3 > high1)
      {
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(price >= high1 && price <= low3)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check Day/Week Reset                                              |
//+------------------------------------------------------------------+
void CheckDayWeekReset()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime dt, lastDt, lastWeekDt;

   TimeToStruct(currentTime, dt);
   TimeToStruct(g_lastDayCheck, lastDt);
   TimeToStruct(g_lastWeekCheck, lastWeekDt);

   if(dt.day != lastDt.day || dt.mon != lastDt.mon || dt.year != lastDt.year)
   {
      g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_riskMetrics.dailyStartBalance = g_dailyStartBalance;
      g_riskMetrics.dailyPnL = 0;
      g_riskMetrics.dailyPnLPercent = 0;
      g_riskMetrics.dailyTrades = 0;
      g_riskMetrics.dailyWins = 0;
      g_riskMetrics.dailyLosses = 0;
      g_riskMetrics.dayStartTime = currentTime;
      g_lastDayCheck = currentTime;

      Print("NEW DAY - Balance: $", DoubleToString(g_dailyStartBalance, 2));
   }

   if(dt.day_of_week == 1 && lastWeekDt.day_of_week != 1)
   {
      g_weeklyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_riskMetrics.weeklyStartBalance = g_weeklyStartBalance;
      g_riskMetrics.weeklyPnL = 0;
      g_riskMetrics.weeklyPnLPercent = 0;
      g_riskMetrics.weeklyTrades = 0;
      g_riskMetrics.weekStartTime = currentTime;
      g_lastWeekCheck = currentTime;
      g_riskMetrics.inRecoveryMode = false;

      Print("NEW WEEK - Balance: $", DoubleToString(g_weeklyStartBalance, 2));
   }
}

//+------------------------------------------------------------------+
//| Get Dynamic ATR Multiplier                                        |
//+------------------------------------------------------------------+
double GetATRMultiplier()
{
   if(g_symbolInfo.isGold) return InpATRMultGold;
   if(g_symbolInfo.isSilver) return InpATRMultSilver;
   if(g_symbolInfo.isCrypto) return InpATRMultCrypto;
   if(g_symbolInfo.isJPY) return InpATRMultJPY;
   return InpATRMultForex;
}

//+------------------------------------------------------------------+
//| Get Confluence Adjusted Risk                                      |
//+------------------------------------------------------------------+
double GetConfluenceAdjustedRisk(int confluenceScore, bool newsActive = false)
{
   double riskPct = InpBaseRiskPercent;

   if(InpUseConfluenceRisk)
   {
      if(confluenceScore >= 8)
         riskPct = InpStrongSignalRisk;
      else if(confluenceScore >= 6)
         riskPct = InpModerateSignalRisk;
      else if(confluenceScore >= 4)
         riskPct = InpWeakSignalRisk;
      else
         riskPct = InpMinRiskPercent;
   }

   if(InpReduceOnNews && newsActive)
      riskPct *= 0.5;

   if(riskPct > InpMaxRiskPercent) riskPct = InpMaxRiskPercent;
   if(riskPct < InpMinRiskPercent) riskPct = InpMinRiskPercent;

   return riskPct;
}

//+------------------------------------------------------------------+
//| Check Correlation Limits                                          |
//+------------------------------------------------------------------+
bool CheckCorrelationLimits(double additionalRiskPct)
{
   if(!InpUseCorrelationLimit) return true;

   ENUM_CURRENCY_GROUP group = GetCurrencyGroup(_Symbol);
   double currentExposure = 0;
   double maxExposure = 0;

   switch(group)
   {
      case GROUP_USD:
         currentExposure = g_riskMetrics.usdExposure;
         maxExposure = InpMaxUSDExposure;
         break;
      case GROUP_EUR:
         currentExposure = g_riskMetrics.eurExposure;
         maxExposure = InpMaxEURExposure;
         break;
      case GROUP_GBP:
         currentExposure = g_riskMetrics.gbpExposure;
         maxExposure = InpMaxGBPExposure;
         break;
      case GROUP_GOLD:
         currentExposure = g_riskMetrics.goldExposure;
         maxExposure = InpMaxGoldExposure;
         break;
      default:
         return true;
   }

   if(currentExposure + additionalRiskPct > maxExposure)
   {
      Print("CORRELATION LIMIT: Exposure would exceed ", DoubleToString(maxExposure, 1), "%");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check Free Margin                                                 |
//+------------------------------------------------------------------+
bool CheckFreeMargin(double lots, double entryPrice)
{
   double marginRequired = 0;

   if(!OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, lots, entryPrice, marginRequired))
      return false;

   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   if(marginRequired > freeMargin * 0.8)
   {
      Print("MARGIN WARNING: Required $", DoubleToString(marginRequired, 2));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size                                                |
//+------------------------------------------------------------------+
LotCalculation CalculateLotSize(double entryPrice, double stopLossPrice,
                                 int confluenceScore = 6, bool newsActive = false)
{
   LotCalculation calc;
   calc.isValid = false;
   calc.calculatedLots = 0;
   calc.adjustedLots = 0;
   calc.marginOK = false;

   double riskPercent = GetConfluenceAdjustedRisk(confluenceScore, newsActive);
   calc.riskPercent = riskPercent;

   if(!CheckCorrelationLimits(riskPercent))
   {
      calc.reason = "Correlation limit";
      return calc;
   }

   double slDistance = MathAbs(entryPrice - stopLossPrice);
   calc.stopLossPrice = stopLossPrice;
   calc.stopLossPips = slDistance / g_symbolInfo.pipSize;

   if(calc.stopLossPips <= 0)
   {
      calc.reason = "Invalid SL";
      return calc;
   }

   calc.riskAmount = g_riskMetrics.accountBalance * (riskPercent / 100.0);

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize <= 0)
   {
      calc.reason = "Invalid tick size";
      return calc;
   }

   calc.pipValue = tickValue * (g_symbolInfo.pipSize / tickSize);

   if(calc.pipValue <= 0)
   {
      calc.reason = "Invalid pip value";
      return calc;
   }

   calc.calculatedLots = calc.riskAmount / (calc.stopLossPips * calc.pipValue);
   calc.adjustedLots = NormalizeLots(calc.calculatedLots);

   calc.marginOK = CheckFreeMargin(calc.adjustedLots, entryPrice);
   if(!calc.marginOK)
   {
      calc.adjustedLots = NormalizeLots(calc.adjustedLots * 0.5);
      calc.marginOK = CheckFreeMargin(calc.adjustedLots, entryPrice);
   }

   calc.riskAmount = calc.adjustedLots * calc.stopLossPips * calc.pipValue;
   calc.riskPercent = (calc.riskAmount / g_riskMetrics.accountBalance) * 100;

   calc.isValid = calc.marginOK;
   calc.reason = calc.isValid ? "OK: " + DoubleToString(calc.adjustedLots, 2) + " lots" : "Margin issue";

   return calc;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size ATR                                            |
//+------------------------------------------------------------------+
LotCalculation CalculateLotSizeATR(double entryPrice, bool isBuy,
                                    int confluenceScore = 6, bool newsActive = false)
{
   LotCalculation calc;
   calc.isValid = false;

   double atr = 0;
   double slPrice = 0;

   if(InpUseATRForSL)
   {
      int atrHandle = iATR(_Symbol, PERIOD_H1, 14);
      if(atrHandle != INVALID_HANDLE)
      {
         double buffer[];
         ArraySetAsSeries(buffer, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, buffer) >= 1)
            atr = buffer[0];
         IndicatorRelease(atrHandle);
      }

      if(atr <= 0)
      {
         calc.reason = "ATR failed";
         return calc;
      }

      calc.atrMultiplier = GetATRMultiplier();
      double slDistance = atr * calc.atrMultiplier;

      slPrice = isBuy ? entryPrice - slDistance : entryPrice + slDistance;
   }
   else
   {
      double slDistance = InpFixedSLPips * g_symbolInfo.pipSize;
      slPrice = isBuy ? entryPrice - slDistance : entryPrice + slDistance;
      calc.atrMultiplier = 0;
   }

   return CalculateLotSize(entryPrice, slPrice, confluenceScore, newsActive);
}

//+------------------------------------------------------------------+
//| Normalize Lots                                                    |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(minLot < InpMinLots) minLot = InpMinLots;
   if(maxLot > InpMaxLots) maxLot = InpMaxLots;

   lots = MathFloor(lots / lotStep) * lotStep;

   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Calculate Scaled Position                                         |
//+------------------------------------------------------------------+
ScaledPosition CalculateScaledPosition(double totalLots)
{
   ScaledPosition pos;

   if(!InpUseScaling)
   {
      pos.stage1Lots = totalLots;
      pos.stage2Lots = 0;
      pos.stage3Lots = 0;
      pos.totalLots = totalLots;
      pos.currentStage = 1;
      return pos;
   }

   pos.stage1Lots = NormalizeLots(totalLots * InpStage1Percent / 100);
   pos.stage2Lots = NormalizeLots(totalLots * InpStage2Percent / 100);
   pos.stage3Lots = NormalizeLots(totalLots * InpStage3Percent / 100);

   double sum = pos.stage1Lots + pos.stage2Lots + pos.stage3Lots;
   if(sum < totalLots)
      pos.stage2Lots = NormalizeLots(pos.stage2Lots + (totalLots - sum));

   pos.totalLots = pos.stage1Lots + pos.stage2Lots + pos.stage3Lots;
   pos.currentStage = 0;
   pos.avgEntryPrice = 0;

   return pos;
}

//+------------------------------------------------------------------+
//| Get Pip Value For Lot                                             |
//+------------------------------------------------------------------+
double GetPipValueForLot(double lots)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize <= 0) return 0;

   return tickValue * (g_symbolInfo.pipSize / tickSize) * lots;
}

//+------------------------------------------------------------------+
//| Is Trading Allowed                                                |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   UpdateRiskMetrics();

   if(g_riskMetrics.inRecoveryMode && InpUseSMCRecovery)
   {
      bool recoveryOK = true;
      if(InpWaitForOTE && !g_riskMetrics.waitingForOTE) recoveryOK = false;
      if(InpWaitForFVG && !g_riskMetrics.waitingForFVG) recoveryOK = false;
      if(g_riskMetrics.barsSinceLoss < InpRecoveryBarsWait) recoveryOK = false;

      if(!recoveryOK) return false;
   }

   return g_riskMetrics.tradingAllowed;
}

//+------------------------------------------------------------------+
//| Register Trade Result                                             |
//+------------------------------------------------------------------+
void RegisterTradeResult(bool isWin, double profitLoss, double riskRewardRatio = 1.0)
{
   g_riskMetrics.dailyTrades++;
   g_riskMetrics.weeklyTrades++;
   g_riskMetrics.edge.totalTrades++;

   if(isWin)
   {
      g_riskMetrics.dailyWins++;
      g_riskMetrics.edge.winningTrades++;
      g_riskMetrics.edge.totalRRWins += riskRewardRatio;

      if(g_riskMetrics.edge.currentStreak > 0)
         g_riskMetrics.edge.currentStreak++;
      else
         g_riskMetrics.edge.currentStreak = 1;

      if(g_riskMetrics.edge.currentStreak > g_riskMetrics.edge.maxWinStreak)
         g_riskMetrics.edge.maxWinStreak = g_riskMetrics.edge.currentStreak;

      g_riskMetrics.inRecoveryMode = false;
   }
   else
   {
      g_riskMetrics.dailyLosses++;
      g_riskMetrics.edge.losingTrades++;
      g_riskMetrics.edge.totalRRLosses += 1.0;

      if(g_riskMetrics.edge.currentStreak < 0)
         g_riskMetrics.edge.currentStreak--;
      else
         g_riskMetrics.edge.currentStreak = -1;

      if(MathAbs(g_riskMetrics.edge.currentStreak) > g_riskMetrics.edge.maxLossStreak)
         g_riskMetrics.edge.maxLossStreak = MathAbs(g_riskMetrics.edge.currentStreak);

      if(InpUseSMCRecovery)
      {
         g_riskMetrics.inRecoveryMode = true;
         g_riskMetrics.barsSinceLoss = 0;
         g_riskMetrics.lastLossTime = TimeCurrent();
         Print("SMC RECOVERY: Entered after loss");
      }
   }

   UpdateRiskMetrics();
}

//+------------------------------------------------------------------+
//| Set Confluence Score                                              |
//+------------------------------------------------------------------+
void SetConfluenceScore(int score, ENUM_SIGNAL_STRENGTH strength)
{
   g_riskMetrics.lastConfluenceScore = score;
   g_riskMetrics.lastSignalStrength = strength;
}

//+------------------------------------------------------------------+
//| Set News Status                                                   |
//+------------------------------------------------------------------+
void SetNewsStatus(bool newsActive)
{
   g_riskMetrics.newsImpactActive = newsActive;
}

//+------------------------------------------------------------------+
//| Risk Status To String                                             |
//+------------------------------------------------------------------+
string RiskStatusToString(ENUM_RISK_STATUS status)
{
   switch(status)
   {
      case RISK_OK:       return "OK";
      case RISK_WARNING:  return "WARNING";
      case RISK_BLOCKED:  return "BLOCKED";
      case RISK_RECOVERY: return "RECOVERY";
      default:            return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Print Init Report                                                 |
//+------------------------------------------------------------------+
void PrintInitReport()
{
   Print("");
   Print("=================================================");
   Print("     SWING TRADER PRO - SECTION 12 (v1.01)       ");
   Print("     SMC RISK MANAGEMENT                         ");
   Print("=================================================");
   Print("Symbol: ", _Symbol, " (", g_profile.instrumentType, ")");
   Print("ATR Multiplier: ", DoubleToString(GetATRMultiplier(), 1));
   Print("-------------------------------------------------");
   Print("SMC RISK SETTINGS:");
   Print("  Base: ", DoubleToString(InpBaseRiskPercent, 1), "%");
   Print("  Strong (8+): ", DoubleToString(InpStrongSignalRisk, 1), "%");
   Print("  Moderate (6-7): ", DoubleToString(InpModerateSignalRisk, 1), "%");
   Print("  Weak (4-5): ", DoubleToString(InpWeakSignalRisk, 1), "%");
   Print("  News Reduction: ", InpReduceOnNews ? "50%" : "Off");
   Print("-------------------------------------------------");
   Print("LIMITS:");
   Print("  Daily: ", DoubleToString(InpMaxDailyLoss, 1), "%");
   Print("  Weekly: ", DoubleToString(InpMaxWeeklyLoss, 1), "%");
   Print("  Max DD: ", DoubleToString(InpMaxDrawdown, 1), "%");
   Print("-------------------------------------------------");
   Print("SMC RECOVERY: ", InpUseSMCRecovery ? "Enabled" : "Disabled");
   Print("Starting Balance: $", DoubleToString(g_startingBalance, 2));
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Create Panel                                                      |
//+------------------------------------------------------------------+
void CreatePanel()
{
   int x = InpPanelX;
   int y = InpPanelY;

   CreateRectangle(g_panelName + "_bg", x, y, 290, 420, clrBlack, 200);
   CreateLabel(g_panelName + "_title", x + 10, y + 5, "SMC RISK v1.01", clrGold, 10, "Arial Bold");

   int yOff = 30;

   CreateLabel(g_panelName + "_bal_l", x + 10, y + yOff, "Balance:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_bal_v", x + 100, y + yOff, "--", clrCyan, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_eq_l", x + 10, y + yOff, "Equity:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_eq_v", x + 100, y + yOff, "--", clrCyan, 8, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_dd_l", x + 10, y + yOff, "Drawdown:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_dd_v", x + 100, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_ddmax_l", x + 10, y + yOff, "Max DD:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_ddmax_v", x + 100, y + yOff, "--", clrOrange, 8, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_daily_l", x + 10, y + yOff, "Daily P&L:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_daily_v", x + 100, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_trades_l", x + 10, y + yOff, "Trades:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_trades_v", x + 100, y + yOff, "--", clrGray, 8, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_wr_l", x + 10, y + yOff, "Winrate:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_wr_v", x + 100, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_exp_l", x + 10, y + yOff, "Expectancy:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_exp_v", x + 100, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_edge_l", x + 10, y + yOff, "Edge:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_edge_v", x + 100, y + yOff, "--", clrGray, 8, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_usd_l", x + 10, y + yOff, "USD:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_usd_v", x + 50, y + yOff, "--", clrCyan, 8, "Arial");
   CreateLabel(g_panelName + "_eur_l", x + 100, y + yOff, "EUR:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_eur_v", x + 140, y + yOff, "--", clrCyan, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_gbp_l", x + 10, y + yOff, "GBP:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_gbp_v", x + 50, y + yOff, "--", clrCyan, 8, "Arial");
   CreateLabel(g_panelName + "_gold_l", x + 100, y + yOff, "Gold:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_gold_v", x + 140, y + yOff, "--", clrCyan, 8, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_status_l", x + 10, y + yOff, "STATUS:", clrWhite, 9, "Arial Bold");
   CreateLabel(g_panelName + "_status_v", x + 100, y + yOff, "--", clrLimeGreen, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_trading_l", x + 10, y + yOff, "Trading:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_trading_v", x + 100, y + yOff, "--", clrLimeGreen, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_conf_l", x + 10, y + yOff, "Confluence:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_conf_v", x + 100, y + yOff, "--", clrYellow, 8, "Arial");
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel) return;

   ObjectSetString(0, g_panelName + "_bal_v", OBJPROP_TEXT, "$" + DoubleToString(g_riskMetrics.accountBalance, 2));
   ObjectSetString(0, g_panelName + "_eq_v", OBJPROP_TEXT, "$" + DoubleToString(g_riskMetrics.accountEquity, 2));

   string ddStr = DoubleToString(g_riskMetrics.currentDrawdownPercent, 1) + "%";
   color ddColor = (g_riskMetrics.currentDrawdownPercent < InpMaxDrawdown * 0.5) ? clrLimeGreen :
                   (g_riskMetrics.currentDrawdownPercent < InpMaxDrawdown * 0.8) ? clrYellow : clrRed;
   ObjectSetString(0, g_panelName + "_dd_v", OBJPROP_TEXT, ddStr);
   ObjectSetInteger(0, g_panelName + "_dd_v", OBJPROP_COLOR, ddColor);

   ObjectSetString(0, g_panelName + "_ddmax_v", OBJPROP_TEXT, DoubleToString(g_riskMetrics.maxDrawdownHit, 1) + "%");

   string dailyStr = "$" + DoubleToString(g_riskMetrics.dailyPnL, 2);
   color dailyColor = (g_riskMetrics.dailyPnL >= 0) ? clrLimeGreen : clrRed;
   ObjectSetString(0, g_panelName + "_daily_v", OBJPROP_TEXT, dailyStr);
   ObjectSetInteger(0, g_panelName + "_daily_v", OBJPROP_COLOR, dailyColor);

   string tradesStr = IntegerToString(g_riskMetrics.dailyTrades) + " (W:" +
                      IntegerToString(g_riskMetrics.dailyWins) + " L:" +
                      IntegerToString(g_riskMetrics.dailyLosses) + ")";
   ObjectSetString(0, g_panelName + "_trades_v", OBJPROP_TEXT, tradesStr);

   ObjectSetString(0, g_panelName + "_wr_v", OBJPROP_TEXT, DoubleToString(g_riskMetrics.edge.winrate, 1) + "%");
   ObjectSetString(0, g_panelName + "_exp_v", OBJPROP_TEXT, DoubleToString(g_riskMetrics.edge.expectancy, 2) + "R");
   ObjectSetString(0, g_panelName + "_edge_v", OBJPROP_TEXT, g_riskMetrics.edge.edgeStatus);
   ObjectSetInteger(0, g_panelName + "_edge_v", OBJPROP_COLOR, g_riskMetrics.edge.hasEdge ? clrLimeGreen : clrOrange);

   ObjectSetString(0, g_panelName + "_usd_v", OBJPROP_TEXT, DoubleToString(g_riskMetrics.usdExposure, 1) + "%");
   ObjectSetString(0, g_panelName + "_eur_v", OBJPROP_TEXT, DoubleToString(g_riskMetrics.eurExposure, 1) + "%");
   ObjectSetString(0, g_panelName + "_gbp_v", OBJPROP_TEXT, DoubleToString(g_riskMetrics.gbpExposure, 1) + "%");
   ObjectSetString(0, g_panelName + "_gold_v", OBJPROP_TEXT, DoubleToString(g_riskMetrics.goldExposure, 1) + "%");

   string statusStr = RiskStatusToString(g_riskMetrics.status);
   color statusColor = (g_riskMetrics.status == RISK_OK) ? clrLimeGreen :
                       (g_riskMetrics.status == RISK_WARNING) ? clrYellow :
                       (g_riskMetrics.status == RISK_RECOVERY) ? clrOrange : clrRed;
   ObjectSetString(0, g_panelName + "_status_v", OBJPROP_TEXT, statusStr);
   ObjectSetInteger(0, g_panelName + "_status_v", OBJPROP_COLOR, statusColor);

   string tradingStr = g_riskMetrics.tradingAllowed ? "ALLOWED" : "BLOCKED";
   color tradingColor = g_riskMetrics.tradingAllowed ? clrLimeGreen : clrRed;
   ObjectSetString(0, g_panelName + "_trading_v", OBJPROP_TEXT, tradingStr);
   ObjectSetInteger(0, g_panelName + "_trading_v", OBJPROP_COLOR, tradingColor);

   ObjectSetString(0, g_panelName + "_conf_v", OBJPROP_TEXT, IntegerToString(g_riskMetrics.lastConfluenceScore) + "/10");

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
//| Public API Functions                                              |
//+------------------------------------------------------------------+
double GetLotSize(double entryPrice, double stopLossPrice, int confluenceScore = 6, bool newsActive = false)
{
   LotCalculation calc = CalculateLotSize(entryPrice, stopLossPrice, confluenceScore, newsActive);
   g_lastCalc = calc;
   return calc.adjustedLots;
}

double GetLotSizeATR(double entryPrice, bool isBuy, int confluenceScore = 6, bool newsActive = false)
{
   LotCalculation calc = CalculateLotSizeATR(entryPrice, isBuy, confluenceScore, newsActive);
   g_lastCalc = calc;
   return calc.adjustedLots;
}

void GetScaledLots(double totalLots, double &stage1, double &stage2, double &stage3)
{
   ScaledPosition pos = CalculateScaledPosition(totalLots);
   g_scaledPos = pos;
   stage1 = pos.stage1Lots;
   stage2 = pos.stage2Lots;
   stage3 = pos.stage3Lots;
}

bool CanTrade() { return IsTradingAllowed(); }
double GetCurrentDrawdown() { return g_riskMetrics.currentDrawdownPercent; }
double GetDailyPnL() { return g_riskMetrics.dailyPnLPercent; }
double GetWeeklyPnL() { return g_riskMetrics.weeklyPnLPercent; }
int GetOpenPositions() { return g_riskMetrics.openPositions; }
double GetTotalExposure() { return g_riskMetrics.totalExposure; }
double GetWinrate() { return g_riskMetrics.edge.winrate; }
double GetExpectancy() { return g_riskMetrics.edge.expectancy; }
bool HasEdge() { return g_riskMetrics.edge.hasEdge; }
bool IsInRecoveryMode() { return g_riskMetrics.inRecoveryMode; }
ENUM_RISK_STATUS GetRiskStatus() { return g_riskMetrics.status; }

void OnTradeResult(bool isWin, double pnl, double rr = 1.0) { RegisterTradeResult(isWin, pnl, rr); }
LotCalculation GetLastCalculation() { return g_lastCalc; }
RiskMetrics GetRiskMetrics() { return g_riskMetrics; }
//+------------------------------------------------------------------+
