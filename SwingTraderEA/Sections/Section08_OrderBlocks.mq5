//+------------------------------------------------------------------+
//|                                       Section08_OrderBlocks.mq5  |
//|                                      SwingTrader Pro EA          |
//|                Section 8: Order Blocks + Volume Profile (v2.01)  |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "2.01"
#property description "Section 8: Order Blocks & Volume Profile v2.01"
#property description "Identifies institutional order blocks with scoring"
#property description "Volume validation, ATR thresholds, retest limits"
#property description "HVN/LVN identification for liquidity analysis"

//+------------------------------------------------------------------+
//| Modification History                                              |
//+------------------------------------------------------------------+
// 2025.12.25 v2.01 - Loosened OB detection criteria:
//                    - InpMinMoveMultiple: 2 → 1
//                    - InpRequireVolume: true → false
//                    - InpVolumeMultiplier: 1.2 → 1.0
//                    - Fixed duplicate struct error (OrderBlockV2, VolumeLevelV2)
// 2025.12.23 v2.00 - Initial release with scoring and volume validation
//+------------------------------------------------------------------+

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
input bool     InpUseATRSize          = true;     // Use ATR for OB Size Thresholds
input double   InpMinOBSizeATR        = 0.3;      // Min OB Size (ATR multiplier)
input double   InpMaxOBSizeATR        = 3.0;      // Max OB Size (ATR multiplier)
input double   InpMinOBSizePips       = 10.0;     // Min OB Size (pips) - if ATR disabled
input double   InpMaxOBSizePips       = 200.0;    // Max OB Size (pips) - if ATR disabled
input ENUM_TIMEFRAMES InpOBTimeframe  = PERIOD_H4; // Order Block Timeframe

input group "=== Order Block Validation ==="
input int      InpMinMoveMultiple     = 1;        // Min Move Multiple (xOB size) - loosened from 2
input bool     InpRequireImpulse      = true;     // Require Impulse Move
input int      InpImpulseCandles      = 3;        // Impulse Within N Candles
input bool     InpRequireVolume       = false;    // Require Above-Average Volume - disabled for more OBs
input double   InpVolumeMultiplier    = 1.0;      // Volume Multiplier (vs average) - loosened from 1.2
input int      InpVolumeAvgPeriod     = 20;       // Volume Average Period

input group "=== Order Block Mitigation ==="
input int      InpMaxRetests          = 3;        // Max Retests Before Invalid
input bool     InpMitigateOnWick      = false;    // Mitigate on Wick (vs Close)
input double   InpMitigationBuffer    = 0.2;      // Mitigation Buffer (ATR mult)

input group "=== ATR Settings ==="
input int      InpATRPeriod           = 14;       // ATR Period

input group "=== Volume Profile Settings ==="
input int      InpVPLookback          = 100;      // Volume Profile Lookback Bars
input int      InpVPRows              = 24;       // Number of Price Rows
input double   InpVAPercent           = 70.0;     // Value Area Percentage
input double   InpHVNThreshold        = 1.5;      // HVN Threshold (x average)
input double   InpLVNThreshold        = 0.5;      // LVN Threshold (x average)

input group "=== Visual Settings ==="
input bool     InpDrawOB              = true;     // Draw Order Blocks
input bool     InpDrawVP              = true;     // Draw Volume Profile
input bool     InpShowOBLabels        = true;     // Show OB Labels with Score
input color    InpBullishOBColor      = clrDodgerBlue;  // Bullish OB Color
input color    InpBearishOBColor      = clrCrimson;     // Bearish OB Color
input color    InpTestedOBColor       = clrDarkSlateGray; // Tested OB Color
input color    InpMitigatedOBColor    = clrDimGray;    // Mitigated OB Color
input color    InpPOCColor            = clrGold;        // POC Line Color
input color    InpVAColor             = clrDarkSlateGray; // Value Area Color
input color    InpHVNColor            = clrLimeGreen;   // High Volume Node Color
input color    InpLVNColor            = clrOrangeRed;   // Low Volume Node Color

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

