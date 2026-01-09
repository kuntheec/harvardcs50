//+------------------------------------------------------------------+
//|                                            SectionStudyMode.mq5   |
//|                         SwingTrader Pro EA - Section Study Tool   |
//|                                 Learn Each Section Individually   |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "1.00"
#property description "Section Study Mode - Learn SMC Concepts Step by Step"
#property description "Select a section to study its analysis in detail"
#property description "Full panel display, chart drawings, and explanations"

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_STUDY_SECTION
{
   SECTION_1_ATR = 1,           // Section 1: ATR Filter
   SECTION_2_EMA = 2,           // Section 2: EMA Analysis
   SECTION_3_STRUCTURE = 3,     // Section 3: BOS/CHoCH Structure
   SECTION_4_SUPPLY_DEMAND = 4, // Section 4: Supply/Demand Zones
   SECTION_5_FIBONACCI = 5,     // Section 5: Fibonacci/OTE
   SECTION_6_MACD_RSI = 6,      // Section 6: MACD/RSI Momentum
   SECTION_7_FVG = 7,           // Section 7: Fair Value Gaps
   SECTION_8_ORDER_BLOCKS = 8,  // Section 8: Order Blocks
   SECTION_9_NEWS = 9,          // Section 9: News Filter
   SECTION_10_MTF = 10,         // Section 10: Multi-Timeframe
   SECTION_11_ENTRY = 11,       // Section 11: Entry Logic
   SECTION_12_RISK = 12,        // Section 12: Risk Management
   SECTION_13_EXECUTION = 13    // Section 13: Trade Execution
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== SECTION STUDY MODE v1.00 ==="
input ENUM_STUDY_SECTION InpStudySection = SECTION_1_ATR;  // Select Section to Study
input bool     InpShowNavButtons      = true;              // Show Next/Prev Navigation Buttons
input bool     InpAutoRefresh         = true;              // Auto-Refresh on New Bar

input group "=== Timeframe Settings ==="
input ENUM_TIMEFRAMES InpHTF          = PERIOD_H4;         // Higher Timeframe (Analysis)
input ENUM_TIMEFRAMES InpLTF          = PERIOD_M15;        // Lower Timeframe (Entry)

input group "=== Section 1: ATR Settings ==="
input int      InpATRPeriod           = 14;                // ATR Period
input double   InpATRQuietPips        = 60.0;              // Quiet Market Threshold (pips)
input double   InpATRExtremePips      = 250.0;             // Extreme Volatility Threshold (pips)

input group "=== Section 2: EMA Settings ==="
input int      InpEMAFast             = 50;                // EMA Fast Period
input int      InpEMASlow             = 200;               // EMA Slow Period

input group "=== Section 3: Structure Settings ==="
input int      InpSwingLookback       = 3;                 // Swing Detection Lookback
input int      InpStructureBars       = 50;                // Structure Analysis Bars

input group "=== Section 5: Fibonacci Settings ==="
input int      InpFibLookback         = 100;               // Fibonacci Lookback Bars
input int      InpFibSwingStrength    = 5;                 // Swing Strength for Fib

input group "=== Section 6: MACD/RSI Settings ==="
input int      InpMACDFast            = 12;                // MACD Fast Period
input int      InpMACDSlow            = 26;                // MACD Slow Period
input int      InpMACDSignal          = 9;                 // MACD Signal Period
input int      InpRSIPeriod           = 14;                // RSI Period
input int      InpRSIOverbought       = 70;                // RSI Overbought Level
input int      InpRSIOversold         = 30;                // RSI Oversold Level

input group "=== Section 7: FVG Settings ==="
input int      InpFVGLookback         = 100;               // FVG Lookback Bars
input int      InpMaxFVGs             = 10;                // Max FVGs to Display

input group "=== Section 8: Order Block Settings ==="
input int      InpOBLookback          = 50;                // Order Block Lookback Bars
input int      InpMaxOBs              = 8;                 // Max Order Blocks to Display

input group "=== Display Settings ==="
input int      InpPanelX              = 20;                // Panel X Position
input int      InpPanelY              = 30;                // Panel Y Position
input color    InpPanelBg             = clrBlack;          // Panel Background
input color    InpBullColor           = clrLimeGreen;      // Bullish Color
input color    InpBearColor           = clrRed;            // Bearish Color
input color    InpNeutralColor        = clrGray;           // Neutral Color

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
string         g_panelName = "StudyPanel";
string         g_navPrefix = "NavBtn";
int            g_currentSection;

// Symbol Info
SymbolInfoCache g_symbolInfo;

// Indicator Handles
int            g_atrHandle = INVALID_HANDLE;
int            g_emaFastHandle = INVALID_HANDLE;
int            g_emaSlowHandle = INVALID_HANDLE;
int            g_macdHandle = INVALID_HANDLE;
int            g_rsiHandle = INVALID_HANDLE;

// Buffers
double         g_atrBuffer[];
double         g_emaFastBuffer[];
double         g_emaSlowBuffer[];
double         g_macdMainBuffer[];
double         g_macdSignalBuffer[];
double         g_rsiBuffer[];
double         g_highBuffer[];
double         g_lowBuffer[];
double         g_closeBuffer[];
double         g_openBuffer[];
datetime       g_timeBuffer[];

// Section Results Storage
struct StudyResults
{
   // Section 1: ATR
   double atrValue;
   double atrPips;
   string atrCondition;
   bool   atrTradingAllowed;

   // Section 2: EMA
   double ema50;
   double ema200;
   double emaGap;
   double emaGapPercent;
   string emaTrend;
   string emaSlope50;
   string emaSlope200;
   bool   priceAboveEMA50;
   bool   priceAboveEMA200;

   // Section 3: Structure
   string marketStructure;
   double lastSwingHigh;
   double lastSwingLow;
   int    swingHighCount;
   int    swingLowCount;
   bool   bosDetected;
   string bosDirection;
   bool   chochDetected;
   string chochDirection;

   // Section 4: Supply/Demand
   int    demandZoneCount;
   int    supplyZoneCount;
   double nearestDemandHigh;
   double nearestDemandLow;
   double nearestSupplyHigh;
   double nearestSupplyLow;
   bool   inDemandZone;
   bool   inSupplyZone;

   // Section 5: Fibonacci
   double fibSwingHigh;
   double fibSwingLow;
   double fib236;
   double fib382;
   double fib500;
   double fib618;
   double fib786;
   bool   inOTEZone;
   string fibDirection;

   // Section 6: MACD/RSI
   double macdMain;
   double macdSignal;
   double macdHistogram;
   double rsiValue;
   string macdTrend;
   string rsiCondition;
   bool   macdBullishCross;
   bool   macdBearishCross;
   bool   bullishDivergence;
   bool   bearishDivergence;

   // Section 7: FVG
   int    bullishFVGCount;
   int    bearishFVGCount;
   bool   priceInFVG;
   double nearestFVGHigh;
   double nearestFVGLow;
   string fvgType;

   // Section 8: Order Blocks
   int    bullishOBCount;
   int    bearishOBCount;
   bool   priceInOB;
   double nearestOBHigh;
   double nearestOBLow;
   string obType;
   int    obStrength;

   // Section 9: News
   bool   newsUpcoming;
   string newsEvent;
   int    minsToNews;
   string newsImpact;
   bool   tradingAllowed;

   // Section 10: MTF
   string h1Trend;
   string h4Trend;
   string d1Trend;
   int    alignedTFs;
   int    confluenceScore;
   bool   allAligned;

   // Section 11: Entry
   bool   entrySignal;
   string entryType;
   string entryDirection;
   int    entryScore;
   string entryReason;

   // Section 12: Risk
   double riskPercent;
   double positionSize;
   double stopLossPips;
   double takeProfitPips;
   double riskReward;

   // Section 13: Execution
   string orderType;
   double entryPrice;
   double slPrice;
   double tp1Price;
   double tp2Price;
   double tp3Price;
};

StudyResults g_results;

// Swing Point Storage
struct SwingPointStudy
{
   double price;
   datetime time;
   int barIndex;
   bool isHigh;
};
SwingPointStudy g_swingHighs[];
SwingPointStudy g_swingLows[];

// FVG Storage
struct FVGStudy
{
   double highPrice;
   double lowPrice;
   datetime time;
   bool isBullish;
   bool isMitigated;
};
FVGStudy g_fvgZones[];

// Order Block Storage
struct OBStudy
{
   double highPrice;
   double lowPrice;
   datetime time;
   bool isBullish;
   int strength;
   int retests;
};
OBStudy g_obZones[];

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   g_currentSection = InpStudySection;

   // Initialize symbol info
   InitSymbolInfo(g_symbolInfo, _Symbol);

   // Create indicator handles
   g_atrHandle = iATR(_Symbol, InpHTF, InpATRPeriod);
   g_emaFastHandle = iMA(_Symbol, InpHTF, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHandle = iMA(_Symbol, InpHTF, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   g_macdHandle = iMACD(_Symbol, InpHTF, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   g_rsiHandle = iRSI(_Symbol, InpHTF, InpRSIPeriod, PRICE_CLOSE);

   // Set arrays as series
   ArraySetAsSeries(g_atrBuffer, true);
   ArraySetAsSeries(g_emaFastBuffer, true);
   ArraySetAsSeries(g_emaSlowBuffer, true);
   ArraySetAsSeries(g_macdMainBuffer, true);
   ArraySetAsSeries(g_macdSignalBuffer, true);
   ArraySetAsSeries(g_rsiBuffer, true);
   ArraySetAsSeries(g_highBuffer, true);
   ArraySetAsSeries(g_lowBuffer, true);
   ArraySetAsSeries(g_closeBuffer, true);
   ArraySetAsSeries(g_openBuffer, true);
   ArraySetAsSeries(g_timeBuffer, true);

   // Initialize arrays
   ArrayResize(g_swingHighs, 20);
   ArrayResize(g_swingLows, 20);
   ArrayResize(g_fvgZones, InpMaxFVGs);
   ArrayResize(g_obZones, InpMaxOBs);

   // Print initialization
   PrintInitReport();

   // Create navigation buttons
   if(InpShowNavButtons)
      CreateNavigationButtons();

   // Run initial analysis
   Sleep(500);
   AnalyzeCurrentSection();

   // Create panel
   CreateSectionPanel();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release handles
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_emaFastHandle != INVALID_HANDLE) IndicatorRelease(g_emaFastHandle);
   if(g_emaSlowHandle != INVALID_HANDLE) IndicatorRelease(g_emaSlowHandle);
   if(g_macdHandle != INVALID_HANDLE) IndicatorRelease(g_macdHandle);
   if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);

   // Delete all visual objects
   ClearAllObjects();
   ObjectsDeleteAll(0, g_panelName);
   ObjectsDeleteAll(0, g_navPrefix);

   Print("═══════════════════════════════════════════════════════════");
   Print("  Section Study Mode Closed");
   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!InpAutoRefresh) return;

   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, InpHTF, 0);

   if(currentBar != lastBar)
   {
      lastBar = currentBar;
      AnalyzeCurrentSection();
      UpdateSectionPanel();
   }
}

