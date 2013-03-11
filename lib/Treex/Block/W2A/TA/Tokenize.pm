package Treex::Block::W2A::TA::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';

my $verb_rules_file = require_file_from_share("data/models/simple_tokenizer/ta/verb_rules.txt");
my $noun_rules_file = require_file_from_share("data/models/simple_tokenizer/ta/noun_rules.txt");
my $compound_words_file = require_file_from_share("data/models/simple_tokenizer/ta/compound_words.txt");
my $exceptions_file = require_file_from_share("data/models/simple_tokenizer/ta/exceptions.txt");
my $separate_words_file = require_file_from_share("data/models/simple_tokenizer/ta/words_to_separate.txt");

# load verb suffixes
log_info 'Loading Tamil verb rules...';
my %verb_rules = load_rules($verb_rules_file);

# load noun suffixes
log_info 'Loading Tamil noun rules...';
my %noun_rules = load_rules($noun_rules_file);

# load compound words
log_info 'Loading Tamil compound words...';
my %compound_rules = load_rules($compound_words_file);

# load exceptions
log_info 'Loading Tamil exceptions...';
my %exceptional_rules = load_rules($exceptions_file);

# load separate words (no context)
log_info 'Loading Tamil separate words...';
my %separate_words_rules = load_separate_words($separate_words_file);


sub load_rules {
	my $f = shift;
    my %rules_hash;
    open( my $RHANDLE, '<:encoding(UTF-8)', $f );
    my @data = <$RHANDLE>;
    close $RHANDLE;	
    foreach my $line (@data) {
        chomp $line;
        $line =~ s/(^\s+|\s+$)//;
        next if ( $line =~ /^$/ );
        next if ( $line =~ /^#/ );
        my @suff_split = split /\t+:\t+/, $line;
        next if ( scalar(@suff_split) != 2 );
        $suff_split[0] =~ s/(^\s+|\s+$)//;
        $suff_split[1] =~ s/(^\s+|\s+$)//;
        $rules_hash{ $suff_split[0] } = $suff_split[1];
    }
    return %rules_hash;
}

sub load_separate_words {
	my $f = shift;
	my %words;
    open( my $RHANDLE, '<:encoding(UTF-8)', $f );
    my @data = <$RHANDLE>;
    close $RHANDLE;		
    foreach my $line (@data) {
        chomp $line;
        $line =~ s/(^\s+|\s+$)//;
        next if ( $line =~ /^$/ );
        next if ( $line =~ /^#/ );
        $words{$line}++;
    }    
    return %words;
}

sub print_rules {
	my $ref_hash = shift;
	my %rules_hash = %{$ref_hash};
	map{print $_ . "\t:\t" . $rules_hash{$_} . "\n";}keys %rules_hash;
}

override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;
    $sentence = super();
    $sentence =~ s/^(.*)$/ $1 /;

	# separate "TAn"
	# "um", "TAn" including single letter clitics "E" and "O"
#	my $clitics = qr{\N{U+0BC1}ம்|தான்};
	my $clitics = qr{தான்};
	$sentence =~ s/(\S+)($clitics)\s+/$1 $2 /g;

	# apply verb rules
	foreach my $vs (keys %verb_rules) {
		my $val = $verb_rules{$vs};
		$sentence =~ s/$vs\s+/$val /g;
	}
	
	# apply noun rules
	foreach my $vs (keys %noun_rules) {
		my $val = $noun_rules{$vs};
		$sentence =~ s/$vs\s+/$val /g;
	}	
	
	# apply compound rules
	foreach my $vs (keys %compound_rules) {
		my $val = $compound_rules{$vs};
		$sentence =~ s/$vs\s+/$val /g;
	}

	# apply exceptions
	foreach my $vs (keys %exceptional_rules) {
		my $val = $exceptional_rules{$vs};
		$sentence =~ s/$vs\s+/$val /g;
	}		

	# separate "postpositions" from "nouns"
#	my $postpositions = qr{குறுக்கில்|குறுக்காக|தவிர்த்து|மத்தியில்|அல்லாமல்|\N{U+0BBF}ல்லாமல்|
#குறித்து|குறுக்கே|பார்த்து|முன்னால்|அருகில்|அல்லாது|\N{U+0BBF}டையில்|
#\N{U+0BC6}திரில்|குறித்த|சுற்றிய|தாண்டிய|நடுவில்|பின்னர்|முன்னர்|
#அல்லாத|\N{U+0BBF}ல்லாத|\N{U+0BC6}திரான|கொண்டு|சுற்றி|தாண்டி|
#நோக்கி|பதிலாக|பற்றிய|பிந்தி|மீதும்|முந்தி|முன்பு|முன்பே|மூலமாக|
#வழியாக|விட்டு|வெளியே|வைத்து|அன்று|அருகே|\N{U+0BBF}டையே|
#\N{U+0BBF}ன்றி|\N{U+0BC1}ட்பட|\N{U+0BC6}திரே|\N{U+0BCA}ட்டி|கொண்ட|
#நடுவே|பற்றி|பிறகு|மீதான|மூலம்|கீழே|கீழ்|தவிர|பின்|போல்|மீது|
#முன்|மேலே|மேல்|\N{U+0BCA}ழிய|\N{U+0BC1}ள்|படி|போல|வரை|விட
#	};
		
#	$sentence =~ s/(\S+)($postpositions)\s+/$1 $2 /g;	

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


=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
