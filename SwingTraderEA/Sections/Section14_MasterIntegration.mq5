//+------------------------------------------------------------------+
//|                                  Section14_MasterIntegration.mq5  |
//|                         SwingTrader Pro EA - Master Controller    |
//|                                 Version 1.01 - Full SMC System    |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.01"

//+------------------------------------------------------------------+
//| Include All Section Modules                                       |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <SwingTraderPro/SMCModules.mqh>  // All SMC analysis modules

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

// Note: ENUM_SESSION_TYPE is defined in SMCModules.mqh
// SESSION_ASIA, SESSION_LONDON, SESSION_NEWYORK, SESSION_OVERLAP, SESSION_OFFHOURS

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

input group "=== Backtest Date Range ==="
input bool     InpUseDateFilter       = false;             // Enable Date Range Filter
input datetime InpStartDate           = D'2024.01.01 00:00'; // Start Date (for backtest)
input datetime InpEndDate             = D'2024.12.31 23:59'; // End Date (for backtest)

input group "=== Debug Step Mode ==="
input bool     InpDebugStepMode       = false;             // Enable Step-by-Step Initialization
input bool     InpAutoAdvance         = false;             // Auto-advance after 3 seconds (no button click)
input int      InpAutoAdvanceDelay    = 3;                 // Auto-advance delay (seconds)

//+------------------------------------------------------------------+
//| Debug Step Mode - Initialization State                            |
//+------------------------------------------------------------------+
enum ENUM_INIT_STEP
{
   STEP_NOT_STARTED = 0,
   STEP_SECTION_1,      // ATR Filter
   STEP_SECTION_2,      // EMA Analysis
   STEP_SECTION_3,      // Market Structure
   STEP_SECTION_4,      // Supply/Demand
   STEP_SECTION_5,      // Liquidity
   STEP_SECTION_6,      // Sessions
   STEP_SECTION_7,      // FVG
   STEP_SECTION_8,      // Order Blocks
   STEP_SECTION_9,      // Fibonacci/OTE
   STEP_SECTION_10,     // Killzones
   STEP_SECTION_11,     // Confluence
   STEP_COMPLETE        // All sections initialized
};

// Cached section results for debug mode
struct SectionReport
{
   bool     analyzed;
   bool     confirmed;
   string   summary;
   datetime timestamp;
};

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
   ENUM_SESSION_TYPE currentSession;
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

// Master SMC Analyzer - Calls All Section Modules
CMasterSMC        g_masterSMC;

int               g_atrHandle;
double            g_atrBuffer[];

string            g_panelName = "SEC14_MasterPanel";
datetime          g_lastBarTime = 0;
int               g_todayDayOfYear = -1;

// Debug Step Mode Variables
ENUM_INIT_STEP    g_currentStep = STEP_NOT_STARTED;
SectionReport     g_sectionReports[12];    // Reports for sections 1-11 + summary
datetime          g_stepStartTime = 0;
bool              g_stepModeActive = false;
string            g_continueButtonName = "SEC14_ContinueBtn";
string            g_stepPanelName = "SEC14_StepPanel";

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

   // Initialize Master SMC Analyzer with all section modules
   g_masterSMC.Init(_Symbol, InpHTF, InpLTF);

   g_status.initialized = true;
   g_status.tradingEnabled = (InpEAMode != MODE_ANALYSIS_ONLY);

   // Load historical stats
   LoadTradeHistory();

   // Create dashboard
   if(InpShowMasterPanel)
      CreateMasterPanel();

   PrintInitialization();

   // Run initial analysis immediately (don't wait for new bar)
   CopyBuffer(g_atrHandle, 0, 0, 3, g_atrBuffer);
   RunSMCAnalysis(false);  // false = skip debug print during init (will print on first tick)
   Print("✓ Initial SMC Analysis Complete");

   // Check if Debug Step Mode is enabled
   if(InpDebugStepMode)
   {
      g_status.statusMessage = "Debug Step Mode";
      InitStepMode();
      return INIT_SUCCEEDED;
   }

   // Set initial status message based on trading mode
   if(InpEAMode == MODE_ANALYSIS_ONLY)
      g_status.statusMessage = "Analysis Mode";
   else if(!g_analysis.sessionActive)
      g_status.statusMessage = "Off Hours - Monitoring";
   else
      g_status.statusMessage = "Ready to Trade";

   // Update panel with initial values
   if(InpShowMasterPanel)
      UpdatePanel();

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

   // Cleanup step mode UI
   if(InpDebugStepMode)
   {
      DeleteStepModeUI();
   }

   Print("=================================================");
   Print("SwingTrader Pro EA Deinitialized");
   Print("Session Stats:");
   Print("  Total Trades: ", g_stats.totalTrades);
   Print("  Winrate: ", DoubleToString(g_stats.winrate, 1), "%");
   Print("  Net Profit: $", DoubleToString(g_stats.netProfit, 2));
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Check if current time is within backtest date range               |
//+------------------------------------------------------------------+
bool IsWithinDateRange()
{
   if(!InpUseDateFilter)
      return true;  // No filter, always allow

   datetime currentTime = TimeCurrent();
   return (currentTime >= InpStartDate && currentTime <= InpEndDate);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_status.initialized) return;

   // Skip normal processing while step mode is active
   if(g_stepModeActive)
   {
      // Just update the step mode UI
      UpdateStepModeUI();
      return;
   }

   // Check date range filter (for backtesting)
   if(InpUseDateFilter && !IsWithinDateRange())
   {
      datetime currentTime = TimeCurrent();

      // Update status to show we're outside the date range
      if(currentTime < InpStartDate)
         g_status.statusMessage = "Waiting for Start Date";
      else
         g_status.statusMessage = "Past End Date - Stopped";

      // Still update panel to show status
      if(InpShowMasterPanel)
         UpdatePanel();

      return;  // Skip all processing outside date range
   }

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
         else
         {
            // Update status when ready but no valid signal
            g_status.statusMessage = "Scanning for Signals";
         }
      }
      else if(InpEAMode == MODE_ANALYSIS_ONLY)
      {
         g_status.statusMessage = "Analysis Mode";
      }
      else if(!g_analysis.sessionActive)
      {
         g_status.statusMessage = "Off Hours - Monitoring";
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
//| Chart Event Handler - For Step Mode Button                        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Handle button click for step mode
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == g_continueButtonName && g_stepModeActive)
      {
         // User clicked Continue - advance to next step
         AdvanceToNextStep();

         // Reset button state
         ObjectSetInteger(0, g_continueButtonName, OBJPROP_STATE, false);
         ChartRedraw();
      }
   }
}

