package Treex::Block::HamleDT::HE::Harmonize;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::HamleDT::Harmonize';

sub process_zone {
    my $self   = shift;
    my $zone   = shift;

    my $a_root = $self->SUPER::process_zone($zone);
    # $self->restructure_coordination($a_root);
    $self->attach_final_punctuation_to_root($a_root);
    
    $self->check_afuns($a_root);

    return $a_root;
}

# TODO
my %deprel2afun = (
    # dep => 'Atr',
    CONJ => 'Coord',
    SBJ => 'Sb',
    ADJ => 'Atr',
    ADV => 'Adv',
    # ROOT => 'Pred',
    COM => 'Atv',
    OBJ => 'Obj',
    MOD => 'AuxV',
    MW => 'Apos',
    prep_infl => 'AuxP',
    at_infl => 'Atr',
    pos_infl => 'Atr',
    rb_infl => 'Atr',
);


sub deprel_to_afun {
    my $self   = shift;
    my $root   = shift;
    my @nodes  = $root->get_descendants();

    for my $node (@nodes) {
	    my $deprel = $node->conll_deprel;
	    my $parent = $node->get_parent();

        my $afun = $deprel2afun{$deprel};

        # TODO

        if ( defined $afun ) {
            $node->set_afun($afun);
        }
        else {
            $self->set_default_afun($node);
        }
    }
}

sub detect_coordination
{
    my $self = shift;
    my $node = shift;
    my $coordination = shift;
    my $debug = shift;
    return 'not implemented';
}

1;

=head1 NAME 

Treex::Block::HamleDT::HE::Harmonize

=head1 DESCRIPTION

Convert Hebrew treebank dependency trees to HamleDT style.

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

