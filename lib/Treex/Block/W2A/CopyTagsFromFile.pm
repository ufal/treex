package Treex::Block::W2A::CopyTagsFromFile;
use Moose;
use Treex::Core::Common;

extends 'Treex::Core::Block';

has 'tag_file' 	=> ( isa => 'Str', is => 'ro', default => 'data/models/simple_tagger/ta/tagged_data/data.pos' );
has 'selector' 		=> ( isa => 'Str', is => 'ro', default => '' );
has 'tag_file_abspath' => (isa => 'Str', is => 'ro', predicate => 'has_tag_file_abspath');

my %posdata = ();


sub BUILD {
	my ($self) = @_;
	my $pos_file;
	if ($self->has_tag_file_abspath) {
		$pos_file = $self->tag_file_abspath;
	}
	else {
		$pos_file = require_file_from_share( $self->tag_file );
	}
	my @pos_tokens = ();
	my @forms = ();
	my $curr_line_num = 1;
	open(RH, "<:encoding(utf8)", $pos_file);
	while (<RH>) {
    	chomp;
    	s/(^\s+|\s+$)//;
    	my $line = $_;
		if ($line =~ /^$/) {
	    	if (scalar(@pos_tokens) > 0) {
				my $sentence = join(" ", @forms);
				my @tmp = @pos_tokens;
				$posdata{$sentence} = \@tmp;
				@forms = ();
				@pos_tokens = ();
	    	}
			$curr_line_num++;	    	
		}
		else {
	    	my @toks = split(/\t+/, $line);
	    	if (scalar(@toks) == 3 ) {
	    		push @forms, $toks[0];
				push @pos_tokens, $toks[1];
				$curr_line_num++;
	    	}
	    	else {
				die "Error: at line $curr_line_num in the POS file \n";	    
		    }
		}
	}
	close RH;	
}

sub process_atree {
	my ($self, $root) = @_;
	my @nodes = $root->get_descendants( { ordered => 1 } );
	my @forms = map{$_->form}@nodes;
	my $sentence = join(" ", @forms);
	if (exists $posdata{$sentence}) {
		my @gold_pos = @{$posdata{$sentence}};
		if (scalar(@gold_pos) == scalar(@nodes)) {
			map{$nodes[$_]->set_attr('tag',  $gold_pos[$_])}0..$#nodes;
		}
	}
}

1;

__END__


=encoding utf-8

=head1 NAME

Treex::Block::W2A::CopyTagsFromFile - Copies POS data from external file to nodes in a-trees

=head1 SYNOPSIS

Treex::Block::W2A::CopyTagsFromFile language=ta 

=head1 DESCRIPTION

The block simply copies the POS data from external file. The POS assignment occurs at the sentence level i.e. POS sequence 
is assigned to a sentence in an a-tree only when the sentence belonging to the a-tree is found in the external file. The corresponding 
POS sequence from the file is assigned to the a-tree. This block may be useful when the gold tagged data is available outside of the 
treex framework and we want to assign the gold POS data to a-trees in the treex file.   

The tagged data file should have for each line FORM, TAG and LEMMA separated by a tab. The empty lines in the tagged data are treated 
as sentence boundaries.
 
=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.