//+------------------------------------------------------------------+
//| Timer Event Handler - For Auto-Advance Mode                       |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!g_stepModeActive || !InpAutoAdvance)
      return;

   // Check if enough time has passed for auto-advance
   if(g_stepStartTime > 0 &&
      TimeCurrent() - g_stepStartTime >= InpAutoAdvanceDelay)
   {
      AdvanceToNextStep();
   }
}

//+------------------------------------------------------------------+
//| Initialize Step Mode                                              |
//+------------------------------------------------------------------+
void InitStepMode()
{
   g_stepModeActive = true;
   g_currentStep = STEP_NOT_STARTED;

   // Reset all section reports
   for(int i = 0; i < 12; i++)
   {
      g_sectionReports[i].analyzed = false;
      g_sectionReports[i].confirmed = false;
      g_sectionReports[i].summary = "";
      g_sectionReports[i].timestamp = 0;
   }

   // Create step mode UI
   CreateStepModeUI();

   // Start timer for auto-advance if enabled
   if(InpAutoAdvance)
      EventSetTimer(1);  // 1 second timer

   Print("═══════════════════════════════════════════════════════════");
   Print("       DEBUG STEP MODE ACTIVATED                           ");
   Print("       Click 'Continue' to advance through each section    ");
   Print("═══════════════════════════════════════════════════════════");

   // Start with first step
   AdvanceToNextStep();
}

//+------------------------------------------------------------------+
//| Advance to Next Initialization Step                               |
//+------------------------------------------------------------------+
void AdvanceToNextStep()
{
   // Mark current step as confirmed
   if(g_currentStep > STEP_NOT_STARTED && g_currentStep < STEP_COMPLETE)
   {
      g_sectionReports[g_currentStep - 1].confirmed = true;
      Print("✓ Section ", g_currentStep, " confirmed by user");
   }

   // Move to next step
   g_currentStep = (ENUM_INIT_STEP)(g_currentStep + 1);
   g_stepStartTime = TimeCurrent();

   // Execute the current step
   switch(g_currentStep)
   {
      case STEP_SECTION_1:
         AnalyzeSection1_ATR();
         break;
      case STEP_SECTION_2:
         AnalyzeSection2_EMA();
         break;
      case STEP_SECTION_3:
         AnalyzeSection3_Structure();
         break;
      case STEP_SECTION_4:
         AnalyzeSection4_SupplyDemand();
         break;
      case STEP_SECTION_5:
         AnalyzeSection5_Liquidity();
         break;
      case STEP_SECTION_6:
         AnalyzeSection6_Sessions();
         break;
      case STEP_SECTION_7:
         AnalyzeSection7_FVG();
         break;
      case STEP_SECTION_8:
         AnalyzeSection8_OrderBlocks();
         break;
      case STEP_SECTION_9:
         AnalyzeSection9_Fibonacci();
         break;
      case STEP_SECTION_10:
         AnalyzeSection10_Killzones();
         break;
      case STEP_SECTION_11:
         AnalyzeSection11_Confluence();
         break;
      case STEP_COMPLETE:
         CompleteStepMode();
         break;
   }

   // Update UI
   UpdateStepModeUI();
}

//+------------------------------------------------------------------+
//| Section 1: ATR Analysis (Step Mode)                               |
//+------------------------------------------------------------------+
void AnalyzeSection1_ATR()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  SECTION 1: ATR FILTER                                    ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   // Run ATR analysis via master module
   // (ATR is analyzed as part of the master SMC)

   string summary = "";
   summary += "ATR Value: " + DoubleToString(g_sectionResults.atrValue, 2) + "\n";
   summary += "ATR Pips: " + DoubleToString(g_sectionResults.atrPips, 1) + "\n";
   summary += "Condition: " + g_sectionResults.volatilityCondition + "\n";
   summary += "Trend: " + g_sectionResults.volatilityTrend + "\n";
   summary += "Percentile: " + DoubleToString(g_sectionResults.atrPercentile, 1) + "%\n";
   summary += "Filter: " + (g_sectionResults.atrFilterPass ? "PASS" : "FAIL");

   g_sectionReports[0].analyzed = true;
   g_sectionReports[0].summary = summary;
   g_sectionReports[0].timestamp = TimeCurrent();

   Print("║  ATR: ", DoubleToString(g_sectionResults.atrValue, 2),
         " (", DoubleToString(g_sectionResults.atrPips, 1), " pips)");
   Print("║  Condition: ", g_sectionResults.volatilityCondition);
   Print("║  Trend: ", g_sectionResults.volatilityTrend);
   Print("║  Percentile: ", DoubleToString(g_sectionResults.atrPercentile, 1), "%");
   Print("║  Filter: ", g_sectionResults.atrFilterPass ? "PASS ✓" : "FAIL ✗");
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print(">> Click 'Continue' or wait for auto-advance...");
}

