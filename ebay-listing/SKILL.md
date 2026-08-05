---
name: ebay-listing
description: Create eBay listings end-to-end by driving the user's browser — research pricing, download photos, fill the listing form, set shipping, and publish. Use when the user wants to list anything for sale on eBay, revise existing eBay listings, or asks about eBay selling mechanics (shipping setup, item specifics, pricing from sold comps). Encodes hard-won workarounds for eBay's form quirks and the Claude-in-Chrome extension.
---

# Listing items on eBay

Drive the user's real browser via `mcp__claude-in-chrome__*` to build and publish eBay listings. This file encodes the exact sequence and the traps that waste the most time.

## Before you start

1. **Load the browser tools in ONE ToolSearch call**, including `browser_batch`, `file_upload`, `find`, `form_input`, `javascript_tool`.
2. **The user must be signed into eBay themselves.** You cannot type their password. Check by loading any eBay page and looking for "Sign in" in the header — if present, stop and ask them to sign in.
3. **Photos must be real files on disk.** eBay's uploader needs a path. If the user has photos elsewhere (Google Photos, phone), see *Getting photos* below.
4. **Confirm the standing shipping preference** if not already known (see *Shipping*). Never assume free shipping.

## The publish flow

```
ebay.com/sl/prelist/suggest
  → type a search string (brand + part/product + number)
  → Enter
  → "Continue without match"          # catalog rarely has the exact item; a wrong
                                      # catalog match misleads buyers
  → pick condition (usually "Used")
  → "Continue to listing"
  → the full form
```

Then on the form, in this order: **photos → title → item specifics → condition description → description → price → quantity → shipping → List it.**

### Photos
Use `find` for `hidden file input type=file` and call `file_upload` with the **ref of the input**, not the visible "Upload from computer" button (clicking that opens a native picker you cannot see). Upload multiple paths in one call. First image becomes the main photo.

Include a reference/context image when one exists (diagram, spec sheet, size comparison) — it visibly raises buyer confidence.

### Title (80 char max)
`form_input` works reliably here. Pattern that performs well:

> Brand + Product + Part/Model Number + [supersedes number] + OEM + Condition word

Check the character count; eBay silently truncates or rejects over 80.

### Item specifics
- eBay shows **"Suggested item specifics"** checkboxes near the top of the section — ticking those is the fastest path and they're usually correct.
- **`Type` is REQUIRED and does not always autofill.** If it's empty, either tick eBay's suggested Type checkbox, or open the dropdown, type a custom value, and click the **"+ <value>"** row under "Add custom value."
- Set **MPN** to the part/model number — buyers search by it.
- Do NOT blanket-click "Apply all" — eBay's AI guesses often include wrong values (e.g. "Power Source: Electric" on a plastic bin).

### Descriptions — the biggest trap
There are two fields:
- **Condition description** (short) — `form_input` works.
- **Main Description** (rich text) — **`form_input` does NOT register with eBay's React editor.** The DOM value changes but eBay saves nothing, and you'll get "A description is required" on submit.

**To set the main description: click the field, then `type`.** The most reliable way to reach and focus it: click **List it**, then click the **"Description"** link in the red error banner — that jumps to and focuses the field. Then click inside the box and type.

**The hidden textarea only syncs on blur.** Right after typing, `description` still reads `len: 0` — that is expected, not a failure. Click something outside the editor first, *then* verify.

**Always verify before publishing:**
```js
Array.from(document.querySelectorAll('textarea')).map(t => ({n: t.name, len: t.value.length}))
// the entry named "description" must have len > 0
```

**A long `type` into this field often returns `CDP sendCommand "Input.dispatchKeyEvent" timed out`** while having actually typed the whole string. Don't retype on that error — screenshot, and run the verification above. Retyping blind duplicates the description.

### Price
eBay's Pricing panel shows **"Recommended price"** drawn from actual sold listings in the last 90 days. This is better data than any external estimate — external sold-comp scraping is blocked, so this panel is the best sold-price signal available. Read it with:
```js
(() => { const t=document.body.innerText, i=t.indexOf('Recommended price');
  const p=document.querySelector('input[name="price"], input[id*="price"]');
  return (i>=0 ? t.slice(i,i+35).replace(/\n/g,' | ') : 'NO REC') + ' || field=' + (p?p.value:'?'); })()
```
The prefilled price is often NOT the recommendation — compare and set explicitly. Leave **Allow offers ON** so buyers can negotiate.

