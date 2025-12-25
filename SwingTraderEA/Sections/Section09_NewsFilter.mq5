//+------------------------------------------------------------------+
//|                                        Section09_NewsFilter.mq5 |
//|                                      SwingTrader Pro EA          |
//|                    Section 9: Economic News Filter (v2.00)       |
//+------------------------------------------------------------------+
#property copyright "SwingTrader Pro"
#property link      ""
#property version   "2.00"
#property description "Section 9: Economic News Filter v2.00"
#property description "Filters trading during high-impact news events"
#property description "Dynamic block times, risk scoring, ATR extension"

//+------------------------------------------------------------------+
//| Modification History                                              |
//+------------------------------------------------------------------+
// 2025.12.25 v2.00 - Major improvements based on Grok SMC review:
//                    - Dynamic block times by impact (High:60/45, Med:30/20, Low:15/10)
//                    - Event risk scoring (NFP/FOMC=10, GDP=7, etc.)
//                    - Enhanced close logic (hours before, not 5 min)
//                    - ATR-based post-news extension
//                    - Optimized timer and event caching
// 2025.12.23 v1.00 - Initial release
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Include Files                                                     |
//+------------------------------------------------------------------+
#include <SwingTraderPro/CommonStructures.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== News Filter Settings ==="
input bool     InpEnableNewsFilter    = true;     // Enable News Filter
input bool     InpFilterHighImpact    = true;     // Filter High Impact News
input bool     InpFilterMediumImpact  = false;    // Filter Medium Impact News
input bool     InpFilterLowImpact     = false;    // Filter Low Impact News

input group "=== Time Restrictions (Dynamic by Impact) ==="
input bool     InpUseDynamicTimes     = true;     // Use Dynamic Block Times (by impact)
input int      InpHighMinsBefore      = 60;       // High Impact: Minutes Before
input int      InpHighMinsAfter       = 45;       // High Impact: Minutes After
input int      InpMedMinsBefore       = 30;       // Medium Impact: Minutes Before
input int      InpMedMinsAfter        = 20;       // Medium Impact: Minutes After
input int      InpLowMinsBefore       = 15;       // Low Impact: Minutes Before
input int      InpLowMinsAfter        = 10;       // Low Impact: Minutes After
input int      InpMinutesBefore       = 30;       // Fixed Minutes Before (if dynamic disabled)
input int      InpMinutesAfter        = 30;       // Fixed Minutes After (if dynamic disabled)

input group "=== Close Position Settings ==="
input bool     InpCloseBeforeNews     = false;    // Close Positions Before High Impact News
input int      InpCloseHoursBefore    = 2;        // Hours Before High Impact to Close
input bool     InpPartialCloseEnabled = false;    // Enable Partial Close for Medium Impact
input double   InpPartialClosePercent = 50.0;     // Partial Close Percentage

input group "=== ATR Extension Settings ==="
input bool     InpUseATRExtension     = true;     // Extend Block if ATR Spikes Post-News
input double   InpATRSpikeMultiplier  = 1.5;      // ATR Spike Threshold (x normal)
input int      InpATRPeriod           = 14;       // ATR Period
input int      InpMaxExtensionMins    = 30;       // Max Extension Minutes

input group "=== Currency Filter ==="
input bool     InpFilterBaseCurrency  = true;     // Filter Base Currency News
input bool     InpFilterQuoteCurrency = true;     // Filter Quote Currency News
input bool     InpFilterUSD           = true;     // Always Filter USD News
input bool     InpFilterGlobalEvents  = true;     // Filter Global Events (NFP, FOMC, etc)

input group "=== Manual News Events ==="
input bool     InpUseManualEvents     = true;     // Use Manual News Events
input string   InpManualEvents        = "";       // Manual Events (Format: YYYY.MM.DD HH:MM,YYYY.MM.DD HH:MM)

input group "=== Display Settings ==="
input bool     InpShowPanel           = true;     // Show Info Panel
input color    InpNewsActiveColor     = clrRed;   // Active News Warning Color
input color    InpSafeColor           = clrLimeGreen; // Safe to Trade Color
input int      InpPanelX              = 20;       // Panel X Position
input int      InpPanelY              = 30;       // Panel Y Position

input group "=== Report Settings ==="
input bool     InpPrintReport         = true;     // Print Report to Experts Tab

//+------------------------------------------------------------------+
//| Enumerations                                                      |
//+------------------------------------------------------------------+
enum ENUM_NEWS_IMPACT
{
   IMPACT_NONE,             // No impact
   IMPACT_LOW,              // Low impact
   IMPACT_MEDIUM,           // Medium impact
   IMPACT_HIGH              // High impact
};

enum ENUM_TRADING_STATUS
{
   TRADING_ALLOWED,         // Trading is allowed
   TRADING_BLOCKED_BEFORE,  // Blocked - news upcoming
   TRADING_BLOCKED_DURING,  // Blocked - news ongoing
   TRADING_BLOCKED_AFTER    // Blocked - post-news volatility
};

