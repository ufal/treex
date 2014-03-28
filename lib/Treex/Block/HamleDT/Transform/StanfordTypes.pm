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
    Pnom => \&{PnomAtv},
    AuxV => \&{AuxV},
    Pred => 'root',
    AuxP => \&{AuxP},
    Atr  => \&{Atr},
    Adv  => \&{Adv},
    Coord => 'cc',

    # less ordinary afuns
    NR         => 'dep',
    AuxA       => 'det',      # not always used in the harmonization!
    Neg        => 'neg',      # not always used in the harmonization!
    ExD        => 'remnant',
    Apos       => 'appos',    # ?
    Apposition => 'appos',    # ???
    Atv        => \&{PnomAtv},
    AtvV       => \&{PnomAtv},
    AtrAtr     => \&{Atr},
    AtrAdv     => \&{Atr},
    AdvAtr     => \&{Atr},
    AtrObj     => \&{Atr},
    ObjAtr     => \&{Atr},

    # some crazy Aux*
    AuxC => 'mark',
    AuxG => 'dep', # usually already marked as 'punct' from MarkPunct
    AuxK => 'dep', # usually already marked as 'punct' from MarkPunct
    AuxX => 'dep', # usually already marked as 'punct' from MarkPunct
    AuxT => 'mwe',
    AuxR => \&{Obj},
    AuxO => \&{Adv},
    AuxY => \&{AuxY},
    AuxZ => \&{Adv}, # it seems to be labeled e.g. as advmod by the Stanford parser

    # only in ar
    AuxE => \&{Adv},
    AuxM => \&{Adv},
    PredC      => 'dep',      #  "conjunction as the clause's head"
    PredE      => 'dep',      #  "existential predicate"
    PredP      => 'dep',      #  "adposition as the clause's head"
    Ante       => 'appos',

    # only in ta
    AAdjn => \&{Adv},
    AComp => \&{Adv},
    AdjAtr => \&{Atr},
    CC => 'mwe',
    Comp => \&{Atr},

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

    # adpositions (some adpositions are AuxC and should stay mark)
    elsif ( $anode->match_iset( 'pos' => '~prep' ) &&
        $type ne 'mark'
    ) {
       $type = $self->AuxP($anode); 
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

    my $type;

    if ( $anode->match_iset( 'pos' => '~verb' ) ) {
        $type = 'csubj';
        if ( $self->parent_is_passive_verb($anode)) {
            $type = 'csubjpass';
        }
    }
    else {
        $type = 'nsubj';
        if ( $self->parent_is_passive_verb($anode)) {
            $type = 'nsubjpass';
        }
    }

    return $type;
}

# hopefully OK
sub Obj {
    my ( $self, $anode ) = @_;

    # subsequent StanfordObjects sets type to dobj if there is only 1 obj
    my $type = 'obj';

    if ( $anode->match_iset( 'pos' => '~verb' ) ) {
        if ( $self->is_finite($anode) ) {
            $type = 'ccomp';
        }
        else {
            $type = 'xcomp';
        }
    }

    return $type;
}

# Pnom or Atv (Pnom will hopefully get a different label in the subsequent
# StanfordCopulas block)
# hopefully OK
sub PnomAtv {
    my ( $self, $anode ) = @_;

    my $type = 'obj';

    if ( $anode->match_iset( 'pos' => '~adj|verb' ) ) {
        $type = 'xcomp';
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

# hopefully OK
sub AuxP {
    my ($self, $anode) = @_;

    my $type = 'case';

    # compound preps
    my $parent = $anode->get_parent();
    if ( defined $parent &&
        ($parent->match_iset('pos', '~prep') || $parent->afun eq 'AuxP')
    ) {
        # compound preps: the "auxiliaries" are thought to be parts of a
        # multi word expression
        $type = 'mwe';
    }

    return $type;
}

# hopefully OK
sub Atr {
    my ( $self, $anode ) = @_;

    # default ("modifier word")
    my $type = 'amod';
    
    if ( $anode->match_iset( 'pos' => '~noun' ) ) {
        # nominal dependent
        $type = 'nmod';
    }
    elsif ( $anode->match_iset( 'pos' => '~num' ) ) {
        # numeral
        if ( $self->parent_has_pos($anode, 'num') ) {
            $type = 'compound';
        } else {
            $type = 'nummod';
        }
    }
    elsif ( $anode->match_iset( 'pos' => '~verb' ) ) {
        # predicate dependent
        if ( $self->is_finite($anode) ) {
            $type = 'relcl';
        }
        else {
            $type = 'nfincl';
        }
    }

    return $type;
}

# hopefully OK
sub Adv {
    my ( $self, $anode ) = @_;

    # default ("modifier word")
    my $type = 'advmod';

    if ( $anode->match_iset( 'pos' => '~noun' ) ) {
        # nominal dependent
        $type = 'nmod';
    }
    elsif ( $anode->match_iset( 'pos' => '~verb' ) ) {
        # predicate dependent
        if ( $self->is_finite($anode) ) {
            $type = 'advcl';
        }
        else {
            $type = 'nfincl';
        }
    }

    return $type;
}

# hopefully +- OK
sub AuxY {
    my ($self, $anode) = @_;

    my $type;
    
    my $parent = $anode->get_parent();
    if ( defined $parent && $parent->afun =~ /^Aux[XY]$/) {
        # compound AuxY
        $type = 'mwe';
    } else {
        # it seems to be labeled e.g. as advmod by the Stanford parser
        $type = $self->Adv($anode);
    }
    
    return $type;
}

# HELPER SUBS
# I use get_parent() and thanks to the properties of Stanford Dependencies, this
# is the same as using get_eparent() for the first conjunct, and irrelevant for
# other conjuncts since they all should get the 'conj' type

sub is_finite {
    my ($self, $anode) = @_;

    my $verbform = $anode->get_iset('verbform');
    # TODO (now takes the first one from multiple values)
    $verbform =~ s/\|.*//;

    return ($verbform eq '' || $verbform eq 'fin');
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

sub parent_has_pos {
    my ($self, $anode, $pos) = @_;

    my $parent = $anode->get_parent();
    if ( defined $parent &&
        $parent->match_iset( 'pos' => '~' . $pos )
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

TODO: not yet ready, still many things to solve -- e.g. possessives (not marked
now)

Coordination structures should get marked correctly -- the block relies on
the data previously having been processed by L<HamleDT::Transform::CoordStyle>.

Punctuation is to have been marked by L<HamleDT::Transform::MarkPunct>.

If C<conll/deprel> already contains a value, this value is kept. Delete the
values first to avoid that. (But do that before calling
L<HamleDT::Transform::MarkPunct> since this block stores the C<punct> types into
C<conll/deprel>.)

Now based on USD 2014 (LREC).

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

