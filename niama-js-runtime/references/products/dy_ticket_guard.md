# Douyin / ByteDance Ticket Guard and SecureSDK Reference

This document covers the ByteDance Web Ticket Guard and SecureSDK state chain seen with `bd-ticket-guard-*`, `web_protect`, and related storage. It is a product-identification and evidence workflow reference, not a reusable authentication recipe.

Do not record or deliver real Cookies, private keys, certificates, tickets, server data, or account-specific header values. Every conclusion must be revalidated against the current target's trace, resource version, browser profile, and session scope.

## Product Boundary

Ticket Guard is request-integrity state. It is related to, but distinct from, these components:

- `a_bogus` / bdms request-query signing.
- `msToken` and response-issued session tokens.
- `x-tt-session-dtrait` encrypted session/device material.
- Browser Cookie login state.

One request can carry all of them. A correct value for one component does not validate the others. Do not collapse all failures into an `a_bogus` or TLS hypothesis before checking the full state scope.

## Detection Signals

Read this document when the target has one or more of these signals:

- Request headers `bd-ticket-guard-client-data`, `bd-ticket-guard-ree-public-key`, `bd-ticket-guard-web-version`, `bd-ticket-guard-web-sign-type`, or `bd-ticket-guard-version`.
- Cookies `bd_ticket_guard_client_data`, `bd_ticket_guard_client_data_v2`, `_bd_ticket_crypt_cookie`, `__security_mc_*`, or similarly named Ticket Guard markers.
- Storage keys `security-sdk/s_sdk_crypt_sdk`, `security-sdk/s_sdk_cert_key`, `security-sdk/s_sdk_server_cert_key`, `security-sdk/s_sdk_sign_data_key/web_protect`, `web_secsdk_runtime_cache`, or `web_runtime_security_uid`.
- Scripts or stacks naming `SecureSDK`, `web_protect`, `ticket_guard`, `get_client_cert`, `get_sec_ts`, `startDTrait`, or a SecureSDK request wrapper.
- Login or bootstrap requests under `/passport/ticket_guard/`, `/passport/user_info/get_sec_ts/`, `/passport/token/beat/`, QR confirmation, MFA validation, or another authentication-completion path.

If the same chain contains `a_bogus`, `msToken`, `webmssdk`, `sdk-glue`, or `bdms`, also read `references/products/dy_abgous.md`.

## State Scope

Treat the following as one atomic browser security profile, not as interchangeable files or headers:

```text
Cookie jar
localStorage security-sdk state
sessionStorage session state
browser profile and browser-facing fingerprint state
current dynamic response state
```

The minimum scope checks should be trace-derived, but the following checks are strong recurring candidates:

- The account identifier extracted from Cookie agrees with the profile metadata and a safe read-only identity response when available.
- The guard public key in Cookie agrees with the client certificate/public key in matching security storage.
- `ts_sign` in Cookie guard data agrees with the `web_protect` signing state in matching security storage.
- `webid`, `verifyFp`/`fp`, `uifid`, and the session identifier are from the same browser/session generation.
- The browser family and relevant UA/client-hint state agree with the profile that created the security state.

The same account UID is not enough. A later login, another browser, or a renewed security binding can have the same account UID while using a different guard public key, `ts_sign`, ticket, server certificate, or session state.

## Material Roles

Names and JSON shapes are version-specific. Confirm each role with current Cookie/storage writes and the current SecureSDK source before using it.

```text
bd_ticket_guard_client_data
= usually carries a client public-key or client-certificate marker.

bd_ticket_guard_client_data_v2
= commonly carries guard state such as ts_sign and a sec_ts proof/signature envelope.

security-sdk/s_sdk_crypt_sdk
= observed local key-pair state. The private key is local-only material.

security-sdk/s_sdk_cert_key
= observed client public-key/certificate state.

security-sdk/s_sdk_server_cert_key
= observed server certificate state used by the current guard binding.

security-sdk/s_sdk_sign_data_key/web_protect
= observed request signing state such as ticket and ts_sign.

__tea_session_id_* and related sessionStorage
= browser session context; it is not a substitute for the guard private key.
```

Cookie fields can identify a binding but do not disclose the local private key. A public key, a crypt-cookie marker, or a `ts_sign` value must never be treated as enough information to reconstruct a private key or to fabricate a compatible profile.

## Observed Lifecycle

The following is a trace-backed lifecycle pattern, not a cross-version protocol guarantee:

```text
SecureSDK initialization
-> create or load local key material
-> request client/server certificate material
-> receive sec_ts or equivalent challenge state
-> derive proof from local private key and server certificate
-> persist matching Cookie and security storage state

Protected request
-> select the current path and session context
-> build fresh Ticket Guard request header
-> separately build or attach dtrait and query-signing state when required
-> send request

Authentication completion
-> server may issue new server-data / binding material
-> browser persists the new matching state
```

