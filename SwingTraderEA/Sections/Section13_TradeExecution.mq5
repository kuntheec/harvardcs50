//+------------------------------------------------------------------+
//|                                    Section13_TradeExecution.mq5   |
//|                         SwingTrader Pro EA - Trade Execution      |
//|                                 Version 1.00 - SMC Trade Manager  |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== SECTION 13: TRADE EXECUTION v1.00 ==="
input string   InpEAComment           = "SwingTraderPro";  // EA Trade Comment
input ulong    InpMagicNumber         = 123456;            // Magic Number
input int      InpMaxSlippage         = 30;                // Max Slippage (points)
input int      InpMaxRetries          = 3;                 // Max Order Retries

input group "=== Entry Mode ==="
input ENUM_ENTRY_MODE InpEntryMode    = ENTRY_MARKET;      // Entry Mode
input int      InpPendingExpiry       = 24;                // Pending Order Expiry (hours)
input double   InpLimitOffset         = 0.0;               // Limit Order Offset (ATR %)

input group "=== Take Profit Levels ==="
input bool     InpUseMultipleTP       = true;              // Use Multiple TP Levels
input double   InpTP1_RR              = 1.5;               // TP1 Risk:Reward Ratio
input double   InpTP2_RR              = 2.5;               // TP2 Risk:Reward Ratio
input double   InpTP3_RR              = 4.0;               // TP3 Risk:Reward Ratio (Final)
input double   InpTP1_Percent         = 40.0;              // TP1 Close Percent
input double   InpTP2_Percent         = 30.0;              // TP2 Close Percent
// Remaining 30% runs to TP3

input group "=== Break-Even Settings ==="
input bool     InpUseBreakEven        = true;              // Enable Break-Even
input ENUM_BE_TRIGGER InpBETrigger    = BE_AFTER_TP1;      // Break-Even Trigger
input double   InpBEOffset            = 5.0;               // BE Offset (points profit)

input group "=== Trailing Stop ==="
input bool     InpUseTrailing         = true;              // Enable Trailing Stop
input ENUM_TRAIL_MODE InpTrailMode    = TRAIL_ATR;         // Trailing Mode
input double   InpTrailATRMult        = 1.5;               // ATR Multiplier for Trail
input double   InpTrailFixedPoints    = 500;               // Fixed Trail (points)
input double   InpTrailActivation     = 1.0;               // Activation (RR ratio)
input bool     InpTrailBehindStructure= true;              // Trail Behind Swing Points

input group "=== Position Limits ==="
input int      InpMaxPositions        = 3;                 // Max Open Positions
input int      InpMaxPositionsPerSymbol = 1;               // Max Positions Per Symbol
input int      InpMaxPendingOrders    = 5;                 // Max Pending Orders

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;              // Show Execution Panel
input int      InpPanelX              = 10;                // Panel X Position
input int      InpPanelY              = 400;               // Panel Y Position
input color    InpPanelBg             = clrMidnightBlue;   // Panel Background
input color    InpBuyColor            = clrLime;           // Buy Color
input color    InpSellColor           = clrRed;            // Sell Color

//+------------------------------------------------------------------+
//| Enumerations                                                      |
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
   TRAIL_STRUCTURE,       // Behind Structure
   TRAIL_STEP             // Step Trail
};

enum ENUM_TRADE_DIRECTION
{
   TRADE_BUY,
   TRADE_SELL
};

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
   bool              tp1Hit;
   bool              tp2Hit;
   bool              breakEvenSet;
   bool              trailingActive;
   datetime          openTime;
   string            comment;
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
   double            avgSlippage;
   datetime          lastOrderTime;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CTrade            g_trade;
CPositionInfo     g_position;
COrderInfo        g_order;

ActiveTrade       g_activeTrades[];
ExecutionMetrics  g_execMetrics;
int               g_atrHandle;
double            g_atrBuffer[];

