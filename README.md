# 📜 TrustChain – Immutable Professional Credentials Protocol

**Version:** 1.0.0
**Contract Language:** Clarity
**Blockchain:** Bitcoin (via Stacks Layer 2)
**Standard Implemented:** SIP-009 (Non-Fungible Tokens)

---

## 🧩 Overview

**TrustChain** is an enterprise-grade smart contract protocol that issues **tamper-proof, non-transferable professional credentials** as NFTs. Anchored on **Bitcoin's finality and security** via the **Stacks blockchain**, TrustChain allows organizations to mint **verifiable credentials** that encapsulate job roles, employment history, and demonstrated skills. These digital credentials are immutable, auditable, and **follow professionals across their career**, forming a trustless, cryptographic career portfolio.

---

## 🛠️ Core Features

* 🔐 **Soulbound SIP-009 NFTs**: Credentials are issued as non-transferable NFTs, ensuring integrity and ownership by the recipient only.
* 🏢 **Authorized Issuers**: Only registered and approved companies can issue credentials within assigned monthly limits.
* 🧾 **Credential Metadata**: Structured storage of credential type, role title, company name, skills, issue/expiry dates, and URI to metadata.
* 🔁 **Rate Limiting**: Per-company monthly issuance limits enforced at protocol level.
* ❌ **Revocation with Audit Trail**: Credentials can be revoked by issuer or admin with reason, date, and identity logged on-chain.
* 📉 **Expiration Support**: Optional expiry dates ensure credentials become invalid after a defined period.
* 🛑 **Global Pause Control**: Protocol can be paused or resumed by the contract owner in emergencies.

---

## 🏗️ System Architecture

### 📌 Blockchain Stack

```
┌──────────────────────────────────────┐
│            Bitcoin Layer 1          │
│        (Final settlement layer)     │
└──────────────────────────────────────┘
            ▲
            │
            ▼
┌──────────────────────────────────────┐
│          Stacks Layer 2             │
│  Smart contracts & execution layer  │
│    Clarity + SIP-009 NFT standard   │
└──────────────────────────────────────┘
            ▲
            │
            ▼
┌──────────────────────────────────────┐
│         TrustChain Protocol         │
│ Credential logic, revocation, auth  │
│ NFT issuance, audit logs, registry  │
└──────────────────────────────────────┘
```

---

## ⚙️ Contract Architecture

### 📄 Tokens

* `trustchain-credential`: A non-fungible token defined using SIP-009.
* **Soulbound**: Transfer function is disabled; credentials are permanently tied to the recipient.

### 📊 State Variables

* `last-token-id`: Tracks the last minted credential ID.
* `contract-paused`: Emergency toggle for disabling protocol operations.

### 🗂️ Data Maps

* `credential-data`: Stores metadata and ownership of each credential.
* `authorized-companies`: Tracks registration status, rate limits, and usage of issuer organizations.
* `employee-credentials`: Tracks how many credentials each employee holds.
* `revocation-data`: Stores revocation audit details for credentials.

---

## 🔁 Data Flow

### 🏢 Company Registration

1. A company calls `register-company`.
2. System records company metadata, assigns monthly issuance limits.
3. Company becomes eligible to issue credentials.

### 🎓 Credential Issuance

1. Company invokes `issue-credential`, passing metadata and recipient.
2. Protocol validates issuer status, rate limits, data correctness.
3. Credential NFT is minted and stored with metadata.
4. Counters are updated for issuer and employee.

### ❌ Revocation

1. Issuer or admin calls `revoke-credential` or `admin-revoke-credential`.
2. Credential is marked as revoked.
3. `revocation-data` is recorded with date, reason, and revoker identity.

---

## 📘 Key Public Functions

| Function                       | Description                                               |
| ------------------------------ | --------------------------------------------------------- |
| `register-company`             | Register a company with a name and credential mint limit. |
| `issue-credential`             | Mint a credential NFT to a recipient.                     |
| `revoke-credential`            | Issuer revokes an issued credential.                      |
| `admin-revoke-credential`      | Admin (contract owner) forcibly revokes any credential.   |
| `get-credential-info`          | Returns full credential data by ID.                       |
| `is-credential-valid`          | Checks if a credential is valid (not expired or revoked). |
| `get-credentials-by-recipient` | Returns metadata about credentials held by a user.        |
| `get-company-info`             | Retrieves issuer company metadata.                        |
| `batch-verify-credentials`     | Validates multiple credentials in a single call.          |

---

## 🔐 Access Control

| Role                     | Permissions                                                  |
| ------------------------ | ------------------------------------------------------------ |
| **Contract Owner**       | Pause/resume protocol, revoke credentials, update companies. |
| **Authorized Companies** | Issue credentials, revoke credentials they issued.           |
| **General Users**        | View and verify credentials. Cannot transfer them.           |

---

## 🧪 Validation Logic

* All inputs are validated for:

  * Minimum length constraints.
  * Expiry date logic.
  * Company authorization and rate limits.
* Credential issuance is halted if:

  * Monthly usage exceeds company quota.
  * Contract is paused.
  * Credential metadata is incomplete.

---

## 📊 Utilities & Queries

* `get-contract-info`: Returns metadata and current contract status.
* `get-revocation-info`: Provides audit trail of revocations.
* `get-company-stats`: Returns current rate usage, next reset.
* `get-time-until-reset`: How many blocks until monthly reset.
* `get-credential-summary`: Quick-view credential snapshot.

---

## 🧱 Smart Contract Integrity

* Written in **Clarity**, offering:

  * **No runtime surprises** (decidable language).
  * **On-chain auditability**.
  * Strong **type and logic safety**.
* Anchored to Bitcoin via Stacks, ensuring finality and immutability.

---

## 📦 Deployment Notes

* Ensure proper administrative controls via `CONTRACT-OWNER`.
* Initial deployment requires `set-contract-paused(false)` to begin operations.
* Company registration is required before issuing any credentials.

---

## ✅ Future Enhancements (Potential)

* Multi-language metadata support.
* Off-chain metadata gateway validation.
* Credential endorsement system.
* ZK-proof integration for privacy-preserving credential verification.

---

## 📄 License

This smart contract is licensed under [MIT License](https://opensource.org/licenses/MIT).

---

## 🤝 Contributing

If you're a Clarity or Stacks developer interested in contributing, feel free to fork and open a pull request. Security audits and review feedback are welcome.

---

## 📬 Contact

For enterprise integrations, protocol extensions, or audits, reach out via the Stacks developer community or open an issue on the project repository.
