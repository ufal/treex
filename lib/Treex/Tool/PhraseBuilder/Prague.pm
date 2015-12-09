package Treex::Tool::PhraseBuilder::Prague;

use utf8;
use namespace::autoclean;

use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Log;
use Treex::Core::Node;
use Treex::Core::Phrase::Term;
use Treex::Core::Phrase::NTerm;
use Treex::Core::Phrase::PP;
use Treex::Core::Phrase::Coordination;

extends 'Treex::Core::Phrase::Builder';



has 'prep_is_head' =>
(
    is       => 'ro',
    isa      => 'Bool',
    required => 1,
    default  => 1,
    documentation =>
        'Should preposition and subordinating conjunction head its phrase? '.
        'See Treex::Core::Phrase::PP, fun_is_head attribute.'
);

has 'coordination_head_rule' =>
(
    is       => 'ro',
    isa      => 'Str',
    required => 1,
    default  => 'last_coordinator',
    documentation =>
        'See Treex::Core::Phrase::Coordination, head_rule attribute.'
);

has 'dialect' =>
(
    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,
    documentation =>
        'Defines the dialect of the Prague annotation style: translates our '.
        '"neutral" labels to the dependency labels actually used in the data.'
);



#------------------------------------------------------------------------------
# Defines the dialect of the Prague annotation style that is used in the data.
# What dependency labels are used? By separating the labels from the other code
# we can use the same PhraseBuilder for Prague-style trees with original Prague
# labels (afuns), as well as for trees in which the labels have already been
# translated to Universal Dependencies (but the topology is still Prague-like).
#
# Usage 0: if ( $self->is_deprel( $deprel, 'punct' ) ) { ... }
# Usage 1: $self->set_deprel( $phrase, 'punct' );
#------------------------------------------------------------------------------
sub _build_dialect
{
    # A lazy builder can be called from anywhere, including map or grep. Protect $_!
    local $_;
    # Mapping from id to regular expression describing corresponding deprels in the dialect.
    # The second position is the label used in set_deprel(); not available for all ids.
    my %map =
    (
        'apos'  => ['^Apos$', 'Apos'], # head of paratactic apposition (punctuation or conjunction)
        'appos' => ['^Apposition$', 'Apposition'], # dependent member of hypotactic apposition
        'auxg'  => ['^AuxG$', 'AuxG'], # punctuation other than comma
        'auxk'  => ['^AuxK$', 'AuxK'], # sentence-terminating punctuation
        'auxpc' => ['^Aux[PC]$'],      # preposition or subordinating conjunction
        'auxx'  => ['^AuxX$', 'AuxX'], # comma
        'auxy'  => ['^AuxY$', 'AuxY'], # additional coordinating conjunction or other function word
        'auxyz' => ['^Aux[YZ]$'],
        'cc'    => ['^AuxY$', 'AuxY'], # coordinating conjunction
        'conj'  => ['^CoordArg$', 'CoordArg'], # conjunct
        'coord' => ['^Coord$'],        # head of coordination (conjunction or punctuation)
        'mwe'   => ['^AuxP$', 'AuxP'],   # non-head word of a multi-word expression; PDT has only multi-word prepositions
        'punct' => ['^Aux[XGK]$', 'AuxG'],
    );
    return \%map;
}
sub is_deprel
{
    my $self = shift;
    my $deprel = shift; # deprel to test
    my $id = shift; # our neutral/mixed label
    my $map = $self->dialect();
    return exists($map->{$id}) && $deprel =~ m/$map->{$id}[0]/i;
}
sub set_deprel
{
    my $self = shift;
    my $phrase = shift;
    my $id = shift;
    my $map = $self->dialect();
    if(exists($map->{$id}) && defined($map->{$id}[1]))
    {
        return $phrase->set_deprel($map->{$id}[1]);
    }
    else
    {
        log_warn("Dependency relation '$id' is unknown in this dialect of phrase builder.");
        return $phrase->set_deprel("dep:$id");
    }
}



#------------------------------------------------------------------------------
# Examines a nonterminal phrase and tries to recognize certain special phrase
# types. This is the part of phrase building that is specific to expected input
# style and desired output style. This method is called from the core phrase
# building implemented in Treex::Core::Phrase::Builder, after a new nonterminal
# phrase is built.
#------------------------------------------------------------------------------
sub detect_special_constructions
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # The root node must not participate in any specialized construction.
    unless($phrase->node()->is_root())
    {
        # Despite the fact that we work bottom-up, the order of these detection
        # methods matters. There may be multiple special constructions on the same
        # level of the tree. For example: We see a phrase labeled Coord (coordination),
        # hence we do not see a prepositional phrase (the label would have to be AuxP
        # instead of Coord). However, after processing the coordination the phrase
        # will get a new label and it may well be AuxP.
        $phrase = $self->detect_prague_coordination($phrase);
        $phrase = $self->detect_prague_apposition($phrase);
        $phrase = $self->detect_prague_pp($phrase);
    }
    # Return the resulting phrase. It may be different from the input phrase.
    return $phrase;
}



