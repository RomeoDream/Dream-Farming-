# Development milestones

## Implemented scripting expansion — 0.3.0 alpha

The repository now includes the local farm simulation plus individual animals, production chains/storage, tractor driving and field coverage, irrigation equipment, board/work orders/group care, current Garden manure integration and optional existing-protocol fuel/power/bank adapters. See README and EXPANSION for the behavior actually supplied.

The v0.3 milestone adds manure storage/separation, measured spreading, pasture regrowth, PTO/hydraulic/hitch interlocks and named cab controls/gauges. Detailed handling and remaining physical-build work are documented in FIELD_OPERATIONS.md.

This closes the major scripting categories from the expansion plan. It does not certify an installation in Second Life or supply finished visual assets, a public commodity economy or hosting.

## Next: qualify the complete farm in-world

Compile all seventeen scripts as Mono, record memory at maximum herd/ledger/receipt capacity, tune vehicle hull/physics, and run the linked systems under real event timing. Verify Garden manure-to-compost-to-fertilizer, an actual TXAGO engine shutdown/restart, DPC outages and a bank-paid service invoice. Complete IN_WORLD_TESTS before treating the alpha as production-ready.

## Asset and interaction expansion

- Crop-specific meshes and growth stages, PBR materials, realistic animal meshes/animation and sound.
- Vehicle tuning, steering/wheel animation, hitch attachments, implement work animation, continuously swept working widths and physical load effects.
- Hose/cable/pipe meshes with user connection controls; moving trailers and safe loading-zone interfaces.
- Configurable breed/seed/produce grades, deep pedigree history, demand-driven pasture feeding, more detailed manure/slurry analyses and moisture-based grain grading.
- More crops, orchards, greenhouses with growing beds, pollination/beekeeping and expanded food recipes.
- A shared farm calendar, role assignments beyond group membership, automated field-job telemetry and owner-visible operational alerts.

## Later: authoritative servers and public trading

Preserve local material names, immutable request IDs and explicit confirmation boundaries. Introduce server-owned farm/entity IDs, authenticated users, durable idempotent inventory transactions, stock provenance and audit logs. Add recovery for deleted/re-rezzed roots, cross-region logistics, transferable goods and market contracts only when the authoritative ledger can prevent copied-object stock from becoming value.

The existing Office bills completed roleplay services; it is not a goods marketplace. Server work also needs lifecycle/reconciliation tests, deployment configuration, backup/restore and a migration plan for existing local farms. No unprovisioned endpoint or database is described as live.

## Acceptance rule

Keep implementation, local tests, simulator checks, asset delivery and live-service verification distinct. Record evidence and limitations in STATUS.md. A script existing in GitHub does not establish simulator performance or economic security.
