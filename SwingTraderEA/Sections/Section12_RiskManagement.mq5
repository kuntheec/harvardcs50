//+------------------------------------------------------------------+
//|                                     Section12_RiskManagement.mq5 |
//|                                      SwingTrader Pro EA          |
//|                    Section 12: Risk Management                   |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.00"
#property description "Section 12: Risk Management v1.00"
#property description "Position sizing, lot calculation, drawdown protection"
#property description "Integrates with InstrumentProfile for adaptive risk"

//+------------------------------------------------------------------+
//| Modification History                                              |
//+------------------------------------------------------------------+
// 2025.12.29 v1.00 - Initial release:
//                    - Position sizing based on account risk %
//                    - ATR-based lot calculation
//                    - Maximum drawdown protection
//                    - Daily/Weekly loss limits
//                    - Instrument-aware risk parameters
//                    - Risk metrics panel

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Account Risk Settings ==="
input double   InpRiskPercent         = 1.0;         // Risk Per Trade (% of Balance)
input double   InpMaxRiskPercent      = 2.0;         // Maximum Risk Per Trade (%)
input double   InpMaxDailyLoss        = 5.0;         // Max Daily Loss (% of Balance)
input double   InpMaxWeeklyLoss       = 10.0;        // Max Weekly Loss (% of Balance)
input double   InpMaxDrawdown         = 20.0;        // Max Drawdown (% of Starting Balance)

input group "=== Position Sizing Settings ==="
input double   InpMinLots             = 0.01;        // Minimum Lot Size
input double   InpMaxLots             = 10.0;        // Maximum Lot Size
input double   InpLotStep             = 0.01;        // Lot Size Step
input bool     InpUseATRForSL         = true;        // Use ATR for Stop Loss Calculation
input double   InpATRMultiplier       = 1.5;         // ATR Multiplier for SL
input double   InpFixedSLPips         = 50.0;        // Fixed SL (pips) if not using ATR

input group "=== Scaling Settings ==="
input bool     InpUseScaling          = true;        // Enable Position Scaling
input double   InpStage1Percent       = 30.0;        // Stage 1 Entry (% of position)
input double   InpStage2Percent       = 40.0;        // Stage 2 Entry (% of position)
input double   InpStage3Percent       = 30.0;        // Stage 3 Entry (% of position)

input group "=== Martingale/Recovery (Use with Caution) ==="
input bool     InpUseMartingale       = false;       // Enable Martingale (DANGEROUS)
input double   InpMartingaleMultiplier = 1.5;        // Martingale Multiplier
input int      InpMaxMartingaleSteps  = 3;           // Max Martingale Steps

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
   RISK_BLOCKED             // Trading blocked
};

