package Treex::Block::W2A::TA::RuleBasedTagger;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Orthography::TA;
extends 'Treex::Core::Block';

use charnames ':full';

has 'data_dir' =>
  ( isa => 'Str', is => 'ro', default => 'data/models/simple_tagger/ta/dict' );
has 'verb_tags_file' =>
  ( isa => 'Str', is => 'ro', default => 'verb_suffixes_tagged.dat' );
has 'noun_tags_file' =>
  ( isa => 'Str', is => 'ro', default => 'noun_suffixes_tagged.dat' );
has 'verb_tags' =>
  ( isa => 'HashRef', is => 'rw', lazy => 1, builder => '_build_verb_tags' );
has 'noun_tags' =>
  ( isa => 'HashRef', is => 'rw', lazy => 1, builder => '_build_noun_tags' );
has 'pp_list' =>
  ( isa => 'HashRef', is => 'rw', lazy => 1, builder => '_build_pp_list' );
has 'adj_list' =>
  ( isa => 'HashRef', is => 'rw', lazy => 1, builder => '_build_adj_list' );
has 'adv_list' =>
  ( isa => 'HashRef', is => 'rw', lazy => 1, builder => '_build_adv_list' );
has 'aux_verbs' =>
  ( isa => 'HashRef', is => 'rw', lazy => 1, builder => '_build_aux_verbs' );

has 'quantifiers_list' => (
	isa     => 'HashRef',
	is      => 'rw',
	lazy    => 1,
	builder => '_build_quantifiers_list'
);

has 'pronouns_list' => (
	isa     => 'HashRef',
	is      => 'rw',
	lazy    => 1,
	builder => '_build_pronouns_list'
);

has 'print_rule_freq' => ( isa => 'Bool', is => 'ro', default => 0 );

# global variables for easy access
my @noun_suffixes;
my @noun_tags;
my @verb_suffixes;
my @verb_tags;
my %noun_rule_freq;
my %verb_rule_freq;

# verbal participle endings
my $_VBP_END_REG = qr/\N{TAMIL VOWEL SIGN U}|\N{TAMIL VOWEL SIGN I}/;

