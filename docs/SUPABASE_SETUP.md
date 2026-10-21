# Online ordering: Supabase setup

The site stays static. Customers use `order.html`; staff use `<random-name>.html`. All data lives in Supabase and is protected by Row Level Security (RLS).

## 1. Create the project and run the schema

1. Create a project at supabase.com.
2. SQL Editor → run `supabase/migrations/0001_ordering.sql` (once, on a fresh project).
2b. Run `supabase/migrations/0002_inquiries.sql` too. It adds the `inquiries` table so booking, table-reservation and contact forms also appear in the staff dashboard's **Inquiries** tab (the email via the form service still goes out as before). Visitors can only submit through `submit_inquiry()`; only staff can read them.
2c. Run `supabase/migrations/0003_menu_images.sql`. It creates the public `menu-images` storage bucket so staff can upload photos for menu items and rooms from the dashboard (JPG, PNG or WebP, resized in the browser, 3 MB cap). Only active staff can add, replace or remove files.
3. Then run `supabase/seed.sql` for the starter categories, priced menu items and room rates taken from the current site. Items that are "ask for today's price" are not seeded; add them in the dashboard.

Or with the CLI: `supabase link --project-ref <ref>` then `supabase db push`.

## 2. Authentication

- **Authentication → Sign In / Providers → Allow anonymous sign-ins: ON.** Guest customers get an anonymous session, which is how "customers can only view their own orders" works without forcing accounts.
- Email provider ON. Turn **Allow new users to sign up OFF** if you only want staff accounts created by you (anonymous sign-ins still work).
- Recommended: enable CAPTCHA (Authentication → Attack Protection) to limit anonymous-sign-in spam. The database also blocks a user from holding more than 5 pending orders.

## 3. Employees and administrators

Roles live in `public.profiles`. A user with no profile row is just a customer.

1. Authentication → Users → **Add user** for each staff member (email + password).
2. Make the **first administrator** in the SQL Editor:

```sql
insert into public.profiles (id, email, role)
select id, email, 'admin' from auth.users where email = 'owner@example.com';
```

3. After that, administrators manage staff in the dashboard's **Staff** tab:
   - **Add a staff member:** enter an email, a temporary password (10+ characters with letters and numbers; **Generate** makes a strong one) and a role. The account is created and confirmed instantly.
   - **Reset password:** sets a new password for any staff account.
   - **Disable / Enable:** turns staff access off or on (it cannot be used to demote yourself).

   Creating users and setting passwords needs Supabase's privileged Auth API, so it runs in the Edge Function `supabase/functions/admin-staff`. The function checks that the caller is an active administrator, and the service-role key stays inside Supabase (it is injected into the function and never appears in this repo or the website). Deploy it with `supabase functions deploy admin-staff`.

| Capability | Employee | Administrator |
|---|---|---|
| View and update order status | yes | yes |
| Add / edit / delete / hide / mark unavailable menu items, edit food prices, manage categories | yes | yes |
| Reopen a completed or cancelled order | no | yes |
| Room rates, add-ons, discounts (including prices) | view only | full |
| Price history (audit trail) | view | view |
| Manage staff | no | yes |

## 4. Environment variables

The frontend needs only the public project URL and the **anon/publishable** key (Project Settings → API).

```sh
cp .env.example .env        # fill in SUPABASE_URL and SUPABASE_ANON_KEY
node scripts/build-env.mjs  # writes assets/js/env.js (gitignored)
```

For deployment, set the same two variables in your host (for example Cloudflare) and run `node scripts/build-env.mjs` as the build command so `assets/js/env.js` is generated at deploy time.

**Never use the `service_role` / secret key in the frontend.** The build script refuses to run if it detects one. It is not needed: all privileged logic is in RLS policies and `SECURITY DEFINER` functions.

## 5. How security works

- **Prices can't be tampered with.** Customers have no INSERT permission on `orders`/`order_items`. They call `place_order()`, which recomputes every price from the live menu, rejects hidden/unavailable items, applies discount codes server-side, and validates all input.
- **Customers see only their own orders** (`orders.user_id = auth.uid()`); staff see all. Discount codes are unreadable by customers.
- **Only staff can update orders** and only the `status` and `staff_notes` columns.
- **Prices must be > 0 and ≤ 1,000,000** (CHECK constraints), percent discounts ≤ 100. The dashboard validates first, the database is the final guard.
- **Audit trail:** triggers write every price create/change (menu, rooms, add-ons, discounts) to `price_history` with the user's email and time. The table is append-only for clients.
- **Realtime** is on for orders, menu items, categories, room rates and add-ons. Staff receive new orders instantly; customers' menu and confirmation pages update live. RLS applies to realtime too.

## 6. Local testing

```sh
node scripts/build-env.mjs
python -m http.server 8080      # ES modules need http://, not file://
```

1. Open `http://localhost:8080/order.html`, add items, check out. A confirmation with an order number appears.
2. In another window open `http://localhost:8080/<random-name>.html`, sign in as staff. The order appears live; change its status and watch the customer's confirmation update.
3. Edit a price in **Menu**; the customer page refreshes within a moment. Check **Price history**.
4. Negative-path checks: enter `-5` or `0` as a price (rejected), sign in as an employee and confirm Room rates/Discounts are view-only, and from the browser console confirm a customer cannot `insert` into `orders` or `update` prices.

## Notes and limits

- Customers' name and phone are stored for fulfilment; publish a privacy notice (see README).
- Payment is collected by staff on receipt; there is no online payment.
- Photos are uploaded from the dashboard into the `menu-images` bucket. The original site photos still live under `assets/food` and keep working.
- Hidden-item changes reach customers by realtime plus a 60-second/focus refresh, and checkout always re-validates on the server.

## Staff page address

The dashboard is deliberately not at `/staff.html`. It is a randomly named file in the project root (`<random-name>.html`), reached by clicking the © symbol in any page footer. Keep the real name private and out of this repository's public docs. This only hides the page; the real protection is the login plus the database security policies. To change the address, rename the file and update the `href` on the © link in each page's footer.
