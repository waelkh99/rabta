-- Offers in the seller's own words, and Jordanian dinars by default.
--
-- Asked for by the product owner on 22 September 2026. The structured kinds —
-- a percentage, an amount, buy X get Y — cover the common sales. Everything
-- else a seller might think of ("the second piece half price", "a free scarf
-- with any dress") would each need a new structure. Instead the seller writes
-- it as a sentence and the assistant reads it as written, with the same dates,
-- switch and optional scope as any other offer. See ai.ts: the assistant may
-- apply a percentage or amount the seller wrote to a price the seller listed,
-- and nothing more.

-- Compared as text below, never as the enum: a value added by ALTER TYPE
-- cannot be used as an enum in the same transaction that adds it.
alter type offer_kind add value if not exists 'text';

alter table offers add column description text;

alter table offers drop constraint offers_value;

-- The same rule as before for the three structured kinds. A worded offer has
-- words and nothing else — a value on it would be a second, silent version of
-- the offer that the seller never sees.
alter table offers add constraint offers_value check (
  coalesce(
    case kind::text
      when 'percent' then value > 0 and value < 100 and buy is null and get is null
      when 'amount'  then value > 0 and buy is null and get is null
      when 'buy_get' then value is null and buy >= 1 and get >= 1
      when 'text'    then value is null and buy is null and get is null
                          and length(trim(coalesce(description, ''))) > 0
    end,
    false
  )
);

-- Said by the product owner: the default is the Jordanian dinar, written out.
-- A shop that never opened its settings has no row, and the assistant falls
-- back to the same words (DEFAULT_CURRENCY in ai.ts). A currency a shop has
-- already chosen is left alone.
alter table shop alter column currency set default 'دينار أردني';

comment on column conversations.ai_escalation_code is
  'Which kind of escalation this was, as a stable token the client localises: '
  'window_closed, no_window, ai_streak, seller_present, ceiling, ungrounded, '
  'unusable, not_sent, no_photo when the customer asked to see something that '
  'has no photo, or assistant when the model itself handed over. An '
  'unrecognised value must read as a general hand-over, never as an error.';
