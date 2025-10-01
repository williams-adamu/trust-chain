;; TrustChain - Immutable Professional Credentials Protocol                 
;;
;; Summary:
;; TrustChain transforms professional credentials into permanent, verifiable 
;; digital assets anchored on Bitcoin's blockchain through Stacks Layer-2.
;;
;; Description:
;; An enterprise-grade protocol enabling organizations to mint tamper-proof
;; professional credentials as SIP-009 compliant NFTs. Each credential carries
;; cryptographically verified proof of skills, roles, and employment history,
;; creating an unforgeable career portfolio that follows professionals throughout
;; their journey. Built on Bitcoin's security with Clarity's predictable execution.

;; TRAITS & STANDARDS

;; Implements SIP-009 Non-Fungible Token Standard

;; TOKEN DEFINITION

(define-non-fungible-token trustchain-credential uint)

;; CONSTANTS & ERROR CODES

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-INVALID-CREDENTIAL (err u400))
(define-constant ERR-EXPIRED-CREDENTIAL (err u410))
(define-constant ERR-REVOKED-CREDENTIAL (err u403))

;; DATA VARIABLES

(define-data-var last-token-id uint u0)
(define-data-var contract-paused bool false)

;; DATA MAPS

;; Credential metadata storage
(define-map credential-data
    { token-id: uint }
    {
        issuer: principal,
        recipient: principal,
        credential-type: (string-ascii 50),
        role-title: (string-ascii 100),
        company-name: (string-ascii 100),
        issue-date: uint,
        expiry-date: (optional uint),
        skills: (list 10 (string-ascii 50)),
        metadata-uri: (string-ascii 256),
        is-revoked: bool,
    }
)

;; Company authorization and rate limiting
(define-map authorized-companies
    { company: principal }
    {
        company-name: (string-ascii 100),
        registration-date: uint,
        is-active: bool,
        monthly-limit: uint,
        used-this-month: uint,
        last-reset: uint,
    }
)

;; Employee credential tracking
(define-map employee-credentials
    { employee: principal }
    { credential-count: uint }
)

;; Revocation audit trail
(define-map revocation-data
    { token-id: uint }
    {
        revoked-by: principal,
        revocation-date: uint,
        reason: (string-ascii 256),
    }
)

;; SIP-009 STANDARD FUNCTIONS

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (match (map-get? credential-data { token-id: token-id })
        credential-info (ok (some (get metadata-uri credential-info)))
        ERR-NOT-FOUND
    )
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? trustchain-credential token-id))
)

(define-public (transfer
        (token-id uint)
        (sender principal)
        (recipient principal)
    )
    ;; Credentials are soul-bound and non-transferable to maintain integrity
    ERR-NOT-AUTHORIZED
)

;; COMPANY MANAGEMENT

(define-public (register-company
        (company-name (string-ascii 100))
        (monthly-limit uint)
    )
    (let ((company tx-sender))
        (asserts! (not (get-contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? authorized-companies { company: company }))
            ERR-ALREADY-EXISTS
        )
        (asserts! (> (len company-name) u0) ERR-INVALID-CREDENTIAL)
        (asserts! (> monthly-limit u0) ERR-INVALID-CREDENTIAL)

        (map-set authorized-companies { company: company } {
            company-name: company-name,
            registration-date: stacks-block-height,
            is-active: true,
            monthly-limit: monthly-limit,
            used-this-month: u0,
            last-reset: stacks-block-height,
        })
        (ok company)
    )
)

;; CREDENTIAL ISSUANCE