//+------------------------------------------------------------------+
//| Section 2: EMA Analysis (Step Mode)                               |
//+------------------------------------------------------------------+
void AnalyzeSection2_EMA()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  SECTION 2: EMA ANALYSIS                                  ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   string summary = "";
   summary += "EMA 50: " + DoubleToString(g_sectionResults.emaFast, 2) + "\n";
   summary += "EMA 200: " + DoubleToString(g_sectionResults.emaSlow, 2) + "\n";
   summary += "Trend Bias: " + g_sectionResults.emaTrendBias + "\n";
   summary += "Bullish: " + (g_sectionResults.emaBullish ? "YES" : "NO") + "\n";
   summary += "Bearish: " + (g_sectionResults.emaBearish ? "YES" : "NO");

   g_sectionReports[1].analyzed = true;
   g_sectionReports[1].summary = summary;
   g_sectionReports[1].timestamp = TimeCurrent();

   Print("║  EMA 50: ", DoubleToString(g_sectionResults.emaFast, 2));
   Print("║  EMA 200: ", DoubleToString(g_sectionResults.emaSlow, 2));
   Print("║  Trend Bias: ", g_sectionResults.emaTrendBias);
   Print("║  Bullish: ", g_sectionResults.emaBullish ? "YES ✓" : "NO");
   Print("║  Bearish: ", g_sectionResults.emaBearish ? "YES ✓" : "NO");
   Print("║  Golden Cross: ", g_sectionResults.emaCrossoverBullish ? "YES" : "NO");
   Print("║  Death Cross: ", g_sectionResults.emaCrossoverBearish ? "YES" : "NO");
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print(">> Click 'Continue' or wait for auto-advance...");
}

//+------------------------------------------------------------------+
//| Section 3: Market Structure (Step Mode)                           |
//+------------------------------------------------------------------+
void AnalyzeSection3_Structure()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  SECTION 3: MARKET STRUCTURE                              ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   string trendStr = g_sectionResults.marketTrend == TREND_BULLISH ? "BULLISH" :
                     g_sectionResults.marketTrend == TREND_BEARISH ? "BEARISH" : "RANGING";

   string summary = "";
   summary += "Trend: " + trendStr + "\n";
   summary += "BOS: " + (g_sectionResults.bosConfirmed ? "CONFIRMED" : "NO") + "\n";
   summary += "CHoCH: " + (g_sectionResults.chochDetected ? "DETECTED" : "NO") + "\n";
   summary += "Swing High: " + DoubleToString(g_sectionResults.lastSwingHigh, 2) + "\n";
   summary += "Swing Low: " + DoubleToString(g_sectionResults.lastSwingLow, 2);

   g_sectionReports[2].analyzed = true;
   g_sectionReports[2].summary = summary;
   g_sectionReports[2].timestamp = TimeCurrent();

   Print("║  Trend: ", trendStr);
   Print("║  BOS: ", g_sectionResults.bosConfirmed ? "CONFIRMED ✓" : "NO");
   Print("║  CHoCH: ", g_sectionResults.chochDetected ? "DETECTED ✓" : "NO");
   Print("║  Swing High: ", DoubleToString(g_sectionResults.lastSwingHigh, 2));
   Print("║  Swing Low: ", DoubleToString(g_sectionResults.lastSwingLow, 2));
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print(">> Click 'Continue' or wait for auto-advance...");
}

//+------------------------------------------------------------------+
//| Section 4: Supply/Demand (Step Mode)                              |
//+------------------------------------------------------------------+
void AnalyzeSection4_SupplyDemand()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  SECTION 4: SUPPLY/DEMAND ZONES                           ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   string summary = "";
   summary += "In Supply: " + (g_sectionResults.inSupplyZone ? "YES" : "NO") + "\n";
   summary += "In Demand: " + (g_sectionResults.inDemandZone ? "YES" : "NO") + "\n";
   summary += "Supply High: " + DoubleToString(g_sectionResults.supplyZoneHigh, 2) + "\n";
   summary += "Demand Low: " + DoubleToString(g_sectionResults.demandZoneLow, 2);

   g_sectionReports[3].analyzed = true;
   g_sectionReports[3].summary = summary;
   g_sectionReports[3].timestamp = TimeCurrent();

   Print("║  In Supply Zone: ", g_sectionResults.inSupplyZone ? "YES ✓" : "NO");
   Print("║  In Demand Zone: ", g_sectionResults.inDemandZone ? "YES ✓" : "NO");
   Print("║  Supply High: ", DoubleToString(g_sectionResults.supplyZoneHigh, 2));
   Print("║  Demand Low: ", DoubleToString(g_sectionResults.demandZoneLow, 2));
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print(">> Click 'Continue' or wait for auto-advance...");
}

//+------------------------------------------------------------------+
//| Section 5: Liquidity (Step Mode)                                  |
//+------------------------------------------------------------------+
void AnalyzeSection5_Liquidity()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  SECTION 5: LIQUIDITY ANALYSIS                            ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   string summary = "";
   summary += "Swept: " + (g_sectionResults.liquiditySwept ? "YES" : "NO") + "\n";
   summary += "Level: " + DoubleToString(g_sectionResults.liquidityLevel, 2) + "\n";
   summary += "EQL Taken: " + (g_sectionResults.eqlTaken ? "YES" : "NO") + "\n";
   summary += "EQH Taken: " + (g_sectionResults.eqhTaken ? "YES" : "NO");

   g_sectionReports[4].analyzed = true;
   g_sectionReports[4].summary = summary;
   g_sectionReports[4].timestamp = TimeCurrent();

   Print("║  Liquidity Swept: ", g_sectionResults.liquiditySwept ? "YES ✓" : "NO");
   Print("║  Level: ", DoubleToString(g_sectionResults.liquidityLevel, 2));
   Print("║  EQL Taken: ", g_sectionResults.eqlTaken ? "YES" : "NO");
   Print("║  EQH Taken: ", g_sectionResults.eqhTaken ? "YES" : "NO");
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print(">> Click 'Continue' or wait for auto-advance...");
}

