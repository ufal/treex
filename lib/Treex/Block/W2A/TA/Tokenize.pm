package Treex::Block::W2A::TA::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Orthography::TA;

extends 'Treex::Block::W2A::Tokenize';


override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;
    $sentence = super();
    
    # do not separate periods if they are initials as in "ரூ. " and  "ஐ.பி.எல்."  [English eq:  "Rs.", "I.P.L."]
    $sentence =~ s/(^\s*|\s+)($TA_VOWELS_REG)\s+\./$1$2./g;
    $sentence =~ s/(^\s*|\s+)($TA_CONSONANTS_REG)\s+\./$1$2./g;
    $sentence =~ s/(^\s*|\s+)($TA_CONSONANTS_PLUS_VOWEL_A_REG)\s+\./$1$2./g;
    $sentence =~ s/(^\s*|\s+)($TA_CONSONANTS_PLUS_VOWEL_A_REG)($TA_VOWEL_SIGNS_REG)\s+\./$1$2$3./g;
    
    # period should not be separated from 2 letter initials for ex: "எல், ஆர், எஸ், எம் "
    # English: sometimes "R." is written as "AR.", similary "S." as "ES."
    # rule for:  "எஸ், எல், எம், என், ஆர்"
    $sentence =~ s/(^\s*|\s+)(எஸ்|எல்|எம்|என்|ஆர்)\s+\./$1$2./g;


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


=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