(define-public (issue-credential
        (recipient principal)
        (credential-type (string-ascii 50))
        (role-title (string-ascii 100))
        (skills (list 10 (string-ascii 50)))
        (metadata-uri (string-ascii 256))
        (expiry-date (optional uint))
    )
    (let (
            (token-id (+ (var-get last-token-id) u1))
            (issuer tx-sender)
            (current-height stacks-block-height)
        )
        ;; Pre-flight validations
        (asserts! (not (get-contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts! (is-company-authorized issuer) ERR-NOT-AUTHORIZED)
        (asserts! (can-issue-credential issuer) ERR-NOT-AUTHORIZED)
        (asserts! (> (len credential-type) u0) ERR-INVALID-CREDENTIAL)
        (asserts! (> (len role-title) u0) ERR-INVALID-CREDENTIAL)
        (asserts! (> (len metadata-uri) u0) ERR-INVALID-CREDENTIAL)

        ;; Validate expiry date if provided
        (match expiry-date
            exp-date (asserts! (> exp-date current-height) ERR-INVALID-CREDENTIAL)
            true
        )

        ;; Mint credential NFT
        (try! (nft-mint? trustchain-credential token-id recipient))

        ;; Store comprehensive credential data
        (map-set credential-data { token-id: token-id } {
            issuer: issuer,
            recipient: recipient,
            credential-type: credential-type,
            role-title: role-title,
            company-name: (get-company-name issuer),
            issue-date: current-height,
            expiry-date: expiry-date,
            skills: skills,
            metadata-uri: metadata-uri,
            is-revoked: false,
        })

        ;; Update rate limiting counters
        (update-company-usage issuer)
        (update-employee-count recipient)

        ;; Increment global token counter
        (var-set last-token-id token-id)

        (ok token-id)
    )
)

;; CREDENTIAL REVOCATION

(define-public (revoke-credential
        (token-id uint)
        (reason (string-ascii 256))
    )
    (let ((credential-info (unwrap! (map-get? credential-data { token-id: token-id }) ERR-NOT-FOUND)))
        (asserts! (not (get-contract-paused)) ERR-NOT-AUTHORIZED)
        (asserts!
            (or
                (is-eq tx-sender (get issuer credential-info))
                (is-eq tx-sender CONTRACT-OWNER)
            )
            ERR-NOT-AUTHORIZED
        )
        (asserts! (not (get is-revoked credential-info)) ERR-ALREADY-EXISTS)

        ;; Mark credential as revoked
        (map-set credential-data { token-id: token-id }
            (merge credential-info { is-revoked: true })
        )

        ;; Create audit trail
        (map-set revocation-data { token-id: token-id } {
            revoked-by: tx-sender,
            revocation-date: stacks-block-height,
            reason: reason,
        })

        (ok true)
    )
)

;; READ-ONLY FUNCTIONS

(define-read-only (get-contract-paused)
    (var-get contract-paused)
)

(define-read-only (is-company-authorized (company principal))
    (match (map-get? authorized-companies { company: company })
        company-info (get is-active company-info)
        false
    )
)

(define-read-only (can-issue-credential (company principal))
    (match (map-get? authorized-companies { company: company })
        company-info (let ((reset-needed (> (- stacks-block-height (get last-reset company-info)) u4320)))
            (if reset-needed
                true
                (< (get used-this-month company-info)
                    (get monthly-limit company-info)
                )
            )
        )
        false
    )
)

(define-read-only (get-company-name (company principal))
    (match (map-get? authorized-companies { company: company })
        company-info (get company-name company-info)
        "Unknown Company"
    )
)

(define-read-only (get-credential-info (token-id uint))
    (map-get? credential-data { token-id: token-id })
)

(define-read-only (get-company-info (company principal))
    (map-get? authorized-companies { company: company })
)

(define-read-only (is-credential-valid (token-id uint))
    (match (map-get? credential-data { token-id: token-id })
        credential-info (let ((is-not-revoked (not (get is-revoked credential-info))))
            (match (get expiry-date credential-info)
                exp-date
                (and is-not-revoked (< stacks-block-height exp-date))
                is-not-revoked
            )
        )
        false
    )
)

(define-read-only (get-employee-credential-count (employee principal))
    (default-to u0
        (get credential-count
            (map-get? employee-credentials { employee: employee })
        ))
)

;; PRIVATE HELPER FUNCTIONS

(define-private (update-company-usage (company principal))
    (match (map-get? authorized-companies { company: company })
        company-info (let ((reset-needed (> (- stacks-block-height (get last-reset company-info)) u4320)))
            (if reset-needed
                ;; Reset counter for new monthly period
                (map-set authorized-companies { company: company }
                    (merge company-info {
                        used-this-month: u1,
                        last-reset: stacks-block-height,
                    })
                )
                ;; Increment usage counter
                (map-set authorized-companies { company: company }
                    (merge company-info { used-this-month: (+ (get used-this-month company-info) u1) })
                )
            )
        )
        false
    )
)

(define-private (update-employee-count (employee principal))
    (let ((current-count (get-employee-credential-count employee)))
        (map-set employee-credentials { employee: employee } { credential-count: (+ current-count u1) })
    )
)

;; ADMINISTRATIVE FUNCTIONS

(define-public (set-contract-paused (paused bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set contract-paused paused)
        (ok paused)
    )
)

(define-public (update-company-status
        (company principal)
        (is-active bool)
    )
    (let ((company-info (unwrap! (map-get? authorized-companies { company: company })
            ERR-NOT-FOUND
        )))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (map-set authorized-companies { company: company }
            (merge company-info { is-active: is-active })
        )
        (ok is-active)
    )
)

(define-public (update-company-limit
        (company principal)
        (new-limit uint)
    )
    (let ((company-info (unwrap! (map-get? authorized-companies { company: company })
            ERR-NOT-FOUND
        )))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (> new-limit u0) ERR-INVALID-CREDENTIAL)
        (map-set authorized-companies { company: company }
            (merge company-info { monthly-limit: new-limit })
        )
        (ok new-limit)
    )
)

(define-public (admin-revoke-credential
        (token-id uint)
        (reason (string-ascii 256))
    )
    (let ((credential-info (unwrap! (map-get? credential-data { token-id: token-id }) ERR-NOT-FOUND)))
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (not (get is-revoked credential-info)) ERR-ALREADY-EXISTS)

        ;; Mark credential as revoked
        (map-set credential-data { token-id: token-id }
            (merge credential-info { is-revoked: true })
        )

        ;; Store revocation data
        (map-set revocation-data { token-id: token-id } {
            revoked-by: tx-sender,
            revocation-date: stacks-block-height,
            reason: reason,
        })

        (ok true)
    )
)

