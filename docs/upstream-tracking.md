# Upstream compatibility tracking

This project prefers unmodified pinned Vial-QMK whenever upstream behavior is
correct on the supported keyboards. Local core patches must therefore have an
upstream reference, a reason for existing, and explicit removal criteria.

## Vial Tap Dance report ordering

- Upstream issue: [vial-kb/vial-qmk#1023 — tap dance triggers press/release in wrong order](https://github.com/vial-kb/vial-qmk/issues/1023)
- Status checked: open on 2026-09-27
- Local workaround: `patches/vial-tap-dance-reliable-interrupt.patch`
- WebHID control: **Reliable typing interrupt**, enabled by default
- Affected pinned trees: the direct Vial-QMK revision and the Vial-QMK submodule
  inside foostan's firmware wrapper, both recorded in `upstream.lock.json`

The workaround completes an interrupted synthetic tap before processing the
different key that interrupted it. It exists because rolled typing can otherwise
lose or reorder the tap while the original Tap Dance key is still physically
held.

### Removal gate

Return to the complete, unpatched upstream Vial implementation only when all of
the following are true:

1. An upstream Vial-QMK change fixes the ordering/lifetime problem, rather than
   the issue merely being closed administratively.
2. Both pinned Vial-QMK inputs contain the fix, or the foostan wrapper has been
   updated to a fixed Vial-QMK submodule.
3. `vial-tap-dance-reliable-interrupt.patch`, its build-script application, the
   Corne Control hook, and the temporary WebHID option are removed together.
4. Upstream preserves a nonzero delay between synthetic Tap Dance press and release reports, or provides equivalent host-visible ordering guarantees.
5. All three firmware targets build and pass their persistent-storage guards.
5. Physical XTIPS testing passes rapid rolled typing for `A` and `O`, repeated
   `average orange` text, tap-Space, Space-held-as-Shift, double tap, tap-hold,
   and use of Tap Dance keys from both halves.

Do not remove the workaround solely because a newer Vial release exists. Confirm
the relevant upstream code and complete the physical regression tests first.
