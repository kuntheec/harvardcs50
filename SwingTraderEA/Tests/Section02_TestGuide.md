# Section 2: EMA Analysis - Test Guide

## Overview
This section implements EMA 50/200 trend analysis for H4 bias detection, building on Section 1's ATR filter.

## Features
- EMA 50 (Fast) and EMA 200 (Slow) calculation
- Trend bias detection (Bullish/Bearish/Neutral)
- Crossover detection within configurable lookback
- ATR filter integration from Section 1
- Visual EMA lines on chart
- Comprehensive panel display

## Installation

1. **Ensure Section 1 files are in place**

2. **Copy Section 2 file:**
   ```
   Copy: SwingTraderEA/Sections/Section02_EMAAnalysis.mq5
   To:   [MT5 Data Folder]/MQL5/Experts/SwingTraderPro/Section02_EMAAnalysis.mq5
   ```

3. **Update include path** (if needed):
   Change line 14 from:
   ```cpp
   #include "../Include/CommonStructures.mqh"
   ```
   To:
   ```cpp
   #include <SwingTraderPro/CommonStructures.mqh>
   ```

4. **Compile in MetaEditor (F7)**

## Input Parameters

### EMA Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| EMA Fast Period | 50 | Fast EMA period |
| EMA Slow Period | 200 | Slow EMA period |
| EMA Timeframe | H4 | Analysis timeframe |
| Crossover Lookback | 10 | Candles to check for crossover |
| Applied Price | Close | Price type for EMA |

### ATR Filter (Inherited from Section 1)
| Parameter | Default | Description |
|-----------|---------|-------------|
| Use ATR Filter | true | Enable/disable ATR filter |
| ATR Period | 14 | ATR calculation period |
| Quiet Threshold | 60 pips | Below = skip trade |
| Extreme Threshold | 250 pips | Above = extreme volatility |

### Display Settings
| Parameter | Default | Description |
|-----------|---------|-------------|
| Show Panel | true | Display info panel |
| Show EMA Lines | true | Draw EMAs on chart |
| EMA Fast Color | DodgerBlue | EMA 50 line color |
| EMA Slow Color | OrangeRed | EMA 200 line color |

## Running the Test

### Step 1: Attach to Chart
1. Open XAU/USD chart
2. Set timeframe to H4 (recommended for visual clarity)
3. Drag Section02_EMAAnalysis onto chart
4. Enable "Allow Algo Trading"

### Step 2: Verify Visual Elements

**EMA Lines:**
- Blue line = EMA 50
- Orange/Red line = EMA 200
- Lines should match MT5's built-in MA indicator

**Panel Display:**
- ATR filter status (if enabled)
- Current EMA 50 value
- Current EMA 200 value
- EMA Gap (distance between EMAs)
- Current price
- Price position (Above Both / Below Both / Between)
- H4 BIAS (BULLISH / BEARISH / NEUTRAL)
- Crossover status
- Trading recommendation

### Step 3: Verify Report Output

Check Experts tab (Ctrl+E) for output like:
```
=================================================
         EMA ANALYSIS REPORT (Section 2)
=================================================
Symbol: XAUUSDp
Timeframe: H4
Analysis Time: 2025.12.11 15:00
-------------------------------------------------
ATR FILTER STATUS:
  ATR Value: 225.27 pips
  Condition: NORMAL (Proceed)
  Trading: ALLOWED
-------------------------------------------------
EMA VALUES:
  EMA 50: 2650.45
  EMA 200: 2580.30
  EMA Gap: 70.15 (2.72%)
-------------------------------------------------
PRICE POSITION:
  Current Price: 2670.50
  Distance to EMA50: 20.05 (ABOVE)
  Distance to EMA200: 90.20 (ABOVE)
-------------------------------------------------
TREND ANALYSIS:
  EMA Alignment: BULLISH (EMA50 > EMA200)
  Price vs EMAs: Above both EMAs (Strong Bullish)
-------------------------------------------------
H4 BIAS: BULLISH
-------------------------------------------------
CROSSOVER DETECTION:
  Recent Crossover: NO (within 10 candles)
  Trend Established: YES
-------------------------------------------------
TRADING RECOMMENDATION:
  STATUS: LOOK FOR BUYS
  REASON: EMA50 > EMA200, price in bullish position
  ACTION: Wait for BOS/CHoCH confirmation on H4
  ENTRY: Look for demand zone + bullish structure on H1/M15
=================================================
```