;; ADVANCED QUERY FUNCTIONS

(define-read-only (get-credentials-by-recipient
        (recipient principal)
        (limit uint)
        (offset uint)
    )
    (let ((recipient-count (get-employee-credential-count recipient)))
        {
            total-count: recipient-count,
            has-more: (> recipient-count (+ offset limit)),
        }
    )
)

(define-read-only (get-company-stats (company principal))
    (match (map-get? authorized-companies { company: company })
        company-info (ok {
            company-name: (get company-name company-info),
            registration-date: (get registration-date company-info),
            is-active: (get is-active company-info),
            monthly-limit: (get monthly-limit company-info),
            used-this-month: (get used-this-month company-info),
            remaining-this-month: (- (get monthly-limit company-info)
                (get used-this-month company-info)
            ),
            last-reset: (get last-reset company-info),
            days-until-reset: (- u4320 (- stacks-block-height (get last-reset company-info))),
        })
        ERR-NOT-FOUND
    )
)

(define-read-only (credential-exists (token-id uint))
    (is-some (map-get? credential-data { token-id: token-id }))
)

(define-read-only (get-revocation-info (token-id uint))
    (map-get? revocation-data { token-id: token-id })
)

(define-read-only (batch-verify-credentials (token-ids (list 20 uint)))
    (map is-credential-valid token-ids)
)

(define-read-only (get-company-issued-count (company principal))
    (match (map-get? authorized-companies { company: company })
        company-info (ok (get used-this-month company-info))
        ERR-NOT-FOUND
    )
)

;; UTILITY FUNCTIONS

(define-read-only (get-contract-info)
    {
        version: "1.0.0",
        name: "TrustChain",
        description: "Immutable Professional Credentials Protocol",
        total-credentials: (var-get last-token-id),
        contract-paused: (var-get contract-paused),
        contract-owner: CONTRACT-OWNER,
    }
)

(define-read-only (validate-credential-data
        (credential-type (string-ascii 50))
        (role-title (string-ascii 100))
        (skills (list 10 (string-ascii 50)))
        (metadata-uri (string-ascii 256))
    )
    (and
        (> (len credential-type) u0)
        (> (len role-title) u0)
        (> (len metadata-uri) u0)
        (<= (len skills) u10)
    )
)

(define-read-only (get-time-until-reset (company principal))
    (match (map-get? authorized-companies { company: company })
        company-info (let ((time-since-reset (- stacks-block-height (get last-reset company-info))))
            (if (>= time-since-reset u4320)
                u0
                (- u4320 time-since-reset)
            )
        )
        u0
    )
)

(define-read-only (is-contract-owner (principal principal))
    (is-eq principal CONTRACT-OWNER)
)

(define-read-only (get-credential-summary (token-id uint))
    (match (map-get? credential-data { token-id: token-id })
        credential-info (ok {
            token-id: token-id,
            credential-type: (get credential-type credential-info),
            role-title: (get role-title credential-info),
            company-name: (get company-name credential-info),
            issue-date: (get issue-date credential-info),
            is-valid: (is-credential-valid token-id),
            is-revoked: (get is-revoked credential-info),
            recipient: (get recipient credential-info),
        })
        ERR-NOT-FOUND
    )
)