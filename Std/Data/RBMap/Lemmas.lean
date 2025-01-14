/-
Copyright (c) 2022 Mario Carneiro. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mario Carneiro
-/
import Std.Data.RBMap.WF
import Std.Data.Nat.Lemmas
import Std.Data.List.Lemmas

/-!
# Additional lemmas for Red-black trees
-/

namespace Std
namespace RBNode
open RBColor

attribute [simp] fold foldl foldr Any forM foldlM Stream.foldl Stream.foldr

section depth

/--
`O(n)`. `depth t` is the maximum number of nodes on any path to a leaf.
It is an upper bound on most tree operations.
-/
def depth : RBNode α → Nat
  | nil => 0
  | node _ a _ b => max a.depth b.depth + 1

theorem size_lt_depth : ∀ t : RBNode α, t.size < 2 ^ t.depth
  | .nil => (by decide : 0 < 1)
  | .node _ a _ b => by
    rw [size, depth, Nat.add_right_comm, Nat.pow_succ, Nat.mul_two]
    refine Nat.add_le_add
      (Nat.lt_of_lt_of_le a.size_lt_depth ?_) (Nat.lt_of_lt_of_le b.size_lt_depth ?_)
    · exact Nat.pow_le_pow_of_le_right (by decide) (Nat.le_max_left ..)
    · exact Nat.pow_le_pow_of_le_right (by decide) (Nat.le_max_right ..)

/--
`depthLB c n` is the best upper bound on the depth of any balanced red-black tree
with root colored `c` and black-height `n`.
-/
def depthLB : RBColor → Nat → Nat
  | red, n => n + 1
  | black, n => n

theorem depthLB_le : ∀ c n, n ≤ depthLB c n
  | red, _ => Nat.le_succ _
  | black, _ => Nat.le_refl _

/--
`depthUB c n` is the best upper bound on the depth of any balanced red-black tree
with root colored `c` and black-height `n`.
-/
def depthUB : RBColor → Nat → Nat
  | red, n => 2 * n + 1
  | black, n => 2 * n

theorem depthUB_le : ∀ c n, depthUB c n ≤ 2 * n + 1
  | red, _ => Nat.le_refl _
  | black, _ => Nat.le_succ _

theorem depthUB_le_two_depthLB : ∀ c n, depthUB c n ≤ 2 * depthLB c n
  | red, _ => Nat.le_succ _
  | black, _ => Nat.le_refl _

theorem Balanced.depth_le : @Balanced α t c n → t.depth ≤ depthUB c n
  | .nil => Nat.le_refl _
  | .red hl hr => Nat.succ_le_succ <| Nat.max_le.2 ⟨hl.depth_le, hr.depth_le⟩
  | .black hl hr => Nat.succ_le_succ <| Nat.max_le.2
    ⟨Nat.le_trans hl.depth_le (depthUB_le ..), Nat.le_trans hr.depth_le (depthUB_le ..)⟩

theorem Balanced.le_size : @Balanced α t c n → 2 ^ depthLB c n ≤ t.size + 1
  | .nil => Nat.le_refl _
  | .red hl hr => by
    rw [size, Nat.add_right_comm (size _), Nat.add_assoc, depthLB, Nat.pow_succ, Nat.mul_two]
    exact Nat.add_le_add hl.le_size hr.le_size
  | .black hl hr => by
    rw [size, Nat.add_right_comm (size _), Nat.add_assoc, depthLB, Nat.pow_succ, Nat.mul_two]
    refine Nat.add_le_add (Nat.le_trans ?_ hl.le_size) (Nat.le_trans ?_ hr.le_size) <;>
      exact Nat.pow_le_pow_of_le_right (by decide) (depthLB_le ..)

theorem Balanced.depth_bound (h : @Balanced α t c n) : t.depth ≤ 2 * (t.size + 1).log2 :=
  Nat.le_trans h.depth_le <| Nat.le_trans (depthUB_le_two_depthLB ..) <|
    Nat.mul_le_mul_left _ <| (Nat.le_log2 (Nat.succ_ne_zero _)).2 h.le_size

