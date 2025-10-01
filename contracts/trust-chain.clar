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