string            g_panelName = "SEC13_ExecPanel";
bool              g_initialized = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpMaxSlippage);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);
   g_trade.SetAsyncMode(false);

   // Initialize ATR for trailing
   g_atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("Failed to create ATR indicator");
      return INIT_FAILED;
   }
   ArraySetAsSeries(g_atrBuffer, true);

   // Initialize metrics
   ZeroMemory(g_execMetrics);

   // Load existing positions
   LoadActivePositions();

   // Create panel
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
   Print("Trade Execution EA v1.00 Deinitialized");
   Print("Total Orders: ", g_execMetrics.totalOrders);
   Print("Success Rate: ", g_execMetrics.totalOrders > 0 ?
         DoubleToString((double)g_execMetrics.successfulOrders/g_execMetrics.totalOrders*100, 1) + "%" : "N/A");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_initialized) return;

   // Update ATR
   CopyBuffer(g_atrHandle, 0, 0, 3, g_atrBuffer);

   // Manage existing positions
   ManagePositions();

   // Update panel
   if(InpShowPanel)
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
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
      {
         // New position opened or closed
         LoadActivePositions();
      }
   }
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

   // Check position limits
   if(!CheckPositionLimits(request.symbol))
   {
      Print("Position limits exceeded for ", request.symbol);
      return false;
   }

   g_execMetrics.totalOrders++;

   bool success = false;
   double sl = request.stopLoss;
   double tp = InpUseMultipleTP ? request.takeProfit1 : request.takeProfit3;

   string comment = InpEAComment + "_" + request.signalSource +
                    "_C" + IntegerToString(request.confluenceScore);

   // Execute based on entry mode
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

      // Store TP levels for management
      StoreTPLevels(request);

      Print("✓ Trade executed: ", request.direction == TRADE_BUY ? "BUY" : "SELL",
            " ", request.symbol, " @ ", request.entryPrice,
            " SL: ", sl, " TP1: ", request.takeProfit1);
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
      // Calculate slippage
      double executed = g_trade.ResultPrice();
      double requested = request.direction == TRADE_BUY ?
                        SymbolInfoDouble(request.symbol, SYMBOL_ASK) :
                        SymbolInfoDouble(request.symbol, SYMBOL_BID);
      double slippage = MathAbs(executed - requested) / _Point;

      // Update average slippage
      int totalSuccess = g_execMetrics.successfulOrders;
      g_execMetrics.avgSlippage = ((g_execMetrics.avgSlippage * totalSuccess) + slippage) / (totalSuccess + 1);
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
      limitPrice = request.entryPrice - offset;  // Below current for buy limit
      return g_trade.BuyLimit(request.lotSize, limitPrice, request.symbol, sl, tp,
                              ORDER_TIME_SPECIFIED, expiry, comment);
   }
   else
   {
      limitPrice = request.entryPrice + offset;  // Above current for sell limit
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
      stopPrice = request.entryPrice + offset;  // Above current for buy stop
      return g_trade.BuyStop(request.lotSize, stopPrice, request.symbol, sl, tp,
                             ORDER_TIME_SPECIFIED, expiry, comment);
   }
   else
   {
      stopPrice = request.entryPrice - offset;  // Below current for sell stop
      return g_trade.SellStop(request.lotSize, stopPrice, request.symbol, sl, tp,
                              ORDER_TIME_SPECIFIED, expiry, comment);
   }
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
         // Position closed - remove from array
         RemoveActiveTrade(i);
         continue;
      }

      double currentPrice = g_activeTrades[i].direction == TRADE_BUY ?
                           SymbolInfoDouble(g_activeTrades[i].symbol, SYMBOL_BID) :
                           SymbolInfoDouble(g_activeTrades[i].symbol, SYMBOL_ASK);

      // Check TP1
      if(!g_activeTrades[i].tp1Hit && InpUseMultipleTP)
      {
         if(CheckTPHit(g_activeTrades[i], currentPrice, 1))
         {
            HandleTP1Hit(i, currentPrice);
         }
      }

      // Check TP2
      if(g_activeTrades[i].tp1Hit && !g_activeTrades[i].tp2Hit && InpUseMultipleTP)
      {
         if(CheckTPHit(g_activeTrades[i], currentPrice, 2))
         {
            HandleTP2Hit(i, currentPrice);
         }
      }

      // Check Break-Even
      if(InpUseBreakEven && !g_activeTrades[i].breakEvenSet)
      {
         CheckBreakEven(i, currentPrice);
      }

      // Check Trailing Stop
      if(InpUseTrailing && g_activeTrades[i].breakEvenSet)
      {
         CheckTrailingStop(i, currentPrice);
      }
   }
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

   // Calculate lots to close
   double lotsToClose = NormalizeDouble(trade.originalLots * InpTP1_Percent / 100.0, 2);
   lotsToClose = MathMax(lotsToClose, SymbolInfoDouble(trade.symbol, SYMBOL_VOLUME_MIN));

   // Partial close
   if(g_trade.PositionClosePartial(trade.ticket, lotsToClose))
   {
      g_activeTrades[index].tp1Hit = true;
      g_activeTrades[index].lots -= lotsToClose;
      g_execMetrics.tp1Hits++;

      Print("✓ TP1 Hit: Closed ", lotsToClose, " lots @ ", currentPrice);

      // Modify TP to TP2
      if(InpUseMultipleTP)
      {
         g_trade.PositionModify(trade.ticket, trade.stopLoss, trade.takeProfit2);
      }
   }
}

