package Treex::Block::HamleDT::Test::Statistical::OutputAfunBigrams;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_anode {
    my $self = shift;
    my $node = shift;
    my @parents = $node->get_eparents({or_topological => 1, dive => 'AuxCP'});

    my $afun = $node->afun();
    my $pos  = $node->get_iset('pos');

    for my $parent (@parents) {
        my $parent_afun = (defined $parent) ? $parent->afun() : 'ROOT';
        my $parent_pos  = (defined $parent) ? $parent->get_iset('pos') : 'ROOT';
        print join "\t", ($parent_pos, $pos, $parent_afun, $afun), "\n";
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Test::Statistical::OutputAfunBigrams

=head1 DESCRIPTION

Prints afun and POS (parent-child) bigrams to the standard output.

=head1 AUTHOR

Jan Mašek <masek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