## Testing Checklist

### Test 1: EMA Value Accuracy
- [ ] Add MA indicator: Insert → Indicators → Trend → Moving Average
- [ ] Set Period=50, Method=Exponential, Apply=Close
- [ ] Compare with EA's EMA 50 value (should match exactly)
- [ ] Repeat for EMA 200

### Test 2: Trend Bias Logic
- [ ] When EMA50 > EMA200 + Price above EMA50 → BULLISH
- [ ] When EMA50 < EMA200 + Price below EMA50 → BEARISH
- [ ] When EMAs very close (< 0.1% gap) → NEUTRAL
- [ ] When price between EMAs → Check logic matches position

### Test 3: Crossover Detection
- [ ] Find a recent Golden Cross (EMA50 crosses above EMA200)
- [ ] EA should detect and report "Recent Crossover: YES"
- [ ] After 10+ candles → "Recent Crossover: NO"

### Test 4: ATR Integration
- [ ] Enable ATR filter
- [ ] ATR values should match Section 1
- [ ] Trading blocked when ATR < 60 pips
- [ ] Trading allowed when ATR 60-250 pips

### Test 5: Visual Elements
- [ ] EMA lines drawn correctly on chart
- [ ] Lines update on new bar
- [ ] Panel displays all values correctly
- [ ] Colors match trend direction

### Test 6: Different Market Conditions
Test on different scenarios:
- [ ] Strong uptrend (price above both EMAs, large gap)
- [ ] Strong downtrend (price below both EMAs, large gap)
- [ ] Ranging market (EMAs close together)
- [ ] Pullback (price between EMAs)

## Trend Bias Rules

### BULLISH Conditions:
1. EMA 50 > EMA 200 (Golden Cross territory)
2. Price above EMA 50 (following the trend)
3. No recent crossover (trend established)

### BEARISH Conditions:
1. EMA 50 < EMA 200 (Death Cross territory)
2. Price below EMA 50 (following the trend)
3. No recent crossover (trend established)

### NEUTRAL Conditions (Skip Trading):
1. EMAs too close (< 0.1% gap) - consolidation
2. Price between EMAs - mixed signals
3. Recent crossover (< 3 candles) - wait for confirmation

## Trading Recommendations

| ATR Status | Trend Bias | Crossover | Action |
|------------|------------|-----------|--------|
| QUIET | Any | Any | NO TRADE |
| NORMAL | BULLISH | No | LOOK FOR BUYS |
| NORMAL | BEARISH | No | LOOK FOR SELLS |
| NORMAL | NEUTRAL | Any | NO TRADE |
| NORMAL | Any | Yes (< 3 bars) | WAIT |
| EXTREME | BULLISH | No | LOOK FOR BUYS (smaller size) |

## Expected Gold (XAU/USD) Observations

Typical EMA characteristics for Gold on H4:
- EMA 50/200 gap during trend: $30-$100
- EMA 50/200 gap during range: $0-$30
- Golden Cross frequency: Every few weeks/months
- Death Cross frequency: Every few weeks/months

## Troubleshooting

### EMA Lines Not Showing
- Check "Show EMA Lines" is enabled
- Ensure enough historical data is loaded
- Try refreshing chart (F5)

### Values Don't Match Built-in Indicator
- Verify same period settings
- Verify same timeframe
- Verify Applied Price is "Close"

### Panel Overlapping Other Elements
- Adjust Panel X/Y position in inputs
- Default is top-left corner (20, 30)

### "Recent Crossover" Always Shows
- Increase Crossover Lookback if needed
- Check if market is in consolidation

## Next Steps

Once Section 2 is verified:
1. Document any issues
2. Note typical EMA gap ranges for gold
3. Proceed to Section 3: BOS/CHoCH Detection

## Pass Criteria

Section 2 is PASSED when:
- [ ] Compiles without errors
- [ ] EMA values match MT5 indicator
- [ ] Trend bias correctly determined
- [ ] Crossover detection works
- [ ] ATR filter integration works
- [ ] Visual elements display correctly
- [ ] Trading recommendations make sense