#==============================================================================
# Coordination
#==============================================================================



#------------------------------------------------------------------------------
# Examines a nonterminal phrase in the Prague style. If it recognizes
# a coordination, transforms the general NTerm to Coordination.
###!!! The current implementation does not take into account possible orphans
###!!! caused by ellipsis.
#------------------------------------------------------------------------------
sub detect_prague_coordination
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # If this is the Prague style then the head is either coordinating conjunction or punctuation.
    if($self->is_deprel($phrase->deprel(), 'coord'))
    {
        my @dependents = $phrase->dependents('ordered' => 1);
        my @conjuncts;
        my @coordinators;
        my @punctuation;
        my @sdependents;
        # Classify dependents.
        my ($cmin, $cmax);
        foreach my $d (@dependents)
        {
            if($d->is_member())
            {
                push(@conjuncts, $d);
                $cmin = $d->ord() if(!defined($cmin));
                $cmax = $d->ord();
            }
            # Additional coordinating conjunctions (except the head).
            # In PDT they are labeled AuxY but other words in the tree may get
            # that label too. We identify it as 'cc' and use the dialect vocabulary
            # to see what label we actually expect.
            elsif($self->is_deprel($d->deprel(), 'cc'))
            {
                push(@coordinators, $d);
            }
            # Punctuation (except the head).
            # Some punctuation may have headed a nested coordination or
            # apposition (playing either a conjunct or a shared dependent) but
            # it should have been processed by now, as we are proceeding
            # bottom-up.
            elsif($self->is_deprel($d->deprel(), 'punct'))
            {
                push(@punctuation, $d);
            }
            # The rest are dependents shared by all the conjuncts.
            else
            {
                push(@sdependents, $d);
            }
        }
        # If there are no conjuncts, we cannot create a coordination.
        my $n = scalar(@conjuncts);
        if($n == 0)
        {
            log_warn('Coordination without conjuncts');
            # We cannot keep 'coord' as the deprel of the phrase if there are no conjuncts.
            my $node = $phrase->node();
            my $deprel_id = defined($node->form()) && $node->form() eq ',' ? 'auxx' : $node->is_punctuation() ? 'auxg' : 'auxy';
            $self->set_deprel($phrase, $deprel_id);
            return $phrase;
        }
        # The dependency relation label of the coordination head represented the relation of the
        # coordination to its parent and did not distinguish whether the head was conjunction or punctuation.
        my $old_head = $phrase->head();
        if($old_head->node()->is_punctuation())
        {
            push(@punctuation, $old_head);
        }
        else
        {
            push(@coordinators, $old_head);
        }
        # Now it is clear that we have a coordination.
        # Create a new Coordination phrase and destroy the old input NTerm.
        return $self->replace_nterm_by_coordination($phrase, \@conjuncts, \@coordinators, \@punctuation, \@sdependents, $cmin, $cmax);
    }
    # Return the input NTerm phrase if no Coordination has been detected.
    return $phrase;
}



#------------------------------------------------------------------------------
# Examines a nonterminal phrase in the Alpino style. This style is similar to
# Prague in that a coordinator plays the head; however, the deprel of the head
# is the relation of the coordination to its parent, and the coordination is
# recognized by the deprels of the conjuncts.
#
# If a coordination is recognized, the function transforms the general NTerm to
# Coordination.
#------------------------------------------------------------------------------
sub detect_alpino_coordination
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # If this is the Alpino style then the head is a coordinating conjunction,
    # its deprel may be anything but the conjuncts are labeled with a specific
    # deprel.
    my @dependents = $phrase->dependents('ordered' => 1);
    my @conjuncts = grep {$self->is_deprel($_->deprel(), 'conj')} (@dependents);
    if(@conjuncts)
    {
        my @coordinators;
        my @punctuation;
        my @sdependents;
        # Classify dependents.
        my ($cmin, $cmax);
        foreach my $d (@dependents)
        {
            if($self->is_deprel($d->deprel(), 'conj'))
            {
                $cmin = $d->ord() if(!defined($cmin));
                $cmax = $d->ord();
            }
            # Additional coordinating conjunctions (except the head).
            # In PDT they are labeled AuxY but other words in the tree may get
            # that label too. We identify it as 'cc' and use the dialect vocabulary
            # to see what label we actually expect.
            elsif($self->is_deprel($d->deprel(), 'cc'))
            {
                push(@coordinators, $d);
            }
            # Punctuation (except the head).
            # Some punctuation may have headed a nested coordination or
            # apposition (playing either a conjunct or a shared dependent) but
            # it should have been processed by now, as we are proceeding
            # bottom-up.
            elsif($self->is_deprel($d->deprel(), 'punct'))
            {
                push(@punctuation, $d);
            }
            # The rest are dependents shared by all the conjuncts.
            else
            {
                push(@sdependents, $d);
            }
        }
        # The dependency relation label of the coordination head represented the relation of the
        # coordination to its parent and did not distinguish whether the head was conjunction or punctuation.
        my $old_head = $phrase->head();
        if($old_head->node()->is_punctuation())
        {
            push(@punctuation, $old_head);
        }
        else
        {
            push(@coordinators, $old_head);
        }
        # Now it is clear that we have a coordination.
        # Create a new Coordination phrase and destroy the old input NTerm.
        return $self->replace_nterm_by_coordination($phrase, \@conjuncts, \@coordinators, \@punctuation, \@sdependents, $cmin, $cmax);
        # Use heuristic to recognize some shared dependents.
        # Even though the Alpino style belongs to the Prague family, it does not seem to take the opportunity to distinguish shared modifiers.
        # There are frequent non-projective dependents of the first conjunct that appear in the sentence after the last conjunct.
        $self->reconsider_distant_private_dependents($phrase);
    }
    # Return the input NTerm phrase if no Coordination has been detected.
    return $phrase;
}



