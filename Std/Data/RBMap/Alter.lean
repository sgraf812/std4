/-
Copyright (c) 2022 Mario Carneiro. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mario Carneiro
-/
import Std.Data.RBMap.WF

/-!
# Path operations; `modify` and `alter`

This develops the necessary theorems to construct the `modify` and `alter` functions on `RBSet`
using path operations for in-place modification of an `RBTree`.
-/

namespace Std

namespace RBNode
open RBColor

attribute [simp] Path.fill

/-! ## path balance -/

/-- Asserts that property `p` holds on the root of the tree, if any. -/
def OnRoot (p : α → Prop) : RBNode α → Prop
  | nil => True
  | node _ _ x _ => p x

/--
Auxiliary definition for `zoom_ins`: set the root of the tree to `v`, creating a node if necessary.
-/
def setRoot (v : α) : RBNode α → RBNode α
  | nil => node red nil v nil
  | node c a _ b => node c a v b

/--
Auxiliary definition for `zoom_ins`: set the root of the tree to `v`, creating a node if necessary.
-/
def delRoot : RBNode α → RBNode α
  | nil => nil
  | node _ a _ b => a.append b

namespace Path

/-- Same as `fill` but taking its arguments in a pair for easier composition with `zoom`. -/
@[inline] def fill' : RBNode α × Path α → RBNode α := fun (t, path) => path.fill t

theorem zoom_fill' (cut : α → Ordering) (t : RBNode α) (path : Path α) :
    fill' (zoom cut t path) = path.fill t := by
  induction t generalizing path with
  | nil => rfl
  | node _ _ _ _ iha ihb => unfold zoom; split <;> [apply iha, apply ihb, rfl]

theorem zoom_fill (H : zoom cut t path = (t', path')) : path.fill t = path'.fill t' :=
  (H ▸ zoom_fill' cut t path).symm

theorem zoom_ins {t : RBNode α} {cmp : α → α → Ordering} :
    t.zoom (cmp v) path = (t', path') →
    path.ins (t.ins cmp v) = path'.ins (t'.setRoot v) := by
  unfold RBNode.ins; split <;> simp [zoom]
  · intro | rfl, rfl => rfl
  all_goals
  · split
    · exact zoom_ins
    · exact zoom_ins
    · intro | rfl => rfl

theorem insertNew_eq_insert (h : zoom (cmp v) t = (nil, path)) :
    path.insertNew v = (t.insert cmp v).setBlack :=
  insert_setBlack .. ▸ (zoom_ins h).symm