//+------------------------------------------------------------------+
//| Chart event handler                                               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == g_navPrefix + "_Prev")
      {
         SwitchSection(-1);
      }
      else if(sparam == g_navPrefix + "_Next")
      {
         SwitchSection(1);
      }
      else if(StringFind(sparam, g_navPrefix + "_Sec") >= 0)
      {
         // Direct section button clicked
         int secNum = (int)StringToInteger(StringSubstr(sparam, StringLen(g_navPrefix + "_Sec")));
         if(secNum >= 1 && secNum <= 13)
         {
            g_currentSection = secNum;
            ClearAllObjects();
            AnalyzeCurrentSection();
            UpdateSectionPanel();
            PrintSectionReport();
         }
      }

      // Reset button state
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Switch to next/previous section                                   |
//+------------------------------------------------------------------+
void SwitchSection(int direction)
{
   g_currentSection += direction;

   if(g_currentSection < 1) g_currentSection = 13;
   if(g_currentSection > 13) g_currentSection = 1;

   // Clear previous section objects
   ClearAllObjects();

   // Analyze new section
   AnalyzeCurrentSection();

   // Update panel
   UpdateSectionPanel();

   // Print report
   PrintSectionReport();
}

//+------------------------------------------------------------------+
//| Clear all chart objects from current section                      |
//+------------------------------------------------------------------+
void ClearAllObjects()
{
   ObjectsDeleteAll(0, "Study_");
   ObjectsDeleteAll(0, "EMA_");
   ObjectsDeleteAll(0, "Swing_");
   ObjectsDeleteAll(0, "BOS_");
   ObjectsDeleteAll(0, "CHoCH_");
   ObjectsDeleteAll(0, "FVG_");
   ObjectsDeleteAll(0, "OB_");
   ObjectsDeleteAll(0, "Fib_");
   ObjectsDeleteAll(0, "SD_");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Analyze current section                                           |
//+------------------------------------------------------------------+
void AnalyzeCurrentSection()
{
   // Copy price data
   int bars = MathMax(InpStructureBars, InpFibLookback) + 50;
   CopyHigh(_Symbol, InpHTF, 0, bars, g_highBuffer);
   CopyLow(_Symbol, InpHTF, 0, bars, g_lowBuffer);
   CopyClose(_Symbol, InpHTF, 0, bars, g_closeBuffer);
   CopyOpen(_Symbol, InpHTF, 0, bars, g_openBuffer);
   CopyTime(_Symbol, InpHTF, 0, bars, g_timeBuffer);

   switch(g_currentSection)
   {
      case SECTION_1_ATR:        AnalyzeSection1_ATR();        break;
      case SECTION_2_EMA:        AnalyzeSection2_EMA();        break;
      case SECTION_3_STRUCTURE:  AnalyzeSection3_Structure();  break;
      case SECTION_4_SUPPLY_DEMAND: AnalyzeSection4_SupplyDemand(); break;
      case SECTION_5_FIBONACCI:  AnalyzeSection5_Fibonacci();  break;
      case SECTION_6_MACD_RSI:   AnalyzeSection6_MACD_RSI();   break;
      case SECTION_7_FVG:        AnalyzeSection7_FVG();        break;
      case SECTION_8_ORDER_BLOCKS: AnalyzeSection8_OrderBlocks(); break;
      case SECTION_9_NEWS:       AnalyzeSection9_News();       break;
      case SECTION_10_MTF:       AnalyzeSection10_MTF();       break;
      case SECTION_11_ENTRY:     AnalyzeSection11_Entry();     break;
      case SECTION_12_RISK:      AnalyzeSection12_Risk();      break;
      case SECTION_13_EXECUTION: AnalyzeSection13_Execution(); break;
   }
}

//+------------------------------------------------------------------+
//| Section 1: ATR Filter Analysis                                    |
//+------------------------------------------------------------------+
void AnalyzeSection1_ATR()
{
   if(CopyBuffer(g_atrHandle, 0, 0, 20, g_atrBuffer) < 20) return;

   g_results.atrValue = g_atrBuffer[0];
   g_results.atrPips = PointsToPips(g_symbolInfo, g_results.atrValue);

   if(g_results.atrPips < InpATRQuietPips)
   {
      g_results.atrCondition = "QUIET";
      g_results.atrTradingAllowed = false;
   }
   else if(g_results.atrPips > InpATRExtremePips)
   {
      g_results.atrCondition = "EXTREME";
      g_results.atrTradingAllowed = true;
   }
   else
   {
      g_results.atrCondition = "NORMAL";
      g_results.atrTradingAllowed = true;
   }

   // Draw ATR info on chart
   DrawATRInfo();
}

//+------------------------------------------------------------------+
//| Section 2: EMA Analysis                                           |
//+------------------------------------------------------------------+
void AnalyzeSection2_EMA()
{
   if(CopyBuffer(g_emaFastHandle, 0, 0, 50, g_emaFastBuffer) < 50) return;
   if(CopyBuffer(g_emaSlowHandle, 0, 0, 50, g_emaSlowBuffer) < 50) return;

   g_results.ema50 = g_emaFastBuffer[0];
   g_results.ema200 = g_emaSlowBuffer[0];
   g_results.emaGap = g_results.ema50 - g_results.ema200;
   g_results.emaGapPercent = (g_results.emaGap / g_results.ema200) * 100;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_results.priceAboveEMA50 = (currentPrice > g_results.ema50);
   g_results.priceAboveEMA200 = (currentPrice > g_results.ema200);

   // Determine trend
   if(g_results.ema50 > g_results.ema200 && g_results.priceAboveEMA50)
      g_results.emaTrend = "BULLISH";
   else if(g_results.ema50 < g_results.ema200 && !g_results.priceAboveEMA50)
      g_results.emaTrend = "BEARISH";
   else
      g_results.emaTrend = "NEUTRAL";

   // Calculate slopes
   double slope50 = g_emaFastBuffer[0] - g_emaFastBuffer[5];
   double slope200 = g_emaSlowBuffer[0] - g_emaSlowBuffer[5];

   g_results.emaSlope50 = (slope50 > 0) ? "RISING" : (slope50 < 0) ? "FALLING" : "FLAT";
   g_results.emaSlope200 = (slope200 > 0) ? "RISING" : (slope200 < 0) ? "FALLING" : "FLAT";

   // Draw EMA lines
   DrawEMALines();
}

//+------------------------------------------------------------------+
//| Section 3: Market Structure (BOS/CHoCH)                           |
//+------------------------------------------------------------------+
void AnalyzeSection3_Structure()
{
   // First run EMA for trend context
   AnalyzeSection2_EMA();

   // Find swing points
   FindSwingPoints();

   // Detect BOS and CHoCH
   DetectStructureBreaks();

   // Draw structure on chart
   DrawStructure();
}

//+------------------------------------------------------------------+
//| Find Swing High and Low Points                                    |
//+------------------------------------------------------------------+
void FindSwingPoints()
{
   int highCount = 0;
   int lowCount = 0;

   for(int i = InpSwingLookback; i < InpStructureBars - InpSwingLookback; i++)
   {
      // Check for Swing High
      bool isSwingHigh = true;
      for(int j = 1; j <= InpSwingLookback; j++)
      {
         if(g_highBuffer[i] <= g_highBuffer[i-j] || g_highBuffer[i] <= g_highBuffer[i+j])
         {
            isSwingHigh = false;
            break;
         }
      }

      if(isSwingHigh && highCount < 20)
      {
         g_swingHighs[highCount].price = g_highBuffer[i];
         g_swingHighs[highCount].time = g_timeBuffer[i];
         g_swingHighs[highCount].barIndex = i;
         g_swingHighs[highCount].isHigh = true;
         highCount++;
      }

      // Check for Swing Low
      bool isSwingLow = true;
      for(int j = 1; j <= InpSwingLookback; j++)
      {
         if(g_lowBuffer[i] >= g_lowBuffer[i-j] || g_lowBuffer[i] >= g_lowBuffer[i+j])
         {
            isSwingLow = false;
            break;
         }
      }

      if(isSwingLow && lowCount < 20)
      {
         g_swingLows[lowCount].price = g_lowBuffer[i];
         g_swingLows[lowCount].time = g_timeBuffer[i];
         g_swingLows[lowCount].barIndex = i;
         g_swingLows[lowCount].isHigh = false;
         lowCount++;
      }
   }

   g_results.swingHighCount = highCount;
   g_results.swingLowCount = lowCount;

   if(highCount > 0) g_results.lastSwingHigh = g_swingHighs[0].price;
   if(lowCount > 0) g_results.lastSwingLow = g_swingLows[0].price;
}

//+------------------------------------------------------------------+
//| Detect BOS and CHoCH                                              |
//+------------------------------------------------------------------+
void DetectStructureBreaks()
{
   g_results.bosDetected = false;
   g_results.chochDetected = false;
   g_results.bosDirection = "NONE";
   g_results.chochDirection = "NONE";

   if(g_results.swingHighCount < 2 || g_results.swingLowCount < 2) return;

   double currentClose = g_closeBuffer[0];

   // Determine structure
   bool higherHighs = (g_swingHighs[0].price > g_swingHighs[1].price);
   bool higherLows = (g_swingLows[0].price > g_swingLows[1].price);
   bool lowerHighs = (g_swingHighs[0].price < g_swingHighs[1].price);
   bool lowerLows = (g_swingLows[0].price < g_swingLows[1].price);

   if(higherHighs && higherLows)
      g_results.marketStructure = "BULLISH";
   else if(lowerHighs && lowerLows)
      g_results.marketStructure = "BEARISH";
   else
      g_results.marketStructure = "RANGING";

   // BOS Detection
   if(g_results.marketStructure == "BULLISH" && currentClose > g_results.lastSwingHigh)
   {
      g_results.bosDetected = true;
      g_results.bosDirection = "BULLISH";
   }
   else if(g_results.marketStructure == "BEARISH" && currentClose < g_results.lastSwingLow)
   {
      g_results.bosDetected = true;
      g_results.bosDirection = "BEARISH";
   }

   // CHoCH Detection
   if(g_results.marketStructure == "BULLISH" && currentClose < g_results.lastSwingLow)
   {
      g_results.chochDetected = true;
      g_results.chochDirection = "BEARISH";
   }
   else if(g_results.marketStructure == "BEARISH" && currentClose > g_results.lastSwingHigh)
   {
      g_results.chochDetected = true;
      g_results.chochDirection = "BULLISH";
   }
}

//+------------------------------------------------------------------+
//| Section 4: Supply/Demand Zones                                    |
//+------------------------------------------------------------------+
void AnalyzeSection4_SupplyDemand()
{
   // Run ATR for zone sizing
   AnalyzeSection1_ATR();

   g_results.demandZoneCount = 0;
   g_results.supplyZoneCount = 0;
   g_results.inDemandZone = false;
   g_results.inSupplyZone = false;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrValue = g_results.atrValue;

   // Find demand zones (bullish engulfing patterns)
   for(int i = 3; i < InpStructureBars - 1; i++)
   {
      // Bullish engulfing = demand zone
      if(g_closeBuffer[i+1] < g_openBuffer[i+1] &&  // Previous bearish
         g_closeBuffer[i] > g_openBuffer[i] &&       // Current bullish
         g_closeBuffer[i] > g_openBuffer[i+1] &&     // Close above prev open
         g_openBuffer[i] < g_closeBuffer[i+1])       // Open below prev close
      {
         double zoneHigh = g_highBuffer[i+1];
         double zoneLow = g_lowBuffer[i+1];

         // Check if zone is still valid (not broken)
         bool valid = true;
         for(int j = 0; j < i; j++)
         {
            if(g_lowBuffer[j] < zoneLow)
            {
               valid = false;
               break;
            }
         }

         if(valid && g_results.demandZoneCount < 5)
         {
            if(g_results.demandZoneCount == 0)
            {
               g_results.nearestDemandHigh = zoneHigh;
               g_results.nearestDemandLow = zoneLow;
            }
            g_results.demandZoneCount++;

            // Check if price in zone
            if(currentPrice >= zoneLow && currentPrice <= zoneHigh)
               g_results.inDemandZone = true;
         }
      }

      // Bearish engulfing = supply zone
      if(g_closeBuffer[i+1] > g_openBuffer[i+1] &&  // Previous bullish
         g_closeBuffer[i] < g_openBuffer[i] &&       // Current bearish
         g_closeBuffer[i] < g_openBuffer[i+1] &&     // Close below prev open
         g_openBuffer[i] > g_closeBuffer[i+1])       // Open above prev close
      {
         double zoneHigh = g_highBuffer[i+1];
         double zoneLow = g_lowBuffer[i+1];

         // Check if zone is still valid
         bool valid = true;
         for(int j = 0; j < i; j++)
         {
            if(g_highBuffer[j] > zoneHigh)
            {
               valid = false;
               break;
            }
         }

         if(valid && g_results.supplyZoneCount < 5)
         {
            if(g_results.supplyZoneCount == 0)
            {
               g_results.nearestSupplyHigh = zoneHigh;
               g_results.nearestSupplyLow = zoneLow;
            }
            g_results.supplyZoneCount++;

            // Check if price in zone
            if(currentPrice >= zoneLow && currentPrice <= zoneHigh)
               g_results.inSupplyZone = true;
         }
      }
   }

   DrawSupplyDemandZones();
}

//+------------------------------------------------------------------+
//| Section 5: Fibonacci/OTE Analysis                                 |
//+------------------------------------------------------------------+
void AnalyzeSection5_Fibonacci()
{
   // First find swing points
   FindSwingPoints();

   if(g_results.swingHighCount < 1 || g_results.swingLowCount < 1) return;

   // Determine fib direction based on most recent swing
   int recentHighBar = g_swingHighs[0].barIndex;
   int recentLowBar = g_swingLows[0].barIndex;

   if(recentHighBar < recentLowBar)
   {
      // Most recent is high - bearish fib (retrace up)
      g_results.fibDirection = "BEARISH";
      g_results.fibSwingHigh = g_swingHighs[0].price;
      g_results.fibSwingLow = g_swingLows[0].price;
   }
   else
   {
      // Most recent is low - bullish fib (retrace down)
      g_results.fibDirection = "BULLISH";
      g_results.fibSwingHigh = g_swingHighs[0].price;
      g_results.fibSwingLow = g_swingLows[0].price;
   }

   double range = g_results.fibSwingHigh - g_results.fibSwingLow;

   if(g_results.fibDirection == "BULLISH")
   {
      g_results.fib236 = g_results.fibSwingHigh - range * 0.236;
      g_results.fib382 = g_results.fibSwingHigh - range * 0.382;
      g_results.fib500 = g_results.fibSwingHigh - range * 0.500;
      g_results.fib618 = g_results.fibSwingHigh - range * 0.618;
      g_results.fib786 = g_results.fibSwingHigh - range * 0.786;
   }
   else
   {
      g_results.fib236 = g_results.fibSwingLow + range * 0.236;
      g_results.fib382 = g_results.fibSwingLow + range * 0.382;
      g_results.fib500 = g_results.fibSwingLow + range * 0.500;
      g_results.fib618 = g_results.fibSwingLow + range * 0.618;
      g_results.fib786 = g_results.fibSwingLow + range * 0.786;
   }

   // Check if price in OTE zone (61.8% - 78.6%)
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double oteHigh = MathMax(g_results.fib618, g_results.fib786);
   double oteLow = MathMin(g_results.fib618, g_results.fib786);

   g_results.inOTEZone = (currentPrice >= oteLow && currentPrice <= oteHigh);

   DrawFibonacciLevels();
}

//+------------------------------------------------------------------+
//| Section 6: MACD/RSI Momentum                                      |
//+------------------------------------------------------------------+
void AnalyzeSection6_MACD_RSI()
{
   if(CopyBuffer(g_macdHandle, 0, 0, 20, g_macdMainBuffer) < 20) return;
   if(CopyBuffer(g_macdHandle, 1, 0, 20, g_macdSignalBuffer) < 20) return;
   if(CopyBuffer(g_rsiHandle, 0, 0, 20, g_rsiBuffer) < 20) return;

   g_results.macdMain = g_macdMainBuffer[0];
   g_results.macdSignal = g_macdSignalBuffer[0];
   g_results.macdHistogram = g_results.macdMain - g_results.macdSignal;
   g_results.rsiValue = g_rsiBuffer[0];

   // MACD trend
   if(g_results.macdMain > g_results.macdSignal && g_results.macdMain > 0)
      g_results.macdTrend = "STRONG BULLISH";
   else if(g_results.macdMain > g_results.macdSignal)
      g_results.macdTrend = "BULLISH";
   else if(g_results.macdMain < g_results.macdSignal && g_results.macdMain < 0)
      g_results.macdTrend = "STRONG BEARISH";
   else
      g_results.macdTrend = "BEARISH";

   // RSI condition
   if(g_results.rsiValue >= InpRSIOverbought)
      g_results.rsiCondition = "OVERBOUGHT";
   else if(g_results.rsiValue <= InpRSIOversold)
      g_results.rsiCondition = "OVERSOLD";
   else if(g_results.rsiValue > 50)
      g_results.rsiCondition = "BULLISH";
   else
      g_results.rsiCondition = "BEARISH";

   // Crossover detection
   g_results.macdBullishCross = (g_macdMainBuffer[1] < g_macdSignalBuffer[1] &&
                                  g_macdMainBuffer[0] > g_macdSignalBuffer[0]);
   g_results.macdBearishCross = (g_macdMainBuffer[1] > g_macdSignalBuffer[1] &&
                                  g_macdMainBuffer[0] < g_macdSignalBuffer[0]);

   // Simple divergence check
   g_results.bullishDivergence = false;
   g_results.bearishDivergence = false;

   DrawMACDRSIInfo();
}

//+------------------------------------------------------------------+
//| Section 7: Fair Value Gaps                                        |
//+------------------------------------------------------------------+
void AnalyzeSection7_FVG()
{
   g_results.bullishFVGCount = 0;
   g_results.bearishFVGCount = 0;
   g_results.priceInFVG = false;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int fvgIndex = 0;

   for(int i = 2; i < InpFVGLookback && fvgIndex < InpMaxFVGs; i++)
   {
      // Bullish FVG: Gap between candle 0 low and candle 2 high
      double bullGapHigh = g_lowBuffer[i-2];
      double bullGapLow = g_highBuffer[i];

      if(bullGapHigh > bullGapLow)  // Valid gap
      {
         g_fvgZones[fvgIndex].highPrice = bullGapHigh;
         g_fvgZones[fvgIndex].lowPrice = bullGapLow;
         g_fvgZones[fvgIndex].time = g_timeBuffer[i-1];
         g_fvgZones[fvgIndex].isBullish = true;
         g_fvgZones[fvgIndex].isMitigated = (currentPrice <= bullGapLow);

         if(!g_fvgZones[fvgIndex].isMitigated)
         {
            g_results.bullishFVGCount++;

            if(currentPrice >= bullGapLow && currentPrice <= bullGapHigh)
            {
               g_results.priceInFVG = true;
               g_results.fvgType = "BULLISH";
               g_results.nearestFVGHigh = bullGapHigh;
               g_results.nearestFVGLow = bullGapLow;
            }
         }
         fvgIndex++;
      }

      // Bearish FVG: Gap between candle 0 high and candle 2 low
      double bearGapHigh = g_lowBuffer[i];
      double bearGapLow = g_highBuffer[i-2];

      if(bearGapHigh > bearGapLow && fvgIndex < InpMaxFVGs)
      {
         g_fvgZones[fvgIndex].highPrice = bearGapHigh;
         g_fvgZones[fvgIndex].lowPrice = bearGapLow;
         g_fvgZones[fvgIndex].time = g_timeBuffer[i-1];
         g_fvgZones[fvgIndex].isBullish = false;
         g_fvgZones[fvgIndex].isMitigated = (currentPrice >= bearGapHigh);

         if(!g_fvgZones[fvgIndex].isMitigated)
         {
            g_results.bearishFVGCount++;

            if(currentPrice >= bearGapLow && currentPrice <= bearGapHigh)
            {
               g_results.priceInFVG = true;
               g_results.fvgType = "BEARISH";
               g_results.nearestFVGHigh = bearGapHigh;
               g_results.nearestFVGLow = bearGapLow;
            }
         }
         fvgIndex++;
      }
   }

   DrawFVGZones();
}

//+------------------------------------------------------------------+
//| Section 8: Order Blocks                                           |
//+------------------------------------------------------------------+
void AnalyzeSection8_OrderBlocks()
{
   g_results.bullishOBCount = 0;
   g_results.bearishOBCount = 0;
   g_results.priceInOB = false;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int obIndex = 0;

   for(int i = 2; i < InpOBLookback && obIndex < InpMaxOBs; i++)
   {
      // Bullish OB: Last bearish candle before bullish move
      if(g_closeBuffer[i] < g_openBuffer[i])  // Bearish candle
      {
         // Check for bullish move after
         bool bullishMove = false;
         for(int j = i - 1; j >= 0 && j >= i - 3; j--)
         {
            if(g_closeBuffer[j] > g_highBuffer[i])
            {
               bullishMove = true;
               break;
            }
         }

         if(bullishMove)
         {
            double obHigh = g_highBuffer[i];
            double obLow = g_lowBuffer[i];

            // Check if OB is still valid
            bool valid = true;
            for(int j = 0; j < i; j++)
            {
               if(g_lowBuffer[j] < obLow)
               {
                  valid = false;
                  break;
               }
            }

            if(valid)
            {
               g_obZones[obIndex].highPrice = obHigh;
               g_obZones[obIndex].lowPrice = obLow;
               g_obZones[obIndex].time = g_timeBuffer[i];
               g_obZones[obIndex].isBullish = true;
               g_obZones[obIndex].strength = 7;
               g_results.bullishOBCount++;

               if(currentPrice >= obLow && currentPrice <= obHigh)
               {
                  g_results.priceInOB = true;
                  g_results.obType = "BULLISH";
                  g_results.nearestOBHigh = obHigh;
                  g_results.nearestOBLow = obLow;
               }
               obIndex++;
            }
         }
      }

      // Bearish OB: Last bullish candle before bearish move
      if(g_closeBuffer[i] > g_openBuffer[i] && obIndex < InpMaxOBs)
      {
         bool bearishMove = false;
         for(int j = i - 1; j >= 0 && j >= i - 3; j--)
         {
            if(g_closeBuffer[j] < g_lowBuffer[i])
            {
               bearishMove = true;
               break;
            }
         }

         if(bearishMove)
         {
            double obHigh = g_highBuffer[i];
            double obLow = g_lowBuffer[i];

            bool valid = true;
            for(int j = 0; j < i; j++)
            {
               if(g_highBuffer[j] > obHigh)
               {
                  valid = false;
                  break;
               }
            }

            if(valid)
            {
               g_obZones[obIndex].highPrice = obHigh;
               g_obZones[obIndex].lowPrice = obLow;
               g_obZones[obIndex].time = g_timeBuffer[i];
               g_obZones[obIndex].isBullish = false;
               g_obZones[obIndex].strength = 7;
               g_results.bearishOBCount++;

               if(currentPrice >= obLow && currentPrice <= obHigh)
               {
                  g_results.priceInOB = true;
                  g_results.obType = "BEARISH";
                  g_results.nearestOBHigh = obHigh;
                  g_results.nearestOBLow = obLow;
               }
               obIndex++;
            }
         }
      }
   }

   DrawOrderBlocks();
}

//+------------------------------------------------------------------+
//| Section 9: News Filter                                            |
//+------------------------------------------------------------------+
void AnalyzeSection9_News()
{
   // Simplified news check - in real implementation would use calendar
   g_results.newsUpcoming = false;
   g_results.newsEvent = "None scheduled";
   g_results.minsToNews = -1;
   g_results.newsImpact = "NONE";
   g_results.tradingAllowed = true;

   // Check MQL5 calendar if available
   MqlCalendarValue values[];
   datetime startTime = TimeCurrent();
   datetime endTime = startTime + 3600 * 4;  // Next 4 hours

   if(CalendarValueHistory(values, startTime, endTime))
   {
      for(int i = 0; i < ArraySize(values); i++)
      {
         MqlCalendarEvent event;
         if(CalendarEventById(values[i].event_id, event))
         {
            if(event.importance == CALENDAR_IMPORTANCE_HIGH)
            {
               g_results.newsUpcoming = true;
               g_results.newsEvent = event.name;
               g_results.minsToNews = (int)((values[i].time - TimeCurrent()) / 60);
               g_results.newsImpact = "HIGH";

               if(g_results.minsToNews <= 30)
                  g_results.tradingAllowed = false;

               break;
            }
         }
      }
   }

   DrawNewsInfo();
}

//+------------------------------------------------------------------+
//| Section 10: Multi-Timeframe Analysis                              |
//+------------------------------------------------------------------+
void AnalyzeSection10_MTF()
{
   g_results.alignedTFs = 0;

   // H1 Trend
   int h1EmaFast = iMA(_Symbol, PERIOD_H1, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   int h1EmaSlow = iMA(_Symbol, PERIOD_H1, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   double h1Fast[], h1Slow[];
   ArraySetAsSeries(h1Fast, true);
   ArraySetAsSeries(h1Slow, true);

   if(CopyBuffer(h1EmaFast, 0, 0, 1, h1Fast) > 0 && CopyBuffer(h1EmaSlow, 0, 0, 1, h1Slow) > 0)
   {
      g_results.h1Trend = (h1Fast[0] > h1Slow[0]) ? "BULLISH" : "BEARISH";
   }
   IndicatorRelease(h1EmaFast);
   IndicatorRelease(h1EmaSlow);

   // H4 Trend
   double h4Fast[], h4Slow[];
   ArraySetAsSeries(h4Fast, true);
   ArraySetAsSeries(h4Slow, true);

   if(CopyBuffer(g_emaFastHandle, 0, 0, 1, h4Fast) > 0 && CopyBuffer(g_emaSlowHandle, 0, 0, 1, h4Slow) > 0)
   {
      g_results.h4Trend = (h4Fast[0] > h4Slow[0]) ? "BULLISH" : "BEARISH";
   }

   // D1 Trend
   int d1EmaFast = iMA(_Symbol, PERIOD_D1, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   int d1EmaSlow = iMA(_Symbol, PERIOD_D1, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   double d1Fast[], d1Slow[];
   ArraySetAsSeries(d1Fast, true);
   ArraySetAsSeries(d1Slow, true);

   if(CopyBuffer(d1EmaFast, 0, 0, 1, d1Fast) > 0 && CopyBuffer(d1EmaSlow, 0, 0, 1, d1Slow) > 0)
   {
      g_results.d1Trend = (d1Fast[0] > d1Slow[0]) ? "BULLISH" : "BEARISH";
   }
   IndicatorRelease(d1EmaFast);
   IndicatorRelease(d1EmaSlow);

   // Count aligned
   string mainTrend = g_results.d1Trend;
   if(g_results.h1Trend == mainTrend) g_results.alignedTFs++;
   if(g_results.h4Trend == mainTrend) g_results.alignedTFs++;
   if(g_results.d1Trend == mainTrend) g_results.alignedTFs++;

   g_results.allAligned = (g_results.alignedTFs == 3);
   g_results.confluenceScore = g_results.alignedTFs * 3;

   DrawMTFInfo();
}

//+------------------------------------------------------------------+
//| Section 11: Entry Logic                                           |
//+------------------------------------------------------------------+
void AnalyzeSection11_Entry()
{
   // Run prerequisite analyses
   AnalyzeSection1_ATR();
   AnalyzeSection2_EMA();
   AnalyzeSection3_Structure();
   AnalyzeSection6_MACD_RSI();
   AnalyzeSection8_OrderBlocks();

   g_results.entrySignal = false;
   g_results.entryType = "NONE";
   g_results.entryDirection = "NONE";
   g_results.entryScore = 0;
   g_results.entryReason = "";

   // Calculate confluence score
   int score = 0;
   string reasons = "";

   // ATR OK (+1)
   if(g_results.atrTradingAllowed) { score++; reasons += "ATR OK, "; }

   // EMA Trend (+2)
   if(g_results.emaTrend == "BULLISH" || g_results.emaTrend == "BEARISH")
   {
      score += 2;
      reasons += "EMA " + g_results.emaTrend + ", ";
   }

   // Structure (+2)
   if(g_results.bosDetected) { score += 2; reasons += "BOS " + g_results.bosDirection + ", "; }

   // Order Block (+2)
   if(g_results.priceInOB) { score += 2; reasons += "In OB, "; }

   // MACD/RSI alignment (+2)
   if((g_results.emaTrend == "BULLISH" && g_results.macdTrend == "BULLISH") ||
      (g_results.emaTrend == "BEARISH" && g_results.macdTrend == "BEARISH"))
   {
      score += 2;
      reasons += "Momentum aligned, ";
   }

   // RSI not extreme (+1)
   if(g_results.rsiCondition != "OVERBOUGHT" && g_results.rsiCondition != "OVERSOLD")
   {
      score++;
      reasons += "RSI OK, ";
   }

   g_results.entryScore = score;
   g_results.entryReason = reasons;

   // Determine if we have entry signal
   if(score >= 6)
   {
      g_results.entrySignal = true;

      if(g_results.emaTrend == "BULLISH" && g_results.marketStructure == "BULLISH")
      {
         g_results.entryDirection = "BUY";
         g_results.entryType = g_results.priceInOB ? "OB_ENTRY" : "TREND_ENTRY";
      }
      else if(g_results.emaTrend == "BEARISH" && g_results.marketStructure == "BEARISH")
      {
         g_results.entryDirection = "SELL";
         g_results.entryType = g_results.priceInOB ? "OB_ENTRY" : "TREND_ENTRY";
      }
   }

   DrawEntryInfo();
}

//+------------------------------------------------------------------+
//| Section 12: Risk Management                                       |
//+------------------------------------------------------------------+
void AnalyzeSection12_Risk()
{
   AnalyzeSection1_ATR();

   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (1.0 / 100.0);  // 1% risk

   g_results.riskPercent = 1.0;
   g_results.stopLossPips = g_results.atrPips * 1.5;
   g_results.takeProfitPips = g_results.stopLossPips * 2.0;
   g_results.riskReward = 2.0;

   // Calculate position size
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double slPoints = g_results.stopLossPips * g_symbolInfo.pipSize / g_symbolInfo.point;

   if(tickValue > 0 && slPoints > 0)
   {
      g_results.positionSize = NormalizeDouble(riskAmount / (slPoints * tickValue / tickSize), 2);
   }
   else
   {
      g_results.positionSize = 0.01;
   }

   DrawRiskInfo();
}

//+------------------------------------------------------------------+
//| Section 13: Trade Execution                                       |
//+------------------------------------------------------------------+
void AnalyzeSection13_Execution()
{
   AnalyzeSection11_Entry();
   AnalyzeSection12_Risk();

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * g_symbolInfo.point;

   if(g_results.entrySignal && g_results.entryDirection == "BUY")
   {
      g_results.orderType = "BUY MARKET";
      g_results.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      g_results.slPrice = g_results.entryPrice - g_results.stopLossPips * g_symbolInfo.pipSize;
      g_results.tp1Price = g_results.entryPrice + g_results.stopLossPips * 1.5 * g_symbolInfo.pipSize;
      g_results.tp2Price = g_results.entryPrice + g_results.stopLossPips * 2.5 * g_symbolInfo.pipSize;
      g_results.tp3Price = g_results.entryPrice + g_results.stopLossPips * 4.0 * g_symbolInfo.pipSize;
   }
   else if(g_results.entrySignal && g_results.entryDirection == "SELL")
   {
      g_results.orderType = "SELL MARKET";
      g_results.entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      g_results.slPrice = g_results.entryPrice + g_results.stopLossPips * g_symbolInfo.pipSize;
      g_results.tp1Price = g_results.entryPrice - g_results.stopLossPips * 1.5 * g_symbolInfo.pipSize;
      g_results.tp2Price = g_results.entryPrice - g_results.stopLossPips * 2.5 * g_symbolInfo.pipSize;
      g_results.tp3Price = g_results.entryPrice - g_results.stopLossPips * 4.0 * g_symbolInfo.pipSize;
   }
   else
   {
      g_results.orderType = "NO SIGNAL";
      g_results.entryPrice = currentPrice;
      g_results.slPrice = 0;
      g_results.tp1Price = 0;
      g_results.tp2Price = 0;
      g_results.tp3Price = 0;
   }

   DrawExecutionInfo();
}

//+------------------------------------------------------------------+
//| Drawing Functions                                                  |
//+------------------------------------------------------------------+
void DrawATRInfo()
{
   string name = "Study_ATR_Label";
   datetime labelTime = g_timeBuffer[0];
   double labelPrice = g_highBuffer[0] + g_results.atrValue;

   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 400);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, "ATR: " + DoubleToString(g_results.atrPips, 1) + " pips | " + g_results.atrCondition);
   ObjectSetInteger(0, name, OBJPROP_COLOR, g_results.atrTradingAllowed ? clrLimeGreen : clrRed);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
}

void DrawEMALines()
{
   int barsToShow = 50;

   for(int i = 0; i < barsToShow - 1; i++)
   {
      // EMA 50 line
      string fastName = "EMA_Fast_" + IntegerToString(i);
      ObjectCreate(0, fastName, OBJ_TREND, 0, g_timeBuffer[i+1], g_emaFastBuffer[i+1], g_timeBuffer[i], g_emaFastBuffer[i]);
      ObjectSetInteger(0, fastName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, fastName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, fastName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, fastName, OBJPROP_BACK, true);

      // EMA 200 line
      string slowName = "EMA_Slow_" + IntegerToString(i);
      ObjectCreate(0, slowName, OBJ_TREND, 0, g_timeBuffer[i+1], g_emaSlowBuffer[i+1], g_timeBuffer[i], g_emaSlowBuffer[i]);
      ObjectSetInteger(0, slowName, OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, slowName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, slowName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, slowName, OBJPROP_BACK, true);
   }

   // Labels
   ObjectCreate(0, "EMA_Label_50", OBJ_TEXT, 0, g_timeBuffer[0], g_emaFastBuffer[0]);
   ObjectSetString(0, "EMA_Label_50", OBJPROP_TEXT, " EMA50");
   ObjectSetInteger(0, "EMA_Label_50", OBJPROP_COLOR, clrDodgerBlue);

   ObjectCreate(0, "EMA_Label_200", OBJ_TEXT, 0, g_timeBuffer[0], g_emaSlowBuffer[0]);
   ObjectSetString(0, "EMA_Label_200", OBJPROP_TEXT, " EMA200");
   ObjectSetInteger(0, "EMA_Label_200", OBJPROP_COLOR, clrOrangeRed);
}

void DrawStructure()
{
   // Draw swing highs
   for(int i = 0; i < g_results.swingHighCount && i < 10; i++)
   {
      string name = "Swing_High_" + IntegerToString(i);
      ObjectCreate(0, name, OBJ_ARROW, 0, g_swingHighs[i].time, g_swingHighs[i].price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 218);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);

      // Label
      string labelName = "Swing_High_Lbl_" + IntegerToString(i);
      string labelText = (i > 0 && g_swingHighs[i].price > g_swingHighs[i-1].price) ? "HH" : "LH";
      if(i == 0) labelText = "SH";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, g_swingHighs[i].time, g_swingHighs[i].price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   }

   // Draw swing lows
   for(int i = 0; i < g_results.swingLowCount && i < 10; i++)
   {
      string name = "Swing_Low_" + IntegerToString(i);
      ObjectCreate(0, name, OBJ_ARROW, 0, g_swingLows[i].time, g_swingLows[i].price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 217);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrLimeGreen);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);

      // Label
      string labelName = "Swing_Low_Lbl_" + IntegerToString(i);
      string labelText = (i > 0 && g_swingLows[i].price > g_swingLows[i-1].price) ? "HL" : "LL";
      if(i == 0) labelText = "SL";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, g_swingLows[i].time, g_swingLows[i].price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrLimeGreen);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   }

   // Draw BOS/CHoCH lines
   if(g_results.bosDetected)
   {
      double level = (g_results.bosDirection == "BULLISH") ? g_results.lastSwingHigh : g_results.lastSwingLow;
      ObjectCreate(0, "BOS_Line", OBJ_HLINE, 0, 0, level);
      ObjectSetInteger(0, "BOS_Line", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "BOS_Line", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "BOS_Line", OBJPROP_WIDTH, 2);
      ObjectSetString(0, "BOS_Line", OBJPROP_TEXT, "BOS " + g_results.bosDirection);
   }

   if(g_results.chochDetected)
   {
      double level = (g_results.chochDirection == "BULLISH") ? g_results.lastSwingHigh : g_results.lastSwingLow;
      ObjectCreate(0, "CHoCH_Line", OBJ_HLINE, 0, 0, level);
      ObjectSetInteger(0, "CHoCH_Line", OBJPROP_COLOR, clrMagenta);
      ObjectSetInteger(0, "CHoCH_Line", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "CHoCH_Line", OBJPROP_WIDTH, 2);
      ObjectSetString(0, "CHoCH_Line", OBJPROP_TEXT, "CHoCH " + g_results.chochDirection);
   }
}

