package Treex::Tool::Lexicon::Generation::ES;
use Moose;
use Treex::Core::Common;

my %CONJUGATION = (
    ar => {
        'ind pres' => 'o as a amos áis an',
        'ind imp'  => 'aba abas aba ábamos abais aban',
        'ind past' => 'é aste ó amos asteis aron',
        'ind fut'  => 'aré arás ará aremos aréis arán',
        'cnd '     => 'aría arías aría aríamos aríais arían',
        'sub pres' => 'e es e emos éis en',
        'sub imp'  => 'ase ases ase ásemos aseis asen',
        'sub fut'  => 'are ares are áremos areis aren',
        'imp '     => '- a e emos ad en',
    },
    er => {
        'ind pres' => 'o es e emos éis en',
        'ind imp'  => 'ía ías ía íamos íais ían',
        'ind past' => 'í iste ió imos isteis ieron',
        'ind fut'  => 'eré erás erá eremos eréis erán',
        'cnd '     => 'ería erías ería eríamos eríais erían',
        'sub pres' => 'a as a amos áis an',
        'sub imp'  => 'iese ieses iese iésemos ieseis iesen',
        'sub fut'  => 'iere ieres iere iéremos iereis ieren',
        'imp '     => '- e a amos ed an',
    },
    ir => {
        'ind pres' => 'o es e imos ís en',
        'ind imp'  => 'ía ías ía íamos íais ían',
        'ind past' => 'í iste ió imos isteis ieron',
        'ind fut'  => 'iré irás irá iremos iréis irán',
        'cnd '     => 'iría irías iría iríamos iríais irian',
        'sub pres' => 'a as a amos áis an',
        'sub imp'  => 'iese ieses iese iésemos ieseis iesen',
        'sub fut'  => 'iere ieres iere iéremos iereis ieren',
        'imp '     => '- e a amos id an',
    },
    verb_conocer => {
        'ind pres' => 'conozco',
        'sub pres' => 'conozca conozcas conozca conozcamos conozcáis conozcan',
        'imp '     => '- conoce conozca conozcamos conoced conozcan',
    },
    verb_conseguir => {
        'ind pres' => 'consigo consigues consigue . . consiguen',
        'ind past' => '. . consiguió . . consiguieron',
        'sub pres' => 'consiga consigas consiga consigamos consigáis consigan',
        'sub fut'  => 'consigiere consigieres consigiere consigiéremos consigiereis consigieren',
        'imp '     => '- consigue consiga consigamos . consigan',
    },

    verb_estar => {
        'ind pres' => 'estoy estás está estamos estáis están',
        'ind past' => 'estuve estuviste estuvo estuvimos estubviteis estuvieron',
        'sub pres' => 'esté estés esté estemos estéis estén',
        'sub imp'  => 'estuviese estuvieses estuviese estuviesemos estuvieseis estuviesen',
        'sub fut'  => 'estuviere estuvieres estuviere estuvieremos estuviereis estuvieren',
        'imp '     => '- está esté estemos estad estén',
    },
    verb_haber => {
        'ind pres' => 'he has ha hemos habéis han',
        'ind imp'  => 'había habías había habíamos habíais habían',
        'ind past' => 'hube hubiste hubo hubimos hubisteis hubieron',
        'ind fut'  => 'habré habrás habrá habremos habréis habrán',
        'cnd '     => 'habría habrías habría habríamos habríais habrían',        
        'sub pres' => 'haga hagas haga hagamos hagáis hagan',
        'sub imp'  => 'hiciera hicieras hiciera hiciéramos hicierais hicieran',
        'sub fut'  => 'hiciere hicieres hiciere hiciéremos hiciereis hicieren',
        'imp '     => '- * haya hayamos * hayan',
    },
    verb_hacer => {
        'ind pres' => 'hago',
        'ind past' => 'hice hiciste hizo hicimos hicisteis hicieron',
        'ind fut'  => 'haré harás hará haremos haréis harán',
        'cnd '     => 'haría harías haría haríamos haríais harían',
        'sub pres' => 'haya hayas haya hayamos hayáis hayan',
        'sub imp'  => 'hubiese hubieses hubiese hubiésemos hubieseis hubiesen',
        'sub fut'  => 'hubiere hubieres hubiese hubiéremos hubiereis hubieren',
        'imp '     => '- haz haga hagamos haced hagan',
    },
    verb_ir => {
        'ind pres' => 'voy vas va vamos vais van',
        'ind imp'  => 'iba ibas iba íbamos ibais iban',
        'ind past' => 'fui fuiste fue fuimos fuisteis fueron',
        'ind fut'  => 'iré irás irá iremos iréis irán',
        'cnd '     => 'iría irías iría iríamos iríais irían',
        'sub pres' => 'vaya vayas vaya vayamos vayáis vayan',
        'sub imp'  => 'fuese fueses fuese fuésemos fueseis fuesen',
        'sub fut'  => 'fuere fueres fuere fuéremos fuereis fueren',
        'imp '     => '- ve vaya vayamos id vayan',
    },
    verb_poder => {
        'ind pres' => 'puedo puedes puede podemos podéis pueden',
        'ind past' => 'pude pudiste pudo pudimos pudisteis pudieron',
        'ind fut'  => 'podré podrás podrá podremos podréis podrán',
        'cnd '     => 'podría podrías podría podríamos podríais rían',
        'sub pres' => 'pueda puedas pueda podamos podáis puedan',
        'sub imp'  => 'pudiera pudieras pudiera pudiéramos pudierais pudieran',
        'sub fut'  => 'pudiere pudieres pudiere pudiéremos pudiereis pudieren',
        'imp '     => '- puede pueda podamos poded puedan',
    },
    verb_ser => {
        'ind pres' => 'soy eres es somos sois son',
        'ind imp'  => 'era eras era éramos erais eran',
        'ind past' => 'fui fuiste fue fuimos fuistes fuiron',
        'sub pres' => 'sea seas sea seamos seáis sean',
        'sub imp'  => 'fuese fueses fuese fuésemos fueseis fuesen',
        'sub fut'  => 'fuere fueres fuere fuéremos fuereis fueren',
        'imp '     => '- sé sea seamos sed sean',
    },
    verb_tener => {
        'ind pres' => 'tengo tienes tiene tenemos tenéis tienen',
        'ind past' => 'tuve tuviste tuvo tuvimos tuvisteis tuvieron',
        'ind fut'  => 'tendré tendrás tendrá tendremos tendréis tendrán',
        'cnd '     => 'tendría tendrías tendría tendríamos tendríais tendrían',
        'sub pres' => 'tenga tengas tenga tengamos tengáis tengan',
        'sub imp'  => 'tuviese tuvieses tuviese tuviésemos tuvieseis tuviesen',
        'sub fut'  => 'tuviere tuvieres tuviere tuvieremos tuviereis tuvieren',
        'imp '     => '- ten tenga tengamos tened tengan',
    },
    verb_venir => {
        'ind pres' => 'vengo vienes viene venimos venís vienen',
        'ind past' => 'vine viniste vino vinimos vinisteis vinieron',
        'ind fut'  => 'vendré vendrás vendrá vendremos vendréis vendrán',
        'cnd '     => 'vendría vendrías vendría vendríamos vendríais vendrían',
        'sub pres' => 'venga vengas venga vengamos vengáis vengan',
        'sub imp'  => 'viniese vinieses viniese viniésemos vinieseis viniesen',
        'sub fut'  => 'viniere vinieres viniere viniéremos viniereis vinieren',
        'imp '     => '- ven vanga vengamos venid vengan',
    },
);

