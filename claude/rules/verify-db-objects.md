# Verify Database Objects Before Writing SQL

**CRITICAL:** Before writing any backend code that references a PostgreSQL function, enum value, column, or table — verify it exists in the actual database first. Do NOT assume naming conventions.

## Mandatory checks before writing SQL:

1. **Functions**: Query `pg_proc` to confirm the exact function name
2. **Enum values**: Query `pg_enum` to confirm all valid values before INSERT
3. **Columns**: Query `information_schema.columns` before SELECT/INSERT with new columns
4. **After ALTER TABLE**: Verify the migration ran on BOTH staging and production

## When DB is unavailable:

If Cloud SQL proxy is down or gcloud auth expired:
- Check migration files and schema.sql for the object definition
- Add a comment: `# TODO: Verify DB object exists — could not check live DB`
- Use savepoints (`conn.begin_nested()`) around fallible DB calls so failures don't poison transactions

## Example of what NOT to do:

```python
# BAD — assumed function name without checking
result = conn.execute(text("SELECT generate_docs_invoice_number()"))
# Actual function name is generate_invoice_number()
# This fails and poisons the entire transaction
```

```python
# BAD — assumed enum value exists
INSERT INTO docs_invoices (invoice_type) VALUES ('client_invoice')
# invoice_type enum only had 3 values, not 4
# Need ALTER TYPE invoice_type ADD VALUE 'client_invoice' first
```