enum ENUM_VP_NODE_TYPE
{
   NODE_NORMAL,            // Normal volume
   NODE_HVN,               // High Volume Node
   NODE_LVN                // Low Volume Node
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct OrderBlockV2
{
   ENUM_OB_TYPE     type;
   ENUM_OB_STATUS   status;
   double           highPrice;      // Top of OB zone
   double           lowPrice;       // Bottom of OB zone
   double           midPrice;       // Middle (50%) of OB
   double           sizePips;       // Size in pips
   double           sizeATR;        // Size as ATR multiple
   double           bodyHigh;       // Candle body high
   double           bodyLow;        // Candle body low
   long             volume;         // OB candle volume
   double           volumeRatio;    // vs average volume
   datetime         timeCreated;    // When OB was created
   int              barIndex;       // Bar index when created
   int              timesTestedCount; // How many times price touched
   int              score;          // Quality score (1-10)
   string           objName;        // Chart object name
   bool             isValid;        // Is this OB still valid
};

struct VolumeLevelV2
{
   double           priceLevel;     // Price at this level
   long             volume;         // Volume at this level
   double           percentage;     // Percentage of total volume
   bool             isPOC;          // Is Point of Control
   bool             isInVA;         // Is within Value Area
   ENUM_VP_NODE_TYPE nodeType;      // HVN, LVN, or Normal
};

struct VolumeProfile
{
   VolumeLevelV2    levels[];       // Volume levels array
   double           pocPrice;       // Point of Control price
   long             pocVolume;      // POC volume
   double           vahPrice;       // Value Area High
   double           valPrice;       // Value Area Low
   double           highPrice;      // Profile high
   double           lowPrice;       // Profile low
   long             totalVolume;    // Total volume in profile
   long             avgVolume;      // Average volume per level
   int              hvnCount;       // High Volume Nodes count
   int              lvnCount;       // Low Volume Nodes count
   datetime         lastUpdate;
   bool             needsRedraw;    // Performance: only redraw when needed
};

struct OrderBlockAnalysis
{
   OrderBlockV2     blocks[];             // Array of order blocks
   int              bullishCount;         // Active bullish OBs
   int              bearishCount;         // Active bearish OBs
   int              mitigatedCount;       // Mitigated OBs
   int              freshCount;           // Fresh OBs
   OrderBlockV2     nearestBullish;       // Nearest bullish OB
   OrderBlockV2     nearestBearish;       // Nearest bearish OB
   OrderBlockV2     strongestBullish;     // Highest scored bullish OB
   OrderBlockV2     strongestBearish;     // Highest scored bearish OB
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
// Symbol Info Cache
SymbolInfoCache   g_symbolInfo;

// ATR Handle and Buffer
int               g_atrHandle;
double            g_atrBuffer[];
double            g_currentATR = 0;
double            g_currentATRPips = 0;

// Volume average
double            g_avgVolume = 0;

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

// Performance tracking
datetime          g_lastVPUpdate = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize symbol info cache
   InitSymbolInfo(g_symbolInfo, _Symbol);

   string typeStr = "FOREX";
   if(g_symbolInfo.isGold) typeStr = "GOLD/XAU";
   else if(g_symbolInfo.isSilver) typeStr = "SILVER/XAG";
   else if(g_symbolInfo.isJPY) typeStr = "JPY PAIR";

   Print("Symbol Detection: ", _Symbol, " | Type: ", typeStr,
         " | Digits: ", g_symbolInfo.digits,
         " | PipSize: ", DoubleToString(g_symbolInfo.pipSize, 5));

   // Create ATR handle
   g_atrHandle = iATR(_Symbol, InpOBTimeframe, InpATRPeriod);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create ATR handle");
      return(INIT_FAILED);
   }

   // Initialize arrays as series
   ArraySetAsSeries(g_highBuffer, true);
   ArraySetAsSeries(g_lowBuffer, true);
   ArraySetAsSeries(g_closeBuffer, true);
   ArraySetAsSeries(g_openBuffer, true);
   ArraySetAsSeries(g_volumeBuffer, true);
   ArraySetAsSeries(g_atrBuffer, true);

   // Initialize arrays
   ArrayResize(g_analysis.blocks, 0);
   ArrayResize(g_analysis.volumeProfile.levels, InpVPRows);
   g_analysis.volumeProfile.needsRedraw = true;

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
   // Release ATR handle
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);

   // Remove OB drawings
   DeleteAllOBObjects();

   // Remove VP drawings
   DeleteVolumeProfileObjects();

   // Remove panel
   DeletePanel();

   Print("=================================================");
   Print("Order Blocks EA v2.00 Deinitialized");
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
      g_analysis.volumeProfile.needsRedraw = true;
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
   int barsNeeded = MathMax(InpOBLookback, InpVPLookback) + InpVolumeAvgPeriod + 10;
   int minBars = 30;

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

   // Get ATR
   if(CopyBuffer(g_atrHandle, 0, 0, 1, g_atrBuffer) < 1)
   {
      Print("WARNING: ATR data not ready");
      return;
   }
   g_currentATR = g_atrBuffer[0];
   g_currentATRPips = PointsToPips(g_symbolInfo, g_currentATR);

   // Calculate average volume
   CalculateAverageVolume(copied);

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

   if(InpDrawVP && g_analysis.volumeProfile.needsRedraw)
   {
      UpdateVolumeProfileDrawings();
      g_analysis.volumeProfile.needsRedraw = false;
   }

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
//| Calculate Average Volume                                          |
//+------------------------------------------------------------------+
void CalculateAverageVolume(int barCount)
{
   int period = MathMin(InpVolumeAvgPeriod, barCount);
   long totalVol = 0;

   for(int i = 0; i < period; i++)
   {
      totalVol += g_volumeBuffer[i];
   }

   g_avgVolume = (period > 0) ? (double)totalVol / period : 0;
}

