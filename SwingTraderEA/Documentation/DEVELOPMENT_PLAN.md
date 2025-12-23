# Swing Trader EA - Development Plan

## Project Overview
**EA Name:** SwingTrader Pro
**Platform:** MetaTrader 5 (MQL5)
**Trading Style:** Swing Trading (Hold for days/weeks)
**Primary Pair:** XAU/USD (Gold)
**Account:** $500 Demo, 1:100-1:500 Leverage
**Broker:** BlackBull Markets NZ (0.8 pips spread, no commission)

---

## Development Sections

### Section 1: Base Framework + ATR Volatility Filter
**Status:** Pending
**Purpose:** Create EA skeleton with ATR-based market condition filter

**Features:**
- EA initialization and deinitialization
- Input parameters structure
- ATR(14) calculation on H4
- Market condition classification (Quiet/Normal/Extreme)
- Report output to Experts tab

**Testing Criteria:**
- [ ] ATR values match MT5 built-in ATR indicator
- [ ] Correct classification of market conditions
- [ ] Clean report output

---

### Section 2: EMA Analysis
**Status:** Pending
**Purpose:** Trend detection using EMA 50 and EMA 200

**Features:**
- EMA 50 and EMA 200 calculation
- Bullish/Bearish/Neutral classification
- Recent crossover detection (within 10 candles)
- Visual lines on chart

**Testing Criteria:**
- [ ] EMA values match built-in EMA indicator
- [ ] Correct trend classification
- [ ] Crossover detection accuracy

---

### Section 3: BOS/CHoCH Detection
**Status:** Pending
**Purpose:** Smart Money Concepts structure analysis

**Features:**
- Swing high/low detection
- Break of Structure (BOS) identification
- Change of Character (CHoCH) identification
- Structure direction tracking

**Testing Criteria:**
- [ ] Accurate swing point detection
- [ ] Correct BOS labeling
- [ ] CHoCH reversal signals match manual analysis

---

### Section 4: Supply/Demand Zone Detection
**Status:** Pending
**Purpose:** Identify institutional order blocks

**Features:**
- Demand zone identification (last bullish candle before strong move up)
- Supply zone identification (last bearish candle before strong move down)
- Zone strength classification
- Zone visualization on chart

**Testing Criteria:**
- [ ] Zones align with manual ICT analysis
- [ ] Correct zone boundaries
- [ ] Old zones properly managed

---

### Section 5: Fibonacci Retracement and Fan
**Status:** Pending
**Purpose:** Key price levels for entries and targets

**Features:**
- Auto swing point detection for Fib drawing
- Retracement levels: 23.6%, 38.2%, 50%, 61.8%, 78.6%
- Extension levels: 127.2%, 161.8%, 200%, 261.8%
- Fibonacci Fan lines
- Visual representation

**Testing Criteria:**
- [ ] Fib levels match manual drawing
- [ ] Correct swing point selection
- [ ] Fan angles accurate

---

### Section 6: MACD + RSI Indicators
**Status:** Pending
**Purpose:** Momentum and overbought/oversold analysis

**Features:**
- MACD (12,26,9) calculation
- MACD histogram analysis
- MACD crossover detection
- RSI(14) calculation
- Divergence detection (optional)

**Testing Criteria:**
- [ ] Values match built-in indicators
- [ ] Correct signal generation
- [ ] Divergence accuracy

---

### Section 7: FVG (Fair Value Gap) Detection
**Status:** Pending
**Purpose:** Identify imbalances for TP targeting

**Features:**
- Bullish FVG detection (gap between candle 1 high and candle 3 low)
- Bearish FVG detection (gap between candle 1 low and candle 3 high)
- FVG fill tracking
- FVG visualization

**Testing Criteria:**
- [ ] All FVGs correctly identified
- [ ] Fill status properly tracked
- [ ] Visual representation accurate

---

### Section 8: Volume Profile / Order Blocks
**Status:** Pending
**Purpose:** Identify high-volume zones for SL placement

**Features:**
- Volume profile calculation
- Point of Control (POC) identification
- Value Area High/Low
- Order block integration with volume

