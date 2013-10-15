package Treex::Block::HamleDT::Transform::StanfordTypes;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

# Prague afun to Stanford type
# TODO 'dep' means I don't know what to use,
# usually it should eventually become something more specific!
my %afun2type = (

    # ordinary afuns
    Sb   => \&{Sb},
    Obj  => \&{Obj},
    Pnom => \&{Pnom},
    AuxV => \&{AuxV},
    Pred => 'root',
    AuxP => 'adpmod',
    Atr  => \&{Atr},
    Adv  => \&{Adv},
    Coord => 'cc',

    # less ordinary afuns
    NR         => 'dep',
    AuxA       => 'det',      # not always used in the harmonization!
    Neg        => 'neg',      # not always used in the harmonization!
    ExD        => 'dep',      # TODO? \&{ExD},
    Apos       => 'appos',    # ?
    Apposition => 'appos',    # ???
    Atv        => \&{Atv},
    AtvV       => \&{Atv},
    AtrAtr     => \&{Atr},
    AtrAdv     => \&{Atr},
    AdvAtr     => \&{Atr},
    AtrObj     => \&{Atr},
    ObjAtr     => \&{Atr},
    PredC      => 'dep',      # only in ar; "conjunction as the clause's head"
    PredE      => 'dep',      # only in ar; "existential predicate"
    PredP      => 'dep',      # only in ar; "adposition as the clause's head"
    Ante       => 'dep',      # only in ar;

    # some crazy Aux*
    AuxC => 'mark',    # or complm? or ... ???
    AuxG => 'dep', # usually already marked as 'punct' from MarkPunct
    AuxK => 'dep', # usually already marked as 'punct' from MarkPunct
    AuxX => 'dep', # usually already marked as 'punct' from MarkPunct
    AuxT => \&{Adv},
    AuxR => \&{Adv},
    AuxO => \&{Adv},
    AuxE => 'dep',   # only in ar(?)
    AuxM => 'dep',   # only in ar(?)
    AuxY => \&{Adv}, # it seems to be labeled e.g. as advmod by the Stanford parser
    AuxZ => \&{Adv}, # it seems to be labeled e.g. as advmod by the Stanford parser
);

sub process_anode {
    my ( $self, $anode ) = @_;

    if ( defined $anode->conll_deprel && $anode->conll_deprel ne '' ) {
        # type already set by preceding blocks -> skip
        return;
    }

    my $form = $anode->form;

    
    # CONVERSION ACCORDING TO %afun2type

    # get the type;
    # either already the type string
    # or a reference to a subroutine that will return the type string
    my $type = $afun2type{$anode->afun};
    if ( defined $type ) {
        if ( ref($type) ) {
            # asserf ref($type) == 'CODE'
            $type = &$type($self, $anode);
        }
        # else $type is already the type string
    }
    else {
        log_warn "Unknown type for afun " . $anode->afun . " ($form)!";
        $type = 'dep';
    }
    
    
    # SOME POST-CHECKS

    # root
    if ( $anode->get_parent()->is_root()) {
        $type = 'root';
    }
    # negations
    elsif ( $anode->match_iset( 'pos' => '~part', negativeness => 'neg' ) ) {
        $type = 'neg';
    }
    # determiners
    elsif ( $anode->match_iset( 'subpos' => '~art|det' ) ) {
        $type = 'det';
    }

    # adpositions
    elsif ( $anode->match_iset( 'pos' => '~prep' )) {
        $type = 'adp';
    }
    elsif ( $self->parent_is_adposition($anode)) {
        # adpositional objects
        if ( $anode->match_iset( 'pos' => '~noun' ) ) {
            $type = 'adpobj';
        }
        # adpositional complements
        else {
           $type = 'adpcomp';
        }
    }

    # partmod
    elsif ( $anode->match_iset( 'pos' => '~verb' ) &&
        $self->get_simplified_verbform($anode) eq 'part'
    ) {
        $type = 'partmod';
    }

    # MARK CONJUNCTS
    # the first conjunct (which is the head of the coordination) is NOT marked
    # by is_member, so only its children get the 'conj' type, which is correct
    # (relies on the current behaviour of Transform::CoordStyle
    if ( $anode->is_member ) {
        $type = 'conj';
    }

    # SET THE RESULTING SD TYPE
    $anode->set_conll_deprel($type);

    return;
}

