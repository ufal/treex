package Treex::Tool::Lexicon::Generation::ES;
use Moose;
use Treex::Core::Common;

my %CONJUGATION = (
    ar => {
        'ind pres' => 'o as a amos áis an',
        'ind imp'  => 'aba abas aba ábamos abais aban',
        'ind past' => 'é aste ó amos asteis aron',
        #'ind pqp'  => '',
        'ind fut'  => 'aré arás ará aremos aréis arán',
        'cond '    => 'aría arías aría aríamos aríais arían',
        'sub pres' => 'e es e emos éis en',
        'sub imp'  => 'ase ases ase ásemos aseis asen',
        'sub fut'  => 'are ares are áremos areis aren',
    },
    er => {
        'ind pres' => 'o es e emos eis en',
        'ind imp'  => 'ía ías ía íamos íais ían',
        'ind past' => 'í iste ió imos isteis ieron',
        #'ind pqp'  => '',
        'ind fut'  => 'eré erás erá eremos eréis erán',
        'cond '    => 'ería erías ería eríamos eríais erían',
        'sub pres' => 'a as a amos áis an',
        'sub imp'  => 'iese ieses iese iésemos ieseis iesen',
        'sub fut'  => 'iere ieres iere iéremos iereis ieren',
    },
    ir => {
        'ind pres' => 'o es e imos ís en',
        'ind imp'  => 'ía ías ía íamos íais ían',
        'ind past' => 'í iste ió imos isteis ieron',
        #'ind pqp'  => '',
        'ind fut'  => 'iré irás irá iremos iréis irán',
        'cond '    => 'iría irías iría iríamos iríais irian',
        'sub pres' => 'a as a amos áis an',
        'sub imp'  => 'iese ieses iese iésemos ieseis iesen',
        'sub fut'  => 'iere ieres iere iéremos iereis ieren',
    },
    verb_ser => {
        'ind pres' => 'soy eres es somos sois son',
        'ind imp'  => 'era eras era éramos erais eran',
        'ind past' => 'fui fuiste fue fuimos fuistes fuiron',
        #'ind pqp'  => '',
        'ind fut'  => 'seré serás será seremos seréis serán',
        'cond '    => 'sería serías sería seríamos seríais serían',
        'sub pres' => 'sea seas sea seamos seáis sean',
        'sub imp'  => 'fuese fueses fuese fuésemos fueseis fuesen',
        'sub fut'  => 'fuere fueres fuere fuéremos fuereis fueren',
    },
    verb_estar => {
        'ind pres' => 'estoy estás está estamos estáis están',
        'ind imp'  => 'estaba estabas estaba estábamos estabais estabam',
        'ind past' => 'estuve estuviste estuvo estuvimos estubviteis estuvieron',
        #'ind pqp'  => '',
        'ind fut'  => 'estaré estarás estará estaremos estaréis estarán',
        'cond '    => 'estaría estarías estaría estaríamos estaríais estarían',
        'sub pres' => 'esté estés esté estemos estéis estén',
        'sub imp'  => 'estuviese estuvieses estuviese estuviesemos estuvieseis estuviesen',
        'sub fut'  => 'estuviere estuvieres estuviere estuvieremos estuviereis estuvieren',
    },
    verb_haber => {
	'ind pres' => 'he has ha hemos habéis han',
        'ind imp'  => 'había habías había habíamos habíais habían',
        'ind past' => 'hube hubiste hubo hubimos hubisteis hubieron',
        #'ind pqp'  => '',
        'ind fut'  => 'habré habrás habrá habremos habréis habrán',
        'cond '    => 'haría habrías habría habríamos habríais habrían',
        'sub pres' => 'haya hayas haya hayamos hayáis hayan',
        'sub imp'  => 'hubiese hubieses hubiese hubiésemos hubieseis hubiesen',
        'sub fut'  => 'hubiere hubieres hubiese hubiéremos hubiereis hubieren',
    },
    verb_tener => {
	'ind pres' => 'tengo tienes tiene tenemos tenéis tienen',
        'ind imp'  => 'tenía tenías tenía teníamos teníais tenían',
        'ind past' => 'tuve tuviste tuvo tuvimos tuvisteis tuvieron',
        #'ind pqp'  => '',
        'ind fut'  => 'tendré tendrás tendrá tendremos tendréis tendrán',
        'cond '    => 'tendría tendrías tendría tendríamos tendríais tendrían',
        'sub pres' => 'tenga tengas tenga tengamos tengáis tengan',
        'sub imp'  => 'tuviese tuvieses tuviese tuviésemos tuvieseis tuviesen',
        'sub fut'  => 'tuviere tuvieres tuviere tuvieremos tuviereis tuvieren',
    },
    verb_ir => {
        'ind pres' => 'voy vas va vamos vais van',
        'ind imp'  => 'iba ibas iba íbamos ibais iban',
        'ind past' => 'fui fuiste fue fuimos fuisteis fueron',
        #'ind pqp'  => '',
        'ind fut'  => 'iré irás irá iremos iréis irán',
        'cond '    => 'iría irías iría iríamos iríais irían',
        'sub pres' => 'vaya vayas vaya vayamos vayáis vayan',
        'sub imp'  => 'fuese fueses fuese fuésemos fueseis fuesen',
        'sub fut'  => 'fuere fueres fuere fuéremos fuereis fueren',
    },
    verb_conocer => {
	'ind pres' => 'conozco conoces conoce conocemos conocéis conocen',
        'ind imp'  => 'conocía conicías conocía conocíamos conocíais conocían',
        'ind past' => 'conocí conociste conoció conocimos conocisteis conocieron',
        #'ind pqp'  => '',
        'ind fut'  => 'conoceré conocerás conocerá conoceremos conoceréis conocerán',
        'cond '    => 'conocería conocerías conocería conoceríamos conoceríais conocerían',
        'sub pres' => 'conozca conozcas conozca conozcamos caonozcáis conozcan',
        'sub imp'  => 'conociese conocieses conociese conociésemos conocieseis conociesen',
        'sub fut'  => 'conociere conocieres coniciere conociéremos conocieseis conocieren',
    }
);



