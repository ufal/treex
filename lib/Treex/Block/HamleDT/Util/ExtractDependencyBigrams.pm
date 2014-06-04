package Treex::Block::HamleDT::Util::ExtractDependencyBigrams;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

sub process_atree {
    my $self = shift;
    my $a_root = shift;
    my $language = $a_root->get_zone->language();
    for my $anode ($a_root->get_descendants( )) {
        my @parents = $anode->get_eparents({or_topological => 1, dive => 'AuxCP'});

        my $afun = $anode->afun();
        my $pos  = $anode->get_iset('pos');

        for my $parent (@parents) {
            my $parent_afun =  $parent->afun();
            my $parent_pos  =  $parent->get_iset('pos') || 'ROOT';
            print join "\t", ($language, $parent_pos, $pos, $parent_afun, $afun), "\n";
        }
    }
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::HamleDT::Util::ExtractDependencyBigrams

=head1 DESCRIPTION

Prints afun and POS (parent-child) bigrams to the standard output.

=head1 AUTHOR

Jan Mašek <masek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
