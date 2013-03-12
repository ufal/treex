package Treex::Block::A2A::TA::NounVerbTagger;
use utf8;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

my $verb_suffixes_file = require_file_from_share("data/models/simple_tagger/ta/dict/verb_suffixes_trimmed.txt");
my $noun_suffixes_file = require_file_from_share("data/models/simple_tagger/ta/dict/noun_suffixes_trimmed.txt");
my $pp_file = require_file_from_share("data/models/simple_tagger/ta/dict/postpositions.txt");
my $adj_file = require_file_from_share("data/models/simple_tagger/ta/dict/adjectives.txt");
my $adv_file = require_file_from_share("data/models/simple_tagger/ta/dict/adverbs.txt");
my $quantifiers_file = require_file_from_share("data/models/simple_tagger/ta/dict/quantifiers.txt");


my @noun_suffixes = load_suffixes($noun_suffixes_file);
my @verb_suffixes = load_suffixes($verb_suffixes_file);
my %postpositions = load_list($pp_file);
my %adjectives = load_list($adj_file);
my %adverbs = load_list($adv_file);
my %quantifiers = load_list($quantifiers_file);

sub load_list {
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

sub load_suffixes {
	my $f = shift;
	my @suffixes;
    open( my $RHANDLE, '<:encoding(UTF-8)', $f );
    my @data = <$RHANDLE>;
    close $RHANDLE;		
    foreach my $line (@data) {
        chomp $line;
        $line =~ s/(^\s+|\s+$)//;
        next if ( $line =~ /^$/ );
        next if ( $line =~ /^#/ );
        push @suffixes, $line;
    }    
    return @suffixes;
}

sub process_atree {
    my ( $self, $root ) = @_;
    my @nodes =  $root->get_descendants( { ordered => 1 } );
    
    foreach my $node (@nodes) {
    	if (defined $node->form) {
    		my $f = $node->form;
    		$f =~ s/(^\s+|\s+$)//;
    		my $tagged = 0;

    		# start from list with less items
    		# Determiner (DT)
    		if (!$tagged) {
    			if ($f =~ /^(அ|இ|எ)ந்த(க்|ச்|த்|ப்)?$/) {
    				$node->set_attr('tag', 'DT');
    				$tagged = 1;
    			}
    		}
    		
    		# Conjunctions (CC) 
    		if (!$tagged) {
    			if ($f =~ /^(அல்லது|மற்றும்)$/) {
    				$node->set_attr('tag', 'CC');
    				$tagged = 1;    				
    			}
    		}
    		
    		# Punctuations (PUNC)
    		if (!$tagged) {
    			if ($f =~ /^(;|!|<|>|\{|\}|\[|\]|\(|\)|\?|\#|\$|£|\%|\&|``|\'\'|‘‘|"|“|”|«|»|--|–|—|„|‚|‘|\*|\^|\||\`|\.|\:|\')$/) {
    				$node->set_attr('tag', 'PUNC');
    				$tagged = 1;     				
    			}	
    		}
    		
    		# Postpositions (PP) 
    		if (!$tagged) {
				if (exists $postpositions{$f}) {
					$node->set_attr('tag', 'PP');
					$tagged = 1;
				}     			
    		}
    		
			# Adjectives (JJ)
			if (!$tagged) {
				if (exists $adjectives{$f}) {
					$node->set_attr('tag', 'JJ');
					$tagged = 1;
				} 
				else {
					# test if the form ends with derived 
					# adjectival suffix "Ana" - ான
					if ($f =~ /ான$/) { 
						$node->set_attr('tag', 'JJ');
						$tagged = 1;						
					}
				}
			}
			
			# Adverbs (RB)
			if (!$tagged) {
				if (exists $adverbs{$f}) {
					$node->set_attr('tag', 'RB');
					$tagged = 1;
				} 
				else {
					# test if the form ends with derived 
					# adverbial suffix "Aka" - ாக 
					if ($f =~ /ாக$/) { 
						$node->set_attr('tag', 'RB');
						$tagged = 1;						
					}
				}
			}
			
			# Quantifiers (Q)   			   
    		if (!$tagged) {
				if (exists $quantifiers{$f}) {
					$node->set_attr('tag', 'QQ');
					$tagged = 1;
				}     			
    		}
    					 		
    		# Verbs (V)
			if (!$tagged) {
    			foreach my $vs (@verb_suffixes) {
					if ($f =~ /$vs$/) {
						$node->set_attr('tag', 'V'); 
						$tagged = 1;
						last; 
					}				
    			}				
			} 
			
			# Nouns (N)
			if (!$tagged) {
    			foreach my $ns (@noun_suffixes) {
					if ($f =~ /$ns$/) {
						$node->set_attr('tag', 'N'); 
						$tagged = 1;
						last; 
					}				
    			}				
			} 
			   		
			# Default tag : N
			$node->set_attr('tag', 'N') if !$tagged;						   		
    	} 
    } 
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::TA::NounVerbTagger - Basic POS tagger using Tamil word list/endings

=head1 DESCRIPTION

This block tags the Tamil sentences based on word list/endings. The POS tagset is based on major POS categories available for Tamil. 
The tagset contains the following POS categories,

=over 4

=item * Verbs (V)

=item * Nouns (N)

=item * Postpositions (PP)

=item * Adjectives (JJ)

=item * Adverbs (RB)

=item * Quantifiers (QQ)

=item * Conjunctions (CC)

=item * Determiners (DT)

=item * Punctuations (PUNC)

=back

Tokenization (See L<Treex::Block::W2A::TA::Tokenize>) should be performed before tagging. 

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
