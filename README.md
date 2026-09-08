# American Roadhouse Hotel & Restaurant — Website

A production-ready, responsive multi-page website for American Roadhouse Hotel
and Restaurant (Guindulman, Bohol). Built as static HTML/CSS/vanilla JS so it
runs anywhere with no build step, no dependencies, and no server required.

## Why static HTML instead of Next.js/TypeScript/Tailwind

The original brief asked for a Next.js + TypeScript + Tailwind + shadcn/ui
stack. This build environment has no internet access, so `npm install` for
Next.js, Tailwind, and shadcn cannot run here. Rather than hand you an
uninstallable project, this delivers the **same design system, structure,
and functionality** as plain, dependency-free HTML/CSS/JS that opens and
works immediately in any browser or static host (Netlify, Vercel, GitHub
Pages, cPanel, etc.). It also ports cleanly to Next.js later — the page
sections, copy, and data model map directly to React components and routes
if/when you want to rebuild it in that stack.

## Structure

```
american-roadhouse/
├── index.html          Home
├── rooms.html           Rooms
├── restaurant.html      Restaurant
├── menu.html            Menu (with category tabs)
├── gallery.html         Gallery (filters + lightbox)
├── about.html           About
├── location.html        Location + embedded map
├── contact.html         Contact form
├── booking.html         Booking / reservation inquiry form
├── robots.txt
├── sitemap.xml
└── assets/
    ├── css/style.css    Design system: colors, type, components, responsive
    └── js/
        ├── data.js      ALL editable content lives here (rooms, menu, gallery, reviews, FAQs)
        └── main.js       Nav, mobile menu, reveal animation, form validation, helpers
```

## Editing content

Everything a client needs to update lives in **`assets/js/data.js`**:
room names/prices/amenities, menu items, gallery photos, reviews, and FAQs.
Nothing is hardcoded inside the HTML pages — edit that one file and the
change appears everywhere it's used (home page previews included).

## Replacing placeholder photography

Every image on the site is currently a labelled placeholder tile (a soft
tan gradient with a caption like "Room photo placeholder") — no stock
photography was substituted, per the brief. To add real photos:

1. Put image files in `assets/img/` (e.g. `assets/img/rooms/room-1.jpg`).
2. In `assets/js/data.js`, change the `img`/`label` value for that item to
   the file path.
3. In each HTML file, swap the corresponding `phTile(...)` call or
   `<div class="ph" data-label="...">` element for a real `<img>` tag.

The hero and section background photos (marked "photo placeholder" directly
in the HTML) can be swapped the same way — replace the `.ph` placeholder div
with an `<img>` or CSS `background-image`.

## Content still marked "confirm before publishing"

Per the brief, nothing was invented. These are placeholders you should
confirm with the business before launch:
- Room names, rates, and amenities (`assets/js/data.js` → `ROOMS`)
- Menu item names, descriptions, and prices (`MENU_ITEMS`)
- Guest reviews — the 4.6/5 rating and 40-review count are real (from the
  supplied reference); the review *text* in `TESTIMONIALS` is placeholder
  and marked as such in the UI
- FAQ answers for check-in/out times and walk-in policy
- Facebook/Instagram links in the footer (currently `#`)

## Running it

No build step. Open `index.html` directly in a browser, or serve the folder
with any static server, e.g.:

```
npx serve .
# or
python3 -m http.server 8080
```

## Notes on functionality

- Booking and contact forms validate client-side and show a confirmation
  state — no data is actually transmitted yet. Wire the `fetch()` call in
  the form submit handlers (`booking.html`, `contact.html`) to your backend,
  form service (e.g. Formspree), or CMS when ready.
- The homepage "Check Availability" widget passes dates/guests to the
  booking page as URL parameters, which pre-fill the booking form.
- The Google Maps embed uses the address as a query string, so it works
  without an API key; swap in a `place_id`-based embed later for more
  precision if desired.
