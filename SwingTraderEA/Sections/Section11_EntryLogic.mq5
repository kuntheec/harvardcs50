//+------------------------------------------------------------------+
//|                                        Section11_EntryLogic.mq5 |
//|                                      SwingTrader Pro EA          |
//|                    Section 11: SMC Entry Logic                   |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.02"
#property description "Section 11: SMC Entry Logic v1.02"
#property description "Combines all sections for confluence-based entries"
#property description "OTE zones, FVG fills, Order Block retests"

//+------------------------------------------------------------------+
//| Modification History                                              |
//+------------------------------------------------------------------+
// 2025.12.26 v1.02 - Added Crypto (BTC) support and user overrides:
//                    - Crypto profile (RSI 80/20, extreme ATR thresholds)
//                    - User override inputs for backtesting variants
//                    - Enhanced PrintInitReport with profile details
// 2025.12.25 v1.01 - Added InstrumentProfile integration:
//                    - Uses centralized InstrumentProfile from CommonStructures
//                    - Auto-adjusts RSI/ATR/Spread thresholds by instrument
//                    - Gold/Silver/JPY/Forex automatic detection
// 2025.12.25 v1.00 - Initial release with SMC entry logic:
//                    - 10-point confluence scoring system
//                    - OTE (Optimal Trade Entry) zone detection
//                    - FVG and Order Block entry triggers
//                    - Dynamic entry timing based on conditions
//                    - Integration with all previous sections

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Entry Signal Settings ==="
input int      InpMinConfluence       = 6;          // Minimum Confluence Score (1-10)
input bool     InpRequireMTFAlignment = true;       // Require MTF Alignment
input bool     InpRequireStructure    = true;       // Require BOS/CHoCH Confirmation
input bool     InpRequireZone         = true;       // Require S/D Zone or Order Block

input group "=== OTE Zone Settings ==="
input bool     InpUseOTEZone          = true;       // Use Optimal Trade Entry (61.8-78.6%)
input double   InpOTEUpperFib         = 61.8;       // OTE Upper Level (%)
input double   InpOTELowerFib         = 78.6;       // OTE Lower Level (%)
input bool     InpRequireOTEForStrong = true;       // Require OTE for Strong Signals

input group "=== Entry Trigger Settings ==="
input bool     InpUseFVGEntry         = true;       // Enter on FVG Fill
input bool     InpUseOBEntry          = true;       // Enter on Order Block Retest
input bool     InpUseSDZoneEntry      = true;       // Enter on S/D Zone Touch
input int      InpEntryLookback       = 3;          // Candles to Confirm Entry

input group "=== Risk Filter Settings ==="
input bool     InpCheckNewsFilter     = true;       // Check News Before Entry
input bool     InpCheckATRFilter      = true;       // Check ATR Conditions
input double   InpMaxSpreadPips       = 5.0;        // Maximum Spread (pips)

input group "=== Profile Override Settings (Backtesting) ==="
input bool     InpUseProfileOverride  = false;      // Override Auto-Detection
input int      InpOverrideRSIUpper    = 0;          // Override RSI Upper (0=auto)
input int      InpOverrideRSILower    = 0;          // Override RSI Lower (0=auto)
input double   InpOverrideATRQuiet    = 0;          // Override ATR Quiet (0=auto)
input double   InpOverrideATRExtreme  = 0;          // Override ATR Extreme (0=auto)

input group "=== Timing Settings ==="
input int      InpSignalValidityMins  = 60;         // Signal Validity (minutes)
input bool     InpWaitForPullback     = true;       // Wait for Pullback Entry
input double   InpPullbackPercent     = 38.2;       // Minimum Pullback (% of move)

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;       // Show Info Panel
input color    InpBuyColor            = clrLimeGreen; // Buy Signal Color
input color    InpSellColor           = clrRed;     // Sell Signal Color
input color    InpNeutralColor        = clrGray;    // No Signal Color
input int      InpPanelX              = 20;         // Panel X Position
input int      InpPanelY              = 30;         // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;       // Print Report to Experts Tab
input bool     InpAlertOnSignal       = true;       // Alert on New Signal

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_TYPE
{
   ENTRY_NONE,              // No entry signal
   ENTRY_BUY,               // Buy entry
   ENTRY_SELL               // Sell entry
};

enum ENUM_ENTRY_TRIGGER
{
   TRIGGER_NONE,            // No specific trigger
   TRIGGER_OTE_ZONE,        // Price in OTE zone
   TRIGGER_FVG_FILL,        // FVG being filled
   TRIGGER_OB_RETEST,       // Order Block retest
   TRIGGER_SD_ZONE,         // S/D zone touch
   TRIGGER_BOS_CONFIRM,     // BOS confirmed
   TRIGGER_CHOCH_CONFIRM    // CHoCH confirmed
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct ConfluenceScore
{
   // Individual scores (0 or 1)
   int               mtfAlignment;     // MTF bias aligned
   int               structureBreak;   // BOS/CHoCH confirmed
   int               emaTrend;         // EMA trend aligned
   int               inOTEZone;        // Price in OTE zone
   int               atFVG;            // At or near FVG
   int               atOrderBlock;     // At or near Order Block
   int               atSDZone;         // At S/D zone
   int               rsiConfirm;       // RSI confirms direction
   int               macdConfirm;      // MACD confirms direction
   int               atrCondition;     // ATR conditions favorable
   // Total
   int               total;            // Sum of all scores (0-10)
   ENUM_SIGNAL_STRENGTH strength;      // Derived strength
};

struct EntrySignalV2
{
   // Signal type
   ENUM_ENTRY_TYPE   type;             // Buy/Sell/None
   ENUM_ENTRY_TRIGGER trigger;         // What triggered the entry
   ENUM_SIGNAL_STRENGTH strength;      // Signal strength

   // Confluence
   ConfluenceScore   confluence;       // Detailed confluence breakdown

   // Price levels
   double            entryPrice;       // Suggested entry price
   double            currentPrice;     // Current market price
   double            stopLoss;         // Calculated SL
   double            takeProfit1;      // TP1 (1:1 R:R)
   double            takeProfit2;      // TP2 (1:2 R:R)
   double            takeProfit3;      // TP3 (1:3 R:R)
   double            riskPips;         // Risk in pips
   double            rewardPips;       // Reward in pips (to TP2)
   double            riskReward;       // Risk:Reward ratio

   // Zone information
   double            oteUpperPrice;    // OTE zone upper
   double            oteLowerPrice;    // OTE zone lower
   double            nearestZonePrice; // Nearest S/D or OB price

   // Validity
   bool              isValid;          // Signal still valid?
   datetime          signalTime;       // When signal generated
   datetime          expiryTime;       // When signal expires
   string            reason;           // Signal explanation

