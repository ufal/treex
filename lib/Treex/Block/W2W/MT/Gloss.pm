package Treex::Block::W2W::MT::Gloss;

use strict;
use warnings;
use utf8;
use Moose;
use Treex::Core::Common;
extends 'Treex::Core::Block';



has 'glossary' => ( is => 'ro', isa => 'HashRef', builder => '_build_glossary', lazy => 1 );



#------------------------------------------------------------------------------
# Adds English glosses to some frequent Maltese words. Helps understand Maltese
# trees in Tred.
#------------------------------------------------------------------------------
sub process_anode
{
    my $self = shift;
    my $node = shift;
    my $gloss = $self->get_gloss($node);
    $node->set_gloss($gloss);
    ###!!! Ve Windows v Tredu 2.5049 glosy nevidím. U stejného souboru v Ubuntu v Tredu 2.4984 je vidím. Jak to?
}



#------------------------------------------------------------------------------
# Attempts to find an English gloss for a Maltese word (node).
#------------------------------------------------------------------------------
sub get_gloss
{
    my $self = shift;
    my $node = shift;
    my $glossary = $self->glossary();
    my $original = $node->form();
    return undef unless(defined($original));
    $original = lc($original);
    if(exists($glossary->{$original}))
    {
        #log_info("$original\t$gloss{$original}");
        return $glossary->{$original};
    }
    return undef;
}