void DrawSupplyDemandZones()
{
   // Draw demand zone
   if(g_results.demandZoneCount > 0)
   {
      ObjectCreate(0, "SD_Demand", OBJ_RECTANGLE, 0,
                   g_timeBuffer[30], g_results.nearestDemandHigh,
                   g_timeBuffer[0], g_results.nearestDemandLow);
      ObjectSetInteger(0, "SD_Demand", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "SD_Demand", OBJPROP_FILL, true);
      ObjectSetInteger(0, "SD_Demand", OBJPROP_BACK, true);

      ObjectCreate(0, "SD_Demand_Lbl", OBJ_TEXT, 0, g_timeBuffer[15], g_results.nearestDemandHigh);
      ObjectSetString(0, "SD_Demand_Lbl", OBJPROP_TEXT, "DEMAND");
      ObjectSetInteger(0, "SD_Demand_Lbl", OBJPROP_COLOR, clrDodgerBlue);
   }

   // Draw supply zone
   if(g_results.supplyZoneCount > 0)
   {
      ObjectCreate(0, "SD_Supply", OBJ_RECTANGLE, 0,
                   g_timeBuffer[30], g_results.nearestSupplyHigh,
                   g_timeBuffer[0], g_results.nearestSupplyLow);
      ObjectSetInteger(0, "SD_Supply", OBJPROP_COLOR, clrCrimson);
      ObjectSetInteger(0, "SD_Supply", OBJPROP_FILL, true);
      ObjectSetInteger(0, "SD_Supply", OBJPROP_BACK, true);

      ObjectCreate(0, "SD_Supply_Lbl", OBJ_TEXT, 0, g_timeBuffer[15], g_results.nearestSupplyLow);
      ObjectSetString(0, "SD_Supply_Lbl", OBJPROP_TEXT, "SUPPLY");
      ObjectSetInteger(0, "SD_Supply_Lbl", OBJPROP_COLOR, clrCrimson);
   }
}

