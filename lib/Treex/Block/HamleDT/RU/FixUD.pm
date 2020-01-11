package Treex::Block::HamleDT::RU::FixUD;
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
# Kira's conversion of SynTagRus does not set the pronominal type.
#------------------------------------------------------------------------------
sub fix_features
{
    my $self = shift;
    my $root = shift;
    my @nodes = $root->get_descendants();
    foreach my $node (@nodes)
    {
        my $form = $node->form();
        my $lemma = $node->lemma();
        my $iset = $node->iset();
        if($iset->is_pronominal())
        {
            if($lemma =~ m/^(я|ты|он|она|оно|мы|вы|они)$/)
            {
                $iset->add('prontype' => 'prs', 'poss' => '', 'reflex' => '');
            }
            elsif($lemma =~ m/^(себя)$/)
            {
                $iset->add('prontype' => 'prs', 'poss' => '', 'reflex' => 'yes');
            }
            elsif($lemma =~ m/^(мой|твой|его|ее|наш|ваш|их)$/)
            {
                $iset->add('prontype' => 'prs', 'poss' => 'yes', 'reflex' => '');
            }
            elsif($lemma =~ m/^(свой)$/)
            {
                $iset->add('prontype' => 'prs', 'poss' => 'yes', 'reflex' => 'yes');
            }
            elsif($lemma =~ m/^(этот?|тот?|такой|сей)$/)
            {
                $iset->add('prontype' => 'dem');
            }
            elsif($lemma =~ m/^(который|кто|что|какой|чей|кой)$/)
            {
                $iset->add('prontype' => 'int|rel');
            }
            elsif($lemma =~ m/^(один|некоторый|некий|любой|некто|нечто|(кто|что|какой)-(то|нибудь|либо)|кое-(кто|что|какой)|прочее)$/)
            {
                $iset->add('prontype' => 'ind');
            }
            elsif($lemma =~ m/^(весь|все|каждый|всякий)$/)
            {
                $iset->add('prontype' => 'tot');
            }
            elsif($lemma =~ m/^(никто|ничто|никакой|некого|нечего|никой)$/)
            {
                $iset->add('prontype' => 'neg');
            }
        }
    }
}



1;

=over

=item Treex::Block::HamleDT::RU::FixUD

A block to fix SynTagRus UD. Currently used to add features that are needed to
correctly generate the enhanced UD graph.

=back

=head1 AUTHORS

Daniel Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017, 2020 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
