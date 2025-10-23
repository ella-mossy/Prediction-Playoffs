;; Prediction Playoffs - Forecasting Tournament Contract
;; A decentralized prediction market for sports, markets, and events

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-tournament-closed (err u103))
(define-constant err-tournament-active (err u104))
(define-constant err-invalid-prediction (err u105))
(define-constant err-already-predicted (err u106))
(define-constant err-insufficient-funds (err u107))
(define-constant err-not-resolved (err u108))
(define-constant err-already-resolved (err u109))
(define-constant err-already-claimed (err u110))

;; Data Variables
(define-data-var tournament-counter uint u0)
(define-data-var prediction-counter uint u0)

;; Data Maps
(define-map tournaments
    uint
    {
        creator: principal,
        title: (string-ascii 100),
        description: (string-ascii 500),
        category: (string-ascii 50),
        entry-fee: uint,
        total-pool: uint,
        start-block: uint,
        end-block: uint,
        resolution-block: uint,
        outcome-count: uint,
        winning-outcome: (optional uint),
        is-resolved: bool,
        total-predictions: uint
    }
)

(define-map predictions
    uint
    {
        tournament-id: uint,
        predictor: principal,
        predicted-outcome: uint,
        amount: uint,
        timestamp: uint,
        claimed: bool
    }
)

(define-map tournament-predictions
    {tournament-id: uint, predictor: principal}
    uint
)

(define-map outcome-totals
    {tournament-id: uint, outcome: uint}
    uint
)

(define-map user-tournament-count
    principal
    uint
)

;; Private Functions
(define-private (get-next-tournament-id)
    (let ((current-id (var-get tournament-counter)))
        (var-set tournament-counter (+ current-id u1))
        current-id
    )
)

(define-private (get-next-prediction-id)
    (let ((current-id (var-get prediction-counter)))
        (var-set prediction-counter (+ current-id u1))
        current-id
    )
)

;; Public Functions

;; Create a new tournament
(define-public (create-tournament 
    (title (string-ascii 100))
    (description (string-ascii 500))
    (category (string-ascii 50))
    (entry-fee uint)
    (duration-blocks uint)
    (resolution-delay-blocks uint)
    (outcome-count uint))
    (let
        (
            (tournament-id (get-next-tournament-id))
            (start-block stacks-block-height)
            (end-block (+ stacks-block-height duration-blocks))
            (resolution-block (+ end-block resolution-delay-blocks))
        )
        (asserts! (> outcome-count u1) err-invalid-prediction)
        (asserts! (> duration-blocks u0) err-invalid-prediction)
        
        (map-set tournaments tournament-id {
            creator: tx-sender,
            title: title,
            description: description,
            category: category,
            entry-fee: entry-fee,
            total-pool: u0,
            start-block: start-block,
            end-block: end-block,
            resolution-block: resolution-block,
            outcome-count: outcome-count,
            winning-outcome: none,
            is-resolved: false,
            total-predictions: u0
        })
        
        (ok tournament-id)
    )
)

