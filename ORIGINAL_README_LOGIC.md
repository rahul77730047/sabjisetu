# SabziSetu - Business Logic & Data Rules

## Inventory
- Purchases increase stock and recalculate average cost.
- Sales require sufficient stock and reduce stock atomically.
- Sale COGS is recorded from the stock average cost at sale time.
- Deleting a sale restores its quantity to stock.

## Customer / Due
- Every sale creates or updates a customer record.
- Customer mobile number is stored in `customers.phone`.
- A sale can save/update the customer's mobile number.
- Payments reduce outstanding due; payment cannot exceed current due.
- Changing a sale between Due/Paid recalculates the customer's due.
- Customer contact editing is available from Customers and Payments & Due.

## Reports
- Date-wise and monthly views use real database dates.
- Demand = quantity sold.
- Gross profit by sabji = sales revenue - recorded COGS.
- Purchase recommendations use demand velocity + current stock coverage + margin.
- Recommendations target approximately 7 days of demand.

## WhatsApp
- Payment/Due page has a WhatsApp reminder button.
- Customer mobile is normalized to an Indian WhatsApp number when a 10-digit number is entered.
- Reminder text includes customer name, business name and current due.
- A WhatsApp bill record is saved when a reminder is sent.

## Important
Use the same PostgreSQL database configured in `server/.env` (normally `sabzisetu_new`). Run `server/schema.sql` only for a new database or as a safe upgrade; it does not delete existing data.


## Latest dashboard and stock status
- Dashboard distinguishes today from recent history; zero today is shown as zero when there were no transactions today.
- Dashboard also shows last 7 days, recent sales, stock alerts, current due, and operating costs.
- Stock status is user-entered and stored in PostgreSQL; it is no longer derived from a hardcoded quantity threshold.
- Stock status can be edited after creation.

- Existing databases are automatically upgraded at server startup with stock.status and customers.phone if those columns are missing.