# AFUN-SPECIFIC SUBS

# hopefully OK
sub Sb {
    my ( $self, $anode ) = @_;

    my $type = 'subj';

    if ( $anode->match_iset( 'pos' => '~noun' ) ) {
        $type = 'nsubj';
        if ( $self->parent_is_passive_verb($anode)) {
            $type = 'nsubjpass';
        }
    }
    elsif ( $anode->match_iset( 'pos' => '~verb' ) ) {
        $type = 'csubj';
        if ( $self->parent_is_passive_verb($anode)) {
            $type = 'csubjpass';
        }
    }

    return $type;
}

# hopefully OK
sub Obj {
    my ( $self, $anode ) = @_;

    my $type = 'comp';

    if ( $anode->match_iset( 'pos' => '~noun' ) ) {
        $type = 'obj';
        # elsif ( $anode->match_iset( case => '~acc' ) ) {
        #   $type = 'dobj';
        # }
        # elsif ( $anode->match_iset( case => '~dat' ) ) {
        #   $type = 'iobj';
        # }
    }
    elsif ( $anode->match_iset( 'pos' => '~verb' ) ) {
        if ( $self->get_simplified_verbform($anode) eq 'fin' ) {
            $type = 'ccomp';
        }
        else {
            $type = 'xcomp';
        }
    }

    return $type;
}

# probably TODO
sub Pnom {
    my ( $self, $anode ) = @_;

    my $type = 'comp';

    if ( $anode->match_iset( 'pos' => '~adj' ) ) {
        $type = 'acomp';
    }
    elsif ( $anode->match_iset( 'pos' => '~noun') ) {
        $type = 'obj';
    }

    return $type;
}

# hopefully OK
sub AuxV {
    my ( $self, $anode ) = @_;

    my $type = 'aux';

    if ( $self->parent_is_passive_verb($anode) ) {
        $type = 'auxpass';
    }

    return $type;
}

# probably TODO
sub Atv {
    my ( $self, $anode ) = @_;

    my $type = 'comp';

    if ( $anode->match_iset( 'pos' => '~adj' ) ) {
        $type = 'acomp';
    }
    elsif ( $anode->match_iset( 'pos' => '~verb' ) ) {
        $type = 'partmod';
    }

    return $type;
}

# TODO
sub Atr {
    my ( $self, $anode ) = @_;

    my $type = 'mod';

    # TODO: I usually do not know the priorities,
    # therefore I use "if" instead of "elsif"
    # and I do not nest the ifs
    
    # noun modifiers
    if ( $self->parent_is_noun($anode) ) {
    if ( $anode->match_iset( 'pos' => '~noun' ) &&  ) {
        $type = 'nmod';
    }
    if ( $anode->match_iset( 'pos' => '~adj' ) && $self->parent_is_noun($anode) ) {
        $type = 'amod';
    }
    if ( $anode->match_iset( 'pos' => '~verb' ) && $self->parent_is_noun($anode) ) {
        if ( $self->get_simplified_verbform($anode) eq 'fin' ) {
            $type = 'rcmod';
        }
        else {
            $type = 'infmod';
        }
    }

    }

    # possessives
    if ( $anode->match_iset( 'poss' => '~poss' ) ) {
        $type = 'poss';
    }
    # numerals
    if ( $anode->match_iset( 'pos' => '~num' ) ) {
        $type = 'num';
        #if ( $self->parent_is_numeral($anode) ) {
        #    $type = 'number';
        #}
    }
    #elsif ( $self->parent_is_numeral($anode) ) {
    #    $type = 'quantmod';
    #}

    return $type;
}

