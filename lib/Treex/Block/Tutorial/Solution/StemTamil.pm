package Treex::Block::Tutorial::Solution::StemTamil;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# declare we want to use the module which does the actual splitting
use Treex::Tool::Stemmer::TA::Simple;

sub process_zone {
    my ( $self, $zone ) = @_;
    my $sentence = $zone->sentence;

    # Delegate the actual suffix splitting to the tool
    $sentence = Treex::Tool::Stemmer::TA::Simple::stem_sentence($sentence);
    
    $zone->set_sentence($sentence);
    return;
}

1;

=encoding utf8

=head1 NAME

Treex::Block::Tutorial::Solution::StemTamil - Tamil suffix splitting

=head1 DESCRIPTION

When processing agglutinative languages,
many NLP tasks (such as SMT) profit from a pre-processing,
where suffixes are separated from word stems,
so the suffixes can be handled as separate tokens.

This block does this pre-processing for Tamil.
The real work is be done by a tool L<Treex::Tool::Stemmer::TA::Simple>.


You can test this block with:

  echo 'enakku patikkiRa pazakkam irukkiRaTu' \
   | treex -Lta Read::Sentences Tutorial::Solution::StemTamil Write::Sentences

It should print "ena +kku pati +kkiR +a pazakkam iru +kkiR +aTu".

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
