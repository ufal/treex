package Treex::Block::W2A::TA::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';

override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;
    $sentence = super();
    $sentence =~ s/^(.*)$/ $1 /;

	# separate "clitics"
	# "um", "TAn" including single letter clitics "E" and "O"
	my $clitics = qr{\N{U+0BC1}ம்|தான்};
	$sentence =~ s/(\S+)($clitics)\s+/$1 $2 /g;
		
	# separate auxiliary words
	# "uLLA"
	my $ulla = qr/\N{U+0BC1}(ள்ளார்கள்|ள்ளான்|ள்ளாள்|ள்ளார்|ள்ளது|ள்ளன|ள்ள)/;
	$sentence =~ s/(\S+)($ulla)/$1 $2/g; 

	# separate "enRu"
	my $enru = qr{\N{U+0BC6}(ன்றார்கள்|ன்றீர்கள்|ன்றால்|ன்றேன்|ன்றாய்|
		ன்றீர்|ன்றான்|ன்றாள்|ன்றது|ன்றன|ன்று|ன்ற)};
	$sentence =~ s/(\S+)($enru)/$1 $2/g;
	
	# separate "koL - koLLum, koNta etc"
	
	# separate "patu"
	

	# negative word "illai"
	$sentence =~ s/(\S+)(\N{U+0BBF}ல்லை)/$1 $2/g;

	# separate "postpositions" from "nouns"
	my $postpositions = qr{குறுக்கில்|குறுக்காக|தவிர்த்து|மத்தியில்|அல்லாமல்|\N{U+0BBF}ல்லாமல்|
குறித்து|குறுக்கே|பார்த்து|முன்னால்|அருகில்|அல்லாது|\N{U+0BBF}டையில்|
\N{U+0BC6}திரில்|குறித்த|சுற்றிய|தாண்டிய|நடுவில்|பின்னர்|முன்னர்|
அல்லாத|\N{U+0BBF}ல்லாத|\N{U+0BC6}திரான|கொண்டு|சுற்றி|தாண்டி|
நோக்கி|பதிலாக|பற்றிய|பிந்தி|மீதும்|முந்தி|முன்பு|முன்பே|மூலமாக|
வழியாக|விட்டு|வெளியே|வைத்து|அன்று|அருகே|\N{U+0BBF}டையே|
\N{U+0BBF}ன்றி|\N{U+0BC1}ட்பட|\N{U+0BC6}திரே|\N{U+0BCA}ட்டி|கொண்ட|
நடுவே|பற்றி|பிறகு|மீதான|மூலம்|கீழே|கீழ்|தவிர|பின்|போல்|மீது|
முன்|மேலே|மேல்|\N{U+0BCA}ழிய|\N{U+0BC1}ள்|படி|போல|வரை|விட
	};	
	$sentence =~ s/(\S+)($postpositions)\s+/$1 $2 /g;	

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

=item * Separate ஆக - 'Aka' and ஆன - 'Ana' when they occur as a separate functional words. Do not separate 
when they occur as suffixes in adjectives (kind of 'ful' in 'wonderful') and adverbs (kind of 'ly' in 'quickly').
  

=back 


=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
