# Prediction Playoffs 🏆

A decentralized prediction market smart contract built on the Stacks blockchain using Clarity. Create forecasting tournaments for sports events, market predictions, or any event with multiple possible outcomes.

## Overview

Prediction Playoffs enables users to create and participate in prediction tournaments where participants forecast outcomes and winners share the prize pool proportionally based on their stakes.

## Features

### 🎯 Core Functionality
- **Create Tournaments** - Launch prediction markets for any event
- **Make Predictions** - Place bets on outcomes with entry fees
- **Resolve Tournaments** - Tournament creators declare winning outcomes
- **Claim Winnings** - Automatic proportional distribution to winners
- **Multiple Categories** - Support for sports, markets, events, and more

### 🔐 Security Features
- Time-locked predictions (must predict before tournament ends)
- Time-locked resolution (only after resolution period)
- Single prediction per user per tournament
- Creator-only resolution rights
- Anti-double-claim protection
- Comprehensive error handling

### 💰 Prize Pool Management
- Automatic pool aggregation from entry fees
- Proportional distribution based on stake
- Transparent outcome tracking
- Real-time potential winnings calculation

## Smart Contract Functions

### Public Functions

#### `create-tournament`
Creates a new prediction tournament.

**Parameters:**
- `title` (string-ascii 100) - Tournament name
- `description` (string-ascii 500) - Detailed description
- `category` (string-ascii 50) - Category (e.g., "sports", "crypto", "politics")
- `entry-fee` (uint) - Entry fee in microSTX (1 STX = 1,000,000 microSTX)
- `duration-blocks` (uint) - How many blocks until predictions close
- `resolution-delay-blocks` (uint) - Additional blocks before resolution allowed
- `outcome-count` (uint) - Number of possible outcomes (minimum 2)

**Returns:** `(ok tournament-id)`

**Example:**
```clarity
(contract-call? .prediction-playoffs create-tournament 
    "Champions League Final 2025"
    "Predict the winner of the Champions League Final"
    "sports"
    u1000000  ;; 1 STX entry fee
    u1440     ;; ~10 days (144 blocks/day)
    u144      ;; ~1 day resolution delay
    u2        ;; 2 outcomes (Team A or Team B)
)
```

#### `make-prediction`
Make a prediction on a tournament.

**Parameters:**
- `tournament-id` (uint) - ID of the tournament
- `predicted-outcome` (uint) - Your predicted outcome (0-indexed)

**Returns:** `(ok prediction-id)`

**Example:**
```clarity
(contract-call? .prediction-playoffs make-prediction u1 u0)
;; Predict outcome 0 in tournament 1
```

#### `resolve-tournament`
Resolve a tournament with the winning outcome (creator only).

**Parameters:**
- `tournament-id` (uint) - ID of the tournament
- `winning-outcome` (uint) - The actual outcome that occurred

**Returns:** `(ok true)`

**Example:**
```clarity
(contract-call? .prediction-playoffs resolve-tournament u1 u0)
;; Declare outcome 0 as the winner
```

#### `claim-winnings`
Claim your winnings from a resolved tournament.

**Parameters:**
- `tournament-id` (uint) - ID of the tournament

**Returns:** `(ok true)` and transfers STX winnings

**Example:**
```clarity
(contract-call? .prediction-playoffs claim-winnings u1)
```

### Read-Only Functions

#### `get-tournament`
Get full tournament details.

**Parameters:**
- `tournament-id` (uint)

**Returns:** Tournament data or none

#### `get-prediction`
Get prediction details by prediction ID.

**Parameters:**
- `prediction-id` (uint)

**Returns:** Prediction data or none

#### `get-user-prediction`
Get a user's prediction for a specific tournament.

**Parameters:**
- `tournament-id` (uint)
- `user` (principal)

**Returns:** Prediction data or none

#### `get-outcome-total`
Get total stake on a specific outcome.

**Parameters:**
- `tournament-id` (uint)
- `outcome` (uint)

**Returns:** Total microSTX staked on that outcome

#### `calculate-potential-winnings`
Calculate potential winnings for a user.

**Parameters:**
- `tournament-id` (uint)
- `user` (principal)

**Returns:** `(ok amount)` in microSTX

#### `get-tournament-count`
Returns total number of tournaments created.

#### `get-prediction-count`
Returns total number of predictions made.

#### `get-user-tournament-count`
Get how many tournaments a user has participated in.

**Parameters:**
- `user` (principal)

## Usage Example

### 1. Create a Tournament
```clarity
;; Create a prediction market for a sports match
(contract-call? .prediction-playoffs create-tournament
    "Lakers vs Celtics"
    "NBA Finals Game 7 - Who will win?"
    "basketball"
    u5000000    ;; 5 STX entry
    u288        ;; ~2 days to predict
    u72         ;; ~12 hours to resolve
    u2          ;; 2 teams
)
;; Returns: (ok u0) - tournament ID 0
```