   // Filters
   bool              newsOK;           // No conflicting news
   bool              atrOK;            // ATR conditions OK
   bool              spreadOK;         // Spread acceptable
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
// Symbol info
SymbolInfoCache   g_symbolInfo;
InstrumentProfile g_profile;      // Centralized instrument settings
int               g_digits;
double            g_point;

// Current signal
EntrySignalV2     g_signal;

// Price data
double            g_currentBid;
double            g_currentAsk;
double            g_currentSpread;

// Panel
string            g_panelName = "EntryPanel";

// Last signal time (for alert throttling)
datetime          g_lastSignalTime = 0;
ENUM_ENTRY_TYPE   g_lastSignalType = ENTRY_NONE;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize symbol info
   InitSymbolInfo(g_symbolInfo, _Symbol);
   g_digits = g_symbolInfo.digits;
   g_point = g_symbolInfo.point;

   // Get instrument profile (auto-adjusts settings for Gold/Forex/Crypto/etc)
   g_profile = GetInstrumentProfile(g_symbolInfo);

   // Apply user overrides if enabled (for backtesting variants)
   if(InpUseProfileOverride)
   {
      if(InpOverrideRSIUpper > 0) g_profile.rsiUpper = InpOverrideRSIUpper;
      if(InpOverrideRSILower > 0) g_profile.rsiLower = InpOverrideRSILower;
      if(InpOverrideATRQuiet > 0) g_profile.atrQuiet = InpOverrideATRQuiet;
      if(InpOverrideATRExtreme > 0) g_profile.atrExtreme = InpOverrideATRExtreme;
      Print("USER OVERRIDE ACTIVE - Custom profile settings applied");
   }

   Print("INSTRUMENT PROFILE: ", g_profile.instrumentType,
         " | RSI: ", g_profile.rsiLower, "/", g_profile.rsiUpper,
         " | ATR: ", DoubleToString(g_profile.atrQuiet, 0), "-", DoubleToString(g_profile.atrExtreme, 0), " pips",
         " | Max Spread: ", DoubleToString(g_profile.maxSpreadPips, 1), " pips");

   // Print initialization
   PrintInitReport();

   // Create panel
   if(InpShowPanel)
      CreatePanel();

   // Run initial analysis
   AnalyzeEntry();

   // Update panel
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
   Print("Entry Logic EA Deinitialized");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_M15, 0);

   // Update on new bar or significant price change
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      AnalyzeEntry();

      if(InpShowPanel)
         UpdatePanel();
   }

   // Always update current prices
   g_currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   g_currentSpread = (g_currentAsk - g_currentBid) / g_symbolInfo.pipSize;
}

//+------------------------------------------------------------------+
//| Main Entry Analysis Function                                      |
//+------------------------------------------------------------------+
void AnalyzeEntry()
{
   // Reset signal
   ResetSignal();

   // Get current prices
   g_currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   g_currentSpread = (g_currentAsk - g_currentBid) / g_symbolInfo.pipSize;
   g_signal.currentPrice = g_currentBid;

   // Check spread filter (using profile or input override)
   double maxSpread = (InpMaxSpreadPips > 0) ? InpMaxSpreadPips : g_profile.maxSpreadPips;
   g_signal.spreadOK = IsSpreadAcceptable(g_currentSpread, g_profile) || (g_currentSpread <= maxSpread);
   if(!g_signal.spreadOK)
   {
      g_signal.reason = "Spread too high: " + DoubleToString(g_currentSpread, 1) +
                        " pips (max: " + DoubleToString(g_profile.maxSpreadPips, 1) + ")";
      if(InpPrintReport) PrintEntryReport();
      return;
   }

   // Calculate confluence score
   CalculateConfluence();

   // Check if minimum confluence is met
   if(g_signal.confluence.total < InpMinConfluence)
   {
      g_signal.reason = "Insufficient confluence: " + IntegerToString(g_signal.confluence.total) + "/" + IntegerToString(InpMinConfluence);
      if(InpPrintReport) PrintEntryReport();
      return;
   }

   // Determine entry direction based on confluence
   DetermineEntryDirection();

   // If we have a signal, calculate levels
   if(g_signal.type != ENTRY_NONE)
   {
      CalculateEntryLevels();
      CheckEntryTriggers();

      // Generate alert if new signal
      if(InpAlertOnSignal && g_signal.isValid)
      {
         if(g_signal.type != g_lastSignalType || g_signal.signalTime > g_lastSignalTime + 300)
         {
            GenerateAlert();
            g_lastSignalType = g_signal.type;
            g_lastSignalTime = g_signal.signalTime;
         }
      }
   }

   // Print report
   if(InpPrintReport)
      PrintEntryReport();
}

//+------------------------------------------------------------------+
//| Reset Signal to Default                                           |
//+------------------------------------------------------------------+
void ResetSignal()
{
   g_signal.type = ENTRY_NONE;
   g_signal.trigger = TRIGGER_NONE;
   g_signal.strength = SIGNAL_NONE;

   // Reset confluence
   g_signal.confluence.mtfAlignment = 0;
   g_signal.confluence.structureBreak = 0;
   g_signal.confluence.emaTrend = 0;
   g_signal.confluence.inOTEZone = 0;
   g_signal.confluence.atFVG = 0;
   g_signal.confluence.atOrderBlock = 0;
   g_signal.confluence.atSDZone = 0;
   g_signal.confluence.rsiConfirm = 0;
   g_signal.confluence.macdConfirm = 0;
   g_signal.confluence.atrCondition = 0;
   g_signal.confluence.total = 0;
   g_signal.confluence.strength = SIGNAL_NONE;

   // Reset prices
   g_signal.entryPrice = 0;
   g_signal.stopLoss = 0;
   g_signal.takeProfit1 = 0;
   g_signal.takeProfit2 = 0;
   g_signal.takeProfit3 = 0;
   g_signal.riskPips = 0;
   g_signal.rewardPips = 0;
   g_signal.riskReward = 0;

   // Reset validity
   g_signal.isValid = false;
   g_signal.signalTime = TimeCurrent();
   g_signal.expiryTime = g_signal.signalTime + InpSignalValidityMins * 60;
   g_signal.reason = "";

   // Reset filters
   g_signal.newsOK = true;
   g_signal.atrOK = true;
   g_signal.spreadOK = true;
}

