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

**Always verify before publishing:**
```js
Array.from(document.querySelectorAll('textarea')).map(t => ({n: t.name, len: t.value.length}))
// the entry named "description" must have len > 0
```

### Price
eBay's Pricing panel shows **"Recommended price"** drawn from actual sold listings in the last 90 days. This is better data than any external estimate — external sold-comp scraping is blocked, so this panel is the best sold-price signal available. Read it with:
```js
(() => { const t=document.body.innerText, i=t.indexOf('Recommended price');
  const p=document.querySelector('input[name="price"], input[id*="price"]');
  return (i>=0 ? t.slice(i,i+35).replace(/\n/g,' | ') : 'NO REC') + ' || field=' + (p?p.value:'?'); })()
```
The prefilled price is often NOT the recommendation — compare and set explicitly. Leave **Allow offers ON** so buyers can negotiate.

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

**Package weight/dimensions:** eBay autofills these from "similar listings" and they are **frequently too small**, especially for anything double-boxed or oversized. Always override with the real packed box. Getting this wrong means the seller eats the difference on every label.

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

## Claude-in-Chrome extension quirks

- **`cmd+a` triggers a focus glitch** that freezes `computer` and `screenshot` with *"Cannot access a chrome-extension:// URL of different extension."* **Never use `cmd+a` in a field — use `triple_click` to select existing text.**
- **Recovery from that error:** reload the draft URL (`.../lstng?draftId=...&mode=AddItem`). Drafts persist, including uploaded photos. If a reload doesn't fix it, ask the user to click the page and close any other extension popups.
- **Element refs go stale constantly** as eBay re-renders. If `scroll_to`/`click` fails with "No element found," just re-run `find`.
- **`scroll_to` sometimes lands at the page bottom** instead of the element. Screenshot to confirm position rather than trusting it.
- Prefer `browser_batch` to chain steps — much faster than one call per action.

## Getting photos from Google Photos

If the user's photos live in Google Photos share links (`photos.app.goo.gl/...`), downloads via the UI usually fail (hidden save dialogs). This works instead:

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
