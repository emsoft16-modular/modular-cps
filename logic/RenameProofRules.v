Require Import Coq.Lists.List.
Require Import Coq.Classes.Morphisms.
Require Import Logic.Syntax.
Require Import Logic.Semantics.
Require Import Logic.Automation.
Require Import Logic.BasicProofRules.

Local Open Scope HP_scope.

(* Some renaming functions and proof rules. *)
Fixpoint rename_term (m : RenameMap) (t:Term) :=
  match t with
  | NatT n => NatT n
  | RealT r => RealT r
  | VarNowT x => m x
  | VarNextT x => next_term (m x)
  | PlusT t1 t2 => PlusT (rename_term m t1)
                         (rename_term m t2)
  | MinusT t1 t2 => MinusT (rename_term m t1)
                           (rename_term m t2)
  | MultT t1 t2 => MultT (rename_term m t1)
                         (rename_term m t2)
  | InvT t => InvT (rename_term m t)
  | CosT t => CosT (rename_term m t)
  | SinT t => SinT (rename_term m t)
  | SqrtT t => SqrtT (rename_term m t)
  | ArctanT t => ArctanT (rename_term m t)
  | ExpT t => ExpT (rename_term m t)
  | MaxT t1 t2 => MaxT (rename_term m t1)
                       (rename_term m t2)
  | Unop f t => Unop f (rename_term m t)
  | Binop f t1 t2 => Binop f (rename_term m t1)
                           (rename_term m t2)
  end.