//+------------------------------------------------------------------+
//| Structures                                                        |
//+------------------------------------------------------------------+
struct NewsEventV2
{
   string            name;           // Event name
   string            currency;       // Affected currency
   datetime          eventTime;      // Event time
   ENUM_NEWS_IMPACT  impact;         // Event impact level
   int               riskScore;      // Risk score 1-10 (NFP/FOMC=10, GDP=7, etc.)
   int               minsBefore;     // Dynamic minutes before
   int               minsAfter;      // Dynamic minutes after
   bool              isManual;       // Is manual entry
};

struct NewsFilterResult
{
   ENUM_TRADING_STATUS tradingStatus;
   bool              tradingAllowed;
   NewsEventV2       nextEvent;          // Next upcoming event
   NewsEventV2       currentEvent;       // Current/recent event affecting trading
   int               minutesToNextNews;  // Minutes until next news
   int               minutesSinceLastNews; // Minutes since last news
   int               upcomingHighCount;  // High impact events in next 24h
   int               upcomingMediumCount;// Medium impact events in next 24h
   int               currentRiskScore;   // Current event risk score
   bool              atrExtended;        // Is block extended due to ATR spike
   int               extensionMinutes;   // Additional extension minutes
   string            statusMessage;
   datetime          lastUpdate;
};

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
// News events array
NewsEventV2       g_newsEvents[];
int               g_newsEventCount;

// Analysis result
NewsFilterResult  g_result;

// Panel
string            g_panelName = "NewsPanel";

// Currency info
string            g_baseCurrency;
string            g_quoteCurrency;

// Calendar availability flag
bool              g_calendarAvailable = false;

// ATR for extension
int               g_atrHandle;
double            g_atrBuffer[];
double            g_normalATR = 0;
double            g_currentATR = 0;

// Event caching
datetime          g_lastEventRefresh = 0;
int               g_eventCacheMinutes = 15;  // Refresh events every 15 min

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Extract base and quote currencies from symbol
   g_baseCurrency = StringSubstr(_Symbol, 0, 3);
   g_quoteCurrency = StringSubstr(_Symbol, 3, 3);

   // Handle special symbols
   if(StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0)
   {
      g_baseCurrency = "XAU";
      g_quoteCurrency = "USD";
   }
   else if(StringFind(_Symbol, "XAG") >= 0 || StringFind(_Symbol, "SILVER") >= 0)
   {
      g_baseCurrency = "XAG";
      g_quoteCurrency = "USD";
   }

   // Initialize news events array
   ArrayResize(g_newsEvents, 0);
   g_newsEventCount = 0;

   // Initialize ATR handle for extension feature
   if(InpUseATRExtension)
   {
      g_atrHandle = iATR(_Symbol, PERIOD_H1, InpATRPeriod);
      if(g_atrHandle == INVALID_HANDLE)
      {
         Print("WARNING: Failed to create ATR handle for news extension");
      }
      ArraySetAsSeries(g_atrBuffer, true);

      // Get initial ATR as baseline
      if(CopyBuffer(g_atrHandle, 0, 0, 20, g_atrBuffer) >= 20)
      {
         double sum = 0;
         for(int i = 0; i < 20; i++) sum += g_atrBuffer[i];
         g_normalATR = sum / 20.0;
         g_currentATR = g_atrBuffer[0];
      }
   }

   // Check if economic calendar is available
   CheckCalendarAvailability();

   // Load manual events
   if(InpUseManualEvents && StringLen(InpManualEvents) > 0)
      LoadManualEvents();

   // Print initialization
   PrintInitReport();

   // Create panel
   if(InpShowPanel)
      CreatePanel();

   // Run initial analysis
   AnalyzeNews();

   // Update panel with initial values
   if(InpShowPanel)
      UpdatePanel();

   // Set timer for periodic updates
   EventSetTimer(60);  // Update every minute

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   // Remove panel
   DeletePanel();

   Print("=================================================");
   Print("News Filter EA Deinitialized");
   Print("=================================================");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // News check is done on timer, but we can update panel more frequently
   static datetime lastUpdate = 0;
   datetime currentTime = TimeCurrent();

   // Update every 10 seconds
   if(currentTime - lastUpdate >= 10)
   {
      lastUpdate = currentTime;
      CheckTradingStatus();
      if(InpShowPanel) UpdatePanel();
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                    |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Only refresh events from calendar every 15 minutes (caching)
   datetime currentTime = TimeCurrent();
   bool needsRefresh = (currentTime - g_lastEventRefresh) >= (g_eventCacheMinutes * 60);

   if(needsRefresh)
   {
      // Full news analysis (refresh from calendar)
      AnalyzeNews();
      g_lastEventRefresh = currentTime;
   }
   else
   {
      // Just check trading status (no calendar refresh)
      CheckTradingStatus();
      CountUpcomingEvents();
   }

   if(InpShowPanel) UpdatePanel();
}