In the analyzed version, a P-256 ECDH shared secret, HKDF-SHA256, and HMAC proof were observed around `sec_ts`. That observation is usable only after current resource hash and trace evidence confirm the same implementation. Do not assume the curve, KDF, signed string, header JSON shape, or endpoint set is stable across versions.

## Authentication Boundary

Do not label a successful heartbeat or HTTP `200` as a completed security binding. The historical evidence distinguished two cases:

- Certificate and `sec_ts` endpoints can return normal responses without issuing new `bd-ticket-guard-server-data`.
- Token-beat/heartbeat traffic can refresh identity or timestamp state without binding a newly generated key pair.
- New server-data was observed on successful authentication completion, such as confirmed QR login or final verification/MFA completion.

Therefore a new local key pair is only a provisional candidate until the current trace proves a server response has bound it. If the expected binding response is absent, do not write a profile that claims it is initialized.

## Request-Time Rules

- `bd-ticket-guard-client-data` is request-time material, not a long-lived static header.
- The protected path and request timestamp can be inputs to the guard proof. Their exact serialization must come from the current SecureSDK/request-boundary trace.
- `x-tt-session-dtrait` is a separate state product. It can have its own timestamp phase and encryption randomness; do not force it to share the guard timestamp merely because both headers occur on one request.
- `msToken` is dynamic session material. A historical value may be a diagnostic fixture but is not a live-value source.
- A historical `a_bogus`, dtrait envelope, ticket header, `uifid`, or profile field must not be carried into another account, browser binding, or session generation.

## Evidence Workflow

1. Classify the product from Cookie, header, storage, script, and endpoint signals.
2. Inventory current resource URLs and hashes for SecureSDK, async chunks, dtrait code, and request wrappers.
3. Build a request timeline from `http_packet`, `jscall`, Cookie/storage writes, and response transitions.
4. Identify the exact request-boundary injection point for every `bd-ticket-guard-*` header.
5. Map each local storage key to a current trace write/read and record whether it is persistent, session-scoped, or response-issued.
6. Build a redacted profile-consistency report before any stateful validation. Compare account ID, public key, `ts_sign`, web/session identity, and browser profile scope.
7. For any new-binding hypothesis, require a current response that actually delivers the binding material. A setup or heartbeat response alone is insufficient.
8. Validate with a non-destructive, current-session criterion first. Do not infer protected-action success from a public-read response.

Use hashes, lengths, key names, and redacted fingerprints in artifacts. Never put private key PEM, full ticket, Cookie, `msToken`, or full guard headers into logs, `param_info.md`, or reusable skill references.

## Failure Taxonomy

Classify failures before changing a signer or browser environment:

```text
Profile mismatch
= Cookie public key or ts_sign conflicts with local security storage.

Missing binding material
= no local private key, server certificate, ticket/sign state, or server-data for this binding.

Stale dynamic state
= session, webid, msToken, dtrait, or response transition belongs to an earlier generation.

Path-scoped guard mismatch
= the current path requires Ticket Guard or dtrait state not present for this scope.

Independent signer mismatch
= a_bogus/bdms or another request-boundary signer differs after profile consistency is proven.

Authentication or verification gate
= response indicates reauthentication, MFA, CAPTCHA, or another server-side verification stage.
```

HTTP status alone is not a classifier. An empty `200`, a public read success, or a refreshed response token can coexist with an invalid protected-request security profile. Preserve the response body, response headers, Cookie transitions, and an explicit current-state verification criterion before assigning a root cause.

## Common Pitfalls

- Treating a login Cookie as the whole security profile.
- Mixing Cookie from one session with storage or path-scoped headers from another session.
- Treating the same account UID as proof that two browser bindings are interchangeable.
- Copying a historical `bd-ticket-guard-client-data` or `x-tt-session-dtrait` into a new request.
- Generating a fresh key pair and treating `get_sec_ts` or token-beat success as proof of server binding.
- Conflating `a_bogus`, dtrait, TLS persona, and Ticket Guard into one parameter problem.
- Declaring success because a request returns HTTP `200` without checking the correct response/state criterion.
- Logging raw private keys, tickets, certificates, Cookies, or full header values in analysis artifacts.
- Letting a profile registry silently fall back to another account's storage.

## Delivery Boundary

A reusable runtime may support an already registered profile by matching current Cookie identity, guard public key, and `ts_sign` to the locally saved profile. It must reject a mismatch before request construction.

For a new browser binding, the runtime must require either matching imported storage or a current, completed authentication flow that yields server-side binding material. Do not present a Cookie-only lookup as silent private-key recovery or new-binding creation.

This document does not authorize reuse of credentials or protected requests. It only defines how to identify, scope, and verify the Ticket Guard security product from current authorized evidence.
