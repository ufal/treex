package Treex::Block::W2A::TA::FixAmbiguousTags;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Orthography::TA;
extends 'Treex::Core::Block';

has 'data_dir' =>
  ( isa => 'Str', is => 'rw', default => 'data/models/simple_tagger/ta/dict' );
has 'ambiguous_tags_file' =>
  ( isa => 'Str', is => 'rw', default => 'ambiguous_tags.dat' );
has 'forms_pattern'          => ( isa => 'ArrayRef', is => 'rw', default => sub { [] } );
has 'lemmas_pattern'         => ( isa => 'ArrayRef', is => 'rw', default => sub { [] } );
has 'ambiguous_tags_pattern' => ( isa => 'ArrayRef', is => 'rw', default => sub { [] } );
has 'tags_replacement'       => ( isa => 'ArrayRef', is => 'rw', default => sub { [] } );

sub BUILD {
	my ($self) = @_;
	my $fname = require_file_from_share($self->data_dir . '/' . $self->ambiguous_tags_file);
	my %ts = load_tag_replacement_rules($fname);
	@{$self->forms_pattern} = @{$ts{'fp'}};
	@{$self->lemmas_pattern} = @{$ts{'lp'}};
	@{$self->ambiguous_tags_pattern} = @{$ts{'t1'}};	
	@{$self->tags_replacement} = @{$ts{'t2'}};	
}

sub load_tag_replacement_rules {
	my ($f) = @_;
	my %ts;
	my @f_p = ();
	my @l_p = ();
	my @at_p = ();
	my @t_r = ();		
	open(RHANDLE, '<:encoding(UTF-8)', $f );
	my @data = <RHANDLE>;
	close RHANDLE;
	foreach my $line (@data) {
		chomp $line;
		$line =~ s/(^\s+|\s+$)//;
		next if ( $line =~ /^$/ );
		next if ( $line =~ /^#/ );
		if ( $line =~ /\t/ ) {
			my @rule_split = split( /\t+/, $line );
			next if ( scalar(@rule_split) != 4 );
			$rule_split[0] =~ s/(^\s+|\s+$)//;
			$rule_split[1] =~ s/(^\s+|\s+$)//;
			$rule_split[2] =~ s/(^\s+|\s+$)//;
			$rule_split[3] =~ s/(^\s+|\s+$)//;			
			push @f_p, $rule_split[0];
			push @l_p,  $rule_split[1];
			push @at_p,  $rule_split[2];
			push @t_r,  $rule_split[3];						
		}
	}
	$ts{'fp'} = \@f_p;
	$ts{'lp'} = \@l_p;
	$ts{'t1'} = \@at_p;
	$ts{'t2'} = \@t_r;
	return %ts;
}

sub process_document {
	my ( $self, $document ) = @_;
	my @bundles = $document->get_bundles();
	for ( my $i = 0 ; $i < @bundles ; ++$i ) {
		my $atree =
		  $bundles[$i]->get_zone( $self->language, $self->selector )
		  ->get_atree();
		my @nodes = $atree->get_descendants( { ordered => 1 } );
		my @forms  = map { $_->form } @nodes;
		my @lemmas = map { $_->lemma } @nodes;
		my @tags   = map { $_->tag } @nodes;
		my @resolved_tags =
		  $self->fix_ambiguous_tags( \@forms, \@lemmas, \@tags );
		map { $nodes[$_]->set_attr( 'tag', $resolved_tags[$_] ) } 0 .. $#tags;
	}
}

sub fix_ambiguous_tags {
	my ( $self, $forms_ref, $lemmas_ref, $tags_ref ) = @_;
	my @f          = @{$forms_ref};
	my @l          = @{$lemmas_ref};
	my @t          = @{$tags_ref};
	my @fixed_tags = @{$tags_ref};

	foreach my $fid ( 0 .. $#f ) {
		foreach my $rid (0 .. (scalar(@{$self->forms_pattern}) - 1)) {
			my $f1 = $self->forms_pattern->[$rid];
			my $l1 = $self->lemmas_pattern->[$rid];
			my $t1 = $self->ambiguous_tags_pattern->[$rid];
			my $t2 = $self->tags_replacement->[$rid];
			if (($t[$fid] =~ /$t1/) && ($f[$fid] =~ /$f1$/) && ($l[$fid] =~ /$l1$/)) {
				$fixed_tags[$fid] = $t2;
				last; 
			}
		}
	}
	return @fixed_tags;
}

1;
__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::TA::FixAmbiguousTags - Fixes Ambiguous Tags 

=head1 DESCRIPTION

This block is written to fix some of the incorrectly tagged word forms that are tagged using the block Treex::Block::A2A::TA::RuleBasedTagger. 
The rule based tagger (L<Treex::Block::A2A::TA::RuleBasedTagger>) is purely a suffix based tagger which determines tags based on just suffixes. 
Some of the suffixes are common to both the verbs and nouns. Thus, this block will mainly correct the tags if they are tagged otherwise. 

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.