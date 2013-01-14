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
	# "um", "TAn"
	my $clitics = qr{\N{U+0BC1}ம்|தான்};
	

	# separate "postpositions" from "nouns"
	my $postpositions = qr{\N{U+0BBF}டமிருந்து|தொடர்பாக|தொடர்பான|
		\N{U+0BBF}லிருந்து|மத்தியில்|மூலமாக|தொடர்ந்து|\N{U+0BC1}ள்ளாகவே|
		வழியாக|\N{U+0BC6}திரான|\N{U+0BBF}ல்லாமல்|\N{U+0BBF}டையில்|குறித்த|குறித்து|முறையே|பற்றிய|அல்லாத|அல்லாது|
		அருகில்|சார்பில்|சார்ந்த|சேர்த்து|சேர்ந்த|\N{U+0BC6}திரில்|
		\N{U+0BBF}ல்லாத|\N{U+0BBF}ருந்த|\N{U+0BBF}ருந்து|\N{U+0BBF}டையே|
		மேலான|மீதான|முன்னால்|பின்னர்|பிறகு|தவிர|\N{U+0BC1}ட்பட|அருகே|கொண்ட|
		மீதும்|மூலம்|முன்பு|முன்பே|முதல்|பற்றி|போன்ற|வரை|அன்று|அற்ற|
		\N{U+0BBF}ன்றி|\N{U+0BBF}டம்|கீழே|மேலே|மீது|\N{U+0BCA}ட்டி|படி|
		கூட|போல|போது|\N{U+0BC1}ள்ள|\N{U+0BC1}டன்|விட|கீழ்|மேல்|\N{U+0BCB}டு
	};
	
	$sentence =~ s/(\S+)($clitics)\s+/$1 $2 /g;
	$sentence =~ s/(\S+)($postpositions)\s+/$1 $2 /g;

    return $sentence;
};

1;