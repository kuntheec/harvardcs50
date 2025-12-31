//+------------------------------------------------------------------+
//|                                    Section13_TradeExecution.mq5   |
//|                         SwingTrader Pro EA - Trade Execution      |
//|                                 Version 1.01 - SMC Enhanced       |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.01"
#property indicator_chart_window

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Enumerations (must be before inputs)                              |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_MODE
{
   ENTRY_MARKET,          // Market Order
   ENTRY_LIMIT,           // Limit Order
   ENTRY_STOP             // Stop Order
};

enum ENUM_BE_TRIGGER
{
   BE_AFTER_TP1,          // After TP1 Hit
   BE_AT_RR_1,            // At 1:1 Risk:Reward
   BE_CUSTOM_POINTS       // Custom Points
};

enum ENUM_TRAIL_MODE
{
   TRAIL_NONE,            // No Trailing
   TRAIL_ATR,             // ATR-Based
   TRAIL_FIXED,           // Fixed Points
   TRAIL_SMC_STRUCTURE,   // SMC Structure (BOS/Swings)
   TRAIL_STEP             // Step Trail
};

enum ENUM_TRADE_DIRECTION
{
   TRADE_BUY,
   TRADE_SELL
};

enum ENUM_INSTRUMENT_PROFILE
{
   PROFILE_FOREX,
   PROFILE_GOLD,
   PROFILE_SILVER,
   PROFILE_CRYPTO,
   PROFILE_INDEX,
   PROFILE_OTHER
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
   GROUP_CRYPTO,
   GROUP_OTHER
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== SECTION 13: TRADE EXECUTION v1.01 (SMC) ==="
input string   InpEAComment           = "SwingTraderPro";  // EA Trade Comment
input ulong    InpMagicNumber         = 123456;            // Magic Number
input int      InpMaxSlippage         = 30;                // Max Slippage (points)
input int      InpMaxRetries          = 3;                 // Max Order Retries

input group "=== Entry Mode ==="
input ENUM_ENTRY_MODE InpEntryMode    = ENTRY_MARKET;      // Entry Mode
input int      InpPendingExpiry       = 24;                // Pending Order Expiry (hours)
input double   InpLimitOffset         = 0.0;               // Limit Order Offset (ATR %)
input double   InpMaxSpreadATR        = 0.1;               // Max Spread (ATR %) - 0=disabled

input group "=== SMC Confluence Integration ==="
input bool     InpUseConfluenceTP     = true;              // Adjust TP by Confluence Score
input double   InpStrongTP_Mult       = 1.2;               // Strong Signal TP Multiplier (8-10)
input double   InpModerateTP_Mult     = 1.0;               // Moderate Signal TP Mult (6-7)
input double   InpWeakTP_Mult         = 0.8;               // Weak Signal TP Mult (4-5)

input group "=== Dynamic R:R Per Profile ==="
input double   InpTP1_RR_Forex        = 1.5;               // TP1 R:R - Forex
input double   InpTP2_RR_Forex        = 2.5;               // TP2 R:R - Forex
input double   InpTP3_RR_Forex        = 4.0;               // TP3 R:R - Forex
input double   InpTP1_RR_Gold         = 2.0;               // TP1 R:R - Gold (Higher Vol)
input double   InpTP2_RR_Gold         = 3.5;               // TP2 R:R - Gold
input double   InpTP3_RR_Gold         = 5.0;               // TP3 R:R - Gold
input double   InpTP1_RR_Crypto       = 2.5;               // TP1 R:R - Crypto
input double   InpTP2_RR_Crypto       = 4.0;               // TP2 R:R - Crypto
input double   InpTP3_RR_Crypto       = 6.0;               // TP3 R:R - Crypto

input group "=== Take Profit Levels ==="
input bool     InpUseMultipleTP       = true;              // Use Multiple TP Levels
input double   InpTP1_Percent         = 40.0;              // TP1 Close Percent
input double   InpTP2_Percent         = 30.0;              // TP2 Close Percent

input group "=== SMC Staged Entries (Pyramiding) ==="
input bool     InpUseStagedEntries    = true;              // Enable Staged Entries
input int      InpMaxStages           = 3;                 // Max Entry Stages
input double   InpStage2_LotMult      = 0.5;               // Stage 2 Lot Multiplier
input double   InpStage3_LotMult      = 0.25;              // Stage 3 Lot Multiplier
input bool     InpStage2_OnOTE        = true;              // Stage 2: Add on OTE Pullback
input bool     InpStage3_OnBOS        = true;              // Stage 3: Add after BOS Confirm

input group "=== Break-Even Settings ==="
input bool     InpUseBreakEven        = true;              // Enable Break-Even
input ENUM_BE_TRIGGER InpBETrigger    = BE_AFTER_TP1;      // Break-Even Trigger
input double   InpBEOffset            = 5.0;               // BE Offset (points profit)

input group "=== SMC Trailing Stop ==="
input bool     InpUseTrailing         = true;              // Enable Trailing Stop
input ENUM_TRAIL_MODE InpTrailMode    = TRAIL_SMC_STRUCTURE; // Trailing Mode
input double   InpTrailATRMult        = 1.5;               // ATR Multiplier for Trail
input double   InpTrailFixedPoints    = 500;               // Fixed Trail (points)
input double   InpTrailActivation     = 1.0;               // Activation (RR ratio)
input bool     InpPauseTrailOnNews    = true;              // Pause Trailing During News
input int      InpStructureLookback   = 50;                // Structure Lookback Bars

input group "=== Correlation/Exposure Limits ==="
input bool     InpUseCorrelationLimit = true;              // Enable Correlation Limits
input double   InpMaxUSDExposure      = 4.0;               // Max USD Group Exposure (%)
input double   InpMaxEURExposure      = 4.0;               // Max EUR Group Exposure (%)
input double   InpMaxGoldExposure     = 3.0;               // Max Gold Exposure (%)
input double   InpMaxTotalExposure    = 10.0;              // Max Total Exposure (%)

input group "=== Position Limits ==="
input int      InpMaxPositions        = 5;                 // Max Open Positions
input int      InpMaxPositionsPerSymbol = 3;               // Max Positions Per Symbol (stages)
input int      InpMaxPendingOrders    = 5;                 // Max Pending Orders

input group "=== Alerts ==="
input bool     InpAlertOnTP           = true;              // Alert on TP Hit
input bool     InpAlertOnBE           = true;              // Alert on Break-Even
input bool     InpAlertOnTrail        = false;             // Alert on Trail Adjustment
input bool     InpUsePushNotify       = false;             // Use Push Notifications

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;              // Show Execution Panel
input int      InpPanelX              = 10;                // Panel X Position
input int      InpPanelY              = 400;               // Panel Y Position
input color    InpPanelBg             = clrMidnightBlue;   // Panel Background

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct TradeRequest
{
   string            symbol;
   ENUM_TRADE_DIRECTION direction;
   double            entryPrice;
   double            stopLoss;
   double            takeProfit1;
   double            takeProfit2;
   double            takeProfit3;
   double            lotSize;
   int               confluenceScore;
   string            signalSource;
   int               stage;
   bool              isValid;
};

struct ActiveTrade
{
   ulong             ticket;
   string            symbol;
   ENUM_TRADE_DIRECTION direction;
   double            entryPrice;
   double            stopLoss;
   double            originalSL;
   double            takeProfit1;
   double            takeProfit2;
   double            takeProfit3;
   double            lots;
   double            originalLots;
   int               stage;
   int               confluenceScore;
   bool              tp1Hit;
   bool              tp2Hit;
   bool              breakEvenSet;
   bool              trailingActive;
   datetime          openTime;
   string            comment;
   double            lastBOSLevel;
   double            riskAmount;
};

struct ExecutionMetrics
{
   int               totalOrders;
   int               successfulOrders;
   int               failedOrders;
   int               tp1Hits;
   int               tp2Hits;
   int               tp3Hits;
   int               breakEvenHits;
   int               trailingStops;
   int               stagedEntries;
   double            avgSlippage;
   double            totalExposure;
   datetime          lastOrderTime;
};

struct ExposureTracker
{
   double            usdExposure;
   double            eurExposure;
   double            gbpExposure;
   double            jpyExposure;
   double            goldExposure;
   double            cryptoExposure;
   double            totalExposure;
};

struct SMCContext
{
   bool              newsActive;
   int               confluenceScore;
   double            lastBOS;
   double            lastCHoCH;
   double            recentSwingHigh;
   double            recentSwingLow;
   bool              inOTE;
   bool              bosConfirmed;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade            g_trade;
CPositionInfo     g_position;
COrderInfo        g_order;

ActiveTrade       g_activeTrades[];
ExecutionMetrics  g_execMetrics;
ExposureTracker   g_exposure;
SMCContext        g_smcContext;

int               g_atrHandle;
double            g_atrBuffer[];
bool              g_positionsLoaded = false;
bool              g_needsRefresh = true;

string            g_panelName = "SEC13_ExecPanel";
bool              g_initialized = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpMaxSlippage);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);
   g_trade.SetAsyncMode(false);

   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator");
      return INIT_FAILED;
   }
   ArraySetAsSeries(g_atrBuffer, true);

   ZeroMemory(g_execMetrics);
   ZeroMemory(g_exposure);
   ZeroMemory(g_smcContext);

   LoadActivePositions();
   CalculateExposure();

   if(InpShowPanel)
      CreateExecutionPanel();

   g_initialized = true;
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
   Print("Trade Execution EA v1.01 Deinitialized");
   Print("Total Orders: ", g_execMetrics.totalOrders);
   Print("Success Rate: ", g_execMetrics.totalOrders > 0 ?
         DoubleToString((double)g_execMetrics.successfulOrders/g_execMetrics.totalOrders*100, 1) + "%" : "N/A");
   Print("Staged Entries: ", g_execMetrics.stagedEntries);
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialized) return;

   CopyBuffer(g_atrHandle, 0, 0, 3, g_atrBuffer);

   if(g_needsRefresh)
   {
      LoadActivePositions();
      CalculateExposure();
      g_needsRefresh = false;
   }

   ManagePositions();

   if(InpShowPanel)
      UpdatePanel();
}

