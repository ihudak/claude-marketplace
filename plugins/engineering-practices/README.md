# engineering-practices

Five skills for disciplined software engineering practice.

## Skills

### grill-me

Stress-tests a plan or design by interviewing you relentlessly, walking every branch of the decision tree and providing a recommended answer for each question. Use when you want to pressure-test an idea before committing to it.

### grill-with-docs

Like `grill-me`, but grounded in your project's existing domain model: challenges your plan against the `CONTEXT.md` glossary, sharpens terminology, and writes ADRs and glossary updates inline as decisions crystallise. Use when you want to stress-test a design against documented language and architecture decisions.

### diagnose

A structured six-phase debugging discipline: build a feedback loop, reproduce, hypothesise, instrument, fix with a regression test, and clean up. Use when you are dealing with a hard bug, a flaky failure, or a performance regression.

### tdd

Red-green-refactor TDD with vertical slicing (one test, one implementation, repeat). Plans the interface and test scope up front, then drives implementation through a tracer bullet and incremental loop. Use when building a new feature or behaviour change test-first.

### improve-codebase-architecture

Surfaces deepening opportunities across the codebase — refactors that reduce interface complexity while increasing behavioural leverage — using your domain vocabulary from `CONTEXT.md` and respecting decisions in `docs/adr/`. Use when the codebase is hard to test, hard to navigate, or carrying too much surface area in its module interfaces.
