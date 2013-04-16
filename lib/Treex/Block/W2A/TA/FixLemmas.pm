package Treex::Block::W2A::TA::FixLemmas;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Orthography::TA;
extends 'Treex::Core::Block';

sub process_document {
	my ( $self, $document ) = @_;
	my @bundles = $document->get_bundles();
	for ( my $i = 0 ; $i < @bundles ; ++$i ) {
		my $atree =
		  $bundles[$i]->get_zone( $self->language, $self->selector )
		  ->get_atree();
		my @nodes = $atree->get_descendants( { ordered => 1 } );
		my @forms = map{$_->form}@nodes;
		my @lemmas = map{$_->lemma}@nodes;			
		my @fixed_lemmas = $self->fix_lemmas(\@forms, \@lemmas);
		map{$nodes[$_]->set_attr('lemma', $fixed_lemmas[$_])}0..$#lemmas;
	}
}

sub fix_lemmas {
	my ($self, $forms_ref, $lemmas_ref) = @_;
	my @f = @{$forms_ref};
	my @l = @{$lemmas_ref};
	my @nl = @l;
	foreach my $i (0..$#f) {		
		
		# FALSE POSITIVES
		# ===============

		# noun+acc
		$nl[$i] = $f[$i] if $f[$i] =~ /ிக்கை$/;
		$nl[$i] = $f[$i] if $l[$i] =~ /ல்ல்$/;
		$nl[$i] = $f[$i] if (($f[$i] eq 'வேதனை') && ($l[$i] eq 'வேதன்'));
		$nl[$i] = $f[$i] if (($f[$i] eq 'தொகை') && ($l[$i] eq 'தொகு'));
		
		# noun + dative
		if ($f[$i] =~ /^($TA_CONSONANTS_PLUS_VOWEL_A_REG)த்துக்கு/) {
			$nl[$i] = $f[$i];
			$nl[$i] =~ s/க்கு$//;
		}
		$nl[$i] = $f[$i] if (($f[$i] =~ /கணக்கு(க்|ச்|த்|ப்)/) && ($l[$i] eq 'கண'));				
		$nl[$i] = $f[$i] if (($f[$i] =~ /க்கு(க்|ச்|த்|ப்)/) && ($l[$i] =~ /$TA_LONG_VOWEL_SIGNS_NO_I_REG$/)  );
		
		# noun + locative
		$nl[$i] = 'எண்' if (($f[$i] =~ /(ில்)$/) && ($l[$i] eq 'எண்ண்'));
		 
		# instrumental is misunderstood as conditional
		$nl[$i] = $f[$i] if $f[$i] =~ /($TA_CONSONANTS_PLUS_VOWEL_A_REG)த்தால்$/;
		$nl[$i] = $f[$i] if $f[$i] eq 'ஆனால்';
		
		# adjectival participles
		$nl[$i] = $f[$i] if (($f[$i] eq 'கடந்த') && ($l[$i] eq 'கட'));
		$nl[$i] = $f[$i] if (($f[$i] =~ /(அ|இ|எ)/) && ($l[$i] =~ /^(அ|இ|எ)$/));
		
		# infinitives
		$nl[$i] = $f[$i] if $f[$i] eq 'தொடக்க';
		

		# OTHERS
		# ======
		
		# plural suffix not removed
		$nl[$i] =~ s/(க்கள்|கள்)// if ($f[$i] =~ /ின்/);
		$nl[$i] =~ s/(க்கள|கள)(ு)// if ($f[$i] =~ /க்கு/);		
		
		# irregulars
		$nl[$i] = 'காண்' if $f[$i] =~ /^(கண்டது)$/;		
				
	}	
	return @nl;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2A::TA::FixLemmas - Fixes Incorrect Lemmatization of Word Forms

=head1 AUTHOR

Loganathan Ramasamy <ramasamy@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2013 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.