-- The assistant stops being a thing you tune with a dial.
--
-- `assistant_caution` picked one of two prompt strings: 'reserved' answered
-- only what was literally written in the catalog, 'normal' also took greetings
-- and delivery questions. Both were written as limits on what the assistant was
-- allowed to say, and both produced the same complaint from the product owner —
-- it waited to be asked an exact question, and handed back everything else.
--
-- The rewrite on 20 September 2026 replaced both with one set of instructions
-- describing a shop assistant rather than a list of things not to do. There is
-- nothing left for the setting to choose between, and a control over behaviour
-- that has not been tuned yet is a control nobody can set well. It comes back
-- if there is ever a real difference for it to name.

alter table shop drop column assistant_caution;

drop type ai_caution;
