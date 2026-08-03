---
name: facebook-marketplace
description: Create Facebook Marketplace listings end-to-end by driving the user's browser — upload photos, fill the three-step form, set delivery and meetup preferences, cross-post to local buy/sell groups, and publish. Use when the user wants to list something on Facebook Marketplace, cross-post eBay listings locally, edit or end a Marketplace listing, or asks about Marketplace selling mechanics. Encodes the form's field-reveal order and the Claude-in-Chrome workarounds.
---

# Listing items on Facebook Marketplace

Drive the user's real browser via `mcp__claude-in-chrome__*`. Marketplace's form is far simpler than eBay's, but it reveals fields progressively and its dropdowns refuse `form_input` — those two facts drive the whole flow below.

## Before you start

1. **Load the browser tools in ONE ToolSearch call**: `tabs_context_mcp`, `navigate`, `computer`, `read_page`, `find`, `form_input`, `file_upload`, `browser_batch`.
2. **The user must already be signed into Facebook.** You cannot type their password. Load `facebook.com/marketplace/you/selling` and confirm you see "Your listings."
3. **Photos must be real files on disk.** If they live in Google Photos, use the `=d` download trick in the `ebay-listing` skill.
4. **Confirm the delivery preference.** Default to **local pickup only** unless the user says otherwise — see *Shipping* below.

## The publish flow

```
facebook.com/marketplace/create/item
  → photos → title → price → category → condition → description → [More details]
  → Next  → delivery method + meetup preferences
  → Next  → Marketplace + groups
  → Publish
```

Direct-navigating to `/marketplace/create/item` is faster than clicking "Create new listing."

### Fields appear progressively — this is the #1 thing to know

On a fresh form **only the Title box exists.** Price, Category, Condition, and Description are not in the DOM until the title has a value. So:

1. `find` the hidden file input, `file_upload` the photos.
2. `read_page filter:interactive` → `form_input` the **title**.
3. `read_page` **again** → now you get the price / category / condition / description refs.

Skipping the second `read_page` means silently filling nothing.

**Removing a photo can clear the title.** If you edit the photo set after typing the title, re-read the page; if the price field has vanished, the title was wiped — set it again.

### Photos

`find` for `hidden file input type=file` and call `file_upload` with the **ref of the input**, never the visible "Add photos" button (that opens a native picker you cannot see). Repeat calls on the same ref **append** rather than replace, so you can build up a set.

- **10 MB per `file_upload` call**, counted across every path in that call. Phone photos run 1.5–3 MB each, so 3–4 files per call. Splitting into several calls is fine.
- **A `file_upload` that would exceed the cap aborts the whole `browser_batch`, and earlier `file_upload` items in that same batch do not run.** Don't assume a partial batch half-succeeded — `read_page` and count the "Remove photo N of M" buttons.
- **Photo 1 is the cover** and is the single biggest driver of clicks. Order is upload order and there is no reliable drag-reorder; to promote an image, remove the ones ahead of it and re-add them at the end.
- 10 photos max. Include a diagram or spec sheet at the end when one exists.

### Title, price, description

`form_input` works on all three (they are plain inputs/textarea).

- Title: no hard 80-char cap like eBay, but keep it under ~100 so it isn't truncated in the grid.
- Price: type digits only; Facebook adds the `$`.
- Description: newlines work. Lead with the most decision-relevant fact.

### Category and Condition — clicks only

These render as `combobox` elements wrapped in a `LABEL`. **`form_input` fails on them** with `Element type "LABEL" is not a supported form input`. Click the combobox by ref, screenshot, then click the option by coordinate.

The list is long and scrolls; **Appliances** sits just below Home & Garden / Tools / Furniture / Household / Garden. Facebook also offers "Suggested category" chips under the field — they are frequently wrong (an appliance part gets suggested as "Antiques & Collectibles"), so pick the category deliberately.

Condition options: **New · Used - Like New · Used - Good · Used - Fair**.

> **"Like new" is fine on Facebook.** It's a first-class condition value here. This is the opposite of eBay, which bans the phrase outright — don't carry that rule across platforms.

### More details (optional)

Collapsible section holding **Material**, **Color**, **SKU**. Material and Color show in the buyer-facing Details table and cost one `form_input` each — worth filling. There is **no quantity field**: for multiples, say "3 available" in the title and description.