//+------------------------------------------------------------------+
//| Check Calendar Availability                                       |
//+------------------------------------------------------------------+
void CheckCalendarAvailability()
{
   // Try to access the calendar to see if it's available
   MqlCalendarValue values[];

   datetime from = TimeCurrent();
   datetime to = from + 86400;  // Next 24 hours

   // Attempt to get calendar values
   int count = CalendarValueHistory(values, from, to);

   if(count >= 0)
   {
      g_calendarAvailable = true;
      Print("Economic Calendar is available");
   }
   else
   {
      g_calendarAvailable = false;
      Print("Economic Calendar not available - using manual events only");
   }
}

//+------------------------------------------------------------------+
//| Main News Analysis Function                                       |
//+------------------------------------------------------------------+
void AnalyzeNews()
{
   if(!InpEnableNewsFilter)
   {
      g_result.tradingStatus = TRADING_ALLOWED;
      g_result.tradingAllowed = true;
      g_result.statusMessage = "News filter disabled";
      g_result.lastUpdate = TimeCurrent();
      return;
   }

   // Clear previous events
   ArrayResize(g_newsEvents, 0);
   g_newsEventCount = 0;

   // Load events from economic calendar
   if(g_calendarAvailable)
      LoadCalendarEvents();

   // Reload manual events
   if(InpUseManualEvents && StringLen(InpManualEvents) > 0)
      LoadManualEvents();

   // Check trading status
   CheckTradingStatus();

   // Count upcoming events
   CountUpcomingEvents();

   g_result.lastUpdate = TimeCurrent();

   // Print report
   if(InpPrintReport)
      PrintNewsReport();
}

//+------------------------------------------------------------------+
//| Load Events from Economic Calendar                                |
//+------------------------------------------------------------------+
void LoadCalendarEvents()
{
   MqlCalendarValue values[];

   datetime from = TimeCurrent() - InpMinutesAfter * 60;  // Include recent events
   datetime to = TimeCurrent() + 86400;  // Next 24 hours

   int count = CalendarValueHistory(values, from, to);

   if(count <= 0) return;

   for(int i = 0; i < count; i++)
   {
      // Get event details
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id, event))
         continue;

      // Get country details
      MqlCalendarCountry country;
      if(!CalendarCountryById(event.country_id, country))
         continue;

      // Check impact level
      ENUM_NEWS_IMPACT impact = IMPACT_NONE;
      switch(event.importance)
      {
         case CALENDAR_IMPORTANCE_HIGH:
            impact = IMPACT_HIGH;
            break;
         case CALENDAR_IMPORTANCE_MODERATE:
            impact = IMPACT_MEDIUM;
            break;
         case CALENDAR_IMPORTANCE_LOW:
            impact = IMPACT_LOW;
            break;
         default:
            continue;
      }

      // Filter by impact setting
      if(impact == IMPACT_LOW && !InpFilterLowImpact) continue;
      if(impact == IMPACT_MEDIUM && !InpFilterMediumImpact) continue;
      if(impact == IMPACT_HIGH && !InpFilterHighImpact) continue;

      // Check currency filter
      string eventCurrency = country.currency;
      bool relevant = false;

      if(InpFilterBaseCurrency && eventCurrency == g_baseCurrency)
         relevant = true;
      if(InpFilterQuoteCurrency && eventCurrency == g_quoteCurrency)
         relevant = true;
      if(InpFilterUSD && eventCurrency == "USD")
         relevant = true;
      if(InpFilterGlobalEvents && IsGlobalEvent(event.name))
         relevant = true;

      if(!relevant) continue;

      // Add event
      AddNewsEvent(event.name, eventCurrency, values[i].time, impact, false);
   }
}

//+------------------------------------------------------------------+
//| Check if event is a global high-impact event                      |
//+------------------------------------------------------------------+
bool IsGlobalEvent(string eventName)
{
   string lowerName = eventName;
   StringToLower(lowerName);

   // Global events that affect all markets
   if(StringFind(lowerName, "nonfarm") >= 0) return true;
   if(StringFind(lowerName, "nfp") >= 0) return true;
   if(StringFind(lowerName, "fomc") >= 0) return true;
   if(StringFind(lowerName, "fed") >= 0 && StringFind(lowerName, "rate") >= 0) return true;
   if(StringFind(lowerName, "ecb") >= 0 && StringFind(lowerName, "rate") >= 0) return true;
   if(StringFind(lowerName, "boe") >= 0 && StringFind(lowerName, "rate") >= 0) return true;
   if(StringFind(lowerName, "rba") >= 0 && StringFind(lowerName, "rate") >= 0) return true;
   if(StringFind(lowerName, "cpi") >= 0) return true;
   if(StringFind(lowerName, "gdp") >= 0) return true;
   if(StringFind(lowerName, "unemployment") >= 0) return true;
   if(StringFind(lowerName, "interest rate") >= 0) return true;

   return false;
}