sub BUILD {
	my ($self) = @_;
	@verb_suffixes = @{ $self->verb_tags->{'s'} };
	@verb_tags     = @{ $self->verb_tags->{'t'} };
	@noun_suffixes = @{ $self->noun_tags->{'s'} };
	@noun_tags     = @{ $self->noun_tags->{'t'} };

	# initialize frequencies
	if ( $self->print_rule_freq ) {
		foreach my $i ( 0 .. $#noun_suffixes ) { $noun_rule_freq{$i}++ }
		foreach my $i ( 0 .. $#verb_suffixes ) { $verb_rule_freq{$i}++ }
	}
}

sub _build_verb_tags {
	my ($self) = @_;
	my $vs_file =
	  require_file_from_share( $self->data_dir . '/' . $self->verb_tags_file );
	my %verb_suffixes_tags = load_suffixes($vs_file);
	return \%verb_suffixes_tags;
}

sub _build_noun_tags {
	my ($self) = @_;
	my $ns_file =
	  require_file_from_share( $self->data_dir . '/' . $self->noun_tags_file );
	my %noun_suffixes_tags = load_suffixes($ns_file);
	return \%noun_suffixes_tags;
}

sub _build_pp_list {
	my ($self) = @_;
	my $pp_file =
	  require_file_from_share( $self->data_dir . "/postpositions.dat" );
	my %postpositions = load_list($pp_file);
	return \%postpositions;
}

sub _build_adj_list {
	my ($self) = @_;
	my $adj_file =
	  require_file_from_share( $self->data_dir . "/adjectives.dat" );
	my %adjectives = load_list($adj_file);
	return \%adjectives;
}

sub _build_adv_list {
	my ($self)   = @_;
	my $adv_file = require_file_from_share( $self->data_dir . "/adverbs.dat" );
	my %adverbs  = load_list($adv_file);
	return \%adverbs;
}

sub _build_pronouns_list {
	my ($self) = @_;
	my $pronouns_file =
	  require_file_from_share( $self->data_dir . "/pronouns.dat" );
	my %pronouns = load_list($pronouns_file);
	return \%pronouns;
}

sub _build_quantifiers_list {
	my ($self) = @_;
	my $quantifiers_file =
	  require_file_from_share( $self->data_dir . "/quantifiers.dat" );
	my %quantifiers = load_list($quantifiers_file);
	return \%quantifiers;
}

sub _build_aux_verbs {
	my ($self) = @_;
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
	return \%aux_verbs;
}

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

sub process_document {
	my ( $self, $document ) = @_;
	my @bundles = $document->get_bundles();
	for ( my $i = 0 ; $i < @bundles ; ++$i ) {
		my $atree =
		  $bundles[$i]->get_zone( $self->language, $self->selector )
		  ->get_atree();
		my @nodes = $atree->get_descendants( { ordered => 1 } );
		my @forms = map { $_->form } @nodes;
		my @lemmas = map { $_->lemma } @nodes;		
		my @tags = $self->tag_sentence( \@forms, \@lemmas );
		map { $nodes[$_]->set_attr( 'tag', $tags[$_] ) } 0 .. $#tags;
	}
}

sub tag_sentence {
	my ( $self, $forms_ref, $lemmas_ref ) = @_;
	my @forms     = @{$forms_ref};
	my @lemmas = ();
	my @tags      = ();
	my @is_tagged = 0 x scalar(@forms);
	@lemmas = @{$lemmas_ref} if (defined $lemmas_ref); 
	my %tagging_stat =
	  ( 'forms' => \@forms, 'lemmas' => \@lemmas, 'tags' => \@tags, 'tagged' => \@is_tagged );
	%tagging_stat = $self->first_pass( \%tagging_stat );
	%tagging_stat = $self->second_pass( \%tagging_stat );
	@tags         = @{ $tagging_stat{'tags'} };
	return @tags;
}

sub first_pass {
	my ( $self, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @forms     = @{ $ts{'forms'} };
	my @lemmas = @{ $ts{'lemmas'} };
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };

	foreach my $fid ( 0 .. $#forms ) {
		my $form = $forms[$fid];
		if ( defined $form ) {
			my $f = $form;
			$f =~ s/(^\s+|\s+$)//;

			# start from list with less items
			%ts = $self->tag_if_determiner( $fid, $form, \%ts );
			%ts = $self->tag_if_conjunction( $fid, $form, \%ts );
			%ts = $self->tag_if_punc( $fid, $form, \%ts );
			%ts = $self->tag_if_pp( $fid, $form, \%ts );
			%ts = $self->tag_if_adj( $fid, $form, \%ts );
			%ts = $self->tag_if_adv( $fid, $form, \%ts );
			%ts = $self->tag_if_quantifier( $fid, $form, \%ts );
			%ts = $self->tag_if_pronoun( $fid, $form, \%ts );
			%ts = $self->tag_if_noun( $fid, $form, \%ts );
			%ts = $self->tag_if_verb( $fid, $form, \%ts );
		}
	}

	# SUBPOS [: -> #] at sentence boundaries
	if ( $forms[$#forms] =~ /\.|\?|\!|\:|\;/ ) {
		$tags[$#tags] = 'Z#-------------';
	}
	
	# assign default tags
	@tags      = @{ $ts{'tags'} };
	@is_tagged = @{ $ts{'tagged'} };
	
	foreach my $fid ( 0 .. $#forms ) {
		$tags[$fid] = 'NNNSN----------' if ( !defined $tags[$fid] );
		$is_tagged[$fid] = 1;
	}
	
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub second_pass {
	my ( $self, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @forms     = @{ $ts{'forms'} };
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };

	# make sure the tag length is 15 for each tag
	foreach my $id ( 0 .. $#forms ) {
		if ( length $tags[$id] != 15 ) {
			print "tag length error at : "
			  . $forms[$id] . "\t"
			  . $tags[$id] . "\n";
			$tags[$id] = 'NNNSN----------';
		}
	}
	
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub tag_if_verb {
	my ( $self, $fid, $form, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };

	if ( !$is_tagged[$fid] ) {

		# a. suffix based matching
		foreach my $i ( 0 .. $#verb_suffixes ) {
			my $vs = $verb_suffixes[$i];
			if ( $form =~ /$vs$/ ) {
				$tags[$fid]      = $verb_tags[$i];
				$is_tagged[$fid] = 1;
				$verb_rule_freq{$i}++ if $self->print_rule_freq;
				last;
			}
		}

		# b. matching against well known auxiliary verbs
		# tag is set if the wordform matches the beginning
		# of the auxiliary verb (faster than comparing against
		# all possible forms of auxiliary verbs)
		foreach my $ak ( keys %{ $self->aux_verbs } ) {
			if ( $form =~ /^$ak/ ) {
				if ( defined $tags[$fid] ) {
					my $t = $tags[$fid];
					$t =~ s/^Vr/VR/;
					$t =~ s/^Vt/VT/;
					$t =~ s/^Vu/VU/;
					$t =~ s/^Vw/VW/;
					$tags[$fid]      = $t;
					$is_tagged[$fid] = 1;
					last;
				}
			}
		}
	}
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub tag_if_noun {
	my ( $self, $fid, $form, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };
	if ( !$is_tagged[$fid] ) {
		foreach my $i ( 0 .. $#noun_suffixes ) {
			my $ns = $noun_suffixes[$i];
			if ( $form =~ /$ns$/ ) {
				$tags[$fid]      = $noun_tags[$i];
				$is_tagged[$fid] = 1;
				$noun_rule_freq{$i}++ if $self->print_rule_freq;
				last;
			}
		}
	}
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub tag_if_pronoun {
	my ( $self, $fid, $form, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };
	if ( $form =~ /^(அ|இ|எ|ய|த|ந)/ ) {
		if ( !$is_tagged[$fid] ) {
			if ( exists $self->pronouns_list->{$form} ) {
				$tags[$fid]      = 'R--------------';
				$is_tagged[$fid] = 1;

				# determine SUBPOS
				my $subpos_found = 0;

				# SUBPOS: 'B' [general referential pronouns]
				# ends with உம்/um
				if ( $form =~
/\N{TAMIL VOWEL SIGN U}\N{TAMIL LETTER MA}\N{TAMIL SIGN VIRAMA}$/
				  )
				{
					$tags[$fid] = $self->set_position( $tags[$fid], 'B', 2 );
					$subpos_found = 1;
				}

				# SUBPOS: 'F' [Specific indefinite referential pronouns]
				# ends with ஓ/oo
				if ( $form =~ /\N{TAMIL VOWEL SIGN OO}$/ ) {
					$tags[$fid] = $self->set_position( $tags[$fid], 'F', 2 );
					$subpos_found = 1;
				}

				# SUBPOS: 'G' [Non specific indefinite pronouns]
				# ends with ஆவது/aavathu
				if ( $form =~
/\N{TAMIL VOWEL SIGN AA}\N{TAMIL LETTER VA}\N{TAMIL LETTER TA}\N{TAMIL VOWEL SIGN U}$/
				  )
				{
					$tags[$fid] = $self->set_position( $tags[$fid], 'G', 2 );
					$subpos_found = 1;
				}

				if ( !$subpos_found ) {

					# SUBPOS: 'i' [interrogative pronouns]
					if ( $form =~ /^(\N{TAMIL LETTER YA}|\N{TAMIL LETTER E})/ )
					{
						$tags[$fid] = $self->set_position( $tags[$fid], 'i', 2 );
					}

					# SUBPOS: 'p' [personal pronouns]
					else {
						$tags[$fid] = $self->set_position( $tags[$fid], 'p', 2 );
					}
				}
			}
		}
	}
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub tag_if_pp {
	my ( $self, $fid, $form, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };
	if ( !$is_tagged[$fid] ) {
		if ( exists $self->pp_list->{$form} ) {
			$tags[$fid]      = 'PP-------------';
			$is_tagged[$fid] = 1;
		}
	}
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub tag_if_adj {
	my ( $self, $fid, $form, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };
	if ( !$is_tagged[$fid] ) {
		if ( exists $self->adj_list->{$form} ) {
			$tags[$fid]      = 'JJ-------------';
			$is_tagged[$fid] = 1;
		}
		else {

			# test if the form ends with derived
			# adjectival suffix ான/Ana
			if ( $form =~ /ான$/ ) {
				$tags[$fid]      = 'JJ-------------';
				$is_tagged[$fid] = 1;
			}
		}
	}
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub tag_if_adv {
	my ( $self, $fid, $form, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };
	if ( !$is_tagged[$fid] ) {
		if ( exists $self->adv_list->{$form} ) {
			$tags[$fid]      = 'AA-------------';
			$is_tagged[$fid] = 1;
		}
		else {

			# test if the form ends with derived
			# adverbial suffix "Aka" - ாக
			if ( $form =~ /ாக(வும்|வே|வா|வோ)$/ ) {
				$tags[$fid]      = 'AA-------------';
				$is_tagged[$fid] = 1;
			}
		}
	}
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub tag_if_quantifier {
	my ( $self, $fid, $form, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };
	if ( !$is_tagged[$fid] ) {
		if ( exists $self->quantifiers_list->{$form} ) {
			$tags[$fid]      = 'QQ-------------';
			$is_tagged[$fid] = 1;
		}
	}
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub tag_if_conjunction {
	my ( $self, $fid, $form, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };
	if ( !$is_tagged[$fid] ) {
		if ( $form =~ /^(அல்லது|மற்றும்)$/ ) {
			$tags[$fid]      = 'CC-------------';
			$is_tagged[$fid] = 1;
		}
	}
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub tag_if_determiner {
	my ( $self, $fid, $form, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };
	if ( !$is_tagged[$fid] ) {
		if ( $form =~ /^(அ|இ|எ)ந்த(க்|ச்|த்|ப்)?$/ )
		{
			$tags[$fid]      = 'DD-------------';
			$is_tagged[$fid] = 1;
		}
	}
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub tag_if_punc {
	my ( $self, $fid, $form, $ts_ref ) = @_;
	my %ts        = %{$ts_ref};
	my @tags      = @{ $ts{'tags'} };
	my @is_tagged = @{ $ts{'tagged'} };
	if ( !$is_tagged[$fid] ) {
		if ( $form =~
/^(;|!|<|>|\{|\}|\[|\]|\(|\)|\?|\#|\$|£|\%|\&|``|\'\'|‘‘|"|“|”|«|»|--|–|—|„|\,|‘|\*|\^|\||\`|\.|\:|\')$/
		  )
		{
			$tags[$fid]      = 'Z:-------------';
			$is_tagged[$fid] = 1;
		}
	}
	$ts{'tags'}   = \@tags;
	$ts{'tagged'} = \@is_tagged;
	return %ts;
}

sub guess_gender_for_noun {
	my ( $self, $form, $lemma, $tag ) = @_;

	# Masculine (M)
	# gender: 'M'
	# frequent endings : அன்/ANNN, ஆன்/AANNN, தி/TI

	# Feminine (F)
	# gender: 'F'	
	# frequent endings : ஐ/AI, தா/TAA, அம்/AM, ரி/RI, தி/TI, கா/KAA
	if ( $lemma =~ /(($TA_CONSONANTS_PLUS_VOWEL_A_REG)ன்|ான்)$/ )
	{
		$tag = $self->set_position( $tag, 'M', 3 );
	}
	elsif ( $lemma =~
/(ை|தா|($TA_CONSONANTS_PLUS_VOWEL_A_REG)ம்|ரி|தி|கா)/
	  )
	{
		$tag = $self->set_position( $tag, 'F', 3 );
	}
	return $tag;	
}

# set nth position of a tag
# note: The positon index 'n' starts from 1
sub set_position {
	my ( $self, $tag, $c, $n ) = @_;
	substr( $tag, $n - 1, 1 ) = $c;
	return $tag;
}

sub process_end {
	my ($self) = @_;
	if ( $self->print_rule_freq ) {
		my @sorted_noun_idx =
		  sort { $noun_rule_freq{$b} <=> $noun_rule_freq{$a} }
		  keys %noun_rule_freq;
		my @sorted_verb_idx =
		  sort { $verb_rule_freq{$b} <=> $verb_rule_freq{$a} }
		  keys %verb_rule_freq;
		print "Noun Rules According to Rule Application in the Data\n";
		foreach my $idx ( 0 .. $#noun_suffixes ) {
			my $sid = $sorted_noun_idx[$idx];
			print $noun_suffixes[$sid] . "\t:\t"
			  . $noun_tags[$sid] . "\t:\t"
			  . $noun_rule_freq{$sid} . "\n";
		}
		print "Verb Rules According to Rule Application in the Data\n";
		foreach my $idx ( 0 .. $#verb_suffixes ) {
			my $sid = $sorted_verb_idx[$idx];
			print $verb_suffixes[$sid] . "\t:\t"
			  . $verb_tags[$sid] . "\t:\t"
			  . $verb_rule_freq{$sid} . "\n";
		}
	}
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
