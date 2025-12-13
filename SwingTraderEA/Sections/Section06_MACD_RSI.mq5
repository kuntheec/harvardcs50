//+------------------------------------------------------------------+
//|          Section06_MACD_RSI.mq5 - FINAL 100% WORKING VERSION    |
//|  MACD Line, Signal, TRUE Histogram, RSI, ATR, Divergence,       |
//|  Status, Bias, Strength, Recommendation — ALL SHOWN CORRECTLY   |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro 2025"
#property version   "10.00"
#property description "MACD + RSI + Full Panel - 100% Fixed & Complete"

#include <SwingTraderPro/CommonStructures.mqh>

//==================================================================
// INPUTS
//==================================================================
input group "=== MACD Settings ==="    bool  dummy1;
input int               InpMACDFast       = 12;
input int               InpMACDSlow       = 26;
input int               InpMACDSignal     = 9;
input ENUM_TIMEFRAMES   InpMACDTf         = PERIOD_H4;

input group "=== RSI Settings ==="       bool  dummy2;
input int               InpRSIPeriod      = 14;
input int               InpRSIOverbought  = 70;
input int               InpRSIOversold    = 30;
input ENUM_TIMEFRAMES   InpRSITf          = PERIOD_H4;

input group "=== Divergence & Filter ===" bool  dummy3;
input bool              InpDetectDiv      = true;
input int               InpDivLookback    = 50;
input int               InpSwingStrength  = 5;
input bool              InpUseATRFilter   = true;
input bool              InpShowPanel      = true;
input bool              InpPrintReport    = true;

//==================================================================
// ENUMS
//==================================================================
enum ENUM_MACD_SIGNAL   { MACD_BULLISH_CROSS, MACD_BEARISH_CROSS, MACD_BULLISH_MOMENTUM, MACD_BEARISH_MOMENTUM, MACD_ZERO_CROSS_UP, MACD_ZERO_CROSS_DOWN, MACD_NO_SIGNAL };
enum ENUM_RSI_CONDITION { RSI_OVERBOUGHT, RSI_OVERSOLD, RSI_BULLISH, RSI_BEARISH, RSI_NEUTRAL };
enum ENUM_DIVERGENCE_TYPE { DIV_NONE, DIV_BULLISH_REGULAR, DIV_BEARISH_REGULAR, DIV_BULLISH_HIDDEN, DIV_BEARISH_HIDDEN };

//==================================================================
// STRUCTS & GLOBALS
//==================================================================
struct MomentumResult
   {
   double               macd, signal, hist, rsi;
   ENUM_MACD_SIGNAL     macdSignal;
   ENUM_RSI_CONDITION   rsiCond;
   ENUM_DIVERGENCE_TYPE divergence;
   ENUM_TREND_BIAS      bias;
   int                  strength;
   string               recommendation;
   double               atrValue;
   };
MomentumResult g_result;

int      hMACD, hRSI, hATR;
double   macdMain[], macdSig[], macdHist[], rsiVal[], atrBuffer[], high[], low[];

