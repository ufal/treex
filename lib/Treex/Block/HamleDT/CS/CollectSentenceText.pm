package Treex::Block::HamleDT::CS::CollectSentenceText;
use utf8;
use Moose;
use Treex::Core::Common;
use Lingua::Interset qw(decode encode);
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Reconstructs the sentence text attribute from the actual nodes and their
# no_space_after attribute.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    $zone->set_sentence($root->collect_sentence_text());
}



1;

=over

=item Treex::Block::HamleDT::CS::CollectSentenceText

Reconstructs the sentence text attribute, stored in the zone, from the actual
nodes and their no_space_after attribute.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Faculty of Mathematics and Physics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
