package Treex::Block::W2W::TA::CollapseAgglutination;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $aux_verb_rules_file = require_file_from_share("data/models/simple_tokenizer/ta/auxiliary_rules.txt");
my $verb_rules_file = require_file_from_share("data/models/simple_tokenizer/ta/verb_rules.txt");
my $noun_rules_file = require_file_from_share("data/models/simple_tokenizer/ta/noun_rules.txt");
my $postpositions_rule_file = require_file_from_share("data/models/simple_tokenizer/ta/postpositional_rules.txt");
my $compound_words_file = require_file_from_share("data/models/simple_tokenizer/ta/compound_words.txt");

# load auxiliary verb rules
log_info 'Loading Tamil aux verb rules...';
my %aux_verb_rules = load_rules($aux_verb_rules_file);
print_rules(\%aux_verb_rules, 'ordered');

## load verb suffixes
#log_info 'Loading Tamil verb rules...';
#my %verb_rules = load_rules($verb_rules_file);
#
## load noun suffixes
#log_info 'Loading Tamil noun rules...';
#my %noun_rules = load_rules($noun_rules_file);
#
## load postpositional rules
#log_info 'Loading Tamil postpositions...';
#my %pp_rules = load_rules($postpositions_rule_file);
#
## load compound words
#log_info 'Loading Tamil compound words...';
#my %compound_rules = load_rules($compound_words_file);


sub load_rules {
	my ($f, $type) = @_;
	my %variables;
    my %rules_unordered;
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
        if ($line =~ /=/) {
        	my @var_val = split (/\s*=\s*/, $line);
        	$variables{$var_val[0]} = $var_val[1];
        }
        # 2. rulues
        elsif ($line =~ /:/) {
	        my @suff_split = split(/\t+:\t+/, $line);
	        next if ( scalar(@suff_split) != 2 );
	        $suff_split[0] =~ s/(^\s+|\s+$)//;
	        $suff_split[1] =~ s/(^\s+|\s+$)//;
	        if ($type eq 'ordered') {
	        	push @rules_array, $suff_split[0];
	        	push @vals_array, $suff_split[1];
	        }
	        elsif ($type eq 'unordered') {
	        	$rules_unordered{ $suff_split[0] } = $suff_split[1];	        	
	        }        	
        }
    }
    # replace variables found in the rules with variable values
    my %rules_to_replace;
    my @rules;
	if ($type eq 'unordered') {
	    foreach my $r (keys %rules_unordered) {
			my $new_rule = $r;
			my $change_rule = 0;
	    	foreach my $v (keys %variables) {
	    		if ($r =~ /$v/) {
	    			my $val = $variables{$v};
					$new_rule =~ s/[\%]$v/$val/g;
					$change_rule = 1;
	    		}
	    	}
	    	if ($change_rule) {
	    		$rules_to_replace{$r} = $new_rule;    		
	    	}
	    }
	    foreach my $rc (keys %rules_to_replace) {
	    	if (exists $rules_unordered{$rc}) {
	    		my $orval = $rules_unordered{$rc};
	    		my $nr = $rules_to_replace{$rc};
	    		$rules_unordered{$nr} = $orval;
	    		delete $rules_unordered{$rc};
	    	}
	    }   		
    	return %rules_unordered;
	}
	elsif ($type eq 'ordered') {
	    foreach my $ri (0..$#rules_array) {
			my $new_rule = $rules_array[$ri];
	    	foreach my $v (keys %variables) {
	    			my $val = $variables{$v};
					$new_rule =~ s/[\%]$v/$val/g;
	    	}
	    	$rules_array[$ri] = $new_rule;
	    }
		$rules_ordered{'r'} = \@rules_array;
		$rules_ordered{'v'} = \@vals_array;
		return %rules_ordered;
	}
}

sub process_zone {
    my ( $self, $zone ) = @_;
    my $sentence = $zone->sentence;
	$sentence =~ s/(^\s+|\s+$)//;
    log_fatal("No sentence found") if !defined $sentence;
#    my $outsentence = $self->reduce_agglutination($sentence);
#    $zone->set_sentence($outsentence);
    return 1;
}

sub print_rules {
	my ($ref, $type) = @_;
	if ($type eq 'ordered') {
		my %rules = %$ref;
		map {my $r = $_; print $r . "\t:\t" . $rules{$r} . "\n";}keys %rules;		
	}
	elsif ($type eq 'unordered') {
		my @rules = @$ref;
		map {my $r = $_; print $r . "\t:\t" . $rules{$r} . "\n";}@rules;
	}

	return;
}

sub reduce_agglutination {
    my ( $self, $sentence ) = @_;

	# separate "comma" and the "period" at the end of the sentence
	$sentence =~ s/(\,|\.$)/$1 /g;
	
	# apply auxiliary verb rules
	foreach my $vs (keys %aux_verb_rules) {
		my $val = $aux_verb_rules{$vs};
		$sentence =~ s/$vs\s+/$val /g;
	}	

#	# apply verb rules
#	foreach my $vs (keys %verb_rules) {
#		my $val = $verb_rules{$vs};
#		$sentence =~ s/$vs\s+/$val /g;
#	}
#	
#	# apply noun rules
#	foreach my $vs (keys %noun_rules) {
#		my $val = $noun_rules{$vs};
#		$sentence =~ s/$vs\s+/$val /g;
#	}	
#	
#	# apply postpositional rules
#	foreach my $vs (keys %pp_rules) {
#		my $val = $pp_rules{$vs};
#		$sentence =~ s/$vs\s+/$val /g;
#	}    
#	
#	# apply compound rules
#	foreach my $vs (keys %compound_rules) {
#		my $val = $compound_rules{$vs};
#		$sentence =~ s/$vs\s+/$val /g;
#	}	
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
  