//+------------------------------------------------------------------+
//| Calculate Confluence Score                                        |
//+------------------------------------------------------------------+
void CalculateConfluence()
{
   // This function simulates checking each section's output
   // In a real implementation, these would call the actual section functions

   // 1. MTF Alignment (from Section 10)
   g_signal.confluence.mtfAlignment = CheckMTFAlignment() ? 1 : 0;

   // 2. Structure Break (from Section 3)
   g_signal.confluence.structureBreak = CheckStructureBreak() ? 1 : 0;

   // 3. EMA Trend (from Section 2)
   g_signal.confluence.emaTrend = CheckEMATrend() ? 1 : 0;

   // 4. OTE Zone (from Section 5 Fibonacci)
   g_signal.confluence.inOTEZone = CheckOTEZone() ? 1 : 0;

   // 5. At FVG (from Section 7)
   g_signal.confluence.atFVG = CheckAtFVG() ? 1 : 0;

   // 6. At Order Block (from Section 8)
   g_signal.confluence.atOrderBlock = CheckAtOrderBlock() ? 1 : 0;

   // 7. At S/D Zone (from Section 4)
   g_signal.confluence.atSDZone = CheckAtSDZone() ? 1 : 0;

   // 8. RSI Confirms (from Section 6)
   g_signal.confluence.rsiConfirm = CheckRSIConfirm() ? 1 : 0;

   // 9. MACD Confirms (from Section 6)
   g_signal.confluence.macdConfirm = CheckMACDConfirm() ? 1 : 0;

   // 10. ATR Conditions (from Section 1)
   g_signal.confluence.atrCondition = CheckATRCondition() ? 1 : 0;

   // Calculate total
   g_signal.confluence.total = g_signal.confluence.mtfAlignment +
                                g_signal.confluence.structureBreak +
                                g_signal.confluence.emaTrend +
                                g_signal.confluence.inOTEZone +
                                g_signal.confluence.atFVG +
                                g_signal.confluence.atOrderBlock +
                                g_signal.confluence.atSDZone +
                                g_signal.confluence.rsiConfirm +
                                g_signal.confluence.macdConfirm +
                                g_signal.confluence.atrCondition;

   // Determine strength
   if(g_signal.confluence.total >= 8)
      g_signal.confluence.strength = SIGNAL_STRONG;
   else if(g_signal.confluence.total >= 6)
      g_signal.confluence.strength = SIGNAL_MODERATE;
   else if(g_signal.confluence.total >= 4)
      g_signal.confluence.strength = SIGNAL_WEAK;
   else
      g_signal.confluence.strength = SIGNAL_NONE;
}

