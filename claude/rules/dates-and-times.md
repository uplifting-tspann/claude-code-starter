# Date & Time Handling — Local Time Convention

All dates and times in this project are treated as **local time**, not UTC. Most users operate in a single timezone (or one they expect to see consistently) and expect dates to match their wall clock. UTC storage causes off-by-one day errors when YYYY-MM-DD strings are parsed as UTC midnight.

> If your project is intentionally UTC-everywhere (e.g., a multi-region service with no single user timezone), invert this rule. The risk pattern is the same — pick one convention and enforce it.

## The Core Problem

`new Date('2026-04-01')` in JavaScript parses as **UTC midnight**, which becomes `2026-03-31 7:00 PM` in US Eastern — shifting the displayed date back one day. This is the single most common date bug in user-facing apps.

---

## Frontend Rules (TypeScript/React)

### NEVER use `new Date(dateString)` for date-only strings

```typescript
// ❌ WRONG — parses as UTC midnight, shifts date in non-UTC timezones
new Date('2026-04-01')
new Date(record.effective_date)
new Date(dateString).toLocaleDateString(...)

// ✅ CORRECT — use parseLocalDate or date-fns parse()
parseLocalDate('2026-04-01')                    // from your project's utils
parse(dateString, 'yyyy-MM-dd', new Date())     // from date-fns
```

### Use shared utility functions

Each frontend app should expose:

- `formatDate(date)` — formats as "Apr 1, 2026" (uses parseLocalDate internally)
- `formatDateTime(date)` — formats as "Apr 1, 2026, 3:45 PM"
- Both handle YYYY-MM-DD strings safely
- Date picker components should use `date-fns` `parse(value, 'yyyy-MM-dd', new Date())` which treats input as local

### When `new Date()` IS acceptable
- `new Date()` with no arguments (current time) — OK
- `new Date(year, month, day)` constructor — OK (always local)
- `new Date(isoStringWithTime)` for full ISO timestamps with timezone — OK
- `new Date().getFullYear()` for copyright year — OK
- Sorting by `.getTime()` on full timestamps (created_at with time component) — OK

### When you MUST use parseLocalDate or equivalent
- Any YYYY-MM-DD string from the backend (effective_date, expiration_date, start_date, end_date, deadline)
- Any DATE column value displayed to the user
- Any date comparison for filtering or validation

### Pattern for inline date display

```typescript
// ❌ WRONG
<span>{new Date(record.effective_date).toLocaleDateString()}</span>

// ✅ CORRECT — import formatDate from your shared utils
import { formatDate } from '../lib/utils';
<span>{formatDate(record.effective_date)}</span>
```

### Every frontend app must have parseLocalDate

If a frontend app doesn't have `parseLocalDate` in its utils, add it:

```typescript
export function parseLocalDate(date: string | Date): Date {
  if (date instanceof Date) return date;
  if (/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    const [y, m, d] = date.split('-').map(Number);
    return new Date(y, m - 1, d);
  }
  return new Date(date);
}
```

---

## Backend Rules (Python/Flask)

### Timestamps for audit fields (created_at, updated_at)

Use database server time via `CURRENT_TIMESTAMP` or `NOW()` in SQL — these respect the PostgreSQL `timezone` setting. Do NOT generate timestamps in Python and pass them to SQL.

```python
# ✅ CORRECT — let the database handle timestamps
conn.execute(text("INSERT INTO ... (created_at) VALUES (CURRENT_TIMESTAMP)"))
conn.execute(text("UPDATE ... SET updated_at = NOW()"))

# ❌ WRONG — Python-generated UTC timestamps
conn.execute(text("UPDATE ... SET updated_at = :now"), {"now": datetime.utcnow()})
```

### When Python timestamps are needed (logging, external APIs)

```python
# ✅ CORRECT — aware local time
from datetime import datetime, timezone
now = datetime.now()  # local server time (for display/logging)

# ✅ ALSO CORRECT — when UTC is explicitly required (external APIs, iCal, etc.)
now_utc = datetime.now(timezone.utc)  # aware UTC — use ONLY for external protocols

# ❌ WRONG — naive UTC (deprecated in Python 3.12+)
datetime.utcnow()  # Never use this
```

### Date-only fields (effective_date, expiration_date, start_date, end_date)

These are business dates that mean "this calendar date" regardless of timezone. Store as `DATE` type, return as `YYYY-MM-DD` string, never attach time or timezone.

```python
# ✅ CORRECT — return date-only strings
result['effective_date'] = row['effective_date'].isoformat()  # "2026-04-01"

# ❌ WRONG — converting to datetime adds UTC timezone confusion
result['effective_date'] = datetime.combine(row['effective_date'], time.min).isoformat()
```

### Date comparison for validation

```python
from datetime import date

# ✅ CORRECT — compare date to date
today = date.today()  # local server date
if start_date < today:
    return error("Start date cannot be in the past")

# ❌ WRONG — comparing date to UTC datetime
if start_date < datetime.utcnow().date():  # Off by one near midnight
    return error(...)
```

---

## Database Rules (PostgreSQL)

### Column types
- **Audit timestamps** (created_at, updated_at, signed_at): Use `TIMESTAMP WITH TIME ZONE` with default `CURRENT_TIMESTAMP`
- **Business dates** (effective_date, expiration_date, start_date, end_date): Use `DATE` type — no time component, no timezone

### Default values
```sql
-- ✅ CORRECT
created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
-- The server's timezone setting determines what "now" means

-- ❌ WRONG — don't set UTC explicitly in column defaults
created_at TIMESTAMP DEFAULT (NOW() AT TIME ZONE 'UTC')
```

---

## Checklist for Any Date-Related Change

- [ ] No `new Date('YYYY-MM-DD')` in frontend code — use parseLocalDate/formatDate
- [ ] No `datetime.utcnow()` in backend code — use `datetime.now()` or `date.today()`
- [ ] Date-only fields stored as `DATE`, returned as `YYYY-MM-DD`, displayed via formatDate
- [ ] Timestamps use `CURRENT_TIMESTAMP` in SQL, not Python-generated values
- [ ] Date comparisons use `date.today()` not `datetime.utcnow().date()`
