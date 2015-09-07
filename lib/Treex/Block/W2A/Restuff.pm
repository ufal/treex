package Treex::Block::W2A::Restuff;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Looks for the output of a delexicalized parser (zone mt_dlx), which does not
# contain word forms, and for the original sentence (zone mt), which does not
# contain syntactic annotation. Combines the two trees in the delexicalized
# zone (because copying word forms is easier than copying the tree structure).
#------------------------------------------------------------------------------
sub process_bundle
{
    my $self = shift;
    my $bundle = shift;
    my $language = $self->language();
    my @original = $bundle->get_zone($language)->get_atree()->get_descendants({ordered => 1});
    my @delex = $bundle->get_zone($language, 'dlx')->get_atree()->get_descendants({ordered => 1});
    my $n = scalar(@delex);
    for (my $i = 0; $i < $n; $i++)
    {
        my $tgt = $delex[$i];
        my $src = $original[$i];
        if (defined($src) && defined($tgt))
        {
            $tgt->set_form($src->form());
        }
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::Restuff

=head1 DESCRIPTION

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