//+------------------------------------------------------------------+
//| Calculate Event Risk Score (1-10)                                 |
//+------------------------------------------------------------------+
int CalculateRiskScore(string eventName, ENUM_NEWS_IMPACT impact)
{
   string lowerName = eventName;
   StringToLower(lowerName);

   // Tier 1: Maximum Risk (Score 10) - Market Moving Events
   if(StringFind(lowerName, "nonfarm") >= 0 || StringFind(lowerName, "nfp") >= 0)
      return 10;
   if(StringFind(lowerName, "fomc") >= 0)
      return 10;
   if(StringFind(lowerName, "fed") >= 0 && StringFind(lowerName, "rate") >= 0)
      return 10;

   // Tier 2: Very High Risk (Score 8-9)
   if(StringFind(lowerName, "cpi") >= 0)
      return 9;
   if(StringFind(lowerName, "ecb") >= 0 && StringFind(lowerName, "rate") >= 0)
      return 9;
   if(StringFind(lowerName, "boe") >= 0 && StringFind(lowerName, "rate") >= 0)
      return 9;

   // Tier 3: High Risk (Score 7)
   if(StringFind(lowerName, "gdp") >= 0)
      return 7;
   if(StringFind(lowerName, "retail sales") >= 0)
      return 7;
   if(StringFind(lowerName, "unemployment") >= 0)
      return 7;
   if(StringFind(lowerName, "pmi") >= 0)
      return 7;

   // Tier 4: Medium Risk (Score 5-6)
   if(StringFind(lowerName, "trade balance") >= 0)
      return 6;
   if(StringFind(lowerName, "housing") >= 0)
      return 5;
   if(StringFind(lowerName, "confidence") >= 0)
      return 5;

   // Default based on impact level
   switch(impact)
   {
      case IMPACT_HIGH:   return 6;
      case IMPACT_MEDIUM: return 4;
      case IMPACT_LOW:    return 2;
      default:            return 1;
   }
}

//+------------------------------------------------------------------+
//| Get Dynamic Block Minutes by Impact                               |
//+------------------------------------------------------------------+
void GetDynamicBlockMinutes(ENUM_NEWS_IMPACT impact, int &minsBefore, int &minsAfter)
{
   if(!InpUseDynamicTimes)
   {
      minsBefore = InpMinutesBefore;
      minsAfter = InpMinutesAfter;
      return;
   }

   switch(impact)
   {
      case IMPACT_HIGH:
         minsBefore = InpHighMinsBefore;
         minsAfter = InpHighMinsAfter;
         break;
      case IMPACT_MEDIUM:
         minsBefore = InpMedMinsBefore;
         minsAfter = InpMedMinsAfter;
         break;
      case IMPACT_LOW:
         minsBefore = InpLowMinsBefore;
         minsAfter = InpLowMinsAfter;
         break;
      default:
         minsBefore = InpMinutesBefore;
         minsAfter = InpMinutesAfter;
   }
}

//+------------------------------------------------------------------+
//| Check ATR Spike for Post-News Extension                           |
//+------------------------------------------------------------------+
int CheckATRExtension()
{
   if(!InpUseATRExtension || g_atrHandle == INVALID_HANDLE)
      return 0;

   // Update current ATR
   if(CopyBuffer(g_atrHandle, 0, 0, 1, g_atrBuffer) < 1)
      return 0;

   g_currentATR = g_atrBuffer[0];

   // Check if ATR is spiking
   if(g_normalATR > 0 && g_currentATR > g_normalATR * InpATRSpikeMultiplier)
   {
      // Calculate extension proportional to spike
      double spikeRatio = g_currentATR / g_normalATR;
      int extension = (int)((spikeRatio - 1.0) * InpMaxExtensionMins);
      return MathMin(extension, InpMaxExtensionMins);
   }

   return 0;
}

//+------------------------------------------------------------------+
//| Get Impact String                                                 |
//+------------------------------------------------------------------+
string GetImpactString(ENUM_NEWS_IMPACT impact)
{
   switch(impact)
   {
      case IMPACT_HIGH:   return "HIGH";
      case IMPACT_MEDIUM: return "MED";
      case IMPACT_LOW:    return "LOW";
      default:            return "?";
   }
}

//+------------------------------------------------------------------+
//| Load Manual Events                                                |
//+------------------------------------------------------------------+
void LoadManualEvents()
{
   if(StringLen(InpManualEvents) == 0) return;

   string events[];
   int count = StringSplit(InpManualEvents, ',', events);

   for(int i = 0; i < count; i++)
   {
      string eventStr = events[i];
      StringTrimLeft(eventStr);
      StringTrimRight(eventStr);

      if(StringLen(eventStr) < 16) continue;  // Minimum: YYYY.MM.DD HH:MM

      datetime eventTime = StringToTime(eventStr);
      if(eventTime > 0)
      {
         AddNewsEvent("Manual Event", "ALL", eventTime, IMPACT_HIGH, true);
      }
   }
}