my @IRREGULAR_VERBS = map {/^verb_(.+)/ ? $1 : ()} keys %CONJUGATION;

my @DIPHTHONGIZING_VERBS = qw(comprobar encontrar mostrar querer);

sub best_form_of_lemma {
    my ( $self, $lemma, $iset ) = @_;
    return $lemma if !$self->should_inflect($lemma, $iset);
    my $pos = $iset->pos;
    if ($pos eq 'verb'){
        return $lemma if $iset->is_infinitive;
        my ($stem, $class) = ('', '');

        # check irregular verbs first
        if (any {$lemma eq $_} @IRREGULAR_VERBS){
            $class = "verb_$lemma";
        } else {
            ($stem, $class) = ($lemma =~ /^(.*)(ar|er|ir)$/);
        }
        return $lemma if !$class;
        my $mood = $iset->mood;
        my $tense = $iset->tense;
        my $person = $iset->person || 3;
        $tense = '' if $mood =~ /imp|cnd/; # tense is irrelevant for imperative and conditional in Spanish
        my $forms = $CONJUGATION{$class}{"$mood $tense"} || '';
        $person += 3 if $iset->number eq 'plur';
        my $ending = (split / /, $forms)[$person - 1];
        
        # Regular forms of irregular verbs do not need to be specified
        if ((!$ending || $ending eq '.') && $class =~ /^verb/){
            ($stem, $class) = ($lemma =~ /^(.*)(ar|er|ir)$/);
            $forms = $CONJUGATION{$class}{"$mood $tense"} || '';
            $ending = (split / /, $forms)[$person - 1];
        }
        return $lemma if !$ending;
        
        # Diphthongization
        # In stems of some verbs, "e"=>"ie" and "o"=>"ue",
        # but only in imperative, present indicative and present subjunctive.
        # First and second person in plural is regular.
        # The change takes place only in the last syllable of the stem.
        # E.g. comprobar => {
        #  'ind pres' => 'compruebo compruebas comprueba . . comprueban',
        #  'sub pres' => 'compruebe compruebes compruebe . . comprueben',
        #  'imp '     => '-         comprueba  compruebe . . comprueben', }
        # Note that there are other kinds of diphthongization in Spanish
        # which still need to be handled via @IRREGULAR_VERBS.
        if ((any {$_ eq $lemma} @DIPHTHONGIZING_VERBS)
           && ($mood eq 'imp' || ($mood =~ /ind|sub/ && $tense eq 'pres'))
           && ($person ne '4' && $person ne '5')
        ){
            $stem =~ s/e([^aeiou]{1,3})$/ie$1/ or
            $stem =~ s/o([^aeiou]{1,3})$/ue$1/;
        }
        
        # Spanish orthographical changes
        if ($ending =~ /^[eéi]/ && $lemma =~ /([czg]|gu)ar$/){
            $stem =~ s/c$/qu/ or
            $stem =~ s/z$/c/ or
            $stem =~ s/g$/gu/ or
            $stem =~ s/gu$/gü/;
        }
        elsif ($ending =~ /^[aáo]/ && $lemma =~ /([cg]|qu)[ei]r$/){
            $stem =~ s/qu$/c/ or
            $stem =~ s/c$/z/ or
            $stem =~ s/g$/j/;
        }
        
        return $stem.$ending;
    }
    elsif ($pos =~/noun|adj/){
        if ($iset->degree eq 'sup'){
            $lemma =~ s/[oe]?$/ísimo/;
        }
        if ($pos eq 'adj' && $self->should_adjective_end_with_a($lemma, $iset)){
            $lemma =~ s/[oe]?$/a/ if $lemma !~ /a$/;
        }
        if ($iset->number eq 'plur'){
            $lemma =~ s/([aeiouú])$/$1s/ or $lemma =~ /s$/ or $lemma .= 'es';
            $lemma =~ s/ó(n[ea]s)$/o$1/;
            $lemma =~ s/í(n[ea]s)$/i$1/;
            $lemma =~ s/^(est?)es$/$1os/;
            $lemma =~ s/zes$/ces/;
            $lemma =~ s/^driveres$/drivers/;
        }
    }
    return $lemma;
}

sub should_adjective_end_with_a{
    my ( $self, $lemma, $iset ) = @_;
    return 0 if $iset->gender ne 'fem';
    return 0 if $iset->is_possessive; # possessive pronouns (mi, tu, su)
    return 0 if $lemma =~ /erior$/;
    return 1 if $lemma =~ /(or|ón|ín|^est?e)$/;
    return 0 if $lemma =~ /[lrne]$/; # add other consonants?
    return 1;
}

sub should_inflect {
    my ( $self, $lemma, $iset ) = @_;
    return 0 if any {$lemma eq $_} qw(wifi web ip se que caché);
    return 1;
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

Copyright © 2014-2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