//+------------------------------------------------------------------+
//| Section 6: Sessions (Step Mode)                                   |
//+------------------------------------------------------------------+
void AnalyzeSection6_Sessions()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  SECTION 6: SESSION ANALYSIS                              ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   string sessionStr = g_sectionResults.currentSession == SESSION_LONDON ? "London" :
                       g_sectionResults.currentSession == SESSION_NEWYORK ? "New York" :
                       g_sectionResults.currentSession == SESSION_OVERLAP ? "Overlap" :
                       g_sectionResults.currentSession == SESSION_ASIA ? "Asia" : "Off Hours";

   string summary = "";
   summary += "Session: " + sessionStr + "\n";
   summary += "Active: " + (g_sectionResults.sessionActive ? "YES" : "NO") + "\n";
   summary += "Killzone: " + (g_sectionResults.inKillzone ? "YES" : "NO");

   g_sectionReports[5].analyzed = true;
   g_sectionReports[5].summary = summary;
   g_sectionReports[5].timestamp = TimeCurrent();

   Print("║  Current Session: ", sessionStr);
   Print("║  Active: ", g_sectionResults.sessionActive ? "YES ✓" : "NO");
   Print("║  In Killzone: ", g_sectionResults.inKillzone ? "YES ✓" : "NO");
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print(">> Click 'Continue' or wait for auto-advance...");
}

//+------------------------------------------------------------------+
//| Section 7: FVG (Step Mode)                                        |
//+------------------------------------------------------------------+
void AnalyzeSection7_FVG()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  SECTION 7: FAIR VALUE GAPS                               ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   string summary = "";
   summary += "Bullish: " + IntegerToString(g_sectionResults.bullishFVGCount) + "\n";
   summary += "Bearish: " + IntegerToString(g_sectionResults.bearishFVGCount) + "\n";
   summary += "Mitigated: " + IntegerToString(g_sectionResults.mitigatedFVGCount) + "\n";
   summary += "In FVG: " + (g_sectionResults.priceInFVG ? "YES" : "NO");

   g_sectionReports[6].analyzed = true;
   g_sectionReports[6].summary = summary;
   g_sectionReports[6].timestamp = TimeCurrent();

   Print("║  Bullish FVGs: ", g_sectionResults.bullishFVGCount);
   Print("║  Bearish FVGs: ", g_sectionResults.bearishFVGCount);
   Print("║  Mitigated: ", g_sectionResults.mitigatedFVGCount);
   Print("║  Price In FVG: ", g_sectionResults.priceInFVG ? "YES ✓" : "NO");
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print(">> Click 'Continue' or wait for auto-advance...");
}

//+------------------------------------------------------------------+
//| Section 8: Order Blocks (Step Mode)                               |
//+------------------------------------------------------------------+
void AnalyzeSection8_OrderBlocks()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  SECTION 8: ORDER BLOCKS                                  ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   string summary = "";
   summary += "Bullish OB: " + (g_sectionResults.bullishOBPresent ? "YES" : "NO") + "\n";
   summary += "Bearish OB: " + (g_sectionResults.bearishOBPresent ? "YES" : "NO") + "\n";
   summary += "In OB: " + (g_sectionResults.priceInOB ? "YES" : "NO") + "\n";
   summary += "Fresh: " + (g_sectionResults.obFresh ? "YES" : "NO");

   g_sectionReports[7].analyzed = true;
   g_sectionReports[7].summary = summary;
   g_sectionReports[7].timestamp = TimeCurrent();

   Print("║  Bullish OB: ", g_sectionResults.bullishOBPresent ? "YES ✓" : "NO");
   Print("║  Bearish OB: ", g_sectionResults.bearishOBPresent ? "YES ✓" : "NO");
   Print("║  Price In OB: ", g_sectionResults.priceInOB ? "YES ✓" : "NO");
   Print("║  OB Fresh: ", g_sectionResults.obFresh ? "YES" : "NO");
   if(g_sectionResults.bullishOBPresent || g_sectionResults.bearishOBPresent)
      Print("║  OB Range: ", DoubleToString(g_sectionResults.obLow, 2),
            " - ", DoubleToString(g_sectionResults.obHigh, 2));
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print(">> Click 'Continue' or wait for auto-advance...");
}

//+------------------------------------------------------------------+
//| Section 9: Fibonacci/OTE (Step Mode)                              |
//+------------------------------------------------------------------+
void AnalyzeSection9_Fibonacci()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  SECTION 9: FIBONACCI / OTE ZONE                          ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   string summary = "";
   summary += "In OTE: " + (g_sectionResults.inOTEZone ? "YES" : "NO") + "\n";
   summary += "Fib Level: " + DoubleToString(g_sectionResults.currentFibLevel * 100, 1) + "%\n";
   summary += "OTE High: " + DoubleToString(g_sectionResults.oteHigh, 2) + "\n";
   summary += "OTE Low: " + DoubleToString(g_sectionResults.oteLow, 2);

   g_sectionReports[8].analyzed = true;
   g_sectionReports[8].summary = summary;
   g_sectionReports[8].timestamp = TimeCurrent();

   Print("║  In OTE Zone: ", g_sectionResults.inOTEZone ? "YES ✓" : "NO");
   Print("║  Current Fib: ", DoubleToString(g_sectionResults.currentFibLevel * 100, 1), "%");
   Print("║  OTE High: ", DoubleToString(g_sectionResults.oteHigh, 2));
   Print("║  OTE Low: ", DoubleToString(g_sectionResults.oteLow, 2));
   Print("║  Golden Pocket: ", DoubleToString(g_sectionResults.goldenPocket618, 2));
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print(">> Click 'Continue' or wait for auto-advance...");
}