#------------------------------------------------------------------------------
# Examines a nonterminal phrase in the left-to-right Stanford style. The head
# of the coordination is the first conjunct and it has no special label. All
# subsequent conjuncts and all delimiters (punctuation and conjunctions) are
# attached to it using prescribed relations.
# This style allows limited representation of nested coordination. It cannot
# distinguish ((A,B),C) from (A,B,C). Having nested coordination as the first
# conjunct is a problem. Example treebank is Bulgarian.
#
# If a coordination is recognized, the function transforms the general NTerm to
# Coordination.
#------------------------------------------------------------------------------
sub detect_stanford_coordination
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # If this is the Stanford style then the head is a conjunct, its deprel may
    # be anything but the other conjuncts are labeled with a specific deprel.
    my @dependents = $phrase->dependents('ordered' => 1);
    my @conjuncts = grep {$self->is_deprel($_->deprel(), 'conj')} (@dependents);
    if(@conjuncts)
    {
        my @coordinators;
        my @punctuation;
        # Classify dependents.
        my ($cmin, $cmax);
        $cmin = $phrase->ord();
        foreach my $d (@dependents)
        {
            if($self->is_deprel($d->deprel(), 'conj'))
            {
                # Check $cmin just in case the head conjunct was not the first one (it should have been!)
                $cmin = $d->ord() if($d->ord()<$cmin);
                $cmax = $d->ord();
            }
            # Coordinating conjunctions.
            # In PDT they are labeled AuxY but other words in the tree may get
            # that label too. We identify it as 'cc' and use the dialect vocabulary
            # to see what label we actually expect.
            elsif($self->is_deprel($d->deprel(), 'cc'))
            {
                push(@coordinators, $d);
            }
            # Punctuation.
            elsif($self->is_deprel($d->deprel(), 'punct'))
            {
                push(@punctuation, $d);
            }
            # The rest are private dependents of the head conjunct. Note that
            # the Stanford style cannot distinguish them from the dependents
            # shared by all conjuncts. We may later apply heuristics to identify
            # shared dependents.
        }
        # Now it is clear that we have a coordination.
        # The old input NTerm will now only hold the first conjunct with its private dependents.
        return $self->surround_nterm_by_coordination($phrase, \@conjuncts, \@coordinators, \@punctuation, [], $cmin, $cmax);
        # Use heuristic to recognize some shared dependents.
        $self->reconsider_distant_private_dependents($phrase);
    }
    # Return the input NTerm phrase if no Coordination has been detected.
    return $phrase;
}



