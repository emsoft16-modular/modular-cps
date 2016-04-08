Require Import Strings.String.
Require Import Coq.Reals.Rdefinitions.
Require Import Coq.Reals.RIneq.

(************************************************)
(* The syntax of differential dynamic logic.    *)
(************************************************)
Definition Var := string.
Definition Value := R.
Definition state : Type := Var -> Value.

(* Real-valued terms built using variables, constants
   and arithmetic. *)
Inductive Term :=
| VarNowT : Var -> Term
| VarNextT : Var -> Term
| NatT : nat -> Term
| RealT : R -> Term
| PlusT : Term -> Term -> Term
| MinusT : Term -> Term -> Term
| MultT : Term -> Term -> Term
| InvT : Term -> Term
| CosT : Term -> Term
| SinT : Term -> Term
| SqrtT : Term -> Term
| ArctanT : Term -> Term
| ExpT : Term -> Term
| MaxT : Term -> Term -> Term
| Unop : (R -> R) -> Term -> Term
| Binop : (R -> R -> R) -> Term -> Term -> Term
.

(* Comparison operations *)
Inductive CompOp :=
| Gt : CompOp
| Ge : CompOp
| Lt : CompOp
| Le : CompOp
| Eq : CompOp.

(* Map from variable to term. Essentially
   a refinement mapping from TLA. *)
Definition RenameMap := Var->Term.

(* Temporal formulas *)
Inductive Formula :=
| TRUE : Formula
| FALSE : Formula
| Comp : Term -> Term -> CompOp -> Formula
| And : Formula -> Formula -> Formula
| Or : Formula -> Formula -> Formula
| Imp : Formula -> Formula -> Formula
| PropF : Prop -> Formula
| Exists : forall T, (T -> Formula) -> Formula
| Forall : forall T, (T -> Formula) -> Formula
| Enabled : Formula -> Formula
| Always : Formula -> Formula
| Eventually : Formula -> Formula
| Embed : (state -> state -> Prop) -> Formula
| Rename : RenameMap -> Formula -> Formula.

(* Aliases for documentation purposes *)
Definition StateFormula := Formula.
Definition ActionFormula := Formula.

(************************************************)
(* Some notation for the logic.                 *)
(************************************************)
Delimit Scope HP_scope with HP.

(*Term notation *)
Definition NatC (n:nat) : Term :=
  NatT n.
Coercion NatC : nat >-> Term.
Definition ConstC (c:R) : Term :=
  RealT c.
Coercion ConstC : R >-> Term.
Definition VarC (x:string) : Term :=
  VarNowT x.
Coercion VarC : string >-> Term.
Notation "x !" :=
  (VarNextT x) (at level 0) : HP_scope.
Infix "+" := (PlusT) : HP_scope.
Infix "-" := (MinusT) : HP_scope.
Notation "-- x" := (MinusT (RealT R0) x)
                     (at level 0) : HP_scope.
Infix "*" := (MultT) : HP_scope.
Fixpoint pow (t : Term) (n : nat) :=
  match n with
  | O => RealT 1
  | S n => MultT t (pow t n)
  end.
Notation "t ^^ n" := (pow t n) (at level 10) : HP_scope.
Notation "/ x" := (InvT x) : HP_scope.
Notation "x / y" := (MultT x (InvT y)) : HP_scope.
Notation "cos( x )" := (CosT x).
Notation "sin( x )" := (SinT x).
Notation "exp( x )" := (ExpT x).
Notation "MAX( x1 , x2 )" := (MaxT x1 x2).
Notation "[ f ]( x )" := (Unop f x).
Notation "[ f ]( x , y )" := (Binop f x y).

(* Comparisons *)
Notation "t1 > t2" := (Comp t1 t2 Gt) : HP_scope.
Notation "t1 >= t2" := (Comp t1 t2 Ge) : HP_scope.
Notation "t1 < t2" := (Comp t1 t2 Lt) : HP_scope.
Notation "t1 <= t2" := (Comp t1 t2 Le) : HP_scope.
Notation "t1 = t2" := (Comp t1 t2 Eq) : HP_scope.
Notation "x <= y <= z" :=
  (And (Comp x y Le) (Comp y z Le)) : HP_scope.
Notation "x < y <= z" :=
  (And (Comp x y Lt) (Comp y z Le)) : HP_scope.
Notation "x <= y < z" :=
  (And (Comp x y Le) (Comp y z Lt)) : HP_scope.
Notation "x < y < z" :=
  (And (Comp x y Lt) (Comp y z Lt)) : HP_scope.

Notation "[] f" := (Always f)
                     (at level 72) : HP_scope.
Notation "<> f" := (Eventually f)
                     (at level 72) : HP_scope.

Bind Scope HP_scope with Term.
Bind Scope HP_scope with Formula.