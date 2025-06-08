;; Customer Preference Contract
;; Manages customer shopping preferences and behavior data

;; Constants
(define-constant ERR_UNAUTHORIZED (err u200))
(define-constant ERR_PREFERENCE_NOT_FOUND (err u201))
(define-constant ERR_INVALID_CATEGORY (err u202))

;; Data Variables
(define-data-var next-preference-id uint u1)

;; Data Maps
(define-map customer-preferences
  { customer: principal }
  {
    preference-id: uint,
    categories: (list 10 (string-ascii 30)),
    price-range-min: uint,
    price-range-max: uint,
    brand-preferences: (list 5 (string-ascii 30)),
    last-updated: uint
  }
)

(define-map purchase-history
  { customer: principal, purchase-id: uint }
  {
    retailer-id: uint,
    category: (string-ascii 30),
    amount: uint,
    satisfaction-rating: uint,
    purchase-block: uint
  }
)

(define-map customer-purchase-count
  { customer: principal }
  { count: uint }
)

;; Public Functions

;; Set customer preferences
(define-public (set-preferences
  (categories (list 10 (string-ascii 30)))
  (price-min uint)
  (price-max uint)
  (brands (list 5 (string-ascii 30))))
  (let ((preference-id (var-get next-preference-id))
        (caller tx-sender))
    (map-set customer-preferences
      { customer: caller }
      {
        preference-id: preference-id,
        categories: categories,
        price-range-min: price-min,
        price-range-max: price-max,
        brand-preferences: brands,
        last-updated: block-height
      }
    )
    (var-set next-preference-id (+ preference-id u1))
    (ok preference-id)
  )
)

;; Record a purchase
(define-public (record-purchase
  (retailer-id uint)
  (category (string-ascii 30))
  (amount uint)
  (satisfaction uint))
  (let ((caller tx-sender)
        (current-count (default-to u0 (get count (map-get? customer-purchase-count { customer: caller }))))
        (purchase-id (+ current-count u1)))
    (map-set purchase-history
      { customer: caller, purchase-id: purchase-id }
      {
        retailer-id: retailer-id,
        category: category,
        amount: amount,
        satisfaction-rating: satisfaction,
        purchase-block: block-height
      }
    )
    (map-set customer-purchase-count
      { customer: caller }
      { count: purchase-id }
    )
    (ok purchase-id)
  )
)

;; Update preferences
(define-public (update-categories (new-categories (list 10 (string-ascii 30))))
  (let ((caller tx-sender)
        (current-prefs (unwrap! (map-get? customer-preferences { customer: caller }) ERR_PREFERENCE_NOT_FOUND)))
    (map-set customer-preferences
      { customer: caller }
      (merge current-prefs {
        categories: new-categories,
        last-updated: block-height
      })
    )
    (ok true)
  )
)

;; Read-only Functions

;; Get customer preferences
(define-read-only (get-preferences (customer principal))
  (map-get? customer-preferences { customer: customer })
)

;; Get purchase history
(define-read-only (get-purchase (customer principal) (purchase-id uint))
  (map-get? purchase-history { customer: customer, purchase-id: purchase-id })
)

;; Get customer purchase count
(define-read-only (get-purchase-count (customer principal))
  (default-to u0 (get count (map-get? customer-purchase-count { customer: customer })))
)

;; Check if customer has preferences set
(define-read-only (has-preferences (customer principal))
  (is-some (map-get? customer-preferences { customer: customer }))
)
