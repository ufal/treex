package Treex::Block::A2A::FillCoNLLAttributes;

use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

# default tagset: PDT
has 'tag_features' => (
	traits => ['Hash'],
	is		=> 'ro',
	isa	=> 'HashRef[Str]',
	default => sub {{
    #"1"	=>	"POS",
    #"2"	=>	"SubPOS",
    "3"	=>	"Gen",
    "4"	=>	"Num",
    "5"	=>	"Cas",
    "6"	=>	"PGe",
    "7"	=>	"PNu",
    "8"	=>	"Per",
    "9"	=>	"Ten",
    "10"	=>	"Gra",
    "11"	=>	"Neg",
    "12"	=>	"Voi",
    #"13"	=>	"Unused",
    #"14"	=>	"Unused",
    "15"	=>	"Var"
	}},
	handles => {
		get_fpositions => 'keys',
		get_fname => 'get',	
		clear_map => 'clear',
		has_no_mapping => 'is_empty',
		has_fposition => 'exists'	
	},	
);

has 'use_index_for_feat_name' => (
	is => 'ro',
	isa => 'Str',
	default => 0,
);

sub BUILD {
	my ($self) = @_;
	$self->clear_map() if $self->use_index_for_feat_name;
}

sub process_atree {
    my $self = shift;
    my $tree = shift;
    my @nodes = $tree->get_descendants({'ordered' => 1});
	# CPOSTAG    
    map{$_->set_conll_cpos((substr $_->tag, 0, 1));}@nodes;
	# POSTAG
    map{$_->set_conll_pos((substr $_->tag, 0, 2));}@nodes;
	# FEATS    
    foreach my $n (@nodes) {
		my $feats = '_';
		my @f;
		foreach my $i (2..(length($n->tag)-1)) {
			my $fval = substr $n->tag, $i, 1;
			if ($fval ne '-') {
				my $fname = $i+1; 
				$fname = $self->get_fname($i+1) if ($self->has_fposition($i+1));
				push @f, $fname . "=" . $fval;				
			}
		}
		$feats = join("|", @f) if scalar @f > 0;
		$n->set_conll_feat($feats);
    }
    # DEPREL
	map{my $deprel = '-'; $deprel = $_->afun if ($_->afun);$_->set_conll_deprel($deprel);}@nodes;	
}

1;

__END__

=head1 NAME

Treex::Block:::A2A::FillCoNLLAttributes - Fills CoNLL features in a-nodes based on morphological tag and afun values.  


=head1 DESCRIPTION

This block fills the CoNLL features of a-tree nodes given that the morphological (positional) 
tags and afun values are available for each a-node in the a-tree.


=head1 PARAMETERS

=over 4

=item C<use_index_for_feat_name>

If this value is 1, then the index positions of the positional tag will be used as feature names instead of searching for the feature 
names in the hash reference (C<tag_features>). The default value is 0.

=item C<tag_features>

Hash reference of tag positions and the corresponding position names according to the tagset. The default tagset is PDT.

=back


=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE 

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