**⚠️ The recommended price assumes FREE shipping.** The panel prints it as e.g. "$15.00 | Free shipping" — that is a *total-to-buyer* figure, not an item-value figure. With calculated shipping the buyer pays that item price **plus** postage **plus** handling, so listing at the recommendation puts the all-in cost far above the comps it was derived from. Subtract a realistic postage estimate from the recommendation to get the item price, then say so to the user: this is a real speed-vs-margin tradeoff and it's their call, not a silent adjustment.

### Quantity
**eBay forbids two identical fixed-price listings of the same item.** For multiples, set **Quantity** on ONE listing. Say "3 available" in the description too.

## Shipping

Three options, and the choice materially affects whether the seller loses money:

| Mode | Seller pays | Use when |
|---|---|---|
| **Free shipping** | Full postage — often $10–35 | Only if baked into a high price. Dangerous on cheap/bulky items. |
| **Flat rate** | The overage on far-away buyers | Buyer-friendly, predictable, still leaks money |
| **Calculated + handling** | **$0** | **Default recommendation** |

**Calculated + handling cost** is almost always right: the buyer pays the live carrier rate for their address, and a flat handling fee covers the seller's box/tape/bubble wrap.

**How to set it:**
1. **UNCHECK "Offer free shipping" FIRST** (it locks other controls).
2. Cost type dropdown → **"Calculated: Cost varies by buyer location."**
3. Click **"See shipping options"** (top-right of the SHIPPING section) → toggle **"Handling cost"** ON → close the menu.
4. A **"Handling cost (optional)"** field appears below "Add additional services." **Triple-click it and type** — a plain click+type will not replace the existing `0.00`.

The field is `input[name="handlingFee"]` — a stable selector, unlike element refs.

**Package weight/dimensions:** eBay autofills these from "similar listings" and they are **frequently wrong in both directions**. Always override with the real packed box. Getting this wrong means the seller eats the difference on every label, or prices the listing out of the market.

**Look the part up on partstown.com before guessing.** For appliance/equipment parts it publishes manufacturer dimensions, which beats both eBay's estimator and eyeballing a photo:

```
partstown.com → search the bare part number (e.g. 241511601)
  → product page → SPECS tab → Length / Width / Height / Weight
```
The FITS MODELS tab also lists every compatible model — good material for the description and for buyer "will this fit?" questions. Sears PartsDirect does not publish dimensions; Parts Town does.

Real example: eBay estimated a freezer door bin at 16.3 × 12 × 7.9 @ 2 lb. Parts Town gave the actual part as **11.7 × 7.7 × 4.9 @ 0.57 lb** — roughly half the volume. Boxed at 14 × 10 × 6, the buyer's postage fell from $8.43–$23.89 to $6.65–$12.87.

Add ~1–2 in per side to the part dimensions for padding, then round to a real stock carton size.

**Dimensional weight:** boxes over ~1 cubic foot bill on volume, not actual weight (139 divisor). A big-but-light item in an oversized box costs like a much heavier parcel. Use the smallest box that fits.

## eBay policy rules that cause rejections

- **"Like new" / "like-new" is BANNED** in titles and descriptions — it makes the item surface in "new" searches. Use **"Excellent"**, **"gently used"**, or **"very good"**. Condition stays "Used".
- No duplicate fixed-price listings of the same item (use Quantity).
- Don't attach a catalog product match that isn't actually your item.

## Revising an existing listing

```
https://www.ebay.com/lstng?mode=ReviseItem&itemId=<ITEM_ID>
```
Same field mechanics apply. Useful for bulk-changing shipping across many listings.

### Bulk revising: the loop that actually works

Setting an input's `.value` from `javascript_tool` **does not stick**, even with the React native-setter trick plus `input`/`change` events. The DOM shows the new value, "Revise it" reports success, and a reload shows the OLD value. Verified twice — don't use it. Only real typing registers.

Per listing, in ONE `browser_batch`:
1. `navigate` to the revise URL, then `wait` 8–10s (the form is slow; a short wait leaves `handlingFee` undefined)
2. `javascript_tool`: `document.querySelector('input[name="handlingFee"]').scrollIntoView({block:'center'})` and return its value
3. `wait` 2s — the layout is still settling right after navigation
4. **`screenshot`** ← not optional, see below
5. `triple_click` the field, `type` the new value, `key` Tab
6. `javascript_tool` **guarded submit** — re-read the field and only click "Revise it" if it holds the intended value:
   ```js
   (()=>{const v=document.querySelector('input[name="handlingFee"]').value;
     if(v!=='10.00') return 'ABORT val='+v;
     const b=Array.from(document.querySelectorAll('button')).find(b=>b.innerText.trim()==='Revise it');
     if(!b) return 'ABORT no btn'; b.click(); return 'SUBMITTED';})()
   ```