theorem zoom_del {t : RBNode α} :
    t.zoom cut path = (t', path') →
    path.del (t.del cut) (match t with | node c .. => c | _ => red) =
    path'.del t'.delRoot (match t' with | node c .. => c | _ => red) := by
  unfold RBNode.del; split <;> simp [zoom]
  · intro | rfl, rfl => rfl
  · next c a y b =>
    split
    · have IH := @zoom_del (t := a)
      match a with
      | nil => intro | rfl => rfl
      | node black .. | node red .. => apply IH
    · have IH := @zoom_del (t := b)
      match b with
      | nil => intro | rfl => rfl
      | node black .. | node red .. => apply IH
    · intro | rfl => rfl

variable (c₀ : RBColor) (n₀ : Nat) in
/--
The balance invariant for a path. `path.Balanced c₀ n₀ c n` means that `path` is a red-black tree
with balance invariant `c₀, n₀`, but it has a "hole" where a tree with balance invariant `c, n`
has been removed. The defining property is `Balanced.fill`: if `path.Balanced c₀ n₀ c n` and you
fill the hole with a tree satisfying `t.Balanced c n`, then `(path.fill t).Balanced c₀ n₀` .
-/
protected inductive Balanced : Path α → RBColor → Nat → Prop where
  /-- The root of the tree is `c₀, n₀`-balanced by assumption. -/
  | protected root : Path.root.Balanced c₀ n₀
  /-- Descend into the left subtree of a red node. -/
  | redL : Balanced y black n → parent.Balanced red n →
    (Path.left red parent v y).Balanced black n
  /-- Descend into the right subtree of a red node. -/
  | redR : Balanced x black n → parent.Balanced red n →
    (Path.right red x v parent).Balanced black n
  /-- Descend into the left subtree of a black node. -/
  | blackL : Balanced y c₂ n → parent.Balanced black (n + 1) →
    (Path.left black parent v y).Balanced c₁ n
  /-- Descend into the right subtree of a black node. -/
  | blackR : Balanced x c₁ n → parent.Balanced black (n + 1) →
    (Path.right black x v parent).Balanced c₂ n

/--
The defining property of a balanced path: If `path` is a `c₀,n₀` tree with a `c,n` hole,
then filling the hole with a `c,n` tree yields a `c₀,n₀` tree.
-/
protected theorem Balanced.fill {path : Path α} {t} :
    path.Balanced c₀ n₀ c n → t.Balanced c n → (path.fill t).Balanced c₀ n₀
  | .root, h => h
  | .redL hb H, ha | .redR ha H, hb => H.fill (.red ha hb)
  | .blackL hb H, ha | .blackR ha H, hb => H.fill (.black ha hb)

protected theorem _root_.Std.RBNode.Balanced.zoom : t.Balanced c n → path.Balanced c₀ n₀ c n →
    zoom cut t path = (t', path') → ∃ c n, t'.Balanced c n ∧ path'.Balanced c₀ n₀ c n
  | .nil, hp => fun e => by cases e; exact ⟨_, _, .nil, hp⟩
  | .red ha hb, hp => by
    unfold zoom; split
    · exact ha.zoom (.redL hb hp)
    · exact hb.zoom (.redR ha hp)
    · intro e; cases e; exact ⟨_, _, .red ha hb, hp⟩
  | .black ha hb, hp => by
    unfold zoom; split
    · exact ha.zoom (.blackL hb hp)
    · exact hb.zoom (.blackR ha hp)
    · intro e; cases e; exact ⟨_, _, .black ha hb, hp⟩

theorem ins_eq_fill {path : Path α} {t : RBNode α} :
    path.Balanced c₀ n₀ c n → t.Balanced c n → path.ins t = (path.fill t).setBlack
  | .root, h => rfl
  | .redL hb H, ha | .redR ha H, hb => by unfold ins; exact ins_eq_fill H (.red ha hb)
  | .blackL hb H, ha => by rw [ins, fill, ← ins_eq_fill H (.black ha hb), balance1_eq ha]
  | .blackR ha H, hb => by rw [ins, fill, ← ins_eq_fill H (.black ha hb), balance2_eq hb]

protected theorem Balanced.ins {path : Path α}
    (hp : path.Balanced c₀ n₀ c n) (ht : t.RedRed (c = red) n) :
    ∃ n, (path.ins t).Balanced black n := by
  induction hp generalizing t with
  | root => exact ht.setBlack
  | redL hr hp ih => match ht with
    | .balanced .nil => exact ih (.balanced (.red .nil hr))
    | .balanced (.red ha hb) => exact ih (.redred rfl (.red ha hb) hr)
    | .balanced (.black ha hb) => exact ih (.balanced (.red (.black ha hb) hr))
  | redR hl hp ih => match ht with
    | .balanced .nil => exact ih (.balanced (.red hl .nil))
    | .balanced (.red ha hb) => exact ih (.redred rfl hl (.red ha hb))
    | .balanced (.black ha hb) => exact ih (.balanced (.red hl (.black ha hb)))
  | blackL hr hp ih => exact have ⟨c, h⟩ := ht.balance1 hr; ih (.balanced h)
  | blackR hl hp ih => exact have ⟨c, h⟩ := ht.balance2 hl; ih (.balanced h)

protected theorem Balanced.insertNew {path : Path α} (H : path.Balanced c n black 0) :
    ∃ n, (path.insertNew v).Balanced black n := H.ins (.balanced (.red .nil .nil))

protected theorem Balanced.insert {path : Path α} (hp : path.Balanced c₀ n₀ c n) :
    t.Balanced c n → ∃ c n, (path.insert t v).Balanced c n
  | .nil => ⟨_, hp.insertNew⟩
  | .red ha hb => ⟨_, _, hp.fill (.red ha hb)⟩
  | .black ha hb => ⟨_, _, hp.fill (.black ha hb)⟩

theorem zoom_insert {path : Path α} {t : RBNode α} (ht : t.Balanced c n)
    (H : zoom (cmp v) t = (t', path)) :
    (path.insert t' v).setBlack = (t.insert cmp v).setBlack := by
  have ⟨_, _, ht', hp'⟩ := ht.zoom .root H
  cases ht' with simp [insert]
  | nil => simp [insertNew_eq_insert H, setBlack_idem]
  | red hl hr => rw [← ins_eq_fill hp' (.red hl hr), insert_setBlack]; exact (zoom_ins H).symm
  | black hl hr => rw [← ins_eq_fill hp' (.black hl hr), insert_setBlack]; exact (zoom_ins H).symm

protected theorem Balanced.del {path : Path α}
    (hp : path.Balanced c₀ n₀ c n) (ht : t.DelProp c' n) (hc : c = black → c' ≠ red) :
    ∃ n, (path.del t c').Balanced black n := by
  induction hp generalizing t c' with
  | root => match c', ht with
    | red, ⟨_, h⟩ | black, ⟨_, _, h⟩ => exact h.setBlack
  | @redL _ n _ _ hb hp ih => match c', n, ht with
    | red, _, _ => cases hc rfl rfl
    | black, _, ⟨_, rfl, ha⟩ => exact ih ((hb.balLeft ha).of_false (fun.)) (fun.)
  | @redR _ n _ _ ha hp ih => match c', n, ht with
    | red, _, _ => cases hc rfl rfl
    | black, _, ⟨_, rfl, hb⟩ => exact ih ((ha.balRight hb).of_false (fun.)) (fun.)
  | @blackL _ _ n _ _ _ hb hp ih => match c', n, ht with
    | red, _, ⟨_, ha⟩ => exact ih ⟨_, rfl, .redred ⟨⟩ ha hb⟩ (fun.)
    | black, _, ⟨_, rfl, ha⟩ => exact ih ⟨_, rfl, (hb.balLeft ha).imp fun _ => ⟨⟩⟩ (fun.)
  | @blackR _ _ n _ _ _ ha hp ih =>  match c', n, ht with
    | red, _, ⟨_, hb⟩ => exact ih ⟨_, rfl, .redred ⟨⟩ ha hb⟩ (fun.)
    | black, _, ⟨_, rfl, hb⟩ => exact ih ⟨_, rfl, (ha.balRight hb).imp fun _ => ⟨⟩⟩ (fun.)

/-- Asserts that `p` holds on all elements to the left of the hole. -/
def AllL (p : α → Prop) : Path α → Prop
  | .root => True
  | .left _ parent _ _ => parent.AllL p
  | .right _ a x parent => a.All p ∧ p x ∧ parent.AllL p

/-- Asserts that `p` holds on all elements to the right of the hole. -/
def AllR (p : α → Prop) : Path α → Prop
  | .root => True
  | .left _ parent x b => parent.AllR p ∧ p x ∧ b.All p
  | .right _ _ _ parent => parent.AllR p

/--
The property of a path returned by `t.zoom cut`. Each of the parents visited along the path have
the appropriate ordering relation to the cut.
-/
def Zoomed (cut : α → Ordering) : Path α → Prop
  | .root => True
  | .left _ parent x _ => cut x = .lt ∧ parent.Zoomed cut
  | .right _ _ x parent => cut x = .gt ∧ parent.Zoomed cut

theorem zoom_zoomed₁ (e : zoom cut t path = (t', path')) : t'.OnRoot (cut · = .eq) :=
  match t, e with
  | nil, rfl => trivial
  | node .., e => by
    revert e; unfold zoom; split
    · exact zoom_zoomed₁
    · exact zoom_zoomed₁
    · next H => intro e; cases e; exact H

theorem zoom_zoomed₂ (e : zoom cut t path = (t', path'))
    (hp : path.Zoomed cut) : path'.Zoomed cut :=
  match t, e with
  | nil, rfl => hp
  | node .., e => by
    revert e; unfold zoom; split
    · next h => exact fun e => zoom_zoomed₂ e ⟨h, hp⟩
    · next h => exact fun e => zoom_zoomed₂ e ⟨h, hp⟩
    · intro e; cases e; exact hp

/--
`path.RootOrdered cmp v` is true if `v` would be able to fit into the hole
without violating the ordering invariant.
-/
def RootOrdered (cmp : α → α → Ordering) : Path α → α → Prop
  | .root, _ => True
  | .left _ parent x _, v => cmpLT cmp v x ∧ parent.RootOrdered cmp v
  | .right _ _ x parent, v => cmpLT cmp x v ∧ parent.RootOrdered cmp v

theorem _root_.Std.RBNode.cmpEq.RootOrdered_congr {cmp : α → α → Ordering} (h : cmpEq cmp a b) :
    ∀ {t : Path α}, t.RootOrdered cmp a ↔ t.RootOrdered cmp b
  | .root => .rfl
  | .left .. => and_congr h.lt_congr_left h.RootOrdered_congr
  | .right .. => and_congr h.lt_congr_right h.RootOrdered_congr

theorem Zoomed.toRootOrdered {cmp} :
    ∀ {path : Path α}, path.Zoomed (cmp v) → path.RootOrdered cmp v
  | .root, h => h
  | .left .., ⟨h, hp⟩ => ⟨⟨h⟩, hp.toRootOrdered⟩
  | .right .., ⟨h, hp⟩ => ⟨⟨OrientedCmp.cmp_eq_gt.1 h⟩, hp.toRootOrdered⟩

/-- The ordering invariant for a `Path`. -/
def Ordered (cmp : α → α → Ordering) : Path α → Prop
  | .root => True
  | .left _ parent x b => b.All (cmpLT cmp x ·) ∧ parent.RootOrdered cmp x ∧
    b.All (parent.RootOrdered cmp) ∧ b.Ordered cmp ∧ parent.Ordered cmp
  | .right _ a x parent => a.All (cmpLT cmp · x) ∧ parent.RootOrdered cmp x ∧
    a.All (parent.RootOrdered cmp) ∧ a.Ordered cmp ∧ parent.Ordered cmp

protected theorem Ordered.fill : ∀ {path : Path α} {t},
    (path.fill t).Ordered cmp ↔ path.Ordered cmp ∧ t.Ordered cmp ∧ t.All (path.RootOrdered cmp)
  | .root, _ => ⟨fun H => ⟨⟨⟩, H, .trivial ⟨⟩⟩, (·.2.1)⟩
  | .left .., _ => by
    simp [Ordered.fill, RBNode.Ordered, Ordered, RootOrdered, All_and]
    exact ⟨
      fun ⟨hp, ⟨ax, xb, ha, hb⟩, ⟨xp, ap, bp⟩⟩ => ⟨⟨xb, xp, bp, hb, hp⟩, ha, ⟨ax, ap⟩⟩,
      fun ⟨⟨xb, xp, bp, hb, hp⟩, ha, ⟨ax, ap⟩⟩ => ⟨hp, ⟨ax, xb, ha, hb⟩, ⟨xp, ap, bp⟩⟩⟩
  | .right .., _ => by
    simp [Ordered.fill, RBNode.Ordered, Ordered, RootOrdered, All_and]
    exact ⟨
      fun ⟨hp, ⟨ax, xb, ha, hb⟩, ⟨xp, ap, bp⟩⟩ => ⟨⟨ax, xp, ap, ha, hp⟩, hb, ⟨xb, bp⟩⟩,
      fun ⟨⟨ax, xp, ap, ha, hp⟩, hb, ⟨xb, bp⟩⟩ => ⟨hp, ⟨ax, xb, ha, hb⟩, ⟨xp, ap, bp⟩⟩⟩

theorem _root_.Std.RBNode.Ordered.zoom' {t : RBNode α} {path : Path α}
    (ht : t.Ordered cmp) (hp : path.Ordered cmp) (tp : t.All (path.RootOrdered cmp))
    (pz : path.Zoomed cut) (eq : t.zoom cut path = (t', path')) :
    t'.Ordered cmp ∧ path'.Ordered cmp ∧ t'.All (path'.RootOrdered cmp) ∧ path'.Zoomed cut :=
  have ⟨hp', ht', tp'⟩ := Ordered.fill.1 <| zoom_fill eq ▸ Ordered.fill.2 ⟨hp, ht, tp⟩
  ⟨ht', hp', tp', zoom_zoomed₂ eq pz⟩

theorem _root_.Std.RBNode.Ordered.zoom {t : RBNode α}
    (ht : t.Ordered cmp) (eq : t.zoom cut = (t', path')) :
    t'.Ordered cmp ∧ path'.Ordered cmp ∧ t'.All (path'.RootOrdered cmp) ∧ path'.Zoomed cut :=
  ht.zoom' (path := .root) ⟨⟩ (.trivial ⟨⟩) ⟨⟩ eq

theorem Ordered.ins : ∀ {path : Path α} {t : RBNode α},
    t.Ordered cmp → path.Ordered cmp → t.All (path.RootOrdered cmp) → (path.ins t).Ordered cmp
  | .root, t, ht, _, _ => Ordered.setBlack.2 ht
  | .left red parent x b, a, ha, ⟨xb, xp, bp, hb, hp⟩, H => by
    unfold ins; have ⟨ax, ap⟩ := All_and.1 H; exact hp.ins ⟨ax, xb, ha, hb⟩ ⟨xp, ap, bp⟩
  | .right red a x parent, b, hb, ⟨ax, xp, ap, ha, hp⟩, H => by
    unfold ins; have ⟨xb, bp⟩ := All_and.1 H; exact hp.ins ⟨ax, xb, ha, hb⟩ ⟨xp, ap, bp⟩
  | .left black parent x b, a, ha, ⟨xb, xp, bp, hb, hp⟩, H => by
    unfold ins; have ⟨ax, ap⟩ := All_and.1 H
    exact hp.ins (ha.balance1 ax xb hb) (balance1_All.2 ⟨xp, ap, bp⟩)
  | .right black a x parent, b, hb, ⟨ax, xp, ap, ha, hp⟩, H => by
    unfold ins; have ⟨xb, bp⟩ := All_and.1 H
    exact hp.ins (ha.balance2 ax xb hb) (balance2_All.2 ⟨xp, ap, bp⟩)

theorem Ordered.insertNew {path : Path α} (hp : path.Ordered cmp) (vp : path.RootOrdered cmp v) :
    (path.insertNew v).Ordered cmp :=
  hp.ins ⟨⟨⟩, ⟨⟩, ⟨⟩, ⟨⟩⟩ ⟨vp, ⟨⟩, ⟨⟩⟩

-- theorem Ordered.insert : ∀ {path : Path α} {t : RBNode α},
--     path.Ordered cmp → t.Ordered cmp → t.All (path.RootOrdered cmp) → path.RootOrdered cmp v →
--     t.OnRoot (cmpEq cmp v) → (path.insert t v).Ordered cmp
--   | path, nil, hp, ht, tp, vp, tv => hp.insertNew vp
--   | path, node .., hp, ⟨ax, xb, ha, hb⟩, ⟨xp, ap, bp⟩, vp, xv => Ordered.fill.2 ⟨hp, _, _⟩

end Path

/-! ## alter -/

-- /-- The `alter` function preserves the ordering invariants. -/
-- protected theorem Ordered.alter {t : RBNode α}
--     (H : ∀ {x t' p}, t.zoom cut = (t', p) → f t'.root? = some x → p.RootOrdered cmp x)
--     (h : t.Ordered cmp) : (alter cut f t).Ordered cmp := by
--   simp [alter]; split
--   · next path eq =>
--     split
--     · exact h
--     · have ⟨_, hp, _, hz⟩ := h.zoom eq
--       apply hp.insertNew
--       sorry
--   · next path eq =>
--     split
--     · sorry
--     · sorry

/-- The `alter` function preserves the balance invariants. -/
protected theorem Balanced.alter {t : RBNode α}
    (h : t.Balanced c n) : ∃ c n, (t.alter cut f).Balanced c n := by
  simp [alter]; split
  · next path eq =>
    split
    · exact ⟨_, _, h⟩
    · have ⟨_, _, .nil, h⟩ := h.zoom .root eq
      exact ⟨_, h.insertNew⟩
  · next path eq =>
    have ⟨_, _, h, hp⟩ := h.zoom .root eq
    split
    · match h with
      | .red ha hb => exact ⟨_, hp.del ((ha.append hb).of_false (· rfl rfl)) (fun.)⟩
      | .black ha hb => exact ⟨_, hp.del ⟨_, rfl, (ha.append hb).imp fun _ => ⟨⟩⟩ (fun.)⟩
    · match h with
      | .red ha hb => exact ⟨_, _, hp.fill (.red ha hb)⟩
      | .black ha hb => exact ⟨_, _, hp.fill (.black ha hb)⟩

end RBNode