//+------------------------------------------------------------------+
//| Section 10: Killzones/HTF-LTF (Step Mode)                         |
//+------------------------------------------------------------------+
void AnalyzeSection10_Killzones()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  SECTION 10: KILLZONES / HTF-LTF ALIGNMENT                ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   string summary = "";
   summary += "HTF Aligned: " + (g_sectionResults.htfLtfAligned ? "YES" : "NO") + "\n";
   summary += "LTF Entry: " + (g_sectionResults.ltfEntryValid ? "YES" : "NO") + "\n";
   summary += "In Killzone: " + (g_sectionResults.inKillzone ? "YES" : "NO");

   g_sectionReports[9].analyzed = true;
   g_sectionReports[9].summary = summary;
   g_sectionReports[9].timestamp = TimeCurrent();

   Print("║  HTF-LTF Aligned: ", g_sectionResults.htfLtfAligned ? "YES ✓" : "NO");
   Print("║  LTF Entry Valid: ", g_sectionResults.ltfEntryValid ? "YES ✓" : "NO");
   Print("║  In Killzone: ", g_sectionResults.inKillzone ? "YES ✓" : "NO");
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print(">> Click 'Continue' or wait for auto-advance...");
}

//+------------------------------------------------------------------+
//| Section 11: Confluence (Step Mode)                                |
//+------------------------------------------------------------------+
void AnalyzeSection11_Confluence()
{
   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  SECTION 11: CONFLUENCE SCORING                           ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   string strengthStr = g_sectionResults.signalStrong ? "STRONG" :
                        g_sectionResults.signalModerate ? "MODERATE" :
                        g_sectionResults.signalWeak ? "WEAK" : "NONE";

   string summary = "";
   summary += "Score: " + IntegerToString(g_sectionResults.confluenceScore) + "/10\n";
   summary += "Strength: " + strengthStr + "\n";
   summary += "Trade Valid: " + (g_sectionResults.confluenceScore >= InpMinConfluence ? "YES" : "NO");

   g_sectionReports[10].analyzed = true;
   g_sectionReports[10].summary = summary;
   g_sectionReports[10].timestamp = TimeCurrent();

   Print("║  Confluence Score: ", g_sectionResults.confluenceScore, "/10");
   Print("║  Signal Strength: ", strengthStr);
   Print("║  Min Required: ", InpMinConfluence, "/10");
   Print("║  Trade Valid: ", g_sectionResults.confluenceScore >= InpMinConfluence ? "YES ✓" : "NO ✗");
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print(">> Click 'Continue' to complete initialization...");
}

//+------------------------------------------------------------------+
//| Complete Step Mode                                                |
//+------------------------------------------------------------------+
void CompleteStepMode()
{
   g_stepModeActive = false;

   // Kill timer
   EventKillTimer();

   Print("");
   Print("╔═══════════════════════════════════════════════════════════╗");
   Print("║  ALL SECTIONS INITIALIZED & CONFIRMED                     ║");
   Print("╠═══════════════════════════════════════════════════════════╣");

   // Print summary of all sections
   Print("║  SECTION SUMMARY:");
   for(int i = 0; i < 11; i++)
   {
      string status = g_sectionReports[i].confirmed ? "✓ CONFIRMED" : "○ ANALYZED";
      Print("║    Section ", i+1, ": ", status);
   }

   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║  Confluence Score: ", g_sectionResults.confluenceScore, "/10");
   Print("║  Ready for Trading: ", g_sectionResults.confluenceScore >= InpMinConfluence ? "YES" : "NO");
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print("");

   // Set status
   g_status.statusMessage = "Step Mode Complete - Ready";

   // Hide step mode UI, show normal panel
   DeleteStepModeUI();

   if(InpShowMasterPanel)
      UpdatePanel();
}