sub best_form_of_lemma {
    my ( $self, $lemma, $iset ) = @_;
    my $pos = $iset->pos;
    if ($pos eq 'verb'){
        my ($stem, $class) = ('', '');

        # check irregular verbs first
        if ($lemma =~ /^(ser|estar|haber|tener|ir|conocer)$/){
            $class = "verb_$lemma";
        } else {
            ($stem, $class) = ($lemma =~ /^(.+)(ar|er|ir)$/);
        }
        return $lemma if !$class;
        my $mood = $iset->mood;
        my $tense = $iset->tense;
        my $person = $iset->person || 3;
        my $forms = $CONJUGATION{$class}{"$mood $tense"};
        return $lemma if !$forms;
        $person += 3 if $iset->number eq 'plu';
        my $ending = (split / /, $forms)[$person - 1];
        return $stem.$ending;
    }
    elsif ($pos =~/noun|adj/){
        if ($iset->degree eq 'sup'){
            $lemma =~ s/[oe]?$/ísimo/;
        }
        if ($pos eq 'adj' && $iset->gender eq 'fem'){
            $lemma =~ s/[oe]?$/a/ if $lemma !~ /a$/;
        }
        if ($iset->number eq 'plu'){
            $lemma =~ s/([aeiou])$/$1s/ or
            $lemma = $lemma.'es';
        }
    }
    return $lemma;
}

1;

__END__

=head1 NAME

Treex::Tool::Lexicon::Generation::ES

=head1 SYNOPSIS

 use Treex::Tool::Lexicon::Generation::ES;
 my $generator = Treex::Tool::Lexicon::Generation::ES->new();

 my $iset = Lingua::Interset::FeatureStructure->new({pos=> 'verb', number=>'sing', mood=>'ind', person=>3, tense=>'pres'});
 print $generator->best_form_of_lemma('gustar', $iset);
 #Should print:
 # gosta

=head1 DESCRIPTION

Draft of Portuguese verbal conjugation (and simple noun+adjective inflection)
based on http://en.wikipedia.org/wiki/Spanish_verb_conjugation.
This is just a placeholder for the real morphological module by LX-Center.

=head1 AUTHORS

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