/--
A well formed tree has `t.depth ∈ O(log t.size)`, that is, it is well balanced.
This justifies the `O(log n)` bounds on most searching operations of `RBSet`.
-/
theorem WF.depth_bound {t : RBNode α} (h : t.WF cmp) : t.depth ≤ 2 * (t.size + 1).log2 :=
  let ⟨_, _, h⟩ := h.out.2; h.depth_bound

end depth

@[simp] theorem mem_nil {x} : ¬x ∈ (.nil : RBNode α) := by simp [(·∈·), EMem]
@[simp] theorem mem_node {y c a x b} :
    y ∈ (.node c a x b : RBNode α) ↔ y = x ∨ y ∈ a ∨ y ∈ b := by simp [(·∈·), EMem]

theorem All_def {t : RBNode α} : t.All p ↔ ∀ x ∈ t, p x := by
  induction t <;> simp [or_imp, forall_and, *]

theorem Any_def {t : RBNode α} : t.Any p ↔ ∃ x ∈ t, p x := by
  induction t <;> simp [or_and_right, exists_or, *]

theorem memP_def : MemP cut t ↔ ∃ x ∈ t, cut x = .eq := Any_def

theorem mem_def : Mem cmp x t ↔ ∃ y ∈ t, cmp x y = .eq := Any_def

/--
A cut is like a homomorphism of orderings: it is a monotonic predicate with respect to `cmp`,
but it can make things that are distinguished by `cmp` equal.
This is sufficient for `find?` to locate an element on which `cut` returns `.eq`,
but there may be other elements, not returned by `find?`, on which `cut` also returns `.eq`.
-/
class IsCut (cmp : α → α → Ordering) (cut : α → Ordering) : Prop where
  /-- The set `{x | cut x = .lt}` is downward-closed. -/
  le_lt_trans [TransCmp cmp] : cmp x y ≠ .gt → cut x = .lt → cut y = .lt
  /-- The set `{x | cut x = .gt}` is upward-closed. -/
  le_gt_trans [TransCmp cmp] : cmp x y ≠ .gt → cut y = .gt → cut x = .gt

theorem IsCut.lt_trans [IsCut cmp cut] [TransCmp cmp]
    (H : cmp x y = .lt) : cut x = .lt → cut y = .lt :=
  IsCut.le_lt_trans <| TransCmp.gt_asymm <| OrientedCmp.cmp_eq_gt.2 H

theorem IsCut.gt_trans [IsCut cmp cut] [TransCmp cmp]
    (H : cmp x y = .lt) : cut y = .gt → cut x = .gt :=
  IsCut.le_gt_trans <| TransCmp.gt_asymm <| OrientedCmp.cmp_eq_gt.2 H

theorem IsCut.congr [IsCut cmp cut] [TransCmp cmp] (H : cmp x y = .eq) : cut x = cut y := by
  cases ey : cut y
  · exact IsCut.le_lt_trans (fun h => nomatch H.symm.trans <| OrientedCmp.cmp_eq_gt.1 h) ey
  · cases ex : cut x
    · exact IsCut.le_lt_trans (fun h => nomatch H.symm.trans h) ex |>.symm.trans ey
    · rfl
    · refine IsCut.le_gt_trans (cmp := cmp) (fun h => ?_) ex |>.symm.trans ey
      cases H.symm.trans <| OrientedCmp.cmp_eq_gt.1 h
  · exact IsCut.le_gt_trans (fun h => nomatch H.symm.trans h) ey

/--
`IsStrictCut` upgrades the `IsCut` property to ensure that at most one element of the tree
can match the cut, and hence `find?` will return the unique such element if one exists.
-/
class IsStrictCut (cmp : α → α → Ordering) (cut : α → Ordering) extends IsCut cmp cut : Prop where
  /-- If `cut = x`, then `cut` and `x` have compare the same with respect to other elements. -/
  exact [TransCmp cmp] : cut x = .eq → cmp x y = cut y