enum ENUM_SIZING_METHOD
{
   SIZE_FIXED_LOT,          // Fixed lot size
   SIZE_FIXED_RISK,         // Fixed risk percentage
   SIZE_ATR_BASED           // ATR-based sizing
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct RiskMetrics
{
   // Account Info
   double            accountBalance;
   double            accountEquity;
   double            accountFreeMargin;
   double            startingBalance;

   // Current Drawdown
   double            currentDrawdown;        // $ amount
   double            currentDrawdownPercent; // % of starting balance
   double            maxDrawdownHit;         // Max DD reached

   // Daily Tracking
   double            dailyStartBalance;
   double            dailyPnL;
   double            dailyPnLPercent;
   int               dailyTrades;
   int               dailyWins;
   int               dailyLosses;

   // Weekly Tracking
   double            weeklyStartBalance;
   double            weeklyPnL;
   double            weeklyPnLPercent;
   int               weeklyTrades;

   // Risk Status
   ENUM_RISK_STATUS  status;
   bool              tradingAllowed;
   string            blockReason;

   // Position Info
   int               openPositions;
   double            totalExposure;          // Total lots open
   double            totalRiskAmount;        // $ at risk

   // Timestamps
   datetime          lastUpdate;
   datetime          dayStartTime;
   datetime          weekStartTime;
};

struct LotCalculation
{
   double            calculatedLots;         // Calculated lot size
   double            adjustedLots;           // After min/max adjustment
   double            riskAmount;             // $ risk for this trade
   double            riskPercent;            // % risk for this trade
   double            stopLossPips;           // SL distance in pips
   double            stopLossPrice;          // SL price level
   double            pipValue;               // Value per pip
   bool              isValid;                // Calculation valid?
   string            reason;                 // Explanation
};

struct ScaledPosition
{
   double            stage1Lots;             // Stage 1 lots (30%)
   double            stage2Lots;             // Stage 2 lots (40%)
   double            stage3Lots;             // Stage 3 lots (30%)
   double            totalLots;              // Total position size
   double            avgEntryPrice;          // Average entry
   int               currentStage;           // Current stage (1-3)
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
// Symbol info
SymbolInfoCache   g_symbolInfo;
InstrumentProfile g_profile;
int               g_digits;
double            g_point;

// Risk tracking
RiskMetrics       g_riskMetrics;
LotCalculation    g_lastCalc;
ScaledPosition    g_scaledPos;

// Account info
double            g_startingBalance;
double            g_dailyStartBalance;
double            g_weeklyStartBalance;
datetime          g_lastDayCheck;
datetime          g_lastWeekCheck;

// Martingale tracking
int               g_martingaleStep = 0;
double            g_lastLotSize = 0;

// Panel
string            g_panelName = "RiskPanel";

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize symbol info
   InitSymbolInfo(g_symbolInfo, _Symbol);
   g_digits = g_symbolInfo.digits;
   g_point = g_symbolInfo.point;

   // Get instrument profile
   g_profile = GetInstrumentProfile(g_symbolInfo);

   // Initialize account tracking
   g_startingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_dailyStartBalance = g_startingBalance;
   g_weeklyStartBalance = g_startingBalance;
   g_lastDayCheck = TimeCurrent();
   g_lastWeekCheck = TimeCurrent();

   // Initialize risk metrics
   InitRiskMetrics();

   // Print initialization
   PrintInitReport();

   // Create panel
   if(InpShowPanel)
      CreatePanel();

   // Initial update
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
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_M15, 0);

   // Update on new bar
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;

      // Check for new day/week
      CheckDayWeekReset();

      // Update risk metrics
      UpdateRiskMetrics();

      // Update panel
      if(InpShowPanel)
         UpdatePanel();

      // Print report if enabled
      if(InpPrintReport)
         PrintRiskReport();
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

   g_riskMetrics.lastUpdate = TimeCurrent();
   g_riskMetrics.dayStartTime = TimeCurrent();
   g_riskMetrics.weekStartTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Update Risk Metrics                                               |
//+------------------------------------------------------------------+
void UpdateRiskMetrics()
{
   // Update account info
   g_riskMetrics.accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_riskMetrics.accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_riskMetrics.accountFreeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);

   // Calculate current drawdown from starting balance
   g_riskMetrics.currentDrawdown = g_startingBalance - g_riskMetrics.accountEquity;
   if(g_startingBalance > 0)
      g_riskMetrics.currentDrawdownPercent = (g_riskMetrics.currentDrawdown / g_startingBalance) * 100;

   // Track max drawdown
   if(g_riskMetrics.currentDrawdownPercent > g_riskMetrics.maxDrawdownHit)
      g_riskMetrics.maxDrawdownHit = g_riskMetrics.currentDrawdownPercent;

   // Calculate daily P&L
   g_riskMetrics.dailyPnL = g_riskMetrics.accountBalance - g_dailyStartBalance;
   if(g_dailyStartBalance > 0)
      g_riskMetrics.dailyPnLPercent = (g_riskMetrics.dailyPnL / g_dailyStartBalance) * 100;

   // Calculate weekly P&L
   g_riskMetrics.weeklyPnL = g_riskMetrics.accountBalance - g_weeklyStartBalance;
   if(g_weeklyStartBalance > 0)
      g_riskMetrics.weeklyPnLPercent = (g_riskMetrics.weeklyPnL / g_weeklyStartBalance) * 100;

   // Count open positions and exposure
   CountOpenPositions();

   // Check risk limits
   CheckRiskLimits();

   g_riskMetrics.lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Count Open Positions and Total Exposure                           |
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

