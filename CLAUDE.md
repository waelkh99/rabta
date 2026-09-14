# CLAUDE.md

## Project Overview

This project is a social commerce application for businesses and individuals who sell products mainly through Meta platforms.

The long-term goal is to provide one place where sellers can manage customer interactions, understand their customers better, streamline sales-related work, and eventually add useful automation and integrations.

The product should be designed around real seller workflows, not around technical possibilities.

Decisions that have already been settled — supported platforms, backend, and
known Meta limitations — are recorded in `DECISIONS.md`. Read it before making
architectural choices.

`WEBHOOKS.md` specifies the webhook service that receives messages from Meta
and sends replies. It is being built as a standalone piece of work.

---

## Phase One

The first phase is focused only on creating a unified customer inbox.

The user should be able to:

- Connect their supported Meta accounts.
- Receive customer messages from Instagram and Facebook Messenger.
- View all conversations from one place.
- Clearly see which platform each conversation came from.
- Open a conversation and view the message history the application has received.
- Reply to customers from the application.
- See unread conversations and new incoming messages clearly.
- Handle common message attachments where possible.

The goal is to make managing customer conversations simpler than switching between multiple Meta applications.

---

## Out of Scope for Phase One

Do not add these unless explicitly requested:

- AI-generated replies.
- Automatic AI responses.
- Order management.
- Product catalog management.
- Inventory management.
- Delivery company integrations.
- Payments.
- Sales analytics.
- Campaign analytics.
- Advanced CRM functionality.
- Other social media platforms.

Do not add features simply because they may be useful later.

---

## Product Direction

This should not feel like separate inboxes placed inside one application.

The experience should feel like one customer communication workspace.

The product should prioritize:

- simplicity;
- speed;
- clear navigation;
- minimal unnecessary steps;
- understandable information;
- clean UX;
- low cognitive load.

The application is intended for people who may not be highly technical.

Do not expose unnecessary technical language to the user.

---

## Product Philosophy

The product should solve real problems in the simplest useful way.

Avoid adding complexity to make the product look more impressive.

When deciding between:

- a complicated solution with many features;
- a simple solution that solves the user's problem well;

prefer the simple solution.

---

## Role of Claude

Claude is the development assistant, not the product owner.

Claude should:

- help implement ideas;
- identify potential problems;
- point out missing cases;
- suggest improvements;
- explain trade-offs;
- help simplify solutions.

Claude should not:

- silently change the product direction;
- invent major features;
- expand the scope without being asked;
- make important UX decisions without discussing them first;
- assume future requirements;
- overengineer the project.

If an important product or UX decision needs to be made, Claude should explain the decision and suggest options before implementing it.

---

## Testing

Everything implemented must be tested. Not described as tested, not assumed to
work — actually run.

This is not negotiable and it is not traded away for speed. Code that has not
been executed is not finished.

Where the obvious way to test something is unavailable, find another way rather
than skipping it. A missing tool is a problem to solve, not a reason to ship
untested work.

Tests must be shown to fail when the code is wrong. A test that passes against
broken code is worse than no test, because it produces false confidence.

Report results honestly. If something fails, say so and show the output. If
something could not be tested, say exactly that and why.

---

## User Experience

The product should be designed from the perspective of someone actively handling customer inquiries throughout the day.

Important questions should always include:

- Is this easy to understand?
- Can the user complete this with fewer steps?
- Is important information visible at the right time?
- Would a non-technical person understand what to do?
- Is this helping the seller respond to customers faster?

Avoid unnecessary screens, popups, settings, and steps.

---

## Future Vision

Later phases may include:

- WhatsApp support;
- customer profiles across multiple channels;
- AI-assisted replies;
- AI-powered customer service;
- product and order information;
- delivery company integrations;
- sales insights;
- conversation analytics;
- automation.

These are future possibilities only.

They should not influence Phase One unless explicitly requested.

---

## Phase One Success

Phase One is successful when a seller can comfortably manage their Instagram and Facebook Messenger customer conversations from one place without needing to constantly switch between separate applications.

That is the only goal for now.