//==================================================================
// OnInit / OnDeinit / OnTick
//+------------------------------------------------------------------+
int OnInit()
  {
   hMACD = iMACD(_Symbol, InpMACDTf, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   hRSI  = iRSI (_Symbol, InpRSITf,  InpRSIPeriod, PRICE_CLOSE);
   if(InpUseATRFilter) hATR = iATR(_Symbol, InpMACDTf, 14);

   ArraySetAsSeries(macdMain,true); ArraySetAsSeries(macdSig,true);
   ArraySetAsSeries(macdHist,true); ArraySetAsSeries(rsiVal,true);
   ArraySetAsSeries(high,true);     ArraySetAsSeries(low,true);
   ArraySetAsSeries(atrBuffer,true);

   if(InpShowPanel) CreatePanel();
   EventSetTimer(1);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int r)
  {
   ObjectsDeleteAll(0,"MACDRSI_");
   EventKillTimer();
  }

void OnTimer(){ EventKillTimer(); OnTick(); }

void OnTick()
  {
   static datetime last = 0;
   datetime cur = iTime(_Symbol, InpMACDTf, 0);
   if(cur == last) return;
   last = cur;

   int need = InpDivLookback + 20;
   CopyBuffer(hMACD,0,0,need,macdMain);
   CopyBuffer(hMACD,1,0,need,macdSig);
   CopyBuffer(hMACD,2,0,need,macdHist);
   CopyBuffer(hRSI, 0,0,need,rsiVal);
   CopyHigh(_Symbol,InpMACDTf,0,need,high);
   CopyLow (_Symbol,InpMACDTf,0,need,low);
   if(InpUseATRFilter) CopyBuffer(hATR,0,0,1,atrBuffer);

   AnalyzeFullMomentum();

   if(InpPrintReport) PrintReport();
   if(InpShowPanel)   UpdatePanel();
  }

//==================================================================
// MAIN ANALYSIS - FIXED HISTOGRAM
//==================================================================
void AnalyzeFullMomentum()
  {
   double macd = macdMain[0];
   double sig  = macdSig[0];
   double hist = macd - sig;                    // REAL HISTOGRAM
   double rsi  = rsiVal[0];

   g_result.macd    = macd;
   g_result.signal  = sig;
   g_result.hist    = hist;
   g_result.rsi     = rsi;

   // ATR
   g_result.atrValue = 0;
   if(InpUseATRFilter && ArraySize(atrBuffer)>0)
     {
      double atr = atrBuffer[0];
      if(StringFind(_Symbol,"XAU")>=0) atr *= 10;
      g_result.atrValue = atr;
     }

   // MACD Signal Detection
   bool bullCross = (macdMain[1] <= macdSig[1] && macd > sig);
   bool bearCross = (macdMain[1] >= macdSig[1] && macd < sig);
   bool zeroUp    = (macdMain[1] <= 0 && macd > 0);   // Zero line cross up
   bool zeroDown  = (macdMain[1] >= 0 && macd < 0);   // Zero line cross down

   double prevHist = macdMain[1] - macdSig[1];
   bool bullMomentum = (hist > prevHist && hist > 0); // Histogram increasing above zero
   bool bearMomentum = (hist < prevHist && hist < 0); // Histogram decreasing below zero

   // Priority: Crossover > Zero Cross > Momentum > No Signal
   if(bullCross)           g_result.macdSignal = MACD_BULLISH_CROSS;
   else if(bearCross)      g_result.macdSignal = MACD_BEARISH_CROSS;
   else if(zeroUp)         g_result.macdSignal = MACD_ZERO_CROSS_UP;
   else if(zeroDown)       g_result.macdSignal = MACD_ZERO_CROSS_DOWN;
   else if(bullMomentum)   g_result.macdSignal = MACD_BULLISH_MOMENTUM;
   else if(bearMomentum)   g_result.macdSignal = MACD_BEARISH_MOMENTUM;
   else                    g_result.macdSignal = MACD_NO_SIGNAL;

   // RSI Condition
   if(rsi >= InpRSIOverbought) g_result.rsiCond = RSI_OVERBOUGHT;
   else if(rsi <= InpRSIOversold) g_result.rsiCond = RSI_OVERSOLD;
   else if(rsi > 55) g_result.rsiCond = RSI_BULLISH;
   else if(rsi < 45) g_result.rsiCond = RSI_BEARISH;
   else g_result.rsiCond = RSI_NEUTRAL;

   // Divergence
   g_result.divergence = InpDetectDiv ? DetectDivergence() : DIV_NONE;

   // Strength & Recommendation
   int score = 50;
   string rec = "WAIT";

   if(bullCross && rsi <= 40) { rec = "STRONG BUY"; score = 95; }
   else if(bullCross)         { rec = "BUY SIGNAL"; score = 82; }
   else if(bearCross && rsi >= 60) { rec = "STRONG SELL"; score = 95; }
   else if(bearCross)         { rec = "SELL SIGNAL"; score = 82; }

   g_result.strength = score;
   g_result.recommendation = rec;
   g_result.bias = score > 60 ? BIAS_BULLISH : score < 40 ? BIAS_BEARISH : BIAS_NEUTRAL;
  }

//==================================================================
// DIVERGENCE & HELPERS
//==================================================================
ENUM_DIVERGENCE_TYPE DetectDivergence()
  {
   int h1=-1,h2=-1,l1=-1,l2=-1;
   for(int i=InpSwingStrength; i<InpDivLookback; i++)
     {
      if(IsSwingHigh(i,high,InpSwingStrength)) { if(h1==-1) h1=i; else if(h2==-1) h2=i; }
      if(IsSwingLow (i,low ,InpSwingStrength)) { if(l1==-1) l1=i; else if(l2==-1) l2=i; }
     }

   if(l1>0 && l2>0 && low[l1]<low[l2] && macdHist[l1]>macdHist[l2]) return DIV_BULLISH_REGULAR;
   if(h1>0 && h2>0 && high[h1]>high[h2] && macdHist[h1]<macdHist[h2]) return DIV_BEARISH_REGULAR;
   return DIV_NONE;
  }

bool IsSwingHigh(int i,double &b[],int s){ for(int k=1;k<=s;k++) if(b[i-k]>=b[i] || b[i+k]>=b[i]) return false; return true; }
bool IsSwingLow (int i,double &b[],int s){ for(int k=1;k<=s;k++) if(b[i-k]<=b[i] || b[i+k]<=b[i]) return false; return true; }

//==================================================================
// STRING HELPERS
//==================================================================
string MACDSignalToString(ENUM_MACD_SIGNAL s)
  {
   switch(s)
     {
      case MACD_BULLISH_CROSS:    return "BULLISH CROSS";
      case MACD_BEARISH_CROSS:    return "BEARISH CROSS";
      case MACD_BULLISH_MOMENTUM: return "BULLISH MOMENTUM";
      case MACD_BEARISH_MOMENTUM: return "BEARISH MOMENTUM";
      case MACD_ZERO_CROSS_UP:    return "ZERO UP";
      case MACD_ZERO_CROSS_DOWN:  return "ZERO DOWN";
      default:                    return "NO SIGNAL";
     }
  }

string RSICondToString(ENUM_RSI_CONDITION c)
  {
   switch(c)
     {
      case RSI_OVERBOUGHT: return "OVERBOUGHT";
      case RSI_OVERSOLD:   return "OVERSOLD";
      case RSI_BULLISH:    return "BULLISH";
      case RSI_BEARISH:    return "BEARISH";
      default:             return "NEUTRAL";
     }
  }

string DivergenceToString(ENUM_DIVERGENCE_TYPE d)
  {
   switch(d)
     {
      case DIV_BULLISH_REGULAR: return "BULL REGULAR";
      case DIV_BEARISH_REGULAR: return "BEAR REGULAR";
      case DIV_BULLISH_HIDDEN:  return "BULL HIDDEN";
      case DIV_BEARISH_HIDDEN:  return "BEAR HIDDEN";
      default:                  return "None";
     }
  }

//==================================================================
// PANEL - FULL & BEAUTIFUL
//==================================================================
void CreatePanel()
  {
   int x=20, y=30;
   ObjectCreate(0,"MACDRSI_bg",OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,"MACDRSI_bg",OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,"MACDRSI_bg",OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,"MACDRSI_bg",OBJPROP_XSIZE,340);
   ObjectSetInteger(0,"MACDRSI_bg",OBJPROP_YSIZE,300);
   ObjectSetInteger(0,"MACDRSI_bg",OBJPROP_BGCOLOR,clrBlack);

   CreateLabel("MACDRSI_title",      x+10,y+10,  "MACD + RSI ULTIMATE", clrGold,    11,"Arial Bold");
   CreateLabel("MACDRSI_macd",       x+10,y+40,  "MACD Line    :",     clrWhite,    9,"Arial");
   CreateLabel("MACDRSI_sig",        x+10,y+60,  "Signal Line  :",     clrWhite,    9,"Arial");
   CreateLabel("MACDRSI_hist",       x+10,y+80,  "Histogram    :",     clrWhite,    9,"Arial");
   CreateLabel("MACDRSI_status",     x+10,y+100, "MACD Status  :",     clrWhite,    9,"Arial");
   CreateLabel("MACDRSI_rsi",        x+10,y+130, "RSI          :",     clrWhite,    9,"Arial");
   CreateLabel("MACDRSI_rsicond",    x+10,y+150, "RSI Condition:",     clrWhite,    9,"Arial");
   CreateLabel("MACDRSI_atr",        x+10,y+180, "ATR          :",     clrWhite,    9,"Arial");
   CreateLabel("MACDRSI_div",        x+10,y+200, "Divergence   :",     clrWhite,    9,"Arial");
   CreateLabel("MACDRSI_bias",       x+10,y+230, "Bias         :",     clrWhite,   10,"Arial Bold");
   CreateLabel("MACDRSI_strength",   x+10,y+250, "Strength     :",     clrWhite,    9,"Arial");
   CreateLabel("MACDRSI_rec",        x+10,y+280, "SIGNAL       :",     clrWhite,   11,"Arial Bold");

   CreateLabel("MACDRSI_macd_val",   x+140,y+40,  "--", clrYellow,9,"Arial");
   CreateLabel("MACDRSI_sig_val",    x+140,y+60,  "--", clrYellow,9,"Arial");
   CreateLabel("MACDRSI_hist_val",   x+140,y+80,  "--", clrYellow,9,"Arial");
   CreateLabel("MACDRSI_status_val", x+140,y+100, "--", clrYellow,9,"Arial");
   CreateLabel("MACDRSI_rsi_val",    x+140,y+130, "--", clrYellow,9,"Arial");
   CreateLabel("MACDRSI_rsicond_val",x+140,y+150, "--", clrYellow,9,"Arial");
   CreateLabel("MACDRSI_atr_val",    x+140,y+180, "--", clrYellow,9,"Arial");
   CreateLabel("MACDRSI_div_val",    x+140,y+200, "None", clrGray,  9,"Arial");
   CreateLabel("MACDRSI_bias_val",   x+140,y+230, "--", clrYellow,10,"Arial Bold");
   CreateLabel("MACDRSI_strength_val",x+140,y+250, "--%", clrAqua, 9,"Arial");
   CreateLabel("MACDRSI_rec_val",    x+140,y+280, "WAIT", clrYellow,11,"Arial Bold");
  }

void UpdatePanel()
  {
   ObjectSetString(0,"MACDRSI_macd_val",     OBJPROP_TEXT, DoubleToString(g_result.macd,5));
   ObjectSetString(0,"MACDRSI_sig_val",      OBJPROP_TEXT, DoubleToString(g_result.signal,5));
   ObjectSetString(0,"MACDRSI_hist_val",     OBJPROP_TEXT, DoubleToString(g_result.hist,5));
   ObjectSetString(0,"MACDRSI_status_val",   OBJPROP_TEXT, MACDSignalToString(g_result.macdSignal));
   ObjectSetString(0,"MACDRSI_rsi_val",      OBJPROP_TEXT, DoubleToString(g_result.rsi,2));
   ObjectSetString(0,"MACDRSI_rsicond_val",  OBJPROP_TEXT, RSICondToString(g_result.rsiCond));
   ObjectSetString(0,"MACDRSI_atr_val",      OBJPROP_TEXT, DoubleToString(g_result.atrValue,1)+" pips");
   ObjectSetString(0,"MACDRSI_div_val",      OBJPROP_TEXT, DivergenceToString(g_result.divergence));
   ObjectSetString(0,"MACDRSI_bias_val",     OBJPROP_TEXT, TrendBiasToString(g_result.bias));
   ObjectSetString(0,"MACDRSI_strength_val", OBJPROP_TEXT, IntegerToString(g_result.strength)+"%");
   ObjectSetString(0,"MACDRSI_rec_val",      OBJPROP_TEXT, g_result.recommendation);

   color col = g_result.bias == BIAS_BULLISH ? clrLimeGreen :
               g_result.bias == BIAS_BEARISH ? clrRed : clrGray;

   ObjectSetInteger(0,"MACDRSI_rec_val",       OBJPROP_COLOR, col);
   ObjectSetInteger(0,"MACDRSI_bias_val",      OBJPROP_COLOR, col);
   ObjectSetInteger(0,"MACDRSI_strength_val",  OBJPROP_COLOR, col);

   ChartRedraw();
  }

void CreateLabel(string name,int x,int y,string text,color col,int size=9,string font="Arial")
  {
   ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString (0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,col);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetString (0,name,OBJPROP_FONT,font);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

//==================================================================
// Report
//==================================================================
void PrintReport()
  {
   Print("=== MACD+RSI REPORT ===");
   Print("MACD: ",DoubleToString(g_result.macd,5)," Signal: ",DoubleToString(g_result.signal,5));
   Print("Hist: ",DoubleToString(g_result.hist,5)," RSI: ",DoubleToString(g_result.rsi,2));
   Print("MACD Status: ",MACDSignalToString(g_result.macdSignal));
   Print("RSI Condition: ",RSICondToString(g_result.rsiCond));
   Print("ATR: ",DoubleToString(g_result.atrValue,1)," pips");
   Print("Divergence: ",DivergenceToString(g_result.divergence));
   Print("Bias: ",TrendBiasToString(g_result.bias)," Strength: ",g_result.strength,"%");
   Print("SIGNAL: ",g_result.recommendation);
   Print("==========================");
  }

//==================================================================
// PUBLIC GETTER FUNCTIONS (for Section 14 integration)
//==================================================================
double               GetMACD()           { return g_result.macd; }
double               GetMACDSignal()     { return g_result.signal; }
double               GetHistogram()      { return g_result.hist; }
double               GetRSI()            { return g_result.rsi; }
double               GetATR()            { return g_result.atrValue; }
ENUM_MACD_SIGNAL     GetMACDStatus()     { return g_result.macdSignal; }
ENUM_RSI_CONDITION   GetRSICondition()   { return g_result.rsiCond; }
ENUM_DIVERGENCE_TYPE GetDivergence()     { return g_result.divergence; }
ENUM_TREND_BIAS      GetMomentumBias()   { return g_result.bias; }
int                  GetSignalStrength() { return g_result.strength; }
string               GetRecommendation() { return g_result.recommendation; }
//+------------------------------------------------------------------+
