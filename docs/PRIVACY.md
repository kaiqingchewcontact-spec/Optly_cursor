# Privacy policy outline (Optly)

> **Note:** This is a structural outline for legal and product review, not final legal text. Counsel should adapt jurisdiction-specific language before publication.

## 1. Who we are

Identify the data controller, contact email, and DPO or privacy contact if applicable.

## 2. Data we collect

- **Account data:** Email, name, authentication identifiers, subscription tier, app preferences.
- **Usage and product data:** Habits, focus sessions, insight interactions, in-app settings.
- **Financial signals:** Aggregates and categories derived from linked accounts or manual entry (not full bank credentials stored on our servers).
- **Health and activity:** Daily summaries you choose to sync (for example steps, sleep duration, active energy), not continuous raw sensor streams unless explicitly enabled.
- **Device data:** OS version, app version, coarse diagnostics for crashes (if crash reporting is enabled).

## 3. On-device processing

Optly emphasizes **on-device processing** where feasible: ranking, lightweight recommendations, and UI assistance may run entirely on the phone without leaving the device. When cloud processing is used, we aim to send **minimized** payloads necessary for the feature.

## 4. Third-party integrations

- **Plaid (or similar):** Used only after explicit linking; governed by their terms and your bank’s policies. We do not store online banking passwords.
- **Health APIs (HealthKit, Health Connect):** Access is **opt-in** and scoped to types you approve. You can revoke access in system settings at any time.
- **AI providers:** When cloud models generate briefings or insights, prompts exclude secrets and are scoped to allowed fields. Retention of prompts/completions should follow the data retention section.

## 5. Purposes and legal bases (GDPR framing)

- Provide and improve the service (contract / legitimate interest).
- Security, fraud prevention, and abuse detection (legitimate interest).
- Marketing only with consent where required.

## 6. Data retention

- **Account:** Until deletion, plus short backup latency.
- **Derived AI artifacts (briefings, insights):** Rolling retention (for example 90 days) unless a shorter or longer period is required for the product; document actual windows.
- **Logs:** Minimal retention for security auditing.
- **Health and finance aggregates:** Configurable deletion with account deletion.

## 7. User rights

Users should be able to:

- **Access** a copy of their data (export).
- **Correct** inaccurate profile or preference data.
- **Delete** their account and associated personal data, subject to legal holds.
- **Withdraw consent** for optional processing (marketing, certain sync features).
- **Port** data in a machine-readable format where applicable.

## 8. GDPR / CCPA notes

- **GDPR:** Lawful basis table, data processing agreements with subprocessors, EU representative if required, 72-hour breach notification process, DPIA for high-risk processing (health + finance).
- **CCPA/CPRA:** Categories of personal information collected, “Do Not Sell or Share” stance, sensitive personal information limits, non-discrimination for exercising rights.

## 9. International transfers

If data leaves the EEA/UK, describe Standard Contractual Clauses or equivalent safeguards.

## 10. Children’s privacy

The service is not directed at children under 13 (or local age of digital consent); no knowing collection from minors.

## 11. Changes

How users are notified of material privacy policy updates (in-app notice, email if required).

## 12. Contact

Privacy email and postal address for requests.
