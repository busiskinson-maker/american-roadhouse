# American Roadhouse Hotel & Restaurant

Responsive static website for American Roadhouse in Guindulman, Bohol. It uses HTML, CSS, and vanilla JavaScript; there is no build step or package installation.

## Pages

- `index.html` — home and quick booking inquiry
- `rooms.html` — room types and rates
- `restaurant.html` and `menu.html` — dining and menu
- `gallery.html` — photo gallery and lightbox
- `about.html` and `location.html` — business information and directions
- `contact.html` — room, table, and general inquiry forms
- `booking.html` — standalone booking inquiry page

## Main files

- `assets/css/style.css` — current design system and responsive styles
- `assets/js/main.js` — navigation, gallery, form validation, and Web3Forms submission
- `assets/js/data.js` — legacy content data; the current pages render their content directly in HTML
- `style.css` and `main.js` at the project root — legacy copies; current pages load the files under `assets/`

## Run locally

Open `index.html` in a browser, or serve the folder with a static web server, for example:

```sh
python -m http.server 8080
```

## Before publishing

- Set the production domain in `robots.txt`, `sitemap.xml`, canonical URLs, and Open Graph image URLs. The current repository remote identifies the source code, not the deployed site domain.
- Confirm room names, rates, included services, taxes, menu details, operating hours, and all business claims with the owner.
- Confirm the Web3Forms access key is enabled for the production domain and that messages reach the intended inbox. Inquiry forms send names, contact details, and booking or message details to that service.
- Publish a privacy notice explaining what information the forms collect and how inquiries are handled.
- Replace duplicate, oversized images with optimized variants for faster mobile loading.

The booking form collects inquiry details; it does not check live room availability or confirm a reservation automatically.