#------------------------------------------------------------------------------
# Examines a nonterminal phrase in the left-to-right Moscow (Mel'čuk) style.
# The head of the coordination is the first conjunct and it has no special
# label. Each non-first conjunct is attached to the previous conjunct, hence we
# have a recursive structure. Conjunctions and commas are attached to the
# following conjunct. If a conjunct has two or more conjuncts as children,
# there is nested coordination. The parent conjunct first combines with the
# first child conjunct (and its descendants, if any). The resulting
# coordination is a conjunct that combines with the next child conjunct (and
# its descendants). The process goes on until all child conjuncts are
# processed.
# This style allows limited representation of nested coordination. It cannot
# distinguish (A,(B,C)) from (A,B,C). Having nested coordination as the
# last conjunct is a problem. Example treebank is Swedish.
#
# If a coordination is recognized, the function transforms the general NTerm to
# Coordination.
#------------------------------------------------------------------------------
sub detect_moscow_coordination
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # If this is the Moscow style then the head is a conjunct, its deprel may
    # be anything but the other conjuncts are labeled with a specific deprel.
    my @dependents = $phrase->dependents('ordered' => 1);
    my @conjuncts = grep {$self->is_deprel($_->deprel(), 'conj')} (@dependents);
    if(@conjuncts)
    {
        # If scalar(@conjuncts) > 1 then there is a nested coordination.
        my $first = 1;
        my $last = 0;
        while(@conjuncts)
        {
            my $conjunct = shift(@conjuncts);
            $last = scalar(@conjuncts)==0;
            # All child conjuncts should be to the right of the head conjunct.
            # If they are not, we will still collect them but inner and outer
            # punctuation will not be distinguished correctly.
            my $cmin = $phrase->ord();
            my $cmax = $conjunct->ord();
            my @coordinators;
            my @punctuation;
            # Classify dependents.
            foreach my $d (@dependents)
            {
                my $dord = $d->ord();
                last if($dord>$cmax && !$last);
                next if($dord<$cmin && !$first);
                # Coordinating conjunctions.
                # In PDT they are labeled AuxY but other words in the tree may get
                # that label too. We identify it as 'cc' and use the dialect vocabulary
                # to see what label we actually expect.
                if($self->is_deprel($d->deprel(), 'cc'))
                {
                    push(@coordinators, $d);
                }
                # Punctuation.
                elsif($dord>$cmin && $dord<$cmax && $self->is_deprel($d->deprel(), 'punct'))
                {
                    push(@punctuation, $d);
                }
                # The rest are private dependents of the head conjunct. Note that
                # the Moscow style cannot distinguish them from the dependents
                # shared by all conjuncts. We may later apply heuristics to identify
                # shared dependents.
            }
            # The old input NTerm will now only hold the first conjunct with its private dependents.
            # We will create a Coordination with two conjuncts. If there are more child conjuncts,
            # the Coordination will then become the current phrase (head conjunct) and combine with them.
            if($conjunct->is_coordination())
            {
                # If a conjunct child is already a Coordination phrase then there is
                # a coordination of more than two conjuncts and we should elevate it to
                # the current level and add the current head to it as a new conjunct.
                $phrase = $self->surround_nterm_by_existing_coordination($phrase, $conjunct, \@coordinators, \@punctuation);
            }
            else
            {
                $phrase = $self->surround_nterm_by_coordination($phrase, [$conjunct], \@coordinators, \@punctuation, [], $cmin, $cmax);
            }
            $first = 0;
        }
        # Use heuristic to recognize some shared dependents.
        $self->reconsider_distant_private_dependents($phrase);
    }
    # If we have detected a coordination, $phrase now points to the Coordination. Otherwise it is still the input NTerm.
    return $phrase;
}



#------------------------------------------------------------------------------
# Replaces a general NTerm phrase by a new Coordination phrase. Common code
# used by the detect_(prague|alpino)_coordination() methods.
#------------------------------------------------------------------------------
sub replace_nterm_by_coordination
{
    my $self = shift;
    my $phrase = shift;
    my $conjuncts = shift; # ArrayRef
    my $coordinators = shift; # ArrayRef
    my $punctuation = shift; # ArrayRef
    my $sdependents = shift; # ArrayRef
    my $cmin = shift;
    my $cmax = shift;
    # Create a new Coordination phrase and destroy the old input NTerm.
    my $parent = $phrase->parent();
    my $member = $phrase->is_member();
    $phrase->detach_children_and_die();
    # Punctuation can be considered a conjunct delimiter only if it occurs
    # between conjuncts.
    my @inpunct  = grep {my $o = $_->ord(); $o > $cmin && $o < $cmax;} (@{$punctuation});
    my @outpunct = grep {my $o = $_->ord(); $o < $cmin || $o > $cmax;} (@{$punctuation});
    # We need at least one delimiter to serve as head in Prague-style coordination.
    # If there is nothing better, take even outlying punctuation. It is occasionally
    # abused this way even in PDT (although the examples I saw may be annotation errors and may not be coordinations at all).
    if(scalar(@{$coordinators}) == 0 && scalar(@inpunct) == 0 && scalar(@outpunct) > 0)
    {
        @inpunct = @outpunct;
        @outpunct = ();
    }
    my $coordination = new Treex::Core::Phrase::Coordination
    (
        'conjuncts'    => $conjuncts,
        'coordinators' => $coordinators,
        'punctuation'  => \@inpunct,
        'head_rule'    => $self->coordination_head_rule(),
        'is_member'    => $member
    );
    # Remove the is_member flag from the conjuncts. It may be re-introduced
    # during back-projection to the dependency tree if the Prague annotation
    # style is selected. Similarly we do not change the deprel of the non-head
    # conjuncts now, but they may be later changed to 'conj' if the UD/Stanford
    # annotation style is selected.
    foreach my $c (@{$conjuncts})
    {
        $c->set_is_member(0);
    }
    foreach my $d (@{$sdependents})
    {
        $d->set_parent($coordination);
    }
    foreach my $p (@outpunct)
    {
        $p->set_parent($coordination);
        # Occasionally an outer punctuation symbol was the original head and now an inner punctuation symbol serves as the head.
        # The old head has the 'Coord' label but it should get something else if it is no longer the head.
        $self->set_deprel($p, $p->node()->form() eq ',' ? 'auxx' : 'auxg');
    }
    # If the original phrase already had a parent, we must make sure that
    # the parent is aware of the reincarnation we have made.
    if(defined($parent))
    {
        $parent->replace_child($phrase, $coordination);
    }
    return $coordination;
}