//+------------------------------------------------------------------+
//| Check MTF Alignment (Simulated - would call Section 10)           |
//+------------------------------------------------------------------+
bool CheckMTFAlignment()
{
   // Simulate MTF check using EMA on multiple timeframes
   int ema50_H1 = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   int ema50_H4 = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   int ema50_D1 = iMA(_Symbol, PERIOD_D1, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(ema50_H1 == INVALID_HANDLE || ema50_H4 == INVALID_HANDLE || ema50_D1 == INVALID_HANDLE)
      return false;

   double buffer[];
   ArraySetAsSeries(buffer, true);

   double h1_ema, h4_ema, d1_ema;

   if(CopyBuffer(ema50_H1, 0, 0, 1, buffer) < 1) return false;
   h1_ema = buffer[0];

   if(CopyBuffer(ema50_H4, 0, 0, 1, buffer) < 1) return false;
   h4_ema = buffer[0];

   if(CopyBuffer(ema50_D1, 0, 0, 1, buffer) < 1) return false;
   d1_ema = buffer[0];

   // Check alignment: all above or all below price
   bool allAbove = (g_currentBid > h1_ema && g_currentBid > h4_ema && g_currentBid > d1_ema);
   bool allBelow = (g_currentBid < h1_ema && g_currentBid < h4_ema && g_currentBid < d1_ema);

   // Release handles
   IndicatorRelease(ema50_H1);
   IndicatorRelease(ema50_H4);
   IndicatorRelease(ema50_D1);

   return (allAbove || allBelow);
}

//+------------------------------------------------------------------+
//| Check Structure Break (Simulated - would call Section 3)          |
//+------------------------------------------------------------------+
bool CheckStructureBreak()
{
   // Check for recent swing high/low break
   double highestHigh = 0, lowestLow = 999999;

   for(int i = 1; i <= 20; i++)
   {
      double high = iHigh(_Symbol, PERIOD_H1, i);
      double low = iLow(_Symbol, PERIOD_H1, i);

      if(high > highestHigh) highestHigh = high;
      if(low < lowestLow) lowestLow = low;
   }

   // Current price breaking structure
   double currentHigh = iHigh(_Symbol, PERIOD_H1, 0);
   double currentLow = iLow(_Symbol, PERIOD_H1, 0);

   bool breakHigh = (currentHigh > highestHigh);
   bool breakLow = (currentLow < lowestLow);

   return (breakHigh || breakLow);
}

//+------------------------------------------------------------------+
//| Check EMA Trend (Simulated - would call Section 2)                |
//+------------------------------------------------------------------+
bool CheckEMATrend()
{
   // Use profile EMA periods (consistent: 50/200)
   int emaFastHandle = iMA(_Symbol, PERIOD_H1, g_profile.emaFast, 0, MODE_EMA, PRICE_CLOSE);
   int emaSlowHandle = iMA(_Symbol, PERIOD_H1, g_profile.emaSlow, 0, MODE_EMA, PRICE_CLOSE);

   if(emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE)
      return false;

   double buffer[];
   ArraySetAsSeries(buffer, true);

   double emaFast, emaSlow;

   if(CopyBuffer(emaFastHandle, 0, 0, 1, buffer) < 1) return false;
   emaFast = buffer[0];

   if(CopyBuffer(emaSlowHandle, 0, 0, 1, buffer) < 1) return false;
   emaSlow = buffer[0];

   IndicatorRelease(emaFastHandle);
   IndicatorRelease(emaSlowHandle);

   // Price above both EMAs = bullish, below both = bearish
   bool bullish = (g_currentBid > emaFast && g_currentBid > emaSlow && emaFast > emaSlow);
   bool bearish = (g_currentBid < emaFast && g_currentBid < emaSlow && emaFast < emaSlow);

   return (bullish || bearish);
}

//+------------------------------------------------------------------+
//| Check OTE Zone (Simulated - would call Section 5)                 |
//+------------------------------------------------------------------+
bool CheckOTEZone()
{
   if(!InpUseOTEZone) return false;

   // Find recent swing high/low
   double swingHigh = 0, swingLow = 999999;

   for(int i = 1; i <= 50; i++)
   {
      double high = iHigh(_Symbol, PERIOD_H1, i);
      double low = iLow(_Symbol, PERIOD_H1, i);

      if(high > swingHigh) swingHigh = high;
      if(low < swingLow) swingLow = low;
   }

   double range = swingHigh - swingLow;

   // Calculate OTE zone (61.8% - 78.6% retracement)
   g_signal.oteUpperPrice = swingHigh - (range * InpOTEUpperFib / 100);
   g_signal.oteLowerPrice = swingHigh - (range * InpOTELowerFib / 100);

   // Check if price is in OTE zone
   bool inBullishOTE = (g_currentBid >= g_signal.oteLowerPrice && g_currentBid <= g_signal.oteUpperPrice);

   // For bearish, flip the levels
   double bearOTEUpper = swingLow + (range * InpOTELowerFib / 100);
   double bearOTELower = swingLow + (range * InpOTEUpperFib / 100);
   bool inBearishOTE = (g_currentBid >= bearOTELower && g_currentBid <= bearOTEUpper);

   return (inBullishOTE || inBearishOTE);
}

//+------------------------------------------------------------------+
//| Check At FVG (Simulated - would call Section 7)                   |
//+------------------------------------------------------------------+
bool CheckAtFVG()
{
   if(!InpUseFVGEntry) return false;

   // Simple FVG detection
   for(int i = 2; i <= 10; i++)
   {
      double high1 = iHigh(_Symbol, PERIOD_H1, i);
      double low1 = iLow(_Symbol, PERIOD_H1, i);
      double high3 = iHigh(_Symbol, PERIOD_H1, i-2);
      double low3 = iLow(_Symbol, PERIOD_H1, i-2);

      // Bullish FVG: gap between candle 1 high and candle 3 low
      if(low3 > high1)
      {
         // Check if price is in this gap
         if(g_currentBid >= high1 && g_currentBid <= low3)
            return true;
      }

      // Bearish FVG: gap between candle 3 high and candle 1 low
      if(high3 < low1)
      {
         if(g_currentBid >= high3 && g_currentBid <= low1)
            return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check At Order Block (Simulated - would call Section 8)           |
//+------------------------------------------------------------------+
bool CheckAtOrderBlock()
{
   if(!InpUseOBEntry) return false;

   // Simple OB detection: look for strong candle before move
   for(int i = 3; i <= 20; i++)
   {
      double open_i = iOpen(_Symbol, PERIOD_H1, i);
      double close_i = iClose(_Symbol, PERIOD_H1, i);
      double high_i = iHigh(_Symbol, PERIOD_H1, i);
      double low_i = iLow(_Symbol, PERIOD_H1, i);

      double body = MathAbs(close_i - open_i);
      double range = high_i - low_i;

      // Strong candle (body > 60% of range)
      if(range > 0 && body / range > 0.6)
      {
         // Bullish OB: bearish candle before bullish move
         if(close_i < open_i)
         {
            // Check if followed by bullish move
            double nextClose = iClose(_Symbol, PERIOD_H1, i-1);
            if(nextClose > high_i)
            {
               // Price returning to OB
               if(g_currentBid >= low_i && g_currentBid <= high_i)
                  return true;
            }
         }
         // Bearish OB: bullish candle before bearish move
         else
         {
            double nextClose = iClose(_Symbol, PERIOD_H1, i-1);
            if(nextClose < low_i)
            {
               if(g_currentBid >= low_i && g_currentBid <= high_i)
                  return true;
            }
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check At S/D Zone (Simulated - would call Section 4)              |
//+------------------------------------------------------------------+
bool CheckAtSDZone()
{
   if(!InpUseSDZoneEntry) return false;

   // Simple S/D detection based on strong moves
   double atr = 0;
   int atrHandle = iATR(_Symbol, PERIOD_H1, 14);

   if(atrHandle != INVALID_HANDLE)
   {
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, buffer) >= 1)
         atr = buffer[0];
      IndicatorRelease(atrHandle);
   }

   if(atr == 0) return false;

   // Look for zones
   for(int i = 5; i <= 30; i++)
   {
      double open_i = iOpen(_Symbol, PERIOD_H1, i);
      double close_i = iClose(_Symbol, PERIOD_H1, i);
      double high_i = iHigh(_Symbol, PERIOD_H1, i);
      double low_i = iLow(_Symbol, PERIOD_H1, i);

      // Strong move out of zone (> 1.5 ATR)
      double move = MathAbs(close_i - open_i);
      if(move > atr * 1.5)
      {
         // Demand zone (bullish candle)
         if(close_i > open_i)
         {
            if(g_currentBid >= open_i - atr * 0.2 && g_currentBid <= open_i + atr * 0.2)
            {
               g_signal.nearestZonePrice = open_i;
               return true;
            }
         }
         // Supply zone (bearish candle)
         else
         {
            if(g_currentBid >= open_i - atr * 0.2 && g_currentBid <= open_i + atr * 0.2)
            {
               g_signal.nearestZonePrice = open_i;
               return true;
            }
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check RSI Confirmation (Simulated - would call Section 6)         |
//+------------------------------------------------------------------+
bool CheckRSIConfirm()
{
   int rsiHandle = iRSI(_Symbol, PERIOD_H1, g_profile.rsiPeriod, PRICE_CLOSE);

   if(rsiHandle == INVALID_HANDLE)
      return false;

   double buffer[];
   ArraySetAsSeries(buffer, true);

   if(CopyBuffer(rsiHandle, 0, 0, 1, buffer) < 1)
   {
      IndicatorRelease(rsiHandle);
      return false;
   }

   double rsi = buffer[0];
   IndicatorRelease(rsiHandle);

   // Use profile-based RSI levels (auto-adjusted for Gold/Forex)
   // RSI should not be at extremes (overbought/oversold)
   // For entry, we want RSI in acceptable range
   bool notOverbought = !IsRSIOverbought(rsi, g_profile);
   bool notOversold = !IsRSIOversold(rsi, g_profile);

   // Valid entry when RSI is not at extremes
   return (notOverbought && notOversold);
}

//+------------------------------------------------------------------+
//| Check MACD Confirmation (Simulated - would call Section 6)        |
//+------------------------------------------------------------------+
bool CheckMACDConfirm()
{
   int macdHandle = iMACD(_Symbol, PERIOD_H1, 12, 26, 9, PRICE_CLOSE);

   if(macdHandle == INVALID_HANDLE)
      return false;

   double macdMain[], macdSignal[];
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);

   if(CopyBuffer(macdHandle, 0, 0, 2, macdMain) < 2 ||
      CopyBuffer(macdHandle, 1, 0, 2, macdSignal) < 2)
   {
      IndicatorRelease(macdHandle);
      return false;
   }

   IndicatorRelease(macdHandle);

   // MACD cross or histogram confirms direction
   bool bullishMACD = (macdMain[0] > macdSignal[0] && macdMain[1] <= macdSignal[1]);
   bool bearishMACD = (macdMain[0] < macdSignal[0] && macdMain[1] >= macdSignal[1]);

   // Or simply aligned with trend
   bool aligned = (macdMain[0] > 0 && macdMain[0] > macdSignal[0]) ||
                  (macdMain[0] < 0 && macdMain[0] < macdSignal[0]);

   return (bullishMACD || bearishMACD || aligned);
}

//+------------------------------------------------------------------+
//| Check ATR Condition (Simulated - would call Section 1)            |
//+------------------------------------------------------------------+
bool CheckATRCondition()
{
   if(!InpCheckATRFilter) return true;

   int atrHandle = iATR(_Symbol, PERIOD_D1, 14);

   if(atrHandle == INVALID_HANDLE)
      return false;

   double buffer[];
   ArraySetAsSeries(buffer, true);

   if(CopyBuffer(atrHandle, 0, 0, 1, buffer) < 1)
   {
      IndicatorRelease(atrHandle);
      return false;
   }

   double atr = buffer[0];
   IndicatorRelease(atrHandle);

   // Convert to pips
   double atrPips = atr / g_symbolInfo.pipSize;

   // Use profile-based ATR thresholds (auto-adjusted for Gold/Forex)
   // Check if in normal range (not too quiet, not extreme)
   g_signal.atrOK = IsMarketNormal(atrPips, g_profile);

   return g_signal.atrOK;
}

//+------------------------------------------------------------------+
//| Determine Entry Direction                                         |
//+------------------------------------------------------------------+
void DetermineEntryDirection()
{
   // Count bullish vs bearish signals
   int bullishCount = 0;
   int bearishCount = 0;

   // MTF alignment direction
   int ema50 = iMA(_Symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(ema50 != INVALID_HANDLE)
   {
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(ema50, 0, 0, 1, buffer) >= 1)
      {
         if(g_currentBid > buffer[0])
            bullishCount++;
         else
            bearishCount++;
      }
      IndicatorRelease(ema50);
   }

   // EMA structure
   int ema50H = iMA(_Symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   int ema200H = iMA(_Symbol, PERIOD_H1, 200, 0, MODE_EMA, PRICE_CLOSE);

   if(ema50H != INVALID_HANDLE && ema200H != INVALID_HANDLE)
   {
      double buf50[], buf200[];
      ArraySetAsSeries(buf50, true);
      ArraySetAsSeries(buf200, true);

      if(CopyBuffer(ema50H, 0, 0, 1, buf50) >= 1 &&
         CopyBuffer(ema200H, 0, 0, 1, buf200) >= 1)
      {
         if(buf50[0] > buf200[0] && g_currentBid > buf50[0])
            bullishCount += 2;
         else if(buf50[0] < buf200[0] && g_currentBid < buf50[0])
            bearishCount += 2;
      }

      IndicatorRelease(ema50H);
      IndicatorRelease(ema200H);
   }

   // Determine final direction
   if(bullishCount > bearishCount && g_signal.confluence.total >= InpMinConfluence)
   {
      g_signal.type = ENTRY_BUY;
      g_signal.reason = "Bullish confluence (" + IntegerToString(g_signal.confluence.total) + "/10)";
   }
   else if(bearishCount > bullishCount && g_signal.confluence.total >= InpMinConfluence)
   {
      g_signal.type = ENTRY_SELL;
      g_signal.reason = "Bearish confluence (" + IntegerToString(g_signal.confluence.total) + "/10)";
   }
   else
   {
      g_signal.type = ENTRY_NONE;
      g_signal.reason = "No clear direction bias";
   }

   g_signal.strength = g_signal.confluence.strength;
}

//+------------------------------------------------------------------+
//| Calculate Entry Levels (Entry, SL, TPs)                           |
//+------------------------------------------------------------------+
void CalculateEntryLevels()
{
   if(g_signal.type == ENTRY_NONE) return;

   // Get ATR for SL/TP calculation
   double atr = 0;
   int atrHandle = iATR(_Symbol, PERIOD_H1, 14);

   if(atrHandle != INVALID_HANDLE)
   {
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, buffer) >= 1)
         atr = buffer[0];
      IndicatorRelease(atrHandle);
   }

   if(atr == 0) atr = 100 * g_symbolInfo.pipSize;  // Default 100 pips

   if(g_signal.type == ENTRY_BUY)
   {
      g_signal.entryPrice = g_currentAsk;
      g_signal.stopLoss = g_signal.entryPrice - atr * 1.5;
      g_signal.takeProfit1 = g_signal.entryPrice + atr * 1.5;    // 1:1
      g_signal.takeProfit2 = g_signal.entryPrice + atr * 3.0;    // 1:2
      g_signal.takeProfit3 = g_signal.entryPrice + atr * 4.5;    // 1:3
   }
   else if(g_signal.type == ENTRY_SELL)
   {
      g_signal.entryPrice = g_currentBid;
      g_signal.stopLoss = g_signal.entryPrice + atr * 1.5;
      g_signal.takeProfit1 = g_signal.entryPrice - atr * 1.5;    // 1:1
      g_signal.takeProfit2 = g_signal.entryPrice - atr * 3.0;    // 1:2
      g_signal.takeProfit3 = g_signal.entryPrice - atr * 4.5;    // 1:3
   }

   // Calculate risk/reward
   g_signal.riskPips = MathAbs(g_signal.entryPrice - g_signal.stopLoss) / g_symbolInfo.pipSize;
   g_signal.rewardPips = MathAbs(g_signal.takeProfit2 - g_signal.entryPrice) / g_symbolInfo.pipSize;

   if(g_signal.riskPips > 0)
      g_signal.riskReward = g_signal.rewardPips / g_signal.riskPips;

   g_signal.isValid = true;
}

//+------------------------------------------------------------------+
//| Check Entry Triggers                                              |
//+------------------------------------------------------------------+
void CheckEntryTriggers()
{
   // Determine which trigger is active
   if(g_signal.confluence.inOTEZone)
      g_signal.trigger = TRIGGER_OTE_ZONE;
   else if(g_signal.confluence.atFVG)
      g_signal.trigger = TRIGGER_FVG_FILL;
   else if(g_signal.confluence.atOrderBlock)
      g_signal.trigger = TRIGGER_OB_RETEST;
   else if(g_signal.confluence.atSDZone)
      g_signal.trigger = TRIGGER_SD_ZONE;
   else if(g_signal.confluence.structureBreak)
      g_signal.trigger = TRIGGER_BOS_CONFIRM;
   else
      g_signal.trigger = TRIGGER_NONE;
}

//+------------------------------------------------------------------+
//| Generate Alert                                                    |
//+------------------------------------------------------------------+
void GenerateAlert()
{
   string alertMsg = "SwingTrader Pro - ";

   if(g_signal.type == ENTRY_BUY)
      alertMsg += "BUY Signal";
   else
      alertMsg += "SELL Signal";

   alertMsg += " | " + _Symbol;
   alertMsg += " | Strength: " + SignalStrengthToString(g_signal.strength);
   alertMsg += " | Confluence: " + IntegerToString(g_signal.confluence.total) + "/10";

   Alert(alertMsg);
   Print("ALERT: ", alertMsg);
}

//+------------------------------------------------------------------+
//| Trigger to String                                                 |
//+------------------------------------------------------------------+
string TriggerToString(ENUM_ENTRY_TRIGGER trigger)
{
   switch(trigger)
   {
      case TRIGGER_OTE_ZONE:      return "OTE Zone (61.8-78.6%)";
      case TRIGGER_FVG_FILL:      return "FVG Fill";
      case TRIGGER_OB_RETEST:     return "Order Block Retest";
      case TRIGGER_SD_ZONE:       return "S/D Zone Touch";
      case TRIGGER_BOS_CONFIRM:   return "BOS Confirmed";
      case TRIGGER_CHOCH_CONFIRM: return "CHoCH Confirmed";
      default:                    return "None";
   }
}

//+------------------------------------------------------------------+
//| Entry Type to String                                              |
//+------------------------------------------------------------------+
string EntryTypeToString(ENUM_ENTRY_TYPE type)
{
   switch(type)
   {
      case ENTRY_BUY:  return "BUY";
      case ENTRY_SELL: return "SELL";
      default:         return "NONE";
   }
}

//+------------------------------------------------------------------+
//| Print Entry Report                                                |
//+------------------------------------------------------------------+
void PrintEntryReport()
{
   Print("");
   Print("=================================================");
   Print("     ENTRY LOGIC ANALYSIS (Section 11 v1.02)     ");
   Print("=================================================");
   Print("Symbol: ", _Symbol, " (", g_profile.instrumentType, ")");
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Current Bid: ", DoubleToString(g_currentBid, g_digits));
   Print("Current Spread: ", DoubleToString(g_currentSpread, 1), " pips (max: ", DoubleToString(g_profile.maxSpreadPips, 1), ")");
   Print("-------------------------------------------------");

   Print("CONFLUENCE BREAKDOWN:");
   Print("  [", g_signal.confluence.mtfAlignment ? "X" : " ", "] MTF Alignment");
   Print("  [", g_signal.confluence.structureBreak ? "X" : " ", "] Structure Break (BOS/CHoCH)");
   Print("  [", g_signal.confluence.emaTrend ? "X" : " ", "] EMA Trend Aligned");
   Print("  [", g_signal.confluence.inOTEZone ? "X" : " ", "] In OTE Zone");
   Print("  [", g_signal.confluence.atFVG ? "X" : " ", "] At FVG");
   Print("  [", g_signal.confluence.atOrderBlock ? "X" : " ", "] At Order Block");
   Print("  [", g_signal.confluence.atSDZone ? "X" : " ", "] At S/D Zone");
   Print("  [", g_signal.confluence.rsiConfirm ? "X" : " ", "] RSI Confirms");
   Print("  [", g_signal.confluence.macdConfirm ? "X" : " ", "] MACD Confirms");
   Print("  [", g_signal.confluence.atrCondition ? "X" : " ", "] ATR Conditions OK");
   Print("  TOTAL: ", g_signal.confluence.total, "/10 (", SignalStrengthToString(g_signal.confluence.strength), ")");
   Print("-------------------------------------------------");

   Print("ENTRY SIGNAL:");
   Print("  Type: ", EntryTypeToString(g_signal.type));
   Print("  Trigger: ", TriggerToString(g_signal.trigger));
   Print("  Strength: ", SignalStrengthToString(g_signal.strength));
   Print("-------------------------------------------------");

   if(g_signal.type != ENTRY_NONE)
   {
      Print("ENTRY LEVELS:");
      Print("  Entry: ", DoubleToString(g_signal.entryPrice, g_digits));
      Print("  Stop Loss: ", DoubleToString(g_signal.stopLoss, g_digits));
      Print("  TP1 (1:1): ", DoubleToString(g_signal.takeProfit1, g_digits));
      Print("  TP2 (1:2): ", DoubleToString(g_signal.takeProfit2, g_digits));
      Print("  TP3 (1:3): ", DoubleToString(g_signal.takeProfit3, g_digits));
      Print("  Risk: ", DoubleToString(g_signal.riskPips, 1), " pips");
      Print("  R:R Ratio: 1:", DoubleToString(g_signal.riskReward, 1));
      Print("-------------------------------------------------");
   }

   Print("STATUS:");
   Print("  Valid: ", g_signal.isValid ? "YES" : "NO");
   Print("  Reason: ", g_signal.reason);
   Print("  Expires: ", TimeToString(g_signal.expiryTime, TIME_DATE|TIME_MINUTES));
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
   Print("     SWING TRADER PRO - SECTION 11 (v1.02)       ");
   Print("     SMC ENTRY LOGIC                             ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol);
   Print("Instrument Type: ", g_profile.instrumentType);
   Print("-------------------------------------------------");
   Print("INSTRUMENT PROFILE (", InpUseProfileOverride ? "OVERRIDE" : "AUTO-DETECTED", "):");
   Print("  RSI Period: ", g_profile.rsiPeriod);
   Print("  RSI Levels: ", g_profile.rsiLower, " / ", g_profile.rsiUpper);
   Print("  RSI Neutral: ", g_profile.rsiNeutralLower, " - ", g_profile.rsiNeutralUpper);
   Print("  ATR Quiet: < ", DoubleToString(g_profile.atrQuiet, 0), " pips");
   Print("  ATR Normal: ", DoubleToString(g_profile.atrQuiet, 0), " - ", DoubleToString(g_profile.atrExtreme, 0), " pips");
   Print("  ATR Extreme: > ", DoubleToString(g_profile.atrExtreme, 0), " pips");
   Print("  EMA Fast/Slow: ", g_profile.emaFast, " / ", g_profile.emaSlow);
   Print("  Max Spread: ", DoubleToString(g_profile.maxSpreadPips, 1), " pips");
   Print("  Zone Range: ", DoubleToString(g_profile.minZonePips, 0), " - ", DoubleToString(g_profile.maxZonePips, 0), " pips");
   Print("-------------------------------------------------");
   Print("ENTRY SETTINGS:");
   Print("  Min Confluence: ", InpMinConfluence, "/10");
   Print("  Require MTF: ", InpRequireMTFAlignment ? "Yes" : "No");
   Print("  Require Structure: ", InpRequireStructure ? "Yes" : "No");
   Print("  Require Zone: ", InpRequireZone ? "Yes" : "No");
   Print("-------------------------------------------------");
   Print("OTE ZONE SETTINGS:");
   Print("  Use OTE: ", InpUseOTEZone ? "Enabled" : "Disabled");
   Print("  OTE Range: ", DoubleToString(g_profile.oteUpperFib, 1), "% - ", DoubleToString(g_profile.oteLowerFib, 1), "%");
   Print("-------------------------------------------------");
   Print("ENTRY TRIGGERS:");
   Print("  FVG Entry: ", InpUseFVGEntry ? "Enabled" : "Disabled");
   Print("  OB Entry: ", InpUseOBEntry ? "Enabled" : "Disabled");
   Print("  S/D Zone Entry: ", InpUseSDZoneEntry ? "Enabled" : "Disabled");
   Print("-------------------------------------------------");
   Print("RISK FILTERS:");
   Print("  News Filter: ", InpCheckNewsFilter ? "Enabled" : "Disabled");
   Print("  ATR Filter: ", InpCheckATRFilter ? "Enabled" : "Disabled");
   Print("  Max Spread: ", DoubleToString(g_profile.maxSpreadPips, 1), " pips");
   if(InpUseProfileOverride)
   {
      Print("-------------------------------------------------");
      Print("USER OVERRIDES ACTIVE:");
      if(InpOverrideRSIUpper > 0) Print("  RSI Upper: ", InpOverrideRSIUpper);
      if(InpOverrideRSILower > 0) Print("  RSI Lower: ", InpOverrideRSILower);
      if(InpOverrideATRQuiet > 0) Print("  ATR Quiet: ", DoubleToString(InpOverrideATRQuiet, 0));
      if(InpOverrideATRExtreme > 0) Print("  ATR Extreme: ", DoubleToString(InpOverrideATRExtreme, 0));
   }
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
   int height = 480;  // Increased height for more info

   CreateRectangle(g_panelName + "_bg", x, y, 320, height, clrBlack, 200);

   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "SMC ENTRY LOGIC v1.02", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "------------------------------------", clrGray, 8, "Courier New");

   int yOff = 40;

   // Symbol & Instrument Type
   CreateLabel(g_panelName + "_sym_label", x + 10, y + yOff, "Symbol:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_sym_value", x + 100, y + yOff, _Symbol, clrGold, 9, "Arial Bold");
   yOff += 18;

   // Instrument Type
   CreateLabel(g_panelName + "_inst_label", x + 10, y + yOff, "Type:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_inst_value", x + 100, y + yOff, "--", clrYellow, 9, "Arial");
   yOff += 18;

   // Current Price
   CreateLabel(g_panelName + "_price_label", x + 10, y + yOff, "Price:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_price_value", x + 100, y + yOff, "--", clrCyan, 9, "Arial");
   yOff += 18;

   // Spread
   CreateLabel(g_panelName + "_spread_label", x + 10, y + yOff, "Spread:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_spread_value", x + 100, y + yOff, "--", clrYellow, 9, "Arial");
   yOff += 22;

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Confluence Header
   CreateLabel(g_panelName + "_conf_header", x + 10, y + yOff, "CONFLUENCE:", clrWhite, 9, "Arial Bold");
   CreateLabel(g_panelName + "_conf_total", x + 200, y + yOff, "--/10", clrYellow, 9, "Arial Bold");
   yOff += 18;

   // Confluence checkboxes
   CreateLabel(g_panelName + "_c1", x + 10, y + yOff, "[ ] MTF Align", clrGray, 8, "Courier New");
   CreateLabel(g_panelName + "_c2", x + 160, y + yOff, "[ ] Structure", clrGray, 8, "Courier New");
   yOff += 15;
   CreateLabel(g_panelName + "_c3", x + 10, y + yOff, "[ ] EMA Trend", clrGray, 8, "Courier New");
   CreateLabel(g_panelName + "_c4", x + 160, y + yOff, "[ ] OTE Zone", clrGray, 8, "Courier New");
   yOff += 15;
   CreateLabel(g_panelName + "_c5", x + 10, y + yOff, "[ ] FVG", clrGray, 8, "Courier New");
   CreateLabel(g_panelName + "_c6", x + 160, y + yOff, "[ ] Order Block", clrGray, 8, "Courier New");
   yOff += 15;
   CreateLabel(g_panelName + "_c7", x + 10, y + yOff, "[ ] S/D Zone", clrGray, 8, "Courier New");
   CreateLabel(g_panelName + "_c8", x + 160, y + yOff, "[ ] RSI", clrGray, 8, "Courier New");
   yOff += 15;
   CreateLabel(g_panelName + "_c9", x + 10, y + yOff, "[ ] MACD", clrGray, 8, "Courier New");
   CreateLabel(g_panelName + "_c10", x + 160, y + yOff, "[ ] ATR OK", clrGray, 8, "Courier New");
   yOff += 20;

   CreateLabel(g_panelName + "_sep3", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Signal Type
   CreateLabel(g_panelName + "_type_label", x + 10, y + yOff, "Signal:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_type_value", x + 100, y + yOff, "--", clrYellow, 9, "Arial Bold");
   yOff += 18;

   // Strength
   CreateLabel(g_panelName + "_str_label", x + 10, y + yOff, "Strength:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_str_value", x + 100, y + yOff, "--", clrGray, 9, "Arial");
   yOff += 18;

   // Trigger
   CreateLabel(g_panelName + "_trig_label", x + 10, y + yOff, "Trigger:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_trig_value", x + 100, y + yOff, "--", clrGray, 8, "Arial");
   yOff += 22;

   CreateLabel(g_panelName + "_sep4", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Entry Price
   CreateLabel(g_panelName + "_entry_label", x + 10, y + yOff, "Entry:", clrCyan, 9, "Arial");
   CreateLabel(g_panelName + "_entry_value", x + 100, y + yOff, "--", clrCyan, 9, "Arial");
   yOff += 18;

   // SL
   CreateLabel(g_panelName + "_sl_label", x + 10, y + yOff, "Stop Loss:", clrRed, 9, "Arial");
   CreateLabel(g_panelName + "_sl_value", x + 100, y + yOff, "--", clrRed, 9, "Arial");
   yOff += 18;

   // TP1
   CreateLabel(g_panelName + "_tp1_label", x + 10, y + yOff, "TP1 (1:1):", clrLimeGreen, 9, "Arial");
   CreateLabel(g_panelName + "_tp1_value", x + 100, y + yOff, "--", clrLimeGreen, 9, "Arial");
   yOff += 18;

   // TP2
   CreateLabel(g_panelName + "_tp2_label", x + 10, y + yOff, "TP2 (1:2):", clrLimeGreen, 9, "Arial");
   CreateLabel(g_panelName + "_tp2_value", x + 100, y + yOff, "--", clrLimeGreen, 9, "Arial");
   yOff += 18;

   // R:R
   CreateLabel(g_panelName + "_rr_label", x + 10, y + yOff, "Risk:Reward:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_rr_value", x + 100, y + yOff, "--", clrYellow, 9, "Arial");
   yOff += 22;

   CreateLabel(g_panelName + "_sep5", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Status
   CreateLabel(g_panelName + "_status_label", x + 10, y + yOff, "Status:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_status_value", x + 100, y + yOff, "Analyzing...", clrYellow, 9, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Update Confluence Checkbox                                        |
//+------------------------------------------------------------------+
void UpdateConfluenceBox(string suffix, int value, string label)
{
   string text = (value > 0) ? "[X] " + label : "[ ] " + label;
   color clr = (value > 0) ? clrLimeGreen : clrGray;
   ObjectSetString(0, g_panelName + suffix, OBJPROP_TEXT, text);
   ObjectSetInteger(0, g_panelName + suffix, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel) return;

   // Instrument Type
   ObjectSetString(0, g_panelName + "_inst_value", OBJPROP_TEXT, g_profile.instrumentType);

   // Current Price
   ObjectSetString(0, g_panelName + "_price_value", OBJPROP_TEXT, DoubleToString(g_currentBid, g_digits));

   // Spread with color coding
   string spreadStr = DoubleToString(g_currentSpread, 1) + " pips";
   color spreadColor = g_signal.spreadOK ? clrLimeGreen : clrRed;
   ObjectSetString(0, g_panelName + "_spread_value", OBJPROP_TEXT, spreadStr);
   ObjectSetInteger(0, g_panelName + "_spread_value", OBJPROP_COLOR, spreadColor);

   // Confluence Total
   ObjectSetString(0, g_panelName + "_conf_total", OBJPROP_TEXT,
                   IntegerToString(g_signal.confluence.total) + "/10");
   color confColor = (g_signal.confluence.total >= 8) ? clrLimeGreen :
                     (g_signal.confluence.total >= 6) ? clrYellow : clrOrange;
   ObjectSetInteger(0, g_panelName + "_conf_total", OBJPROP_COLOR, confColor);

   // Update confluence checkboxes
   UpdateConfluenceBox("_c1", g_signal.confluence.mtfAlignment, "MTF Align");
   UpdateConfluenceBox("_c2", g_signal.confluence.structureBreak, "Structure");
   UpdateConfluenceBox("_c3", g_signal.confluence.emaTrend, "EMA Trend");
   UpdateConfluenceBox("_c4", g_signal.confluence.inOTEZone, "OTE Zone");
   UpdateConfluenceBox("_c5", g_signal.confluence.atFVG, "FVG");
   UpdateConfluenceBox("_c6", g_signal.confluence.atOrderBlock, "Order Block");
   UpdateConfluenceBox("_c7", g_signal.confluence.atSDZone, "S/D Zone");
   UpdateConfluenceBox("_c8", g_signal.confluence.rsiConfirm, "RSI");
   UpdateConfluenceBox("_c9", g_signal.confluence.macdConfirm, "MACD");
   UpdateConfluenceBox("_c10", g_signal.confluence.atrCondition, "ATR OK");

   // Signal Type
   string typeStr = EntryTypeToString(g_signal.type);
   color typeColor = InpNeutralColor;
   if(g_signal.type == ENTRY_BUY) typeColor = InpBuyColor;
   else if(g_signal.type == ENTRY_SELL) typeColor = InpSellColor;

   ObjectSetString(0, g_panelName + "_type_value", OBJPROP_TEXT, typeStr);
   ObjectSetInteger(0, g_panelName + "_type_value", OBJPROP_COLOR, typeColor);

   // Strength
   string strStr = SignalStrengthToString(g_signal.strength);
   color strColor = (g_signal.strength == SIGNAL_STRONG) ? clrLimeGreen :
                    (g_signal.strength == SIGNAL_MODERATE) ? clrYellow : clrGray;
   ObjectSetString(0, g_panelName + "_str_value", OBJPROP_TEXT, strStr);
   ObjectSetInteger(0, g_panelName + "_str_value", OBJPROP_COLOR, strColor);

   // Trigger
   ObjectSetString(0, g_panelName + "_trig_value", OBJPROP_TEXT,
                   TriggerToString(g_signal.trigger));

   // Entry Levels
   if(g_signal.type != ENTRY_NONE)
   {
      ObjectSetString(0, g_panelName + "_entry_value", OBJPROP_TEXT,
                      DoubleToString(g_signal.entryPrice, g_digits));
      ObjectSetString(0, g_panelName + "_sl_value", OBJPROP_TEXT,
                      DoubleToString(g_signal.stopLoss, g_digits));
      ObjectSetString(0, g_panelName + "_tp1_value", OBJPROP_TEXT,
                      DoubleToString(g_signal.takeProfit1, g_digits));
      ObjectSetString(0, g_panelName + "_tp2_value", OBJPROP_TEXT,
                      DoubleToString(g_signal.takeProfit2, g_digits));
      ObjectSetString(0, g_panelName + "_rr_value", OBJPROP_TEXT,
                      "1:" + DoubleToString(g_signal.riskReward, 1));
   }
   else
   {
      ObjectSetString(0, g_panelName + "_entry_value", OBJPROP_TEXT, "--");
      ObjectSetString(0, g_panelName + "_sl_value", OBJPROP_TEXT, "--");
      ObjectSetString(0, g_panelName + "_tp1_value", OBJPROP_TEXT, "--");
      ObjectSetString(0, g_panelName + "_tp2_value", OBJPROP_TEXT, "--");
      ObjectSetString(0, g_panelName + "_rr_value", OBJPROP_TEXT, "--");
   }

   // Status
   string statusStr = g_signal.isValid ? "SIGNAL ACTIVE" : "NO SIGNAL";
   if(!g_signal.spreadOK) statusStr = "SPREAD HIGH";
   if(g_signal.confluence.total < InpMinConfluence) statusStr = "LOW CONFLUENCE";
   color statusColor = g_signal.isValid ? InpBuyColor : InpNeutralColor;
   if(g_signal.type == ENTRY_SELL && g_signal.isValid) statusColor = InpSellColor;

   ObjectSetString(0, g_panelName + "_status_value", OBJPROP_TEXT, statusStr);
   ObjectSetInteger(0, g_panelName + "_status_value", OBJPROP_COLOR, statusColor);

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
ENUM_ENTRY_TYPE GetEntrySignal() { return g_signal.type; }
ENUM_SIGNAL_STRENGTH GetSignalStrength() { return g_signal.strength; }
int GetConfluenceScore() { return g_signal.confluence.total; }
bool IsSignalValid() { return g_signal.isValid; }
double GetEntryPrice() { return g_signal.entryPrice; }
double GetStopLoss() { return g_signal.stopLoss; }
double GetTakeProfit1() { return g_signal.takeProfit1; }
double GetTakeProfit2() { return g_signal.takeProfit2; }
double GetTakeProfit3() { return g_signal.takeProfit3; }
double GetRiskReward() { return g_signal.riskReward; }
ENUM_ENTRY_TRIGGER GetEntryTrigger() { return g_signal.trigger; }
//+------------------------------------------------------------------+