**Testing Criteria:**
- [ ] Volume distribution matches manual analysis
- [ ] POC accuracy
- [ ] Order blocks validated

---

### Section 9: News Filter Integration
**Status:** Pending
**Purpose:** Avoid trading during high-impact news events

**Features:**
- Manual news time input
- Pre-defined high-impact event schedule
- Trading pause functionality
- News proximity warning

**Testing Criteria:**
- [ ] Correct time zone handling
- [ ] Trading properly paused
- [ ] Warning system works

---

### Section 10: Multi-timeframe Integration
**Status:** Pending
**Purpose:** Combine analysis from H4 → H1 → M15 → M5

**Features:**
- H4 bias determination
- H1 confirmation
- M15 entry zone
- M5 precision entry
- Timeframe alignment scoring

**Testing Criteria:**
- [ ] Correct data from all timeframes
- [ ] Proper alignment logic
- [ ] No repainting issues

---

### Section 11: Entry Logic + 3-Stage Position Building
**Status:** Pending
**Purpose:** Pyramid entry system

**Features:**
- Stage 1: Initial entry (30% position)
- Stage 2: Confirmation entry (40% position)
- Stage 3: Breakeven entry (30% position, only when profitable)
- Entry timing within 1 hour for Stage 1-2

**Testing Criteria:**
- [ ] Correct position sizing per stage
- [ ] Proper timing logic
- [ ] Stage 3 only on profitable trades

---

### Section 12: TP/SL Calculation System
**Status:** Pending
**Purpose:** Automatic target and stop loss placement

**Features:**
- SL based on Order Block/Supply-Demand zones
- TP based on FVG levels
- Multiple TP levels (TP1, TP2, TP3)
- ATR-based adjustments

**Testing Criteria:**
- [ ] Logical SL placement
- [ ] TP levels align with structure
- [ ] Risk:Reward calculation

---

### Section 13: Risk Management + Position Sizing
**Status:** Pending
**Purpose:** Protect account and optimize position sizes

**Features:**
- Risk per trade (1-2% of balance)
- Lot size calculation for $500 account
- Maximum drawdown protection
- Daily loss limit

**Testing Criteria:**
- [ ] Correct lot calculations
- [ ] Risk limits enforced
- [ ] Drawdown protection works

---

### Section 14: Complete EA Integration
**Status:** Pending
**Purpose:** Combine all sections into final EA

**Features:**
- All modules integrated
- Enable/disable individual features
- Comprehensive dashboard
- Full backtesting capability

**Testing Criteria:**
- [ ] All sections work together
- [ ] No conflicts between modules
- [ ] Strategy tester compatible

---

## File Structure

```
SwingTraderEA/
├── Sections/
│   ├── Section01_ATRFilter.mq5
│   ├── Section02_EMAAnalysis.mq5
│   ├── Section03_BOSCHoCH.mq5
│   ├── Section04_SupplyDemand.mq5
│   ├── Section05_Fibonacci.mq5
│   ├── Section06_MACD_RSI.mq5
│   ├── Section07_FVG.mq5
│   ├── Section08_VolumeProfile.mq5
│   ├── Section09_NewsFilter.mq5
│   ├── Section10_MTFIntegration.mq5
│   ├── Section11_EntryLogic.mq5
│   ├── Section12_TPSL.mq5
│   ├── Section13_RiskManagement.mq5
│   └── Section14_SwingTraderPro.mq5
├── Include/
│   ├── CommonStructures.mqh
│   ├── IndicatorFunctions.mqh
│   ├── SMCFunctions.mqh
│   └── RiskFunctions.mqh
├── Tests/
│   └── (Test scripts and results)
└── Documentation/
    ├── DEVELOPMENT_PLAN.md
    └── USER_GUIDE.md
```

---

## Testing Protocol

For each section:
1. Compile without errors
2. Run on demo account
3. Compare outputs with manual analysis
4. Document any discrepancies
5. Approve before moving to next section

---

## Notes

- All sections are standalone testable EAs
- Each section outputs detailed reports to Experts tab
- Visual elements can be toggled on/off
- Final EA will have all sections as optional modules