//+------------------------------------------------------------------+
//| Trade Transaction Handler - Efficient Updates                     |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD ||
      trans.type == TRADE_TRANSACTION_ORDER_DELETE ||
      trans.type == TRADE_TRANSACTION_POSITION)
   {
      g_needsRefresh = true;
   }
}

//+------------------------------------------------------------------+
//| Get Instrument Profile                                            |
//+------------------------------------------------------------------+
ENUM_INSTRUMENT_PROFILE GetInstrumentProfile(string symbol = "")
{
   if(symbol == "") symbol = _Symbol;
   string sym = symbol;
   StringToUpper(sym);

   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0)
      return PROFILE_GOLD;
   if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "SILVER") >= 0)
      return PROFILE_SILVER;
   if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 ||
      StringFind(sym, "LTC") >= 0 || StringFind(sym, "CRYPTO") >= 0)
      return PROFILE_CRYPTO;
   if(StringFind(sym, "US30") >= 0 || StringFind(sym, "NAS") >= 0 ||
      StringFind(sym, "SPX") >= 0 || StringFind(sym, "DAX") >= 0)
      return PROFILE_INDEX;

   return PROFILE_FOREX;
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
//| Get Dynamic R:R Based on Profile                                  |
//+------------------------------------------------------------------+
void GetDynamicRR(double &tp1RR, double &tp2RR, double &tp3RR, int confluenceScore = 6)
{
   ENUM_INSTRUMENT_PROFILE profile = GetInstrumentProfile();

   switch(profile)
   {
      case PROFILE_GOLD:
         tp1RR = InpTP1_RR_Gold;
         tp2RR = InpTP2_RR_Gold;
         tp3RR = InpTP3_RR_Gold;
         break;

      case PROFILE_CRYPTO:
         tp1RR = InpTP1_RR_Crypto;
         tp2RR = InpTP2_RR_Crypto;
         tp3RR = InpTP3_RR_Crypto;
         break;

      default:
         tp1RR = InpTP1_RR_Forex;
         tp2RR = InpTP2_RR_Forex;
         tp3RR = InpTP3_RR_Forex;
         break;
   }

   if(InpUseConfluenceTP)
   {
      double mult = InpModerateTP_Mult;
      if(confluenceScore >= 8)
         mult = InpStrongTP_Mult;
      else if(confluenceScore <= 5)
         mult = InpWeakTP_Mult;

      tp1RR *= mult;
      tp2RR *= mult;
      tp3RR *= mult;
   }
}