//+------------------------------------------------------------------+
//| Add News Event                                                    |
//+------------------------------------------------------------------+
void AddNewsEvent(string name, string currency, datetime eventTime,
                  ENUM_NEWS_IMPACT impact, bool isManual)
{
   int count = ArraySize(g_newsEvents);
   ArrayResize(g_newsEvents, count + 1);

   g_newsEvents[count].name = name;
   g_newsEvents[count].currency = currency;
   g_newsEvents[count].eventTime = eventTime;
   g_newsEvents[count].impact = impact;
   g_newsEvents[count].isManual = isManual;

   // Calculate risk score
   g_newsEvents[count].riskScore = CalculateRiskScore(name, impact);

   // Get dynamic block times
   int minsBefore, minsAfter;
   GetDynamicBlockMinutes(impact, minsBefore, minsAfter);
   g_newsEvents[count].minsBefore = minsBefore;
   g_newsEvents[count].minsAfter = minsAfter;

   g_newsEventCount = count + 1;
}

//+------------------------------------------------------------------+
//| Check Trading Status                                              |
//+------------------------------------------------------------------+
void CheckTradingStatus()
{
   if(!InpEnableNewsFilter)
   {
      g_result.tradingStatus = TRADING_ALLOWED;
      g_result.tradingAllowed = true;
      g_result.statusMessage = "News filter disabled";
      g_result.atrExtended = false;
      g_result.extensionMinutes = 0;
      return;
   }

   datetime currentTime = TimeCurrent();
   g_result.tradingStatus = TRADING_ALLOWED;
   g_result.tradingAllowed = true;
   g_result.minutesToNextNews = 9999;
   g_result.minutesSinceLastNews = 9999;
   g_result.statusMessage = "Safe to trade";
   g_result.currentRiskScore = 0;
   g_result.atrExtended = false;
   g_result.extensionMinutes = 0;

   bool foundNextEvent = false;

   // Check for ATR extension (post-news volatility)
   int atrExtension = CheckATRExtension();

   for(int i = 0; i < g_newsEventCount; i++)
   {
      datetime eventTime = g_newsEvents[i].eventTime;
      int minutesDiff = (int)((eventTime - currentTime) / 60);

      // Use dynamic block times from the event
      int blockBefore = g_newsEvents[i].minsBefore;
      int blockAfter = g_newsEvents[i].minsAfter + atrExtension;  // Add ATR extension

      // Event is in the future
      if(minutesDiff > 0)
      {
         // Check if within pre-news restriction (using dynamic time)
         if(minutesDiff <= blockBefore)
         {
            g_result.tradingStatus = TRADING_BLOCKED_BEFORE;
            g_result.tradingAllowed = false;
            g_result.currentEvent = g_newsEvents[i];
            g_result.minutesToNextNews = minutesDiff;
            g_result.currentRiskScore = g_newsEvents[i].riskScore;
            g_result.statusMessage = "BLOCKED - " + GetImpactString(g_newsEvents[i].impact) +
                                     " news in " + IntegerToString(minutesDiff) + " min (Risk: " +
                                     IntegerToString(g_newsEvents[i].riskScore) + "/10)";
            return;
         }

         // Track next event
         if(!foundNextEvent || minutesDiff < g_result.minutesToNextNews)
         {
            g_result.nextEvent = g_newsEvents[i];
            g_result.minutesToNextNews = minutesDiff;
            foundNextEvent = true;
         }
      }
      // Event is in the past
      else
      {
         int minutesSince = -minutesDiff;

         // Check if within post-news restriction (using dynamic time + ATR extension)
         if(minutesSince <= blockAfter)
         {
            g_result.tradingStatus = TRADING_BLOCKED_AFTER;
            g_result.tradingAllowed = false;
            g_result.currentEvent = g_newsEvents[i];
            g_result.minutesSinceLastNews = minutesSince;
            g_result.currentRiskScore = g_newsEvents[i].riskScore;

            if(atrExtension > 0)
            {
               g_result.atrExtended = true;
               g_result.extensionMinutes = atrExtension;
               g_result.statusMessage = "BLOCKED - News " + IntegerToString(minutesSince) +
                                        " min ago (ATR extended +" + IntegerToString(atrExtension) + " min)";
            }
            else
            {
               g_result.statusMessage = "BLOCKED - News " + IntegerToString(minutesSince) + " min ago";
            }
            return;
         }

         // Track most recent past event
         if(minutesSince < g_result.minutesSinceLastNews)
         {
            g_result.minutesSinceLastNews = minutesSince;
         }
      }
   }

   // If we get here, trading is allowed
   if(foundNextEvent)
   {
      g_result.statusMessage = "Safe - Next: " + GetImpactString(g_result.nextEvent.impact) +
                               " in " + IntegerToString(g_result.minutesToNextNews) + " min";
   }
   else
   {
      g_result.statusMessage = "Safe - No upcoming news events";
   }
}