void DrawFibonacciLevels()
{
   datetime startTime = g_timeBuffer[30];
   datetime endTime = g_timeBuffer[0];

   // Draw fib levels
   color fibColor = clrGold;

   // 0% (Swing High for bullish)
   ObjectCreate(0, "Fib_0", OBJ_TREND, 0, startTime, g_results.fibSwingHigh, endTime, g_results.fibSwingHigh);
   ObjectSetInteger(0, "Fib_0", OBJPROP_COLOR, fibColor);
   ObjectSetString(0, "Fib_0", OBJPROP_TEXT, "0%");

   // 23.6%
   ObjectCreate(0, "Fib_236", OBJ_TREND, 0, startTime, g_results.fib236, endTime, g_results.fib236);
   ObjectSetInteger(0, "Fib_236", OBJPROP_COLOR, fibColor);

   // 38.2%
   ObjectCreate(0, "Fib_382", OBJ_TREND, 0, startTime, g_results.fib382, endTime, g_results.fib382);
   ObjectSetInteger(0, "Fib_382", OBJPROP_COLOR, fibColor);

   // 50%
   ObjectCreate(0, "Fib_500", OBJ_TREND, 0, startTime, g_results.fib500, endTime, g_results.fib500);
   ObjectSetInteger(0, "Fib_500", OBJPROP_COLOR, fibColor);

   // 61.8% - Golden
   ObjectCreate(0, "Fib_618", OBJ_TREND, 0, startTime, g_results.fib618, endTime, g_results.fib618);
   ObjectSetInteger(0, "Fib_618", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "Fib_618", OBJPROP_WIDTH, 2);

   // 78.6%
   ObjectCreate(0, "Fib_786", OBJ_TREND, 0, startTime, g_results.fib786, endTime, g_results.fib786);
   ObjectSetInteger(0, "Fib_786", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "Fib_786", OBJPROP_WIDTH, 2);

   // 100% (Swing Low for bullish)
   ObjectCreate(0, "Fib_100", OBJ_TREND, 0, startTime, g_results.fibSwingLow, endTime, g_results.fibSwingLow);
   ObjectSetInteger(0, "Fib_100", OBJPROP_COLOR, fibColor);

   // OTE Zone rectangle
   double oteHigh = MathMax(g_results.fib618, g_results.fib786);
   double oteLow = MathMin(g_results.fib618, g_results.fib786);
   ObjectCreate(0, "Fib_OTE", OBJ_RECTANGLE, 0, startTime, oteHigh, endTime, oteLow);
   ObjectSetInteger(0, "Fib_OTE", OBJPROP_COLOR, clrDarkOrange);
   ObjectSetInteger(0, "Fib_OTE", OBJPROP_FILL, true);
   ObjectSetInteger(0, "Fib_OTE", OBJPROP_BACK, true);

   ObjectCreate(0, "Fib_OTE_Lbl", OBJ_TEXT, 0, g_timeBuffer[15], (oteHigh + oteLow) / 2);
   ObjectSetString(0, "Fib_OTE_Lbl", OBJPROP_TEXT, "OTE ZONE");
   ObjectSetInteger(0, "Fib_OTE_Lbl", OBJPROP_COLOR, clrOrange);
}

