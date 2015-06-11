package Treex::Block::T2TAMR::AddNegNodes;

use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );
has '+selector' => ( isa => 'Str', default => 'amrConvertedFromT' );

sub get_node_var {
    my ( $self, $troot, $letter ) = @_;
    my @vars = grep { $_ =~ /^$letter/ } map { my $x = $_->t_lemma; $x =~ s/\/.*//; $x } $troot->get_descendants();
    return $letter if ( !@vars );
    my $highest_taken = 1;
    foreach my $var ( map { $_ =~ s/^$letter//; $_ } @vars ) {
        $var = 1 if (!$var);
        if ( $var > $highest_taken ) {
            $highest_taken = $var;
        }
    }
    return $letter . ( $highest_taken + 1 );
}

sub process_tnode {

    my ( $self, $tnode ) = @_;

    # skip cases where we don't have the original t-layer
    return if ( !$tnode->src_tnode );

    # skip non-negated
    return if ( ( $tnode->src_tnode->gram_negation // '' ) ne 'neg1' );

    # skip those that already have a negation node
    return if ( any { $_->t_lemma =~ /#Neg/ } $tnode->get_echildren( { or_topological => 1 } ) );

    my $var = $self->get_node_var($tnode->get_root, 'n');

    # create the negation node
    my $tneg = $tnode->create_child(
        {   
            t_lemma      => $var . '/#Neg',
        }
    );
    $tneg->wild->{modifier} = 'RHEM';
    $tneg->shift_before_node($tnode);
    return;
}

1;

=head1 NAME

Treex::Block::T2TAMR::AddNegNodes

=head1 DESCRIPTION

Convert negation grammateme to a #Neg node (which can be simply converted to AMR polarity -).

=head1 AUTHORS

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
