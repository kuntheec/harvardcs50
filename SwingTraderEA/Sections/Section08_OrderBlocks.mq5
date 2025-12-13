//+------------------------------------------------------------------+
//|                                       Section08_OrderBlocks.mq5 |
//|                                      SwingTrader Pro EA          |
//|                Section 8: Order Blocks + Volume Profile Analysis |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.00"
#property description "Section 8: Order Blocks & Volume Profile"
#property description "Identifies institutional order blocks"
#property description "Volume distribution analysis for S/R levels"

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== Order Block Settings ==="
input int      InpOBLookback          = 50;       // Lookback Bars for Order Blocks
input int      InpMaxOrderBlocks      = 8;        // Maximum Order Blocks to Track
input double   InpMinOBSize           = 10.0;     // Minimum OB Size (pips)
input double   InpMaxOBSize           = 200.0;    // Maximum OB Size (pips)
input bool     InpOBRequireBreak      = true;     // Require Structure Break
input ENUM_TIMEFRAMES InpOBTimeframe  = PERIOD_H4; // Order Block Timeframe

input group "=== Order Block Validation ==="
input int      InpMinMoveMultiple     = 2;        // Min Move Multiple (xOB size)
input bool     InpRequireImpulse      = true;     // Require Impulse Move
input int      InpImpulseCandles      = 3;        // Impulse Within N Candles

input group "=== Volume Profile Settings ==="
input int      InpVPLookback          = 100;      // Volume Profile Lookback Bars
input int      InpVPRows              = 24;       // Number of Price Rows
input double   InpVAPercent           = 70.0;     // Value Area Percentage

input group "=== Visual Settings ==="
input bool     InpDrawOB              = true;     // Draw Order Blocks
input bool     InpDrawVP              = true;     // Draw Volume Profile
input color    InpBullishOBColor      = clrDodgerBlue;  // Bullish OB Color
input color    InpBearishOBColor      = clrCrimson;     // Bearish OB Color
input color    InpMitigatedOBColor    = clrDarkGray;    // Mitigated OB Color
input color    InpPOCColor            = clrGold;        // POC Line Color
input color    InpVAColor             = clrDarkSlateGray; // Value Area Color

input group "=== Panel Settings ==="
input bool     InpShowPanel           = true;     // Show Info Panel
input int      InpPanelX              = 20;       // Panel X Position
input int      InpPanelY              = 30;       // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;     // Print Report to Experts Tab

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_OB_TYPE
{
   OB_BULLISH,             // Bullish Order Block (demand)
   OB_BEARISH              // Bearish Order Block (supply)
};

enum ENUM_OB_STATUS
{
   OB_FRESH,               // Not touched yet
   OB_TESTED,              // Price returned to zone
   OB_MITIGATED            // Zone has been violated
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct OrderBlock
{
   ENUM_OB_TYPE     type;
   ENUM_OB_STATUS   status;
   double           highPrice;      // Top of OB zone
   double           lowPrice;       // Bottom of OB zone
   double           midPrice;       // Middle (50%) of OB
   double           sizePips;       // Size in pips
   double           bodyHigh;       // Candle body high
   double           bodyLow;        // Candle body low
   datetime         timeCreated;    // When OB was created
   int              barIndex;       // Bar index when created
   int              timesTestedCount; // How many times price touched
   string           objName;        // Chart object name
   bool             isValid;        // Is this OB still valid
};

struct VolumeLevel
{
   double           priceLevel;     // Price at this level
   long             volume;         // Volume at this level
   double           percentage;     // Percentage of total volume
   bool             isPOC;          // Is Point of Control
   bool             isInVA;         // Is within Value Area
};

struct VolumeProfile
{
   VolumeLevel      levels[];       // Volume levels array
   double           pocPrice;       // Point of Control price
   long             pocVolume;      // POC volume
   double           vahPrice;       // Value Area High
   double           valPrice;       // Value Area Low
   double           highPrice;      // Profile high
   double           lowPrice;       // Profile low
   long             totalVolume;    // Total volume in profile
   datetime         lastUpdate;
};

struct OrderBlockAnalysis
{
   OrderBlock       blocks[];             // Array of order blocks
   int              bullishCount;         // Active bullish OBs
   int              bearishCount;         // Active bearish OBs
   int              mitigatedCount;       // Mitigated OBs
   OrderBlock       nearestBullish;       // Nearest bullish OB
   OrderBlock       nearestBearish;       // Nearest bearish OB
   bool             priceInBullishOB;     // Price in bullish OB
   bool             priceInBearishOB;     // Price in bearish OB
   VolumeProfile    volumeProfile;        // Volume profile data
   ENUM_TREND_BIAS  obBias;               // Overall bias from OBs
   string           recommendation;
   datetime         lastUpdate;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
// Buffers
double            g_highBuffer[];
double            g_lowBuffer[];
double            g_closeBuffer[];
double            g_openBuffer[];
long              g_volumeBuffer[];

// Analysis result
OrderBlockAnalysis g_analysis;

// Panel
string            g_panelName = "OBPanel";

// Symbol info
int               g_digits;
double            g_point;
double            g_pipValue;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Get symbol info
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Calculate pip value
   if(g_digits == 3 || g_digits == 5)
      g_pipValue = g_point * 10;
   else if(g_digits == 2)
      g_pipValue = g_point;
   else
      g_pipValue = g_point;