            // Calculate risk for this position
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
//| Check Risk Limits                                                 |
//+------------------------------------------------------------------+
void CheckRiskLimits()
{
   g_riskMetrics.status = RISK_OK;
   g_riskMetrics.tradingAllowed = true;
   g_riskMetrics.blockReason = "";

   // Check max drawdown
   if(g_riskMetrics.currentDrawdownPercent >= InpMaxDrawdown)
   {
      g_riskMetrics.status = RISK_BLOCKED;
      g_riskMetrics.tradingAllowed = false;
      g_riskMetrics.blockReason = "Max drawdown reached: " +
                                   DoubleToString(g_riskMetrics.currentDrawdownPercent, 1) + "%";

      if(InpAlertOnRiskLimit)
         Alert("RISK LIMIT: ", g_riskMetrics.blockReason);

      return;
   }

   // Check daily loss limit
   if(g_riskMetrics.dailyPnLPercent <= -InpMaxDailyLoss)
   {
      g_riskMetrics.status = RISK_BLOCKED;
      g_riskMetrics.tradingAllowed = false;
      g_riskMetrics.blockReason = "Daily loss limit reached: " +
                                   DoubleToString(MathAbs(g_riskMetrics.dailyPnLPercent), 1) + "%";

      if(InpAlertOnRiskLimit)
         Alert("RISK LIMIT: ", g_riskMetrics.blockReason);

      return;
   }

   // Check weekly loss limit
   if(g_riskMetrics.weeklyPnLPercent <= -InpMaxWeeklyLoss)
   {
      g_riskMetrics.status = RISK_BLOCKED;
      g_riskMetrics.tradingAllowed = false;
      g_riskMetrics.blockReason = "Weekly loss limit reached: " +
                                   DoubleToString(MathAbs(g_riskMetrics.weeklyPnLPercent), 1) + "%";

      if(InpAlertOnRiskLimit)
         Alert("RISK LIMIT: ", g_riskMetrics.blockReason);

      return;
   }

   // Check for warning levels (80% of limits)
   if(g_riskMetrics.currentDrawdownPercent >= InpMaxDrawdown * 0.8 ||
      g_riskMetrics.dailyPnLPercent <= -InpMaxDailyLoss * 0.8 ||
      g_riskMetrics.weeklyPnLPercent <= -InpMaxWeeklyLoss * 0.8)
   {
      g_riskMetrics.status = RISK_WARNING;
      g_riskMetrics.blockReason = "Approaching risk limits";
   }
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

   // Check for new day
   if(dt.day != lastDt.day || dt.mon != lastDt.mon || dt.year != lastDt.year)
   {
      // New day - reset daily tracking
      g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_riskMetrics.dailyStartBalance = g_dailyStartBalance;
      g_riskMetrics.dailyPnL = 0;
      g_riskMetrics.dailyPnLPercent = 0;
      g_riskMetrics.dailyTrades = 0;
      g_riskMetrics.dailyWins = 0;
      g_riskMetrics.dailyLosses = 0;
      g_riskMetrics.dayStartTime = currentTime;
      g_lastDayCheck = currentTime;

      Print("NEW DAY - Daily tracking reset. Starting balance: ",
            DoubleToString(g_dailyStartBalance, 2));
   }

   // Check for new week (Monday)
   if(dt.day_of_week == 1 && lastWeekDt.day_of_week != 1)
   {
      // New week - reset weekly tracking
      g_weeklyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_riskMetrics.weeklyStartBalance = g_weeklyStartBalance;
      g_riskMetrics.weeklyPnL = 0;
      g_riskMetrics.weeklyPnLPercent = 0;
      g_riskMetrics.weeklyTrades = 0;
      g_riskMetrics.weekStartTime = currentTime;
      g_lastWeekCheck = currentTime;

      // Reset martingale on new week
      g_martingaleStep = 0;

      Print("NEW WEEK - Weekly tracking reset. Starting balance: ",
            DoubleToString(g_weeklyStartBalance, 2));
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size Based on Risk                                  |
//+------------------------------------------------------------------+
LotCalculation CalculateLotSize(double entryPrice, double stopLossPrice, double riskPercent = 0)
{
   LotCalculation calc;
   calc.isValid = false;
   calc.calculatedLots = 0;
   calc.adjustedLots = 0;

   // Use input risk percent if not specified
   if(riskPercent <= 0)
      riskPercent = InpRiskPercent;

   // Cap at max risk
   if(riskPercent > InpMaxRiskPercent)
      riskPercent = InpMaxRiskPercent;

   calc.riskPercent = riskPercent;

   // Calculate stop loss distance
   double slDistance = MathAbs(entryPrice - stopLossPrice);
   calc.stopLossPrice = stopLossPrice;
   calc.stopLossPips = slDistance / g_symbolInfo.pipSize;

   if(calc.stopLossPips <= 0)
   {
      calc.reason = "Invalid SL distance";
      return calc;
   }

   // Calculate risk amount in account currency
   calc.riskAmount = g_riskMetrics.accountBalance * (riskPercent / 100.0);

   // Get pip value for 1 lot
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

   // Calculate lot size: Risk Amount / (SL Pips * Pip Value)
   calc.calculatedLots = calc.riskAmount / (calc.stopLossPips * calc.pipValue);

   // Apply martingale if enabled
   if(InpUseMartingale && g_martingaleStep > 0)
   {
      double multiplier = MathPow(InpMartingaleMultiplier, g_martingaleStep);
      calc.calculatedLots *= multiplier;
      calc.reason = "Martingale step " + IntegerToString(g_martingaleStep);
   }

   // Adjust to broker limits
   calc.adjustedLots = NormalizeLots(calc.calculatedLots);

   // Recalculate actual risk with adjusted lots
   calc.riskAmount = calc.adjustedLots * calc.stopLossPips * calc.pipValue;
   calc.riskPercent = (calc.riskAmount / g_riskMetrics.accountBalance) * 100;

   calc.isValid = true;
   calc.reason = "Calculated: " + DoubleToString(calc.adjustedLots, 2) + " lots";

   return calc;
}

//+------------------------------------------------------------------+
//| Calculate Lot Size Using ATR for SL                               |
//+------------------------------------------------------------------+
LotCalculation CalculateLotSizeATR(double entryPrice, bool isBuy, double riskPercent = 0)
{
   LotCalculation calc;
   calc.isValid = false;

   double atr = 0;
   double slPrice = 0;

   if(InpUseATRForSL)
   {
      // Get ATR value
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
         calc.reason = "Failed to get ATR";
         return calc;
      }

      // Calculate SL price using ATR
      double slDistance = atr * InpATRMultiplier;

      if(isBuy)
         slPrice = entryPrice - slDistance;
      else
         slPrice = entryPrice + slDistance;
   }
   else
   {
      // Use fixed SL pips
      double slDistance = InpFixedSLPips * g_symbolInfo.pipSize;

      if(isBuy)
         slPrice = entryPrice - slDistance;
      else
         slPrice = entryPrice + slDistance;
   }

   // Calculate lot size
   return CalculateLotSize(entryPrice, slPrice, riskPercent);
}

//+------------------------------------------------------------------+
//| Normalize Lot Size to Broker Requirements                         |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // Apply input limits
   if(minLot < InpMinLots) minLot = InpMinLots;
   if(maxLot > InpMaxLots) maxLot = InpMaxLots;

   // Round to lot step
   lots = MathFloor(lots / lotStep) * lotStep;

   // Apply limits
   if(lots < minLot) lots = minLot;
   if(lots > maxLot) lots = maxLot;

   return NormalizeDouble(lots, 2);
}

//+------------------------------------------------------------------+
//| Calculate Scaled Position Sizes                                   |
//+------------------------------------------------------------------+
ScaledPosition CalculateScaledPosition(double totalLots)
{
   ScaledPosition pos;

   if(!InpUseScaling)
   {
      // No scaling - all in one entry
      pos.stage1Lots = totalLots;
      pos.stage2Lots = 0;
      pos.stage3Lots = 0;
      pos.totalLots = totalLots;
      pos.currentStage = 1;
      return pos;
   }

   // Calculate scaled lots
   pos.stage1Lots = NormalizeLots(totalLots * InpStage1Percent / 100);
   pos.stage2Lots = NormalizeLots(totalLots * InpStage2Percent / 100);
   pos.stage3Lots = NormalizeLots(totalLots * InpStage3Percent / 100);

   // Adjust for rounding - add remainder to stage 2
   double sum = pos.stage1Lots + pos.stage2Lots + pos.stage3Lots;
   if(sum < totalLots)
   {
      double remainder = totalLots - sum;
      pos.stage2Lots = NormalizeLots(pos.stage2Lots + remainder);
   }

   pos.totalLots = pos.stage1Lots + pos.stage2Lots + pos.stage3Lots;
   pos.currentStage = 0;
   pos.avgEntryPrice = 0;

   return pos;
}

//+------------------------------------------------------------------+
//| Get Pip Value for Specific Lot Size                               |
//+------------------------------------------------------------------+
double GetPipValueForLot(double lots)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickSize <= 0) return 0;

   double pipValue = tickValue * (g_symbolInfo.pipSize / tickSize) * lots;
   return pipValue;
}

