/-
Copyright (c) 2022 Mario Carneiro. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Mario Carneiro
-/
import Std.Data.Nat.Gcd
import Std.Data.Int.DivMod
import Std.Tactic.Ext

/-! # Basics for the Rational Numbers -/

/--
Rational numbers, implemented as a pair of integers `num / den` such that the
denominator is positive and the numerator and denominator are coprime.
-/
@[ext] structure Rat where
  /-- The numerator of the rational number is an integer. -/
  num : Int
  /-- The denominator of the rational number is a natural number. -/
  den : Nat := 1
  /-- The denominator is nonzero. -/
  den_nz : den ≠ 0 := by decide
  /-- The numerator and denominator are coprime: it is in "reduced form". -/
  reduced : num.natAbs.coprime den := by decide
  deriving DecidableEq

instance : Inhabited Rat := ⟨{ num := 0 }⟩

instance : ToString Rat where
  toString a := if a.den = 1 then toString a.num else s!"{a.num}/{a.den}"

instance : Repr Rat where
  reprPrec a _ := if a.den = 1 then repr a.num else s!"({a.num} : Rat)/{a.den}"

theorem Rat.den_pos (self : Rat) : 0 < self.den := Nat.pos_of_ne_zero self.den_nz

/--
Auxiliary definition for `Rat.normalize`. Constructs `num / den` as a rational number,
dividing both `num` and `den` by `g` (which is the gcd of the two) if it is not 1.
-/
@[inline] def Rat.maybeNormalize (num : Int) (den g : Nat)
    (den_nz : den / g ≠ 0) (reduced : (num / g).natAbs.coprime (den / g)) : Rat :=
  if hg : g = 1 then
    { num, den
      den_nz := by simp [hg] at den_nz; exact den_nz
      reduced := by simp [hg, Int.natAbs_ofNat] at reduced; exact reduced }
  else { num := num / g, den := den / g, den_nz, reduced }

theorem Rat.normalize.den_nz {num : Int} {den g : Nat} (den_nz : den ≠ 0)
    (e : g = num.natAbs.gcd den) : den / g ≠ 0 :=
  e ▸ Nat.ne_of_gt (Nat.div_gcd_pos_of_pos_right _ (Nat.pos_of_ne_zero den_nz))

theorem Rat.normalize.reduced {num : Int} {den g : Nat} (den_nz : den ≠ 0)
    (e : g = num.natAbs.gcd den) : (num / g).natAbs.coprime (den / g) :=
  have : Int.natAbs (num / ↑g) = num.natAbs / g := by
    match num, num.eq_nat_or_neg with
    | _, ⟨_, .inl rfl⟩ => rfl
    | _, ⟨_, .inr rfl⟩ => rw [Int.neg_div, Int.natAbs_neg, Int.natAbs_neg]; rfl
  this ▸ e ▸ Nat.coprime_div_gcd_div_gcd (Nat.gcd_pos_of_pos_right _ (Nat.pos_of_ne_zero den_nz))

/--
Construct a normalized `Rat` from a numerator and nonzero denominator.
This is a "smart constructor" that divides the numerator and denominator by
the gcd to ensure that the resulting rational number is normalized.
-/
@[inline] def Rat.normalize (num : Int) (den : Nat := 1) (den_nz : den ≠ 0 := by decide) : Rat :=
  Rat.maybeNormalize num den (num.natAbs.gcd den)
    (normalize.den_nz den_nz rfl) (normalize.reduced den_nz rfl)

/--
Construct a rational number from a numerator and denominator.
This is a "smart constructor" that divides the numerator and denominator by
the gcd to ensure that the resulting rational number is normalized, and returns
zero if `den` is zero.
-/
def mkRat (num : Int) (den : Nat) : Rat :=
  if den_nz : den = 0 then { num := 0 } else Rat.normalize num den den_nz

namespace Rat

/-- Embedding of `Int` in the rational numbers. -/
@[coe] def ofInt (num : Int) : Rat := { num, reduced := Nat.coprime_one_right _ }

instance : Coe Int Rat := ⟨ofInt⟩

instance : OfNat Rat n := ⟨n⟩

/-- Is this rational number integral? -/
@[inline] protected def isInt (a : Rat) : Bool := a.den == 1

/-- Implements "scientific notation" `123.4e-5` for rational numbers. -/
protected def ofScientific (m : Nat) (s : Bool) (e : Nat) : Rat :=
  if s then
    Rat.normalize m (10 ^ e) <| Nat.ne_of_gt <| Nat.pos_pow_of_pos _ (by decide)
  else
    (m * 10 ^ e : Nat)