//+------------------------------------------------------------------+
//| Detect Order Blocks with Volume Validation                        |
//+------------------------------------------------------------------+
void DetectOrderBlocks(int barCount)
{
   int maxCheck = MathMin(barCount - 5, InpOBLookback);

   // Calculate dynamic OB size thresholds
   double minOBSize, maxOBSize;
   if(InpUseATRSize)
   {
      minOBSize = g_currentATR * InpMinOBSizeATR;
      maxOBSize = g_currentATR * InpMaxOBSizeATR;
   }
   else
   {
      minOBSize = InpMinOBSizePips * g_symbolInfo.pipSize;
      maxOBSize = InpMaxOBSizePips * g_symbolInfo.pipSize;
   }

   for(int i = 3; i < maxCheck; i++)
   {
      // Check if this bar already has an OB recorded
      if(HasOBAtBar(i)) continue;

      // Get candle properties
      double open_i = g_openBuffer[i];
      double close_i = g_closeBuffer[i];
      double high_i = g_highBuffer[i];
      double low_i = g_lowBuffer[i];
      long volume_i = g_volumeBuffer[i];
      bool isBullishCandle = (close_i > open_i);
      bool isBearishCandle = (close_i < open_i);

      // Volume validation
      double volumeRatio = (g_avgVolume > 0) ? volume_i / g_avgVolume : 1.0;
      bool volumeOK = !InpRequireVolume || (volumeRatio >= InpVolumeMultiplier);

      // === BULLISH ORDER BLOCK ===
      // Last bearish candle before a strong bullish impulse move
      if(isBearishCandle && volumeOK)
      {
         // Check for bullish impulse in next candles
         bool impulseFound = false;
         double impulseHigh = 0;

         for(int j = i - 1; j >= i - InpImpulseCandles && j >= 0; j--)
         {
            if(g_highBuffer[j] > high_i)
            {
               impulseFound = true;
               impulseHigh = g_highBuffer[j];
               break;
            }
         }

         if(impulseFound)
         {
            double obSize = high_i - low_i;

            if(obSize >= minOBSize && obSize <= maxOBSize)
            {
               double moveSize = impulseHigh - high_i;
               if(!InpRequireImpulse || moveSize >= obSize * InpMinMoveMultiple)
               {
                  AddOrderBlock(OB_BULLISH, high_i, low_i, open_i, close_i, i, volume_i, volumeRatio);
               }
            }
         }
      }

      // === BEARISH ORDER BLOCK ===
      // Last bullish candle before a strong bearish impulse move
      if(isBullishCandle && volumeOK)
      {
         bool impulseFound = false;
         double impulseLow = DBL_MAX;

         for(int j = i - 1; j >= i - InpImpulseCandles && j >= 0; j--)
         {
            if(g_lowBuffer[j] < low_i)
            {
               impulseFound = true;
               impulseLow = g_lowBuffer[j];
               break;
            }
         }

         if(impulseFound)
         {
            double obSize = high_i - low_i;

            if(obSize >= minOBSize && obSize <= maxOBSize)
            {
               double moveSize = low_i - impulseLow;
               if(!InpRequireImpulse || moveSize >= obSize * InpMinMoveMultiple)
               {
                  AddOrderBlock(OB_BEARISH, high_i, low_i, open_i, close_i, i, volume_i, volumeRatio);
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
//| Add Order Block with Scoring                                      |
//+------------------------------------------------------------------+
void AddOrderBlock(ENUM_OB_TYPE type, double high, double low,
                   double open, double close, int barIndex,
                   long volume, double volumeRatio)
{
   // Check if we've reached max count
   int count = ArraySize(g_analysis.blocks);
   if(count >= InpMaxOrderBlocks)
   {
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
   OrderBlockV2 ob;
   ob.type = type;
   ob.status = OB_FRESH;
   ob.highPrice = high;
   ob.lowPrice = low;
   ob.midPrice = (high + low) / 2.0;
   ob.bodyHigh = MathMax(open, close);
   ob.bodyLow = MathMin(open, close);
   ob.sizePips = PointsToPips(g_symbolInfo, high - low);
   ob.sizeATR = (g_currentATR > 0) ? (high - low) / g_currentATR : 0;
   ob.volume = volume;
   ob.volumeRatio = volumeRatio;
   ob.timeCreated = iTime(_Symbol, InpOBTimeframe, barIndex);
   ob.barIndex = barIndex;
   ob.timesTestedCount = 0;
   ob.objName = "OB_" + IntegerToString(ob.timeCreated);
   ob.isValid = true;

   // Calculate score (1-10)
   ob.score = CalculateOBScore(ob);

   g_analysis.blocks[count] = ob;
}

//+------------------------------------------------------------------+
//| Calculate OB Quality Score (1-10)                                 |
//+------------------------------------------------------------------+
int CalculateOBScore(OrderBlockV2 &ob)
{
   double score = 5.0;  // Base score

   // Volume factor (+2 for high volume)
   if(ob.volumeRatio >= 2.0)
      score += 2.0;
   else if(ob.volumeRatio >= 1.5)
      score += 1.5;
   else if(ob.volumeRatio >= 1.2)
      score += 1.0;
   else if(ob.volumeRatio < 1.0)
      score -= 1.0;

   // Size factor (optimal is 0.5-1.5 ATR)
   if(ob.sizeATR >= 0.5 && ob.sizeATR <= 1.5)
      score += 1.5;
   else if(ob.sizeATR >= 0.3 && ob.sizeATR <= 2.0)
      score += 0.5;
   else
      score -= 0.5;

   // Freshness bonus (already fresh, +1)
   if(ob.status == OB_FRESH)
      score += 1.0;

   // Tested penalty
   if(ob.timesTestedCount > 0)
      score -= ob.timesTestedCount * 0.5;

   // Clamp to 1-10
   if(score < 1) score = 1;
   if(score > 10) score = 10;

   return (int)MathRound(score);
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

   // Delete chart objects
   ObjectDelete(0, g_analysis.blocks[index].objName);
   ObjectDelete(0, g_analysis.blocks[index].objName + "_label");

   // Shift array elements
   for(int i = index; i < count - 1; i++)
   {
      g_analysis.blocks[i] = g_analysis.blocks[i + 1];
   }

   // Resize array
   ArrayResize(g_analysis.blocks, count - 1);
}

//+------------------------------------------------------------------+
//| Check OB Mitigation with Retest Limit                             |
//+------------------------------------------------------------------+
void CheckOBMitigation()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double buffer = g_currentATR * InpMitigationBuffer;
   int count = ArraySize(g_analysis.blocks);
   bool needsRedraw = false;

   for(int i = 0; i < count; i++)
   {
      if(g_analysis.blocks[i].status == OB_MITIGATED) continue;

      double obHigh = g_analysis.blocks[i].highPrice;
      double obLow = g_analysis.blocks[i].lowPrice;

      // Check if price is inside the OB
      if(currentPrice >= obLow && currentPrice <= obHigh)
      {
         if(g_analysis.blocks[i].status == OB_FRESH)
         {
            g_analysis.blocks[i].status = OB_TESTED;
            g_analysis.blocks[i].timesTestedCount++;
            g_analysis.blocks[i].score = CalculateOBScore(g_analysis.blocks[i]);
            needsRedraw = true;

            if(InpPrintReport)
               Print("OB Tested: ", (g_analysis.blocks[i].type == OB_BULLISH ? "Bullish" : "Bearish"),
                     " at ", DoubleToString(g_analysis.blocks[i].midPrice, g_symbolInfo.digits),
                     " (Test #", g_analysis.blocks[i].timesTestedCount, ")");
         }
         else if(g_analysis.blocks[i].status == OB_TESTED)
         {
            // Track additional tests
            static datetime lastTestTime[];
            ArrayResize(lastTestTime, count);
            datetime barTime = iTime(_Symbol, InpOBTimeframe, 0);

            if(lastTestTime[i] != barTime)
            {
               g_analysis.blocks[i].timesTestedCount++;
               g_analysis.blocks[i].score = CalculateOBScore(g_analysis.blocks[i]);
               lastTestTime[i] = barTime;
               needsRedraw = true;
            }
         }
      }

      // Check for mitigation (exceeded max retests or price beyond zone)
      if(g_analysis.blocks[i].timesTestedCount >= InpMaxRetests)
      {
         g_analysis.blocks[i].status = OB_MITIGATED;
         needsRedraw = true;

         if(InpPrintReport)
            Print("OB Mitigated (Max Retests): ", (g_analysis.blocks[i].type == OB_BULLISH ? "Bullish" : "Bearish"));
         continue;
      }

      // Check price violation
      if(g_analysis.blocks[i].type == OB_BULLISH)
      {
         // Bullish OB: mitigated when price closes/wicks below the low
         double checkPrice = InpMitigateOnWick ? g_lowBuffer[0] : g_closeBuffer[0];
         if(checkPrice < obLow - buffer)
         {
            g_analysis.blocks[i].status = OB_MITIGATED;
            needsRedraw = true;

            if(InpPrintReport)
               Print("OB Mitigated (Price Break): Bullish OB at ",
                     DoubleToString(g_analysis.blocks[i].midPrice, g_symbolInfo.digits));
         }
      }
      else // Bearish OB
      {
         double checkPrice = InpMitigateOnWick ? g_highBuffer[0] : g_closeBuffer[0];
         if(checkPrice > obHigh + buffer)
         {
            g_analysis.blocks[i].status = OB_MITIGATED;
            needsRedraw = true;

            if(InpPrintReport)
               Print("OB Mitigated (Price Break): Bearish OB at ",
                     DoubleToString(g_analysis.blocks[i].midPrice, g_symbolInfo.digits));
         }
      }
   }

   if(needsRedraw && InpDrawOB)
      UpdateOBDrawings();
}

//+------------------------------------------------------------------+
//| Calculate Volume Profile with HVN/LVN                             |
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
      g_analysis.volumeProfile.levels[i].nodeType = NODE_NORMAL;
   }

   // Accumulate volume at each price level
   long totalVolume = 0;

   for(int bar = 0; bar < lookback; bar++)
   {
      double barHigh = g_highBuffer[bar];
      double barLow = g_lowBuffer[bar];
      long barVolume = g_volumeBuffer[bar];

      for(int row = 0; row < InpVPRows; row++)
      {
         double levelLow = profileLow + row * rowHeight;
         double levelHigh = levelLow + rowHeight;

         if(barLow <= levelHigh && barHigh >= levelLow)
         {
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
   g_analysis.volumeProfile.avgVolume = (InpVPRows > 0) ? totalVolume / InpVPRows : 0;

   // Find POC and calculate percentages
   long maxVolume = 0;
   int pocIndex = 0;

   for(int i = 0; i < InpVPRows; i++)
   {
      if(g_analysis.volumeProfile.levels[i].volume > maxVolume)
      {
         maxVolume = g_analysis.volumeProfile.levels[i].volume;
         pocIndex = i;
      }

      if(totalVolume > 0)
         g_analysis.volumeProfile.levels[i].percentage =
            (double)g_analysis.volumeProfile.levels[i].volume / totalVolume * 100.0;
   }

   g_analysis.volumeProfile.levels[pocIndex].isPOC = true;
   g_analysis.volumeProfile.pocPrice = g_analysis.volumeProfile.levels[pocIndex].priceLevel;
   g_analysis.volumeProfile.pocVolume = maxVolume;

   // Identify HVN and LVN
   long avgLevelVol = g_analysis.volumeProfile.avgVolume;
   g_analysis.volumeProfile.hvnCount = 0;
   g_analysis.volumeProfile.lvnCount = 0;

   for(int i = 0; i < InpVPRows; i++)
   {
      long levelVol = g_analysis.volumeProfile.levels[i].volume;

      if(levelVol >= avgLevelVol * InpHVNThreshold)
      {
         g_analysis.volumeProfile.levels[i].nodeType = NODE_HVN;
         g_analysis.volumeProfile.hvnCount++;
      }
      else if(levelVol <= avgLevelVol * InpLVNThreshold)
      {
         g_analysis.volumeProfile.levels[i].nodeType = NODE_LVN;
         g_analysis.volumeProfile.lvnCount++;
      }
   }

   // Calculate Value Area
   long targetVolume = (long)(totalVolume * InpVAPercent / 100.0);
   long vaVolume = g_analysis.volumeProfile.levels[pocIndex].volume;

   int vaHighIdx = pocIndex;
   int vaLowIdx = pocIndex;

   g_analysis.volumeProfile.levels[pocIndex].isInVA = true;

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
   g_analysis.freshCount = 0;
   g_analysis.priceInBullishOB = false;
   g_analysis.priceInBearishOB = false;

   double nearestBullishDist = DBL_MAX;
   double nearestBearishDist = DBL_MAX;
   int highestBullishScore = 0;
   int highestBearishScore = 0;

   for(int i = 0; i < count; i++)
   {
      OrderBlockV2 ob = g_analysis.blocks[i];

      if(ob.status != OB_MITIGATED)
      {
         if(ob.type == OB_BULLISH)
         {
            g_analysis.bullishCount++;

            // Track strongest
            if(ob.score > highestBullishScore)
            {
               highestBullishScore = ob.score;
               g_analysis.strongestBullish = ob;
            }
         }
         else
         {
            g_analysis.bearishCount++;

            if(ob.score > highestBearishScore)
            {
               highestBearishScore = ob.score;
               g_analysis.strongestBearish = ob;
            }
         }

         if(ob.status == OB_FRESH)
            g_analysis.freshCount++;

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

   // Determine overall bias based on count and score
   int bullishScore = g_analysis.bullishCount * 2;
   int bearishScore = g_analysis.bearishCount * 2;

   if(highestBullishScore >= 7) bullishScore += 2;
   if(highestBearishScore >= 7) bearishScore += 2;

   if(bullishScore > bearishScore + 2)
      g_analysis.obBias = BIAS_BULLISH;
   else if(bearishScore > bullishScore + 2)
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
      int score = g_analysis.nearestBullish.score;
      rec = StringFormat("BUY ZONE - In Bullish OB (Score: %d/10)", score);
   }
   else if(g_analysis.priceInBearishOB)
   {
      int score = g_analysis.nearestBearish.score;
      rec = StringFormat("SELL ZONE - In Bearish OB (Score: %d/10)", score);
   }
   // Priority 2: Volume Profile analysis
   else if(InpDrawVP)
   {
      double vah = g_analysis.volumeProfile.vahPrice;
      double val = g_analysis.volumeProfile.valPrice;
      double poc = g_analysis.volumeProfile.pocPrice;

      // Check LVN zones (potential fast moves)
      for(int i = 0; i < InpVPRows; i++)
      {
         if(g_analysis.volumeProfile.levels[i].nodeType == NODE_LVN)
         {
            double lvnPrice = g_analysis.volumeProfile.levels[i].priceLevel;
            double dist = MathAbs(currentPrice - lvnPrice);
            if(dist < g_currentATR * 0.5)
            {
               rec = "CAUTION - Price at Low Volume Node (fast move possible)";
               break;
            }
         }
      }

      if(rec == "")
      {
         if(currentPrice > vah)
            rec = "CAUTION - Price above VAH (potential rejection)";
         else if(currentPrice < val)
            rec = "WATCH BUY - Price below VAL (potential support)";
         else if(MathAbs(currentPrice - poc) / g_symbolInfo.pipSize < 20)
            rec = "NEUTRAL - Price at POC (high liquidity)";
         else if(currentPrice >= val && currentPrice <= vah)
         {
            if(currentPrice > poc)
               rec = "WATCH - Price in upper Value Area";
            else
               rec = "WATCH - Price in lower Value Area";
         }
      }
   }
   // Priority 3: Nearest OB approach
   else if(g_analysis.bullishCount > 0 || g_analysis.bearishCount > 0)
   {
      if(g_analysis.bullishCount > 0 && g_analysis.nearestBullish.highPrice < currentPrice)
      {
         double distPips = PointsToPips(g_symbolInfo, currentPrice - g_analysis.nearestBullish.highPrice);
         if(distPips < g_currentATRPips)
         {
            rec = StringFormat("WATCH BUY - Approaching Bullish OB (%.1f pips, Score: %d)",
                              distPips, g_analysis.nearestBullish.score);
         }
      }

      if(rec == "" && g_analysis.bearishCount > 0 && g_analysis.nearestBearish.lowPrice > currentPrice)
      {
         double distPips = PointsToPips(g_symbolInfo, g_analysis.nearestBearish.lowPrice - currentPrice);
         if(distPips < g_currentATRPips)
         {
            rec = StringFormat("WATCH SELL - Approaching Bearish OB (%.1f pips, Score: %d)",
                              distPips, g_analysis.nearestBearish.score);
         }
      }
   }

   if(rec == "")
   {
      if(g_analysis.obBias == BIAS_BULLISH)
         rec = "BULLISH BIAS - More/stronger demand OBs";
      else if(g_analysis.obBias == BIAS_BEARISH)
         rec = "BEARISH BIAS - More/stronger supply OBs";
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
      OrderBlockV2 ob = g_analysis.blocks[i];

      // Determine color
      color obColor;
      if(ob.status == OB_MITIGATED)
         obColor = InpMitigatedOBColor;
      else if(ob.status == OB_TESTED)
         obColor = InpTestedOBColor;
      else if(ob.type == OB_BULLISH)
         obColor = InpBullishOBColor;
      else
         obColor = InpBearishOBColor;

      datetime endTime = TimeCurrent() + PeriodSeconds(InpOBTimeframe) * 20;

      // Create/update OB rectangle
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

      // Create/update OB label with score
      if(InpShowOBLabels)
      {
         string labelName = ob.objName + "_label";
         string typeStr = (ob.type == OB_BULLISH) ? "BUL" : "BER";
         string statusStr = "";
         if(ob.status == OB_FRESH) statusStr = "F";
         else if(ob.status == OB_TESTED) statusStr = "T" + IntegerToString(ob.timesTestedCount);
         else statusStr = "M";

         string labelText = StringFormat("%s [%d] %s", typeStr, ob.score, statusStr);

         if(ObjectFind(0, labelName) < 0)
         {
            ObjectCreate(0, labelName, OBJ_TEXT, 0, ob.timeCreated, ob.highPrice);
         }

         ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, obColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
         ObjectMove(0, labelName, 0, ob.timeCreated, ob.highPrice);
      }
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
   int maxBarWidth = 30;

   for(int i = 0; i < numRows; i++)
   {
      VolumeLevelV2 level = g_analysis.volumeProfile.levels[i];
      double range = g_analysis.volumeProfile.highPrice - g_analysis.volumeProfile.lowPrice;
      double rowHeight = range / InpVPRows;

      double priceHigh = level.priceLevel + rowHeight / 2.0;
      double priceLow = level.priceLevel - rowHeight / 2.0;

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
      else if(level.nodeType == NODE_HVN)
         barColor = InpHVNColor;
      else if(level.nodeType == NODE_LVN)
         barColor = InpLVNColor;
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

   g_lastVPUpdate = TimeCurrent();
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
      ObjectDelete(0, g_analysis.blocks[i].objName + "_label");
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
   Print("  ORDER BLOCKS + VOLUME PROFILE (Section 8 v2.0) ");
   Print("=================================================");
   Print("Symbol: ", _Symbol, " (", g_symbolInfo.isGold ? "GOLD" : "FOREX", ")");
   Print("Timeframe: ", TimeframeToString(InpOBTimeframe));
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("Current Price: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), g_symbolInfo.digits));
   Print("-------------------------------------------------");
   Print("ATR STATUS:");
   Print("  ATR Value: ", DoubleToString(g_currentATRPips, 1), " pips");
   Print("  ATR Raw: ", DoubleToString(g_currentATR, g_symbolInfo.digits));
   Print("  Avg Volume: ", DoubleToString(g_avgVolume, 0));
   Print("-------------------------------------------------");

   Print("ORDER BLOCKS SUMMARY:");
   Print("  Active Bullish OBs: ", g_analysis.bullishCount);
   Print("  Active Bearish OBs: ", g_analysis.bearishCount);
   Print("  Fresh OBs: ", g_analysis.freshCount);
   Print("  Mitigated OBs: ", g_analysis.mitigatedCount);
   Print("  Overall Bias: ", TrendBiasToString(g_analysis.obBias));
   Print("-------------------------------------------------");

   // Print active OBs with scores
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
            Print("  ", typeStr, " OB (Score: ", g_analysis.blocks[i].score, "/10):");
            Print("    Range: ", DoubleToString(g_analysis.blocks[i].lowPrice, g_symbolInfo.digits),
                  " - ", DoubleToString(g_analysis.blocks[i].highPrice, g_symbolInfo.digits));
            Print("    Size: ", DoubleToString(g_analysis.blocks[i].sizePips, 1), " pips (",
                  DoubleToString(g_analysis.blocks[i].sizeATR, 2), "x ATR)");
            Print("    Volume: ", DoubleToString(g_analysis.blocks[i].volumeRatio, 2), "x avg");
            Print("    Status: ", statusStr, " (Tests: ", g_analysis.blocks[i].timesTestedCount, "/", InpMaxRetests, ")");
         }
      }
      Print("-------------------------------------------------");
   }

   // Volume Profile
   if(InpDrawVP)
   {
      Print("VOLUME PROFILE:");
      Print("  POC: ", DoubleToString(g_analysis.volumeProfile.pocPrice, g_symbolInfo.digits));
      Print("  VAH: ", DoubleToString(g_analysis.volumeProfile.vahPrice, g_symbolInfo.digits));
      Print("  VAL: ", DoubleToString(g_analysis.volumeProfile.valPrice, g_symbolInfo.digits));
      Print("  HVN Count: ", g_analysis.volumeProfile.hvnCount);
      Print("  LVN Count: ", g_analysis.volumeProfile.lvnCount);
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
   Print("     SWING TRADER PRO - SECTION 8 (v2.0)         ");
   Print("     ORDER BLOCKS + VOLUME PROFILE               ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL DETECTION:");
   Print("  Symbol: ", _Symbol);
   string typeStr = "Standard Forex";
   if(g_symbolInfo.isGold) typeStr = "GOLD/XAU";
   else if(g_symbolInfo.isSilver) typeStr = "SILVER/XAG";
   else if(g_symbolInfo.isJPY) typeStr = "JPY Pair";
   Print("  Type: ", typeStr);
   Print("  Digits: ", g_symbolInfo.digits);
   Print("  Pip Size: ", DoubleToString(g_symbolInfo.pipSize, 5));
   Print("-------------------------------------------------");
   Print("TIMEFRAME: ", TimeframeToString(InpOBTimeframe));
   Print("-------------------------------------------------");
   Print("ORDER BLOCK SETTINGS:");
   Print("  Lookback Bars: ", InpOBLookback);
   Print("  Max OBs Tracked: ", InpMaxOrderBlocks);
   Print("  Use ATR Sizing: ", InpUseATRSize ? "YES" : "NO");
   if(InpUseATRSize)
   {
      Print("  Min OB Size: ", DoubleToString(InpMinOBSizeATR, 1), "x ATR");
      Print("  Max OB Size: ", DoubleToString(InpMaxOBSizeATR, 1), "x ATR");
   }
   else
   {
      Print("  Min OB Size: ", InpMinOBSizePips, " pips");
      Print("  Max OB Size: ", InpMaxOBSizePips, " pips");
   }
   Print("  Impulse Required: ", InpRequireImpulse ? "YES" : "NO");
   Print("  Volume Validation: ", InpRequireVolume ? "YES" : "NO");
   if(InpRequireVolume)
      Print("  Volume Multiplier: ", DoubleToString(InpVolumeMultiplier, 1), "x avg");
   Print("-------------------------------------------------");
   Print("MITIGATION SETTINGS:");
   Print("  Max Retests: ", InpMaxRetests);
   Print("  Mitigate On: ", InpMitigateOnWick ? "Wick" : "Close");
   Print("  Buffer: ", DoubleToString(InpMitigationBuffer, 1), "x ATR");
   Print("-------------------------------------------------");
   Print("VOLUME PROFILE SETTINGS:");
   Print("  Lookback Bars: ", InpVPLookback);
   Print("  Price Rows: ", InpVPRows);
   Print("  Value Area: ", InpVAPercent, "%");
   Print("  HVN Threshold: ", DoubleToString(InpHVNThreshold, 1), "x avg");
   Print("  LVN Threshold: ", DoubleToString(InpLVNThreshold, 1), "x avg");
   Print("-------------------------------------------------");
   Print("SCORING FACTORS:");
   Print("  Volume (>1.5x = +1.5, >2x = +2)");
   Print("  Size (0.5-1.5 ATR = +1.5)");
   Print("  Freshness (+1 for fresh)");
   Print("  Retests (-0.5 per test)");
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

   CreateRectangle(g_panelName + "_bg", x, y, 320, 340, clrBlack, 200);

   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "ORDER BLOCKS v2.0", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "------------------------------------", clrGray, 8, "Courier New");

   int yOff = 40;

   // ATR
   CreateLabel(g_panelName + "_atr_label", x + 10, y + yOff, "ATR:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_atr_value", x + 150, y + yOff, "-- pips", clrYellow, 9, "Arial");
   yOff += 18;

   // OB Counts
   CreateLabel(g_panelName + "_bull_label", x + 10, y + yOff, "Bullish OBs:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_bull_value", x + 150, y + yOff, "0", clrLimeGreen, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_bear_label", x + 10, y + yOff, "Bearish OBs:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_bear_value", x + 150, y + yOff, "0", clrRed, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_fresh_label", x + 10, y + yOff, "Fresh OBs:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_fresh_value", x + 150, y + yOff, "0", clrCyan, 9, "Arial");
   yOff += 18;

   CreateLabel(g_panelName + "_mit_label", x + 10, y + yOff, "Mitigated:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_mit_value", x + 150, y + yOff, "0", clrGray, 9, "Arial");
   yOff += 22;

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Strongest OB
   CreateLabel(g_panelName + "_str_title", x + 10, y + yOff, "Strongest OBs:", clrCyan, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_str_bull", x + 20, y + yOff, "Bull: --", clrLimeGreen, 8, "Arial");
   yOff += 16;

   CreateLabel(g_panelName + "_str_bear", x + 20, y + yOff, "Bear: --", clrRed, 8, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_sep3", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Volume Profile
   CreateLabel(g_panelName + "_vp_title", x + 10, y + yOff, "Volume Profile:", clrCyan, 9, "Arial Bold");
   yOff += 18;

   CreateLabel(g_panelName + "_poc_label", x + 20, y + yOff, "POC:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_poc_value", x + 100, y + yOff, "--", clrGold, 8, "Arial");
   yOff += 16;

   CreateLabel(g_panelName + "_hvn_label", x + 20, y + yOff, "HVN/LVN:", clrWhite, 8, "Arial");
   CreateLabel(g_panelName + "_hvn_value", x + 100, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 20;

   CreateLabel(g_panelName + "_sep4", x + 10, y + yOff,
               "------------------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Price Position
   CreateLabel(g_panelName + "_pos_label", x + 10, y + yOff, "Position:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_pos_value", x + 100, y + yOff, "Outside OBs", clrYellow, 9, "Arial");
   yOff += 20;

   // Bias and Recommendation
   CreateLabel(g_panelName + "_bias_label", x + 10, y + yOff, "OB Bias:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_bias_value", x + 100, y + yOff, "NEUTRAL", clrGray, 9, "Arial Bold");
   yOff += 22;

   CreateLabel(g_panelName + "_rec_label", x + 10, y + yOff, "Signal:", clrWhite, 10, "Arial Bold");
   yOff += 18;
   CreateLabel(g_panelName + "_rec_value", x + 10, y + yOff, "ANALYZING...", clrYellow, 9, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel) return;

   // Update ATR
   ObjectSetString(0, g_panelName + "_atr_value", OBJPROP_TEXT,
                   DoubleToString(g_currentATRPips, 1) + " pips");

   // Update OB counts
   ObjectSetString(0, g_panelName + "_bull_value", OBJPROP_TEXT,
                   IntegerToString(g_analysis.bullishCount));
   ObjectSetString(0, g_panelName + "_bear_value", OBJPROP_TEXT,
                   IntegerToString(g_analysis.bearishCount));
   ObjectSetString(0, g_panelName + "_fresh_value", OBJPROP_TEXT,
                   IntegerToString(g_analysis.freshCount));
   ObjectSetString(0, g_panelName + "_mit_value", OBJPROP_TEXT,
                   IntegerToString(g_analysis.mitigatedCount));

   // Update strongest OBs
   if(g_analysis.bullishCount > 0)
   {
      ObjectSetString(0, g_panelName + "_str_bull", OBJPROP_TEXT,
                      StringFormat("Bull: Score %d at %.0f",
                                   g_analysis.strongestBullish.score,
                                   g_analysis.strongestBullish.midPrice));
   }
   else
   {
      ObjectSetString(0, g_panelName + "_str_bull", OBJPROP_TEXT, "Bull: None");
   }

   if(g_analysis.bearishCount > 0)
   {
      ObjectSetString(0, g_panelName + "_str_bear", OBJPROP_TEXT,
                      StringFormat("Bear: Score %d at %.0f",
                                   g_analysis.strongestBearish.score,
                                   g_analysis.strongestBearish.midPrice));
   }
   else
   {
      ObjectSetString(0, g_panelName + "_str_bear", OBJPROP_TEXT, "Bear: None");
   }

   // Update Volume Profile
   if(InpDrawVP)
   {
      ObjectSetString(0, g_panelName + "_poc_value", OBJPROP_TEXT,
                      DoubleToString(g_analysis.volumeProfile.pocPrice, g_symbolInfo.digits));
      ObjectSetString(0, g_panelName + "_hvn_value", OBJPROP_TEXT,
                      IntegerToString(g_analysis.volumeProfile.hvnCount) + "/" +
                      IntegerToString(g_analysis.volumeProfile.lvnCount));
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
      posText = "Outside OBs";
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
   if(StringLen(recText) > 40)
      recText = StringSubstr(recText, 0, 40) + "...";

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
int GetFreshOBCount() { return g_analysis.freshCount; }
bool IsPriceInBullishOB() { return g_analysis.priceInBullishOB; }
bool IsPriceInBearishOB() { return g_analysis.priceInBearishOB; }
ENUM_TREND_BIAS GetOBBias() { return g_analysis.obBias; }
string GetOBRecommendation() { return g_analysis.recommendation; }
double GetATRPips() { return g_currentATRPips; }

// Volume Profile getters
double GetPOCPrice() { return g_analysis.volumeProfile.pocPrice; }
double GetVAHPrice() { return g_analysis.volumeProfile.vahPrice; }
double GetVALPrice() { return g_analysis.volumeProfile.valPrice; }
int GetHVNCount() { return g_analysis.volumeProfile.hvnCount; }
int GetLVNCount() { return g_analysis.volumeProfile.lvnCount; }

// Get strongest OB info
int GetStrongestBullishScore() { return g_analysis.strongestBullish.score; }
int GetStrongestBearishScore() { return g_analysis.strongestBearish.score; }

// Get nearest OB zone
bool GetNearestBullishOB(double &high, double &low, double &mid, int &score)
{
   if(g_analysis.bullishCount == 0) return false;
   high = g_analysis.nearestBullish.highPrice;
   low = g_analysis.nearestBullish.lowPrice;
   mid = g_analysis.nearestBullish.midPrice;
   score = g_analysis.nearestBullish.score;
   return true;
}

bool GetNearestBearishOB(double &high, double &low, double &mid, int &score)
{
   if(g_analysis.bearishCount == 0) return false;
   high = g_analysis.nearestBearish.highPrice;
   low = g_analysis.nearestBearish.lowPrice;
   mid = g_analysis.nearestBearish.midPrice;
   score = g_analysis.nearestBearish.score;
   return true;
}
//+------------------------------------------------------------------+
