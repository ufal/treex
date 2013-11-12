package Treex::Block::Align::A::InsertBerkeleyAlignment;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'from_language' => ( isa => 'Str', is => 'ro', required => 1 );
has 'from_selector' => ( isa => 'Str', is => 'ro', default  => '' );
has 'to_language' => ( isa => 'Str', is => 'ro', required => 1 );
has 'to_selector' => ( isa => 'Str', is => 'ro', default  => '' );

has 'alignment_file' => ( isa => 'Str', 
  is => 'ro', 
  trigger => \&load_alignment_data, 
  required => 1 );
  
has 'alignment_data' => (
	traits  => ['Array'],
	is      => 'rw',
	isa     => 'ArrayRef',
	default => sub { [] },
	handles => {
		add_alignment        => 'push',
		num_sentences        => 'count',
		get_line_alignment   => 'get',
		set_line_alignment   => 'set',
		empty_alignment_data => 'clear',
	}
);

has 'alignment_type' => ( isa => 'Str', is => 'ro', default  => 'berkeley' ); 

my $FILE;

sub load_alignment_data {
	my ($self) = @_;
	open($FILE, "<:encoding(utf8)", $self->alignment_file);
	while (<$FILE>) {
		my $line = $_;
		chomp $line;
		$line =~ s/(^\s+|\s+$)//;
		$self->add_alignment($line);
	}	
	close $FILE;	
}

sub process_document {
	my ($self, $document) = @_;
	my @bundles = $document->get_bundles();
	if (scalar(@bundles) != $self->num_sentences) {
		log_fatal "error: alignment file size and the document size differ";
	}		
	for ( my $i = 0 ; $i < @bundles ; ++$i ) {
		my $source_t = $bundles[$i]->get_zone( $self->from_language, $self->from_selector )->get_atree();
		my $target_t = $bundles[$i]->get_zone( $self->to_language, $self->to_selector )->get_atree();		
		my @s_nodes = $source_t->get_descendants( { ordered => 1 } );
		my @t_nodes = $target_t->get_descendants( { ordered => 1 } );
		my $alignment_line = $self->get_line_alignment($i);
		if ($alignment_line !~ /^$/) {
			my @word_a = split(/\s+/, $alignment_line);
			foreach my $w_a (@word_a) {
				my @st_ords = split(/-/, $w_a);
				$s_nodes[$st_ords[0]]->add_aligned_node($t_nodes[$st_ords[1]], $self->alignment_type);
			}			
		}
	}
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Align::A::InsertBerkeleyAlignment - Inserts Berkeley alignments from file

=head1 SYNOPSIS

Align::A::InsertBerkeleyAlignment from_language=ta to_language=en alignment_file=training.align

=head1 DESCRIPTION

The block reads alignment data from file and inserts the corresponding links in the treex document (a-tree).
The alignment data is assumed to be produced from Berkeley Aligner. 

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.