#------------------------------------------------------------------------------
# Takes a general NTerm phrase and returns a Coordination phrase. The input
# NTerm becomes a conjunct in the Coordination. It keeps the private dependents
# of the conjunct. Dependents that are listed separately as other conjuncts or
# delimiters will be detached from the NTerm and used in the Coordination. This
# code is used by the detect_(stanford|moscow)_coordination() methods.
#------------------------------------------------------------------------------
sub surround_nterm_by_coordination
{
    my $self = shift;
    my $phrase = shift;
    my $conjuncts = shift; # ArrayRef
    my $coordinators = shift; # ArrayRef
    my $punctuation = shift; # ArrayRef
    my $sdependents = shift; # ArrayRef
    my $cmin = shift;
    my $cmax = shift;
    my $member = $phrase->is_member();
    # We process the tree bottom-up, the current phrase should just have no parent
    # at this moment. Make sure that the parent is really undefined. It is important
    # because we want to make the current phrase a core child of the new Coordination
    # and we cannot use $parent->replace_child() before the Coordination is constructed.
    my $parent = $phrase->parent();
    if(defined($parent))
    {
        log_fatal("Phrases must be processed bottom-up and the parent must be undefined at this moment.");
    }
    unshift(@{$conjuncts}, $phrase);
    # Punctuation can be considered a conjunct delimiter only if it occurs between conjuncts.
    my @inpunct  = grep {my $o = $_->ord(); $o > $cmin && $o < $cmax;} (@{$punctuation});
    my @outpunct = grep {my $o = $_->ord(); $o < $cmin || $o > $cmax;} (@{$punctuation});
    # Detach all conjuncts, coordinators and delimiting punctuation from the
    # input phrase so that we can use them in the new Coordination phrase.
    foreach my $d (@{$conjuncts}, @{$coordinators}, @inpunct)
    {
        $d->set_parent(undef);
    }
    # Create a new Coordination phrase.
    my $coordination = new Treex::Core::Phrase::Coordination
    (
        'conjuncts'    => $conjuncts,
        'coordinators' => $coordinators,
        'punctuation'  => \@inpunct,
        'head_rule'    => $self->coordination_head_rule(),
        'is_member'    => $member
    );
    # Remove the is_member flag from the conjuncts. It may be re-introduced
    # during back-projection to the dependency tree if the Prague annotation
    # style is selected. Similarly we do not change the deprel of the non-head
    # conjuncts now, but they may be later changed to 'conj' if the UD/Stanford
    # annotation style is selected.
    foreach my $c (@{$conjuncts})
    {
        $c->set_is_member(0);
    }
    foreach my $d (@{$sdependents}, @outpunct)
    {
        $d->set_parent($coordination);
    }
    return $coordination;
}



#------------------------------------------------------------------------------
# Takes a general NTerm phrase and a Coordination phrase (presumably but not
# necessarily a dependent of the NTerm). Detaches Coordination from the NTerm
# if it is its current parent. Then makes the NTerm a new conjunct in the
# Coordination and returns the Coordination. This code is used by the
# detect_moscow_coordination() method if coordination has more than two
# conjuncts.
#------------------------------------------------------------------------------
sub surround_nterm_by_existing_coordination
{
    my $self = shift;
    my $phrase = shift;
    my $coordination = shift; # Treex::Core::Phrase::Coordination
    my $coordinators = shift; # ArrayRef
    my $punctuation = shift; # ArrayRef
    my $parent = $phrase->parent();
    my $member = $phrase->is_member();
    # Detach the right conjunct from its current parent (which is probably the
    # left conjunct, i.e. $phrase). The right conjunct is Coordination and will
    # replace the $phrase. If $phrase already has a parent (improbable, because
    # we process the phrases bottom-up), that parent will be now parent of the
    # Coordination.
    $coordination->set_parent(undef);
    if(defined($parent))
    {
        $parent->replace_child($phrase, $coordination);
    }
    $coordination->set_is_member($member);
    # Add the phrase as a new conjunct to the coordination.
    $coordination->add_conjunct($phrase);
    $phrase->set_is_member(0);
    # Add the new delimiters to the coordination.
    foreach my $c (@{$coordinators})
    {
        $coordination->add_coordinator($c);
        $c->set_is_member(0);
    }
    foreach my $p (@{$punctuation})
    {
        $coordination->add_punctuation($p);
        $p->set_is_member(0);
    }
    return $coordination;
}



