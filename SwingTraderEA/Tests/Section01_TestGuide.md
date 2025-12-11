# Section 1: ATR Volatility Filter - Test Guide

## Overview
This section implements the ATR-based volatility filter that determines if market conditions are suitable for swing trading on XAU/USD (Gold).

## Files Created
- `Sections/Section01_ATRFilter.mq5` - Main EA file
- `Include/CommonStructures.mqh` - Shared structures and functions

## Installation

1. **Copy files to MT5:**
   ```
   Copy: SwingTraderEA/Include/CommonStructures.mqh
   To:   [MT5 Data Folder]/MQL5/Include/SwingTraderPro/CommonStructures.mqh

   Copy: SwingTraderEA/Sections/Section01_ATRFilter.mq5
   To:   [MT5 Data Folder]/MQL5/Experts/SwingTraderPro/Section01_ATRFilter.mq5
   ```

2. **Find MT5 Data Folder:**
   - In MT5: File → Open Data Folder

3. **Create folder structure:**
   ```
   MQL5/
   ├── Include/
   │   └── SwingTraderPro/
   │       └── CommonStructures.mqh
   └── Experts/
       └── SwingTraderPro/
           └── Section01_ATRFilter.mq5
   ```

4. **Update include path in EA:**
   Change line 14 in Section01_ATRFilter.mq5 from:
   ```cpp
   #include "../Include/CommonStructures.mqh"
   ```
   To:
   ```cpp
   #include <SwingTraderPro/CommonStructures.mqh>
   ```

5. **Compile:**
   - Open MetaEditor (F4 from MT5)
   - Navigate to Experts/SwingTraderPro/Section01_ATRFilter.mq5
   - Press F7 to compile
   - Should compile with 0 errors

## Running the Test

### Step 1: Attach to Chart
1. Open XAU/USD (Gold) chart
2. Set timeframe to H4 (for visual reference)
3. Drag Section01_ATRFilter EA onto chart
4. Enable "Allow Algo Trading"

### Step 2: Configure Settings
Default settings are optimized for Gold swing trading:

| Parameter | Default | Description |
|-----------|---------|-------------|
| ATR Period | 14 | Standard ATR period |
| Quiet Threshold | 60 pips | Below = too quiet |
| Extreme Threshold | 250 pips | Above = extreme volatility |
| ATR Timeframe | H4 | Analysis timeframe |
| Show Panel | true | Visual display |
| Print Report | true | Experts tab output |

### Step 3: Verify Output

#### Check Experts Tab (Ctrl+E)
You should see output similar to:
```
=================================================
     SWING TRADER PRO - SECTION 1
     ATR VOLATILITY FILTER
=================================================
Initialization Time: 2024.01.15 14:30
-------------------------------------------------
ACCOUNT INFORMATION:
  Broker: BlackBull Markets NZ
  Starting Balance: $500.00
  Spread: 0.8 pips
-------------------------------------------------
SYMBOL INFORMATION:
  Symbol: XAUUSD
  Digits: 2
  Point: 0.01
  ...
-------------------------------------------------
ATR FILTER SETTINGS:
  ATR Period: 14
  Analysis Timeframe: H4
  Quiet Threshold: 60.0 pips
  Extreme Threshold: 250.0 pips
=================================================
```

#### Check Chart Panel
- Should display "ATR VOLATILITY FILTER" panel
- Shows current ATR value in pips
- Shows market condition (QUIET/NORMAL/EXTREME)
- Shows trading status (ALLOWED/BLOCKED)

## Testing Checklist

### Test 1: ATR Value Accuracy
- [ ] Open MT5 built-in ATR indicator (Insert → Indicators → Oscillators → ATR)
- [ ] Set ATR period to 14
- [ ] Compare EA ATR value with indicator value
- [ ] For Gold: EA value should be ~10x the indicator value (pip conversion)
- [ ] Values should match within 0.1 pip tolerance

### Test 2: Market Condition Classification
- [ ] If ATR < 60 pips → Should show "QUIET" (gray color)
- [ ] If ATR 60-250 pips → Should show "NORMAL" (green color)
- [ ] If ATR > 250 pips → Should show "EXTREME" (red color)

### Test 3: Trading Permission
- [ ] QUIET condition → Trading: BLOCKED
- [ ] NORMAL condition → Trading: ALLOWED
- [ ] EXTREME condition → Trading: ALLOWED (with warning)

### Test 4: Historical Report
- [ ] Check Experts tab for ATR history
- [ ] Should show last 20 bars of ATR values
- [ ] Each bar should have correct timestamp
- [ ] Condition labels should match values

### Test 5: New Bar Update
- [ ] Wait for new H4 candle to form
- [ ] EA should automatically update values
- [ ] Panel should refresh with new data
- [ ] New report should print to Experts tab

### Test 6: Multiple Timeframes
- [ ] Change InpATRTimeframe to H1
- [ ] ATR values should update accordingly
- [ ] Compare with H1 ATR indicator

## Expected Results for Gold (XAU/USD)

Typical ATR values for Gold on H4:
- **Quiet market:** 20-50 pips (low volatility, Asian session)
- **Normal market:** 60-180 pips (regular trading conditions)
- **High volatility:** 180-250 pips (news events, trend days)
- **Extreme:** 250+ pips (major events, NFP, FOMC)

## Troubleshooting

### EA Not Loading
- Check if "Allow Algo Trading" is enabled
- Check for compilation errors in MetaEditor

### ATR Shows 0 or Wrong Values
- Ensure enough historical data is loaded
- Check if symbol name matches (XAUUSD vs XAU/USD)

### Panel Not Showing
- Enable "Show Info Panel" in settings
- Check if other EA/indicator is blocking position

### No Output in Experts Tab
- Enable "Print Report to Experts Tab" in settings
- Clear Experts tab and restart EA

## Notes for Gold Trading

Gold ATR interpretation differs from forex pairs:
- Gold moves in dollars, not pips in traditional sense
- 1 pip for Gold = $0.01 movement
- ATR of 30 on indicator = 30-dollar potential daily range
- EA converts this to "pips" for standardization

## Next Steps

Once Section 1 is verified working:
1. Document any issues found
2. Note actual ATR ranges for your trading hours
3. Adjust thresholds if needed for your risk tolerance
4. Proceed to Section 2: EMA Analysis

## Pass Criteria

Section 1 is PASSED when:
- [x] Compiles without errors
- [x] ATR values match MT5 indicator
- [x] Market conditions correctly classified
- [x] Trading permission logic works
- [x] Panel displays correctly
- [x] Reports print to Experts tab
- [x] Updates on new bar formation
