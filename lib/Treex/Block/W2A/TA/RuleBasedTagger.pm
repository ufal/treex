package Treex::Block::W2A::TA::RuleBasedTagger;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Orthography::TA;
extends 'Treex::Core::Block';

use charnames ':full';

my $verb_suffixes_file = require_file_from_share(
	"data/models/simple_tagger/ta/dict/verb_suffixes_tagged.dat");
my $noun_suffixes_file = require_file_from_share(
	"data/models/simple_tagger/ta/dict/noun_suffixes_tagged.dat");
my $pp_file = require_file_from_share(
	"data/models/simple_tagger/ta/dict/postpositions.dat");
my $adj_file =
  require_file_from_share("data/models/simple_tagger/ta/dict/adjectives.dat");
my $adv_file =
  require_file_from_share("data/models/simple_tagger/ta/dict/adverbs.dat");
my $quantifiers_file =
  require_file_from_share("data/models/simple_tagger/ta/dict/quantifiers.dat");
my $pronouns_file =
  require_file_from_share("data/models/simple_tagger/ta/dict/pronouns.dat");

my %aux_verbs = (
	'அழு'       => 'அழு',
	'செய்'    => 'செய்',
	'கிட'       => 'கிட',
	'கிழி'    => 'கிழி',
	'கொள்'    => 'கொள்',
	'கொண்'    => 'கொள்',
	'கொடு'    => 'கொடு',
	'மாட்ட' => 'மாட்டு',
	'முடி'    => 'முடி',
	'பார்'    => 'பார்',
	'பண்ணு' => 'பண்ணு',
	'படு'       => 'படு',
	'பட்ட'    => 'படு',
	'போ'          => 'போ',
	'போடு'    => 'போடு',
	'போட்ட' => 'போடு',
	'தள்ளு' => 'தள்ளு',
	'தீர்'    => 'தீர்',
	'தொலை'    => 'தொலை',
	'வை'          => 'வை',
	'வரு'       => 'வரு',
	'வந்த'    => 'வரு',
	'வேண்ட' => 'வேண்டு',
	'விடு'    => 'விடு',
	'விட்ட' => 'விடு',
	'இரு'       => 'இரு',
	'உள்ள'    => 'உள்',
	'இல்லை' => 'இல்'
);

my %noun_suffixes_tags = load_suffixes($noun_suffixes_file);
my %verb_suffixes_tags = load_suffixes($verb_suffixes_file);
my %postpositions      = load_list($pp_file);
my %adjectives         = load_list($adj_file);
my %adverbs            = load_list($adv_file);
my %quantifiers        = load_list($quantifiers_file);
my %pronouns           = load_list($pronouns_file);

my @verb_suffixes = @{$verb_suffixes_tags{'s'}};
my @verb_tags     = @{$verb_suffixes_tags{'t'}};
my @noun_suffixes = @{$noun_suffixes_tags{'s'}};
my @noun_tags     = @{$noun_suffixes_tags{'t'}};

# verbal participle endings
my $_VBP_END_REG = qr/\N{TAMIL VOWEL SIGN U}|\N{TAMIL VOWEL SIGN I}/;

