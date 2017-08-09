package Treex::Block::HamleDT::FA::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Lingua::Interset qw(decode);
use utf8;
extends 'Treex::Core::Block';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_features($root);
}



#------------------------------------------------------------------------------
# Features are stored in conll/feat and their format is not compatible with
# Universal Dependencies.
#------------------------------------------------------------------------------
sub fix_features
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
}



1;

=over

=item Treex::Block::HamleDT::FA::FixUD

A block to fix Persian UD. Currently dummy.

The main UD 1 to 2 conversion is done in a separate block.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
