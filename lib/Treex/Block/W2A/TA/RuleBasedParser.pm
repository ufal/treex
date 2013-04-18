package Treex::Block::W2A::TA::RuleBasedParser;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Orthography::TA;
extends 'Treex::Core::Block';

use charnames ':full';

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
		my @parents = $self->parse_sentence( \@forms, \@lemmas, \@tags );
		foreach my $i ( 0 .. $#parents ) {
			if ( $parents[$i] == -1 ) {
				$nodes[$i]->set_parent($atree);
			}
			else {
				$nodes[$i]->set_parent( $nodes[ $parents[$i] ] );
			}
		}
	}
}

sub parse_sentence {
	my ( $self, $forms_ref, $lemma_ref, $tags_ref ) = @_;
	my @parents      = (-1) x scalar( @{$forms_ref} );
	my %parsing_stat = ();
	$parsing_stat{'forms'}   = $forms_ref;
	$parsing_stat{'lemmas'}  = $lemma_ref;
	$parsing_stat{'tags'}    = $tags_ref;
	$parsing_stat{'parents'} = \@parents;
	%parsing_stat            = $self->attach_cons_to_pred( \%parsing_stat );
	%parsing_stat            = $self->attach_modifiers( \%parsing_stat );
	@parents                 = @{ $parsing_stat{'parents'} };
	return @parents;
}

# MODIFIERS
# =========
# attach
# a. determiners/adjectives to the following noun
# b. cardinals/ordinals/digits/quantifiers
#	 to the following cardinal or to the noun
# c. group the nominals under the right most nominal

sub attach_modifiers {
	my ( $self, $ps_ref ) = @_;
	my %ps      = %{$ps_ref};
	my @forms   = @{ $ps{'forms'} };
	my @lemmas  = @{ $ps{'lemmas'} };
	my @tags    = @{ $ps{'tags'} };
	my @parents = @{ $ps{'parents'} };

	foreach my $i ( 0 .. ( $#forms - 1 ) ) {

		# a.
		if ( $tags[$i] =~ /^(D|J)/ ) {
			if ( $i + 1 <= $#forms ) {
				for my $j ( ( $i + 1 ) .. $#forms ) {
					$parents[$i] = $j if $tags[$j] =~ /^(N)/;
					last;
				}
			}
		}

		# b.
		if ( $tags[$i] =~ /^(Uc|Uo|U\=|QQ)/ ) {
			if ( $i + 1 <= $#forms ) {
				for my $j ( ( $i + 1 ) .. $#forms ) {
					$parents[$i] = $j if $tags[$j] =~ /^(Uc|N)/;
					last;
				}
			}
		}

		# c.
		my @n_group;
		if ( $tags[$i] =~ /^(NN..N)/ ) {
			push @n_group, $i;
			if ( $i + 1 <= $#forms ) {
				for my $j ( ( $i + 1 ) .. $#forms ) {
					push @n_group, $j if $tags[$j] =~ /^(NN..N)/;
					last if $tags[$j] !~ /^(NN..N)/;					
				}
			}
		}
		if (scalar(@n_group) > 1) {
			map{$parents[$_] = $n_group[$#n_group]}@n_group[0..($#n_group-1)];
			@n_group = ();
		}

	}

	$ps{'parents'} = \@parents;
	return %ps;
}

# attach constituents to the main predicate
sub attach_cons_to_pred {
	my ( $self, $ps_ref ) = @_;
	my %ps      = %{$ps_ref};
	my @forms   = @{ $ps{'forms'} };
	my @lemmas  = @{ $ps{'lemmas'} };
	my @tags    = @{ $ps{'tags'} };
	my @parents = @{ $ps{'parents'} };

	my $l = scalar(@tags) - 1;
	if ( $l - 2 >= 0 ) {
		if ( $tags[ $l - 1 ] =~ /^V(r|R)/ ) {
			foreach my $i ( 0 .. $l - 2 ) { $parents[$i] = $l - 1 }
		}
	}

	$ps{'parents'} = \@parents;
	return %ps;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::TA::RuleBasedParser - Rule Based Dependency Parser for Tamil

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