### 2. Users Make Predictions
```clarity
;; User 1 predicts Lakers (outcome 0)
(contract-call? .prediction-playoffs make-prediction u0 u0)

;; User 2 predicts Celtics (outcome 1)
(contract-call? .prediction-playoffs make-prediction u0 u1)

;; User 3 predicts Lakers (outcome 0)
(contract-call? .prediction-playoffs make-prediction u0 u0)
```

### 3. Check Tournament Status
```clarity
;; View tournament details
(contract-call? .prediction-playoffs get-tournament u0)

;; Check total on each outcome
(contract-call? .prediction-playoffs get-outcome-total u0 u0)  ;; Lakers total
(contract-call? .prediction-playoffs get-outcome-total u0 u1)  ;; Celtics total

;; Check your potential winnings
(contract-call? .prediction-playoffs calculate-potential-winnings u0 tx-sender)
```

### 4. Resolve Tournament
```clarity
;; Creator resolves after the game (Lakers won = outcome 0)
(contract-call? .prediction-playoffs resolve-tournament u0 u0)
```

### 5. Claim Winnings
```clarity
;; Winners claim their share
(contract-call? .prediction-playoffs claim-winnings u0)
```

## Prize Distribution Logic

The prize pool is distributed proportionally based on stake:

```
User Winnings = (Total Pool × User Stake) ÷ Total Stake on Winning Outcome
```

**Example:**
- Total Pool: 15 STX (3 users × 5 STX entry)
- Outcome 0 (Lakers) total stake: 10 STX (User 1 + User 3)
- Outcome 1 (Celtics) total stake: 5 STX (User 2)
- Lakers win!

Winners:
- User 1: (15 × 5) ÷ 10 = **7.5 STX**
- User 3: (15 × 5) ÷ 10 = **7.5 STX**

## Error Codes

| Code | Constant | Description |
|------|----------|-------------|
| u100 | err-owner-only | Only tournament creator can perform this action |
| u101 | err-not-found | Tournament or prediction not found |
| u102 | err-already-exists | Resource already exists |
| u103 | err-tournament-closed | Prediction period has ended |
| u104 | err-tournament-active | Tournament not ready for resolution |
| u105 | err-invalid-prediction | Invalid outcome number |
| u106 | err-already-predicted | User already made a prediction |
| u107 | err-insufficient-funds | Not enough STX to pay entry fee |
| u108 | err-not-resolved | Tournament not yet resolved |
| u109 | err-already-resolved | Tournament already resolved |
| u110 | err-already-claimed | Winnings already claimed |

## Development Setup

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Node.js (for testing)

### Installation

1. Clone the repository:
```bash
git clone <your-repo>
cd prediction-playoffs
```

2. Check contract syntax:
```bash
clarinet check
```

3. Run tests:
```bash
clarinet test
```

4. Launch console for interaction:
```bash
clarinet console
```

## Testing

Run the test suite:
```bash
npm install
npm test
```

Test coverage includes:
- Tournament creation validation
- Prediction mechanics
- Prize pool calculations
- Resolution logic
- Claiming winnings
- Edge cases and error conditions

## Deployment

### Testnet Deployment
```bash
clarinet deployments generate --testnet
clarinet deployments apply --testnet
```

### Mainnet Deployment
```bash
clarinet deployments generate --mainnet
clarinet deployments apply --mainnet
```

## Use Cases

### 🏀 Sports Predictions
- Game winners
- Championship outcomes
- Player performance metrics
- Season standings

### 📈 Market Forecasting
- Stock price movements
- Crypto market predictions
- Economic indicators
- Quarterly earnings

### 🗳️ Event Predictions
- Election results
- Award show winners
- Product launch success
- Weather forecasts

### 🎮 Gaming Tournaments
- Esports match outcomes
- Speedrun competitions
- Tournament brackets

## Best Practices

1. **Set Reasonable Durations**
   - Allow enough time for participation
   - Consider event timing for resolution

2. **Clear Outcome Definitions**
   - Document what each outcome number represents
   - Use unambiguous criteria

3. **Fair Entry Fees**
   - Balance accessibility with prize value
   - Consider your target audience

4. **Timely Resolution**
   - Resolve tournaments promptly after events
   - Maintain trust with participants

5. **Transparent Communication**
   - Use clear titles and descriptions
   - Specify resolution criteria upfront

## Security Considerations

- **Creator Trust**: Tournament creators must resolve honestly
- **Time Locks**: Prevents premature predictions and resolutions
- **No Oracles**: Relies on creator's honest resolution
- **Single Prediction**: Prevents gaming the system
- **Immutable Stakes**: Cannot change prediction after submission

## Future Enhancements

Possible improvements for future versions:
- Multi-sig resolution (community voting)
- Oracle integration for automated resolution
- Tournament categories with verification
- Reputation system for creators
- Partial refunds for cancelled tournaments
- Support for multiple predictions per user
- Leaderboards and statistics


## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Join our Discord community
- Read the [Clarity documentation](https://docs.stacks.co/clarity)