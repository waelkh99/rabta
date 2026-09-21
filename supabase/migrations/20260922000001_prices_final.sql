-- Whether the shop haggles.
--
-- Asked for by the product owner on 21 September 2026: a seller should be able
-- to choose between the assistant handing a price negotiation back to them and
-- the assistant saying plainly that the listed price is the price.
--
-- Default false, which is exactly what the assistant already does — answer the
-- price, never argue about it, and hand the conversation over when a customer
-- pushes. Nothing changes for a shop that never opens this setting.
--
-- The interesting half is not this column. `claimsAreGrounded` refuses a reply
-- claiming a price is fixed, because until now no shop had ever said so, and a
-- price policy the seller never stated is exactly the kind of thing the
-- assistant must not invent. Turning this on does not weaken that check: it
-- makes the claim true, by writing it into the same `facts` string the check
-- searches. See renderFacts in ai.ts, and the standing rule in CLAUDE.md about
-- feeding the assistant everything the seller writes down.

alter table shop
  add column prices_final boolean not null default false;

comment on column shop.prices_final is
  'True when the seller has said the listed price is final. The assistant may '
  'then say so to a customer who asks for a better price, instead of handing '
  'the conversation over. False, the default, is the original behaviour: quote '
  'the price, refuse nothing, argue nothing, and pass it to the seller.';
