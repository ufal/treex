package Treex::Block::W2W::TA::Transliteration;
use utf8;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Transliteration::TA;
extends 'Treex::Core::Block';

has 'use_enc_map' => ( isa => 'Str',  is => 'rw', default => 'utf8_2_latin' );
has 'mark_latin'  => ( isa => 'Bool', is => 'rw', default => 1 );
has 'del_latin_marking' => ( isa => 'Bool', is => 'rw', default => 0 );
has 'transliterator' => ( is => 'ro', lazy_build => 1 );

sub _build_transliterator {
	my ($self) = @_;
	return Treex::Tool::Transliteration::TA->new({'use_enc_map' => $self->use_enc_map});
}

sub process_document {
	my ( $self, $document ) = @_;
	my @bundles = $document->get_bundles();
	for ( my $i = 0 ; $i < @bundles ; ++$i ) {
		my $zone = $bundles[$i]->get_zone( $self->language, $self->selector );
		if ( $zone->has_atree() ) {
			my $atree = $zone->get_atree();
			my @nodes = $atree->get_descendants( { ordered => 1 } );
			my @forms = map { $_->form } @nodes;
			my @tr_forms = $self->transliterate_forms(\@forms);
			map {$nodes[$_]->set_attr('form', $tr_forms[$_])}0..$#tr_forms;
            my @lemmas = map { $_->lemma } @nodes;
            my @tr_lemmas = $self->transliterate_forms(\@lemmas);
            map {$nodes[$_]->set_attr('lemma', $tr_lemmas[$_])} (0..$#tr_lemmas);
		}
		if ($zone->sentence) {
			my $sentence_tr = $self->transliterate_sentence($zone->sentence);
			$zone->set_sentence($sentence_tr);
		}
	}
}

sub transliterate_sentence {
	my ( $self, $sentence ) = @_;
	my $sentence_tr = ();
	if ( $self->mark_latin || $self->del_latin_marking) {
		if ($self->mark_latin) {
			if ($sentence =~ /[a-zA-Z]/) {
	            my @words = split(/\s+/, $sentence);
	            map{$_ =~ s/(.*[a-zA-Z].*)/<§§§§>$1<řřřř>/}@words;
                my @words_tr = ();
                foreach my $w (@words) {
                    push @words_tr, $w and next if $w =~ /^<§§§§>(.+)<řřřř>$/;
                    my $w_tr = $self->transliterator->transliterate_string( $w );
                    push @words_tr, $w_tr;
                }
                $sentence_tr = join " ", @words_tr;	
			}
			else {
				$sentence_tr = $self->transliterator->transliterate_string( $sentence );
			}
		}
		elsif ($self->del_latin_marking) {
			if ( $sentence =~ /<§§§§>(.+)<řřřř>/ ) {
            	my @words_tr = ();
	            my @words = split(/\s+/, $sentence);
	            foreach my $w (@words) {
                    if ($w =~ /^<§§§§>(.+)<řřřř>$/) {
                        $w = $1;
                        push @words_tr, $w and next;
                    }
                    my $w_tr =$self->transliterator->transliterate_string( $w );
                    push @words_tr, $w_tr;    	            	
	            }
                $sentence_tr = join " ", @words_tr;
			}
			else {
				$sentence_tr = $self->transliterator->transliterate_string( $sentence );
			}			
		}
	}
	else {
		$sentence_tr = $self->transliterator->transliterate_string( $sentence );
	}
}

sub transliterate_forms {
	my ( $self, $forms_ref ) = @_;
	my @tr = @{$forms_ref};

	if ( $self->mark_latin ) {
		map { $_ =~ s/(.*[a-zA-Z].*)/<§§§§>$1<řřřř>/ } @tr;
		foreach my $i ( 0 .. $#tr ) {
			if ( $tr[$i] !~ /<§§§§>(.+)<řřřř>/ ) {
				$tr[$i] =
				  $self->transliterator->transliterate_string( $tr[$i] );
			}
		}

	}
	elsif ($self->del_latin_marking) {
		foreach my $i ( 0 .. $#tr ) {
			if ( $tr[$i] !~ /<§§§§>(.+)<řřřř>/ ) {
				$tr[$i] =
				  $self->transliterator->transliterate_string( $tr[$i] );
			}
			else {
				$tr[$i] =~ s/(<§§§§>|<řřřř>)//;
			}
		}		
	}
	else {
		foreach my $i ( 0 .. $#tr ) {
			$tr[$i] = $self->transliterator->transliterate_string( $tr[$i] );
		}
	}
	return @tr;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::TA::Transliteration - Transliteration Between Different Formats

=head1 DESCRIPTION

By default, the 'forms' and 'lemmas' of a-trees are transliterated from one format to another.

=head1 PARAMETERS

=head2 'use_enc_map'

The possible values for C<'use_enc_map'> are 'utf8_2_latin' and 'latin_2_utf8'.

=head1 TODO

An option can be included as to precisely what should be transliterated instead of just 'sentence' and 'forms' and 'lemmas' by default.

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

=cut