# TODO
sub Adv {
    my ( $self, $anode ) = @_;

    my $type = 'mod';

    if ( $anode->match_iset( 'pos' => '~adv' ) ) {
        $type = 'advmod';
    }
    elsif ( $anode->match_iset( 'pos' => '~noun' ) ) {
        $type = 'npadvmod';
    }
    elsif ( $anode->match_iset( 'pos' => '~verb' ) &&
        $self->parent_is_verb($anode) &&
        $self->get_simplified_verbform($anode) eq 'fin'
    ) {
        $type = 'advcl';
    }
    elsif ( $anode->match_iset( 'pos' => '~adj' ) && $self->parent_is_noun($anode) ) {
        $type = 'amod';
    }

    return $type;
}

# TODO
sub ExD {
    my ($self, $anode) = @_;

    my $type = 'dep';

    if ( $anode->get_parent()->is_root() ) {
        $type = 'root';
    }

    return $type;
}

# HELPER SUBS
# I use get_parent() and thanks to the properties of Stanford Dependencies, this
# is the same as using get_eparent() for the first conjunct, and irrelevant for
# other conjuncts since they all should get the 'conj' type

my %simplified_verbform = (
    '' => 'fin',
    fin => 'fin',
    inf => 'inf',
    sup => 'inf',
    part => 'part',
    trans => 'part',
    ger => 'part',
);

sub get_simplified_verbform {
    my ($self, $anode) = @_;

    my $verbform = $anode->get_iset('verbform');
    # TODO (now takes the first one from multiple values)
    $verbform =~ s/\|.*//;

    return $simplified_verbform{$verbform} // 'fin';
}

sub parent_is_verb {
    my ($self, $anode) = @_;

    my $parent = $anode->get_parent();
    if ( defined $parent && $parent->match_iset( 'pos' => '~verb' )) {
        return 1;
    }
    else {
        return 0;
    }
}

sub parent_is_passive_verb {
    my ($self, $anode) = @_;

    my $parent = $anode->get_parent();
    if ( defined $parent &&
        $parent->match_iset( 'pos' => '~verb', voice => '~pass' )
    ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub parent_is_adposition {
    my ($self, $anode) = @_;

    my $parent = $anode->get_parent();
    if ( defined $parent &&
        $parent->match_iset( 'pos' => '~prep' )
    ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub parent_is_noun {
    my ($self, $anode) = @_;

    my $parent = $anode->get_parent();
    if ( defined $parent &&
        $parent->match_iset( 'pos' => '~noun' )
    ) {
        return 1;
    }
    else {
        return 0;
    }
}

sub parent_is_numeral {
    my ($self, $anode) = @_;

    my $parent = $anode->get_parent();
    if ( defined $parent &&
        $parent->match_iset( 'pos' => '~num' )
    ) {
        return 1;
    }
    else {
        return 0;
    }
}



1;

=head1 NAME 

Treex::Block::HamleDT::Transform::StanfordTypes -- convert from HamleDT afuns to Stanford
dependencies types

=head1 DESCRIPTION

The Stanford dependency types are stored into C<conll/deprel>.
This is for this block to be able to look at the C<afun>s at any time;
however, this block should B<not> look at original deprels, as it should be
language-independent (and especially treebank-independent).

TODO: not yet ready, still many things to solve

Coordination structures should get marked correctly -- the block relies on
the data previously having been processed by L<HamleDT::Transform::CoordStyle>.

Punctuation is to have been marked by L<HamleDT::Transform::MarkPunct>.

If C<conll/deprel> already contains a value, this value is kept. Delete the
values first to avoid that. (But do that before calling
L<HamleDT::Transform::MarkPunct> since this block stores the C<punct> types into
C<conll/deprel>.)

There are many log_warn messages that are commented out at the moment, which
might suggest an error in the preceding conversion steps. Comment them back in
if you are interested in that.

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

