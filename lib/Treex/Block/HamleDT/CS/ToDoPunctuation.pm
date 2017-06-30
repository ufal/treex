package Treex::Block::HamleDT::CS::ToDoPunctuation;
use utf8;
use Moose;
use Treex::Core::Common;
use Lingua::Interset qw(decode encode);
extends 'Treex::Block::HamleDT::SplitFusedWords'; # collect_sentence_text()



#------------------------------------------------------------------------------
# Processes all to-do instructions in the a-tree of a zone.
#------------------------------------------------------------------------------
sub process_zone
{
    my $self = shift;
    my $zone = shift;
    my $root = $zone->get_atree();
    my @nodes = $root->get_descendants();
    my $changed = 0;
    foreach my $node (@nodes)
    {
        my $misc = $node->wild()->{misc};
        if(defined($misc))
        {
            my @misc = split(/\|/, $misc);
            if(any {$_ eq 'ToDo=OpeningQuote'} (@misc))
            {
                $node->set_form('„');
                $node->set_lemma('"');
                @misc = grep {$_ ne 'ToDo=OpeningQuote'} (@misc);
                $changed = 1;
            }
            if(any {$_ eq 'ToDo=ClosingQuote'} (@misc))
            {
                $node->set_form('“');
                $node->set_lemma('"');
                @misc = grep {$_ ne 'ToDo=ClosingQuote'} (@misc);
                $changed = 1;
            }
            if(any {$_ eq 'ToDo=HyphenToDash'} (@misc))
            {
                $node->set_form('–');
                $node->set_lemma('-');
                @misc = grep {$_ ne 'ToDo=HyphenToDash'} (@misc);
                $changed = 1;
            }
            if($changed)
            {
                if(scalar(@misc)>=1)
                {
                    $node->wild()->{misc} = join('|', @misc);
                }
                else
                {
                    delete($node->wild()->{misc});
                }
            }
        }
    }
    if($changed)
    {
        $zone->set_sentence($self->collect_sentence_text(@nodes));
    }
}



1;

=over

=item Treex::Block::HamleDT::CS::ToDoPunctuation

Reads to-do instructions from the MISC column of a CoNLL-U file, executes them
and removes them from the MISC column. The instructions are prepared by quot.pl,
which operates directly on the CoNLL-U file but does not apply the changes to
the punctuation symbols. The changes are applied here, and the sentence-level
attribute text is modified accordingly.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by Institute of Formal and Applied Linguistics, Faculty of Mathematics and Physics, Charles University, Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
