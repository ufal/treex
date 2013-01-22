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
	my $postpositions = qr{\N{U+0BBF}டமிருந்து|தொடர்பாக|தொடர்பான|
		\N{U+0BBF}லிருந்து|மத்தியில்|மூலமாக|தொடர்ந்து|\N{U+0BC1}ள்ளாகவே|
		வழியாக|\N{U+0BC6}திரான|\N{U+0BBF}ல்லாமல்|\N{U+0BBF}டையில்|குறித்த|
		குறித்து|முறையே|பற்றிய|அல்லாத|அல்லாது|
		அருகில்|சார்பில்|சார்ந்த|சேர்த்து|சேர்ந்த|\N{U+0BC6}திரில்|
		\N{U+0BBF}ல்லாத|\N{U+0BBF}ருந்த|\N{U+0BBF}ருந்து|\N{U+0BBF}டையே|
		மேலான|மீதான|முன்னால்|பின்னர்|பிறகு|தவிர|\N{U+0BC1}ட்பட|அருகே|கொண்ட|
		மீதும்|மூலம்|முன்பு|முன்பே|முதல்|பற்றி|போன்ற|வரை|அன்று|அற்ற|
		\N{U+0BBF}ன்றி|\N{U+0BBF}டம்|கீழே|மேலே|மீது|\N{U+0BCA}ட்டி|படி|
		கூட|போல|போது|\N{U+0BC1}ள்ள|\N{U+0BC1}டன்|விட|கீழ்|மேல்|\N{U+0BCB}டு
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