void DrawFVGZones()
{
   int drawn = 0;
   for(int i = 0; i < InpMaxFVGs && drawn < 5; i++)
   {
      if(g_fvgZones[i].highPrice == 0) continue;
      if(g_fvgZones[i].isMitigated) continue;

      string name = "FVG_" + IntegerToString(drawn);
      ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                   g_fvgZones[i].time, g_fvgZones[i].highPrice,
                   g_timeBuffer[0], g_fvgZones[i].lowPrice);
      ObjectSetInteger(0, name, OBJPROP_COLOR, g_fvgZones[i].isBullish ? clrDodgerBlue : clrCrimson);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);

      string lblName = "FVG_Lbl_" + IntegerToString(drawn);
      ObjectCreate(0, lblName, OBJ_TEXT, 0, g_fvgZones[i].time, (g_fvgZones[i].highPrice + g_fvgZones[i].lowPrice) / 2);
      ObjectSetString(0, lblName, OBJPROP_TEXT, g_fvgZones[i].isBullish ? "Bull FVG" : "Bear FVG");
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, g_fvgZones[i].isBullish ? clrDodgerBlue : clrCrimson);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);

      drawn++;
   }
}

void DrawOrderBlocks()
{
   int drawn = 0;
   for(int i = 0; i < InpMaxOBs && drawn < 5; i++)
   {
      if(g_obZones[i].highPrice == 0) continue;

      string name = "OB_" + IntegerToString(drawn);
      ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                   g_obZones[i].time, g_obZones[i].highPrice,
                   g_timeBuffer[0], g_obZones[i].lowPrice);
      ObjectSetInteger(0, name, OBJPROP_COLOR, g_obZones[i].isBullish ? clrDodgerBlue : clrCrimson);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);

      string lblName = "OB_Lbl_" + IntegerToString(drawn);
      ObjectCreate(0, lblName, OBJ_TEXT, 0, g_obZones[i].time, (g_obZones[i].highPrice + g_obZones[i].lowPrice) / 2);
      ObjectSetString(0, lblName, OBJPROP_TEXT, (g_obZones[i].isBullish ? "Bull OB" : "Bear OB") + " [" + IntegerToString(g_obZones[i].strength) + "]");
      ObjectSetInteger(0, lblName, OBJPROP_COLOR, g_obZones[i].isBullish ? clrDodgerBlue : clrCrimson);
      ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 9);

      drawn++;
   }
}

