-- Every conversation read as "Customer", because Meta does not put a name in
-- the message. It sends an opaque id scoped to the account the person wrote
-- to, and the name and picture have to be asked for separately.
--
-- A seller scanning a list of identical rows called "Customer" cannot tell who
-- is who, which defeats the list the whole product is built around.
--
-- `customer_name` and `customer_avatar_url` already exist. What was missing is
-- a record of having asked, without which there are only two behaviours
-- available: ask on every single message, or never ask again for a customer
-- whose name Meta withheld.

alter table conversations
  add column customer_profile_fetched_at timestamptz;

comment on column conversations.customer_profile_fetched_at is
  'When Meta was last asked who this customer is. Set even when the answer '
  'was nothing, so a customer with no readable name is not looked up again on '
  'every message. Null means never asked.';

-- Meta's profile picture URLs expire, so this is also what decides when to ask
-- again. Measured on 18 September 2026: a real profile_pic URL carried
-- ext=1792333334, about 30 days out, and was fetchable with no access token —
-- the same shape as attachment URLs.
--
-- The URL is stored rather than the image. A name is what identifies a
-- customer; the picture is decoration, and the interface already draws a
-- monogram when there is none, so an expired URL costs nothing. Copying every
-- customer's picture into storage would buy a graceful failure we already have.
