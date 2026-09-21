-- What the assistant does when a customer pushes on price.
--
-- Replaces the boolean added earlier the same day. The product owner named two
-- modes rather than an on/off, and one of them — notify — is still being
-- worked out against how the case actually goes in a real shop. A boolean
-- called prices_final could not carry that, and the code would have kept
-- saying "final" while the product said something else.
--
-- An enum rather than text so a typo is rejected at insert time, and so adding
-- a third mode later is a migration rather than a guess about what strings are
-- already in the column.
--
-- The underlying rule is unchanged and is not a mode: the assistant states
-- only what it knows. The price comes from the catalog, and a discount will
-- come from the sales section when that exists. Neither mode invents one.

create type price_stance as enum (
  -- The listed price is the price. The assistant says so plainly and warmly,
  -- and offers a cheaper thing from the catalog if there is one, rather than
  -- leaving the customer with a flat no.
  'strict',

  -- The assistant answers the price, does not argue, and hands the
  -- conversation to the seller so they can decide. The original behaviour, and
  -- the default.
  'notify'
);

alter table shop
  add column price_stance price_stance not null default 'notify';

-- Carries over anything set in the few hours the boolean existed.
update shop set price_stance = 'strict' where prices_final;

alter table shop drop column prices_final;

comment on column shop.price_stance is
  'strict: the assistant states the price as final and suggests a cheaper item '
  'instead of bargaining. notify: it states the price, argues nothing, and '
  'hands the conversation to the seller. Neither invents a discount — that '
  'comes from the catalog and, later, the sales section.';
