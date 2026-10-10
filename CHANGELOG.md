# Changelog

## 0.3.0

Improved Controller is now **Improved Forever**, split into modules: each feature is its own addon,
enabled or disabled in the AddOns list. The core (ImprovedForever) is needed by all of them.

- **Modules**: Controller (bag clean-up, touchpad corners, every press on one drawing), Wheel,
  Vibration, Gather, Map, Auction (with Tasks), Destroy and Library.
- **New configuration panel** in the auction window's look: a tab per loaded module down the right
  (L1 / R1 or the right stick), each module's sections down the left (the left stick or L2 / R2),
  its settings as fields in the middle (left / right change them in place, Cross picks from the
  list on the right).
- **Destroy** has its own tab: on / off and the press that opens it.
- `/if` replaces `/ic` (`/if help` lists the commands).
- Settings start fresh: they're kept in new saved variables (ImprovedForeverDB...).

## 0.2.0

First public release.

- **Wheels**: radial wheels on R3 combos laid out like Forever's own radial menu, with several
  wheels per combo, slot tooltips, custom emote icons and a consumables wheel split by category.
  The right stick aims the wheel.
- **Recent action slot** on R3, placed and sized in the game's Edit Mode per layout.
- **Touchpad**: corner slots edited from a wheel-style picker.
- **Button overrides**: L3 click and double-click actions.
- **Vibration**: events (low health, spell casts and more) with patterns matched to action
  families, and a cast preset editor per action and per phase.
- **Bag cleaner**: pick items to destroy from the controller.
- **General** tab: bag sort binding, picker offsets. Double-tap Menu opens the config.
- Own icon set: cream line art with green accents.
