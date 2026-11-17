# App Review — Instagram and Messenger

**Submitted 17 November 2026.** What changed from this draft when the form was
filled in: Meta's form now asks for the use in each permission's card, and for
`pages_messaging` and `instagram_manage_messages` (on behalf of other
businesses) the descriptions were rewritten to say plainly that other
businesses use Inboxara for their own accounts, and the videos were joined so
each shows the business connecting and then the messaging.
`pages_read_engagement` was described as reading the Page's name and a
customer's name and picture, with the Messenger video; `business_management`
only as the dependency Meta documents, with no Business Manager API use.
No tester account was given; the texts offer to add the reviewer's own.
The reviewer instructions also state which Graph endpoints Inboxara calls.

Drafted 16 November 2026 for the second App Review, after WhatsApp's was
approved. Copy each block into the matching field of Meta's form. Permissions
and their reasons are checked against Meta's Messenger Platform overview
(the Facebook Login route; `docs/DECISIONS.md`, 15 September).

**Submit exactly these seven.** Not `ads_management` (required by the use case
but never used; Standard Access needs no review) and not `public_profile`
(granted to every app).

---

## Before recording

- `meta-oauth` deployed to production with the 16 November fix.
- The demo shop on inboxara.app has the **Rabta App** Page and **djangus_w**
  connected, and the Accounts page shows both as receiving.
- **A sender with a role on the app**, for each channel. Until approval Meta
  delivers nothing else:
  - Messenger: the owner's own Facebook account works.
  - Instagram: an account added under App roles → Instagram Testers, which
    needs its owner to have a Facebook developer account.
- The browser at a normal desktop size, Inboxara in **English** (reviewers
  read English), notifications and other tabs closed.

## The two recordings

Meta accepts one screencast for several permissions when it shows each in
use. Two recordings cover all seven; upload the matching one to each
permission.

**Recording 1 — Connecting (about 60 s).**
`pages_show_list`, `pages_manage_metadata`, `pages_read_engagement`,
`business_management`, `instagram_basic`.

1. Signed in to inboxara.app, open the menu → **Accounts**.
2. Press **Connect with Meta**. Meta's dialog opens.
3. Continue as the Page admin. Pause on the screen that lists the Pages and
   Instagram accounts, and choose **Rabta App** and **djangus_w**.
4. Pause on the permissions screen, then confirm.
5. Back in Inboxara: the Accounts page lists **Rabta App** (Messenger) and
   **djangus_w** (Instagram), both "Receiving messages". Hold for 3 seconds.

**Recording 2 — Messaging (about 90 s).**
`pages_messaging`, `instagram_manage_messages`.

1. Inboxara's inbox on one side of the screen, a phone (or a second browser
   window) as the customer on the other.
2. The customer sends a Messenger message to Rabta App: it appears in the
   inbox with the Messenger mark and the customer's name and picture.
3. Open it, type a reply, send. Show it arriving on the customer's side.
4. The same with an Instagram DM to djangus_w: it appears with the Instagram
   mark; reply; show it arriving.

---

## Per permission

### pages_show_list

**How Inboxara uses it.** When a seller connects, Inboxara lists the Facebook
Pages they chose on Meta's screen so it can connect each one to their inbox.
Without it Inboxara cannot find the seller's Page and the connection fails.

**Video:** Recording 1, steps 2–5.

### pages_manage_metadata

**How Inboxara uses it.** After the seller connects a Page, Inboxara subscribes
that Page to its webhook (`POST /{page-id}/subscribed_apps`) for the
`messages`, `messaging_postbacks` and `message_echoes` fields. This is what
makes customer messages reach the seller's Inboxara inbox. When the seller
stops a connection, Inboxara removes the subscription.

**Video:** Recording 1, step 5 (the Page shown as receiving), and Recording 2,
step 2 (a message arriving through that subscription).

### pages_read_engagement

**How Inboxara uses it.** To read the connected Page's name and its linked
Instagram account, which Inboxara shows on its Accounts page so the seller can
see which Page each conversation came from. Meta lists it among the
permissions a Messenger conversation app needs.

**Video:** Recording 1, step 5 (the Page's name on the Accounts page).

### business_management

**How Inboxara uses it.** It is a dependency of `pages_messaging`: Meta's
Messenger Platform documentation states that "The `business_management`
permission is a dependency for `pages_messaging`". Sellers' Pages are often
owned through a business portfolio, and Inboxara needs it to access a Page
the seller manages that way. Inboxara does not read or change anything else
in the seller's business portfolio.

**Video:** Recording 1, steps 3–5.

### instagram_basic

**How Inboxara uses it.** To read the Instagram professional account linked
to the seller's Page — its id and username — so Inboxara can connect it and
show it on the Accounts page, and so incoming Instagram messages are matched
to the right seller.

**Video:** Recording 1, step 5 (djangus_w listed).

### pages_messaging

**How Inboxara uses it.** Inboxara is a shared inbox for sellers who sell
through Messenger and Instagram. With this permission it receives the
messages customers send to the seller's Page, shows them in one inbox with
the customer's name and picture, and sends the seller's replies back through
the Send API. Replies are only sent within Meta's 24-hour window after a
customer writes; Inboxara does not use message tags and sends no promotional
or unsolicited messages.

Sellers can turn on an optional assistant that answers simple questions —
price and availability — from the product list the seller wrote, inside the
same 24-hour window, and hands everything else to the seller.

**Video:** Recording 2, steps 1–3.

### instagram_manage_messages

**How Inboxara uses it.** The same as Messenger, for Instagram: Inboxara
receives the direct messages customers send to the seller's Instagram
professional account, shows them in the same inbox marked as Instagram, and
sends the seller's replies back. Replies only within the 24-hour window, no
message tags, nothing unsolicited.

**Video:** Recording 2, step 4.

---

## Instructions for the reviewer

> Inboxara is a web app at https://inboxara.app. Sign in with the test account
> below. It is a shop with a Facebook Page (Rabta App) and an Instagram
> professional account (djangus_w) already connected; both appear under the
> menu → Accounts.
>
> To see the connection flow: menu → Accounts → "Connect with Meta". Meta's
> dialog lists the Pages and Instagram accounts to choose; on return they are
> listed as "Receiving messages".
>
> To see messaging: the inbox lists conversations from Messenger and Instagram,
> each with its platform's mark. Open one to read the history and reply. The
> recordings show a message arriving and a reply reaching the customer, since
> messages from accounts without a role on the app are only delivered after
> approval.
>
> The interface is in Arabic and English; the switch is at the top of the
> inbox.
>
> Email: _(the reviewer account — to be created)_
> Password: _(to be set)_

**Open:** which account to give. The demo shop (seeded conversations, both
accounts connected) shows the most; a fresh reviewer account shows an empty
inbox. Give the demo shop's sign-in, or create `reviewer@inboxara.app` from
Admin → invite and connect the same Page to it.
