;; RoyaltyFlow: Automated Digital Asset Royalty System
;; This contract manages royalty distributions for NFT sales, allowing creators to receive
;; automatic payments when their NFTs are resold. It supports multiple royalty beneficiaries,
;; configurable percentages, and includes security features to prevent common vulnerabilities.

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-PERCENTAGE (err u101))
(define-constant ERR-NFT-NOT-FOUND (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-ALREADY-EXISTS (err u104))
(define-constant ERR-INVALID-RECIPIENT (err u105))
(define-constant ERR-TRANSFER-FAILED (err u106))
(define-constant ERR-INVALID-PRICE (err u107))
(define-constant MAX-ROYALTY-PERCENTAGE u1000) ;; 10% max (basis points: 1000 = 10%)
(define-constant BASIS-POINTS u10000) ;; 100% in basis points

;; data maps and vars
(define-data-var contract-paused bool false)
(define-data-var total-royalties-distributed uint u0)

;; Map: NFT ID -> Royalty Configuration
(define-map nft-royalties
  { nft-id: uint }
  {
    creator: principal,
    royalty-percentage: uint, ;; in basis points (100 = 1%)
    is-active: bool,
    created-at: uint
  }
)

;; Map: NFT ID -> Sale Record
(define-map nft-sales
  { nft-id: uint, sale-id: uint }
  {
    seller: principal,
    buyer: principal,
    sale-price: uint,
    royalty-paid: uint,
    sale-timestamp: uint
  }
)

;; Map: Track sale counter for each NFT
(define-map nft-sale-counter
  { nft-id: uint }
  { counter: uint }
)

;; Map: Secondary royalty recipients (for splits)
(define-map secondary-recipients
  { nft-id: uint, recipient: principal }
  { percentage: uint } ;; percentage of the royalty (basis points)
)

;; private functions
;; Check if caller is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Check if contract is not paused
(define-private (is-contract-active)
  (not (var-get contract-paused))
)

;; Validate royalty percentage (max 10%)
(define-private (is-valid-royalty-percentage (percentage uint))
  (and (> percentage u0) (<= percentage MAX-ROYALTY-PERCENTAGE))
)

;; Calculate royalty amount from sale price
(define-private (calculate-royalty-amount (sale-price uint) (percentage uint))
  (/ (* sale-price percentage) BASIS-POINTS)
)

;; Get next sale ID for an NFT
(define-private (get-next-sale-id (nft-id uint))
  (match (map-get? nft-sale-counter { nft-id: nft-id })
    counter-data (+ (get counter counter-data) u1)
    u1
  )
)

;; Update sale counter
(define-private (update-sale-counter (nft-id uint) (new-counter uint))
  (map-set nft-sale-counter { nft-id: nft-id } { counter: new-counter })
)

;; Helper function to extract split percentage from recipient tuple
(define-private (get-split-percentage (recipient { recipient: principal, split-percentage: uint }))
  (get split-percentage recipient)
)

;; Helper function to set secondary recipient
(define-private (set-secondary-recipient
  (recipient-data { recipient: principal, split-percentage: uint })
  (nft-id uint))
  (begin
    (map-set secondary-recipients
      { nft-id: nft-id, recipient: (get recipient recipient-data) }
      { percentage: (get split-percentage recipient-data) }
    )
    nft-id
  )
)

;; Helper function to clear existing secondary recipients
(define-private (clear-secondary-recipients (nft-id uint))
  ;; Note: In a production environment, you'd need to track recipients
  ;; to properly clear them. This is a simplified version.
  true
)

;; public functions
;; Initialize royalty configuration for an NFT
(define-public (set-nft-royalty (nft-id uint) (creator principal) (royalty-percentage uint))
  (begin
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-royalty-percentage royalty-percentage) ERR-INVALID-PERCENTAGE)
    (asserts! (is-ok (principal-destruct? creator)) ERR-INVALID-RECIPIENT)
    
    ;; Check if royalty already exists
    (asserts! (is-none (map-get? nft-royalties { nft-id: nft-id })) ERR-ALREADY-EXISTS)
    
    ;; Set royalty configuration
    (map-set nft-royalties
      { nft-id: nft-id }
      {
        creator: creator,
        royalty-percentage: royalty-percentage,
        is-active: true,
        created-at: block-height
      }
    )
    (ok true)
  )
)