instance : OfScientific Rat where ofScientific := Rat.ofScientific

/-- Rational number strictly less than relation, as a `Bool`. -/
protected def blt (a b : Rat) : Bool :=
  if a.num < 0 && 0 ≤ b.num then
    true
  else if a.num = 0 then
    0 < b.num
  else if 0 < a.num && b.num ≤ 0 then
    false
  else
    -- `a` and `b` must have the same sign
   a.num * b.den < b.num * a.den

instance : LT Rat := ⟨(·.blt ·)⟩

instance (a b : Rat) : Decidable (a < b) :=
  inferInstanceAs (Decidable (_ = true))

instance : LE Rat := ⟨fun a b => b.blt a = false⟩

instance (a b : Rat) : Decidable (a ≤ b) :=
  inferInstanceAs (Decidable (_ = false))

/-- Multiplication of rational numbers. -/
protected def mul (a b : Rat) : Rat :=
  let g1 := Nat.gcd a.den b.num.natAbs
  let g2 := Nat.gcd a.num.natAbs b.den
  { num := (a.num / g2) * (b.num / g1)
    den := (b.den / g2) * (a.den / g1)
    den_nz := Nat.ne_of_gt <| Nat.mul_pos
      (Nat.div_gcd_pos_of_pos_right _ b.den_pos) (Nat.div_gcd_pos_of_pos_left _ a.den_pos)
    reduced := by
      simp only [Int.natAbs_mul, Int.natAbs_div, Nat.coprime_mul_iff_left]
      refine ⟨Nat.coprime_mul_iff_right.2 ⟨?_, ?_⟩, Nat.coprime_mul_iff_right.2 ⟨?_, ?_⟩⟩
      · exact Nat.coprime_div_gcd_div_gcd (Nat.gcd_pos_of_pos_right _ b.den_pos)
      · exact a.reduced.coprime_div_left (Nat.gcd_dvd_left ..)
          |>.coprime_div_right (Nat.gcd_dvd_left ..)
      · exact b.reduced.coprime_div_left (Nat.gcd_dvd_right ..)
          |>.coprime_div_right (Nat.gcd_dvd_right ..)
      · exact (Nat.coprime_div_gcd_div_gcd (Nat.gcd_pos_of_pos_left _ a.den_pos)).symm }

instance : Mul Rat := ⟨Rat.mul⟩

/-- The inverse of a rational number. Note: `inv 0 = 0`. -/
protected def inv (a : Rat) : Rat :=
  if h : a.num < 0 then
    { num := -a.den, den := a.num.natAbs
      den_nz := Nat.ne_of_gt (Int.natAbs_pos.2 (Int.ne_of_lt h))
      reduced := Int.natAbs_neg a.den ▸ a.reduced.symm }
  else if h : a.num > 0 then
    { num := a.den, den := a.num.natAbs
      den_nz := Nat.ne_of_gt (Int.natAbs_pos.2 (Int.ne_of_gt h))
      reduced := a.reduced.symm }
  else
    a

/-- Division of rational numbers. Note: `div a 0 = 0`. -/
instance : Div Rat := ⟨(· * ·.inv)⟩

theorem add.aux (a b : Rat) {g ad bd} (hg : g = a.den.gcd b.den)
    (had : ad = a.den / g) (hbd : bd = b.den / g) :
    let den := ad * b.den; let num := bd * a.num + ad * b.num
    num.natAbs.gcd g = num.natAbs.gcd den := by
  intro den num
  have ae : ad * g = a.den := had ▸ Nat.div_mul_cancel (hg ▸ Nat.gcd_dvd_left ..)
  have be : bd * g = b.den := hbd ▸ Nat.div_mul_cancel (hg ▸ Nat.gcd_dvd_right ..)
  have hden : den = ad * bd * g := by rw [Nat.mul_assoc, be]
  rw [hden, Nat.coprime.gcd_mul_left_cancel_right]
  have cop : ad.coprime bd := had ▸ hbd ▸ hg ▸
    Nat.coprime_div_gcd_div_gcd (Nat.gcd_pos_of_pos_left _ a.den_pos)
  have H1 (d : Nat) :
      d.gcd num.natAbs ∣ bd * a.num.natAbs ↔ d.gcd num.natAbs ∣ ad * b.num.natAbs := by
    have := d.gcd_dvd_right num.natAbs
    rw [← Int.ofNat_dvd, Int.dvd_natAbs] at this
    have := Int.dvd_iff_dvd_of_dvd_add this
    rwa [← Int.dvd_natAbs, Int.ofNat_dvd, Int.natAbs_mul,
      ← Int.dvd_natAbs, Int.ofNat_dvd, Int.natAbs_mul] at this
  apply Nat.coprime.mul
  · have := (H1 ad).2 <| Nat.dvd_trans (Nat.gcd_dvd_left ..) (Nat.dvd_mul_right ..)
    have := (cop.coprime_dvd_left <| Nat.gcd_dvd_left ..).dvd_of_dvd_mul_left this
    exact Nat.eq_one_of_dvd_one <| a.reduced.gcd_eq_one ▸ Nat.dvd_gcd this <|
      Nat.dvd_trans (Nat.gcd_dvd_left ..) (ae ▸ Nat.dvd_mul_right ..)
  · have := (H1 bd).1 <| Nat.dvd_trans (Nat.gcd_dvd_left ..) (Nat.dvd_mul_right ..)
    have := (cop.symm.coprime_dvd_left <| Nat.gcd_dvd_left ..).dvd_of_dvd_mul_left this
    exact Nat.eq_one_of_dvd_one <| b.reduced.gcd_eq_one ▸ Nat.dvd_gcd this <|
      Nat.dvd_trans (Nat.gcd_dvd_left ..) (be ▸ Nat.dvd_mul_right ..)

