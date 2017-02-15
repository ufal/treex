package Treex::Block::HamleDT::VI::FixUD;
use Moose;
use List::MoreUtils qw(any);
use Treex::Core::Common;
use Lingua::Interset qw(decode);
use utf8;
extends 'Treex::Block::HamleDT::SplitFusedWords';



sub process_atree
{
    my $self = shift;
    my $root = shift;
    $self->fix_multi_syllable_words($root);
}



#------------------------------------------------------------------------------
# UD v2 permits that Vietnamese has words with spaces.
#------------------------------------------------------------------------------
sub fix_multi_syllable_words
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants({'ordered' => 1});
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        if($form =~ m/_/ && $form !~ m/^_+$/)
        {
            $form =~ s/_+/ /g;
            $node->set_form($form);
        }
    }
    $root->get_zone()->set_sentence($self->collect_sentence_text(@nodes));
}



1;

=over

=item Treex::Block::HamleDT::VI::FixUD

A block to fix Vietnamese UD. Currently dummy.

The main UD 1 to 2 conversion is done in a separate block.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