//+------------------------------------------------------------------+
//| Create Step Mode UI                                               |
//+------------------------------------------------------------------+
void CreateStepModeUI()
{
   int x = 350;
   int y = InpPanelY;
   int width = 280;
   int height = 200;

   // Background
   ObjectCreate(0, g_stepPanelName + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_stepPanelName + "_BG", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, g_stepPanelName + "_BG", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, g_stepPanelName + "_BG", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, g_stepPanelName + "_BG", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, g_stepPanelName + "_BG", OBJPROP_BGCOLOR, clrDarkSlateGray);
   ObjectSetInteger(0, g_stepPanelName + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_stepPanelName + "_BG", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, g_stepPanelName + "_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);

   // Title
   CreateLabel(g_stepPanelName + "_Title", "DEBUG STEP MODE", x + 10, y + 5, clrGold, 11, true);

   // Current step label
   CreateLabel(g_stepPanelName + "_Step", "Step: Initializing...", x + 10, y + 30, clrWhite, 10, false);

   // Status label
   CreateLabel(g_stepPanelName + "_Status", "Status: Waiting", x + 10, y + 55, clrLime, 9, false);

   // Progress label
   CreateLabel(g_stepPanelName + "_Progress", "Progress: 0/11", x + 10, y + 80, clrCyan, 9, false);

   // Auto-advance status
   string autoStr = InpAutoAdvance ? "ON (" + IntegerToString(InpAutoAdvanceDelay) + "s)" : "OFF";
   CreateLabel(g_stepPanelName + "_Auto", "Auto-advance: " + autoStr, x + 10, y + 105, clrSilver, 8, false);

   // Continue button
   ObjectCreate(0, g_continueButtonName, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, g_continueButtonName, OBJPROP_XDISTANCE, x + 40);
   ObjectSetInteger(0, g_continueButtonName, OBJPROP_YDISTANCE, y + 135);
   ObjectSetInteger(0, g_continueButtonName, OBJPROP_XSIZE, 200);
   ObjectSetInteger(0, g_continueButtonName, OBJPROP_YSIZE, 40);
   ObjectSetString(0, g_continueButtonName, OBJPROP_TEXT, "▶ CONTINUE");
   ObjectSetInteger(0, g_continueButtonName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, g_continueButtonName, OBJPROP_BGCOLOR, clrDarkGreen);
   ObjectSetInteger(0, g_continueButtonName, OBJPROP_BORDER_COLOR, clrLime);
   ObjectSetInteger(0, g_continueButtonName, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, g_continueButtonName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, g_continueButtonName, OBJPROP_CORNER, CORNER_LEFT_UPPER);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Step Mode UI                                               |
//+------------------------------------------------------------------+
void UpdateStepModeUI()
{
   if(!g_stepModeActive) return;

   // Step names
   string stepNames[] = {"Not Started", "ATR Filter", "EMA Analysis", "Market Structure",
                         "Supply/Demand", "Liquidity", "Sessions", "FVG",
                         "Order Blocks", "Fibonacci", "Killzones", "Confluence", "Complete"};

   // Update step label
   string stepText = "Step: Section " + IntegerToString(g_currentStep) + " - " + stepNames[g_currentStep];
   ObjectSetString(0, g_stepPanelName + "_Step", OBJPROP_TEXT, stepText);

   // Update status
   string statusText = "Status: Analyzing...";
   if(g_currentStep > STEP_NOT_STARTED && g_currentStep <= STEP_SECTION_11)
   {
      if(g_sectionReports[g_currentStep - 1].analyzed)
         statusText = "Status: Ready for confirmation";
   }
   ObjectSetString(0, g_stepPanelName + "_Status", OBJPROP_TEXT, statusText);

   // Update progress
   int progress = (g_currentStep == STEP_NOT_STARTED) ? 0 : (int)g_currentStep;
   string progressText = "Progress: " + IntegerToString(progress) + "/11";
   ObjectSetString(0, g_stepPanelName + "_Progress", OBJPROP_TEXT, progressText);

   // Update button text based on step
   if(g_currentStep == STEP_SECTION_11)
      ObjectSetString(0, g_continueButtonName, OBJPROP_TEXT, "✓ COMPLETE");
   else
      ObjectSetString(0, g_continueButtonName, OBJPROP_TEXT, "▶ CONTINUE");

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete Step Mode UI                                               |
//+------------------------------------------------------------------+
void DeleteStepModeUI()
{
   ObjectDelete(0, g_continueButtonName);
   ObjectsDeleteAll(0, g_stepPanelName);
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Run Full SMC Analysis - Uses Real Section Modules                 |
//+------------------------------------------------------------------+
void RunSMCAnalysis(bool printDebug = true)
{
   ZeroMemory(g_analysis);

   // Run all section analyses via Master SMC module
   // This calls Sections 3, 5, 6, 7, 8, 9, 10, 11 in sequence
   g_masterSMC.RunFullAnalysis();

   // Sync results from g_sectionResults (SMCModules) to g_analysis (local)
   SyncSectionResults();

   // Generate final signal based on all section data
   GenerateSignal();

   // Debug: Print all section values (skip on init to avoid duplicate)
   if(printDebug)
      PrintSMCDebug();
}

//+------------------------------------------------------------------+
//| Debug Print - Shows All Section Values                            |
//+------------------------------------------------------------------+
void PrintSMCDebug()
{
   Print("═══════════════ SMC ANALYSIS DEBUG ═══════════════");

   // Section 1: ATR Filter
   Print("SEC 1 | ATR: ", DoubleToString(g_sectionResults.atrValue, 2),
         " (", DoubleToString(g_sectionResults.atrPips, 1), " pips)",
         " | Condition: ", g_sectionResults.volatilityCondition,
         " | Filter: ", g_sectionResults.atrFilterPass ? "PASS" : "FAIL");
   Print("      | Trend: ", g_sectionResults.volatilityTrend,
         " | Percentile: ", DoubleToString(g_sectionResults.atrPercentile, 1), "%",
         " | Squeeze: ", g_sectionResults.volatilitySqueeze ? "YES" : "NO");

   // Section 2: EMA Analysis
   Print("SEC 2 | EMA50: ", DoubleToString(g_sectionResults.emaFast, 2),
         " | EMA200: ", DoubleToString(g_sectionResults.emaSlow, 2),
         " | Bias: ", g_sectionResults.emaTrendBias);
   Print("      | Bullish: ", g_sectionResults.emaBullish ? "YES" : "NO",
         " | Bearish: ", g_sectionResults.emaBearish ? "YES" : "NO",
         " | GoldenX: ", g_sectionResults.emaCrossoverBullish ? "YES" : "NO",
         " | DeathX: ", g_sectionResults.emaCrossoverBearish ? "YES" : "NO");

   // Section 3: Market Structure
   string trendStr = g_analysis.trend == STRUCTURE_BULLISH ? "BULLISH" :
                     g_analysis.trend == STRUCTURE_BEARISH ? "BEARISH" : "RANGING";
   Print("SEC 3 | Trend: ", trendStr, " | BOS: ", g_analysis.bosConfirmed ? "YES" : "NO",
         " | CHoCH: ", g_analysis.chochDetected ? "YES" : "NO");
   Print("      | SwingHigh: ", DoubleToString(g_analysis.lastSwingHigh, 2),
         " | SwingLow: ", DoubleToString(g_analysis.lastSwingLow, 2));

   // Section 4: Supply/Demand
   Print("SEC 4 | InSupply: ", g_analysis.inSupplyZone ? "YES" : "NO",
         " | InDemand: ", g_analysis.inDemandZone ? "YES" : "NO");

   // Section 5: Liquidity
   Print("SEC 5 | LiqSwept: ", g_analysis.liquiditySwept ? "YES" : "NO",
         " | EQLTaken: ", g_analysis.eqlTaken ? "YES" : "NO",
         " | Level: ", DoubleToString(g_analysis.liquidityLevel, 2));

   // Session Analysis
   string sessionStr = g_analysis.currentSession == SESSION_LONDON ? "London" :
                       g_analysis.currentSession == SESSION_NEWYORK ? "NewYork" :
                       g_analysis.currentSession == SESSION_OVERLAP ? "Overlap" :
                       g_analysis.currentSession == SESSION_ASIA ? "Asia" : "OffHours";
   Print("SESSN | Session: ", sessionStr, " | Active: ", g_analysis.sessionActive ? "YES" : "NO",
         " | Killzone: ", g_sectionResults.inKillzone ? "YES" : "NO");

   // Section 6: MACD/RSI Momentum
   Print("SEC 6 | MACD: ", DoubleToString(g_sectionResults.macdMain, 5),
         " | Signal: ", DoubleToString(g_sectionResults.macdSignal, 5),
         " | Hist: ", DoubleToString(g_sectionResults.macdHistogram, 5));
   Print("      | MACDBull: ", g_sectionResults.macdBullish ? "YES" : "NO",
         " | MACDBear: ", g_sectionResults.macdBearish ? "YES" : "NO",
         " | CrossBull: ", g_sectionResults.macdCrossoverBullish ? "YES" : "NO",
         " | CrossBear: ", g_sectionResults.macdCrossoverBearish ? "YES" : "NO");
   Print("      | RSI: ", DoubleToString(g_sectionResults.rsiValue, 1),
         " | OB: ", g_sectionResults.rsiOverbought ? "YES" : "NO",
         " | OS: ", g_sectionResults.rsiOversold ? "YES" : "NO",
         " | Bias: ", g_sectionResults.momentumBias,
         " | Aligned: ", g_sectionResults.momentumAligned ? "YES" : "NO");
   if(g_sectionResults.macdDivergenceBullish || g_sectionResults.macdDivergenceBearish)
      Print("      | Divergence: ", g_sectionResults.macdDivergenceBullish ? "BULLISH" : "BEARISH");

   // Section 7: FVG
   Print("SEC 7 | Bullish: ", g_sectionResults.bullishFVGCount,
         " | Bearish: ", g_sectionResults.bearishFVGCount,
         " | Mitigated: ", g_sectionResults.mitigatedFVGCount);
   Print("      | InFVG: ", g_analysis.bullishFVG || g_analysis.bearishFVG ? "YES" : "NO");

   // Section 8: Order Blocks
   Print("SEC 8 | BullOB: ", g_analysis.bullishOB ? "YES" : "NO",
         " | BearOB: ", g_analysis.bearishOB ? "YES" : "NO");
   if(g_analysis.bullishOB || g_analysis.bearishOB)
      Print("      | OB Range: ", DoubleToString(g_analysis.obLow, 2), " - ", DoubleToString(g_analysis.obHigh, 2));

   // Section 9: Fibonacci/OTE
   Print("SEC 9 | InOTE: ", g_analysis.inOTE ? "YES" : "NO",
         " | FibLevel: ", DoubleToString(g_analysis.fibLevel * 100, 1), "%");

   // Section 10: HTF/LTF
   Print("SEC10 | HTFAligned: ", g_analysis.htfAligned ? "YES" : "NO",
         " | LTFEntry: ", g_analysis.ltfEntry ? "YES" : "NO");

   // Section 11: Confluence
   Print("SEC11 | Confluence: ", g_analysis.confluenceScore, "/10",
         " | Strength: ", g_analysis.signalStrength == SIGNAL_STRONG ? "STRONG" :
                          g_analysis.signalStrength == SIGNAL_MODERATE ? "MODERATE" :
                          g_analysis.signalStrength == SIGNAL_WEAK ? "WEAK" : "NONE");

   // Final Signal
   string dirStr = g_analysis.direction == DIR_BUY ? "BUY" :
                   g_analysis.direction == DIR_SELL ? "SELL" : "NONE";
   Print("SIGNAL| Direction: ", dirStr, " | Valid: ", g_analysis.signalValid ? "YES" : "NO");
   Print("      | Reason: ", g_analysis.signalReason);

   Print("═══════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Sync Section Results to Local Analysis Structure                  |
//+------------------------------------------------------------------+
void SyncSectionResults()
{
   // Section 3: Market Structure
   g_analysis.trend = (g_sectionResults.marketTrend == TREND_BULLISH) ? STRUCTURE_BULLISH :
                      (g_sectionResults.marketTrend == TREND_BEARISH) ? STRUCTURE_BEARISH : STRUCTURE_RANGING;
   g_analysis.bosConfirmed = g_sectionResults.bosConfirmed;
   g_analysis.chochDetected = g_sectionResults.chochDetected;
   g_analysis.lastSwingHigh = g_sectionResults.lastSwingHigh;
   g_analysis.lastSwingLow = g_sectionResults.lastSwingLow;

   // Section 4: Supply/Demand
   g_analysis.inSupplyZone = g_sectionResults.inSupplyZone;
   g_analysis.inDemandZone = g_sectionResults.inDemandZone;
   g_analysis.nearestSupply = g_sectionResults.supplyZoneHigh;
   g_analysis.nearestDemand = g_sectionResults.demandZoneLow;

   // Section 5: Liquidity
   g_analysis.liquiditySwept = g_sectionResults.liquiditySwept;
   g_analysis.liquidityLevel = g_sectionResults.liquidityLevel;
   g_analysis.eqlTaken = g_sectionResults.eqlTaken;

   // Section 6: Sessions (directly assign since both use ENUM_SESSION_TYPE)
   g_analysis.currentSession = g_sectionResults.currentSession;
   g_analysis.sessionActive = g_sectionResults.sessionActive;
   g_analysis.newsUpcoming = g_sectionResults.newsUpcoming;
   g_analysis.minsToNews = g_sectionResults.minsToNews;

   // Section 7: FVG
   g_analysis.bullishFVG = g_sectionResults.bullishFVGPresent;
   g_analysis.bearishFVG = g_sectionResults.bearishFVGPresent;
   g_analysis.fvgHigh = g_sectionResults.fvgHigh;
   g_analysis.fvgLow = g_sectionResults.fvgLow;

   // Section 8: Order Blocks
   g_analysis.bullishOB = g_sectionResults.bullishOBPresent;
   g_analysis.bearishOB = g_sectionResults.bearishOBPresent;
   g_analysis.obHigh = g_sectionResults.obHigh;
   g_analysis.obLow = g_sectionResults.obLow;

   // Section 9: Fibonacci/OTE
   g_analysis.inOTE = g_sectionResults.inOTEZone;
   g_analysis.oteHigh = g_sectionResults.oteHigh;
   g_analysis.oteLow = g_sectionResults.oteLow;
   g_analysis.fibLevel = g_sectionResults.currentFibLevel;

   // Section 10: Killzones
   g_analysis.htfAligned = g_sectionResults.htfLtfAligned;
   g_analysis.ltfEntry = g_sectionResults.ltfEntryValid;

   // Section 11: Confluence
   g_analysis.confluenceScore = g_sectionResults.confluenceScore;
   g_analysis.signalStrength = g_sectionResults.signalStrong ? SIGNAL_STRONG :
                               g_sectionResults.signalModerate ? SIGNAL_MODERATE :
                               g_sectionResults.signalWeak ? SIGNAL_WEAK : SIGNAL_NONE;
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

   // Determine current session (using ENUM_SESSION_TYPE from SMCModules.mqh)
   if(hour >= InpAsiaStart && hour < InpAsiaEnd)
      g_analysis.currentSession = SESSION_ASIA;
   else if(hour >= InpLondonStart && hour < InpNYStart)
      g_analysis.currentSession = SESSION_LONDON;
   else if(hour >= InpNYStart && hour < InpLondonEnd)
      g_analysis.currentSession = SESSION_OVERLAP;
   else if(hour >= InpLondonEnd && hour < InpNYEnd)
      g_analysis.currentSession = SESSION_NEWYORK;
   else
      g_analysis.currentSession = SESSION_OFFHOURS;

   // Session is active if not off-hours
   g_analysis.sessionActive = (g_analysis.currentSession != SESSION_OFFHOURS);

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

   // Check spread before execution
   double currentSpread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double maxAllowedSpread = g_sectionResults.atrValue * 0.1;  // Max 10% of ATR

   if(currentSpread > maxAllowedSpread)
   {
      Print("⚠ Trade skipped - Spread too high: ", DoubleToString(currentSpread, _Digits),
            " > Max: ", DoubleToString(maxAllowedSpread, _Digits));
      g_status.statusMessage = "Spread Too High";
      return;
   }

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
                       g_analysis.currentSession == SESSION_NEWYORK ? "New York" :
                       g_analysis.currentSession == SESSION_OVERLAP ? "Overlap" :
                       g_analysis.currentSession == SESSION_ASIA ? "Asian" : "Off Hours";
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
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ BACKTEST DATE RANGE:");
   if(InpUseDateFilter)
   {
      Print("║   Filter: ENABLED");
      Print("║   Start:  ", TimeToString(InpStartDate, TIME_DATE|TIME_MINUTES));
      Print("║   End:    ", TimeToString(InpEndDate, TIME_DATE|TIME_MINUTES));
   }
   else
   {
      Print("║   Filter: DISABLED (All dates processed)");
   }
   Print("╠═══════════════════════════════════════════════════════════╣");
   Print("║ DEBUG STEP MODE:");
   if(InpDebugStepMode)
   {
      Print("║   Mode: ENABLED");
      Print("║   Auto-Advance: ", InpAutoAdvance ? "ON" : "OFF");
      if(InpAutoAdvance)
         Print("║   Delay: ", InpAutoAdvanceDelay, " seconds");
      Print("║   Sections will initialize one-by-one with confirmation");
   }
   else
   {
      Print("║   Mode: DISABLED (Normal initialization)");
   }
   Print("╚═══════════════════════════════════════════════════════════╝");
   Print("");
}

//+------------------------------------------------------------------+
