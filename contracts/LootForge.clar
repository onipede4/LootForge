;; LooteForge Gaming Platform Smart Contract
;; Handles in-game asset ownership and trading functionality

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-authorized (err u102))
(define-constant err-invalid-input (err u103))
(define-constant err-invalid-price (err u104))
(define-constant max-level u100)
(define-constant max-experience u10000)
(define-constant max-metadata-length u256)
(define-constant max-batch-size u10)  ;; Limit batch operations to prevent potential gas issues

;; Data Variables
(define-map assets 
    { asset-id: uint }
    { owner: principal, metadata-uri: (string-utf8 256), transferable: bool })

(define-map asset-prices
    { asset-id: uint }
    { price: uint })

(define-map player-stats
    { player: principal }
    { experience: uint, level: uint })

(define-map marketplace-listings
    { asset-id: uint }
    { seller: principal, price: uint, listed-at: uint })

;; Asset Counter
(define-data-var asset-counter uint u0)

;; Helper Functions

;; Validate asset exists and return asset data
(define-private (get-asset-checked (asset-id uint))
    (let ((asset (map-get? assets { asset-id: asset-id })))
        (asserts! (and 
                (is-some asset)
                (<= asset-id (var-get asset-counter)))
            err-not-found)
        (ok (unwrap-panic asset))))

;; Validate metadata URI length
(define-private (validate-metadata-uri (uri (string-utf8 256)))
    (let ((uri-length (len uri)))
        (and 
            (> uri-length u0)
            (<= uri-length max-metadata-length))))

;; Public Functions

;; Batch Mint new gaming assets
(define-public (batch-mint-assets 
    (metadata-uris (list 10 (string-utf8 256))) 
    (transferable-list (list 10 bool)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (and 
            (> (len metadata-uris) u0)
            (<= (len metadata-uris) max-batch-size)
            (is-eq (len metadata-uris) (len transferable-list))) 
            err-invalid-input)
        (let ((minted-assets 
            (map mint-single-asset 
                metadata-uris 
                transferable-list)))
            (ok minted-assets))))

;; Helper function for batch minting
(define-private (mint-single-asset 
    (uri (string-utf8 256))
    (transferable bool))
    (let 
        ((asset-id (+ (var-get asset-counter) u1)))
        (asserts! (validate-metadata-uri uri) err-invalid-input)
        (map-set assets
            { asset-id: asset-id }
            { owner: contract-owner,
              metadata-uri: uri,
              transferable: transferable })
        (var-set asset-counter asset-id)
        (ok asset-id)))

;; Batch Transfer assets
(define-public (batch-transfer-assets 
    (asset-ids (list 10 uint)) 
    (recipients (list 10 principal)))
    (begin
        (asserts! (and 
            (> (len asset-ids) u0)
            (<= (len asset-ids) max-batch-size)
            (is-eq (len asset-ids) (len recipients))) 
            err-invalid-input)
        (let ((transfers 
            (map transfer-single-asset 
                asset-ids 
                recipients)))
            (ok transfers))))

;; Helper function for batch transfer
(define-private (transfer-single-asset 
    (asset-id uint)
    (recipient principal))
    (let 
        ((asset (unwrap-panic (get-asset-checked asset-id))))
        (asserts! (and
                (is-eq (get owner asset) tx-sender)
                (get transferable asset)
                (not (is-eq recipient tx-sender)))  ;; Prevent self-transfers
            err-not-authorized)
        (map-set assets
            { asset-id: asset-id }
            { owner: recipient,
              metadata-uri: (get metadata-uri asset),
              transferable: (get transferable asset) })
        (ok true)))  ;; Changed to return (ok true)


;; Mint single asset
(define-public (mint-asset (metadata-uri (string-utf8 256)) (transferable bool))
    (let
        ((asset-id (+ (var-get asset-counter) u1)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (validate-metadata-uri metadata-uri) err-invalid-input)
        (map-set assets
            { asset-id: asset-id }
            { owner: tx-sender,
              metadata-uri: metadata-uri,
              transferable: transferable })
        (var-set asset-counter asset-id)
        (ok asset-id)))