#------------------------------------------------------------------------------
# Examines private modifiers of the first (word-order-wise) conjunct. If they
# lie after the last conjunct, the function reclassifies them as shared
# modifiers. This is a heuristic that should work well with coordinations that
# were originally encoded in left-to-right Moscow or Stanford styles.
#------------------------------------------------------------------------------
sub reconsider_distant_private_dependents
{
    my $self = shift;
    my $coordination = shift;
    my @conjuncts = $coordination->conjuncts('ordered' => 1);
    return if(scalar(@conjuncts)<2);
    # We will only compare the head nodes of the constituents, not the whole subtrees that could be interleaved.
    my $maxord = $conjuncts[-1]->ord();
    my @dependents = $conjuncts[0]->dependents();
    foreach my $d (@dependents)
    {
        if($d->ord() > $maxord)
        {
            # Detach the dependent from the first conjunct and attach it to the coordination, thus making it a shared dependent.
            $d->set_parent($coordination);
        }
    }
}



#==============================================================================
# Apposition
#==============================================================================



#------------------------------------------------------------------------------
# Examines a Prague-style nonterminal phrase whether it is an apposition.
# Appositions in the Prague annotation style are analyzed paratactically like
# coordinations. The delimiter (usually punctuation) is the head and both
# members are attached to it. Unlike with coordination, the apposition is not
# converted to a special phrase type. It is just transformed to a hypotactic
# relation using ordinary nonterminal phrases.
#------------------------------------------------------------------------------
sub detect_prague_apposition
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # If this is the Prague style then the head is either punctuation or a conjunction.
    # Apposition is very similar to coordination in the Prague style. Usually
    # it has only two members (“conjuncts”) but it is not guaranteed. In case
    # of ellipsis, the elided member may be represented by two or more orphans.
    if($self->is_deprel($phrase->deprel(), 'apos'))
    {
        my @dependents = $phrase->dependents('ordered' => 1);
        my @conjuncts;
        my @coordinators;
        my @punctuation;
        my @sdependents;
        # Classify dependents.
        my ($cmin, $cmax);
        foreach my $d (@dependents)
        {
            if($d->is_member())
            {
                # Occasionally punctuation is labeled as conjunct (not nested coordination,
                # which should be solved by now, but an orphan leaf node after ellipsis).
                # We want to make it normal punctuation instead.
                # (Note that we cannot recognize punctuation by dependency label in this case.
                # It will be labeled 'ExD', not 'AuxX' or 'AuxG'.)
                if($d->node()->is_punctuation() && $d->node()->is_leaf())
                {
                    $d->set_is_member(0);
                    push(@punctuation, $d);
                }
                else
                {
                    push(@conjuncts, $d);
                    $cmin = $d->ord() if(!defined($cmin));
                    $cmax = $d->ord();
                }
            }
            # Additional coordinating conjunctions (except the head).
            # In PDT they are labeled AuxY but other words in the tree may get
            # that label too. We identify it as 'cc' and use the dialect vocabulary
            # to see what label we actually expect.
            elsif($self->is_deprel($d->deprel(), 'cc'))
            {
                push(@coordinators, $d);
            }
            # Punctuation (except the head).
            # Some punctuation may have headed a nested coordination or
            # apposition (playing either a conjunct or a shared dependent) but
            # it should have been processed by now, as we are proceeding
            # bottom-up.
            elsif($self->is_deprel($d->deprel(), 'punct'))
            {
                push(@punctuation, $d);
            }
            # The rest are dependents shared by all the conjuncts.
            else
            {
                push(@sdependents, $d);
            }
        }
        # If there are no members ("conjuncts"), we cannot create an apposition.
        my $n = scalar(@conjuncts);
        if($n == 0)
        {
            log_warn('Apposition without members');
            # We cannot keep 'apos' as the deprel of the phrase if there are no members.
            my $node = $phrase->node();
            my $deprel_id = defined($node->form()) && $node->form() eq ',' ? 'auxx' : $node->is_punctuation() ? 'auxg' : 'auxy';
            $self->set_deprel($phrase, $deprel_id);
            return $phrase;
        }
        # The dependency relation label of the apposition head did not distinguish whether the head was conjunction or punctuation.
        my $old_head = $phrase->head();
        my $node = $old_head->node();
        if($node->is_punctuation())
        {
            push(@punctuation, $old_head);
            my $deprel_id = defined($node->form()) && $node->form() eq ',' ? 'auxx' : 'auxg';
            $self->set_deprel($old_head, $deprel_id);
        }
        else
        {
            push(@coordinators, $old_head);
            $self->set_deprel($old_head, 'auxy');
        }
        $old_head->set_is_member(0);
        # Now it is clear that we have an apposition.
        # Make the first member the head.
        # Note that we could not use the set_head() method if this was a Coordination or a PP phrase instead of a generic NTerm.
        # However, in the Prague style one node cannot head an Apposition and a Coordination or PP at the same time. Since we
        # have seen the Apos dependency label, we know that the current phrase is an ordinary NTerm.
        my $head_conjunct = shift(@conjuncts);
        $phrase->set_head($head_conjunct);
        # Remove the is_member flag from the conjuncts. We will no longer need it because we are transforming the tree to hypotactic apposition.
        $head_conjunct->set_is_member(0);
        foreach my $c (@conjuncts)
        {
            $c->set_is_member(0);
            $self->set_deprel($c, 'appos');
        }
        # It is not guaranteed that there is a second member (although it is weird if there isn't).
        # But if there is a second member, the delimiting punctuation should be attached to it.
        if(@conjuncts)
        {
            ###!!! Unlike coordination, it is unclear whether we want to treat punctuation differently if it occurs after the second member.
            ###!!! For example for brackets it would mean that the opening bracket is attached to the second member and the closing bracket to the first member.
            #@punctuation = grep {my $ord = $_->ord(); $ord>$cmin && $ord<$cmax} (@punctuation);
            if(@punctuation || @coordinators)
            {
                # The second member could be a terminal phrase, which cannot take dependents.
                # Wrap it in a new nonterminal.
                $conjuncts[0]->set_parent(undef);
                my $nterm = new Treex::Core::Phrase::NTerm('head' => $conjuncts[0]);
                $nterm->set_parent($phrase);
                foreach my $d (@punctuation, @coordinators)
                {
                    $d->set_parent($nterm);
                }
            }
        }
    }
    return $phrase;
}