#------------------------------------------------------------------------------
# Builds the mt-en glossary.
#------------------------------------------------------------------------------
_build_glossary
{
    my %gloss =
    (
        #------------------------------------------------------------
        # Nouns
        'dar'   => 'house',
        'daqs'  => 'size',
        'Ħadd'  => 'Sunday',
        'ħajja' => 'life',
        'ħbieb' => 'friends',
        'ħidma' => 'work',
        'ħin'   => 'time',
        'lewn'  => 'color',
        'ommijiet' => 'mothers',
        'qasam' => 'area',
        'sajf'  => 'summer',
        'sena'  => 'year',
        'Sibt'  => 'Saturday',
        'siegħa' => 'hours',
        'tfal'  => 'children',
        'tmiem' => 'end',
        'uġigħ' => 'pain',
        'xahar' => 'month',
        'xhur'  => 'months',
        'żgħażagħ' => 'young',
        'żmien' => 'time',
        #------------------------------------------------------------
        # Adjectives
        'aħħar'  => 'last',
        'aħjar'  => 'better',
        'akbar'  => 'big',
        'ġdid'   => 'new',
        'ġdida'  => 'new',
        'ġodda'  => 'new',
        'ieħor'  => 'other',
        'istess' => 'same',
        'iżjed'  => 'more',
        'kbar'   => 'big',
        'kmieni' => 'early',
        'oħra'   => 'other',
        'oħrajn' => 'other',
        'tajba'  => 'good',
        #------------------------------------------------------------
        # Pronouns
        'aħna'    => 'we',
        'bejniethom' => 'between-them',
        'bejnietna' => 'between-us',
        'fosthom' => 'including-them',
        'hi'      => 'she',
        'hu'      => 'he',
        'huma'    => 'they',
        'ħaddieħor' => 'others',
        'int'     => 'you.Sing',
        'inti'    => 'you.Sing',
        'jiena'   => 'I',
        'kollox'  => 'everything',
        'magħhom' => 'with-them',
        'magħkom' => 'with-you',
        'min'     => 'who',
        'ruħa'    => 'itself',
        'ruħhom'  => 'themselves',
        'tagħhom' => 'their',
        'tagħna'  => 'our',
        'tiegħu'  => 'his',
        'xejn'    => 'nothing',
        #------------------------------------------------------------
        # Articles
        'id-'  => 'the',
        'il-'  => 'the',
        'ir-'  => 'the',
        'is-'  => 'the',
        'it-'  => 'the',
        'iż-'  => 'the',
        'd-'   => 'the',
        'l-'   => 'the',
        'n-'   => 'the',
        'r-'   => 'the',
        's-'   => 'the',
        't-'   => 'the',
        'x-'   => 'the',
        #------------------------------------------------------------
        # Demonstratives
        'dak'  => 'that',
        'dan'  => 'this',
        'dawk' => 'those',
        'dawn' => 'these',
        'dik'  => 'that',
        'din'  => 'this',
        #------------------------------------------------------------
        # Quantifiers
        'aktar'  => 'more',
        'ftit'   => 'few/little',
        'ħafna'  => 'many/much',
        'iktar'  => 'more',
        'kemm'   => 'how-much',
        'kollha' => 'all',
        'kollu'  => 'all',
        'kull'   => 'all',
        # Numerals
        'wieħed' => 'one', # used also as an impersonal pronoun
        #------------------------------------------------------------
        # Verbs
        'beda'   => 'started',
        'bdiet'  => 'started',
        'għalaq' => 'closed',
        'għandhom' => 'at-them/they-have',
        'għandu' => 'at-him/he-has',
        'jagħmel' => 'he-makes',
        'jagħti' => 'he-gives',
        'jagħtu' => 'they-give',
        'jgħid'  => 'he-says',
        'jgħidu' => 'they-say',
        'jgħinu' => 'help',
        'jibda'  => 'he-starts',
        "jista'" => 'can',
        'jistgħu' => 'can',
        'kien'   => 'he-was',
        'kienet' => 'she-was',
        'kienu'  => 'they-were',
        'konna'  => 'we-were',
        'kont'   => 'I-was/you-were',
        'kontu'  => 'you-were',
        'ssir'   => 'become',
        'tfisser' => 'means',
        'tgħid'  => 'says',
        'tibda'  => 'starts',
        "tibda'" => 'starts',
        "tista'" => 'can',
        'twassal' => 'leads',
        #------------------------------------------------------------
        # Adverbs
        'allura' => 'then',
        'anki'  => 'even',
        'bħala' => 'as',
        'bħalissa' => 'currently',
        'biss'  => 'only',
        'fejn'  => 'where',
        'flimkien' => 'together',
        'għaldaqstant' => 'therefore',
        'għalhekk' => 'therefore',
        'għaliex'  => 'why/because',
        'hekk'  => 'so',
        'hemm'  => 'there',
        'ilbieraħ' => 'yesterday',
        'imbagħad' => 'then',
        'issa'  => 'now',
        'kif'   => 'how',
        'madanakollu' => 'however',
        'meta'  => 'when',
        'qabel' => 'before',
        'tard'  => 'late',
        'ukoll' => 'also',
        'wkoll' => 'also',
        #------------------------------------------------------------
        # Prepositions
        "b'"     => 'with',
        'bejn'   => 'between',
        'bħal'   => 'like/such',
        'bħat-'  => 'like/such',
        'bil-'   => 'with',
        'bis-'   => 'with',
        'bl-'    => 'with',
        'bla'    => 'without',
        'dwar'   => 'about',
        "f'"     => 'in',
        'fi'     => 'in',
        'fid-'   => 'in',
        'fil'    => 'in',
        'fil-'   => 'in',
        'fir-'   => 'in',
        'fis-'   => 'in',
        'fit-'   => 'in',
        'fix-'   => 'in',
        'fl-'    => 'in',
        'fuq'    => 'over',
        'għaċ-'  => 'for',
        'għal'   => 'for',
        'għalihom' => 'to',
        'għall-' => 'for',
        'għat-'  => 'for',
        'lejn'   => 'toward',
        'lil'    => 'to',
        'lill-'  => 'to',
        'lit'    => 'to',
        'lit-'   => 'to',
        "ma'"    => 'with',
        'maċ-'   => 'with',
        'madwar' => 'around',
        'mal'    => 'with',
        'mal-'   => 'with',
        'matul'  => 'during',
        'mill'   => 'from',
        'mill-'  => 'from',
        'minn'   => 'from',
        'mis-'   => 'from',
        'mit-'   => 'from',
        'quddiem' => 'before',
        'sa'     => 'by',
        'sal-'   => 'by',
        "t'"     => 'of',
        "ta'"    => 'of',
        'taċ-'   => 'of',
        'tad-'   => 'of',
        'taħt'   => 'under',
        'tal'    => 'of',
        'tal-'   => 'of',
        'tar-'   => 'of',
        'tas-'   => 'of',
        'tat'    => 'of',
        'tat-'   => 'of',
        'tul'    => 'by',
        'waqt'   => 'while',
        'wara'   => 'after',
        #------------------------------------------------------------
        # Conjunctions
        'biex'   => 'that',
        'billi'  => 'by',
        'imma'   => 'but',
        'iżda'   => 'but',
        'jekk'   => 'if',
        'jew'    => 'or',
        'li'     => 'that',
        'sabiex' => 'that',
        'sakemm' => 'until',
        'u'      => 'and',
        #------------------------------------------------------------
        # Particles
        'mhuwiex' => 'not',
        'mhux'   => 'not',
        'se'     => 'will',
        'ser'    => 'will',
    );
    return \%gloss;
}



1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2W::MT::Gloss

=head1 DESCRIPTION

Adds English glosses to some frequent Maltese words. Helps understand Maltese
trees in Tred.

=head1 AUTHOR

Dan Zeman <zeman@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
