package Treex::Block::W2A::TA::Lemmatization;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';

has 'data_dir' => (
	isa     => 'Str',
	is      => 'ro',
	default => 'data/models/simple_lemmatizer/ta'
);

has 'verb_rules' => (
	isa     => 'HashRef',
	is      => 'rw',
	lazy    => 1,
	builder => '_build_verb_rules'
);

has 'noun_rules' => (
	isa     => 'HashRef',
	is      => 'rw',
	lazy    => 1,
	builder => '_build_noun_rules'
);

has 'noun_rules_file' =>
  ( isa => 'Str', is => 'ro', default => 'noun_suffixes.dat' );
has 'verb_rules_file' =>
  ( isa => 'Str', is => 'ro', default => 'verb_suffixes.dat' );
  

# forms length < 'min_length' will not be lemmatized
has 'min_len' => ( isa => 'Int', is => 'ro', default => 4 );

# global variables for easy access
my @nrules;
my @nvals;
my @vrules;
my @vvals;

sub BUILD {
	my ($self) = @_;
	@vrules = @{ $self->verb_rules->{'r'} };
	@vvals  = @{ $self->verb_rules->{'v'} };
	@nrules = @{ $self->noun_rules->{'r'} };
	@nvals  = @{ $self->noun_rules->{'v'} };
}

sub _build_verb_rules {
	my ($self) = @_;
	my $vr_file =
	  require_file_from_share( $self->data_dir . "/" . "verb_suffixes.dat" );
	my %verb_rules = load_rules($vr_file);
	return \%verb_rules;
}

sub _build_noun_rules {
	my ($self) = @_;
	my $nr_file =
	  require_file_from_share( $self->data_dir . "/" . "noun_suffixes.dat" );
	my %noun_rules = load_rules($nr_file);
	return \%noun_rules;
}

sub process_document {
	my ( $self, $document ) = @_;
	my @bundles = $document->get_bundles();
	for ( my $i = 0 ; $i < @bundles ; ++$i ) {
		my $atree =
		  $bundles[$i]->get_zone( $self->language, $self->selector )
		  ->get_atree();
		my @nodes = $atree->get_descendants( { ordered => 1 } );
		my @forms = map { $_->form } @nodes;
		my @lemmas = $self->lemmatize( \@forms );
		map { $nodes[$_]->set_attr( 'lemma', $lemmas[$_] ) } 0 .. $#lemmas;
	}
}

sub lemmatize {
	my ( $self, $forms_ref ) = @_;
	my @forms  = @{$forms_ref};
	my @lemmas = ();
	my $PUNC =
qr/;|!|<|>|\{|\}|\[|\]|\(|\)|\?|\#|\$|£|\%|\&|``|\'\'|‘‘|"|“|”|«|»|--|–|—|„|\,|‘|\*|\^|\||\`|\.|\:|\'/;
	foreach my $idx ( 0 .. $#forms ) {
		my $form        = $forms[$idx];
		my $lemma_found = 0;

		if ( ( length($form) < $self->min_len ) || ( $form =~ /(\d|$PUNC)/ ) ) {
			$lemmas[$idx] = $form;
			$lemma_found = 1;
			next;
		}

		foreach my $i ( 0 .. $#vrules ) {
			my $r = $vrules[$i];
			my $v = $vvals[$i];
			if ( $form =~ /$r$/ ) {
				my $tmpform = $form;
				$tmpform =~ s/$r$/"$v"/ee;
				$lemmas[$idx] = $tmpform;
				$lemma_found = 1;
				last;
			}
		}

		if ( !$lemma_found ) {
			if ( $form =~ /ாகவ(ும்|ா|ே|ோ|ாவது)?$/ ) {
				my $tmpform = $form;
				$tmpform =~ s/ாகவ(ும்|ா|ே|ோ|ாவது)?$//;
				$lemmas[$idx] = $tmpform;
				$lemma_found = 1;
			}
		}

		if ( !$lemma_found ) {
			foreach my $i ( 0 .. $#nrules ) {
				my $r = $nrules[$i];
				my $v = $nvals[$i];
				if ( $form =~ /$r$/ ) {
					my $tmpform = $form;
					$tmpform =~ s/$r$/"$v"/ee;
					$lemmas[$idx] = $tmpform;
					$lemma_found = 1;
					last;
				}
			}
		}
		$lemmas[$idx] = $form if !$lemma_found;
	}

	# lemma length should be at least 1
	foreach my $i ( 0 .. $#lemmas ) {
		$lemmas[$i] = $forms[$i] if ( length( $lemmas[$i] ) <= 0 );
	}

	return @lemmas;
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

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::TA::Lemmatization - Tamil Lemmatizer

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