#==============================================================================
# Prepositional phrase
#==============================================================================



#------------------------------------------------------------------------------
# Examines a nonterminal phrase in the Prague style. If it recognizes
# a prepositional phrase, transforms the general NTerm to PP. A subordinate
# clause headed by AuxC is also treated as PP.
#------------------------------------------------------------------------------
sub detect_prague_pp
{
    my $self = shift;
    my $phrase = shift; # Treex::Core::Phrase
    # If this is the Prague style then the preposition (if any) must be the head.
    if($self->is_deprel($phrase->deprel(), 'auxpc'))
    {
        # Remember whether the actual function word is 'auxp' (preposition) or 'auxc' (subordinating conjunction).
        # We will need the label later.
        my $fun_deprel = $phrase->deprel();
        my $c = $self->classify_prague_pp_subphrases($phrase);
        # If there are no argument candidates, we cannot create a prepositional phrase.
        # (This does not necessarily mean an error in the data. Multi-word prepositions form subtrees where even leaves are labeled AuxP.)
        if(!defined($c))
        {
            return $phrase;
        }
        # We are working bottom-up, thus the current phrase does not have a parent yet and we do not have to take care of the parent link.
        # We have to detach the argument though, and we have to port the is_member flag.
        my $member = $phrase->is_member();
        $phrase->set_is_member(0);
        # Now it is clear that we have a prepositional phrase.
        # The preposition ($c->{fun}) is the current phrase but we have to detach the dependents and only keep the core.
        $c->{fun}->set_deprel($fun_deprel);
        $c->{arg}->set_parent(undef);
        # If the preposition consists of multiple nodes, group them in a new NTerm first.
        # The main prepositional node has already been detached from its original parent so it can be used as the head elsewhere.
        if(scalar(@{$c->{mwe}}) > 0)
        {
            # In PDT, the last token (preposition or noun) is the head because it governs the case of the following noun.
            # In UD, the leftmost node of the MWE is its head.
            ###!!! If we want to make it variable we should define multi-word expressions as another specific phrase type.
            my @mwe = sort {$a->node()->ord() <=> $b->node()->ord()} (@{$c->{mwe}}, $c->{fun});
            my $head = pop(@mwe);
            $head->set_parent(undef);
            $c->{fun} = new Treex::Core::Phrase::NTerm('head' => $head);
            $c->{fun}->set_deprel($fun_deprel);
            foreach my $mwp (@mwe)
            {
                $mwp->set_parent($c->{fun});
                $self->set_deprel($mwp, 'mwe');
            }
        }
        my $pp = new Treex::Core::Phrase::PP
        (
            'fun'           => $c->{fun},
            'arg'           => $c->{arg},
            'fun_is_head'   => $self->prep_is_head(),
            'deprel_at_fun' => 0,
            'core_deprel'   => $fun_deprel,
            'is_member'     => $member
        );
        foreach my $d (@{$c->{dep}})
        {
            $d->set_parent($pp);
        }
        return $pp;
    }
    # Return the input NTerm phrase if no PP has been detected.
    return $phrase;
}