## Shipping

Marketplace defaults to **"Local pickup only"** and that is almost always the right answer.

Enabling Facebook shipping puts you into Facebook's checkout, where the **seller** buys the label — which is free shipping wearing a disguise, and it silently violates a no-free-shipping standing rule. If a seller wants to ship, leave the listing as local pickup and put **"or I ship at buyer's cost — message me"** in the description, then arrange postage directly.

**Meetup preferences** are checkboxes on the same step: *Public meetup*, *Door pickup*, *Door dropoff*. Tick Public meetup + Door pickup by default; they show as badges on the listing and reduce back-and-forth.

## Cross-posting to groups

The final step lists **Marketplace** (always ticked, not unticheckable) plus any local buy/sell groups the user belongs to, up to 20. Ticking a relevant group is usually free reach.

- Posting to a group is **public content in someone else's space** — get the user's approval the first time, then it's fine for the rest of a batch.
- Do **not** click "Join group" on Facebook's suggestions. Joining a group is a separate commitment; ask first.
- If a group post silently doesn't take (row still says "Listed on Marketplace" with no "and at least 1 group"), retry once via ⋮ → **List in more places**. If it still fails, it's usually Facebook's duplicate-listing filter — report it and move on rather than looping.

## Post-publish banners

Check `/marketplace/you/selling` after a batch. Two banners are common:

- **"This listing is being reviewed."** Automated review. The listing is still Active and usually clears itself. Leave it.
- **"It looks like you created a duplicate listing."** Fires when several listings share similar photos, titles, and prices — very common when parting out one machine. The listing stays Active but reach is reduced and **group cross-posting gets blocked**. Mitigate by giving each listing a distinct cover photo and a distinct title. The banner itself is sticky and won't clear after an edit even when the underlying cause is fixed.

## Editing and ending a listing

The per-row **⋮** menu → *Edit listing* / *Mark as sold* / *Delete listing* / *List in more places*. Edit reopens the same three-step form (button reads **Update** instead of Publish), and previously-set meetup preferences persist.

The menu is slow: click ⋮, wait ~2s, then screenshot before clicking a menu item — the popup renders empty at first and a fast click lands on nothing.

## Pricing against a live eBay listing

When cross-posting, price Facebook **lower than eBay while netting the same**. eBay takes ~13.6% + $0.40; Facebook local-pickup cash has no fee. So a $35.10 eBay item nets ~$29.90 → list it at **$30 on Facebook**. It looks like a better deal and moves faster for identical take-home.

**⚠️ Cross-posting means double-sell risk.** The instant something sells on one platform, end the other listing. Say this to the user explicitly at the end of a batch.

**Master "parting out" posts:** when selling many parts off one machine, one umbrella listing that lists every part and price drives traffic to the rest. Price it at the **real floor** (the cheapest actual item) with "PRICES VARY BY PART" as the first description line — never an arbitrary low placeholder like $1 or $10, which reads as bait-and-switch and gets reported.

## Claude-in-Chrome quirks

- Prefer `browser_batch`; a full listing is ~8 calls instead of ~25. But a failing item aborts the rest of the batch, so keep `file_upload` calls in their own batch.
- **Element refs are not stable across page loads** — the same form gives `ref_88` on one load and `ref_112` on the next. Re-`find` or re-`read_page` on every new listing; never reuse refs from the previous one.
- Coordinate positions *within* a step, by contrast, are stable across listings once the panel has scrolled to the same place — the meetup checkboxes and Next/Publish buttons can be blind-clicked after the first listing.
- After clicking Publish, wait 5–8s. Confirm by the tab URL flipping to `/marketplace/you/selling`, not by screenshot (the screenshot often shows the stale form).
- `/marketplace/you/selling` is slow to hydrate; `find` will report "no listings" on a page that is merely still loading. Wait and re-screenshot before concluding anything is missing.

## Working style

- **Stop at Publish on the first listing**, show the user the title/price/condition/category/delivery/groups, and get approval. Then run the rest of the batch unattended.
- **Checkpoint to memory** after each listing. Facebook doesn't expose item IDs in the UI, so record title + price.
- **Verify by count**: the "N active listings" number on the selling page should rise by exactly the number published. Report honestly if it doesn't.