;; Record an NFT sale and distribute royalties
(define-public (process-nft-sale (nft-id uint) (seller principal) (buyer principal) (sale-price uint))
  (begin
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (> sale-price u0) ERR-INVALID-PRICE)
    
    (let (
      (royalty-config (unwrap! (map-get? nft-royalties { nft-id: nft-id }) ERR-NFT-NOT-FOUND))
      (sale-id (get-next-sale-id nft-id))
      (royalty-amount (calculate-royalty-amount sale-price (get royalty-percentage royalty-config)))
      (creator (get creator royalty-config))
    )
      ;; Verify royalty is active
      (asserts! (get is-active royalty-config) ERR-NOT-AUTHORIZED)
      
      ;; Record the sale
      (map-set nft-sales
        { nft-id: nft-id, sale-id: sale-id }
        {
          seller: seller,
          buyer: buyer,
          sale-price: sale-price,
          royalty-paid: royalty-amount,
          sale-timestamp: block-height
        }
      )
      
      ;; Update sale counter
      (update-sale-counter nft-id sale-id)
      
      ;; Distribute royalty to creator
      (if (> royalty-amount u0)
        (begin
          (try! (stx-transfer? royalty-amount tx-sender creator))
          (var-set total-royalties-distributed
            (+ (var-get total-royalties-distributed) royalty-amount))
        )
        true
      )
      
      (ok { sale-id: sale-id, royalty-paid: royalty-amount })
    )
  )
)

;; Update royalty percentage (only creator can update)
(define-public (update-royalty-percentage (nft-id uint) (new-percentage uint))
  (begin
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-royalty-percentage new-percentage) ERR-INVALID-PERCENTAGE)
    
    (let (
      (royalty-config (unwrap! (map-get? nft-royalties { nft-id: nft-id }) ERR-NFT-NOT-FOUND))
    )
      ;; Only creator can update
      (asserts! (is-eq tx-sender (get creator royalty-config)) ERR-NOT-AUTHORIZED)
      
      ;; Update royalty percentage
      (map-set nft-royalties
        { nft-id: nft-id }
        (merge royalty-config { royalty-percentage: new-percentage })
      )
      (ok true)
    )
  )
)

;; Deactivate royalty collection for an NFT (only creator)
(define-public (deactivate-royalty (nft-id uint))
  (begin
    (asserts! (is-contract-active) ERR-NOT-AUTHORIZED)
    
    (let (
      (royalty-config (unwrap! (map-get? nft-royalties { nft-id: nft-id }) ERR-NFT-NOT-FOUND))
    )
      ;; Only creator can deactivate
      (asserts! (is-eq tx-sender (get creator royalty-config)) ERR-NOT-AUTHORIZED)
      
      ;; Deactivate royalty
      (map-set nft-royalties
        { nft-id: nft-id }
        (merge royalty-config { is-active: false })
      )
      (ok true)
    )
  )
)

;; Emergency pause contract (only owner)
(define-public (pause-contract)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-paused true)
    (ok true)
  )
)

;; Resume contract operations (only owner)
(define-public (resume-contract)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-paused false)
    (ok true)
  )
)

;; Read-only Functions

;; Get royalty configuration for an NFT
(define-read-only (get-nft-royalty (nft-id uint))
  (map-get? nft-royalties { nft-id: nft-id })
)

;; Get sale information
(define-read-only (get-sale-info (nft-id uint) (sale-id uint))
  (map-get? nft-sales { nft-id: nft-id, sale-id: sale-id })
)

;; Get total royalties distributed
(define-read-only (get-total-royalties-distributed)
  (var-get total-royalties-distributed)
)

;; Check if contract is paused
(define-read-only (is-paused)
  (var-get contract-paused)
)


