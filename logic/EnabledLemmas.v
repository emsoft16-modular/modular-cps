Require Import Coq.Lists.List.
Require Import Coq.Strings.String.
Require Import Coq.Classes.Morphisms.
Require Import ExtLib.Tactics.
Require Import Logic.Logic.
Require Import Logic.BasicProofRules.
Require Import Logic.RenameProofRules.

Definition traces_agree (tr1 tr2 : trace)
           (xs : list Var) : Prop :=
  forall x,
    List.In x xs ->
    Stream.stream_eq (fun st1 st2 => eq (st1 x) (st2 x))
                     tr1 tr2.

Definition next_state_vars (A : Formula)
           (xs : list Var) : Prop :=
  forall tr1 tr2 st,
    traces_agree tr1 tr2 xs ->
    (eval_formula A (Stream.Cons st tr1) <->
     eval_formula A (Stream.Cons st tr2)).

Definition sets_disjoint {T} (a b : list T) : Prop :=
  forall x,
    List.In x b -> ~List.In x a.

Lemma sets_disjoint_equiv : forall {T} (a b : list T),
    sets_disjoint a b ->
    sets_disjoint b a.
Proof. firstorder. Qed.

Definition disjoint_states_aux (A B : Formula)
           (xs ys : list Var) :=
  sets_disjoint xs ys /\
  next_state_vars A xs /\
  next_state_vars B ys.

Definition disjoint_states (A B : Formula) :=
  exists xs ys, disjoint_states_aux A B xs ys.

Global Instance Proper_disjoint_states :
  Proper (lequiv ==> lequiv ==> iff) disjoint_states.
Proof.
  morphism_intro. unfold disjoint_states, disjoint_states_aux.
  apply exists_iff. intro. apply exists_iff. intro.
  destruct H as [Hx Hy]. destruct H0 as [Hx0 Hy0].
  unfold sets_disjoint, next_state_vars. breakAbstraction.
  intuition; breakAbstraction;
  try first [apply Hx; apply Hy in H3 |
             apply Hy; apply Hx in H3 |
             apply Hx0; apply Hy0 in H3 |
             apply Hy0; apply Hx0 in H3 ];
  try solve [rewrite <- H; eauto ].
  rewrite <- H; eauto. unfold traces_agree in *. intros.
  eapply Stream.Symmetric_stream_eq;
    [ repeat red; congruence | eauto ].
  rewrite <- H2; eauto.
  rewrite <- H2; eauto. unfold traces_agree in *. intros.
  eapply Stream.Symmetric_stream_eq;
    [ repeat red; congruence | eauto ].
  rewrite <- H; eauto. unfold traces_agree in *. intros.
  eapply Stream.Symmetric_stream_eq;
    [ repeat red; congruence | eauto ].
  rewrite <- H2; eauto.
  rewrite <- H2; eauto. unfold traces_agree in *. intros.
  eapply Stream.Symmetric_stream_eq;
    [ repeat red; congruence | eauto ].
Qed.

Definition merge_states (xs ys : list Var)
           (st1 st2 : state) : state :=
  fun x =>
    if List.existsb (fun y => if String.string_dec x y
                              then true else false) xs
    then st1 x
    else if List.existsb (fun y => if String.string_dec x y
                                   then true else false) ys
         then st2 x else st1 x.

CoFixpoint merge_traces (xs ys : list Var)
           (tr1 tr2 : trace) : trace :=
  Stream.Cons (merge_states xs ys (Stream.hd tr1)
                            (Stream.hd tr2))
              (merge_traces xs ys (Stream.tl tr1)
                            (Stream.tl tr2)).

Lemma traces_agree_sets_disjoint :
  forall tr1 tr2 xs ys,
    sets_disjoint xs ys ->
    exists tr,
      traces_agree tr1 tr xs /\
      traces_agree tr2 tr ys.