void DrawMACDRSIInfo() { /* Panel shows this info */ }
void DrawNewsInfo() { /* Panel shows this info */ }
void DrawMTFInfo() { /* Panel shows this info */ }
void DrawEntryInfo() { /* Panel shows this info */ }
void DrawRiskInfo() { /* Panel shows this info */ }
void DrawExecutionInfo() { /* Panel shows this info */ }

//+------------------------------------------------------------------+
//| Create Navigation Buttons                                         |
//+------------------------------------------------------------------+
void CreateNavigationButtons()
{
   int btnY = InpPanelY + 320;

   // Previous button
   ObjectCreate(0, g_navPrefix + "_Prev", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, g_navPrefix + "_Prev", OBJPROP_XDISTANCE, InpPanelX);
   ObjectSetInteger(0, g_navPrefix + "_Prev", OBJPROP_YDISTANCE, btnY);
   ObjectSetInteger(0, g_navPrefix + "_Prev", OBJPROP_XSIZE, 80);
   ObjectSetInteger(0, g_navPrefix + "_Prev", OBJPROP_YSIZE, 30);
   ObjectSetString(0, g_navPrefix + "_Prev", OBJPROP_TEXT, "◄ PREV");
   ObjectSetInteger(0, g_navPrefix + "_Prev", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, g_navPrefix + "_Prev", OBJPROP_BGCOLOR, clrDarkSlateGray);
   ObjectSetInteger(0, g_navPrefix + "_Prev", OBJPROP_FONTSIZE, 10);

   // Next button
   ObjectCreate(0, g_navPrefix + "_Next", OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, g_navPrefix + "_Next", OBJPROP_XDISTANCE, InpPanelX + 90);
   ObjectSetInteger(0, g_navPrefix + "_Next", OBJPROP_YDISTANCE, btnY);
   ObjectSetInteger(0, g_navPrefix + "_Next", OBJPROP_XSIZE, 80);
   ObjectSetInteger(0, g_navPrefix + "_Next", OBJPROP_YSIZE, 30);
   ObjectSetString(0, g_navPrefix + "_Next", OBJPROP_TEXT, "NEXT ►");
   ObjectSetInteger(0, g_navPrefix + "_Next", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, g_navPrefix + "_Next", OBJPROP_BGCOLOR, clrDarkSlateGray);
   ObjectSetInteger(0, g_navPrefix + "_Next", OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
//| Create Section Panel                                              |
//+------------------------------------------------------------------+
void CreateSectionPanel()
{
   int x = InpPanelX;
   int y = InpPanelY;
   int width = 320;
   int height = 310;

   // Background
   ObjectCreate(0, g_panelName + "_Bg", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_panelName + "_Bg", OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, g_panelName + "_Bg", OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, g_panelName + "_Bg", OBJPROP_XSIZE, width);
   ObjectSetInteger(0, g_panelName + "_Bg", OBJPROP_YSIZE, height);
   ObjectSetInteger(0, g_panelName + "_Bg", OBJPROP_BGCOLOR, InpPanelBg);
   ObjectSetInteger(0, g_panelName + "_Bg", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, g_panelName + "_Bg", OBJPROP_COLOR, clrDarkGray);

   // Title
   CreatePanelLabel("_Title", x + 10, y + 5, "SECTION STUDY MODE", clrGold, 11);
   CreatePanelLabel("_Section", x + 10, y + 25, "Section: --", clrCyan, 10);
   CreatePanelLabel("_Sep1", x + 10, y + 45, "─────────────────────────────", clrDarkGray, 8);

   // Content labels (will be updated)
   for(int i = 0; i < 12; i++)
   {
      CreatePanelLabel("_Line" + IntegerToString(i), x + 10, y + 60 + i * 18, "", clrWhite, 9);
   }

   // Description at bottom
   CreatePanelLabel("_Sep2", x + 10, y + 275, "─────────────────────────────", clrDarkGray, 8);
   CreatePanelLabel("_Desc", x + 10, y + 290, "Use PREV/NEXT to change section", clrGray, 8);

   UpdateSectionPanel();
}

//+------------------------------------------------------------------+
//| Create Panel Label Helper                                         |
//+------------------------------------------------------------------+
void CreatePanelLabel(string suffix, int x, int y, string text, color clr, int fontSize)
{
   string name = g_panelName + suffix;
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Update Section Panel                                              |
//+------------------------------------------------------------------+
void UpdateSectionPanel()
{
   string sectionNames[] = {"", "ATR Filter", "EMA Analysis", "BOS/CHoCH Structure",
                            "Supply/Demand", "Fibonacci/OTE", "MACD/RSI Momentum",
                            "Fair Value Gaps", "Order Blocks", "News Filter",
                            "Multi-Timeframe", "Entry Logic", "Risk Management", "Trade Execution"};

   ObjectSetString(0, g_panelName + "_Section", OBJPROP_TEXT,
                   "Section " + IntegerToString(g_currentSection) + ": " + sectionNames[g_currentSection]);

   // Clear all lines first
   for(int i = 0; i < 12; i++)
   {
      ObjectSetString(0, g_panelName + "_Line" + IntegerToString(i), OBJPROP_TEXT, "");
      ObjectSetInteger(0, g_panelName + "_Line" + IntegerToString(i), OBJPROP_COLOR, clrWhite);
   }

   // Update based on current section
   switch(g_currentSection)
   {
      case SECTION_1_ATR:
         SetPanelLine(0, "ATR Value: " + DoubleToString(g_results.atrPips, 1) + " pips", clrYellow);
         SetPanelLine(1, "Condition: " + g_results.atrCondition,
                      g_results.atrCondition == "NORMAL" ? clrLimeGreen :
                      (g_results.atrCondition == "QUIET" ? clrGray : clrOrange));
         SetPanelLine(2, "Trading: " + (g_results.atrTradingAllowed ? "ALLOWED" : "BLOCKED"),
                      g_results.atrTradingAllowed ? clrLimeGreen : clrRed);
         SetPanelLine(4, "Quiet Threshold: " + DoubleToString(InpATRQuietPips, 0) + " pips", clrGray);
         SetPanelLine(5, "Extreme Threshold: " + DoubleToString(InpATRExtremePips, 0) + " pips", clrGray);
         SetPanelLine(7, "PURPOSE: Filter low volatility", clrCyan);
         SetPanelLine(8, "markets where moves are weak", clrCyan);
         break;

      case SECTION_2_EMA:
         SetPanelLine(0, "EMA 50: " + DoubleToString(g_results.ema50, g_symbolInfo.digits), clrDodgerBlue);
         SetPanelLine(1, "EMA 200: " + DoubleToString(g_results.ema200, g_symbolInfo.digits), clrOrangeRed);
         SetPanelLine(2, "Gap: " + DoubleToString(g_results.emaGapPercent, 2) + "%", clrYellow);
         SetPanelLine(3, "EMA50 Slope: " + g_results.emaSlope50,
                      g_results.emaSlope50 == "RISING" ? clrLimeGreen : clrRed);
         SetPanelLine(4, "EMA200 Slope: " + g_results.emaSlope200,
                      g_results.emaSlope200 == "RISING" ? clrLimeGreen : clrRed);
         SetPanelLine(5, "Trend: " + g_results.emaTrend,
                      g_results.emaTrend == "BULLISH" ? clrLimeGreen :
                      (g_results.emaTrend == "BEARISH" ? clrRed : clrGray));
         SetPanelLine(7, "PURPOSE: Determine H4 trend bias", clrCyan);
         SetPanelLine(8, "EMA50 > EMA200 = Bullish", clrCyan);
         break;

      case SECTION_3_STRUCTURE:
         SetPanelLine(0, "Structure: " + g_results.marketStructure,
                      g_results.marketStructure == "BULLISH" ? clrLimeGreen :
                      (g_results.marketStructure == "BEARISH" ? clrRed : clrGray));
         SetPanelLine(1, "Swing Highs: " + IntegerToString(g_results.swingHighCount), clrRed);
         SetPanelLine(2, "Swing Lows: " + IntegerToString(g_results.swingLowCount), clrLimeGreen);
         SetPanelLine(3, "Last High: " + DoubleToString(g_results.lastSwingHigh, g_symbolInfo.digits), clrRed);
         SetPanelLine(4, "Last Low: " + DoubleToString(g_results.lastSwingLow, g_symbolInfo.digits), clrLimeGreen);
         SetPanelLine(5, "BOS: " + (g_results.bosDetected ? g_results.bosDirection : "NONE"),
                      g_results.bosDetected ? clrDodgerBlue : clrGray);
         SetPanelLine(6, "CHoCH: " + (g_results.chochDetected ? g_results.chochDirection : "NONE"),
                      g_results.chochDetected ? clrMagenta : clrGray);
         SetPanelLine(8, "PURPOSE: Identify trend structure", clrCyan);
         SetPanelLine(9, "BOS=continuation, CHoCH=reversal", clrCyan);
         break;

      case SECTION_4_SUPPLY_DEMAND:
         SetPanelLine(0, "Demand Zones: " + IntegerToString(g_results.demandZoneCount), clrDodgerBlue);
         SetPanelLine(1, "Supply Zones: " + IntegerToString(g_results.supplyZoneCount), clrCrimson);
         SetPanelLine(2, "In Demand: " + (g_results.inDemandZone ? "YES" : "NO"),
                      g_results.inDemandZone ? clrLimeGreen : clrGray);
         SetPanelLine(3, "In Supply: " + (g_results.inSupplyZone ? "YES" : "NO"),
                      g_results.inSupplyZone ? clrRed : clrGray);
         SetPanelLine(5, "PURPOSE: Find institutional zones", clrCyan);
         SetPanelLine(6, "where price is likely to react", clrCyan);
         break;

      case SECTION_5_FIBONACCI:
         SetPanelLine(0, "Direction: " + g_results.fibDirection,
                      g_results.fibDirection == "BULLISH" ? clrLimeGreen : clrRed);
         SetPanelLine(1, "Swing High: " + DoubleToString(g_results.fibSwingHigh, g_symbolInfo.digits), clrWhite);
         SetPanelLine(2, "Swing Low: " + DoubleToString(g_results.fibSwingLow, g_symbolInfo.digits), clrWhite);
         SetPanelLine(3, "38.2%: " + DoubleToString(g_results.fib382, g_symbolInfo.digits), clrGold);
         SetPanelLine(4, "61.8%: " + DoubleToString(g_results.fib618, g_symbolInfo.digits), clrOrange);
         SetPanelLine(5, "78.6%: " + DoubleToString(g_results.fib786, g_symbolInfo.digits), clrOrange);
         SetPanelLine(6, "In OTE Zone: " + (g_results.inOTEZone ? "YES!" : "NO"),
                      g_results.inOTEZone ? clrLimeGreen : clrGray);
         SetPanelLine(8, "PURPOSE: OTE = 61.8-78.6% zone", clrCyan);
         SetPanelLine(9, "Optimal pullback entry area", clrCyan);
         break;

      case SECTION_6_MACD_RSI:
         SetPanelLine(0, "MACD Line: " + DoubleToString(g_results.macdMain, 5), clrDodgerBlue);
         SetPanelLine(1, "Signal Line: " + DoubleToString(g_results.macdSignal, 5), clrOrange);
         SetPanelLine(2, "Histogram: " + DoubleToString(g_results.macdHistogram, 5),
                      g_results.macdHistogram > 0 ? clrLimeGreen : clrRed);
         SetPanelLine(3, "MACD Trend: " + g_results.macdTrend,
                      StringFind(g_results.macdTrend, "BULLISH") >= 0 ? clrLimeGreen : clrRed);
         SetPanelLine(4, "RSI: " + DoubleToString(g_results.rsiValue, 1), clrYellow);
         SetPanelLine(5, "RSI Status: " + g_results.rsiCondition,
                      g_results.rsiCondition == "OVERBOUGHT" ? clrRed :
                      (g_results.rsiCondition == "OVERSOLD" ? clrLimeGreen : clrGray));
         SetPanelLine(6, "Bull Cross: " + (g_results.macdBullishCross ? "YES" : "NO"), clrWhite);
         SetPanelLine(7, "Bear Cross: " + (g_results.macdBearishCross ? "YES" : "NO"), clrWhite);
         SetPanelLine(9, "PURPOSE: Momentum confirmation", clrCyan);
         break;

      case SECTION_7_FVG:
         SetPanelLine(0, "Bullish FVGs: " + IntegerToString(g_results.bullishFVGCount), clrDodgerBlue);
         SetPanelLine(1, "Bearish FVGs: " + IntegerToString(g_results.bearishFVGCount), clrCrimson);
         SetPanelLine(2, "Price in FVG: " + (g_results.priceInFVG ? "YES - " + g_results.fvgType : "NO"),
                      g_results.priceInFVG ? clrLimeGreen : clrGray);
         if(g_results.priceInFVG)
         {
            SetPanelLine(3, "FVG High: " + DoubleToString(g_results.nearestFVGHigh, g_symbolInfo.digits), clrWhite);
            SetPanelLine(4, "FVG Low: " + DoubleToString(g_results.nearestFVGLow, g_symbolInfo.digits), clrWhite);
         }
         SetPanelLine(6, "PURPOSE: Fair Value Gaps show", clrCyan);
         SetPanelLine(7, "imbalance - price tends to fill", clrCyan);
         break;

      case SECTION_8_ORDER_BLOCKS:
         SetPanelLine(0, "Bullish OBs: " + IntegerToString(g_results.bullishOBCount), clrDodgerBlue);
         SetPanelLine(1, "Bearish OBs: " + IntegerToString(g_results.bearishOBCount), clrCrimson);
         SetPanelLine(2, "Price in OB: " + (g_results.priceInOB ? "YES - " + g_results.obType : "NO"),
                      g_results.priceInOB ? clrLimeGreen : clrGray);
         if(g_results.priceInOB)
         {
            SetPanelLine(3, "OB High: " + DoubleToString(g_results.nearestOBHigh, g_symbolInfo.digits), clrWhite);
            SetPanelLine(4, "OB Low: " + DoubleToString(g_results.nearestOBLow, g_symbolInfo.digits), clrWhite);
         }
         SetPanelLine(6, "PURPOSE: Order Blocks mark", clrCyan);
         SetPanelLine(7, "institutional entry zones", clrCyan);
         break;

      case SECTION_9_NEWS:
         SetPanelLine(0, "News Upcoming: " + (g_results.newsUpcoming ? "YES" : "NO"),
                      g_results.newsUpcoming ? clrOrange : clrLimeGreen);
         SetPanelLine(1, "Event: " + g_results.newsEvent, clrWhite);
         SetPanelLine(2, "Impact: " + g_results.newsImpact,
                      g_results.newsImpact == "HIGH" ? clrRed : clrGray);
         SetPanelLine(3, "Mins to News: " + (g_results.minsToNews > 0 ? IntegerToString(g_results.minsToNews) : "N/A"), clrYellow);
         SetPanelLine(4, "Trading: " + (g_results.tradingAllowed ? "ALLOWED" : "BLOCKED"),
                      g_results.tradingAllowed ? clrLimeGreen : clrRed);
         SetPanelLine(6, "PURPOSE: Avoid trading during", clrCyan);
         SetPanelLine(7, "high impact news events", clrCyan);
         break;

      case SECTION_10_MTF:
         SetPanelLine(0, "H1 Trend: " + g_results.h1Trend,
                      g_results.h1Trend == "BULLISH" ? clrLimeGreen : clrRed);
         SetPanelLine(1, "H4 Trend: " + g_results.h4Trend,
                      g_results.h4Trend == "BULLISH" ? clrLimeGreen : clrRed);
         SetPanelLine(2, "D1 Trend: " + g_results.d1Trend,
                      g_results.d1Trend == "BULLISH" ? clrLimeGreen : clrRed);
         SetPanelLine(3, "Aligned TFs: " + IntegerToString(g_results.alignedTFs) + "/3", clrYellow);
         SetPanelLine(4, "All Aligned: " + (g_results.allAligned ? "YES" : "NO"),
                      g_results.allAligned ? clrLimeGreen : clrOrange);
         SetPanelLine(6, "PURPOSE: Confirm trend across", clrCyan);
         SetPanelLine(7, "multiple timeframes", clrCyan);
         break;

      case SECTION_11_ENTRY:
         SetPanelLine(0, "Entry Signal: " + (g_results.entrySignal ? "YES" : "NO"),
                      g_results.entrySignal ? clrLimeGreen : clrGray);
         SetPanelLine(1, "Direction: " + g_results.entryDirection,
                      g_results.entryDirection == "BUY" ? clrLimeGreen :
                      (g_results.entryDirection == "SELL" ? clrRed : clrGray));
         SetPanelLine(2, "Entry Type: " + g_results.entryType, clrYellow);
         SetPanelLine(3, "Confluence Score: " + IntegerToString(g_results.entryScore) + "/10",
                      g_results.entryScore >= 6 ? clrLimeGreen : clrOrange);
         SetPanelLine(5, "Factors: " + g_results.entryReason, clrWhite);
         SetPanelLine(8, "PURPOSE: Combine all sections", clrCyan);
         SetPanelLine(9, "for high-probability entry", clrCyan);
         break;

      case SECTION_12_RISK:
         SetPanelLine(0, "Risk %: " + DoubleToString(g_results.riskPercent, 1) + "%", clrYellow);
         SetPanelLine(1, "Position Size: " + DoubleToString(g_results.positionSize, 2) + " lots", clrWhite);
         SetPanelLine(2, "Stop Loss: " + DoubleToString(g_results.stopLossPips, 1) + " pips", clrRed);
         SetPanelLine(3, "Take Profit: " + DoubleToString(g_results.takeProfitPips, 1) + " pips", clrLimeGreen);
         SetPanelLine(4, "Risk:Reward: 1:" + DoubleToString(g_results.riskReward, 1), clrCyan);
         SetPanelLine(6, "PURPOSE: Calculate proper", clrCyan);
         SetPanelLine(7, "position size based on risk", clrCyan);
         break;

      case SECTION_13_EXECUTION:
         SetPanelLine(0, "Order Type: " + g_results.orderType,
                      g_results.orderType != "NO SIGNAL" ? clrLimeGreen : clrGray);
         SetPanelLine(1, "Entry: " + DoubleToString(g_results.entryPrice, g_symbolInfo.digits), clrWhite);
         SetPanelLine(2, "SL: " + DoubleToString(g_results.slPrice, g_symbolInfo.digits), clrRed);
         SetPanelLine(3, "TP1: " + DoubleToString(g_results.tp1Price, g_symbolInfo.digits), clrLimeGreen);
         SetPanelLine(4, "TP2: " + DoubleToString(g_results.tp2Price, g_symbolInfo.digits), clrLimeGreen);
         SetPanelLine(5, "TP3: " + DoubleToString(g_results.tp3Price, g_symbolInfo.digits), clrLimeGreen);
         SetPanelLine(7, "PURPOSE: Execute trades with", clrCyan);
         SetPanelLine(8, "proper SL/TP levels", clrCyan);
         break;
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Set Panel Line Text                                               |
//+------------------------------------------------------------------+
void SetPanelLine(int line, string text, color clr)
{
   ObjectSetString(0, g_panelName + "_Line" + IntegerToString(line), OBJPROP_TEXT, text);
   ObjectSetInteger(0, g_panelName + "_Line" + IntegerToString(line), OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| Print Section Report to Experts Tab                               |
//+------------------------------------------------------------------+
void PrintSectionReport()
{
   string sectionNames[] = {"", "ATR Filter", "EMA Analysis", "BOS/CHoCH Structure",
                            "Supply/Demand", "Fibonacci/OTE", "MACD/RSI Momentum",
                            "Fair Value Gaps", "Order Blocks", "News Filter",
                            "Multi-Timeframe", "Entry Logic", "Risk Management", "Trade Execution"};

   Print("");
   Print("═══════════════════════════════════════════════════════════");
   Print("  SECTION ", g_currentSection, ": ", sectionNames[g_currentSection]);
   Print("═══════════════════════════════════════════════════════════");
   Print("Symbol: ", _Symbol, " | Timeframe: ", EnumToString(InpHTF));
   Print("───────────────────────────────────────────────────────────");

   switch(g_currentSection)
   {
      case SECTION_1_ATR:
         Print("ATR Value: ", DoubleToString(g_results.atrPips, 1), " pips");
         Print("Condition: ", g_results.atrCondition);
         Print("Trading Allowed: ", g_results.atrTradingAllowed ? "YES" : "NO");
         break;
      case SECTION_2_EMA:
         Print("EMA 50: ", DoubleToString(g_results.ema50, g_symbolInfo.digits));
         Print("EMA 200: ", DoubleToString(g_results.ema200, g_symbolInfo.digits));
         Print("Trend: ", g_results.emaTrend);
         break;
      // Add more cases as needed...
   }

   Print("═══════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Print Initialization Report                                       |
//+------------------------------------------------------------------+
void PrintInitReport()
{
   Print("");
   Print("═══════════════════════════════════════════════════════════");
   Print("       SECTION STUDY MODE v1.00 - INITIALIZED              ");
   Print("═══════════════════════════════════════════════════════════");
   Print("Symbol: ", _Symbol);
   Print("Higher TF: ", EnumToString(InpHTF));
   Print("Lower TF: ", EnumToString(InpLTF));
   Print("───────────────────────────────────────────────────────────");
   Print("Starting Section: ", InpStudySection);
   Print("Navigation Buttons: ", InpShowNavButtons ? "ON" : "OFF");
   Print("Auto-Refresh: ", InpAutoRefresh ? "ON" : "OFF");
   Print("───────────────────────────────────────────────────────────");
   Print("Use PREV/NEXT buttons to navigate between sections");
   Print("Each section shows its analysis with chart drawings");
   Print("═══════════════════════════════════════════════════════════");
   Print("");
}
//+------------------------------------------------------------------+