sub load_list {
	my $f = shift;
	my %words;
	open( RHANDLE, '<:encoding(UTF-8)', $f );
	my @data = <RHANDLE>;
	close RHANDLE;
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
	my $f             = shift;
	my %suffixes_tags = ();
	my @suffixes;
	my @tags;
	open( RHANDLE, '<:encoding(UTF-8)', $f );
	my @data = <RHANDLE>;
	close RHANDLE;
	foreach my $line (@data) {
		chomp $line;
		$line =~ s/(^\s+|\s+$)//;
		next if ( $line =~ /^$/ );
		next if ( $line =~ /^#/ );
		next if ( $line !~ /\t/ );
		my @st = split( /\t/, $line );
		push @suffixes, $st[0];
		push @tags,     $st[1];
	}
	$suffixes_tags{'s'} = \@suffixes;
	$suffixes_tags{'t'} = \@tags;
	return %suffixes_tags;
}

sub process_atree {
	my ( $self, $root ) = @_;
	my @nodes = $root->get_descendants( { ordered => 1 } );
	$self->first_pass( \@nodes );
	$self->second_pass( \@nodes );
}

sub first_pass {
	my ( $self, $nodes_ref ) = @_;
	my @nodes = @{$nodes_ref};
	foreach my $node (@nodes) {
		if ( defined $node->form ) {
			my $f = $node->form;
			$f =~ s/(^\s+|\s+$)//;
			my $tagged = 0;

			# start from list with less items
			$tagged = $self->tag_if_determiner( $node, $tagged );
			$tagged = $self->tag_if_conjunction( $node, $tagged );
			$tagged = $self->tag_if_punc( $node, $tagged );
			$tagged = $self->tag_if_pp( $node, $tagged );
			$tagged = $self->tag_if_adj( $node, $tagged );
			$tagged = $self->tag_if_adv( $node, $tagged );
			$tagged = $self->tag_if_quantifier( $node, $tagged );
			$tagged = $self->tag_if_pronoun( $node, $tagged );
			$tagged = $self->tag_if_noun( $node, $tagged );
			$tagged = $self->tag_if_verb( $node, $tagged );

			# Default tag : NN
			$node->set_attr( 'tag', 'NNNSN----------' ) if !$tagged;
		}
	}

	# postprocessing

	# POS [N->V]
	foreach my $i ( 0 .. ( $#nodes - 1 ) ) {

		# check if the compound verbs are tagged correctly
		# (i) change incorrectly tagged main verbs
		if ( $nodes[$i]->form =~ /($TA_HARD_REG)$/ ) {
			my $end_kctp = $1;
			$end_kctp =~ s/\N{TAMIL SIGN VIRAMA}$//;
			my $curr_tag = $nodes[$i]->tag;
			my $next_tag = $nodes[ $i + 1 ]->tag;
			if (   ( $nodes[ $i + 1 ]->form =~ /^$end_kctp/ )
				&& ( $curr_tag !~ /^V/ )
				&& ( $next_tag =~ /^V/ ) )
			{

#print $nodes[$i]->form . "/" . $curr_tag . "\t" . $nodes[$i+1]->form . "/" . $next_tag . "\n";
				$nodes[$i]->set_attr( 'tag', 'V--------------' );
			}
		}

		# (ii) check if non-finite form (verbal participle and infinitive)
		# is tagged correctly if it is followed by "iru" which has a
		# correct tag
		if ( $nodes[$i]->form =~ /($_VBP_END_REG)$/ ) {
			my $curr_tag = $nodes[$i]->tag;
			my $next_tag = $nodes[ $i + 1 ]->tag;
			if ( ( $curr_tag !~ /^V/ ) && ( $next_tag =~ /^V/ ) ) {

#print $nodes[$i]->form . "/" . $curr_tag . "\t" . $nodes[$i+1]->form . "/" . $next_tag . "\n";
				$nodes[$i]->set_attr( 'tag', 'V--------------' );
			}
		}
	}

	# SUBPOS [: -> #] at sentence boundaries
	if ( $nodes[$#nodes]->form =~ /\.|\?|\!|\:|\;/ ) {
		$nodes[$#nodes]->set_attr( 'tag', 'Z#-------------' );
	}
}

sub second_pass {
	my ( $self, $nodes_ref ) = @_;
	my @nodes = @{$nodes_ref};

	foreach my $node (@nodes) {
		$node->set_attr( 'tag', 'NNNSN----------' ) if ( !defined $node->tag );
	}

	# make sure the tag length is 15 for each tag
	foreach my $node (@nodes) {
		if ( length $node->tag != 15 ) {
			print "tag length error at : "
			  . $node->form . "\t"
			  . $node->tag . "\n";
			$node->set_attr( 'tag', 'NNNSN----------' );
		}
	}
}

sub tag_if_verb {
	my ( $self, $node, $tagged ) = @_;
	if ( !$tagged ) {
		# a. suffix based matching
		foreach my $i ( 0 .. $#verb_suffixes ) {
			my $vs = $verb_suffixes[$i];
			if ( $node->form =~ /$vs$/ ) {
				$node->set_attr( 'tag', $verb_tags[$i] );
				$tagged = 1;
				last;
			}
		}

		# b. matching against well known auxiliary verbs
		# tag is set if the wordform matches the beginning
		# of the auxiliary verb (faster than comparing against
		# all possible forms of auxiliary verbs)
		foreach my $ak ( keys %aux_verbs ) {
			if ( $node->form =~ /^$ak/ ) {
				if ( defined $node->tag ) {
					my $t = $node->tag;
					$t =~ s/^Vr/VR/;
					$t =~ s/^Vt/VT/;
					$t =~ s/^Vu/VU/;
					$t =~ s/^Vw/VW/;
					$node->set_attr( 'tag', $t );
					$tagged = 1;
					last;
				}
			}
		}
	}
	return $tagged;
}

sub tag_if_noun {
	my ( $self, $node, $tagged ) = @_;
	if ( !$tagged ) {
		foreach my $i ( 0 .. $#noun_suffixes ) {
			my $ns = $noun_suffixes[$i];
			if ( $node->form =~ /$ns$/ ) {
				$node->set_attr( 'tag', $noun_tags[$i] );
				$tagged = 1;
				last;
			}
		}
	}
	return $tagged;
}

sub tag_if_pronoun {
	my ( $self, $node, $tagged ) = @_;
	if ( !$tagged ) {
		if ( exists $pronouns{ $node->form } ) {
			$node->set_attr( 'tag', 'R--------------' );
			$tagged = 1;

			# determine SUBPOS
			my $subpos_found = 0;

			# SUBPOS: 'B' [general referential pronouns]
			# ends with உம்/um
			if ( $node->form =~ 
/\N{TAMIL VOWEL SIGN U}\N{TAMIL LETTER MA}\N{TAMIL SIGN VIRAMA}$/
			  )
			{
				$self->set_position( $node, 'B', 2 );
				$subpos_found = 1;
			}

			# SUBPOS: 'F' [Specific indefinite referential pronouns]
			# ends with ஓ/oo
			if ( $node->form =~ /\N{TAMIL VOWEL SIGN OO}$/ ) {
				$self->set_position( $node, 'F', 2 );
				$subpos_found = 1;
			}

			# SUBPOS: 'G' [Non specific indefinite pronouns]
			# ends with ஆவது/aavathu
			if ( $node->form =~
/\N{TAMIL VOWEL SIGN AA}\N{TAMIL LETTER VA}\N{TAMIL LETTER TA}\N{TAMIL VOWEL SIGN U}$/
			  )
			{
				$self->set_position( $node, 'G', 2 );
				$subpos_found = 1;
			}

			if ( !$subpos_found ) {

				# SUBPOS: 'i' [interrogative pronouns]
				if (
					$node->form =~ /^(\N{TAMIL LETTER YA}|\N{TAMIL LETTER E})/ )
				{
					$self->set_position( $node, 'i', 2 );
				}

				# SUBPOS: 'p' [personal pronouns]
				else {
					$self->set_position( $node, 'p', 2 );
				}
			}
		}
	}
	return $tagged;
}

sub tag_if_pp {
	my ( $self, $node, $tagged ) = @_;
	if ( !$tagged ) {
		if ( exists $postpositions{ $node->form } ) {
			$node->set_attr( 'tag', 'PP-------------' );
			$tagged = 1;
		}
	}
	return $tagged;
}

sub tag_if_adj {
	my ( $self, $node, $tagged ) = @_;
	if ( !$tagged ) {
		if ( exists $adjectives{ $node->form } ) {
			$node->set_attr( 'tag', 'JJ-------------' );
			$tagged = 1;
		}
		else {

			# test if the form ends with derived
			# adjectival suffix ான/Ana
			if ( $node->form =~ /ான$/ ) {
				$node->set_attr( 'tag', 'JJ-------------' );
				$tagged = 1;
			}
		}
	}
	return $tagged;
}

sub tag_if_adv {
	my ( $self, $node, $tagged ) = @_;
	if ( !$tagged ) {
		if ( exists $adverbs{ $node->form } ) {
			$node->set_attr( 'tag', 'AA-------------' );
			$tagged = 1;
		}
		else {

			# test if the form ends with derived
			# adverbial suffix "Aka" - ாக
			if ( $node->form =~ /ாக(வும்|வே|வா|வோ)$/ ) {
				$node->set_attr( 'tag', 'AA-------------' );
				$tagged = 1;
			}
		}
	}
	return $tagged;
}

sub tag_if_quantifier {
	my ( $self, $node, $tagged ) = @_;
	if ( !$tagged ) {
		if ( exists $quantifiers{ $node->form } ) {
			$node->set_attr( 'tag', 'QQ-------------' );
			$tagged = 1;
		}
	}
	return $tagged;
}

sub tag_if_conjunction {
	my ( $self, $node, $tagged ) = @_;
	if ( !$tagged ) {
		if ( $node->form =~ /^(அல்லது|மற்றும்)$/ ) {
			$node->set_attr( 'tag', 'CC-------------' );
			$tagged = 1;
		}
	}
	return $tagged;
}

sub tag_if_determiner {
	my ( $self, $node, $tagged ) = @_;
	if ( !$tagged ) {
		if ( $node->form =~
			/^(அ|இ|எ)ந்த(க்|ச்|த்|ப்)?$/ )
		{
			$node->set_attr( 'tag', 'DD-------------' );
			$tagged = 1;
		}
	}
	return $tagged;
}

sub tag_if_punc {
	my ( $self, $node, $tagged ) = @_;
	if ( !$tagged ) {
		if ( $node->form =~
/^(;|!|<|>|\{|\}|\[|\]|\(|\)|\?|\#|\$|£|\%|\&|``|\'\'|‘‘|"|“|”|«|»|--|–|—|„|\,|‘|\*|\^|\||\`|\.|\:|\')$/
		  )
		{
			$node->set_attr( 'tag', 'Z:-------------' );
			$tagged = 1;
		}
	}
	return $tagged;
}

sub fill_png {
	my ( $self, $node ) = @_;

	# Masculine (M)
	# frequent endings : அன்/ANNN, ஆன்/AANNN, தி/TI
	if ( $node->form =~ /(($TA_CONSONANTS_PLUS_VOWEL_A_REG)ன்|ான்)$/ )
	{
		$self->set_position( $node, 'M', 3 );
	}

# Feminine (F)
# frequent endings : ஐ/AI, தா/TAA, அம்/AM, ரி/RI, தி/TI, கா/KAA
	elsif ( $node->form =~
/(ை|தா|($TA_CONSONANTS_PLUS_VOWEL_A_REG)ம்|ரி|தி|கா)/
	  )
	{
		$self->set_position( $node, 'F', 3 );
	}

	# Neuter (N)
	else {
		$self->set_position( $node, 'N', 3 );
	}
}

# set nth position of a node's tag
# note: The positon index 'n' starts from 1
sub set_position {
	my ( $self, $node, $c, $n ) = @_;
	my $tmptag = $node->tag;
	substr( $tmptag, $n - 1, 1 ) = $c;
	$node->set_attr( 'tag', $tmptag );
	return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::TA::RuleBasedTagger - Rule Based POS Tagger for Tamil

=head1 DESCRIPTION

This block tags the Tamil sentences based on word list/endings. The POS tagset is based on major POS categories available for Tamil. 
The tagset contains the following POS categories,


=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>


=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