7. `wait` 7s, then assert `document.body.innerText.includes('has been revised')`

**A fresh `screenshot` must immediately precede the click.** Without one in the same batch, `triple_click` at correct coordinates silently misses — the typing goes nowhere and the field keeps its old value. Cost several confusing retries where the field was plainly visible at the clicked coordinates.

**Getting the coordinate:** after `scrollIntoView({block:'center'})` the field sits at a fixed spot. Convert CSS px to screenshot px with `scale = 1568 / window.innerWidth` (screenshots are letterboxed to 1568 wide regardless of viewport). At a 1848px viewport that put the handling field at **(451, 337)**.

**Keep batches to ONE listing** (~11 actions). Two or three listings per batch times out mid-run, leaving some silently unrevised.

**Always re-verify afterward** by reloading each revise URL and reading the field back. In a 13-listing run, two listings were dropped by a timed-out batch and would have been reported as done. The guarded submit catches bad typing; only a reload catches a batch that never ran.

## Claude-in-Chrome extension quirks

- **`cmd+a` triggers a focus glitch** that freezes `computer` and `screenshot` with *"Cannot access a chrome-extension:// URL of different extension."* **Never use `cmd+a` in a field — use `triple_click` to select existing text.**
- **Recovery from that error:** reload the draft URL (`.../lstng?draftId=...&mode=AddItem`). Drafts persist, including uploaded photos. If a reload doesn't fix it, ask the user to click the page and close any other extension popups.
- **Element refs go stale constantly** as eBay re-renders. If `scroll_to`/`click` fails with "No element found," just re-run `find`.
- **`scroll_to` sometimes lands at the page bottom** instead of the element. Screenshot to confirm position rather than trusting it.
- Prefer `browser_batch` to chain steps — much faster than one call per action.

## Getting photos from Google Photos

If the user's photos live in Google Photos share links (`photos.app.goo.gl/...`), downloads via the UI usually fail (hidden save dialogs).

**Try this first — no browser needed.** A share link is publicly fetchable, and the full-size image URLs are embedded in the HTML:

```bash
curl -sL "<share-link>" -o /tmp/album.html
grep -oE 'https://lh3\.googleusercontent\.com/pw/[A-Za-z0-9_\-]+' /tmp/album.html | sort -u
# then, per URL:
curl -sL "<url>=d" -o photos/<name>.jpg
```

One `curl` per photo and you're done. Confirm you got originals with `file photos/*.jpg` — real phone photos read as 3000x4000 or similar, and the EXIF shows the camera. Small dimensions mean you grabbed thumbnails.

**The browser route below is the fallback**, and note that **`javascript_tool` is blocked on `photos.google.com`** ("Permission denied for JavaScript execution on this domain"), so the snippets only run if the user grants that domain in the extension. `read_page` still works and exposes the per-photo `/photo/` hrefs without JavaScript.

1. Navigate to the share link, wait, then list the photo pages:
   ```js
   Array.from(document.querySelectorAll('a[href*="/photo/"]')).map(a=>a.href).filter((v,i,s)=>s.indexOf(v)===i)
   ```
2. Navigate to each photo page, then grab the base image URL:
   ```js
   (() => { const img = Array.from(document.querySelectorAll('img'))
     .filter(i => i.src.includes('googleusercontent.com') && i.naturalWidth > 300)
     .sort((a,b)=>b.naturalWidth-a.naturalWidth)[0];
     return img ? img.src.split('=')[0] : 'none'; })()
   ```
3. Download the full-resolution original by appending `=d`:
   ```bash
   curl -sL "<base-url>=d" -o photos/<name>.jpg
   ```

Name files by part/product number so uploads stay unambiguous.

## Working style

- **Always stop at the publish button on the first listing** and show the user what's set. Get explicit approval before clicking "List it." After they approve the pattern, you can proceed through the rest without re-asking.
- **Checkpoint progress to memory** after each listing (item ID + price). Long listing runs can exhaust context, and item IDs are unrecoverable from the transcript alone.
- **Report honestly:** if a field silently failed to save, say so and fix it rather than assuming.
