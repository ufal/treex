package Treex::Tool::SandhiHandler::Tamil;
use utf8;
use base 'Exporter';
use Treex::Core::Common;

our @EXPORT_OK = ('combine');

binmode STDIN,  ":utf8";
binmode STDOUT, ":utf8";
binmode STDERR, ":utf8";

# Tamil alphabets

# vowels
my $VOWELS            = qr/அ|ஆ|இ|ஈ|உ|ஊ|எ|ஏ|ஐ|ஒ|ஓ|ஔ/;
my $VOWELS_I          = qr/இ|ஈ|ஐ|ய்/;
my $VOWELS_NO_I       = qr/அ|ஆ|உ|ஊ|எ|ஏ|ஒ|ஓ|ஔ/;
my $SHORT_VOWELS      = qr/அ|இ|உ|எ|ஒ/;
my $SHORT_VOWELS_NO_I = qr/அ|உ|எ/;
my $LONG_VOWELS       = qr/ஆ|ஈ|ஊ|ஏ|ஓ/;
my $LONG_VOWELS_NO_I  = qr/ஆ|ஊ|ஏ/;

# when consonant+vowel combination,
# vowel is a sign (equivalent to diacritics in other languages)
my $VOWELS_SIGNS =
  qr/ா|ி|ீ|ு|ூ|ை|ெ|ே|ொ|ோ|ௌ/;
my $VOWELS_I_SIGNS         = qr/ி|ீ|ை/;
my $VOWELS_NO_I_SIGNS      = qr/ா|ு|ூ|ெ|ே|ொ|ோ|ௌ/;
my $SHORT_VOWEL_SIGNS      = qr/ி|ு|ெ|ொ/;
my $SHORT_VOWEL_SIGNS_NO_I = qr/ு|ெ|ொ/;
my $LONG_VOWEL_SIGNS       = qr/ா|ீ|ூ|ே|ோ/;
my $LONG_VOWEL_SIGNS_NO_I  = qr/ா|ூ|ே|ோ/;

# diphthongs
my $DIPHTHONGS      = qr/ஐ|ஔ/;
my $DIPHTHONG_SIGNS = qr/ை|ௌ/;

# consonants
my $CONSONANTS =
qr/க்|ங்|ச்|ங்|ட்|ண்|த்|ந்|ப்|ம்|ய்|ர்|ல்|வ்|ள்|ழ்|ற்|ன்/;

# consonant+'அ' combination
my $CONSONANTS_PLUS_VOWEL_A =
  qr/க|ங|ச|ங|ட|ண|த|ந|ப|ம|ய|ர|ல|வ|ள|ழ|ற|ன/;

# vowel to sign map
my %VOWEL_VOWELSIGN = (
	'ஆ' => 'ா',
	'இ' => 'ி',
	'ஈ' => 'ீ',
	'உ' => 'ு',
	'ஊ' => 'ூ',
	'எ' => 'ெ',
	'ஏ' => 'ே',
	'ஐ' => 'ை',
	'ஒ' => 'ொ',
	'ஓ' => 'ோ',
	'ஔ' => 'ௌ'
);

my $PULLI = '்';

sub combine {
	my ( $left, $right, $ltype, $rtype ) = @_;
	my $combined;

	# internal sandhi (when two morphemes combine)
	$combined = internal_sandhi( $left, $right );

	return $combined;
}