/-- A "representable cut" is one generated by `cmp a` for some `a`. This is always a valid cut. -/
instance (cmp) (a : α) : IsStrictCut cmp (cmp a) where
  le_lt_trans h₁ h₂ := TransCmp.lt_le_trans h₂ h₁
  le_gt_trans h₁ := Decidable.not_imp_not.1 (TransCmp.le_trans · h₁)
  exact h := (TransCmp.cmp_congr_left h).symm

section find?

theorem find?_some_eq_eq {t : RBNode α} : x ∈ t.find? cut → cut x = .eq := by
  induction t <;> simp [find?] <;> split <;> try assumption
  intro | rfl => assumption

theorem find?_some_mem {t : RBNode α} : x ∈ t.find? cut → x ∈ t := by
  induction t <;> simp [find?] <;> split <;> simp (config := {contextual := true}) [*]

theorem find?_some_memP {t : RBNode α} (h : x ∈ t.find? cut) : MemP cut t :=
  memP_def.2 ⟨_, find?_some_mem h, find?_some_eq_eq h⟩

theorem Ordered.memP_iff_find? [@TransCmp α cmp] [IsCut cmp cut] (ht : Ordered cmp t) :
    MemP cut t ↔ ∃ x, x ∈ t.find? cut := by
  refine ⟨fun H => ?_, fun ⟨x, h⟩ => find?_some_memP h⟩
  induction t with simp [find?] at H ⊢
  | nil => cases H
  | node _ l _ r ihl ihr =>
    let ⟨lx, xr, hl, hr⟩ := ht
    split
    · next ev =>
      refine ihl hl ?_
      rcases H with ev' | hx | hx
      · cases ev.symm.trans ev'
      · exact hx
      · have ⟨z, hz, ez⟩ := Any_def.1 hx
        cases ez.symm.trans <| IsCut.lt_trans (All_def.1 xr _ hz).1 ev
    · next ev =>
      refine ihr hr ?_
      rcases H with ev' | hx | hx
      · cases ev.symm.trans ev'
      · have ⟨z, hz, ez⟩ := Any_def.1 hx
        cases ez.symm.trans <| IsCut.gt_trans (All_def.1 lx _ hz).1 ev
      · exact hx
    · exact ⟨_, rfl⟩

theorem Ordered.unique [@TransCmp α cmp] (ht : Ordered cmp t)
    (hx : x ∈ t) (hy : y ∈ t) (e : cmp x y = .eq) : x = y := by
  induction t with
  | nil => cases hx
  | node _ l _ r ihl ihr =>
    let ⟨lx, xr, hl, hr⟩ := ht
    rcases hx, hy with ⟨rfl | hx | hx, rfl | hy | hy⟩
    · rfl
    · cases e.symm.trans <| OrientedCmp.cmp_eq_gt.2 (All_def.1 lx _ hy).1
    · cases e.symm.trans (All_def.1 xr _ hy).1
    · cases e.symm.trans (All_def.1 lx _ hx).1
    · exact ihl hl hx hy
    · cases e.symm.trans ((All_def.1 lx _ hx).trans (All_def.1 xr _ hy)).1
    · cases e.symm.trans <| OrientedCmp.cmp_eq_gt.2 (All_def.1 xr _ hx).1
    · cases e.symm.trans <| OrientedCmp.cmp_eq_gt.2
        ((All_def.1 lx _ hy).trans (All_def.1 xr _ hx)).1
    · exact ihr hr hx hy

theorem Ordered.mem_find? [@TransCmp α cmp] [IsStrictCut cmp cut] (ht : Ordered cmp t) :
    x ∈ t.find? cut ↔ x ∈ t ∧ cut x = .eq := by
  refine ⟨fun h => ⟨find?_some_mem h, find?_some_eq_eq h⟩, fun ⟨hx, e⟩ => ?_⟩
  have ⟨y, hy⟩ := ht.memP_iff_find?.1 (memP_def.2 ⟨_, hx, e⟩)
  exact ht.unique hx (find?_some_mem hy) ((IsStrictCut.exact e).trans (find?_some_eq_eq hy)) ▸ hy

