package Treex::Block::W2W::RemoveLeadingTrailingSpaces;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



#------------------------------------------------------------------------------
# Makes sure that if a word form or lemma contains whitespace characters, these
# only occur inside but not in the beginning or the end of the word.
#------------------------------------------------------------------------------
sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $form = $node->form();
    if(defined($form))
    {
        $form =~ s/^\s+//;
        $form =~ s/\s+$//;
        $node->set_form($form);
    }
    my $lemma = $node->lemma();
    if(defined($lemma))
    {
        $lemma =~ s/^\s+//;
        $lemma =~ s/\s+$//;
        $node->set_lemma($lemma);
    }
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::RemoveLeadingTrailingSpaces

=head1 DESCRIPTION

Makes sure that if a word form or lemma contains whitespace characters, these
only occur inside but not in the beginning or the end of the word.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2019 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