/-- Addition of rational numbers. -/
protected def add (a b : Rat) : Rat :=
  let g := a.den.gcd b.den
  if hg : g = 1 then
    have den_nz := Nat.ne_of_gt <| Nat.mul_pos a.den_pos b.den_pos
    have reduced := add.aux a b hg.symm (Nat.div_one _).symm (Nat.div_one _).symm
      |>.symm.trans (Nat.gcd_one_right _)
    { num := b.den * a.num + a.den * b.num, den := a.den * b.den, den_nz, reduced }
  else
    let den := (a.den / g) * b.den
    let num := ↑(b.den / g) * a.num + ↑(a.den / g) * b.num
    let g1  := num.natAbs.gcd g
    have den_nz := Nat.ne_of_gt <| Nat.mul_pos (Nat.div_gcd_pos_of_pos_left _ a.den_pos) b.den_pos
    have e : g1 = num.natAbs.gcd den := add.aux a b rfl rfl rfl
    Rat.maybeNormalize num den g1 (normalize.den_nz den_nz e) (normalize.reduced den_nz e)

instance : Add Rat := ⟨Rat.add⟩

/-- Negation of rational numbers. -/
protected def neg (a : Rat) : Rat :=
  { a with num := -a.num, reduced := by rw [Int.natAbs_neg]; exact a.reduced }

instance : Neg Rat := ⟨Rat.neg⟩

theorem sub.aux (a b : Rat) {g ad bd} (hg : g = a.den.gcd b.den)
    (had : ad = a.den / g) (hbd : bd = b.den / g) :
    let den := ad * b.den; let num := bd * a.num - ad * b.num
    num.natAbs.gcd g = num.natAbs.gcd den := by
  have := add.aux a (-b) hg had hbd
  simp only [show (-b).num = -b.num from rfl, Int.mul_neg] at this
  exact this

/-- Subtraction of rational numbers. -/
protected def sub (a b : Rat) : Rat :=
  let g := a.den.gcd b.den
  if hg : g = 1 then
    have den_nz := Nat.ne_of_gt <| Nat.mul_pos a.den_pos b.den_pos
    have reduced := sub.aux a b hg.symm (Nat.div_one _).symm (Nat.div_one _).symm
      |>.symm.trans (Nat.gcd_one_right _)
    { num := b.den * a.num - a.den * b.num, den := a.den * b.den, den_nz, reduced }
  else
    let den := (a.den / g) * b.den
    let num := ↑(b.den / g) * a.num - ↑(a.den / g) * b.num
    let g1  := num.natAbs.gcd g
    have den_nz := Nat.ne_of_gt <| Nat.mul_pos (Nat.div_gcd_pos_of_pos_left _ a.den_pos) b.den_pos
    have e : g1 = num.natAbs.gcd den := sub.aux a b rfl rfl rfl
    Rat.maybeNormalize num den g1 (normalize.den_nz den_nz e) (normalize.reduced den_nz e)

instance : Sub Rat := ⟨Rat.sub⟩

/-- The floor of a rational number `a` is the largest integer less than or equal to `a`. -/
protected def floor (a : Rat) : Int :=
  if a.den = 1 then
    a.num
  else
    let r := a.num / a.den
    if a.num < 0 then r - 1 else r

/-- The ceiling of a rational number `a` is the smallest integer greater than or equal to `a`. -/
protected def ceil (a : Rat) : Int :=
  if a.den = 1 then
    a.num
  else
    let r := a.num / a.den
    if a.num > 0 then r + 1 else r