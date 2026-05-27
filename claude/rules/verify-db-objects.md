# Verify Database Objects Before Writing SQL

**CRITICAL:** Before writing any backend code that references a PostgreSQL function, enum value, column, or table — verify it exists in the actual database first. Do NOT assume naming conventions.

## Mandatory checks before writing SQL:

1. **Functions**: Query `pg_proc` to confirm the exact function name
2. **Enum values**: Query `pg_enum` to confirm all valid values before INSERT
3. **Columns**: Query `information_schema.columns` before SELECT/INSERT with new columns
4. **After ALTER TABLE**: Verify the migration ran on BOTH staging and production

## Quick verification queries

```sql
-- Function exists?
SELECT proname, pronargs FROM pg_proc WHERE proname = 'your_function_name';

-- Valid enum values?
SELECT enumlabel FROM pg_enum e
JOIN pg_type t ON e.enumtypid = t.oid
WHERE t.typname = 'your_enum_type'
ORDER BY e.enumsortorder;

-- Column exists?
SELECT column_name, data_type FROM information_schema.columns
WHERE table_name = 'your_table' AND column_name = 'your_column';
```

## When DB is unavailable

If your database proxy / connection is down:
- Check migration files and schema.sql for the object definition
- Add a comment: `# TODO: Verify DB object exists — could not check live DB`
- Use savepoints (`conn.begin_nested()`) around fallible DB calls so failures don't poison transactions

## Example of what NOT to do:

```python
# BAD — assumed function name without checking
result = conn.execute(text("SELECT generate_invoice_number_v2()"))
# Actual function name is generate_invoice_number()
# This fails and poisons the entire transaction.

# BAD — assumed enum value exists
conn.execute(text("INSERT INTO invoices (invoice_type) VALUES ('client_invoice')"))
# invoice_type enum only had 3 values, not 4.
# Need: ALTER TYPE invoice_type ADD VALUE 'client_invoice' FIRST.
```

## Why this matters

In SQLAlchemy + PostgreSQL, a single failed query inside a transaction puts the connection into `InFailedSqlTransaction` state. Every subsequent query on that connection fails until rollback — including queries that have nothing to do with the original bug. A misnamed function in a logging call can take out a whole request handler.

Verify before you write. It's cheaper than debugging a "mystery 500" two hours later.
