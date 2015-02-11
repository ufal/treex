package Treex::Tool::Lexicon::Derivations::CS;
use Treex::Core::Common;
use utf8;

binmode STDOUT, ":utf8";
use Treex::Tool::LM::MorphoLM;

my $morphoLM;    # will be loaded upon first use (see adj2adv and verb2adj)

# too much of code multiplication, should be rewritten in a more elegant fashion

#TODO: Better way how to make it automatically download.
my $NOUN2ADJ_FN       = 'data/models/lexicon/cs/derivations/extracted_noun2ajd_lowercased_utf8.lex';
my $VERB2NOUN_FN      = 'data/models/lexicon/cs/derivations/extracted_verb2deverbalnoun_lowercased_utf8.lex';
my $VERB2ACTIVEADJ_FN = 'data/models/lexicon/cs/derivations/extracted_verb2activeadj_utf8.lex';
my $VERB2ADJ_FN       = 'data/models/lexicon/cs/derivations/extracted_verb2adj_utf8.lex';
my $PERF2IMPERF_FN    = 'data/models/lexicon/cs/derivations/extracted_perf2imperf_utf8.lex';
my $IMPERF2PERF_FN    = 'data/models/lexicon/cs/derivations/extracted_imperf2perf_utf8.lex';

use Treex::Core::Resource;

my %pregenerated_pairs_filename = (
    noun2adj       => Treex::Core::Resource::require_file_from_share( $NOUN2ADJ_FN,       'Lexicon::Derivations::CS' ),
    verb2noun      => Treex::Core::Resource::require_file_from_share( $VERB2NOUN_FN,      'Lexicon::Derivations::CS' ),
    verb2activeadj => Treex::Core::Resource::require_file_from_share( $VERB2ACTIVEADJ_FN, 'Lexicon::Derivations::CS' ),
    verb2adj       => Treex::Core::Resource::require_file_from_share( $VERB2ADJ_FN,       'Lexicon::Derivations::CS' ),
    perf2imperf    => Treex::Core::Resource::require_file_from_share( $PERF2IMPERF_FN,    'Lexicon::Derivations::CS' ),
    imperf2perf    => Treex::Core::Resource::require_file_from_share( $IMPERF2PERF_FN,    'Lexicon::Derivations::CS' ),
);

my %derivation;
foreach my $type ( keys %pregenerated_pairs_filename ) {
    open my $I, "<:encoding(utf-8)", $pregenerated_pairs_filename{$type} or die $!;
    while (<$I>) {
        chomp;
        my ( $input, $output ) = split /\t/;
        next if !defined $input || !defined $output;
        $derivation{$type}{$input}{$output} = 1;
    }
}

sub adj2adv {
    my $adj_tlemma = shift;
    $morphoLM = Treex::Tool::LM::MorphoLM->new() if ( !$morphoLM );

    if ((   $adj_tlemma    =~ s/([sc]k)ý$/$1y/
            or $adj_tlemma =~ s/([ntv])[íý]$/$1ě/
            or $adj_tlemma =~ s/chý$/še/
            or $adj_tlemma =~ s/hý$/ze/
            or $adj_tlemma =~ s/lý$/le/
            or $adj_tlemma =~ s/rý$/ře/
        )
        and $morphoLM->forms_of_lemma( $adj_tlemma, { tag_regex => '^D' } )
        )
    {
        return ($adj_tlemma);
    }
    else {
        return ();
    }
}

sub verb2adj {
    my $verb_tlemma = shift;
    $morphoLM = Treex::Tool::LM::MorphoLM->new() if ( !$morphoLM );

    my @seen_adj = keys %{ $derivation{verb2adj}{$verb_tlemma} };

    return @seen_adj if @seen_adj;

    # otherwise guessing rules
    if ((   $verb_tlemma    =~ s/slet$/šlený/
            or $verb_tlemma =~ s/dit$/zený/
            or $verb_tlemma =~ s/nit$/něný/
            or $verb_tlemma =~ s/stit$/štěný/
            or $verb_tlemma =~ s/tit$/cený/
            or $verb_tlemma =~ s/ést$/esený/
            or $verb_tlemma =~ s/out$/utý/
            or $verb_tlemma =~ s/cet$/cený/
            or $verb_tlemma =~ s/it$/ený/
            or $verb_tlemma =~ s/ít$/itý/
            or $verb_tlemma =~ s/t$/ný/
        )

        #                    		  and do {print "\t\t\tTRY: $verb_tlemma\n";}
        and $morphoLM->forms_of_lemma( $verb_tlemma, { tag_regex => '^A' } )
        )
    {
        return ($verb_tlemma);
    }
    else {
        return ();
    }
}

sub verb2activeadj {    # koupat -> koupajici
    return keys %{ $derivation{verb2activeadj}{ shift() } };
}

sub noun2adj {
    return keys %{ $derivation{noun2adj}{ shift() } };
}

sub verb2noun {
    return keys %{ $derivation{verb2noun}{ shift() } };
}

sub perf2imperf {
    return keys %{ $derivation{perf2imperf}{ shift() } };
}

sub imperf2perf {
    return keys %{ $derivation{imperf2perf}{ shift() } };
}

sub derive {
    my ( $type, $input ) = @_;
    return eval "$type('$input')";
}

1;

__END__

=pod


=cut

# Copyright 2010 Zdenek Zabokrtsky
# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