//+------------------------------------------------------------------+
//| Handle TP2 Hit                                                    |
//+------------------------------------------------------------------+
void HandleTP2Hit(int index, double currentPrice)
{
   ActiveTrade trade = g_activeTrades[index];

   // Calculate lots to close
   double lotsToClose = NormalizeDouble(trade.originalLots * InpTP2_Percent / 100.0, 2);
   lotsToClose = MathMax(lotsToClose, SymbolInfoDouble(trade.symbol, SYMBOL_VOLUME_MIN));
   lotsToClose = MathMin(lotsToClose, g_activeTrades[index].lots);

   // Partial close
   if(g_trade.PositionClosePartial(trade.ticket, lotsToClose))
   {
      g_activeTrades[index].tp2Hit = true;
      g_activeTrades[index].lots -= lotsToClose;
      g_execMetrics.tp2Hits++;

      Print("✓ TP2 Hit: Closed ", lotsToClose, " lots @ ", currentPrice);

      // Modify TP to TP3 (final)
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

   // Check if trailing should be active
   double profitPoints;
   if(trade.direction == TRADE_BUY)
      profitPoints = (currentPrice - trade.entryPrice) / pointValue;
   else
      profitPoints = (trade.entryPrice - currentPrice) / pointValue;

   double riskPoints = MathAbs(trade.entryPrice - trade.originalSL) / pointValue;

   if(profitPoints < riskPoints * InpTrailActivation)
      return;  // Not yet in profit enough to trail

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

      case TRAIL_STRUCTURE:
         newSL = GetStructureTrailSL(trade);
         break;

      case TRAIL_STEP:
         newSL = GetStepTrailSL(trade, currentPrice);
         break;

      default:
         return;
   }

   // Only move SL in profit direction
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

            Print("✓ Trailing SL moved to ", newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get Structure-Based Trail SL                                      |
//+------------------------------------------------------------------+
double GetStructureTrailSL(ActiveTrade &trade)
{
   double swingPoint = 0;
   int lookback = 20;
   double pointValue = SymbolInfoDouble(trade.symbol, SYMBOL_POINT);

   if(trade.direction == TRADE_BUY)
   {
      // Find recent swing low
      double lowestLow = DBL_MAX;
      for(int i = 1; i <= lookback; i++)
      {
         double low = iLow(trade.symbol, PERIOD_CURRENT, i);
         if(low < lowestLow)
            lowestLow = low;
      }
      swingPoint = lowestLow - (10 * pointValue);  // Buffer below swing
   }
   else
   {
      // Find recent swing high
      double highestHigh = 0;
      for(int i = 1; i <= lookback; i++)
      {
         double high = iHigh(trade.symbol, PERIOD_CURRENT, i);
         if(high > highestHigh)
            highestHigh = high;
      }
      swingPoint = highestHigh + (10 * pointValue);  // Buffer above swing
   }

   return swingPoint;
}

//+------------------------------------------------------------------+
//| Get Step Trail SL                                                 |
//+------------------------------------------------------------------+
double GetStepTrailSL(ActiveTrade &trade, double currentPrice)
{
   double pointValue = SymbolInfoDouble(trade.symbol, SYMBOL_POINT);
   double stepSize = InpTrailFixedPoints * pointValue;
   double riskDistance = MathAbs(trade.entryPrice - trade.originalSL);

   double profitDistance;
   if(trade.direction == TRADE_BUY)
      profitDistance = currentPrice - trade.entryPrice;
   else
      profitDistance = trade.entryPrice - currentPrice;

   // Calculate how many steps we've moved
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
//| Store TP Levels for Position                                      |
//+------------------------------------------------------------------+
void StoreTPLevels(TradeRequest &request)
{
   // Refresh position list
   LoadActivePositions();
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

         // Calculate TP levels based on entry and SL
         double riskDistance = MathAbs(trade.entryPrice - trade.stopLoss);

         if(trade.direction == TRADE_BUY)
         {
            trade.takeProfit1 = trade.entryPrice + (riskDistance * InpTP1_RR);
            trade.takeProfit2 = trade.entryPrice + (riskDistance * InpTP2_RR);
            trade.takeProfit3 = trade.entryPrice + (riskDistance * InpTP3_RR);
         }
         else
         {
            trade.takeProfit1 = trade.entryPrice - (riskDistance * InpTP1_RR);
            trade.takeProfit2 = trade.entryPrice - (riskDistance * InpTP2_RR);
            trade.takeProfit3 = trade.entryPrice - (riskDistance * InpTP3_RR);
         }

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
}

//+------------------------------------------------------------------+
//| Remove Active Trade                                               |
//+------------------------------------------------------------------+
void RemoveActiveTrade(int index)
{
   int size = ArraySize(g_activeTrades);
   for(int i = index; i < size - 1; i++)
   {
      g_activeTrades[i] = g_activeTrades[i + 1];
   }
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
                                 string signalSource)
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

   // Calculate TP levels
   double riskDistance = MathAbs(entryPrice - stopLoss);

   if(direction == TRADE_BUY)
   {
      request.takeProfit1 = entryPrice + (riskDistance * InpTP1_RR);
      request.takeProfit2 = entryPrice + (riskDistance * InpTP2_RR);
      request.takeProfit3 = entryPrice + (riskDistance * InpTP3_RR);
   }
   else
   {
      request.takeProfit1 = entryPrice - (riskDistance * InpTP1_RR);
      request.takeProfit2 = entryPrice - (riskDistance * InpTP2_RR);
      request.takeProfit3 = entryPrice - (riskDistance * InpTP3_RR);
   }

   request.isValid = ValidateTradeRequest(request);

   return request;
}

//+------------------------------------------------------------------+
//| Validate Trade Request                                            |
//+------------------------------------------------------------------+
bool ValidateTradeRequest(TradeRequest &request)
{
   // Check symbol
   if(!SymbolSelect(request.symbol, true))
   {
      Print("Invalid symbol: ", request.symbol);
      return false;
   }

   // Check lot size
   double minLot = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(request.symbol, SYMBOL_VOLUME_STEP);

   if(request.lotSize < minLot || request.lotSize > maxLot)
   {
      Print("Invalid lot size: ", request.lotSize, " (Min: ", minLot, ", Max: ", maxLot, ")");
      return false;
   }

   // Normalize lot size
   request.lotSize = NormalizeDouble(MathFloor(request.lotSize / lotStep) * lotStep, 2);

   // Check SL/TP distances
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
//| Create Panel                                                      |
//+------------------------------------------------------------------+
void CreateExecutionPanel()
{
   int width = 280;
   int height = 250;

   ObjectCreate(0, g_panelName + "_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_YDISTANCE, InpPanelY);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_BGCOLOR, InpPanelBg);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, g_panelName + "_BG", OBJPROP_BACK, false);

   CreateLabel(g_panelName + "_Title", "TRADE EXECUTION v1.00", InpPanelX + 10, InpPanelY + 5, clrGold, 10, true);
   CreateLabel(g_panelName + "_Line1", "─────────────────────────", InpPanelX + 10, InpPanelY + 22, clrGray, 8, false);

   CreateLabel(g_panelName + "_L1", "Active Positions:", InpPanelX + 10, InpPanelY + 40, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V1", "0", InpPanelX + 150, InpPanelY + 40, clrLime, 9, true);

   CreateLabel(g_panelName + "_L2", "Pending Orders:", InpPanelX + 10, InpPanelY + 60, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V2", "0", InpPanelX + 150, InpPanelY + 60, clrYellow, 9, true);

   CreateLabel(g_panelName + "_L3", "TP1 Hits:", InpPanelX + 10, InpPanelY + 80, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V3", "0", InpPanelX + 150, InpPanelY + 80, clrLime, 9, true);

   CreateLabel(g_panelName + "_L4", "TP2 Hits:", InpPanelX + 10, InpPanelY + 100, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V4", "0", InpPanelX + 150, InpPanelY + 100, clrLime, 9, true);

   CreateLabel(g_panelName + "_L5", "Break-Even Sets:", InpPanelX + 10, InpPanelY + 120, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V5", "0", InpPanelX + 150, InpPanelY + 120, clrCyan, 9, true);

   CreateLabel(g_panelName + "_L6", "Trail Adjustments:", InpPanelX + 10, InpPanelY + 140, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V6", "0", InpPanelX + 150, InpPanelY + 140, clrCyan, 9, true);

   CreateLabel(g_panelName + "_Line2", "─────────────────────────", InpPanelX + 10, InpPanelY + 158, clrGray, 8, false);

   CreateLabel(g_panelName + "_L7", "Success Rate:", InpPanelX + 10, InpPanelY + 175, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V7", "N/A", InpPanelX + 150, InpPanelY + 175, clrGold, 9, true);

   CreateLabel(g_panelName + "_L8", "Avg Slippage:", InpPanelX + 10, InpPanelY + 195, clrWhite, 9, false);
   CreateLabel(g_panelName + "_V8", "0 pts", InpPanelX + 150, InpPanelY + 195, clrSilver, 9, true);

   CreateLabel(g_panelName + "_L9", "Entry Mode:", InpPanelX + 10, InpPanelY + 215, clrWhite, 9, false);
   string modeStr = InpEntryMode == ENTRY_MARKET ? "MARKET" :
                    InpEntryMode == ENTRY_LIMIT ? "LIMIT" : "STOP";
   CreateLabel(g_panelName + "_V9", modeStr, InpPanelX + 150, InpPanelY + 215, clrOrange, 9, true);
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
   // Count positions and orders
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
   ObjectSetString(0, g_panelName + "_V3", OBJPROP_TEXT, IntegerToString(g_execMetrics.tp1Hits));
   ObjectSetString(0, g_panelName + "_V4", OBJPROP_TEXT, IntegerToString(g_execMetrics.tp2Hits));
   ObjectSetString(0, g_panelName + "_V5", OBJPROP_TEXT, IntegerToString(g_execMetrics.breakEvenHits));
   ObjectSetString(0, g_panelName + "_V6", OBJPROP_TEXT, IntegerToString(g_execMetrics.trailingStops));

   // Success rate
   string successRate = "N/A";
   if(g_execMetrics.totalOrders > 0)
   {
      double rate = (double)g_execMetrics.successfulOrders / g_execMetrics.totalOrders * 100;
      successRate = DoubleToString(rate, 1) + "%";
   }
   ObjectSetString(0, g_panelName + "_V7", OBJPROP_TEXT, successRate);

   // Average slippage
   ObjectSetString(0, g_panelName + "_V8", OBJPROP_TEXT, DoubleToString(g_execMetrics.avgSlippage, 1) + " pts");
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
   Print("=================================================");
   Print("     SWING TRADER PRO - SECTION 13 (v1.00)       ");
   Print("     SMC TRADE EXECUTION                          ");
   Print("=================================================");
   Print("Symbol: ", _Symbol);
   Print("Magic Number: ", InpMagicNumber);
   Print("-------------------------------------------------");
   Print("ENTRY SETTINGS:");
   Print("  Mode: ", InpEntryMode == ENTRY_MARKET ? "MARKET" :
                     InpEntryMode == ENTRY_LIMIT ? "LIMIT" : "STOP");
   Print("  Max Slippage: ", InpMaxSlippage, " points");
   Print("  Max Retries: ", InpMaxRetries);
   Print("-------------------------------------------------");
   Print("TAKE PROFIT LEVELS:");
   Print("  TP1: ", InpTP1_RR, "R (Close ", InpTP1_Percent, "%)");
   Print("  TP2: ", InpTP2_RR, "R (Close ", InpTP2_Percent, "%)");
   Print("  TP3: ", InpTP3_RR, "R (Close remaining)");
   Print("-------------------------------------------------");
   Print("BREAK-EVEN: ", InpUseBreakEven ? "Enabled" : "Disabled");
   Print("TRAILING: ", InpUseTrailing ? "Enabled" : "Disabled");
   Print("-------------------------------------------------");
   Print("POSITION LIMITS:");
   Print("  Max Total: ", InpMaxPositions);
   Print("  Max Per Symbol: ", InpMaxPositionsPerSymbol);
   Print("-------------------------------------------------");
   Print("Active Positions Loaded: ", ArraySize(g_activeTrades));
   Print("=================================================");
   Print("");
}

//+------------------------------------------------------------------+
//| Public API Functions                                              |
//+------------------------------------------------------------------+

// Execute a buy trade
bool ExecuteBuy(double stopLoss, double lotSize, int confluenceScore = 6, string source = "SMC")
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   TradeRequest request = CreateTradeRequest(_Symbol, TRADE_BUY, ask, stopLoss,
                                              lotSize, confluenceScore, source);
   return ExecuteTrade(request);
}

// Execute a sell trade
bool ExecuteSell(double stopLoss, double lotSize, int confluenceScore = 6, string source = "SMC")
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   TradeRequest request = CreateTradeRequest(_Symbol, TRADE_SELL, bid, stopLoss,
                                              lotSize, confluenceScore, source);
   return ExecuteTrade(request);
}

// Get active positions count
int GetActivePositions() { return ArraySize(g_activeTrades); }

// Get execution metrics
int GetTP1Hits() { return g_execMetrics.tp1Hits; }
int GetTP2Hits() { return g_execMetrics.tp2Hits; }
int GetBreakEvenCount() { return g_execMetrics.breakEvenHits; }
double GetAvgSlippage() { return g_execMetrics.avgSlippage; }
double GetSuccessRate()
{
   if(g_execMetrics.totalOrders == 0) return 0;
   return (double)g_execMetrics.successfulOrders / g_execMetrics.totalOrders * 100;
}

// Check if can trade
bool CanExecute()
{
   return g_initialized && CheckPositionLimits(_Symbol);
}

//+------------------------------------------------------------------+
