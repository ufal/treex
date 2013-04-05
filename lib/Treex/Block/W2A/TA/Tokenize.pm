package Treex::Block::W2A::TA::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';


override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;
    $sentence = super();
    $sentence =~ s/^(.*)$/ $1 /;	
	$sentence =~ s/(^\s+|\s+$)//;
	$sentence =~ s/\s+/ /g;	
    return $sentence;    
};


1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TA::Tokenize - Tamil Tokenizer

=head1 DESCRIPTION

Language specific rules are written in the form of regular expressions.
This module specifically targets on different word combinations that can be separated.
The word combinations include B<"noun+postpositions">, B<"...+clitics">, 
B<"...+auxiliaries">, B<"...+negatives"> etc. The regular expressions process I<UTF-8>
data directly instead of I<transliterated> text.  

The tokenization adheres to the following guidelines:

=over 4

=item * All functional words (postpositions and clitics) should be separated.

=item * All auxiliaries must be separated. 

=item * When it comes to clitics, try separating only: (தான் - 'TAn' and உம் - 'um'). Caution should be exercised when 
separating one letter clitics automatically.

=back 

See(L<Treex::Block::W2W::TA::CollapseAgglutination>)

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
