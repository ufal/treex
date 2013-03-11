package Treex::Block::W2W::TA::CollapseAgglutination;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $verb_rules_file = require_file_from_share("data/models/simple_tokenizer/ta/verb_rules.txt");
my $noun_rules_file = require_file_from_share("data/models/simple_tokenizer/ta/noun_rules.txt");
my $postpositions_rule_file = require_file_from_share("data/models/simple_tokenizer/ta/postpositional_rules.txt");
my $compound_words_file = require_file_from_share("data/models/simple_tokenizer/ta/compound_words.txt");

# load verb suffixes
log_info 'Loading Tamil verb rules...';
my %verb_rules = load_rules($verb_rules_file);

# load noun suffixes
log_info 'Loading Tamil noun rules...';
my %noun_rules = load_rules($noun_rules_file);

# load postpositional rules
log_info 'Loading Tamil postpositions...';
my %pp_rules = load_rules($postpositions_rule_file);

# load compound words
log_info 'Loading Tamil compound words...';
my %compound_rules = load_rules($compound_words_file);


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

sub process_zone {
    my ( $self, $zone ) = @_;
    my $sentence = $zone->sentence;
	$sentence =~ s/(^\s+|\s+$)//;
    log_fatal("No sentence found") if !defined $sentence;
    my $outsentence = $self->reduce_agglutination($sentence);
    $zone->set_sentence($outsentence);
    return 1;
}

sub reduce_agglutination {
    my ( $self, $sentence ) = @_;

	# separate "comma" and the "period" at the end of the sentence
	$sentence =~ s/(\,|\.$)/$1 /g;

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
	
	# apply postpositional rules
	foreach my $vs (keys %pp_rules) {
		my $val = $pp_rules{$vs};
		$sentence =~ s/$vs\s+/$val /g;
	}    
	
	# apply compound rules
	foreach my $vs (keys %compound_rules) {
		my $val = $compound_rules{$vs};
		$sentence =~ s/$vs\s+/$val /g;
	}	
	return $sentence;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::TA::CollapseAgglutination - Reduces Morphological Complexity

=head1 DESCRIPTION

This module is aimed at rewriting some of the complex Tamil wordforms into series of separate words so that the Tamil text becomes less complex
for various NLP tasks. At present, the following transformations are applied to Tamil wordforms.

=over 4

=item * [VERB+AUX1+AUX2+...] becomes [VERB]+[AUX1]+[AUX2]...

=item * [NOUN+POSTPOSITION] becomes [NOUN]+[POSTPOSITION] 

=item * [NOUN+FUNCTIONAL WORD] becomes [NOUN]+[FUNCTIONAL WORD]

=back

This block makes changes to wordforms (if necessary) as opposed to tokenization where there will be no change to wordforms. 
This block is applied before tokenization.
See (L<Treex::Block::W2A::TA::Tokenize>)
    
  
=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
  
