package Treex::Block::Tutorial::StemTamil;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# YOUR_TASK: declare that you want to use the module which does the actual splitting

sub process_zone {
    my ( $self, $zone ) = @_;
    my $sentence = $zone->sentence;

    # YOUR_TASK: split the suffixes (instead of this dummy modification)
    $sentence = 'dummy ' . $sentence;
    
    $zone->set_sentence($sentence);
    return;
}

1;

=encoding utf8

=head1 NAME

Treex::Block::Tutorial::StemTamil - Tamil suffix splitting

=head1 NOTE

This is just a tutorial template for L<Treex::Tutorial>.
The current implementation only creates flat a-trees.
You must fill in the code marked as YOUR_TASK.
The solution can be found in L<Treex::Block::Tutorial::Solution::StemTamil>.

=head1 DESCRIPTION

When processing agglutinative languages,
many NLP tasks (such as SMT) profit from a pre-processing,
where suffixes are separated from word stems,
so the suffixes can be handled as separate tokens.

This block should do this pre-processing for Tamil.
The real work will be done by a tool L<Treex::Tool::Stemmer::TA::Simple>.
You can read the documentation for this module by typing:

 perldoc Treex::Tool::Stemmer::TA::Simple


You can test this block with:

  echo 'enakku patikkiRa pazakkam irukkiRaTu' \
   | treex -Lta Read::Sentences Tutorial::StemTamil Write::Sentences

It should print "ena +kku pati +kkiR +a pazakkam iru +kkiR +aTu".

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