;; Make a prediction
(define-public (make-prediction (tournament-id uint) (predicted-outcome uint))
    (let
        (
            (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
            (prediction-id (get-next-prediction-id))
            (entry-fee (get entry-fee tournament))
            (existing-prediction (map-get? tournament-predictions {tournament-id: tournament-id, predictor: tx-sender}))
        )
        ;; Validations
        (asserts! (is-none existing-prediction) err-already-predicted)
        (asserts! (< stacks-block-height (get end-block tournament)) err-tournament-closed)
        (asserts! (< predicted-outcome (get outcome-count tournament)) err-invalid-prediction)
        (asserts! (>= predicted-outcome u0) err-invalid-prediction)
        
        ;; Transfer entry fee if required
        (if (> entry-fee u0)
            (try! (stx-transfer? entry-fee tx-sender (as-contract tx-sender)))
            true
        )
        
        ;; Store prediction
        (map-set predictions prediction-id {
            tournament-id: tournament-id,
            predictor: tx-sender,
            predicted-outcome: predicted-outcome,
            amount: entry-fee,
            timestamp: stacks-block-height,
            claimed: false
        })
        
        ;; Link prediction to user and tournament
        (map-set tournament-predictions 
            {tournament-id: tournament-id, predictor: tx-sender}
            prediction-id
        )
        
        ;; Update outcome totals
        (let ((current-total (default-to u0 (map-get? outcome-totals {tournament-id: tournament-id, outcome: predicted-outcome}))))
            (map-set outcome-totals 
                {tournament-id: tournament-id, outcome: predicted-outcome}
                (+ current-total entry-fee)
            )
        )
        
        ;; Update tournament stats
        (map-set tournaments tournament-id
            (merge tournament {
                total-pool: (+ (get total-pool tournament) entry-fee),
                total-predictions: (+ (get total-predictions tournament) u1)
            })
        )
        
        ;; Update user stats
        (let ((user-count (default-to u0 (map-get? user-tournament-count tx-sender))))
            (map-set user-tournament-count tx-sender (+ user-count u1))
        )
        
        (ok prediction-id)
    )
)

;; Resolve tournament (only creator can resolve)
(define-public (resolve-tournament (tournament-id uint) (winning-outcome uint))
    (let
        (
            (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
        )
        ;; Validations
        (asserts! (is-eq tx-sender (get creator tournament)) err-owner-only)
        (asserts! (>= stacks-block-height (get resolution-block tournament)) err-tournament-active)
        (asserts! (not (get is-resolved tournament)) err-already-resolved)
        (asserts! (< winning-outcome (get outcome-count tournament)) err-invalid-prediction)
        
        ;; Mark tournament as resolved
        (map-set tournaments tournament-id
            (merge tournament {
                winning-outcome: (some winning-outcome),
                is-resolved: true
            })
        )
        
        (ok true)
    )
)

;; Claim winnings
(define-public (claim-winnings (tournament-id uint))
    (let
        (
            (tournament (unwrap! (map-get? tournaments tournament-id) err-not-found))
            (prediction-id (unwrap! (map-get? tournament-predictions {tournament-id: tournament-id, predictor: tx-sender}) err-not-found))
            (prediction (unwrap! (map-get? predictions prediction-id) err-not-found))
            (winning-outcome (unwrap! (get winning-outcome tournament) err-not-resolved))
        )
        ;; Validations
        (asserts! (get is-resolved tournament) err-not-resolved)
        (asserts! (not (get claimed prediction)) err-already-claimed)
        (asserts! (is-eq (get predicted-outcome prediction) winning-outcome) err-invalid-prediction)
        
        ;; Calculate winnings
        (let
            (
                (total-pool (get total-pool tournament))
                (winning-total (default-to u1 (map-get? outcome-totals {tournament-id: tournament-id, outcome: winning-outcome})))
                (user-stake (get amount prediction))
                (user-winnings (/ (* total-pool user-stake) winning-total))
            )
            ;; Mark as claimed
            (map-set predictions prediction-id
                (merge prediction {claimed: true})
            )
            
            ;; Transfer winnings
            (as-contract (stx-transfer? user-winnings tx-sender (get predictor prediction)))
        )
    )
)

;; Read-only functions

(define-read-only (get-tournament (tournament-id uint))
    (map-get? tournaments tournament-id)
)

(define-read-only (get-prediction (prediction-id uint))
    (map-get? predictions prediction-id)
)

(define-read-only (get-user-prediction (tournament-id uint) (user principal))
    (match (map-get? tournament-predictions {tournament-id: tournament-id, predictor: user})
        prediction-id (map-get? predictions prediction-id)
        none
    )
)

(define-read-only (get-outcome-total (tournament-id uint) (outcome uint))
    (default-to u0 (map-get? outcome-totals {tournament-id: tournament-id, outcome: outcome}))
)

(define-read-only (get-user-tournament-count (user principal))
    (default-to u0 (map-get? user-tournament-count user))
)

(define-read-only (get-tournament-count)
    (var-get tournament-counter)
)

(define-read-only (get-prediction-count)
    (var-get prediction-counter)
)

(define-read-only (calculate-potential-winnings (tournament-id uint) (user principal))
    (match (get-tournament tournament-id)
        tournament
        (match (get-user-prediction tournament-id user)
            prediction
            (match (get winning-outcome tournament)
                winning-outcome
                (let
                    (
                        (total-pool (get total-pool tournament))
                        (winning-total (get-outcome-total tournament-id winning-outcome))
                        (user-stake (get amount prediction))
                    )
                    (if (is-eq (get predicted-outcome prediction) winning-outcome)
                        (ok (/ (* total-pool user-stake) winning-total))
                        (ok u0)
                    )
                )
                (ok u0)
            )
            err-not-found
        )
        err-not-found
    )
)