sub internal_sandhi {
	my ( $l, $r ) = @_;
	my $c;

	# noun stems + case suffix (yet to be implemented)

	# more general spelling rules

	# [I]. vowel + vowel
	# ****************

	# (i.e. the ending of the left string is a vowel and
	# the starting of the right string is a vowel)

	# a. "i,ii,ai" + vowel => "i, ii, ai" . y . vowel
	# a. "இ,ஈ,ஐ" + vowel => "இ, ஈ, ஐ" . ய் . vowel
	if ( $l =~ /($VOWELS_I_SIGNS)$/ ) {

		# the right string starts with a vowel but not அ/a
		if ( ( $r =~ /^($VOWELS)/ ) && ( $r !~ /^அ/ ) ) {
			$r =~ /^($VOWELS)/;
			my $v  = $1;
			my $vs = $VOWEL_VOWELSIGN{$v};
			$r =~ s/^$v/$vs/;
			return $l . 'ய' . $r;
		}

		# the right string starts with a vowel sign but not அ/a
		if ( ( $r =~ /^($VOWELS_SIGNS)/ ) && ( $r !~ /^அ/ ) ) {
			return $l . 'ய' . $r;
		}

		# the right string starts with அ/a
		if ( $r =~ /^அ/ ) {
			$r =~ s/^அ//;
			return $l . 'ய' . $r;
		}
	}

	# b. "long vowel" + vowel => "long vowel" . v . vowel
	if ( $l =~ /($LONG_VOWEL_SIGNS_NO_I)$/ ) {

		# the right string starts with a vowel but not அ/a
		if ( ( $r =~ /^($VOWELS)/ ) && ( $r !~ /^அ/ ) ) {
			$r =~ /^($VOWELS)/;
			my $v  = $1;
			my $vs = $VOWEL_VOWELSIGN{$v};
			$r =~ s/^$v/$vs/;
			return $l . 'வ' . $r;
		}

		# the right string starts with a vowel sign but not அ/a
		if ( ( $r =~ /^($VOWELS_SIGNS)/ ) && ( $r !~ /^அ/ ) ) {
			return $l . 'வ' . $r;
		}

		# the right string starts with அ/a
		if ( $r =~ /^அ/ ) {
			$r =~ s/^அ//;
			return $l . 'வ' . $r;
		}
	}

	# c. "u" + vowel => vowel  [aka vowel deletion]
	# c. "உ/ு" + vowel => vowel  [aka vowel deletion]
	if ( $l =~ /ு$/ ) {

		# the right string starts with a vowel but not அ/a
		if ( ( $r =~ /^($VOWELS)/ ) && ( $r !~ /^அ/ ) ) {
			$l =~ s/ு$//;
			$r =~ /^($VOWELS)/;
			my $v  = $1;
			my $vs = $VOWEL_VOWELSIGN{$v};
			$r =~ s/^$v/$vs/;
			return $l . $r;
		}

		# the right string starts with a vowel sign but not அ/a
		if ( ( $r =~ /^($VOWELS_SIGNS)/ ) && ( $r !~ /^அ/ ) ) {
			$l =~ s/ு$//;
			return $l . $r;
		}

		# the right string starts with அ/a
		if ( $r =~ /^அ/ ) {
			$l =~ s/ு$//;
			$r =~ s/^அ//;
			return $l . $r;
		}
	}


	# "அ/a" + vowel 			=> அ/a . v . vowel
	# (1) constant_vowel_a + vowel 	=> constant_vowel_a . v . vowel
	# the first word ends with consonant plus 'a' combination
	if ( $l =~ /($CONSONANTS_PLUS_VOWEL_A)$/ ) {

		# the second word starts with vowel but not அ
		if ( ( $r =~ /^($VOWELS)/ ) && ( $r !~ /^அ/ ) ) {
			$r =~ /^($VOWELS)/;
			my $v  = $1;
			my $vs = $VOWEL_VOWELSIGN{$v};
			$r =~ s/^$v/$vs/;
			return $l . 'வ' . $r;
		}

		# the second word starts with vowel signs
		if ( $r =~ /^($VOWELS_SIGNS)/ ) {
			return $l . $r;
		}

		# the second word starts with அ
		if ( $r =~ /^அ/ ) {
			$r =~ s/^அ//;
			return $l . $r;
		}
	}
	
	# (2) "அ/a" + vowel 			=> அ/a . v . vowel 
	if ( $l =~ /அ$/ ) {

		# the second word starts with vowel but not அ
		if ( ( $r =~ /^($VOWELS)/ ) && ( $r !~ /^அ/ ) ) {
			$r =~ /^($VOWELS)/;
			my $v  = $1;
			my $vs = $VOWEL_VOWELSIGN{$v};
			$r =~ s/^$v/$vs/;
			return $l . 'வ' . $r;
		}

		# the second word starts with vowel signs
		if ( $r =~ /^($VOWELS_SIGNS)/ ) {
			return $l . $r;
		}

		# the second word starts with அ
		if ( $r =~ /^அ/ ) {
			$r =~ s/^அ//;
			return $l . $r;
		}
	}
	
	# [II]. vowel + consonant
	# *********************
	# no rules needed here

	# [III]. consonant + vowel
	# **********************
	# " ்" + vowel (except அ)
	if ( ( $l =~ /$PULLI$/ ) && ( $r =~ /^($VOWELS)/ ) && ( $r !~ /^அ/ ) ) {
		$l =~ s/$PULLI$//;
		$r =~ /^($VOWELS)/;
		my $v  = $1;
		my $vs = $VOWEL_VOWELSIGN{$v};
		$r =~ s/^$v/$vs/;
		return $l . $r;
	}

	# " ்" + அ
	if ( ( $l =~ /$PULLI$/ ) && ( $r =~ /^அ/ ) ) {
		$l =~ s/$PULLI$//;
		$r =~ s/^அ//;
		return $l . $r;
	}

	# " ்" + vowel signs
	if ( ( $l =~ /$PULLI$/ ) && ( $r =~ /^($VOWELS_SIGNS)/ ) ) {
		$l =~ s/$PULLI$//;
		return $l . $r;
	}

	# [IV]. consonant + consonant
	# *************************
	# no rules needed here

	$c = $l . $r;
	return $c;
}

# yet to be implemented
sub external_sandhi {

}

1;

__END__


=encoding UTF-8


=head1 NAME

Treex::Tool::SandhiHandler::Tamil

=head1 SYNOPSIS

my $left = 'தொகை';
my $right = 'ஐ';
my $combined = Treex::Tool::SandhiHandler::Tamil->combine($left, $right);

=head1 DESCRIPTION

This module handles morpho phonological rules for Tamil i.e. changes that occur when two morphemes or two different words are combined. 
In Indian languages context, this phenomenon is widely known as 'Sandhi'. There are two types of Sandhi,

=over 4

=item * internal Sandhi (changes that occur when two morphemes are combined)

=item * external Sandhi (changes that occur when two words are combined) 



At present, only rules involving internal Sandhi is handled (which can handle most of the situations). 
 

=back


=head1 AUTHOR


Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
