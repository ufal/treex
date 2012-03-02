package Treex::Block::A2A::CS::FixP4_temp;
use Moose;
use Treex::Core::Common;
use utf8;
extends 'Treex::Block::A2A::CS::FixAgreement';

sub fix {
    my ( $self, $dep, $gov, $d, $g, $en_hash ) = @_;
    my %en_counterpart = %$en_hash;

    if ( $dep->lemma eq 'který' ) {

        # find closest preceding N (or PL or PD)
        my $node = $dep;
        while ( $node->tag !~ /^(N|PL|PD)/ ) {
            $node = $node->get_prev_node();
            if ( !defined $node ) {
                return;
            }
        }

        # skip coordinations because they are hard to do correctly
        if ( $node->is_member ) {
            return;
        }

        # find corresponding en node
        my $en_dep  = $en_counterpart{$dep};
        my $en_node = $en_counterpart{$node};

        if ( !defined $en_dep || !defined $en_node ) {
            return;
        }

        if ( $en_dep->is_descendant_of($en_node) ) {
            $self->logfix1( $dep, "P4" );
            my $gn = substr $node->tag, 2, 2;
            substr $d->{tag}, 2, 2, $gn;
            $self->regenerate_node( $dep, $d->{tag} );
            $self->logfix2($dep);
        }
    }
}

1;

=pod

=encoding utf-8

=head1 NAME

Treex::Block::A2A::CS::FixP4 - fixing 'který' agreement

=head1 DESCRIPTION


=head1 AUTHORS

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles
University in Prague

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.
