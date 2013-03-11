package Treex::Block::W2A::TA::Tokenize;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Block::W2A::Tokenize';

my $exceptions_file = require_file_from_share("data/models/simple_tokenizer/ta/exceptions.txt");
my $separate_words_file = require_file_from_share("data/models/simple_tokenizer/ta/words_to_separate.txt");

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

override 'tokenize_sentence' => sub {
    my ( $self, $sentence ) = @_;
    $sentence = super();
    $sentence =~ s/^(.*)$/ $1 /;

	# separate "TAn" - தான்
	$sentence =~ s/(\S+)(தான்)\s+/$1 தான் /g;

	# apply separate words 
	foreach my $vs (keys %separate_words_rules) {
		$sentence =~ s/$vs\s+/ $vs /g;
	}
	
	# apply exceptions
	foreach my $vs (keys %exceptional_rules) {
		my $val = $exceptional_rules{$vs};
		$sentence =~ s/$vs\s+/$val /g;
	}		
	
	# separates "um/உம்" from the wordforms
	$sentence = $self->separate_um($sentence);
	
	$sentence =~ s/(^\s+|\s+$)//;
	
    return $sentence;    
};


sub separate_um {
    my ( $self, $sentence ) = @_;
	
	# separate all "um"s in the sentence
	$sentence =~ s/\N{U+0BC1}ம்/ \N{U+0BC1}ம்/g;	    
    	
	# avoid separating "um" at the finite verbs
	# (a) don't separate "um/உம்" at the end of the sentence boundary
	$sentence =~ s/\s+\N{U+0BC1}ம்\s+\./\N{U+0BC1}ம் /g; 
	
	# (b) avoid "um" at the auxiliary finite verb
	$sentence =~ s/(பட|வர)\s+\N{U+0BC1}ம்\s+\./$1\N{U+0BC1}ம் /g;
	
	# (c) other places
	$sentence =~ s/(மற்ற)\s+\N{U+0BC1}ம்\s+\./$1\N{U+0BC1}ம் /g;
	
	return $sentence;		
}

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
