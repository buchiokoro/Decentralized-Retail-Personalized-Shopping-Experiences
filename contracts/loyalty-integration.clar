;; Loyalty Integration Contract
;; Integrates personalized shopping with loyalty programs

;; Constants
(define-constant ERR_INSUFFICIENT_POINTS (err u500))
(define-constant ERR_INVALID_TIER (err u501))
(define-constant ERR_CUSTOMER_NOT_FOUND (err u502))

;; Data Variables
(define-data-var base-points-rate uint u10) ;; Points per unit spent

;; Data Maps
(define-map loyalty-accounts
  { customer: principal }
  {
    total-points: uint,
    tier: (string-ascii 20),
    tier-benefits: uint,
    lifetime-spent: uint,
    last-activity: uint
  }
)

(define-map loyalty-transactions
  { customer: principal, transaction-id: uint }
  {
    points-earned: uint,
    points-spent: uint,
    transaction-type: (string-ascii 30),
    retailer-id: uint,
    block-height: uint
  }
)

(define-map customer-transaction-count
  { customer: principal }
  { count: uint }
)

(define-map tier-requirements
  { tier: (string-ascii 20) }
  {
    min-spent: uint,
    points-multiplier: uint,
    special-benefits: uint
  }
)

;; Initialize tier requirements
(map-set tier-requirements { tier: "Bronze" } { min-spent: u0, points-multiplier: u1, special-benefits: u0 })
(map-set tier-requirements { tier: "Silver" } { min-spent: u1000, points-multiplier: u2, special-benefits: u5 })
(map-set tier-requirements { tier: "Gold" } { min-spent: u5000, points-multiplier: u3, special-benefits: u10 })
(map-set tier-requirements { tier: "Platinum" } { min-spent: u10000, points-multiplier: u4, special-benefits: u20 })

;; Public Functions

;; Initialize loyalty account
(define-public (initialize-account)
  (let ((caller tx-sender))
    (map-set loyalty-accounts
      { customer: caller }
      {
        total-points: u0,
        tier: "Bronze",
        tier-benefits: u0,
        lifetime-spent: u0,
        last-activity: block-height
      }
    )
    (ok true)
  )
)

;; Earn points from purchase
(define-public (earn-points (amount uint) (retailer-id uint))
  (let ((caller tx-sender)
        (current-account (unwrap! (map-get? loyalty-accounts { customer: caller }) ERR_CUSTOMER_NOT_FOUND))
        (current-count (default-to u0 (get count (map-get? customer-transaction-count { customer: caller }))))
        (transaction-id (+ current-count u1))
        (tier-multiplier (get-tier-multiplier (get tier current-account)))
        (points-earned (* amount (* (var-get base-points-rate) tier-multiplier)))
        (new-lifetime-spent (+ (get lifetime-spent current-account) amount))
        (new-total-points (+ (get total-points current-account) points-earned))
        (new-tier (calculate-tier new-lifetime-spent)))

    ;; Update loyalty account
    (map-set loyalty-accounts
      { customer: caller }
      (merge current-account {
        total-points: new-total-points,
        tier: new-tier,
        lifetime-spent: new-lifetime-spent,
        last-activity: block-height
      })
    )

    ;; Record transaction
    (map-set loyalty-transactions
      { customer: caller, transaction-id: transaction-id }
      {
        points-earned: points-earned,
        points-spent: u0,
        transaction-type: "purchase",
        retailer-id: retailer-id,
        block-height: block-height
      }
    )

    ;; Update transaction count
    (map-set customer-transaction-count
      { customer: caller }
      { count: transaction-id }
    )

    (ok points-earned)
  )
)

;; Redeem points
(define-public (redeem-points (points uint) (retailer-id uint))
  (let ((caller tx-sender)
        (current-account (unwrap! (map-get? loyalty-accounts { customer: caller }) ERR_CUSTOMER_NOT_FOUND))
        (current-count (default-to u0 (get count (map-get? customer-transaction-count { customer: caller }))))
        (transaction-id (+ current-count u1)))

    (asserts! (>= (get total-points current-account) points) ERR_INSUFFICIENT_POINTS)

    ;; Update loyalty account
    (map-set loyalty-accounts
      { customer: caller }
      (merge current-account {
        total-points: (- (get total-points current-account) points),
        last-activity: block-height
      })
    )

    ;; Record transaction
    (map-set loyalty-transactions
      { customer: caller, transaction-id: transaction-id }
      {
        points-earned: u0,
        points-spent: points,
        transaction-type: "redemption",
        retailer-id: retailer-id,
        block-height: block-height
      }
    )

    ;; Update transaction count
    (map-set customer-transaction-count
      { customer: caller }
      { count: transaction-id }
    )

    (ok true)
  )
)

;; Private Functions

;; Get tier multiplier
(define-private (get-tier-multiplier (tier (string-ascii 20)))
  (default-to u1 (get points-multiplier (map-get? tier-requirements { tier: tier })))
)

;; Calculate tier based on lifetime spending
(define-private (calculate-tier (lifetime-spent uint))
  (if (>= lifetime-spent u10000)
    "Platinum"
    (if (>= lifetime-spent u5000)
      "Gold"
      (if (>= lifetime-spent u1000)
        "Silver"
        "Bronze"
      )
    )
  )
)

;; Read-only Functions

;; Get loyalty account
(define-read-only (get-loyalty-account (customer principal))
  (map-get? loyalty-accounts { customer: customer })
)

;; Get loyalty transaction
(define-read-only (get-loyalty-transaction (customer principal) (transaction-id uint))
  (map-get? loyalty-transactions { customer: customer, transaction-id: transaction-id })
)

;; Get tier requirements
(define-read-only (get-tier-info (tier (string-ascii 20)))
  (map-get? tier-requirements { tier: tier })
)

;; Get customer transaction count
(define-read-only (get-transaction-count (customer principal))
  (default-to u0 (get count (map-get? customer-transaction-count { customer: customer })))
)
