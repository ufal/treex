package Treex::Tool::SandhiHandler::TA;
use utf8;
use base 'Exporter';
use Treex::Core::Common;
use Treex::Tool::Orthography::TA;
use charnames ':full';

our @EXPORT_OK = ('combine');


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
	if ( $l =~ /($TA_VOWEL_I_SIGNS_REG)$/ ) {

		# the right string starts with a vowel but not அ/a
		if ( ( $r =~ /^($TA_VOWELS_REG)/ ) && ( $r !~ /^அ/ ) ) {
			$r =~ /^($TA_VOWELS_REG)/;
			my $v  = $1;
			my $vs = $TA_VOWEL_VOWELSIGN_MAP{$v};
			$r =~ s/^$v/$vs/;
			return $l . 'ய' . $r;
		}

		# the right string starts with a vowel sign but not அ/a
		if ( ( $r =~ /^($TA_VOWEL_SIGNS_REG)/ ) && ( $r !~ /^அ/ ) ) {
			return $l . 'ய' . $r;
		}

		# the right string starts with அ/a
		if ( $r =~ /^அ/ ) {
			$r =~ s/^அ//;
			return $l . 'ய' . $r;
		}
	}

	# b. "long vowel" + vowel => "long vowel" . v . vowel
	if ( $l =~ /($TA_LONG_VOWEL_SIGNS_NO_I_REG)$/ ) {

		# the right string starts with a vowel but not அ/a
		if ( ( $r =~ /^($TA_VOWELS_REG)/ ) && ( $r !~ /^அ/ ) ) {
			$r =~ /^($TA_VOWELS_REG)/;
			my $v  = $1;
			my $vs = $TA_VOWEL_VOWELSIGN_MAP{$v};
			$r =~ s/^$v/$vs/;
			return $l . 'வ' . $r;
		}

		# the right string starts with a vowel sign but not அ/a
		if ( ( $r =~ /^($TA_VOWEL_SIGNS_REG)/ ) && ( $r !~ /^அ/ ) ) {
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
		if ( ( $r =~ /^($TA_VOWELS_REG)/ ) && ( $r !~ /^அ/ ) ) {
			$l =~ s/ு$//;
			$r =~ /^($TA_VOWELS_REG)/;
			my $v  = $1;
			my $vs = $TA_VOWEL_VOWELSIGN_MAP{$v};
			$r =~ s/^$v/$vs/;
			return $l . $r;
		}

		# the right string starts with a vowel sign but not அ/a
		if ( ( $r =~ /^($TA_VOWEL_SIGNS_REG)/ ) && ( $r !~ /^அ/ ) ) {
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
	if ( $l =~ /($TA_CONSONANTS_PLUS_VOWEL_A_REG)$/ ) {

		# the second word starts with vowel but not அ
		if ( ( $r =~ /^($TA_VOWELS_REG)/ ) && ( $r !~ /^அ/ ) ) {
			$r =~ /^($TA_VOWELS_REG)/;
			my $v  = $1;
			my $vs = $TA_VOWEL_VOWELSIGN_MAP{$v};
			$r =~ s/^$v/$vs/;
			return $l . 'வ' . $r;
		}

		# the second word starts with vowel signs
		if ( $r =~ /^($TA_VOWEL_SIGNS_REG)/ ) {
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
		if ( ( $r =~ /^($TA_VOWELS_REG)/ ) && ( $r !~ /^அ/ ) ) {
			$r =~ /^($TA_VOWELS_REG)/;
			my $v  = $1;
			my $vs = $TA_VOWEL_VOWELSIGN_MAP{$v};
			$r =~ s/^$v/$vs/;
			return $l . 'வ' . $r;
		}

		# the second word starts with vowel signs
		if ( $r =~ /^($TA_VOWEL_SIGNS_REG)/ ) {
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
	# vowel + (k|c|t|p) => vowel . (kk|cc|tt|pp)
	if ( ( $l =~ /($TA_HARD_A_REG|\N{TAMIL LETTER YA})($TA_PULLI?|$TA_VOWEL_SIGNS_NO_U_REG)$/ ) && ( $r =~ /^($TA_HARD_A_REG)/ ) ) {
		$r =~ /^($TA_HARD_A_REG)/;
		my $v  = $1;
		my $dv = $v . "\N{TAMIL SIGN VIRAMA}" . $v;
		$r =~ s/^$v/$dv/;
		return $l . $r;
	}

	# [III]. consonant + vowel
	# **********************
	# " ்" + vowel (except அ)
	if ( ( $l =~ /$TA_PULLI$/ ) && ( $r =~ /^($TA_VOWELS_REG)/ ) && ( $r !~ /^அ/ ) ) {
		$l =~ s/$TA_PULLI$//;
		$r =~ /^($TA_VOWELS_REG)/;
		my $v  = $1;
		my $vs = $TA_VOWEL_VOWELSIGN_MAP{$v};
		$r =~ s/^$v/$vs/;
		return $l . $r;
	}

	# " ்" + அ
	if ( ( $l =~ /$TA_PULLI$/ ) && ( $r =~ /^அ/ ) ) {
		$l =~ s/$TA_PULLI$//;
		$r =~ s/^அ//;
		return $l . $r;
	}

	# " ்" + vowel signs
	if ( ( $l =~ /$TA_PULLI$/ ) && ( $r =~ /^($TA_VOWEL_SIGNS_REG)/ ) ) {
		$l =~ s/$TA_PULLI$//;
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

Treex::Tool::SandhiHandler::TA

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
