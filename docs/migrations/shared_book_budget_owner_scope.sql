-- Pre-launch migration helper (optional):
-- Goal: for multi-member server books (book.is_multi=1), ensure there is exactly one budget row per book,
-- owned by book.owner_id (since budget is treated as book-scoped).
--
-- If you have no existing data (not launched), you can skip this entirely.
--
-- Safety notes:
-- - This script chooses the most recently updated budget among existing rows for the book.
-- - It then upserts that budget into the owner's (user_id, book_id) row.
-- - Finally it deletes non-owner budget rows for that multi book.

START TRANSACTION;

-- 1) Upsert "latest" budget into owner's row for each multi book.
INSERT INTO budget_info (
  user_id, book_id,
  total, category_budgets, period_start_day,
  annual_total, annual_category_budgets,
  sync_version, update_time, created_at
)
SELECT
  b.owner_id AS user_id,
  bi.book_id,
  bi.total, bi.category_budgets, bi.period_start_day,
  bi.annual_total, bi.annual_category_budgets,
  bi.sync_version, bi.update_time, bi.created_at
FROM book b
JOIN (
  SELECT bi1.*
  FROM budget_info bi1
  JOIN (
    SELECT book_id, MAX(update_time) AS max_ut
    FROM budget_info
    GROUP BY book_id
  ) latest ON latest.book_id = bi1.book_id AND latest.max_ut = bi1.update_time
) bi ON bi.book_id = CAST(b.id AS CHAR)
WHERE b.is_multi = 1
  AND b.owner_id IS NOT NULL
ON DUPLICATE KEY UPDATE
  total = VALUES(total),
  category_budgets = VALUES(category_budgets),
  period_start_day = VALUES(period_start_day),
  annual_total = VALUES(annual_total),
  annual_category_budgets = VALUES(annual_category_budgets),
  sync_version = VALUES(sync_version),
  update_time = VALUES(update_time);

-- 2) Delete non-owner budget rows for multi books.
DELETE bi
FROM budget_info bi
JOIN book b ON bi.book_id = CAST(b.id AS CHAR)
WHERE b.is_multi = 1
  AND b.owner_id IS NOT NULL
  AND bi.user_id <> b.owner_id;

COMMIT;