//+------------------------------------------------------------------+
//| Check Spread                                                      |
//+------------------------------------------------------------------+
bool CheckSpread(string symbol)
{
   if(InpMaxSpreadATR <= 0) return true;

   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   double atr = g_atrBuffer[0];

   if(atr <= 0) return true;

   double spreadPct = spread / atr * 100;

   if(spreadPct > InpMaxSpreadATR * 100)
   {
      Print("Spread too high: ", DoubleToString(spreadPct, 2), "% of ATR (max: ", InpMaxSpreadATR * 100, "%)");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Exposure                                                |
//+------------------------------------------------------------------+
void CalculateExposure()
{
   ZeroMemory(g_exposure);
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(accountBalance <= 0) return;

   for(int i = 0; i < ArraySize(g_activeTrades); i++)
   {
      double riskPct = (g_activeTrades[i].riskAmount / accountBalance) * 100;
      ENUM_CURRENCY_GROUP group = GetCurrencyGroup(g_activeTrades[i].symbol);

      switch(group)
      {
         case GROUP_USD: g_exposure.usdExposure += riskPct; break;
         case GROUP_EUR: g_exposure.eurExposure += riskPct; break;
         case GROUP_GBP: g_exposure.gbpExposure += riskPct; break;
         case GROUP_GOLD: g_exposure.goldExposure += riskPct; break;
         case GROUP_CRYPTO: g_exposure.cryptoExposure += riskPct; break;
         default: break;
      }

      g_exposure.totalExposure += riskPct;
   }

   g_execMetrics.totalExposure = g_exposure.totalExposure;
}

//+------------------------------------------------------------------+
//| Check Correlation Limits                                          |
//+------------------------------------------------------------------+
bool CheckCorrelationLimits(string symbol, double additionalRiskPct)
{
   if(!InpUseCorrelationLimit) return true;

   ENUM_CURRENCY_GROUP group = GetCurrencyGroup(symbol);
   double newExposure = g_exposure.totalExposure + additionalRiskPct;

   if(newExposure > InpMaxTotalExposure)
   {
      Print("Total exposure limit exceeded: ", DoubleToString(newExposure, 2), "%");
      return false;
   }

   switch(group)
   {
      case GROUP_USD:
         if(g_exposure.usdExposure + additionalRiskPct > InpMaxUSDExposure)
         {
            Print("USD exposure limit exceeded");
            return false;
         }
         break;

      case GROUP_EUR:
         if(g_exposure.eurExposure + additionalRiskPct > InpMaxEURExposure)
         {
            Print("EUR exposure limit exceeded");
            return false;
         }
         break;

      case GROUP_GOLD:
         if(g_exposure.goldExposure + additionalRiskPct > InpMaxGoldExposure)
         {
            Print("Gold exposure limit exceeded");
            return false;
         }
         break;

      default:
         break;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Execute Trade                                                     |
//+------------------------------------------------------------------+
bool ExecuteTrade(TradeRequest &request)
{
   if(!request.isValid)
   {
      Print("Invalid trade request");
      return false;
   }

   if(!CheckSpread(request.symbol))
      return false;

   if(!CheckPositionLimits(request.symbol))
   {
      Print("Position limits exceeded for ", request.symbol);
      return false;
   }

   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskDistance = MathAbs(request.entryPrice - request.stopLoss);
   double tickValue = SymbolInfoDouble(request.symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(request.symbol, SYMBOL_TRADE_TICK_SIZE);
   double riskAmount = (riskDistance / tickSize) * tickValue * request.lotSize;
   double riskPct = (riskAmount / accountBalance) * 100;

   if(!CheckCorrelationLimits(request.symbol, riskPct))
      return false;

   g_execMetrics.totalOrders++;

   bool success = false;
   double sl = request.stopLoss;
   double tp = InpUseMultipleTP ? request.takeProfit1 : request.takeProfit3;

   string comment = InpEAComment + "_" + request.signalSource +
                    "_C" + IntegerToString(request.confluenceScore) +
                    "_S" + IntegerToString(request.stage);

   switch(InpEntryMode)
   {
      case ENTRY_MARKET:
         success = ExecuteMarketOrder(request, sl, tp, comment);
         break;
      case ENTRY_LIMIT:
         success = ExecuteLimitOrder(request, sl, tp, comment);
         break;
      case ENTRY_STOP:
         success = ExecuteStopOrder(request, sl, tp, comment);
         break;
   }

   if(success)
   {
      g_execMetrics.successfulOrders++;
      g_execMetrics.lastOrderTime = TimeCurrent();

      if(request.stage > 1)
         g_execMetrics.stagedEntries++;

      g_needsRefresh = true;

      Print("✓ Trade executed: ", request.direction == TRADE_BUY ? "BUY" : "SELL",
            " ", request.symbol, " Stage ", request.stage,
            " @ ", request.entryPrice, " SL: ", sl,
            " Confluence: ", request.confluenceScore);
   }
   else
   {
      g_execMetrics.failedOrders++;
      Print("✗ Trade failed: ", GetLastError());
   }

   return success;
}

//+------------------------------------------------------------------+
//| Execute Market Order                                              |
//+------------------------------------------------------------------+
bool ExecuteMarketOrder(TradeRequest &request, double sl, double tp, string comment)
{
   int retries = 0;
   bool success = false;

   while(retries < InpMaxRetries && !success)
   {
      if(request.direction == TRADE_BUY)
      {
         double ask = SymbolInfoDouble(request.symbol, SYMBOL_ASK);
         success = g_trade.Buy(request.lotSize, request.symbol, ask, sl, tp, comment);
      }
      else
      {
         double bid = SymbolInfoDouble(request.symbol, SYMBOL_BID);
         success = g_trade.Sell(request.lotSize, request.symbol, bid, sl, tp, comment);
      }

      if(!success)
      {
         retries++;
         Sleep(500);
         Print("Order retry ", retries, "/", InpMaxRetries);
      }
   }

   if(success)
   {
      double executed = g_trade.ResultPrice();
      double requested = request.direction == TRADE_BUY ?
                        SymbolInfoDouble(request.symbol, SYMBOL_ASK) :
                        SymbolInfoDouble(request.symbol, SYMBOL_BID);
      double slippage = MathAbs(executed - requested) / SymbolInfoDouble(request.symbol, SYMBOL_POINT);

      int totalSuccess = g_execMetrics.successfulOrders;
      if(totalSuccess > 0)
         g_execMetrics.avgSlippage = ((g_execMetrics.avgSlippage * (totalSuccess - 1)) + slippage) / totalSuccess;
      else
         g_execMetrics.avgSlippage = slippage;
   }

   return success;
}

//+------------------------------------------------------------------+
//| Execute Limit Order                                               |
//+------------------------------------------------------------------+
bool ExecuteLimitOrder(TradeRequest &request, double sl, double tp, string comment)
{
   double atr = g_atrBuffer[0];
   double offset = atr * InpLimitOffset / 100.0;
   double limitPrice;
   datetime expiry = TimeCurrent() + InpPendingExpiry * 3600;

   if(request.direction == TRADE_BUY)
   {
      limitPrice = request.entryPrice - offset;
      return g_trade.BuyLimit(request.lotSize, limitPrice, request.symbol, sl, tp,
                              ORDER_TIME_SPECIFIED, expiry, comment);
   }
   else
   {
      limitPrice = request.entryPrice + offset;
      return g_trade.SellLimit(request.lotSize, limitPrice, request.symbol, sl, tp,
                               ORDER_TIME_SPECIFIED, expiry, comment);
   }
}

//+------------------------------------------------------------------+
//| Execute Stop Order                                                |
//+------------------------------------------------------------------+
bool ExecuteStopOrder(TradeRequest &request, double sl, double tp, string comment)
{
   double atr = g_atrBuffer[0];
   double offset = atr * InpLimitOffset / 100.0;
   double stopPrice;
   datetime expiry = TimeCurrent() + InpPendingExpiry * 3600;

   if(request.direction == TRADE_BUY)
   {
      stopPrice = request.entryPrice + offset;
      return g_trade.BuyStop(request.lotSize, stopPrice, request.symbol, sl, tp,
                             ORDER_TIME_SPECIFIED, expiry, comment);
   }
   else
   {
      stopPrice = request.entryPrice - offset;
      return g_trade.SellStop(request.lotSize, stopPrice, request.symbol, sl, tp,
                              ORDER_TIME_SPECIFIED, expiry, comment);
   }
}

//+------------------------------------------------------------------+
//| Execute Staged Entry (Pyramiding)                                 |
//+------------------------------------------------------------------+
bool ExecuteStagedEntry(ulong parentTicket, int newStage, string triggerReason)
{
   if(!InpUseStagedEntries) return false;
   if(newStage > InpMaxStages) return false;

   int parentIndex = -1;
   for(int i = 0; i < ArraySize(g_activeTrades); i++)
   {
      if(g_activeTrades[i].ticket == parentTicket)
      {
         parentIndex = i;
         break;
      }
   }

   if(parentIndex < 0) return false;

   ActiveTrade parent = g_activeTrades[parentIndex];

   double lotMult = newStage == 2 ? InpStage2_LotMult : InpStage3_LotMult;
   double newLots = NormalizeDouble(parent.originalLots * lotMult, 2);
   double minLot = SymbolInfoDouble(parent.symbol, SYMBOL_VOLUME_MIN);
   if(newLots < minLot) newLots = minLot;

   TradeRequest request;
   ZeroMemory(request);
   request.symbol = parent.symbol;
   request.direction = parent.direction;
   request.stopLoss = parent.stopLoss;
   request.lotSize = newLots;
   request.confluenceScore = parent.confluenceScore;
   request.signalSource = triggerReason;
   request.stage = newStage;

   if(parent.direction == TRADE_BUY)
      request.entryPrice = SymbolInfoDouble(parent.symbol, SYMBOL_ASK);
   else
      request.entryPrice = SymbolInfoDouble(parent.symbol, SYMBOL_BID);

   double tp1RR, tp2RR, tp3RR;
   GetDynamicRR(tp1RR, tp2RR, tp3RR, parent.confluenceScore);

   double riskDistance = MathAbs(request.entryPrice - request.stopLoss);

   if(parent.direction == TRADE_BUY)
   {
      request.takeProfit1 = request.entryPrice + (riskDistance * tp1RR);
      request.takeProfit2 = request.entryPrice + (riskDistance * tp2RR);
      request.takeProfit3 = request.entryPrice + (riskDistance * tp3RR);
   }
   else
   {
      request.takeProfit1 = request.entryPrice - (riskDistance * tp1RR);
      request.takeProfit2 = request.entryPrice - (riskDistance * tp2RR);
      request.takeProfit3 = request.entryPrice - (riskDistance * tp3RR);
   }

   request.isValid = ValidateTradeRequest(request);

   if(request.isValid)
   {
      Print("➕ Adding Stage ", newStage, " entry (", triggerReason, ")");
      return ExecuteTrade(request);
   }

   return false;
}

//+------------------------------------------------------------------+
//| Manage Positions                                                  |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = ArraySize(g_activeTrades) - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_activeTrades[i].ticket))
      {
         RemoveActiveTrade(i);
         continue;
      }

      double currentPrice = g_activeTrades[i].direction == TRADE_BUY ?
                           SymbolInfoDouble(g_activeTrades[i].symbol, SYMBOL_BID) :
                           SymbolInfoDouble(g_activeTrades[i].symbol, SYMBOL_ASK);

      if(!g_activeTrades[i].tp1Hit && InpUseMultipleTP)
      {
         if(CheckTPHit(g_activeTrades[i], currentPrice, 1))
            HandleTP1Hit(i, currentPrice);
      }

      if(g_activeTrades[i].tp1Hit && !g_activeTrades[i].tp2Hit && InpUseMultipleTP)
      {
         if(CheckTPHit(g_activeTrades[i], currentPrice, 2))
            HandleTP2Hit(i, currentPrice);
      }

      if(InpUseBreakEven && !g_activeTrades[i].breakEvenSet)
         CheckBreakEven(i, currentPrice);

      if(InpUseTrailing && g_activeTrades[i].breakEvenSet)
      {
         if(!InpPauseTrailOnNews || !g_smcContext.newsActive)
            CheckTrailingStop(i, currentPrice);
      }

      if(InpUseStagedEntries && g_activeTrades[i].stage == 1)
         CheckStagedEntryTriggers(i, currentPrice);
   }
}

//+------------------------------------------------------------------+
//| Check Staged Entry Triggers                                       |
//+------------------------------------------------------------------+
void CheckStagedEntryTriggers(int index, double currentPrice)
{
   ActiveTrade trade = g_activeTrades[index];

   int currentStages = CountPositionStages(trade.symbol, trade.direction);
   if(currentStages >= InpMaxStages) return;

   if(InpStage2_OnOTE && currentStages < 2)
   {
      if(g_smcContext.inOTE)
      {
         ExecuteStagedEntry(trade.ticket, 2, "OTE_Pullback");
      }
   }

   if(InpStage3_OnBOS && currentStages < 3 && currentStages >= 2)
   {
      if(g_smcContext.bosConfirmed)
      {
         ExecuteStagedEntry(trade.ticket, 3, "BOS_Confirm");
      }
   }
}

//+------------------------------------------------------------------+
//| Count Position Stages                                             |
//+------------------------------------------------------------------+
int CountPositionStages(string symbol, ENUM_TRADE_DIRECTION direction)
{
   int count = 0;
   for(int i = 0; i < ArraySize(g_activeTrades); i++)
   {
      if(g_activeTrades[i].symbol == symbol && g_activeTrades[i].direction == direction)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check TP Hit                                                      |
//+------------------------------------------------------------------+
bool CheckTPHit(ActiveTrade &trade, double currentPrice, int tpLevel)
{
   double tpPrice;
   switch(tpLevel)
   {
      case 1: tpPrice = trade.takeProfit1; break;
      case 2: tpPrice = trade.takeProfit2; break;
      case 3: tpPrice = trade.takeProfit3; break;
      default: return false;
   }

   if(trade.direction == TRADE_BUY)
      return currentPrice >= tpPrice;
   else
      return currentPrice <= tpPrice;
}

//+------------------------------------------------------------------+
//| Handle TP1 Hit                                                    |
//+------------------------------------------------------------------+
void HandleTP1Hit(int index, double currentPrice)
{
   ActiveTrade trade = g_activeTrades[index];

   double lotsToClose = NormalizeDouble(trade.originalLots * InpTP1_Percent / 100.0, 2);
   lotsToClose = MathMax(lotsToClose, SymbolInfoDouble(trade.symbol, SYMBOL_VOLUME_MIN));

   if(g_trade.PositionClosePartial(trade.ticket, lotsToClose))
   {
      g_activeTrades[index].tp1Hit = true;
      g_activeTrades[index].lots -= lotsToClose;
      g_execMetrics.tp1Hits++;

      Print("✓ TP1 Hit: Closed ", lotsToClose, " lots @ ", currentPrice);

      if(InpAlertOnTP)
         SendAlert("TP1 Hit", trade.symbol + " TP1 reached @ " + DoubleToString(currentPrice, (int)SymbolInfoInteger(trade.symbol, SYMBOL_DIGITS)));

      if(InpUseMultipleTP)
         g_trade.PositionModify(trade.ticket, trade.stopLoss, trade.takeProfit2);
   }
}

//+------------------------------------------------------------------+
//| Handle TP2 Hit                                                    |
//+------------------------------------------------------------------+
void HandleTP2Hit(int index, double currentPrice)
{
   ActiveTrade trade = g_activeTrades[index];

   double lotsToClose = NormalizeDouble(trade.originalLots * InpTP2_Percent / 100.0, 2);
   lotsToClose = MathMax(lotsToClose, SymbolInfoDouble(trade.symbol, SYMBOL_VOLUME_MIN));
   lotsToClose = MathMin(lotsToClose, g_activeTrades[index].lots);

   if(g_trade.PositionClosePartial(trade.ticket, lotsToClose))
   {
      g_activeTrades[index].tp2Hit = true;
      g_activeTrades[index].lots -= lotsToClose;
      g_execMetrics.tp2Hits++;

      Print("✓ TP2 Hit: Closed ", lotsToClose, " lots @ ", currentPrice);

      if(InpAlertOnTP)
         SendAlert("TP2 Hit", trade.symbol + " TP2 reached @ " + DoubleToString(currentPrice, (int)SymbolInfoInteger(trade.symbol, SYMBOL_DIGITS)));

      g_trade.PositionModify(trade.ticket, trade.stopLoss, trade.takeProfit3);
   }
}

//+------------------------------------------------------------------+
//| Check Break-Even                                                  |
//+------------------------------------------------------------------+
void CheckBreakEven(int index, double currentPrice)
{
   ActiveTrade trade = g_activeTrades[index];
   double pointValue = SymbolInfoDouble(trade.symbol, SYMBOL_POINT);
   bool shouldSetBE = false;

   switch(InpBETrigger)
   {
      case BE_AFTER_TP1:
         shouldSetBE = trade.tp1Hit;
         break;

      case BE_AT_RR_1:
         {
            double riskPoints = MathAbs(trade.entryPrice - trade.originalSL) / pointValue;
            double profitPoints;
            if(trade.direction == TRADE_BUY)
               profitPoints = (currentPrice - trade.entryPrice) / pointValue;
            else
               profitPoints = (trade.entryPrice - currentPrice) / pointValue;
            shouldSetBE = profitPoints >= riskPoints;
         }
         break;

      case BE_CUSTOM_POINTS:
         {
            double profitPoints;
            if(trade.direction == TRADE_BUY)
               profitPoints = (currentPrice - trade.entryPrice) / pointValue;
            else
               profitPoints = (trade.entryPrice - currentPrice) / pointValue;
            shouldSetBE = profitPoints >= InpBEOffset;
         }
         break;
   }

   if(shouldSetBE)
   {
      double newSL;
      if(trade.direction == TRADE_BUY)
         newSL = trade.entryPrice + (InpBEOffset * pointValue);
      else
         newSL = trade.entryPrice - (InpBEOffset * pointValue);

      if(g_trade.PositionModify(trade.ticket, newSL, PositionGetDouble(POSITION_TP)))
      {
         g_activeTrades[index].breakEvenSet = true;
         g_activeTrades[index].stopLoss = newSL;
         g_execMetrics.breakEvenHits++;

         Print("✓ Break-Even Set @ ", newSL);

         if(InpAlertOnBE)
            SendAlert("Break-Even", trade.symbol + " BE set @ " + DoubleToString(newSL, (int)SymbolInfoInteger(trade.symbol, SYMBOL_DIGITS)));
      }
   }
}

//+------------------------------------------------------------------+
//| Check Trailing Stop                                               |
//+------------------------------------------------------------------+
void CheckTrailingStop(int index, double currentPrice)
{
   ActiveTrade trade = g_activeTrades[index];
   double pointValue = SymbolInfoDouble(trade.symbol, SYMBOL_POINT);
   double newSL = 0;

   double profitPoints;
   if(trade.direction == TRADE_BUY)
      profitPoints = (currentPrice - trade.entryPrice) / pointValue;
   else
      profitPoints = (trade.entryPrice - currentPrice) / pointValue;

   double riskPoints = MathAbs(trade.entryPrice - trade.originalSL) / pointValue;
   if(profitPoints < riskPoints * InpTrailActivation)
      return;

   switch(InpTrailMode)
   {
      case TRAIL_ATR:
         {
            double atrValue = g_atrBuffer[0];
            double trailDistance = atrValue * InpTrailATRMult;
            if(trade.direction == TRADE_BUY)
               newSL = currentPrice - trailDistance;
            else
               newSL = currentPrice + trailDistance;
         }
         break;

      case TRAIL_FIXED:
         {
            double trailDistance = InpTrailFixedPoints * pointValue;
            if(trade.direction == TRADE_BUY)
               newSL = currentPrice - trailDistance;
            else
               newSL = currentPrice + trailDistance;
         }
         break;

      case TRAIL_SMC_STRUCTURE:
         newSL = GetSMCStructureTrailSL(trade);
         break;

      case TRAIL_STEP:
         newSL = GetStepTrailSL(trade, currentPrice);
         break;

      default:
         return;
   }

   if(newSL > 0)
   {
      bool shouldModify = false;

      if(trade.direction == TRADE_BUY && newSL > trade.stopLoss)
         shouldModify = true;
      else if(trade.direction == TRADE_SELL && newSL < trade.stopLoss)
         shouldModify = true;

      if(shouldModify)
      {
         newSL = NormalizeDouble(newSL, (int)SymbolInfoInteger(trade.symbol, SYMBOL_DIGITS));

         if(g_trade.PositionModify(trade.ticket, newSL, PositionGetDouble(POSITION_TP)))
         {
            g_activeTrades[index].stopLoss = newSL;
            g_activeTrades[index].trailingActive = true;
            g_execMetrics.trailingStops++;

            if(InpAlertOnTrail)
               SendAlert("Trail SL", trade.symbol + " SL moved to " + DoubleToString(newSL, (int)SymbolInfoInteger(trade.symbol, SYMBOL_DIGITS)));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get SMC Structure-Based Trail SL                                  |
//+------------------------------------------------------------------+
double GetSMCStructureTrailSL(ActiveTrade &trade)
{
   double swingPoint = 0;
   double pointValue = SymbolInfoDouble(trade.symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(trade.symbol, SYMBOL_DIGITS);

   if(trade.direction == TRADE_BUY)
   {
      double lowestLow = DBL_MAX;
      int swingBar = -1;

      for(int i = 2; i < InpStructureLookback - 2; i++)
      {
         double low = iLow(trade.symbol, PERIOD_CURRENT, i);
         double prevLow1 = iLow(trade.symbol, PERIOD_CURRENT, i + 1);
         double prevLow2 = iLow(trade.symbol, PERIOD_CURRENT, i + 2);
         double nextLow1 = iLow(trade.symbol, PERIOD_CURRENT, i - 1);
         double nextLow2 = iLow(trade.symbol, PERIOD_CURRENT, i - 2);

         if(low < prevLow1 && low < prevLow2 && low < nextLow1 && low < nextLow2)
         {
            if(low < lowestLow)
            {
               lowestLow = low;
               swingBar = i;
            }
         }
      }

      if(swingBar > 0)
      {
         double atrBuffer = g_atrBuffer[0] * 0.1;
         swingPoint = lowestLow - atrBuffer;
      }
   }
   else
   {
      double highestHigh = 0;
      int swingBar = -1;

      for(int i = 2; i < InpStructureLookback - 2; i++)
      {
         double high = iHigh(trade.symbol, PERIOD_CURRENT, i);
         double prevHigh1 = iHigh(trade.symbol, PERIOD_CURRENT, i + 1);
         double prevHigh2 = iHigh(trade.symbol, PERIOD_CURRENT, i + 2);
         double nextHigh1 = iHigh(trade.symbol, PERIOD_CURRENT, i - 1);
         double nextHigh2 = iHigh(trade.symbol, PERIOD_CURRENT, i - 2);

         if(high > prevHigh1 && high > prevHigh2 && high > nextHigh1 && high > nextHigh2)
         {
            if(high > highestHigh)
            {
               highestHigh = high;
               swingBar = i;
            }
         }
      }

      if(swingBar > 0)
      {
         double atrBuffer = g_atrBuffer[0] * 0.1;
         swingPoint = highestHigh + atrBuffer;
      }
   }

   return NormalizeDouble(swingPoint, digits);
}

//+------------------------------------------------------------------+
//| Get Step Trail SL                                                 |
//+------------------------------------------------------------------+
double GetStepTrailSL(ActiveTrade &trade, double currentPrice)
{
   double pointValue = SymbolInfoDouble(trade.symbol, SYMBOL_POINT);
   double stepSize = InpTrailFixedPoints * pointValue;

   double profitDistance;
   if(trade.direction == TRADE_BUY)
      profitDistance = currentPrice - trade.entryPrice;
   else
      profitDistance = trade.entryPrice - currentPrice;

   int steps = (int)(profitDistance / stepSize);
   if(steps < 1) return 0;

   double newSL;
   if(trade.direction == TRADE_BUY)
      newSL = trade.entryPrice + ((steps - 1) * stepSize);
   else
      newSL = trade.entryPrice - ((steps - 1) * stepSize);

   return newSL;
}

//+------------------------------------------------------------------+
//| Load Active Positions                                             |
//+------------------------------------------------------------------+
void LoadActivePositions()
{
   ArrayResize(g_activeTrades, 0);

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(g_position.SelectByIndex(i))
      {
         if(g_position.Magic() != InpMagicNumber) continue;

         ActiveTrade trade;
         ZeroMemory(trade);

         trade.ticket = g_position.Ticket();
         trade.symbol = g_position.Symbol();
         trade.direction = g_position.PositionType() == POSITION_TYPE_BUY ? TRADE_BUY : TRADE_SELL;
         trade.entryPrice = g_position.PriceOpen();
         trade.stopLoss = g_position.StopLoss();
         trade.originalSL = trade.stopLoss;
         trade.lots = g_position.Volume();
         trade.originalLots = trade.lots;
         trade.openTime = g_position.Time();
         trade.comment = g_position.Comment();

         int stagePos = StringFind(trade.comment, "_S");
         if(stagePos >= 0)
            trade.stage = (int)StringToInteger(StringSubstr(trade.comment, stagePos + 2, 1));
         else
            trade.stage = 1;

         int confPos = StringFind(trade.comment, "_C");
         if(confPos >= 0)
            trade.confluenceScore = (int)StringToInteger(StringSubstr(trade.comment, confPos + 2, 1));
         else
            trade.confluenceScore = 6;

         double tp1RR, tp2RR, tp3RR;
         GetDynamicRR(tp1RR, tp2RR, tp3RR, trade.confluenceScore);

         double riskDistance = MathAbs(trade.entryPrice - trade.stopLoss);

         if(trade.direction == TRADE_BUY)
         {
            trade.takeProfit1 = trade.entryPrice + (riskDistance * tp1RR);
            trade.takeProfit2 = trade.entryPrice + (riskDistance * tp2RR);
            trade.takeProfit3 = trade.entryPrice + (riskDistance * tp3RR);
         }
         else
         {
            trade.takeProfit1 = trade.entryPrice - (riskDistance * tp1RR);
            trade.takeProfit2 = trade.entryPrice - (riskDistance * tp2RR);
            trade.takeProfit3 = trade.entryPrice - (riskDistance * tp3RR);
         }

         double tickValue = SymbolInfoDouble(trade.symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize = SymbolInfoDouble(trade.symbol, SYMBOL_TRADE_TICK_SIZE);
         trade.riskAmount = (riskDistance / tickSize) * tickValue * trade.lots;

         trade.tp1Hit = false;
         trade.tp2Hit = false;
         trade.breakEvenSet = (trade.stopLoss >= trade.entryPrice && trade.direction == TRADE_BUY) ||
                              (trade.stopLoss <= trade.entryPrice && trade.direction == TRADE_SELL);
         trade.trailingActive = false;

         int size = ArraySize(g_activeTrades);
         ArrayResize(g_activeTrades, size + 1);
         g_activeTrades[size] = trade;
      }
   }

   g_positionsLoaded = true;
}

//+------------------------------------------------------------------+
//| Remove Active Trade                                               |
//+------------------------------------------------------------------+
void RemoveActiveTrade(int index)
{
   int size = ArraySize(g_activeTrades);
   for(int i = index; i < size - 1; i++)
      g_activeTrades[i] = g_activeTrades[i + 1];
   ArrayResize(g_activeTrades, size - 1);
}

//+------------------------------------------------------------------+
//| Check Position Limits                                             |
//+------------------------------------------------------------------+
bool CheckPositionLimits(string symbol)
{
   int totalPositions = 0;
   int symbolPositions = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(g_position.SelectByIndex(i))
      {
         if(g_position.Magic() == InpMagicNumber)
         {
            totalPositions++;
            if(g_position.Symbol() == symbol)
               symbolPositions++;
         }
      }
   }

   if(totalPositions >= InpMaxPositions)
   {
      Print("Max total positions reached: ", totalPositions);
      return false;
   }

   if(symbolPositions >= InpMaxPositionsPerSymbol)
   {
      Print("Max positions for ", symbol, " reached: ", symbolPositions);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Close All Positions                                               |
//+------------------------------------------------------------------+
void CloseAllPositions(string symbol = "")
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(g_position.SelectByIndex(i))
      {
         if(g_position.Magic() != InpMagicNumber) continue;
         if(symbol != "" && g_position.Symbol() != symbol) continue;
         g_trade.PositionClose(g_position.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
//| Delete All Pending Orders                                         |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders(string symbol = "")
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(g_order.SelectByIndex(i))
      {
         if(g_order.Magic() != InpMagicNumber) continue;
         if(symbol != "" && g_order.Symbol() != symbol) continue;
         g_trade.OrderDelete(g_order.Ticket());
      }
   }
}

//+------------------------------------------------------------------+
//| Create Trade Request                                              |
//+------------------------------------------------------------------+
TradeRequest CreateTradeRequest(string symbol, ENUM_TRADE_DIRECTION direction,
                                 double entryPrice, double stopLoss,
                                 double lotSize, int confluenceScore,
                                 string signalSource, int stage = 1)
{
   TradeRequest request;
   ZeroMemory(request);

   request.symbol = symbol;
   request.direction = direction;
   request.entryPrice = entryPrice;
   request.stopLoss = stopLoss;
   request.lotSize = lotSize;
   request.confluenceScore = confluenceScore;
   request.signalSource = signalSource;
   request.stage = stage;

   double tp1RR, tp2RR, tp3RR;
   GetDynamicRR(tp1RR, tp2RR, tp3RR, confluenceScore);

   double riskDistance = MathAbs(entryPrice - stopLoss);

   if(direction == TRADE_BUY)
   {
      request.takeProfit1 = entryPrice + (riskDistance * tp1RR);
      request.takeProfit2 = entryPrice + (riskDistance * tp2RR);
      request.takeProfit3 = entryPrice + (riskDistance * tp3RR);
   }
   else
   {
      request.takeProfit1 = entryPrice - (riskDistance * tp1RR);
      request.takeProfit2 = entryPrice - (riskDistance * tp2RR);
      request.takeProfit3 = entryPrice - (riskDistance * tp3RR);
   }

   request.isValid = ValidateTradeRequest(request);

   return request;
}

//+------------------------------------------------------------------+
//| Validate Trade Request                                            |
//+------------------------------------------------------------------+
bool ValidateTradeRequest(TradeRequest &request)
{
   if(!SymbolSelect(request.symbol, true))
   {
      Print("Invalid symbol: ", request.symbol);
      return false;
   }

   double minLot = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_STEP);

   if(request.lotSize < minLot || request.lotSize > maxLot)
   {
      Print("Invalid lot size: ", request.lotSize, " (Min: ", minLot, ", Max: ", maxLot, ")");
      return false;
   }

   request.lotSize = NormalizeDouble(MathFloor(request.lotSize / lotStep) * lotStep, 2);

   double pointValue = SymbolInfoDouble(request.symbol, SYMBOL_POINT);
   int stopLevel = (int)SymbolInfoInteger(request.symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * pointValue;

   double slDistance = MathAbs(request.entryPrice - request.stopLoss);
   if(slDistance < minDistance)
   {
      Print("SL too close. Min distance: ", minDistance);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Send Alert                                                        |
//+------------------------------------------------------------------+
void SendAlert(string title, string message)
{
   Alert(title, ": ", message);

   if(InpUsePushNotify)
      SendNotification(title + ": " + message);
}

//+------------------------------------------------------------------+
//| Update SMC Context                                                |
//+------------------------------------------------------------------+
void UpdateSMCContext(bool newsActive, int confluenceScore, double lastBOS,
                      double lastCHoCH, bool inOTE, bool bosConfirmed)
{
   g_smcContext.newsActive = newsActive;
   g_smcContext.confluenceScore = confluenceScore;
   g_smcContext.lastBOS = lastBOS;
   g_smcContext.lastCHoCH = lastCHoCH;
   g_smcContext.inOTE = inOTE;
   g_smcContext.bosConfirmed = bosConfirmed;
}

//+------------------------------------------------------------------+
//| Create Panel                                                      |
//+------------------------------------------------------------------+
void CreateExecutionPanel()
{
   int width = 280;
   int height = 320;

   ObjectCreate(0, g_panelName + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_YDISTANCE, InpPanelY);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_BGCOLOR, InpPanelBg);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_BACK, false);

   CreateLabel(g_panelName + "_Title", "TRADE EXECUTION v1.01 (SMC)", InpPanelX + 10, InpPanelY + 5, clrGold, 10, true);
   CreateLabel(g_panelName + "_Line1", "─────────────────────────", InpPanelX + 10, InpPanelY + 22, clrGray, 8, false);

   int y = InpPanelY + 40;
   CreateLabel(g_panelName + "_L1", "Active Positions:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V1", "0", InpPanelX + 170, y, clrLime, 9, true);

   y += 18;
   CreateLabel(g_panelName + "_L2", "Pending Orders:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V2", "0", InpPanelX + 170, y, clrYellow, 9, true);

   y += 18;
   CreateLabel(g_panelName + "_L3", "Staged Entries:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V3", "0", InpPanelX + 170, y, clrCyan, 9, true);

   y += 22;
   CreateLabel(g_panelName + "_Line2", "─────────────────────────", InpPanelX + 10, y, clrGray, 8, false);

   y += 18;
   CreateLabel(g_panelName + "_L4", "TP1 Hits:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V4", "0", InpPanelX + 170, y, clrLime, 9, true);

   y += 18;
   CreateLabel(g_panelName + "_L5", "TP2 Hits:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V5", "0", InpPanelX + 170, y, clrLime, 9, true);

   y += 18;
   CreateLabel(g_panelName + "_L6", "Break-Even Sets:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V6", "0", InpPanelX + 170, y, clrCyan, 9, true);

   y += 18;
   CreateLabel(g_panelName + "_L7", "Trail Adjustments:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V7", "0", InpPanelX + 170, y, clrCyan, 9, true);

   y += 22;
   CreateLabel(g_panelName + "_Line3", "─────────────────────────", InpPanelX + 10, y, clrGray, 8, false);

   y += 18;
   CreateLabel(g_panelName + "_L8", "Total Exposure:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V8", "0.0%", InpPanelX + 170, y, clrOrange, 9, true);

   y += 18;
   CreateLabel(g_panelName + "_L9", "USD Exposure:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V9", "0.0%", InpPanelX + 170, y, clrSilver, 9, false);

   y += 18;
   CreateLabel(g_panelName + "_L10", "Gold Exposure:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V10", "0.0%", InpPanelX + 170, y, clrGold, 9, false);

   y += 22;
   CreateLabel(g_panelName + "_Line4", "─────────────────────────", InpPanelX + 10, y, clrGray, 8, false);

   y += 18;
   CreateLabel(g_panelName + "_L11", "Success Rate:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V11", "N/A", InpPanelX + 170, y, clrGold, 9, true);

   y += 18;
   CreateLabel(g_panelName + "_L12", "Avg Slippage:", InpPanelX + 10, y, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V12", "0 pts", InpPanelX + 170, y, clrSilver, 9, false);
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
   int positions = 0;
   int pendingOrders = 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(g_position.SelectByIndex(i) && g_position.Magic() == InpMagicNumber)
         positions++;
   }

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(g_order.SelectByIndex(i) && g_order.Magic() == InpMagicNumber)
         pendingOrders++;
   }

   ObjectSetString(0, g_panelName + "_V1", OBJPROP_TEXT, IntegerToString(positions));
   ObjectSetString(0, g_panelName + "_V2", OBJPROP_TEXT, IntegerToString(pendingOrders));
   ObjectSetString(0, g_panelName + "_V3", OBJPROP_TEXT, IntegerToString(g_execMetrics.stagedEntries));
   ObjectSetString(0, g_panelName + "_V4", OBJPROP_TEXT, IntegerToString(g_execMetrics.tp1Hits));
   ObjectSetString(0, g_panelName + "_V5", OBJPROP_TEXT, IntegerToString(g_execMetrics.tp2Hits));
   ObjectSetString(0, g_panelName + "_V6", OBJPROP_TEXT, IntegerToString(g_execMetrics.breakEvenHits));
   ObjectSetString(0, g_panelName + "_V7", OBJPROP_TEXT, IntegerToString(g_execMetrics.trailingStops));

   ObjectSetString(0, g_panelName + "_V8", OBJPROP_TEXT, DoubleToString(g_exposure.totalExposure, 1) + "%");
   ObjectSetString(0, g_panelName + "_V9", OBJPROP_TEXT, DoubleToString(g_exposure.usdExposure, 1) + "%");
   ObjectSetString(0, g_panelName + "_V10", OBJPROP_TEXT, DoubleToString(g_exposure.goldExposure, 1) + "%");

   color expColor = g_exposure.totalExposure > InpMaxTotalExposure * 0.8 ? clrRed :
                    g_exposure.totalExposure > InpMaxTotalExposure * 0.5 ? clrOrange : clrLime;
   ObjectSetInteger(0, g_panelName + "_V8", OBJPROP_COLOR, expColor);

   string successRate = "N/A";
   if(g_execMetrics.totalOrders > 0)
   {
      double rate = (double)g_execMetrics.successfulOrders / g_execMetrics.totalOrders * 100;
      successRate = DoubleToString(rate, 1) + "%";
   }
   ObjectSetString(0, g_panelName + "_V11", OBJPROP_TEXT, successRate);
   ObjectSetString(0, g_panelName + "_V12", OBJPROP_TEXT, DoubleToString(g_execMetrics.avgSlippage, 1) + " pts");
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
   ENUM_INSTRUMENT_PROFILE profile = GetInstrumentProfile();
   string profileStr = profile == PROFILE_GOLD ? "GOLD" :
                       profile == PROFILE_CRYPTO ? "CRYPTO" :
                       profile == PROFILE_INDEX ? "INDEX" : "FOREX";

   double tp1RR, tp2RR, tp3RR;
   GetDynamicRR(tp1RR, tp2RR, tp3RR, 6);

   Print("");
   Print("=================================================");
   Print("     SWING TRADER PRO - SECTION 13 (v1.01)       ");
   Print("     SMC TRADE EXECUTION                          ");
   Print("=================================================");
   Print("Symbol: ", _Symbol, " (", profileStr, ")");
   Print("Magic Number: ", InpMagicNumber);
   Print("-------------------------------------------------");
   Print("DYNAMIC R:R (", profileStr, "):");
   Print("  TP1: ", DoubleToString(tp1RR, 2), "R (Close ", InpTP1_Percent, "%)");
   Print("  TP2: ", DoubleToString(tp2RR, 2), "R (Close ", InpTP2_Percent, "%)");
   Print("  TP3: ", DoubleToString(tp3RR, 2), "R (Close remaining)");
   Print("-------------------------------------------------");
   Print("SMC FEATURES:");
   Print("  Confluence TP Adjust: ", InpUseConfluenceTP ? "Enabled" : "Disabled");
   Print("  Staged Entries: ", InpUseStagedEntries ? "Enabled (Max " + IntegerToString(InpMaxStages) + ")" : "Disabled");
   Print("  SMC Structure Trail: ", InpTrailMode == TRAIL_SMC_STRUCTURE ? "Enabled" : "Disabled");
   Print("  News Trail Pause: ", InpPauseTrailOnNews ? "Enabled" : "Disabled");
   Print("-------------------------------------------------");
   Print("EXPOSURE LIMITS:");
   Print("  Total: ", InpMaxTotalExposure, "%");
   Print("  USD: ", InpMaxUSDExposure, "% | EUR: ", InpMaxEURExposure, "%");
   Print("  Gold: ", InpMaxGoldExposure, "%");
   Print("-------------------------------------------------");
   Print("Break-Even: ", InpUseBreakEven ? "Enabled" : "Disabled");
   Print("Trailing: ", InpUseTrailing ? "Enabled" : "Disabled");
   Print("Spread Check: ", InpMaxSpreadATR > 0 ? DoubleToString(InpMaxSpreadATR * 100, 1) + "% ATR" : "Disabled");
   Print("-------------------------------------------------");
   Print("Active Positions: ", ArraySize(g_activeTrades));
   Print("Current Exposure: ", DoubleToString(g_exposure.totalExposure, 2), "%");
   Print("=================================================");
   Print("");
}

//+------------------------------------------------------------------+
//| Public API Functions                                              |
//+------------------------------------------------------------------+

bool ExecuteBuy(double stopLoss, double lotSize, int confluenceScore = 6, string source = "SMC")
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   TradeRequest request = CreateTradeRequest(_Symbol, TRADE_BUY, ask, stopLoss,
                                              lotSize, confluenceScore, source, 1);
   return ExecuteTrade(request);
}

bool ExecuteSell(double stopLoss, double lotSize, int confluenceScore = 6, string source = "SMC")
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   TradeRequest request = CreateTradeRequest(_Symbol, TRADE_SELL, bid, stopLoss,
                                              lotSize, confluenceScore, source, 1);
   return ExecuteTrade(request);
}

int GetActivePositions() { return ArraySize(g_activeTrades); }
int GetTP1Hits() { return g_execMetrics.tp1Hits; }
int GetTP2Hits() { return g_execMetrics.tp2Hits; }
int GetBreakEvenCount() { return g_execMetrics.breakEvenHits; }
int GetStagedEntries() { return g_execMetrics.stagedEntries; }
double GetAvgSlippage() { return g_execMetrics.avgSlippage; }
double GetTotalExposure() { return g_exposure.totalExposure; }
double GetSuccessRate()
{
   if(g_execMetrics.totalOrders == 0) return 0;
   return (double)g_execMetrics.successfulOrders / g_execMetrics.totalOrders * 100;
}

bool CanExecute()
{
   return g_initialized && CheckPositionLimits(_Symbol) && CheckSpread(_Symbol);
}

//+------------------------------------------------------------------+
