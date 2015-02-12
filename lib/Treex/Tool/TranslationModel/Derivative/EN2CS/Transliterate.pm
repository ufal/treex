package Treex::Tool::TranslationModel::Derivative::EN2CS::Transliterate;
use Treex::Core::Common;
use utf8;
use Class::Std;
use Treex::Tool::Lexicon::Generation::CS;
use Treex::Tool::LM::MorphoLM;

my %RULES = (
    sh      => 'š',
    ts      => 'c',
    tch     => 'č',
    shch    => 'šč',
    zh      => 'ž',
    kh      => 'ch',
    yu      => 'ju',
    ya      => 'ja',
    ch      => 'č',
    '[iy]$' => 'ij',     # Georgi -> Georgij, Jury -> Jurij
);

use base qw(Treex::Tool::TranslationModel::Derivative::Common);

sub get_translations {
    my ( $self, $en_lemma, $features_array_rf ) = @_;
    my ($ne_type_feature) = grep {/^ne_type/} @{$features_array_rf};
    return if !$ne_type_feature;

    # Some transliteration/transcription rules are risky,
    # so try all rules (almost) independently.
    my @lemmas = ($en_lemma);
    while ( my ( $from, $to ) = each %RULES ) {
        push @lemmas, map {
            $a = $_;
            $a =~ s/$from/$to/eg;
            $a eq $_ ? () : $a
        } @lemmas;
    }

    # remove the original $en_lemma
    shift @lemmas;

    # remove lemmas which cannot be confirmed by Czech morphology nor SYN corpus
    my $S = 'Derivative::EN2CS::Transliterate';
    return map {
        my $pos = czech_pos($_);
        $pos ? { label => "$_#$pos", source => $S, prob => 0.1 } : ();
    } @lemmas;
}

# will be initialized on first use in czech_pos()
my $morphoLM;
my $generator;

sub czech_pos {
    my ($lemma) = @_;
    $morphoLM = Treex::Tool::LM::MorphoLM->new() if ( !$morphoLM );
    $generator = Treex::Tool::Lexicon::Generation::CS->new() if ( !$generator );

    #HACK: because of lowercased translation dictionaries
    $lemma = ucfirst $lemma;

    # First, try morphological language model based on SYN corpus
    my ($first_form) = $morphoLM->forms_of_lemma($lemma);

    # Hajic's morphology serves as a backoff
    if ( !$first_form ) {
        ($first_form) = $generator->forms_of_lemma($lemma);
    }
    return undef if !$first_form;
    return substr( $first_form->get_tag(), 0, 1 );
}

1;

__END__

=encoding utf8

=head1 NAME

TranslationModel::Derivative::EN2CS::Transliterate


=head1 DESCRIPTION

Named entities (personal names, geographic names,...) written originally
in Cyrillic (e.g. Russian) are usually transliterated (I<romanized>)
or transcribed when used in a Latin Alphabet language.
However, English uses mostly BGN/PCGN romanization system, whereas
Czech uses mostly ISO 9:1995 (ČSN ISO 9). 
If we are sure that a given word was originally Cyrillic (C<ru>),
we can use following table to translate from BGN/PCGN (C<en>)
to ISO 9 transliteration (C<cs-lit>)
or traditional Czech transription (C<cs-transcription>).

 ru   en         cs-lit   cs-transcription
 е  → ye       → e      → je | ě
 ё  → yo       → ё      → jo | ˘o
 ж  → zh       → ž
 ц  → ts       → c
 ч  → ch | tch → č
 х  → kh | h   → h      → ch
 ш  → sh       → š
 щ  → shch     → ŝ      → šč | št
 ю  → yu       → û      → ju | ˘u
 я  → ya       → â      → ja | ˘a

=head1 COPYRIGHT

Copyright 2010 Martin Popel
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README
