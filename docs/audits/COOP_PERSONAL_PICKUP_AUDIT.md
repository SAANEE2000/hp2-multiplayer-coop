# Ch1 personal pickup and unsupported save entry guards

Scope: original ChocolateFrog, WiggenWell, WWellBlueBottle and WWellOrangeBottle
personal grants on Ch1Rictusempra. Other collectible policies are unresolved.
The adapter uses narrow HProp replacements; original sources/assets are not
redistributed. Full campaign pickup compatibility is not claimed.

## Pickup contract

HProp.Touch recognizes supported co-op props and always returns after the adapter,
including refused contacts. A refusal cannot fall through to the original cached
PlayerHarry. The adapter requires authority, the actual touching registered ready
living owner, an active session, and no capture/recovery/resume transaction.
Cosmetic drinking bottles, attached/owned props, mixing, hidden or previously
claimed props do not award inventory.

The synchronous claim precedes callbacks. It disables further contacts and the
prop's random motion, invokes the collector's original managerStatus_PickupItem,
publishes that owner's status, dispatches the original pickup event with its
original `(Prop, Prop)` arguments, then hides/destroys the prop. It never changes
the cached prop.PlayerHarry or Level.PlayerHarryActor.

The original status chain clamps frog healing and increments potion inventory.
A potion pickup does not itself drink/heal. A frog still consumes at full health,
matching the original grant behavior. Immediate sound and destroy replace the
single-player flight-to-HUD presentation; remote sound/destruction and natural
placed-map hopping require separate acceptance. Native destruction replication
must not be inferred from a server grant log alone.

## Temporary save boundary

The co-op save/load recipe adds early guards to SavePoint.Touch/OnSaveGame and
audited HPConsole/FEBook saved-slot/page/URL routes. Books are refused before
health, activation, opacity, destruction, queue or timer changes. The authority
addresses the actual touching player. Menu guards resolve their own viewport
owner and run before pause, SloMo, metadata writes or saved-game travel.

Ordinary Harry and Versus retain their original bodies after the guards. These
guards do not implement persistence, shared checkpoint recovery, native frontend
interception, or a sandbox for typed native Exec commands. Other campaign
CutScript save/load commands and SleepingGoyle reloads remain outside this scope.

## Explicit disposable contact fixture

RuntimeProbe=Pickup creates exact original prop classes near two stationary
players after the intro. It seeds 20 HP and zero potions, freezes only synthetic
props, and uses native MoveSmooth collision to enter each player. It never calls
Touch, TryCollect, OnSaveGame or an award function directly. The event observer
requires a unique explicitly supplied Spawn tag; omitted Spawn tags are None on
this runtime despite the class default.

Six awards cover each owner's frog/potion plus repeated synthetic dead/capture
refusals followed by successful contact on the same prop. Counts, one event per
prop, unchanged cached context and destruction are checked. Two original active
one-shot SavePoints each receive two fresh native contacts. Their state and both
players' status/save queues must remain unchanged, including a delayed check.
The collected log must also show the real SavePoint.Touch guard for each contact.

This fixture proves only the executed server contact/ownership predicates. It
does not test simultaneous pickup races, real death/capture contacts, placed-map
pathfinding, input, rendered HUD/audio, network destruction, menus or two PCs.
The session must be discarded because its player status is intentionally seeded.

## Native replica lifetime

On the inspected M212 Engine.dll (`e7bd8f53aa1bce2386ba8943fdfc4d4c54c0a27948f49bc0de53dee22cc82391`),
client LoadMap removes dynamic map actors before channel recreation (RVA
9B9D1–9BA3F). Server DestroyActor notifies the net driver; NotifyActorDestroyed
closes the actor channel (130D30–130DCF). Client channel Destroy calls forced
DestroyActor for a non-temporary actor (125D9B–125F06). The four Ch1 placed frog
property streams contain no Role/RemoteRole/static/no-delete/temporary override;
their inherited Pawn RemoteRole is SimulatedProxy. This supports a native path,
but static evidence alone was not counted as a successful deletion.

The separate PickupNet fixture splits creation from contact. Both owners must
first acknowledge the exact existing actor reference with Role2, visible and
collidable. After native Touch consumes it, local read-only observers require
the saved reference to be absent/deleted and no live actor with its previously
observed client-local Name/Class. Both repeat this absence check for two seconds.
No client hide/destroy call or item relevance/role override is used.

Build182426-014 passed this lifecycle for one original ChocolateFrog and one
WWellBlueBottle. These are explicitly spawned stationary test props, not natural
placed-map pickup navigation or visual acceptance. Report:
`docs/iterations/20260920_COOP_PICKUP_REPLICATION.md`.