Proof.
  intros tr1 tr2 xs ys Hdisjoint.
  pose proof (@sets_disjoint_equiv _ _ _ Hdisjoint)
    as Hdisjoint2.
  unfold sets_disjoint in *.
  exists (merge_traces xs ys tr1 tr2).
  split.
  { generalize dependent tr1. generalize dependent tr2.
    cofix. unfold traces_agree. intros. constructor.
    simpl. unfold merge_states.
    { assert (existsb
                (fun y : string => if string_dec x y
                                   then true
                                   else false) xs = true).
      { apply existsb_exists. exists x.
        destruct (String.string_dec x x); auto. }
      { rewrite H0; auto. } }
    { unfold traces_agree in *. simpl. auto. } }
  { generalize dependent tr1. generalize dependent tr2.
    cofix. unfold traces_agree. intros. constructor.
    simpl. unfold merge_states.
    { assert (existsb
                (fun y : string => if string_dec x y
                                   then true
                                   else false) ys = true).
      { apply existsb_exists. exists x.
        destruct (String.string_dec x x); auto. }
      { rewrite H0; auto.
        assert (existsb
                  (fun y : string => if string_dec x y
                                     then true
                                     else false) xs = false).
        { apply Bool.not_true_is_false. intro.
          apply existsb_exists in H1. destruct H1.
          specialize (Hdisjoint _ H).
          destruct (String.string_dec x x0);
            try subst; intuition. }
        { rewrite H1. auto. } } }
    { unfold traces_agree in *. simpl. auto. } }
Qed.

Lemma disjoint_state_enabled :
  forall A B,
    disjoint_states A B ->
    Enabled A //\\ Enabled B |-- Enabled (A //\\ B).
Proof.
  intros A B Hdisjoint. breakAbstraction. intros tr Hen.
  unfold disjoint_states, disjoint_states_aux,
  next_state_vars in *.
  destruct Hen as [[trA HenA] [trB HenB]].
  destruct Hdisjoint as [xs [ys [Hdisjoint [HA HB]]]].
  pose proof (traces_agree_sets_disjoint trA trB) as Htr'.
  specialize (Htr' _ _ Hdisjoint).
  destruct Htr' as [tr' [HAtr' HBtr']].
  exists tr'. split.
  { eapply HA. 2: apply HenA.
    unfold traces_agree in *. intros.
    apply Stream.Symmetric_stream_eq; auto. }
  { eapply HB. 2: apply HenB.
    unfold traces_agree in *. intros.
    apply Stream.Symmetric_stream_eq; auto. }
Qed.

