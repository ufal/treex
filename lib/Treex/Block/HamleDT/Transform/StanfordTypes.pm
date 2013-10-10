package Treex::Block::HamleDT::Transform::StanfordTypes;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Core::Block';

# regex for verbform of a finite verb
# my $FINITE = '~fin';
my $FINITE = '!~inf';

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
    AuxP => 'prep',
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
    PredC      => 'dep',
    PredE      => 'dep',
    PredP      => 'dep',
    Ante       => 'dep',

    # some crazy Aux*
    AuxC => 'mark',    # or complm? or ... ???
    AuxG => 'punct',
    AuxK => 'punct',
    AuxX => 'punct',
    AuxT => \&{Adv},
    AuxR => \&{Adv},
    AuxO => \&{Adv},
    AuxE => 'dep',
    AuxM => 'dep',
    AuxY => \&{Adv}, # it seems to be labeled e.g. as advmod by the Stanford parser
    AuxZ => \&{Adv}, # it seems to be labeled e.g. as advmod by the Stanford parser
);

sub process_anode {
    my ( $self, $anode ) = @_;

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
    if ( $anode->get_parent()->is_root()
        # && $type ne 'root'
    ) {
        # log_warn "Attempted to use type '$type' for the root ($form)!";
        $type = 'root';
    }
    # punctuation
    elsif ( $anode->match_iset( 'pos' => 'punc' ) || $anode->form =~ /^\p{IsP}+$/
        # && $type ne 'punct'
    ) {
        # log_warn "Attempted to use type '$type' for a punctuation ($form)!";
        $type = 'punct';
    }
    elsif ( $anode->form !~ /^\p{IsP}+$/ && $type eq 'punct' ) {
        # log_warn "Attempted to use type 'punct' for a non-punctuation ($form)!";
        $type = 'dep';
    }
    # determiners
    elsif ( $anode->match_iset( 'subpos' => '~art|det' ) ) {
        $type = 'det';
    }
    # prepositions
    elsif ( $anode->match_iset( 'pos' => 'prep' )
        # && $type ne 'prep'
    ) {
        # log_warn "Attempted to use type '$type' for a preposition ($form)!";
        $type = 'prep';
    }
    # prepositional objects
    elsif ( $anode->match_iset( 'pos' => 'noun' ) && $self->parent_is_preposition($anode)
        # && $type ne 'pobj'
    ) {
        # log_warn "Attempted to use type '$type' for a pobj ($form)!";
        $type = 'pobj';
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
    elsif ( $anode->match_iset( 'pos' => '~verb', verbform => $FINITE ) ) {
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
        if ( $self->parent_is_preposition($anode)) {
            $type = 'pobj';
        }
        # elsif ( $anode->match_iset( case => '~acc' ) ) {
        #   $type = 'dobj';
        # }
        # elsif ( $anode->match_iset( case => '~dat' ) ) {
        #   $type = 'iobj';
        # }
    }
    elsif ( $anode->match_iset( 'pos' => '~verb' ) ) {
        if ( $anode->match_iset( verbform => $FINITE ) ) {
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
        if ( $self->parent_is_preposition($anode)) {
            $type = 'pobj';
        }
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

    return $type;
}

# TODO
sub Atr {
    my ( $self, $anode ) = @_;

    my $type = 'mod';

    # TODO: I usually do not know the priorities,
    # therefore I use "if" instead of "elsif"
    # and I do not nest the ifs
    if ( $anode->match_iset( 'pos' => '~noun' ) && $self->parent_is_noun($anode) ) {
        $type = 'nmod';
    }
    if ( $anode->match_iset( 'pos' => '~adj' ) && $self->parent_is_noun($anode) ) {
        $type = 'amod';
    }
    if ( $anode->match_iset( 'pos' => '~verb', verbform => $FINITE ) && $self->parent_is_noun($anode) ) {
        $type = 'rcmod';
    }
    if ( $anode->match_iset( 'pos' => '~noun' ) && $self->parent_is_preposition($anode) ) {
        $type = 'pobj';
    }
    # possessives
    if ( $anode->match_iset( 'poss' => '~poss' ) ) {
        $type = 'poss';
        if ( $anode->match_iset( 'pos' => '~part' ) ) {
            $type = 'possessive';
        }
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
    elsif ( $anode->match_iset( 'pos' => '~verb', verbform => $FINITE ) &&
        $self->parent_is_verb($anode)
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

sub parent_is_preposition {
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

