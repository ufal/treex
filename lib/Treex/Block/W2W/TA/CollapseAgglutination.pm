package Treex::Block::W2W::TA::CollapseAgglutination;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $data_dir = "data/models/normalization/ta/agglutination";

# auxiliary verbs
my $aux_rules_file   = require_file_from_share("$data_dir/aux_rules_short.dat");
my %aux_rules;

# postpositions
my $pp_rules_file = require_file_from_share("$data_dir/pp_rules.dat");
my %pp_rules;

# compound words
my $compound_words_file = require_file_from_share("$data_dir/compound_words.dat");
my %compound_rules;

# exceptions
my $exceptions_file = require_file_from_share("$data_dir/exceptions.dat"); 
my %exception_rules;

# load auxiliary verb rules
log_info 'Loading Tamil aux verb rules...';
%aux_rules = load_rules($aux_rules_file);

# load postpositional rules
log_info 'Loading Tamil postpositional rules...';
%pp_rules =  load_rules($pp_rules_file);

# load compound words
log_info 'Loading compound words...';
%compound_rules = load_rules($compound_words_file);

# load compound words
log_info 'Loading exceptions';
%exception_rules = load_rules($exceptions_file);

sub load_rules {
	my ( $f, $type ) = @_;
	my %variables;
	my %rules_ordered;
	my @rules_array;
	my @vals_array;
	open( my $RHANDLE, '<:encoding(UTF-8)', $f );
	my @data = <$RHANDLE>;
	close $RHANDLE;

	foreach my $line (@data) {
		chomp $line;
		$line =~ s/(^\s+|\s+$)//;
		next if ( $line =~ /^$/ );
		next if ( $line =~ /^#/ );

		# 1. variables
		if ( $line =~ /=/ ) {
			my @var_val = split( /\s*=\s*/, $line );
			$variables{ $var_val[0] } = $var_val[1];
		}

		# 2. rules
		elsif ( $line =~ /:/ ) {
			my @suff_split = split( /\t+:\t+/, $line );
			next if ( scalar(@suff_split) != 2 );
			$suff_split[0] =~ s/(^\s+|\s+$)//;
			$suff_split[1] =~ s/(^\s+|\s+$)//;
			push @rules_array, $suff_split[0];
			push @vals_array,  $suff_split[1];
		}
	}

	# replace variables found in the rules with variable values
	my %rules_to_replace;
	my @rules;
	foreach my $ri ( 0 .. $#rules_array ) {
		my $new_rule = $rules_array[$ri];
		foreach my $v ( keys %variables ) {
			my $val = $variables{$v};
			$new_rule =~ s/[\%]$v/$val/g;
		}
		$rules_array[$ri] = $new_rule;
	}
	$rules_ordered{'r'} = \@rules_array;
	$rules_ordered{'v'} = \@vals_array;
	return %rules_ordered;
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
	
	chomp $sentence;
	
	# add space at both sides of the sentence
	$sentence = ' ' . $sentence . ' ';

	# separate "comma" and the "period"
	$sentence =~ s/([^\d])(\,|\.)\s+/$1 $2 /g;
	$sentence =~ s/\.$/ ./;
	
	# apply auxiliary verb rules
	my @arules = @{ $aux_rules{'r'} };
	my @avals  = @{ $aux_rules{'v'} };
	foreach my $i ( 0 .. $#arules ) {
		my $r = $arules[$i];
		my $v = $avals[$i];
		$sentence =~ s/$r/"$v"/gee;
	}
	
	# separate postpositions
	my @prules = @{ $pp_rules{'r'} };
	my @pvals  = @{ $pp_rules{'v'} };
	foreach my $i ( 0 .. $#prules ) {
		my $r = $prules[$i];
		my $v = $pvals[$i];
		$sentence =~ s/$r\s+/"$v"/gee;
	}
	
	# separate compound words
	my @crules = @{ $compound_rules{'r'} };
	my @cvals  = @{ $compound_rules{'v'} };
	foreach my $i ( 0 .. $#crules ) {
		my $r = $crules[$i];
		my $v = $cvals[$i];
		$sentence =~ s/$r\s+/"$v"/eeg;
	}
		
	# exceptions to the separation
	my @exrules = @{ $exception_rules{'r'} };
	my @exvals  = @{ $exception_rules{'v'} };
	foreach my $i ( 0 .. $#exrules ) {
		my $r = $exrules[$i];
		my $v = $exvals[$i];
		$sentence =~ s/$r\s+/$v /g;
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
  