end find?

section lowerBound?

/-- The value `x` returned by `lowerBound?` is less or equal to the `cut`. -/
theorem lowerBound?_le' {t : RBNode α} (H : ∀ {x}, x ∈ lb → cut x ≠ .lt) :
    x ∈ t.lowerBound? cut lb → cut x ≠ .lt := by
  induction t generalizing lb with
  | nil => exact H
  | node _ _ _ _ ihl ihr =>
    simp [lowerBound?]; split
    · exact ihl H
    · next hv => exact ihr fun | rfl, e => nomatch hv.symm.trans e
    · next hv => intro | rfl, e => cases hv.symm.trans e

/-- The value `x` returned by `lowerBound?` is less or equal to the `cut`. -/
theorem lowerBound?_le {t : RBNode α} : x ∈ t.lowerBound? cut none → cut x ≠ .lt :=
  lowerBound?_le' (fun.)

theorem All.lowerBound?_lb {t : RBNode α} (hp : t.All p) (H : ∀ {x}, x ∈ lb → p x) :
    x ∈ t.lowerBound? cut lb → p x := by
  induction t generalizing lb with
  | nil => exact H
  | node _ _ _ _ ihl ihr =>
    simp [lowerBound?]; split
    · exact ihl hp.2.1 H
    · exact ihr hp.2.2 fun | rfl => hp.1
    · exact fun | rfl => hp.1

theorem All.lowerBound? {t : RBNode α} (hp : t.All p) : x ∈ t.lowerBound? cut none → p x :=
  hp.lowerBound?_lb (fun.)

theorem lowerBound?_mem_lb {t : RBNode α}
    (h : x ∈ t.lowerBound? cut lb) : x ∈ t ∨ x ∈ lb :=
  All.lowerBound?_lb (p := fun x => x ∈ t ∨ x ∈ lb) (All_def.2 fun _ => .inl) Or.inr h

theorem lowerBound?_mem {t : RBNode α} (h : x ∈ t.lowerBound? cut none) : x ∈ t :=
  (lowerBound?_mem_lb h).resolve_right (fun.)

theorem lowerBound?_of_some {t : RBNode α} : ∃ x, x ∈ t.lowerBound? cut (some y) := by
  simp; induction t generalizing y <;> simp [lowerBound?]; split <;> simp [*]

theorem Ordered.lowerBound?_exists [@TransCmp α cmp] [IsCut cmp cut] (h : Ordered cmp t) :
    (∃ x, x ∈ t.lowerBound? cut none) ↔ ∃ x ∈ t, cut x ≠ .lt := by
  refine ⟨fun ⟨x, hx⟩ => ⟨_, lowerBound?_mem hx, lowerBound?_le hx⟩, fun H => ?_⟩
  obtain ⟨x, hx, e⟩ := H
  induction t generalizing x with
  | nil => cases hx
  | node _ _ _ _ ihl =>
    simp [lowerBound?]; split
    · rcases hx with rfl | hx | hx
      · contradiction
      · exact ihl h.2.2.1 _ hx e
      · next hv => cases e <| IsCut.lt_trans (All_def.1 h.2.1 _ hx).1 hv
    · exact lowerBound?_of_some
    · exact ⟨_, rfl⟩

