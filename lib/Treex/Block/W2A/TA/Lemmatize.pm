package Treex::Block::W2A::TA::Lemmatize;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

my $data_dir = "data/models/simple_lemmatizer/ta/";

my $noun_rules_file =  require_file_from_share("$data_dir/noun_suffixes.dat");
my %noun_rules;

my $verb_rules_file =  require_file_from_share("$data_dir/verb_suffixes.dat");
my %verb_rules;

# load noun rules
log_info 'Loading Tamil noun morphotactics';
%noun_rules = load_rules($noun_rules_file);
my @nrules = @{ $noun_rules{'r'} };
my @nvals  = @{ $noun_rules{'v'} };

# load noun rules
log_info 'Loading Tamil verb morphotactics';
%verb_rules = load_rules($verb_rules_file);
my @vrules = @{ $verb_rules{'r'} };
my @vvals  = @{ $verb_rules{'v'} };

my $PUNC = qr/;|!|<|>|\{|\}|\[|\]|\(|\)|\?|\#|\$|£|\%|\&|``|\'\'|‘‘|"|“|”|«|»|--|–|—|„|\,|‘|\*|\^|\||\`|\.|\:|\'/;

sub process_atree {
    my ( $self, $atree ) = @_;
    my @nodes = $atree->get_descendants({ordered=>1});
    foreach my $node (@nodes) {
    	# do not lemmatize if the form contains
    	# 1. punctuations
    	# 2. digits
		if ($node->form !~ /(\d|$PUNC)/) {
	    	$self->find_lemma($node);			
		}
    	$node->set_attr('lemma', $node->form) if (!defined $node->lemma); 
    }    
    return;
}

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

sub find_lemma {
	my ($self, $node) = @_;	
	my $lemma_found = 0;
	
	# apply verb morphotactics
	foreach my $i ( 0 .. $#vrules ) {
		my $r = $vrules[$i];
		my $v = $vvals[$i];
		if ($node->form =~ /$r$/) {
			my $tmpform = $node->form;
			$tmpform =~ s/$r$/"$v"/ee;
			$node->set_attr('lemma', $tmpform);
			$lemma_found = 1;
			last;				
		}
	}
	
	# apply noun morphotactics
	if (!$lemma_found) {
		foreach my $i ( 0 .. $#nrules ) {
			my $r = $nrules[$i];
			my $v = $nvals[$i];
			if ($node->form =~ /$r$/) {
				my $tmpform = $node->form;
				$tmpform =~ s/$r$/"$v"/ee;
				$node->set_attr('lemma', $tmpform);
				$lemma_found = 1;
				last;				
			}
		}
	}
	
	# postprocessing
	
	# 1. if there are 2 consonants in a row, change 
	# the last one into a vowel (உ/u)
	
		
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TA::Lemmatizer - Tamil Lemmatizer