   // Initialize arrays as series
   ArraySetAsSeries(g_highBuffer, true);
   ArraySetAsSeries(g_lowBuffer, true);
   ArraySetAsSeries(g_closeBuffer, true);
   ArraySetAsSeries(g_openBuffer, true);
   ArraySetAsSeries(g_volumeBuffer, true);

   // Initialize arrays
   ArrayResize(g_analysis.blocks, 0);
   ArrayResize(g_analysis.volumeProfile.levels, InpVPRows);

   // Print initialization
   PrintInitReport();

   // Create panel
   if(InpShowPanel)
      CreatePanel();

   // Run initial analysis
   AnalyzeOrderBlocks();

   // Update panel with initial values
   if(InpShowPanel)
      UpdatePanel();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Remove OB drawings
   DeleteAllOBObjects();

   // Remove VP drawings
   DeleteVolumeProfileObjects();

   // Remove panel
   DeletePanel();

   Print("=================================================");
   Print("Order Blocks EA Deinitialized");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, InpOBTimeframe, 0);

   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      AnalyzeOrderBlocks();

      if(InpShowPanel) UpdatePanel();
   }
   else
   {
      // Check OB mitigation on every tick
      CheckOBMitigation();
   }
}

//+------------------------------------------------------------------+
//| Main Order Block Analysis Function                                |
//+------------------------------------------------------------------+
void AnalyzeOrderBlocks()
{
   int barsNeeded = MathMax(InpOBLookback, InpVPLookback) + 10;
   int minBars = 20;

   // Copy price data
   int copied = CopyHigh(_Symbol, InpOBTimeframe, 0, barsNeeded, g_highBuffer);
   if(copied < minBars)
   {
      Print("WARNING: Price data not ready (copied: ", copied, ")");
      return;
   }

   if(CopyLow(_Symbol, InpOBTimeframe, 0, copied, g_lowBuffer) < minBars) return;
   if(CopyClose(_Symbol, InpOBTimeframe, 0, copied, g_closeBuffer) < minBars) return;
   if(CopyOpen(_Symbol, InpOBTimeframe, 0, copied, g_openBuffer) < minBars) return;
   if(CopyTickVolume(_Symbol, InpOBTimeframe, 0, copied, g_volumeBuffer) < minBars) return;

   // Detect new order blocks
   DetectOrderBlocks(copied);

   // Check mitigation of existing OBs
   CheckOBMitigation();

   // Calculate volume profile
   if(InpDrawVP)
      CalculateVolumeProfile(copied);

   // Update visual objects
   if(InpDrawOB)
      UpdateOBDrawings();

   if(InpDrawVP)
      UpdateVolumeProfileDrawings();

   // Calculate analysis
   CalculateOBAnalysis();

   // Generate recommendation
   GenerateRecommendation();

   g_analysis.lastUpdate = TimeCurrent();

   // Print report
   if(InpPrintReport)
      PrintOBReport();
}