theorem Ordered.lowerBound?_least_lb [@TransCmp α cmp] [IsCut cmp cut] (h : Ordered cmp t)
    (hlb : ∀ {x}, x ∈ lb → t.All (cmpLT cmp x ·)) :
    x ∈ t.lowerBound? cut lb → y ∈ t → cut x = .gt → cmp x y = .lt → cut y = .lt := by
  induction t generalizing lb with
  | nil => intro.
  | node _ _ _ _ ihl ihr =>
    simp [lowerBound?]; split <;> rename_i hv <;> rintro h₁ (rfl | hy' | hy') hx h₂
    · exact hv
    · exact ihl h.2.2.1 (fun h => (hlb h).2.1) h₁ hy' hx h₂
    · exact IsCut.lt_trans (cut := cut) (cmp := cmp) (All_def.1 h.2.1 _ hy').1 hv
    · rcases lowerBound?_mem_lb h₁ with h₁ | ⟨⟨⟩⟩
      · cases TransCmp.lt_asymm h₂ (All_def.1 h.2.1 _ h₁).1
      · cases TransCmp.lt_asymm h₂ h₂
    · refine (TransCmp.lt_asymm h₂ ?_).elim; have := (All_def.1 h.1 _ hy').1
      rcases lowerBound?_mem_lb h₁ with h₁ | ⟨⟨⟩⟩
      · exact TransCmp.lt_trans this (All_def.1 h.2.1 _ h₁).1
      · exact this
    · exact ihr h.2.2.2 (by rintro _ ⟨⟨⟩⟩; exact h.2.1) h₁ hy' hx h₂
    · cases h₁; cases TransCmp.lt_asymm h₂ h₂
    · cases h₁; cases hx.symm.trans hv
    · cases h₁; cases hx.symm.trans hv

/--
A statement of the least-ness of the result of `lowerBound?`. If `x` is the return value of
`lowerBound?` and it is strictly less than the cut, then any other `y > x` in the tree is in fact
strictly greater than the cut (so there is no exact match, and nothing closer to the cut).
-/
theorem Ordered.lowerBound?_least [@TransCmp α cmp] [IsCut cmp cut] (ht : Ordered cmp t)
    (H : x ∈ t.lowerBound? cut none) (hy : y ∈ t)
    (xy : cmp x y = .lt) (hx : cut x = .gt) : cut y = .lt :=
  ht.lowerBound?_least_lb (by exact fun.) H hy hx xy

theorem Ordered.memP_iff_lowerBound? [@TransCmp α cmp] [IsCut cmp cut] (ht : Ordered cmp t) :
    t.MemP cut ↔ ∃ x ∈ t.lowerBound? cut none, cut x = .eq := by
  refine memP_def.trans ⟨fun ⟨y, hy, ey⟩ => ?_, fun ⟨x, hx, e⟩ => ⟨_, lowerBound?_mem hx, e⟩⟩
  have ⟨x, hx⟩ := ht.lowerBound?_exists.2 ⟨_, hy, fun h => nomatch ey.symm.trans h⟩
  refine ⟨x, hx, ?_⟩; cases ex : cut x
  · cases lowerBound?_le hx ex
  · rfl
  · cases e : cmp x y
    · cases ey.symm.trans <| ht.lowerBound?_least hx hy e ex
    · cases ey.symm.trans <| IsCut.congr e |>.symm.trans ex
    · cases ey.symm.trans <| IsCut.gt_trans (OrientedCmp.cmp_eq_gt.1 e) ex

/-- A stronger version of `lowerBound?_least` that holds when the cut is strict. -/
theorem Ordered.lowerBound?_lt [@TransCmp α cmp] [IsStrictCut cmp cut] (ht : Ordered cmp t)
    (H : x ∈ t.lowerBound? cut none) (hy : y ∈ t) : cmp x y = .lt ↔ cut y = .lt := by
  refine ⟨fun h => ?_, fun h => OrientedCmp.cmp_eq_gt.1 ?_⟩
  · cases e : cut x
    · cases lowerBound?_le H e
    · exact IsStrictCut.exact e |>.symm.trans h
    · exact ht.lowerBound?_least H hy h e
  · by_contra h'; exact lowerBound?_le H <| IsCut.le_lt_trans (cmp := cmp) (cut := cut) h' h

end lowerBound?

section fold

theorem foldr_cons (t : RBNode α) (l) : t.foldr (·::·) l = t.toList ++ l := by
  unfold toList
  induction t generalizing l with
  | nil => rfl
  | node _ a _ b iha ihb => rw [foldr, foldr, iha, iha (_::_), ihb]; simp

@[simp] theorem toList_nil : (.nil : RBNode α).toList = [] := rfl

@[simp] theorem toList_node : (.node c a x b : RBNode α).toList = a.toList ++ x :: b.toList := by
  rw [toList, foldr, foldr_cons]; rfl

@[simp] theorem mem_toList {t : RBNode α} : x ∈ t.toList ↔ x ∈ t := by
  induction t <;> simp [*, or_left_comm]

theorem foldr_eq_foldr_toList {t : RBNode α} : t.foldr f init = t.toList.foldr f init := by
  induction t generalizing init <;> simp [*]

theorem foldl_eq_foldl_toList {t : RBNode α} : t.foldl f init = t.toList.foldl f init := by
  induction t generalizing init <;> simp [*]

theorem forM_eq_forM_toList [Monad m] [LawfulMonad m] {t : RBNode α} :
    t.forM (m := m) f = t.toList.forM f := by induction t <;> simp [*]

theorem foldlM_eq_foldlM_toList [Monad m] [LawfulMonad m] {t : RBNode α} :
    t.foldlM (m := m) f init = t.toList.foldlM f init := by
  induction t generalizing init <;> simp [*]

theorem forIn_visit_eq_bindList [Monad m] [LawfulMonad m] {t : RBNode α} :
    forIn.visit (m := m) f t init = (ForInStep.yield init).bindList f t.toList := by
  induction t generalizing init <;> simp [*, forIn.visit]

theorem forIn_eq_forIn_toList [Monad m] [LawfulMonad m] {t : RBNode α} :
    forIn (m := m) t init f = forIn t.toList init f := by
  simp [forIn, RBNode.forIn]; rw [List.forIn_eq_bindList, forIn_visit_eq_bindList]

end fold

namespace Stream

theorem foldr_cons (t : RBNode.Stream α) (l) : t.foldr (·::·) l = t.toList ++ l := by
  unfold toList; apply Eq.symm; induction t <;> simp [*, foldr, RBNode.foldr_cons]

@[simp] theorem toList_nil : (.nil : RBNode.Stream α).toList = [] := rfl

@[simp] theorem toList_cons :
    (.cons x r s : RBNode.Stream α).toList = x :: r.toList ++ s.toList := by
  rw [toList, toList, foldr, RBNode.foldr_cons]; rfl

theorem foldr_eq_foldr_toList {s : RBNode.Stream α} : s.foldr f init = s.toList.foldr f init := by
  induction s <;> simp [-List.foldr] <;> simp [*, RBNode.foldr_eq_foldr_toList]

theorem foldl_eq_foldl_toList {t : RBNode.Stream α} : t.foldl f init = t.toList.foldl f init := by
  induction t generalizing init <;> simp [-List.foldl] <;> simp [*, RBNode.foldl_eq_foldl_toList]

theorem forIn_eq_forIn_toList [Monad m] [LawfulMonad m] {t : RBNode α} :
    forIn (m := m) t init f = forIn t.toList init f := by
  simp [forIn, RBNode.forIn]; rw [List.forIn_eq_bindList, forIn_visit_eq_bindList]

end Stream

theorem toStream_toList' {t : RBNode α} {s} : (t.toStream s).toList = t.toList ++ s.toList := by
  induction t generalizing s <;> simp [*, toStream]

@[simp] theorem toStream_toList {t : RBNode α} : t.toStream.toList = t.toList := by
  simp [toStream_toList']

theorem Stream.next?_toList {s : RBNode.Stream α} :
    (s.next?.map fun (a, b) => (a, b.toList)) = s.toList.next? := by
  cases s <;> simp [next?, toStream_toList']

theorem Ordered.toList_sorted {t : RBNode α} (h : t.Ordered cmp) :
    t.toList.Pairwise (cmpLT cmp) := by
  induction t with
  | nil => simp
  | node c l v r ihl ihr =>
    simp_all [List.pairwise_append, Ordered, All_def]
    exact fun a ha b hb => (h.1 _ ha).trans (h.2.1 _ hb)
