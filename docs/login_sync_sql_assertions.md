# Login First Sync SQL Assertions

This checklist defines the minimal expected SQL during the first login sync
for a new account. Use it as a log-based regression guard to prevent re-
introducing duplicate or unnecessary queries.

## Scope
- Scenario: new user registers and logs in
- Book: default-book (or first active book)
- Time window: within 60 seconds after login success
- Server log level: DEBUG

## Categories
- Expected: at most 1 of the following chains
  - upload-only: `uploadCategories` returns categories; no prior download
  - download-only: `findAllByUserId` once
- Forbidden:
  - `findAllByUserId` -> `findByUserIdAndKeys` -> `batchInsert` -> `findAllByUserId`
  - two consecutive `findAllByUserId` within the same login window

## Tags
- Expected: `findAllByUserIdAndBookId` at most 1 time
- Forbidden: duplicate `findAllByUserIdAndBookId` in the same window

## Budget
- Expected: `findByUserIdAndBookId` at most 1 time
- Forbidden: duplicate `findByUserIdAndBookId`

## Accounts
- Expected:
  - `findAllByUserIdAndBookId` at most 1 time
  - optional: single insert for default wallet if none exist
- Forbidden:
  - `findByUserIdAndBookIdAndAccountId` immediately after a full find
  - multiple inserts for default wallet

## Savings Plans
- Expected: `findAllByUserIdAndBookId` at most 1 time
- Forbidden: duplicate `findAllByUserIdAndBookId`

## SyncV2
- Expected:
  - 1 `pull` (app_start)
  - 1 `summary` (summary_check)
- Forbidden:
  - repeated `pull` in the same login window
  - repeated `summary` in the same login window

## Manual Verification Steps
1) Clear DB or use a new test user.
2) Register and login.
3) Capture server log for 60 seconds.
4) Compare against the above rules.

