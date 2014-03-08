package Treex::Tool::Depfix::CS::PairGetter;
use Moose;
use Treex::Core::Common;
use utf8;

sub get_pair {
    my ( $node ) = @_;

    return if $node->isa('Treex::Core::Node::Deleted');

    my ($parent) = $node->get_eparents({
            or_topological => 1,
            ignore_incorrect_tree_structure => 1
        });

    return if ( !defined $parent || $parent->is_root );

    my $d_tag = ($node->tag && length ($node->tag) >= 15) ?
        $node->tag : '---------------';
    my %d_categories = (
        pos    => substr( $d_tag, 0,  1 ),
        subpos => substr( $d_tag, 1,  1 ),
        gen    => substr( $d_tag, 2,  1 ),
        num    => substr( $d_tag, 3,  1 ),
        case   => substr( $d_tag, 4,  1 ),
        pgen   => substr( $d_tag, 5,  1 ),
        pnum   => substr( $d_tag, 6,  1 ),
        pers   => substr( $d_tag, 7,  1 ),
        tense  => substr( $d_tag, 8,  1 ),
        grade  => substr( $d_tag, 9,  1 ),
        neg    => substr( $d_tag, 10, 1 ),
        voice  => substr( $d_tag, 11, 1 ),
        var    => substr( $d_tag, 14, 1 ),
        tag    => $d_tag,
        afun   => ( $node->afun || '' ),
        flt    => ( $node->form || '' ) . '#' . ( $node->lemma || '' ) . '#' . ( $node->tag || '' ),
    );
    my $g_tag = ($parent->tag && length ($parent->tag) >= 15) ?
        $parent->tag : '---------------';
    my %g_categories = (
        pos    => substr( $g_tag, 0,  1 ),
        subpos => substr( $g_tag, 1,  1 ),
        gen    => substr( $g_tag, 2,  1 ),
        num    => substr( $g_tag, 3,  1 ),
        case   => substr( $g_tag, 4,  1 ),
        pgen   => substr( $g_tag, 5,  1 ),
        pnum   => substr( $g_tag, 6,  1 ),
        pers   => substr( $g_tag, 7,  1 ),
        tense  => substr( $g_tag, 8,  1 ),
        grade  => substr( $g_tag, 9,  1 ),
        neg    => substr( $g_tag, 10, 1 ),
        voice  => substr( $g_tag, 11, 1 ),
        var    => substr( $g_tag, 14, 1 ),
        tag    => $g_tag,
        afun   => ( $parent->afun || '' ),
        flt    => ( $parent->form || '' ) . '#' . ( $parent->lemma || '' ) . '#' . ( $parent->tag || '' ),
    );

    return ( $node, $parent, \%d_categories, \%g_categories );
}

1;

=head1 NAME 

Treex::

=head1 DESCRIPTION

=head1 PARAMETERS

=over

=back

=head1 AUTHOR

Rudolf Rosa <rosa@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics,
Charles University in Prague

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