Definition RenameMap_compose (m m' : RenameMap) : RenameMap :=
  fun x => rename_term m (m' x).

Arguments RenameMap_compose _ _ _ /.

Fixpoint rename_formula (m : RenameMap) (F:Formula) :=
  match F with
  | TRUE => ltrue
  | FALSE => lfalse
  | Comp t1 t2 op => Comp (rename_term m t1)
                          (rename_term m t2) op
  | And F1 F2 => rename_formula m F1 //\\ rename_formula m F2
  | Or F1 F2 => rename_formula m F1 \\// rename_formula m F2
  | Imp F1 F2 => rename_formula m F1 -->> rename_formula m F2
  | Syntax.Exists _ f => Exists x, rename_formula m (f x)
  | Syntax.Forall _ f => Forall x, rename_formula m (f x)
  | PropF P => PropF P
  | Enabled F => Rename m (Enabled F)
  | Always F => Always (rename_formula m F)
  | Eventually F => Eventually (rename_formula m F)
  | Embed P => Rename m (Embed P)
  | Rename s P => rename_formula (RenameMap_compose m s) P
  end.

Definition RenameMapOk (sigma : RenameMap) : Prop :=
  forall x : Var, is_st_term (sigma x) = true.

Lemma Rename_term_ok : forall m t st1 st2,
  RenameMapOk m ->
  eval_term (rename_term m t) st1 st2 =
  eval_term t (subst_state m st1) (subst_state m st2).
Proof.
  induction t; simpl; intros; auto;
  try solve [rewrite IHt1; auto; rewrite IHt2; auto |
             rewrite IHt; auto ].
  - unfold subst_state.
    apply st_term_hd; auto.
  - unfold subst_state.
    apply next_term_tl; auto.
Qed.

Lemma Rename_True : forall m,
  Rename m TRUE -|- TRUE.
Proof.
  intros; split; breakAbstraction; auto.
Qed.

Lemma Rename_False : forall m,
  Rename m FALSE -|- FALSE.
Proof.
  intros; split; breakAbstraction; auto.
Qed.

Lemma Rename_Comp : forall m t1 t2 op,
  RenameMapOk m ->
  Rename m (Comp t1 t2 op) -|-
  rename_formula m (Comp t1 t2 op).
Proof.
  split; breakAbstraction; intros.
  + unfold eval_comp in *.
    repeat (rewrite Rename_term_ok; auto).
    destruct tr as [st1 [st2 tr]]. auto.
  + unfold eval_comp in *.
    repeat (rewrite Rename_term_ok in H0; auto).
    destruct tr as [st1 [st2 tr]]. auto.
Qed.

Lemma Rename_and : forall m F1 F2,
  Rename m (F1 //\\ F2) -|-
  Rename m F1 //\\ Rename m F2.
Proof.
  intros; split; breakAbstraction; auto.
Qed.

Lemma Rename_or : forall m F1 F2,
  Rename m (F1 \\// F2) -|-
  Rename m F1 \\// Rename m F2.
Proof.
  intros; split; breakAbstraction; auto.
Qed.

Lemma Rename_impl : forall m F1 F2,
  Rename m (F1 -->> F2) -|-
  Rename m F1 -->> Rename m F2.
Proof.
  intros; split; breakAbstraction; auto.
Qed.

Lemma Rename_PropF : forall m P,
  Rename m (PropF P) -|- PropF P.
Proof.
  intros; split; breakAbstraction; auto.
Qed.

Lemma Rename_Exists : forall T m f,
  Rename m (Syntax.Exists T f) -|-
  Syntax.Exists T (fun x => Rename m (f x)).
Proof.
  intros; split; breakAbstraction; auto.
Qed.

Lemma Rename_Forall : forall T m f,
  Rename m (Syntax.Forall T f) -|-
  Syntax.Forall T (fun x => Rename m (f x)).
Proof.
  intros; split; breakAbstraction; auto.
Qed.

Lemma Rename_Always : forall m F,
  Rename m (Always F) -|-
  Always (Rename m F).
Proof.
  intros; split; breakAbstraction; intros.
  { specialize (H n).
    rewrite Stream.stream_map_nth_suf in H; auto. }
  { rewrite Stream.stream_map_nth_suf; auto. }
Qed.

Lemma Rename_Eventually : forall m F,
  Rename m (Eventually F) -|-
  Eventually (Rename m F).
Proof.
  intros; split; breakAbstraction; intros.
  { destruct H as [n H].
    rewrite Stream.stream_map_nth_suf in H; eauto. }
  { destruct H as [n H].
    exists n. rewrite Stream.stream_map_nth_suf; auto. }
Qed.

Require Import Coq.Strings.String.

Definition RenameList : Type := list (Var * Term).

Delimit Scope rename_scope with rn.
Bind Scope rename_scope with RenameList.
Bind Scope rename_scope with RenameMap.
Bind Scope rn with RenameMap.

Definition RLcons : (Var * Term) -> RenameList -> RenameList :=
  @cons _.
Definition RLnil : RenameList :=
  @nil _.

Notation "X ~> Y" := (@pair Var Term X%string Y%HP%string) (at level 60) : rename_scope.

Notation "{{  X & .. & Y }}" := ((RLcons X%rn ( .. (@RLcons Y%rn RLnil) .. ))) (X at level 100) : rename_scope.
Notation "{{  }}" := (RLnil) : rename_scope.

Fixpoint to_RenameMap (m : RenameList) : RenameMap :=
  match m with
  | nil => fun x => x
  | (y, t) :: m =>
    fun x => if String.string_dec x y
             then t else to_RenameMap m x
  end.

Coercion to_RenameMap : RenameList >-> RenameMap.

Arguments Rename _%rename_scope _.

Lemma Rename_Enabled
: forall P m,
    Enabled (Rename m P) |-- Rename m (Enabled P).
Proof.
  Opaque Stream.stream_map.
  breakAbstraction. intros.
  destruct H.
  simpl.
  destruct tr. simpl in H.
  eapply Proper_eval_formula in H. 2: reflexivity.
  2: symmetry. 2: eapply Stream.stream_map_cons. 2: eauto.
  eauto.
Qed.

Lemma Rename_Rename :
  forall P m m',
    RenameMapOk m ->
    Rename m (Rename m' P) -|-
    Rename (RenameMap_compose m m') P.
Proof.
  intros. apply lequiv_to_iff. intros.
  simpl.
  rewrite Stream.stream_map_compose
    by eauto with typeclass_instances.
  unfold RenameMap_compose. apply Proper_eval_formula.
  { reflexivity. }
  { eapply Stream.Proper_stream_map.
    2: instantiate (1:=eq); reflexivity.
    morphism_intro. subst. unfold subst_state.
    apply FunctionalExtensionality.functional_extensionality.
    intros. rewrite Rename_term_ok by auto. reflexivity. }
Qed.

Fixpoint st_term_renamings (F : Formula) : Prop :=
  match F with
    | TRUE | FALSE | Comp _ _ _ | PropF _ | Embed _ => True
    | And F1 F2 | Or F1 F2 | Imp F1 F2 =>
        st_term_renamings F1 /\ st_term_renamings F2
    | Syntax.Exists _ f | Syntax.Forall _ f =>
        forall x, st_term_renamings (f x)
    | Enabled F | Always F | Eventually F => st_term_renamings F
    | Rename s P =>
       (forall x, is_st_term (s x) = true) /\ st_term_renamings P
  end.

Lemma rename_term_st_term : forall t m,
  (forall x, is_st_term (m x) = true) ->
  is_st_term t = true ->
  is_st_term (rename_term m t) = true.
Proof.
  induction t; auto;
  try solve
      [ simpl; intros; apply andb_prop in H0; destruct H0;
        rewrite IHt1; auto; rewrite IHt2; auto |
        simpl; auto |
        simpl; discriminate ].
Qed.

Lemma Rename_ok : forall F m
  (Hst : st_term_renamings F),
  RenameMapOk m ->
  rename_formula m F -|- Rename m F.
Proof.
  induction F; intros.
  - apply Rename_True with (m:=m).
  - apply Rename_False with (m:=m).
  - rewrite Rename_Comp; auto.
  - rewrite Rename_and. simpl rename_formula.
    simpl in Hst. destruct Hst. restoreAbstraction.
    rewrite IHF1; auto. rewrite IHF2; auto.
  - rewrite Rename_or. simpl rename_formula.
    simpl in Hst. destruct Hst. restoreAbstraction.
    rewrite IHF1; auto. rewrite IHF2; auto.
  - rewrite Rename_impl. simpl rename_formula.
    simpl in Hst. destruct Hst. restoreAbstraction.
    rewrite IHF1; auto. rewrite IHF2; auto.
  - rewrite Rename_PropF. simpl rename_formula.
    split; charge_tauto.
  - rewrite Rename_Exists. simpl rename_formula.
    split; breakAbstraction; intros.
    + destruct H1. specialize (H x _ (Hst x) H0). destruct H.
      revert H0 H1. breakAbstraction. intros. exists x.
      auto.
    + destruct H1. specialize (H x _ (Hst x) H0). destruct H.
      revert H0 H1. breakAbstraction. intros. exists x.
      auto.
  - rewrite Rename_Forall. simpl rename_formula.
    split; breakAbstraction; intros.
    + specialize (H x _ (Hst x) H0). destruct H. revert H H1.
      breakAbstraction. intros. auto.
    + specialize (H x _ (Hst x) H0). destruct H. revert H H1.
      breakAbstraction. intros. auto.
  - simpl rename_formula. auto.
  - rewrite Rename_Always. simpl rename_formula.
    split; tlaRevert; apply Always_imp; rewrite IHF;
    auto; charge_tauto.
  - rewrite Rename_Eventually. simpl rename_formula.
    split; tlaRevert; apply eventually_imp; rewrite IHF;
    auto; charge_tauto.
  - simpl rename_formula. split; charge_tauto.
  - simpl rename_formula. rewrite Rename_Rename by auto.
    rewrite <- IHF.
    + reflexivity.
    + simpl in Hst. tauto.
    + unfold RenameMapOk, RenameMap_compose. simpl in Hst.
      destruct Hst. intros. apply rename_term_st_term; auto.
Qed.

Definition RenameListOk (r : RenameList) : Prop :=
  eq (forallb (fun x => is_st_term (snd x)) r) true.

Lemma is_st_term_to_RenameMap : forall (ls : RenameList),
    RenameListOk ls ->
    RenameMapOk ls.
Proof.
  unfold RenameMapOk.
  induction ls.
  { simpl in *. reflexivity. }
  { simpl in *. intros.
    eapply Bool.andb_true_iff in H.
    destruct H.
    destruct a; simpl in *.
    destruct (String.string_dec x v); subst; auto. }
Qed.

Hint Extern 1 (RenameListOk _) => reflexivity : rw_rename.

Hint Extern 1 (RenameMapOk (to_RenameMap ?X)) =>
  solve [ eapply (is_st_term_to_RenameMap X) ; reflexivity ] : rw_rename.

Ltac is_st_term_list :=
  simpl; intros;
  repeat match goal with
           |- context [ String.string_dec ?e1 ?e2 ] =>
           destruct (String.string_dec e1 e2)
         end; try reflexivity; try tauto.

Hint Extern 1 (st_term_renamings _) => solve [ is_st_term_list ] : rw_rename.

Ltac rw_side_condition :=
  repeat first [ split | intros ];
  try solve [ apply is_st_term_to_RenameMap ; reflexivity ].

Hint Rewrite Rename_True Rename_False Rename_Comp
     Rename_and Rename_or Rename_impl Rename_PropF
     Rename_Exists Rename_Forall
     Rename_Always Rename_Eventually
     Rename_Enabled using solve [ eauto with rw_rename ] : rw_rename.

Ltac Rename_rewrite :=
  autorewrite with rw_rename.

Global Instance Proper_Rename_lentails :
  Proper (eq ==> lentails ==> lentails) Rename.
Proof.
  morphism_intro.
  breakAbstraction. subst. intuition.
Qed.

Global Instance Proper_Rename_lequiv :
  Proper (eq ==> lequiv ==> lequiv) Rename.
Proof.
  morphism_intro. split.
  - rewrite H0; subst; reflexivity.
  - rewrite <- H0; subst; reflexivity.
Qed.

Lemma Proper_Rename_True : forall sigma P,
    |-- P ->
    |-- Rename sigma P.
Proof.
  intros.
  eapply Proper_Rename_lentails in H; [ | reflexivity ].
  rewrite <- H. autorewrite with rw_rename. charge_tauto.
Qed.


Ltac rename_hyp m H :=
  apply (Proper_Rename_lentails (to_RenameMap m) (to_RenameMap m))
  in H; [ | reflexivity ].

Definition NotRenamed (m : RenameMap) (x : Var) :=
  eq (m x) x.

Hint Extern 1 (NotRenamed _ _) => reflexivity : rw_rename.