//+------------------------------------------------------------------+
//| Detect Order Blocks                                               |
//+------------------------------------------------------------------+
void DetectOrderBlocks(int barCount)
{
   int maxCheck = MathMin(barCount - 5, InpOBLookback);

   for(int i = 3; i < maxCheck; i++)
   {
      // Check if this bar already has an OB recorded
      if(HasOBAtBar(i)) continue;

      // Get candle properties
      double open_i = g_openBuffer[i];
      double close_i = g_closeBuffer[i];
      double high_i = g_highBuffer[i];
      double low_i = g_lowBuffer[i];
      bool isBullishCandle = (close_i > open_i);
      bool isBearishCandle = (close_i < open_i);

      // === BULLISH ORDER BLOCK ===
      // Last bearish candle before a strong bullish impulse move
      if(isBearishCandle)
      {
         // Check for bullish impulse in next candles
         bool impulseFound = false;
         double impulseHigh = 0;

         for(int j = i - 1; j >= i - InpImpulseCandles && j >= 0; j--)
         {
            // Check if candle j broke above the bearish candle's high
            if(g_highBuffer[j] > high_i)
            {
               impulseFound = true;
               impulseHigh = g_highBuffer[j];
               break;
            }
         }

         if(impulseFound)
         {
            // Calculate OB size
            double obSize = (high_i - low_i) / g_pipValue;

            if(obSize >= InpMinOBSize && obSize <= InpMaxOBSize)
            {
               // Check move size requirement
               double moveSize = (impulseHigh - high_i) / g_pipValue;
               if(!InpRequireImpulse || moveSize >= obSize * InpMinMoveMultiple)
               {
                  AddOrderBlock(OB_BULLISH, high_i, low_i, open_i, close_i, i);
               }
            }
         }
      }

      // === BEARISH ORDER BLOCK ===
      // Last bullish candle before a strong bearish impulse move
      if(isBullishCandle)
      {
         // Check for bearish impulse in next candles
         bool impulseFound = false;
         double impulseLow = DBL_MAX;

         for(int j = i - 1; j >= i - InpImpulseCandles && j >= 0; j--)
         {
            // Check if candle j broke below the bullish candle's low
            if(g_lowBuffer[j] < low_i)
            {
               impulseFound = true;
               impulseLow = g_lowBuffer[j];
               break;
            }
         }

         if(impulseFound)
         {
            // Calculate OB size
            double obSize = (high_i - low_i) / g_pipValue;

            if(obSize >= InpMinOBSize && obSize <= InpMaxOBSize)
            {
               // Check move size requirement
               double moveSize = (low_i - impulseLow) / g_pipValue;
               if(!InpRequireImpulse || moveSize >= obSize * InpMinMoveMultiple)
               {
                  AddOrderBlock(OB_BEARISH, high_i, low_i, open_i, close_i, i);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if OB exists at bar                                         |
//+------------------------------------------------------------------+
bool HasOBAtBar(int barIndex)
{
   datetime barTime = iTime(_Symbol, InpOBTimeframe, barIndex);
   int count = ArraySize(g_analysis.blocks);

   for(int i = 0; i < count; i++)
   {
      if(g_analysis.blocks[i].timeCreated == barTime)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Add Order Block                                                   |
//+------------------------------------------------------------------+
void AddOrderBlock(ENUM_OB_TYPE type, double high, double low,
                   double open, double close, int barIndex)
{
   // Check if we've reached max count
   int count = ArraySize(g_analysis.blocks);
   if(count >= InpMaxOrderBlocks)
   {
      // Remove oldest mitigated OB
      RemoveOldestMitigatedOB();
      count = ArraySize(g_analysis.blocks);

      if(count >= InpMaxOrderBlocks)
      {
         RemoveOldestOB();
         count = ArraySize(g_analysis.blocks);
      }
   }

   // Resize array
   ArrayResize(g_analysis.blocks, count + 1);

   // Fill OB data
   OrderBlock ob;
   ob.type = type;
   ob.status = OB_FRESH;
   ob.highPrice = high;
   ob.lowPrice = low;
   ob.midPrice = (high + low) / 2.0;
   ob.bodyHigh = MathMax(open, close);
   ob.bodyLow = MathMin(open, close);
   ob.sizePips = (high - low) / g_pipValue;
   ob.timeCreated = iTime(_Symbol, InpOBTimeframe, barIndex);
   ob.barIndex = barIndex;
   ob.timesTestedCount = 0;
   ob.objName = "OB_" + IntegerToString(ob.timeCreated);
   ob.isValid = true;

   g_analysis.blocks[count] = ob;
}

//+------------------------------------------------------------------+
//| Remove Oldest Mitigated OB                                        |
//+------------------------------------------------------------------+
void RemoveOldestMitigatedOB()
{
   int count = ArraySize(g_analysis.blocks);
   int oldestIdx = -1;
   datetime oldestTime = TimeCurrent();

   for(int i = 0; i < count; i++)
   {
      if(g_analysis.blocks[i].status == OB_MITIGATED &&
         g_analysis.blocks[i].timeCreated < oldestTime)
      {
         oldestTime = g_analysis.blocks[i].timeCreated;
         oldestIdx = i;
      }
   }

   if(oldestIdx >= 0)
      RemoveOBAtIndex(oldestIdx);
}

//+------------------------------------------------------------------+
//| Remove Oldest OB                                                  |
//+------------------------------------------------------------------+
void RemoveOldestOB()
{
   int count = ArraySize(g_analysis.blocks);
   if(count == 0) return;

   int oldestIdx = 0;
   datetime oldestTime = g_analysis.blocks[0].timeCreated;

   for(int i = 1; i < count; i++)
   {
      if(g_analysis.blocks[i].timeCreated < oldestTime)
      {
         oldestTime = g_analysis.blocks[i].timeCreated;
         oldestIdx = i;
      }
   }

   RemoveOBAtIndex(oldestIdx);
}

//+------------------------------------------------------------------+
//| Remove OB at Index                                                |
//+------------------------------------------------------------------+
void RemoveOBAtIndex(int index)
{
   int count = ArraySize(g_analysis.blocks);
   if(index < 0 || index >= count) return;

   // Delete chart object
   ObjectDelete(0, g_analysis.blocks[index].objName);

   // Shift array elements
   for(int i = index; i < count - 1; i++)
   {
      g_analysis.blocks[i] = g_analysis.blocks[i + 1];
   }

   // Resize array
   ArrayResize(g_analysis.blocks, count - 1);
}

//+------------------------------------------------------------------+
//| Check OB Mitigation                                               |
//+------------------------------------------------------------------+
void CheckOBMitigation()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int count = ArraySize(g_analysis.blocks);

   for(int i = 0; i < count; i++)
   {
      if(g_analysis.blocks[i].status == OB_MITIGATED) continue;

      // Check if price is inside the OB
      if(currentPrice >= g_analysis.blocks[i].lowPrice &&
         currentPrice <= g_analysis.blocks[i].highPrice)
      {
         if(g_analysis.blocks[i].status == OB_FRESH)
         {
            g_analysis.blocks[i].status = OB_TESTED;
            g_analysis.blocks[i].timesTestedCount++;
         }
      }

      // Check for mitigation
      // Bullish OB: mitigated when price closes below the low
      // Bearish OB: mitigated when price closes above the high
      if(g_analysis.blocks[i].type == OB_BULLISH)
      {
         // Check recent closes
         for(int j = 0; j < 3 && j < ArraySize(g_closeBuffer); j++)
         {
            if(g_closeBuffer[j] < g_analysis.blocks[i].lowPrice)
            {
               g_analysis.blocks[i].status = OB_MITIGATED;
               break;
            }
         }
      }
      else // Bearish OB
      {
         for(int j = 0; j < 3 && j < ArraySize(g_closeBuffer); j++)
         {
            if(g_closeBuffer[j] > g_analysis.blocks[i].highPrice)
            {
               g_analysis.blocks[i].status = OB_MITIGATED;
               break;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Volume Profile                                          |
//+------------------------------------------------------------------+
void CalculateVolumeProfile(int barCount)
{
   int lookback = MathMin(barCount, InpVPLookback);

   // Find high and low of the lookback period
   double profileHigh = g_highBuffer[ArrayMaximum(g_highBuffer, 0, lookback)];
   double profileLow = g_lowBuffer[ArrayMinimum(g_lowBuffer, 0, lookback)];

   g_analysis.volumeProfile.highPrice = profileHigh;
   g_analysis.volumeProfile.lowPrice = profileLow;

   double range = profileHigh - profileLow;
   double rowHeight = range / InpVPRows;

   // Reset volume levels
   ArrayResize(g_analysis.volumeProfile.levels, InpVPRows);
   for(int i = 0; i < InpVPRows; i++)
   {
      g_analysis.volumeProfile.levels[i].priceLevel = profileLow + (i + 0.5) * rowHeight;
      g_analysis.volumeProfile.levels[i].volume = 0;
      g_analysis.volumeProfile.levels[i].percentage = 0;
      g_analysis.volumeProfile.levels[i].isPOC = false;
      g_analysis.volumeProfile.levels[i].isInVA = false;
   }

   // Accumulate volume at each price level
   long totalVolume = 0;

   for(int bar = 0; bar < lookback; bar++)
   {
      double barHigh = g_highBuffer[bar];
      double barLow = g_lowBuffer[bar];
      long barVolume = g_volumeBuffer[bar];

      // Distribute volume across price levels that the bar touched
      for(int row = 0; row < InpVPRows; row++)
      {
         double levelLow = profileLow + row * rowHeight;
         double levelHigh = levelLow + rowHeight;

         // Check if bar touched this level
         if(barLow <= levelHigh && barHigh >= levelLow)
         {
            // Calculate overlap proportion
            double overlapLow = MathMax(barLow, levelLow);
            double overlapHigh = MathMin(barHigh, levelHigh);
            double overlap = overlapHigh - overlapLow;
            double barRange = barHigh - barLow;

            if(barRange > 0)
            {
               double proportion = overlap / barRange;
               g_analysis.volumeProfile.levels[row].volume += (long)(barVolume * proportion);
            }
            else
            {
               g_analysis.volumeProfile.levels[row].volume += barVolume;
            }
         }
      }
      totalVolume += barVolume;
   }

   g_analysis.volumeProfile.totalVolume = totalVolume;

   // Find POC (Point of Control) - highest volume level
   long maxVolume = 0;
   int pocIndex = 0;

   for(int i = 0; i < InpVPRows; i++)
   {
      if(g_analysis.volumeProfile.levels[i].volume > maxVolume)
      {
         maxVolume = g_analysis.volumeProfile.levels[i].volume;
         pocIndex = i;
      }

      // Calculate percentage
      if(totalVolume > 0)
         g_analysis.volumeProfile.levels[i].percentage =
            (double)g_analysis.volumeProfile.levels[i].volume / totalVolume * 100.0;
   }

   g_analysis.volumeProfile.levels[pocIndex].isPOC = true;
   g_analysis.volumeProfile.pocPrice = g_analysis.volumeProfile.levels[pocIndex].priceLevel;
   g_analysis.volumeProfile.pocVolume = maxVolume;

   // Calculate Value Area (VA)
   // VA contains ~70% of the total volume, centered around POC
   long targetVolume = (long)(totalVolume * InpVAPercent / 100.0);
   long vaVolume = g_analysis.volumeProfile.levels[pocIndex].volume;

   int vaHighIdx = pocIndex;
   int vaLowIdx = pocIndex;

   g_analysis.volumeProfile.levels[pocIndex].isInVA = true;

   // Expand VA up and down until we reach target volume
   while(vaVolume < targetVolume)
   {
      long aboveVolume = 0;
      long belowVolume = 0;

      if(vaHighIdx < InpVPRows - 1)
         aboveVolume = g_analysis.volumeProfile.levels[vaHighIdx + 1].volume;
      if(vaLowIdx > 0)
         belowVolume = g_analysis.volumeProfile.levels[vaLowIdx - 1].volume;

      if(aboveVolume == 0 && belowVolume == 0)
         break;

      // Add the side with higher volume
      if(aboveVolume >= belowVolume && vaHighIdx < InpVPRows - 1)
      {
         vaHighIdx++;
         g_analysis.volumeProfile.levels[vaHighIdx].isInVA = true;
         vaVolume += aboveVolume;
      }
      else if(vaLowIdx > 0)
      {
         vaLowIdx--;
         g_analysis.volumeProfile.levels[vaLowIdx].isInVA = true;
         vaVolume += belowVolume;
      }
      else
      {
         break;
      }
   }

   // Set VAH and VAL prices
   g_analysis.volumeProfile.vahPrice = profileLow + (vaHighIdx + 1) * rowHeight;
   g_analysis.volumeProfile.valPrice = profileLow + vaLowIdx * rowHeight;
   g_analysis.volumeProfile.lastUpdate = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Calculate OB Analysis                                             |
//+------------------------------------------------------------------+
void CalculateOBAnalysis()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int count = ArraySize(g_analysis.blocks);

   // Reset counters
   g_analysis.bullishCount = 0;
   g_analysis.bearishCount = 0;
   g_analysis.mitigatedCount = 0;
   g_analysis.priceInBullishOB = false;
   g_analysis.priceInBearishOB = false;

   double nearestBullishDist = DBL_MAX;
   double nearestBearishDist = DBL_MAX;

   for(int i = 0; i < count; i++)
   {
      OrderBlock ob = g_analysis.blocks[i];

      if(ob.status != OB_MITIGATED)
      {
         if(ob.type == OB_BULLISH)
            g_analysis.bullishCount++;
         else
            g_analysis.bearishCount++;

         // Check if price is in this OB
         if(currentPrice >= ob.lowPrice && currentPrice <= ob.highPrice)
         {
            if(ob.type == OB_BULLISH)
               g_analysis.priceInBullishOB = true;
            else
               g_analysis.priceInBearishOB = true;
         }

         // Find nearest OBs
         double distToMid = MathAbs(currentPrice - ob.midPrice);

         if(ob.type == OB_BULLISH && distToMid < nearestBullishDist)
         {
            nearestBullishDist = distToMid;
            g_analysis.nearestBullish = ob;
         }
         else if(ob.type == OB_BEARISH && distToMid < nearestBearishDist)
         {
            nearestBearishDist = distToMid;
            g_analysis.nearestBearish = ob;
         }
      }
      else
      {
         g_analysis.mitigatedCount++;
      }
   }

   // Determine overall bias
   if(g_analysis.bullishCount > g_analysis.bearishCount + 1)
      g_analysis.obBias = BIAS_BULLISH;
   else if(g_analysis.bearishCount > g_analysis.bullishCount + 1)
      g_analysis.obBias = BIAS_BEARISH;
   else
      g_analysis.obBias = BIAS_NEUTRAL;
}

//+------------------------------------------------------------------+
//| Generate Recommendation                                           |
//+------------------------------------------------------------------+
void GenerateRecommendation()
{
   string rec = "";
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Priority 1: Price is inside an Order Block
   if(g_analysis.priceInBullishOB)
   {
      rec = "BUY ZONE - Price in Bullish OB (institutional demand)";
   }
   else if(g_analysis.priceInBearishOB)
   {
      rec = "SELL ZONE - Price in Bearish OB (institutional supply)";
   }
   // Priority 2: Volume Profile analysis
   else if(InpDrawVP)
   {
      double vah = g_analysis.volumeProfile.vahPrice;
      double val = g_analysis.volumeProfile.valPrice;
      double poc = g_analysis.volumeProfile.pocPrice;

      // Price above VAH - potential rejection
      if(currentPrice > vah)
      {
         rec = "CAUTION - Price above Value Area High (potential rejection)";
      }
      // Price below VAL - potential support
      else if(currentPrice < val)
      {
         rec = "WATCH BUY - Price below Value Area Low (potential support)";
      }
      // Price near POC
      else if(MathAbs(currentPrice - poc) / g_pipValue < 20)
      {
         rec = "NEUTRAL - Price at Point of Control (high liquidity)";
      }
      // Price in Value Area
      else if(currentPrice >= val && currentPrice <= vah)
      {
         if(currentPrice > poc)
            rec = "WATCH - Price in upper Value Area";
         else
            rec = "WATCH - Price in lower Value Area";
      }
   }
   // Priority 3: Nearest OB approach
   else if(g_analysis.bullishCount > 0 || g_analysis.bearishCount > 0)
   {
      // Check distance to nearest bullish OB (below price)
      if(g_analysis.bullishCount > 0 &&
         g_analysis.nearestBullish.highPrice < currentPrice)
      {
         double distPips = (currentPrice - g_analysis.nearestBullish.highPrice) / g_pipValue;
         if(distPips < 50)
         {
            rec = "WATCH BUY - Approaching Bullish OB (" +
                  DoubleToString(distPips, 1) + " pips)";
         }
      }

      // Check distance to nearest bearish OB (above price)
      if(rec == "" && g_analysis.bearishCount > 0 &&
         g_analysis.nearestBearish.lowPrice > currentPrice)
      {
         double distPips = (g_analysis.nearestBearish.lowPrice - currentPrice) / g_pipValue;
         if(distPips < 50)
         {
            rec = "WATCH SELL - Approaching Bearish OB (" +
                  DoubleToString(distPips, 1) + " pips)";
         }
      }
   }

   if(rec == "")
   {
      if(g_analysis.obBias == BIAS_BULLISH)
         rec = "BULLISH BIAS - More demand OBs active";
      else if(g_analysis.obBias == BIAS_BEARISH)
         rec = "BEARISH BIAS - More supply OBs active";
      else
         rec = "NEUTRAL - No clear institutional bias";
   }

   g_analysis.recommendation = rec;
}

//+------------------------------------------------------------------+
//| Update OB Drawings                                                |
//+------------------------------------------------------------------+
void UpdateOBDrawings()
{
   int count = ArraySize(g_analysis.blocks);

   for(int i = 0; i < count; i++)
   {
      OrderBlock ob = g_analysis.blocks[i];

      // Determine color
      color obColor;
      if(ob.status == OB_MITIGATED)
         obColor = InpMitigatedOBColor;
      else if(ob.type == OB_BULLISH)
         obColor = InpBullishOBColor;
      else
         obColor = InpBearishOBColor;

      datetime endTime = TimeCurrent() + PeriodSeconds(InpOBTimeframe) * 20;

      if(ObjectFind(0, ob.objName) < 0)
      {
         ObjectCreate(0, ob.objName, OBJ_RECTANGLE, 0,
                     ob.timeCreated, ob.highPrice,
                     endTime, ob.lowPrice);
      }

      ObjectSetInteger(0, ob.objName, OBJPROP_COLOR, obColor);
      ObjectSetInteger(0, ob.objName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, ob.objName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, ob.objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, ob.objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, ob.objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, ob.objName, OBJPROP_TIME, 1, endTime);
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Update Volume Profile Drawings                                    |
//+------------------------------------------------------------------+
void UpdateVolumeProfileDrawings()
{
   // Delete old VP objects
   ObjectsDeleteAll(0, "VP_");

   if(!InpDrawVP) return;

   int numRows = ArraySize(g_analysis.volumeProfile.levels);
   if(numRows == 0) return;

   // Find max volume for scaling
   long maxVol = 0;
   for(int i = 0; i < numRows; i++)
   {
      if(g_analysis.volumeProfile.levels[i].volume > maxVol)
         maxVol = g_analysis.volumeProfile.levels[i].volume;
   }

   if(maxVol == 0) return;

   // Draw volume histogram
   datetime vpStartTime = iTime(_Symbol, InpOBTimeframe, InpVPLookback);
   int maxBarWidth = 30;  // Max width in bars

   for(int i = 0; i < numRows; i++)
   {
      VolumeLevel level = g_analysis.volumeProfile.levels[i];
      double range = g_analysis.volumeProfile.highPrice - g_analysis.volumeProfile.lowPrice;
      double rowHeight = range / InpVPRows;

      double priceHigh = level.priceLevel + rowHeight / 2.0;
      double priceLow = level.priceLevel - rowHeight / 2.0;

      // Calculate bar width based on volume
      double volRatio = (double)level.volume / maxVol;
      int barBars = (int)(maxBarWidth * volRatio);
      if(barBars < 1) barBars = 1;

      datetime barEndTime = vpStartTime - PeriodSeconds(InpOBTimeframe) * barBars;

      string objName = "VP_Row_" + IntegerToString(i);
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0,
                  vpStartTime, priceHigh,
                  barEndTime, priceLow);

      color barColor;
      if(level.isPOC)
         barColor = InpPOCColor;
      else if(level.isInVA)
         barColor = InpVAColor;
      else
         barColor = clrDimGray;

      ObjectSetInteger(0, objName, OBJPROP_COLOR, barColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   }

   // Draw POC line
   ObjectCreate(0, "VP_POC", OBJ_HLINE, 0, 0, g_analysis.volumeProfile.pocPrice);
   ObjectSetInteger(0, "VP_POC", OBJPROP_COLOR, InpPOCColor);
   ObjectSetInteger(0, "VP_POC", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "VP_POC", OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, "VP_POC", OBJPROP_SELECTABLE, false);

   // Draw VAH and VAL lines
   ObjectCreate(0, "VP_VAH", OBJ_HLINE, 0, 0, g_analysis.volumeProfile.vahPrice);
   ObjectSetInteger(0, "VP_VAH", OBJPROP_COLOR, clrDarkGreen);
   ObjectSetInteger(0, "VP_VAH", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "VP_VAH", OBJPROP_SELECTABLE, false);

   ObjectCreate(0, "VP_VAL", OBJ_HLINE, 0, 0, g_analysis.volumeProfile.valPrice);
   ObjectSetInteger(0, "VP_VAL", OBJPROP_COLOR, clrDarkRed);
   ObjectSetInteger(0, "VP_VAL", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "VP_VAL", OBJPROP_SELECTABLE, false);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete All OB Objects                                             |
//+------------------------------------------------------------------+
void DeleteAllOBObjects()
{
   int count = ArraySize(g_analysis.blocks);
   for(int i = 0; i < count; i++)
   {
      ObjectDelete(0, g_analysis.blocks[i].objName);
   }
   ObjectsDeleteAll(0, "OB_");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Delete Volume Profile Objects                                     |
//+------------------------------------------------------------------+
void DeleteVolumeProfileObjects()
{
   ObjectsDeleteAll(0, "VP_");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Print OB Report                                                   |
//+------------------------------------------------------------------+
void PrintOBReport()
{
   Print("");
   Print("=================================================");
   Print("    ORDER BLOCKS + VOLUME PROFILE (Section 8)    ");
   Print("=================================================");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", TimeframeToString(InpOBTimeframe));
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Current Price: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), g_digits));
   Print("-------------------------------------------------");

   Print("ORDER BLOCKS SUMMARY:");
   Print("  Active Bullish OBs: ", g_analysis.bullishCount);
   Print("  Active Bearish OBs: ", g_analysis.bearishCount);
   Print("  Mitigated OBs: ", g_analysis.mitigatedCount);
   Print("  Overall Bias: ", TrendBiasToString(g_analysis.obBias));
   Print("-------------------------------------------------");

   // Print active OBs
   int count = ArraySize(g_analysis.blocks);
   if(count > 0)
   {
      Print("ACTIVE ORDER BLOCKS:");
      for(int i = 0; i < count; i++)
      {
         if(g_analysis.blocks[i].status != OB_MITIGATED)
         {
            string typeStr = (g_analysis.blocks[i].type == OB_BULLISH) ? "BULLISH" : "BEARISH";
            string statusStr = (g_analysis.blocks[i].status == OB_FRESH) ? "Fresh" : "Tested";
            Print("  ", typeStr, " OB:");
            Print("    Range: ", DoubleToString(g_analysis.blocks[i].lowPrice, g_digits),
                  " - ", DoubleToString(g_analysis.blocks[i].highPrice, g_digits));
            Print("    Size: ", DoubleToString(g_analysis.blocks[i].sizePips, 1), " pips");
            Print("    Status: ", statusStr);
            if(g_analysis.blocks[i].timesTestedCount > 0)
               Print("    Times Tested: ", g_analysis.blocks[i].timesTestedCount);
         }
      }
      Print("-------------------------------------------------");
   }

   // Volume Profile
   if(InpDrawVP)
   {
      Print("VOLUME PROFILE:");
      Print("  POC (Point of Control): ", DoubleToString(g_analysis.volumeProfile.pocPrice, g_digits));
      Print("  Value Area High: ", DoubleToString(g_analysis.volumeProfile.vahPrice, g_digits));
      Print("  Value Area Low: ", DoubleToString(g_analysis.volumeProfile.valPrice, g_digits));
      Print("  Profile Range: ", DoubleToString(g_analysis.volumeProfile.lowPrice, g_digits),
            " - ", DoubleToString(g_analysis.volumeProfile.highPrice, g_digits));
      Print("-------------------------------------------------");
   }

   // Price Position
   Print("PRICE POSITION:");
   if(g_analysis.priceInBullishOB)
      Print("  >> Price is INSIDE a Bullish Order Block");
   else if(g_analysis.priceInBearishOB)
      Print("  >> Price is INSIDE a Bearish Order Block");
   else
      Print("  Price is outside all Order Blocks");
   Print("-------------------------------------------------");

   Print("RECOMMENDATION:");
   Print("  ", g_analysis.recommendation);
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
   Print("     SWING TRADER PRO - SECTION 8                ");
   Print("     ORDER BLOCKS + VOLUME PROFILE               ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol);
   Print("TIMEFRAME: ", TimeframeToString(InpOBTimeframe));
   Print("-------------------------------------------------");
   Print("ORDER BLOCK SETTINGS:");
   Print("  Lookback Bars: ", InpOBLookback);
   Print("  Max OBs Tracked: ", InpMaxOrderBlocks);
   Print("  Min OB Size: ", InpMinOBSize, " pips");
   Print("  Impulse Required: ", InpRequireImpulse ? "Yes" : "No");
   Print("-------------------------------------------------");
   Print("VOLUME PROFILE SETTINGS:");
   Print("  Lookback Bars: ", InpVPLookback);
   Print("  Price Rows: ", InpVPRows);
   Print("  Value Area: ", InpVAPercent, "%");
   Print("-------------------------------------------------");
   Print("INTERPRETATION:");
   Print("  Bullish OB = Institutional demand zone (buy)");
   Print("  Bearish OB = Institutional supply zone (sell)");
   Print("  POC = Highest traded price level");
   Print("  Value Area = 70% of volume traded");
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

   CreateRectangle(g_panelName + "_bg", x, y, 300, 280, clrBlack, 200);

   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "ORDER BLOCKS + VOLUME", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "--------------------------------", clrGray, 8, "Courier New");

   int yOff = 40;

   // OB Counts
   CreateLabel(g_panelName + "_bull_label", x + 10, y + yOff, "Bullish OBs:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_bull_value", x + 150, y + yOff, "0", clrLimeGreen, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_bear_label", x + 10, y + yOff, "Bearish OBs:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_bear_value", x + 150, y + yOff, "0", clrRed, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_mit_label", x + 10, y + yOff, "Mitigated:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_mit_value", x + 150, y + yOff, "0", clrGray, 9, "Arial");
   yOff += 22;

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOff,
               "--------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Volume Profile
   CreateLabel(g_panelName + "_vp_title", x + 10, y + yOff, "Volume Profile:", clrCyan, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_poc_label", x + 20, y + yOff, "POC:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_poc_value", x + 100, y + yOff, "--", clrGold, 8, "Arial");
   yOff += 16;

   CreateLabel(g_panelName + "_vah_label", x + 20, y + yOff, "VAH:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_vah_value", x + 100, y + yOff, "--", clrLimeGreen, 8, "Arial");
   yOff += 16;

   CreateLabel(g_panelName + "_val_label", x + 20, y + yOff, "VAL:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_val_value", x + 100, y + yOff, "--", clrRed, 8, "Arial");
   yOff += 22;

   CreateLabel(g_panelName + "_sep3", x + 10, y + yOff,
               "--------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Price Position
   CreateLabel(g_panelName + "_pos_label", x + 10, y + yOff, "Price Position:", clrCyan, 9, "Arial Bold");
   yOff += 18;
   CreateLabel(g_panelName + "_pos_value", x + 20, y + yOff, "Outside OBs", clrYellow, 9, "Arial");
   yOff += 22;

   // Bias and Recommendation
   CreateLabel(g_panelName + "_bias_label", x + 10, y + yOff, "OB Bias:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_bias_value", x + 150, y + yOff, "NEUTRAL", clrGray, 9, "Arial Bold");
   yOff += 22;

   CreateLabel(g_panelName + "_rec_label", x + 10, y + yOff, "Signal:", clrWhite, 10, "Arial Bold");
   CreateLabel(g_panelName + "_rec_value", x + 10, y + yOff + 18, "ANALYZING...", clrYellow, 9, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel) return;

   // Update OB counts
   ObjectSetString(0, g_panelName + "_bull_value", OBJPROP_TEXT,
                   IntegerToString(g_analysis.bullishCount));
   ObjectSetString(0, g_panelName + "_bear_value", OBJPROP_TEXT,
                   IntegerToString(g_analysis.bearishCount));
   ObjectSetString(0, g_panelName + "_mit_value", OBJPROP_TEXT,
                   IntegerToString(g_analysis.mitigatedCount));

   // Update Volume Profile
   if(InpDrawVP)
   {
      ObjectSetString(0, g_panelName + "_poc_value", OBJPROP_TEXT,
                      DoubleToString(g_analysis.volumeProfile.pocPrice, g_digits));
      ObjectSetString(0, g_panelName + "_vah_value", OBJPROP_TEXT,
                      DoubleToString(g_analysis.volumeProfile.vahPrice, g_digits));
      ObjectSetString(0, g_panelName + "_val_value", OBJPROP_TEXT,
                      DoubleToString(g_analysis.volumeProfile.valPrice, g_digits));
   }

   // Update price position
   string posText;
   color posColor;
   if(g_analysis.priceInBullishOB)
   {
      posText = "IN BULLISH OB";
      posColor = clrLimeGreen;
   }
   else if(g_analysis.priceInBearishOB)
   {
      posText = "IN BEARISH OB";
      posColor = clrRed;
   }
   else
   {
      posText = "Outside Order Blocks";
      posColor = clrGray;
   }
   ObjectSetString(0, g_panelName + "_pos_value", OBJPROP_TEXT, posText);
   ObjectSetInteger(0, g_panelName + "_pos_value", OBJPROP_COLOR, posColor);

   // Update bias
   string biasText = TrendBiasToString(g_analysis.obBias);
   color biasColor = clrGray;
   if(g_analysis.obBias == BIAS_BULLISH)
      biasColor = clrLimeGreen;
   else if(g_analysis.obBias == BIAS_BEARISH)
      biasColor = clrRed;

   ObjectSetString(0, g_panelName + "_bias_value", OBJPROP_TEXT, biasText);
   ObjectSetInteger(0, g_panelName + "_bias_value", OBJPROP_COLOR, biasColor);

   // Update recommendation
   color recColor = clrGray;
   if(StringFind(g_analysis.recommendation, "BUY") >= 0 ||
      StringFind(g_analysis.recommendation, "BULLISH") >= 0)
      recColor = clrLimeGreen;
   else if(StringFind(g_analysis.recommendation, "SELL") >= 0 ||
           StringFind(g_analysis.recommendation, "BEARISH") >= 0)
      recColor = clrRed;

   string recText = g_analysis.recommendation;
   if(StringLen(recText) > 35)
      recText = StringSubstr(recText, 0, 35) + "...";

   ObjectSetString(0, g_panelName + "_rec_value", OBJPROP_TEXT, recText);
   ObjectSetInteger(0, g_panelName + "_rec_value", OBJPROP_COLOR, recColor);

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
int GetOrderBlockCount() { return ArraySize(g_analysis.blocks); }
int GetBullishOBCount() { return g_analysis.bullishCount; }
int GetBearishOBCount() { return g_analysis.bearishCount; }
bool IsPriceInBullishOB() { return g_analysis.priceInBullishOB; }
bool IsPriceInBearishOB() { return g_analysis.priceInBearishOB; }
ENUM_TREND_BIAS GetOBBias() { return g_analysis.obBias; }
string GetOBRecommendation() { return g_analysis.recommendation; }

// Volume Profile getters
double GetPOCPrice() { return g_analysis.volumeProfile.pocPrice; }
double GetVAHPrice() { return g_analysis.volumeProfile.vahPrice; }
double GetVALPrice() { return g_analysis.volumeProfile.valPrice; }

// Get nearest OB zone
bool GetNearestBullishOB(double &high, double &low, double &mid)
{
   if(g_analysis.bullishCount == 0) return false;
   high = g_analysis.nearestBullish.highPrice;
   low = g_analysis.nearestBullish.lowPrice;
   mid = g_analysis.nearestBullish.midPrice;
   return true;
}

bool GetNearestBearishOB(double &high, double &low, double &mid)
{
   if(g_analysis.bearishCount == 0) return false;
   high = g_analysis.nearestBearish.highPrice;
   low = g_analysis.nearestBearish.lowPrice;
   mid = g_analysis.nearestBearish.midPrice;
   return true;
}
//+------------------------------------------------------------------+