#------------------------------------------------------------------------------
# Takes a phrase that seems to be a prepositional phrase headed by the
# preposition. Classifies the children of the phrase: finds the preposition,
# the argument and the other dependents. Returns undef if it cannot find the
# argument: that means that this is not a PP! Otherwise returns a reference to
# a hash with preposition, argument and dependents. This method does not modify
# anything in the structure.
#------------------------------------------------------------------------------
sub classify_prague_pp_subphrases
{
    my $self = shift;
    my $phrase = shift; # the input phrase that seems to be a prepositional phrase headed by the preposition
    my @dependents = $phrase->dependents('ordered' => 1);
    my @mwauxp;
    my @punc;
    my @candidates;
    # Classify dependents of the preposition.
    foreach my $d (@dependents)
    {
        # AuxP attached to AuxP (or AuxC to AuxC, or even AuxC to AuxP or AuxP to AuxC) means a multi-word preposition (conjunction).
        if($self->is_deprel($d->deprel(), 'auxpc'))
        {
            push(@mwauxp, $d);
        }
        # Punctuation should never represent an argument of a preposition (provided we have solved any coordinations on lower levels).
        elsif($self->is_deprel($d->deprel(), 'punct'))
        {
            push(@punc, $d);
        }
        # All other dependents are candidates for the argument.
        else
        {
            push(@candidates, $d);
        }
    }
    # If there are no argument candidates, we cannot create a prepositional phrase.
    # We will not complain though. Legitimate AuxP leaves may occur in multi-word prepositions.
    my $n = scalar(@candidates);
    if($n == 0)
    {
        return undef;
    }
    # Now it is clear that we have a prepositional phrase.
    # If this is currently an ordinary NTerm phrase, its head is the preposition (or subordinating conjunction).
    # However, it is also possible that we have a special phrase such as coordination.
    # Then we cannot just take the head. The whole core of the phrase is the preposition.
    # (For coordinate prepositions, consider "the box may be on or under the table".)
    # Therefore we will return the whole phrase as the preposition (the caller will later remove its dependents and keep the core).
    # For ordinary NTerm phrases this will add one unnecessary (but harmless) layer around the head.
    my $preposition = $phrase;
    # If there are two or more argument candidates, we have to select the best one.
    # There may be more sophisticated approaches but let's just take the first one for the moment.
    # Emphasizers (AuxZ) preceding the preposition should be attached to the argument
    # rather than the preposition. However, occasionally they are attached to the preposition, as in [cs]:
    #   , přinejmenším pokud jde o platy
    #   , at-least if are-concerned about salaries
    # ("pokud" is the AuxC and the original head, "přinejmenším" should be attached to the verb "jde" but it is
    # attached to "pokud", thus "pokud" has two children. We want the verb "jde" to become the argument.)
    # Similarly [cs]:
    #   třeba v tom
    #   for-example in the-fact
    # In this case, "třeba" is attached to "v" as AuxY (cc), not as AuxZ (advmod:emph).
    my @ecandidates = grep {$self->is_deprel($_->deprel(), 'auxyz')} (@candidates);
    my @ocandidates = grep {!$self->is_deprel($_->deprel(), 'auxyz')} (@candidates);
    my $argument;
    if(scalar(@ocandidates)>0)
    {
        $argument = shift(@ocandidates);
        @candidates = (@ecandidates, @ocandidates);
    }
    else
    {
        $argument = shift(@candidates);
    }
    my %classification =
    (
        'fun' => $preposition,
        'mwe' => \@mwauxp,
        'arg' => $argument,
        'dep' => [@candidates, @punc]
    );
    return \%classification;
}



__PACKAGE__->meta->make_immutable();

1;



=for Pod::Coverage BUILD

=encoding utf-8

=head1 NAME

Treex::Tool::PhraseBuilder::Prague

=head1 DESCRIPTION

Derived from C<Treex::Core::Phrase::Builder>, this class implements language-
and treebank-specific phrase structures.

There are methods that detect structures in a Prague-style treebank (such as
the Czech Prague Dependency Treebank).

Transformations organized bottom-up during phrase building are advantageous
because we can rely on that all special structures (such as coordination) on the
lower levels have been detected and treated properly so that we will not
accidentially destroy them.

=head1 METHODS

=over

=item build

Wraps a node (and its subtree, if any) in a phrase.

=item detect_prague_pp

Examines a nonterminal phrase in the Prague style. If it recognizes
a prepositional phrase, transforms the general nonterminal to PP.
Returns the resulting phrase (if nothing has been changed, returns
the original phrase).

=item detect_prague_coordination

Examines a nonterminal phrase in the Prague style (with analytical functions
converted to dependency relation labels based on Universal Dependencies). If
it recognizes a coordination, transforms the general NTerm to Coordination.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