//+------------------------------------------------------------------+
//| Count Upcoming Events                                             |
//+------------------------------------------------------------------+
void CountUpcomingEvents()
{
   g_result.upcomingHighCount = 0;
   g_result.upcomingMediumCount = 0;

   datetime currentTime = TimeCurrent();
   datetime tomorrow = currentTime + 86400;

   for(int i = 0; i < g_newsEventCount; i++)
   {
      if(g_newsEvents[i].eventTime > currentTime &&
         g_newsEvents[i].eventTime < tomorrow)
      {
         if(g_newsEvents[i].impact == IMPACT_HIGH)
            g_result.upcomingHighCount++;
         else if(g_newsEvents[i].impact == IMPACT_MEDIUM)
            g_result.upcomingMediumCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| Print News Report                                                 |
//+------------------------------------------------------------------+
void PrintNewsReport()
{
   Print("");
   Print("=================================================");
   Print("        NEWS FILTER REPORT (Section 9)           ");
   Print("=================================================");
   Print("Symbol: ", _Symbol);
   Print("Base Currency: ", g_baseCurrency);
   Print("Quote Currency: ", g_quoteCurrency);
   Print("Analysis Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");

   Print("FILTER STATUS:");
   Print("  News Filter: ", InpEnableNewsFilter ? "ENABLED" : "DISABLED");
   Print("  Calendar Available: ", g_calendarAvailable ? "Yes" : "No");
   Print("  Manual Events: ", InpUseManualEvents ? "Enabled" : "Disabled");
   Print("-------------------------------------------------");

   Print("CURRENT STATUS:");
   string statusStr;
   switch(g_result.tradingStatus)
   {
      case TRADING_ALLOWED:        statusStr = "TRADING ALLOWED"; break;
      case TRADING_BLOCKED_BEFORE: statusStr = "BLOCKED (Pre-News)"; break;
      case TRADING_BLOCKED_DURING: statusStr = "BLOCKED (During News)"; break;
      case TRADING_BLOCKED_AFTER:  statusStr = "BLOCKED (Post-News)"; break;
   }
   Print("  Status: ", statusStr);
   Print("  Message: ", g_result.statusMessage);
   Print("-------------------------------------------------");

   Print("UPCOMING EVENTS (24h):");
   Print("  High Impact: ", g_result.upcomingHighCount);
   Print("  Medium Impact: ", g_result.upcomingMediumCount);

   if(g_result.minutesToNextNews < 9999)
   {
      Print("  Next Event: ", g_result.nextEvent.name);
      Print("  Currency: ", g_result.nextEvent.currency);
      Print("  Time: ", TimeToString(g_result.nextEvent.eventTime, TIME_DATE|TIME_MINUTES));
      Print("  In: ", g_result.minutesToNextNews, " minutes");
      Print("  Risk Score: ", g_result.nextEvent.riskScore, "/10");
      Print("  Block: ", g_result.nextEvent.minsBefore, " min before / ", g_result.nextEvent.minsAfter, " min after");
   }
   Print("-------------------------------------------------");

   // ATR Extension status
   if(InpUseATRExtension)
   {
      Print("ATR EXTENSION STATUS:");
      Print("  Current ATR: ", DoubleToString(g_currentATR, 5));
      Print("  Normal ATR: ", DoubleToString(g_normalATR, 5));
      Print("  Ratio: ", DoubleToString(g_normalATR > 0 ? g_currentATR / g_normalATR : 0, 2), "x");
      Print("  Extended: ", g_result.atrExtended ? "YES (+" + IntegerToString(g_result.extensionMinutes) + " min)" : "NO");
      Print("-------------------------------------------------");
   }

   // List all events with risk scores
   if(g_newsEventCount > 0)
   {
      Print("ALL TRACKED EVENTS:");
      for(int i = 0; i < MathMin(g_newsEventCount, 10); i++)
      {
         string impactStr = GetImpactString(g_newsEvents[i].impact);
         Print("  [", impactStr, " Risk:", g_newsEvents[i].riskScore, "/10] ",
               g_newsEvents[i].currency, " - ",
               TimeToString(g_newsEvents[i].eventTime, TIME_DATE|TIME_MINUTES),
               " - ", g_newsEvents[i].name);
      }
      if(g_newsEventCount > 10)
         Print("  ... and ", g_newsEventCount - 10, " more events");
      Print("-------------------------------------------------");
   }

   Print("RECOMMENDATION:");
   if(g_result.tradingAllowed)
      Print("  SAFE TO TRADE - ", g_result.statusMessage);
   else
      Print("  DO NOT TRADE - ", g_result.statusMessage);
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
   Print("     SWING TRADER PRO - SECTION 9 (v2.00)        ");
   Print("     ECONOMIC NEWS FILTER                        ");
   Print("=================================================");
   Print("Initialization Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
   Print("-------------------------------------------------");
   Print("SYMBOL: ", _Symbol);
   Print("Base Currency: ", g_baseCurrency);
   Print("Quote Currency: ", g_quoteCurrency);
   Print("-------------------------------------------------");
   Print("NEWS FILTER SETTINGS:");
   Print("  Filter Enabled: ", InpEnableNewsFilter ? "Yes" : "No");
   Print("  High Impact: ", InpFilterHighImpact ? "Yes" : "No");
   Print("  Medium Impact: ", InpFilterMediumImpact ? "Yes" : "No");
   Print("  Low Impact: ", InpFilterLowImpact ? "Yes" : "No");
   Print("-------------------------------------------------");
   Print("DYNAMIC TIME RESTRICTIONS:");
   Print("  Dynamic Times: ", InpUseDynamicTimes ? "ENABLED" : "DISABLED");
   if(InpUseDynamicTimes)
   {
      Print("  High Impact: ", InpHighMinsBefore, " min before / ", InpHighMinsAfter, " min after");
      Print("  Medium Impact: ", InpMedMinsBefore, " min before / ", InpMedMinsAfter, " min after");
      Print("  Low Impact: ", InpLowMinsBefore, " min before / ", InpLowMinsAfter, " min after");
   }
   else
   {
      Print("  Fixed: ", InpMinutesBefore, " min before / ", InpMinutesAfter, " min after");
   }
   Print("-------------------------------------------------");
   Print("CLOSE POSITION SETTINGS:");
   Print("  Close Before High Impact: ", InpCloseBeforeNews ? "Yes" : "No");
   if(InpCloseBeforeNews)
      Print("  Close Hours Before: ", InpCloseHoursBefore);
   Print("  Partial Close (Medium): ", InpPartialCloseEnabled ? "Yes" : "No");
   if(InpPartialCloseEnabled)
      Print("  Partial Close %: ", InpPartialClosePercent);
   Print("-------------------------------------------------");
   Print("ATR EXTENSION SETTINGS:");
   Print("  ATR Extension: ", InpUseATRExtension ? "ENABLED" : "DISABLED");
   if(InpUseATRExtension)
   {
      Print("  ATR Spike Threshold: ", InpATRSpikeMultiplier, "x normal");
      Print("  Max Extension: ", InpMaxExtensionMins, " min");
      Print("  Normal ATR: ", DoubleToString(g_normalATR, 5));
   }
   Print("-------------------------------------------------");
   Print("CURRENCY FILTER:");
   Print("  Base Currency (", g_baseCurrency, "): ", InpFilterBaseCurrency ? "Yes" : "No");
   Print("  Quote Currency (", g_quoteCurrency, "): ", InpFilterQuoteCurrency ? "Yes" : "No");
   Print("  Always USD: ", InpFilterUSD ? "Yes" : "No");
   Print("  Global Events: ", InpFilterGlobalEvents ? "Yes" : "No");
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

   CreateRectangle(g_panelName + "_bg", x, y, 280, 200, clrBlack, 200);

   CreateLabel(g_panelName + "_title", x + 10, y + 5,
               "NEWS FILTER", clrGold, 10, "Arial Bold");

   CreateLabel(g_panelName + "_sep1", x + 10, y + 25,
               "-----------------------------", clrGray, 8, "Courier New");

   int yOff = 40;

   // Status
   CreateLabel(g_panelName + "_status_label", x + 10, y + yOff, "Status:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_status_value", x + 100, y + yOff, "CHECKING...", clrYellow, 9, "Arial Bold");
   yOff += 22;

   // Trading Allowed
   CreateLabel(g_panelName + "_trade_label", x + 10, y + yOff, "Trading:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_trade_value", x + 100, y + yOff, "...", clrYellow, 9, "Arial Bold");
   yOff += 25;

   CreateLabel(g_panelName + "_sep2", x + 10, y + yOff,
               "-----------------------------", clrGray, 8, "Courier New");
   yOff += 15;

   // Next News
   CreateLabel(g_panelName + "_next_label", x + 10, y + yOff, "Next News:", clrCyan, 9, "Arial Bold");
   yOff += 18;
   CreateLabel(g_panelName + "_next_name", x + 20, y + yOff, "--", clrWhite, 8, "Arial");
   yOff += 16;
   CreateLabel(g_panelName + "_next_time", x + 20, y + yOff, "--", clrYellow, 8, "Arial");
   yOff += 25;

   // Upcoming count
   CreateLabel(g_panelName + "_upcoming_label", x + 10, y + yOff, "24h Events:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_upcoming_value", x + 100, y + yOff, "H:0 M:0", clrYellow, 9, "Arial");
   yOff += 25;

   // Message
   CreateLabel(g_panelName + "_msg_label", x + 10, y + yOff, "Info:", clrWhite, 9, "Arial");
   CreateLabel(g_panelName + "_msg_value", x + 10, y + yOff + 16, "...", clrGray, 8, "Arial");
}

//+------------------------------------------------------------------+
//| Update Panel                                                      |
//+------------------------------------------------------------------+
void UpdatePanel()
{
   if(!InpShowPanel) return;

   // Status
   string statusStr;
   color statusColor;
   switch(g_result.tradingStatus)
   {
      case TRADING_ALLOWED:
         statusStr = "SAFE";
         statusColor = InpSafeColor;
         break;
      case TRADING_BLOCKED_BEFORE:
         statusStr = "PRE-NEWS";
         statusColor = InpNewsActiveColor;
         break;
      case TRADING_BLOCKED_DURING:
         statusStr = "NEWS NOW";
         statusColor = InpNewsActiveColor;
         break;
      case TRADING_BLOCKED_AFTER:
         statusStr = "POST-NEWS";
         statusColor = clrOrange;
         break;
   }
   ObjectSetString(0, g_panelName + "_status_value", OBJPROP_TEXT, statusStr);
   ObjectSetInteger(0, g_panelName + "_status_value", OBJPROP_COLOR, statusColor);

   // Trading allowed
   string tradeStr = g_result.tradingAllowed ? "ALLOWED" : "BLOCKED";
   color tradeColor = g_result.tradingAllowed ? InpSafeColor : InpNewsActiveColor;
   ObjectSetString(0, g_panelName + "_trade_value", OBJPROP_TEXT, tradeStr);
   ObjectSetInteger(0, g_panelName + "_trade_value", OBJPROP_COLOR, tradeColor);

   // Next news
   if(g_result.minutesToNextNews < 9999)
   {
      string nextName = g_result.nextEvent.name;
      if(StringLen(nextName) > 25)
         nextName = StringSubstr(nextName, 0, 25) + "...";
      ObjectSetString(0, g_panelName + "_next_name", OBJPROP_TEXT, nextName);

      string timeStr = "In " + IntegerToString(g_result.minutesToNextNews) + " min";
      ObjectSetString(0, g_panelName + "_next_time", OBJPROP_TEXT, timeStr);
   }
   else
   {
      ObjectSetString(0, g_panelName + "_next_name", OBJPROP_TEXT, "No upcoming events");
      ObjectSetString(0, g_panelName + "_next_time", OBJPROP_TEXT, "--");
   }

   // Upcoming count
   string upcomingStr = "H:" + IntegerToString(g_result.upcomingHighCount) +
                        " M:" + IntegerToString(g_result.upcomingMediumCount);
   ObjectSetString(0, g_panelName + "_upcoming_value", OBJPROP_TEXT, upcomingStr);

   // Message
   string msgText = g_result.statusMessage;
   if(StringLen(msgText) > 35)
      msgText = StringSubstr(msgText, 0, 35) + "...";
   ObjectSetString(0, g_panelName + "_msg_value", OBJPROP_TEXT, msgText);

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
bool IsTradingAllowed() { return g_result.tradingAllowed; }
ENUM_TRADING_STATUS GetTradingStatus() { return g_result.tradingStatus; }
string GetNewsStatusMessage() { return g_result.statusMessage; }
int GetMinutesToNextNews() { return g_result.minutesToNextNews; }
int GetUpcomingHighImpactCount() { return g_result.upcomingHighCount; }

// Check if should close positions before news (hours before for high impact)
bool ShouldCloseBeforeNews()
{
   if(!InpCloseBeforeNews) return false;

   // Only close for high impact news
   if(g_result.nextEvent.impact != IMPACT_HIGH) return false;

   // Close X hours before high impact news
   int closeMinutesBefore = InpCloseHoursBefore * 60;
   if(g_result.minutesToNextNews <= closeMinutesBefore &&
      g_result.minutesToNextNews > 0)
      return true;

   return false;
}

// Check if should partial close for medium impact
bool ShouldPartialClose()
{
   if(!InpPartialCloseEnabled) return false;

   // Only partial close for medium impact
   if(g_result.nextEvent.impact != IMPACT_MEDIUM) return false;

   // Partial close 30 min before medium impact
   if(g_result.minutesToNextNews <= 30 && g_result.minutesToNextNews > 0)
      return true;

   return false;
}

// Get partial close percentage
double GetPartialClosePercent()
{
   return InpPartialClosePercent;
}

// Get current event risk score
int GetCurrentRiskScore()
{
   return g_result.currentRiskScore;
}

// Get next news event details
bool GetNextNewsEvent(string &name, datetime &time, ENUM_NEWS_IMPACT &impact)
{
   if(g_result.minutesToNextNews >= 9999) return false;

   name = g_result.nextEvent.name;
   time = g_result.nextEvent.eventTime;
   impact = g_result.nextEvent.impact;
   return true;
}
//+------------------------------------------------------------------+