//+------------------------------------------------------------------+
//| Check if Trading is Allowed by Risk Rules                         |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   UpdateRiskMetrics();
   return g_riskMetrics.tradingAllowed;
}

//+------------------------------------------------------------------+
//| Get Current Risk Status                                           |
//+------------------------------------------------------------------+
ENUM_RISK_STATUS GetRiskStatus()
{
   return g_riskMetrics.status;
}

//+------------------------------------------------------------------+
//| Register Trade Result (for tracking)                              |
//+------------------------------------------------------------------+
void RegisterTradeResult(bool isWin, double profitLoss)
{
   g_riskMetrics.dailyTrades++;
   g_riskMetrics.weeklyTrades++;

   if(isWin)
   {
      g_riskMetrics.dailyWins++;
      g_martingaleStep = 0;  // Reset martingale on win
   }
   else
   {
      g_riskMetrics.dailyLosses++;

      // Increment martingale on loss
      if(InpUseMartingale && g_martingaleStep < InpMaxMartingaleSteps)
         g_martingaleStep++;
   }

   UpdateRiskMetrics();
}

//+------------------------------------------------------------------+
//| Risk Status to String                                             |
//+------------------------------------------------------------------+
string RiskStatusToString(ENUM_RISK_STATUS status)
{
   switch(status)
   {
      case RISK_OK:      return "OK";
      case RISK_WARNING: return "WARNING";
      case RISK_BLOCKED: return "BLOCKED";
      default:           return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Print Risk Report                                                 |
//+------------------------------------------------------------------+
void PrintRiskReport()
{
   static datetime lastReport = 0;

   // Only print every 5 minutes to reduce log spam
   if(TimeCurrent() - lastReport < 300) return;
   lastReport = TimeCurrent();

   Print("");
   Print("=================================================");
   Print("     RISK MANAGEMENT REPORT (Section 12 v1.00)   ");
   Print("=================================================");
   Print("Symbol: ", _Symbol, " (", g_profile.instrumentType, ")");
   Print("Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");

   Print("ACCOUNT STATUS:");
   Print("  Balance: $", DoubleToString(g_riskMetrics.accountBalance, 2));
   Print("  Equity: $", DoubleToString(g_riskMetrics.accountEquity, 2));
   Print("  Free Margin: $", DoubleToString(g_riskMetrics.accountFreeMargin, 2));
   Print("-------------------------------------------------");

   Print("DRAWDOWN:");
   Print("  Current: $", DoubleToString(g_riskMetrics.currentDrawdown, 2),
         " (", DoubleToString(g_riskMetrics.currentDrawdownPercent, 2), "%)");
   Print("  Max Hit: ", DoubleToString(g_riskMetrics.maxDrawdownHit, 2), "%");
   Print("  Limit: ", DoubleToString(InpMaxDrawdown, 1), "%");
   Print("-------------------------------------------------");

   Print("DAILY P&L:");
   Print("  Today: $", DoubleToString(g_riskMetrics.dailyPnL, 2),
         " (", DoubleToString(g_riskMetrics.dailyPnLPercent, 2), "%)");
   Print("  Trades: ", g_riskMetrics.dailyTrades,
         " (W:", g_riskMetrics.dailyWins, " L:", g_riskMetrics.dailyLosses, ")");
   Print("  Limit: -", DoubleToString(InpMaxDailyLoss, 1), "%");
   Print("-------------------------------------------------");

   Print("WEEKLY P&L:");
   Print("  This Week: $", DoubleToString(g_riskMetrics.weeklyPnL, 2),
         " (", DoubleToString(g_riskMetrics.weeklyPnLPercent, 2), "%)");
   Print("  Trades: ", g_riskMetrics.weeklyTrades);
   Print("  Limit: -", DoubleToString(InpMaxWeeklyLoss, 1), "%");
   Print("-------------------------------------------------");

   Print("EXPOSURE:");
   Print("  Open Positions: ", g_riskMetrics.openPositions);
   Print("  Total Lots: ", DoubleToString(g_riskMetrics.totalExposure, 2));
   Print("  Risk at Stake: $", DoubleToString(g_riskMetrics.totalRiskAmount, 2));
   Print("-------------------------------------------------");

   Print("STATUS: ", RiskStatusToString(g_riskMetrics.status));
   Print("Trading Allowed: ", g_riskMetrics.tradingAllowed ? "YES" : "NO");
   if(g_riskMetrics.blockReason != "")
      Print("Reason: ", g_riskMetrics.blockReason);

   if(InpUseMartingale)
      Print("Martingale Step: ", g_martingaleStep, "/", InpMaxMartingaleSteps);

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
   Print("     SWING TRADER PRO - SECTION 12 (v1.00)       ");
   Print("     RISK MANAGEMENT                             ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol);
   Print("Instrument Type: ", g_profile.instrumentType);
   Print("-------------------------------------------------");
   Print("RISK SETTINGS:");
   Print("  Risk Per Trade: ", DoubleToString(InpRiskPercent, 1), "%");
   Print("  Max Risk Per Trade: ", DoubleToString(InpMaxRiskPercent, 1), "%");
   Print("  Max Daily Loss: ", DoubleToString(InpMaxDailyLoss, 1), "%");
   Print("  Max Weekly Loss: ", DoubleToString(InpMaxWeeklyLoss, 1), "%");
   Print("  Max Drawdown: ", DoubleToString(InpMaxDrawdown, 1), "%");
   Print("-------------------------------------------------");
   Print("POSITION SIZING:");
   Print("  Min Lots: ", DoubleToString(InpMinLots, 2));
   Print("  Max Lots: ", DoubleToString(InpMaxLots, 2));
   Print("  Use ATR for SL: ", InpUseATRForSL ? "Yes" : "No");
   if(InpUseATRForSL)
      Print("  ATR Multiplier: ", DoubleToString(InpATRMultiplier, 1));
   else
      Print("  Fixed SL: ", DoubleToString(InpFixedSLPips, 1), " pips");
   Print("-------------------------------------------------");
   Print("SCALING:");
   Print("  Enabled: ", InpUseScaling ? "Yes" : "No");
   if(InpUseScaling)
   {
      Print("  Stage 1: ", DoubleToString(InpStage1Percent, 0), "%");
      Print("  Stage 2: ", DoubleToString(InpStage2Percent, 0), "%");
      Print("  Stage 3: ", DoubleToString(InpStage3Percent, 0), "%");
   }
   Print("-------------------------------------------------");
   Print("MARTINGALE:");
   Print("  Enabled: ", InpUseMartingale ? "YES (DANGER!)" : "No");
   if(InpUseMartingale)
   {
      Print("  Multiplier: ", DoubleToString(InpMartingaleMultiplier, 1));
      Print("  Max Steps: ", InpMaxMartingaleSteps);
   }
   Print("-------------------------------------------------");
   Print("STARTING BALANCE: $", DoubleToString(g_startingBalance, 2));
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
   int width = 280;
   int height = 380;

   CreateRectangle(g_panelName + "_bg", x, y, width, height, clrBlack, 200);

   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "RISK MANAGEMENT v1.00", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "--------------------------------", clrGray, 8, "Courier New");

   int yOff = 40;

   // Account section
   CreateLabel(g_panelName + "_acc_header", x + 10, y + yOff, "ACCOUNT:", clrWhite, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_bal_label", x + 10, y + yOff, "Balance:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_bal_value", x + 100, y + yOff, "--", clrCyan, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_eq_label", x + 10, y + yOff, "Equity:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_eq_value", x + 100, y + yOff, "--", clrCyan, 8, "Arial");
   yOff += 18;

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOff,
               "--------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Drawdown section
   CreateLabel(g_panelName + "_dd_header", x + 10, y + yOff, "DRAWDOWN:", clrWhite, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_dd_label", x + 10, y + yOff, "Current:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_dd_value", x + 100, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_ddmax_label", x + 10, y + yOff, "Max Hit:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_ddmax_value", x + 100, y + yOff, "--", clrOrange, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_ddlim_label", x + 10, y + yOff, "Limit:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_ddlim_value", x + 100, y + yOff, "--", clrGray, 8, "Arial");
   yOff += 18;

   CreateLabel(g_panelName + "_sep3", x + 10, y + yOff,
               "--------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Daily P&L
   CreateLabel(g_panelName + "_daily_header", x + 10, y + yOff, "DAILY:", clrWhite, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_daily_label", x + 10, y + yOff, "P&L:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_daily_value", x + 100, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_trades_label", x + 10, y + yOff, "Trades:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_trades_value", x + 100, y + yOff, "--", clrGray, 8, "Arial");
   yOff += 18;

   CreateLabel(g_panelName + "_sep4", x + 10, y + yOff,
               "--------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Exposure
   CreateLabel(g_panelName + "_exp_header", x + 10, y + yOff, "EXPOSURE:", clrWhite, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_pos_label", x + 10, y + yOff, "Positions:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_pos_value", x + 100, y + yOff, "--", clrCyan, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_lots_label", x + 10, y + yOff, "Total Lots:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_lots_value", x + 100, y + yOff, "--", clrCyan, 8, "Arial");
   yOff += 15;

   CreateLabel(g_panelName + "_risk_label", x + 10, y + yOff, "At Risk:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_risk_value", x + 100, y + yOff, "--", clrOrange, 8, "Arial");
   yOff += 18;

   CreateLabel(g_panelName + "_sep5", x + 10, y + yOff,
               "--------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Status
   CreateLabel(g_panelName + "_status_label", x + 10, y + yOff, "STATUS:", clrWhite, 9, "Arial Bold");
   CreateLabel(g_panelName + "_status_value", x + 100, y + yOff, "--", clrLimeGreen, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_trading_label", x + 10, y + yOff, "Trading:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_trading_value", x + 100, y + yOff, "--", clrLimeGreen, 8, "Arial");
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel) return;

   // Account
   ObjectSetString(0, g_panelName + "_bal_value", OBJPROP_TEXT,
                   "$" + DoubleToString(g_riskMetrics.accountBalance, 2));
   ObjectSetString(0, g_panelName + "_eq_value", OBJPROP_TEXT,
                   "$" + DoubleToString(g_riskMetrics.accountEquity, 2));

   // Drawdown
   string ddStr = DoubleToString(g_riskMetrics.currentDrawdownPercent, 1) + "%";
   color ddColor = (g_riskMetrics.currentDrawdownPercent < InpMaxDrawdown * 0.5) ? clrLimeGreen :
                   (g_riskMetrics.currentDrawdownPercent < InpMaxDrawdown * 0.8) ? clrYellow : clrRed;
   ObjectSetString(0, g_panelName + "_dd_value", OBJPROP_TEXT, ddStr);
   ObjectSetInteger(0, g_panelName + "_dd_value", OBJPROP_COLOR, ddColor);

   ObjectSetString(0, g_panelName + "_ddmax_value", OBJPROP_TEXT,
                   DoubleToString(g_riskMetrics.maxDrawdownHit, 1) + "%");
   ObjectSetString(0, g_panelName + "_ddlim_value", OBJPROP_TEXT,
                   DoubleToString(InpMaxDrawdown, 1) + "%");

   // Daily P&L
   string dailyStr = "$" + DoubleToString(g_riskMetrics.dailyPnL, 2) +
                     " (" + DoubleToString(g_riskMetrics.dailyPnLPercent, 1) + "%)";
   color dailyColor = (g_riskMetrics.dailyPnL >= 0) ? clrLimeGreen : clrRed;
   ObjectSetString(0, g_panelName + "_daily_value", OBJPROP_TEXT, dailyStr);
   ObjectSetInteger(0, g_panelName + "_daily_value", OBJPROP_COLOR, dailyColor);

   // Trades
   string tradesStr = IntegerToString(g_riskMetrics.dailyTrades) +
                      " (W:" + IntegerToString(g_riskMetrics.dailyWins) +
                      " L:" + IntegerToString(g_riskMetrics.dailyLosses) + ")";
   ObjectSetString(0, g_panelName + "_trades_value", OBJPROP_TEXT, tradesStr);

   // Exposure
   ObjectSetString(0, g_panelName + "_pos_value", OBJPROP_TEXT,
                   IntegerToString(g_riskMetrics.openPositions));
   ObjectSetString(0, g_panelName + "_lots_value", OBJPROP_TEXT,
                   DoubleToString(g_riskMetrics.totalExposure, 2));
   ObjectSetString(0, g_panelName + "_risk_value", OBJPROP_TEXT,
                   "$" + DoubleToString(g_riskMetrics.totalRiskAmount, 2));

   // Status
   string statusStr = RiskStatusToString(g_riskMetrics.status);
   color statusColor = (g_riskMetrics.status == RISK_OK) ? clrLimeGreen :
                       (g_riskMetrics.status == RISK_WARNING) ? clrYellow : clrRed;
   ObjectSetString(0, g_panelName + "_status_value", OBJPROP_TEXT, statusStr);
   ObjectSetInteger(0, g_panelName + "_status_value", OBJPROP_COLOR, statusColor);

   // Trading allowed
   string tradingStr = g_riskMetrics.tradingAllowed ? "ALLOWED" : "BLOCKED";
   color tradingColor = g_riskMetrics.tradingAllowed ? clrLimeGreen : clrRed;
   ObjectSetString(0, g_panelName + "_trading_value", OBJPROP_TEXT, tradingStr);
   ObjectSetInteger(0, g_panelName + "_trading_value", OBJPROP_COLOR, tradingColor);

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

// Get calculated lot size for a trade
double GetLotSize(double entryPrice, double stopLossPrice)
{
   LotCalculation calc = CalculateLotSize(entryPrice, stopLossPrice);
   g_lastCalc = calc;
   return calc.adjustedLots;
}

// Get lot size using ATR for SL
double GetLotSizeATR(double entryPrice, bool isBuy)
{
   LotCalculation calc = CalculateLotSizeATR(entryPrice, isBuy);
   g_lastCalc = calc;
   return calc.adjustedLots;
}

// Get scaled position sizes
void GetScaledLots(double totalLots, double &stage1, double &stage2, double &stage3)
{
   ScaledPosition pos = CalculateScaledPosition(totalLots);
   g_scaledPos = pos;
   stage1 = pos.stage1Lots;
   stage2 = pos.stage2Lots;
   stage3 = pos.stage3Lots;
}

// Check if trading allowed
bool CanTrade() { return IsTradingAllowed(); }

// Get risk metrics
double GetCurrentDrawdown() { return g_riskMetrics.currentDrawdownPercent; }
double GetDailyPnL() { return g_riskMetrics.dailyPnLPercent; }
double GetWeeklyPnL() { return g_riskMetrics.weeklyPnLPercent; }
int GetOpenPositions() { return g_riskMetrics.openPositions; }
double GetTotalExposure() { return g_riskMetrics.totalExposure; }

// Register trade for tracking
void OnTradeResult(bool isWin, double pnl) { RegisterTradeResult(isWin, pnl); }

// Get last calculation details
LotCalculation GetLastCalculation() { return g_lastCalc; }
RiskMetrics GetRiskMetrics() { return g_riskMetrics; }
//+------------------------------------------------------------------+