Lemma disjoint_statespace_enabled :
  forall (P Q : StateFormula) (A B : ActionFormula),
    is_st_formula P -> is_st_formula Q ->
    (P \\// Q) //\\
    (P -->> Q -->> lfalse) //\\
    Enabled (P -->> A) //\\
    Enabled (Q -->> B)
    |-- Enabled ((P -->> A) //\\ (Q -->> B)).
Proof.
  intros.
  breakAbstraction.
  intros. forward_reason.
  destruct H1.
  { exists x0. split; auto.
    intros. exfalso; eapply H2; eauto.
    eapply st_formula_hd; eauto. }
  { exists x. split; auto.
    intros. exfalso; eapply H2; eauto.
    eapply st_formula_hd; eauto. }
Qed.

Definition not_in_dec
           {T} (f : forall x y, {x = y} + {x <> y})
           (a : list T) x : bool :=
  List.forallb (fun y => if f x y
                         then false
                         else true) a.

Definition sets_disjoint_dec
           {T} (f : forall x y, {x = y} + {x <> y})
           (a b : list T) : bool :=
  List.forallb (not_in_dec f b) a.

Lemma sets_disjoint_dec_ok :
  forall {T} f (a b : list T),
    sets_disjoint_dec f a b = true ->
    sets_disjoint a b.
Proof.
  unfold sets_disjoint, sets_disjoint_dec. intros.
  pose proof List.forallb_forall.
  specialize (H1 _ (not_in_dec f b) a).
  destruct H1. intuition.
  specialize (H4 _ H3).
  clear - H4 H0.
  unfold not_in_dec in *.
  pose proof List.forallb_forall.
  specialize
    (H _ (fun y : T => if f x y then false else true) b).
  destruct H. intuition. specialize (H2 _ H0).
  destruct (f x x); auto; discriminate.
Qed.

Ltac decide_disjoint_var_sets :=
  apply (sets_disjoint_dec_ok String.string_dec);
  reflexivity.


(*
  Fixpoint get_vars_term (t : Term) : list Var :=
    match t with
    | VarNextT t | VarNowT t => t :: nil
    | NatT _ | RealT _ => nil
    | PlusT a b | MinusT a b | MultT a b =>
         get_vars_term a ++
         get_vars_term b
    | InvT a | CosT a | SinT a | SqrtT a | ArctanT a =>
         get_vars_term a
    end.

  Fixpoint get_vars_formula (f : Formula) : list Var :=
    match f with
    | Always a | Eventually a | Enabled a =>
         get_vars_formula a
    | And a b | Or a b | Imp a b =>
         get_vars_formula a ++
         get_vars_formula b
    | Rename _ a => get_vars_formula a
    | Comp l r _ => get_vars_term l ++
         get_vars_term r
    | _ => nil
    end.
*)

Fixpoint can_get_vars_formula (f : Formula) : bool :=
  match f with
  | Always a | Eventually a | Enabled a =>
   (* This could be true, but proving it is a pain,
      and we don't need it at the moment. *)
                              false
  | And a b | Or a b | Imp a b =>
                       andb (can_get_vars_formula a)
                            (can_get_vars_formula b)
  | Comp _ _ _ => true
  | TRUE | FALSE => true
  | _ => false
  end.

Lemma traces_agree_app :
  forall tr1 tr2 xs ys,
    traces_agree tr1 tr2 (xs ++ ys) ->
    traces_agree tr1 tr2 xs /\ traces_agree tr1 tr2 ys.
Proof.
  intros. unfold traces_agree in *.
  split; intros; apply H; apply List.in_or_app; tauto.
Qed.

Lemma traces_agree_sym :
  forall tr1 tr2 xs,
    traces_agree tr1 tr2 xs ->
    traces_agree tr2 tr1 xs.
Proof.
  unfold traces_agree. intros.
  apply Stream.Symmetric_stream_eq.
  { repeat red. congruence. }
  { auto. }
Qed.

Require Import Coq.Reals.Rdefinitions.

Lemma get_vars_term :
  forall t tr1 tr2 st,
    traces_agree tr1 tr2 (get_next_vars_term t) ->
    eval_term t st (Stream.hd tr1) =
    eval_term t st (Stream.hd tr2).
Proof.
  induction t; simpl; intros; auto;
  try solve [ apply traces_agree_app in H; destruct H;
              erewrite IHt1; eauto; erewrite IHt2; eauto |
              erewrite IHt; eauto ].
  unfold traces_agree in *. simpl in *.
  specialize (H v (or_introl (eq_refl _))).
  destruct H. auto.
Qed.

Lemma get_vars_next_state_vars :
  forall A,
    can_get_vars_formula A = true ->
    next_state_vars A (get_next_vars_formula A).
Proof.
  induction A; simpl; try discriminate;
  unfold next_state_vars in *; simpl; intros; try tauto.
    - destruct c; simpl;
      apply traces_agree_app in H0; destruct H0;
      erewrite get_vars_term with (t:=t); eauto;
      erewrite get_vars_term with (t:=t0); eauto; tauto.
    - apply andb_prop in H.
      split; intros;
      apply traces_agree_app in H0;
      destruct H0; destruct H1;
      split.
      { eapply IHA1; try tauto;
        try apply traces_agree_sym; eauto. }
      { eapply IHA2; try tauto;
        try apply traces_agree_sym; eauto. }
      { eapply IHA1; try tauto; eauto. }
      { eapply IHA2; try tauto; eauto. }
    - apply andb_prop in H.
      split; intros;
      apply traces_agree_app in H0;
      destruct H0; destruct H1.
      { left. eapply IHA1; try tauto;
        try apply traces_agree_sym; eauto. }
      { right. eapply IHA2; try tauto;
        try apply traces_agree_sym; eauto. }
      { left. eapply IHA1; try tauto; eauto. }
      { right. eapply IHA2; try tauto; eauto. }
    - apply andb_prop in H.
      split; intros;
      apply traces_agree_app in H0;
      destruct H0.
      { eapply IHA2; try tauto;
        try apply traces_agree_sym; eauto.
        apply H1. eapply IHA1; try tauto; eauto. }
      { eapply IHA2; try tauto; eauto; apply H1.
        eapply IHA1; try tauto;
        try apply traces_agree_sym; eauto. }
Qed.

Lemma formulas_disjoint_state :
  forall A B,
    can_get_vars_formula A = true ->
    can_get_vars_formula B = true ->
    sets_disjoint_dec String.string_dec
                      (get_next_vars_formula A)
                      (get_next_vars_formula B) = true ->
    disjoint_states A B.
Proof.
  unfold disjoint_states. intros.
  exists (get_next_vars_formula A).
  exists (get_next_vars_formula B).
  apply sets_disjoint_dec_ok in H1.
  unfold disjoint_states_aux. split; auto.
  apply get_vars_next_state_vars in H.
  apply get_vars_next_state_vars in H0.
  auto.
Qed.

Definition witness_function (m:RenameMap) (f:state->state)
  (xs : list Var) : Prop :=
  forall st x,
    List.In x xs ->
    st x = eval_term (m x) (f st) (f st).

Lemma subst_enabled :
  forall A xs G m (f:state->state),
    next_state_vars A xs ->
    witness_function m f xs ->
    G |-- Enabled A ->
    Rename m G |-- Enabled (Rename m A).
Proof.
  breakAbstraction. intros. unfold next_state_vars in *.
  specialize (H1 _ H2).
  destruct tr.
  destruct H1 as [tr' HA].
  exists (Stream.stream_map f tr').
  rewrite Stream.stream_map_cons
    by eauto with typeclass_instances.
  rewrite H.
  { eapply BasicProofRules.Proper_eval_formula.
    3: apply HA.
    { reflexivity. }
    { constructor.
      { reflexivity. }
      { reflexivity. } } }
  { unfold witness_function, traces_agree in *. intros.
    unfold subst_state.
    eapply Stream.Transitive_stream_eq.
    { repeat red. congruence. }
    { apply Stream.stream_map_compose.
      repeat red. reflexivity. }
    { simpl.
      match goal with
      | [ |- context [ Stream.stream_map ?f _ ] ] =>
        pose proof (@Stream.Proper_stream_map _ _
              (fun st1 st2 : state => (eq (st1 x) (st2 x)))
              (fun st1 st2 : state => (eq (st1 x) (st2 x)))
              f (fun x => x)) as Hproper
      end.
      repeat red in Hproper.
      eapply Stream.Transitive_stream_eq.
      { repeat red. congruence. }
      { apply Hproper.
        { repeat red. intros. rewrite <- H0; auto. }
        { apply Stream.Reflexive_stream_eq.
          repeat red. auto. } }
      { apply Stream.stream_map_id. repeat red.
        auto. } } }
Qed.

Lemma subst_enabled_noenv :
  forall A xs m (f:state->state),
    next_state_vars A xs ->
    witness_function m f xs ->
    |-- Enabled A ->
    |-- Enabled (Rename m A).
Proof.
  intros. rewrite <- subst_enabled with (G:=ltrue); eauto.
  apply Rename_True.
Qed.

Definition predicated_witness_function (m:RenameMap)
  (f:state->state) (xs : list Var) (P Q : StateFormula) : Prop :=
  witness_function m f xs /\
  forall tr, eval_formula P tr -> eval_formula Q (Stream.stream_map f tr).

Definition Witnessable (P Q : StateFormula) (r : RenameMap) : Prop :=
  P |-- Enabled ((Forall x : Var, x = next_term (r x)) //\\ next Q)%HP.

Definition is_action_formula (P : Formula) : Prop :=
  forall tr tr',
    Stream.hd tr = Stream.hd tr' ->
    Stream.hd (Stream.tl tr) = Stream.hd (Stream.tl tr') ->
    (eval_formula P tr <-> eval_formula P tr').

(* Prop expressing that the Formula has no temporal operators.
   This cannot be a bool because of Forall and Exists. *)
Fixpoint is_action_formula' (F:Formula) : Prop :=
  match F with
  | TRUE => True
  | FALSE => True
  | Comp t1 t2 _ => True
  | And F1 F2 =>
    and (is_action_formula' F1) (is_action_formula' F2)
  | Or F1 F2 =>
    and (is_action_formula' F1) (is_action_formula' F2)
  | Imp F1 F2 =>
    and (is_action_formula' F1) (is_action_formula' F2)
  | Syntax.Exists _ f =>
    forall x, is_action_formula' (f x)
  | Syntax.Forall _ f =>
    forall x, is_action_formula' (f x)
  | PropF _ => True
  | Rename _ x => False
  | _ => False
  end.

Lemma is_action_formula_ok :
  forall F, is_action_formula' F -> is_action_formula F.
Proof.
  induction F; unfold is_action_formula; simpl; intros;
    try reflexivity; unfold is_action_formula in *;
      try (rewrite IHF1 with (tr:=tr) (tr':=tr'); try tauto;
           rewrite IHF2 with (tr:=tr) (tr':=tr'); try tauto);
      try contradiction.
  { rewrite H0. rewrite H1. reflexivity. }
  { split; intro; destruct H3; exists x;
    eapply H with (tr:=tr) (tr':=tr'); auto. }
  { split; intros; specialize (H3 x);
    eapply H with (tr:=tr) (tr':=tr'); auto. }
Qed.

Lemma Enabled_Witnessable :
  forall (A : ActionFormula) G m (P Q : StateFormula)
         (Hrn : RenameMapOk m)
    (HstP : is_st_formula P)
    (HstQ : is_st_formula Q)
    (HactA : is_action_formula A),
    Witnessable P Q m ->
    G |-- Enabled (A //\\ next P) ->
    Rename m G |-- Enabled ((Rename m A) //\\ next Q).
Proof.
  do 9 intro.
  unfold Witnessable; breakAbstraction.
  intros.
  eapply H0 in H1; clear H0.
  destruct H1. destruct H0.
  eapply next_formula_tl in H1; eauto.
  simpl in H1.
  destruct tr. simpl in *.
  eapply H in H1; clear H.
  destruct H1.
  exists (Stream.Cons (Stream.hd x0) (Stream.tl x)).
  destruct H.
  split.
  { revert H0.
    eapply HactA.
    - reflexivity.
    - simpl.
      eapply FunctionalExtensionality.functional_extensionality.
      intros.
      unfold subst_state.
      rewrite H.
      erewrite next_term_tl. reflexivity. eapply Hrn. }
  { eapply next_formula_tl; eauto.
    simpl.
    eapply next_formula_tl in H1; eauto.
    eapply st_formula_hd; eauto. }
Qed.

Lemma subst_enabled_predicated_witness :
  forall A xs G m (f:state->state) P Q
    (HstP : is_st_formula P)
    (HstQ : is_st_formula Q),
    next_state_vars A xs ->
    predicated_witness_function m f xs P Q ->
    G |-- Enabled (A //\\ next P) ->
    Rename m G |-- Enabled ((Rename m A) //\\ next Q).
Proof.
  breakAbstraction. intros. unfold next_state_vars in *.
  specialize (H1 _ H2).
  destruct tr.
  destruct H1 as [tr' [HA HP]].
  exists (Stream.stream_map f tr').
  rewrite Stream.stream_map_cons
    by eauto with typeclass_instances.
  rewrite H.
  { split.
    { eapply BasicProofRules.Proper_eval_formula.
      3: apply HA.
      { reflexivity. }
      { constructor.
        { reflexivity. }
        { reflexivity. } } }
    { unfold predicated_witness_function in *.
      rewrite next_formula_tl; auto. simpl.
      apply H0. apply next_formula_tl in HP; [ | assumption ].
      assumption. } }
  { unfold predicated_witness_function, witness_function,
    traces_agree in *. intros.
    unfold subst_state.
    eapply Stream.Transitive_stream_eq.
    { repeat red. congruence. }
    { apply Stream.stream_map_compose.
      repeat red. reflexivity. }
    { simpl.
      match goal with
      | [ |- context [ Stream.stream_map ?f _ ] ] =>
        pose proof (@Stream.Proper_stream_map _ _
             (fun st1 st2 : state => (eq (st1 x) (st2 x)))
             (fun st1 st2 : state => (eq (st1 x) (st2 x)))
             f (fun x => x)) as Hproper
      end.
      repeat red in Hproper.
      eapply Stream.Transitive_stream_eq.
      { repeat red. congruence. }
      { apply Hproper.
        { repeat red. intros. destruct H0.
          rewrite <- H0; auto. }
        { apply Stream.Reflexive_stream_eq.
          repeat red. auto. } }
      { apply Stream.stream_map_id. repeat red.
        auto. } } }
Qed.

Lemma subst_enabled_predicated_witness_noenv :
  forall A xs m (f:state->state) P Q
    (HstP : is_st_formula P)
    (HstQ : is_st_formula Q),
    next_state_vars A xs ->
    predicated_witness_function m f xs P Q ->
    |-- Enabled (A //\\ next P) ->
    |-- Enabled ((Rename m A) //\\ next Q).
Proof.
  intros.
  rewrite <- subst_enabled_predicated_witness
  with (G:=ltrue) (P:=P) (Q:=Q); eauto.
  apply Rename_True.
Qed.

Lemma predicated_witness_to_witness_function :
  forall f m xs P Q,
    predicated_witness_function m f xs P Q ->
    witness_function m f xs.
Proof.
  unfold predicated_witness_function. tauto.
Qed.

Lemma subst_enabled_predicated_witness_simple :
  forall A xs G m (f:state->state) I
    (Hst : is_st_formula I),
    next_state_vars A xs ->
    predicated_witness_function m f xs ltrue I ->
    G |-- Enabled A ->
    Rename m G |-- Enabled ((Rename m A) //\\ next I).
Proof.
  intros. eapply subst_enabled_predicated_witness with (P:=ltrue); eauto.
  - compute; tauto.
  - simpl next. restoreAbstraction. rewrite landtrueR.
    assumption.
Qed.

Lemma subst_enabled_predicated_witness_simple_noenv :
  forall A xs m (f:state->state) I
    (Hst : is_st_formula I),
    next_state_vars A xs ->
    predicated_witness_function m f xs ltrue I ->
    |-- Enabled A ->
    |-- Enabled ((Rename m A) //\\ next I).
Proof.
  intros.
  rewrite <- subst_enabled_predicated_witness_simple
  with (G:=ltrue); eauto.
  apply Rename_True.
Qed.

Require Import Logic.Stream.

Lemma stream_eq_forever :
  forall (A : Type) (s1 s2 : A) (r : A -> A -> Prop),
    r s1 s2 ->
    stream_eq r (forever s1) (forever s2).
Proof.
  intros. cofix.
  constructor.
  { exact H. }
  { auto. }
Qed.

Lemma stream_map_hd :
  forall (A B : Type) (tr : stream A) (f : A -> B),
    hd (stream_map f tr) = f (hd tr).
Proof.
  destruct tr. simpl. reflexivity.
Qed.

Lemma subst_enabled_full :
  forall G (S : ActionFormula) (Q R : StateFormula)
         (sigma sigma_inv : RenameMap) xs,
    is_st_formula Q ->
    is_st_formula R ->
    is_action_formula S ->
    next_state_vars S xs ->
    (forall st x,
        In x xs ->
        eval_formula R (Stream.forever st) ->
        subst_state sigma (subst_state sigma_inv st) x =
        st x) ->
    R |-- Rename sigma_inv Q ->
    G |-- Enabled (S //\\ next R) ->
    Rename sigma G |-- Enabled (Rename sigma S //\\ next Q).
Proof.
  intros. breakAbstraction. intros. destruct tr.
  apply H5 in H6. simpl in *. clear tr.
  destruct H6 as [tr' [HS HR]].
  exists (stream_map (subst_state sigma_inv) tr').
  split.
  { rewrite stream_map_cons by eauto with typeclass_instances.
    unfold next_state_vars in *.
    rewrite next_formula_tl in HR; auto. simpl in *.
    assert (eval_formula R (forever (hd tr')))
      by (eapply st_formula_hd; eauto).
    unfold is_action_formula in *.
    rewrite H1
    with (tr':=Cons (subst_state sigma s) (forever (hd tr')))
      in HS; try reflexivity.
    rewrite H1
    with (tr':=Cons (subst_state sigma s)
                    (forever
                       (hd (stream_map
                              (subst_state sigma)
                              (stream_map
                                 (subst_state sigma_inv)
                                 tr'))))); try reflexivity.
    erewrite H2; eauto.
    unfold traces_agree. intros.
    apply stream_eq_forever.
    repeat rewrite stream_map_hd. apply H3; auto. }
  { rewrite next_formula_tl; auto. simpl.
    rewrite next_formula_tl in HR; auto. }
Qed.

Theorem Enabled_and (A B : Formula) :
  Enabled (A //\\ B) |-- Enabled A //\\ Enabled B.
Proof.
  breakAbstraction. intros. split; destruct H;
  exists x; tauto.
Qed.

Lemma Enabled_or :
  forall P Q, Enabled P \\// Enabled Q -|- Enabled (P \\// Q).
Proof.
  split; breakAbstraction; intros.
  { destruct H; forward_reason; eauto. }
  { destruct H. destruct H; eauto. }
Qed.

Global Instance Proper_Enabled_lentails
: Proper (lentails ==> lentails) Enabled.
Proof.
  morphism_intro.
  breakAbstraction. intros. destruct H0.
  eauto.
Qed.

Global Instance Proper_Enabled_lequiv
: Proper (lequiv ==> lequiv) Enabled.
Proof.
  morphism_intro. split.
  - eapply Proper_Enabled_lentails; eapply H.
  - eapply Proper_Enabled_lentails; eapply H.
Qed.

Lemma Enabled_limpl_st
  : forall P Q,
    is_st_formula P ->
    Enabled (P -->> Q) |-- P -->> Enabled Q.
Proof.
  intros.
  { breakAbstraction.
    intros. destruct H0. exists x.
    eapply H0.
    eapply st_formula_hd; eauto. }
Qed.



(** This lemma shows that we can push state formulas inside
 ** of Enabled which allows us to move the inductive invariant inside
 ** of the controller
 **)
Lemma Enabled_and_push : forall P Q,
    is_st_formula P ->
    P //\\ Enabled Q -|- Enabled (P //\\ Q).
Proof.
  intros. breakAbstraction.
  eapply lequiv_to_iff. intros; simpl; split.
  { destruct 1 as [ ? [ ? ? ] ].
    eexists; split; eauto.
    eapply st_formula_hd; eauto. }
  { destruct 1 as [ ? [ ? ? ] ].
    split; eauto.
    eapply st_formula_hd; eauto. }
Qed.