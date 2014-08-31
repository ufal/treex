package Treex::Tool::EnglishMorpho::Lemmatizer;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource qw(require_file_from_share);
use File::Slurp;
use utf8;

has 'exceptions_filename' => (
    is       => 'ro',
    init_arg => undef,
    default  => sub {
        return require_file_from_share('/data/models/lemmatizer/en/exceptions.tsv');
    },
);

has 'negation_filename' => (
    is       => 'ro',
    init_arg => undef,
    default  => sub {
        return require_file_from_share('/data/models/lemmatizer/en/negation');
    },
);

has 'exceptions' => (
    is       => 'ro',
    builder  => '_build_exceptions',
    init_arg => undef,
    lazy     => 1,
);

has 'negation' => (
    is       => 'ro',
    builder  => '_build_negation',
    init_arg => undef,
    lazy     => 1,
);

has 'cut_negation' => (
    isa     => 'Bool',
    default => 1,
    reader  => 'cut_negation',
);

has 'lowercase_proper_names' => (
    isa     => 'Bool',
    default => 0,
    reader  => 'lowercase_proper_names',
);

my $V   = qr/[aeiou]/;
my $VY  = qr/[aeiouy]/;
my $C   = qr/[bcdfghjklmnpqrstvwxyz]/;
my $CXY = qr/[bcdfghjklmnpqrstvwxz]/;
my $S   = qr/([sxz]|[cs]h)/;
my $S2  = qr/(ss|zz)/;
my $PRE = qr/(be|ex|in|mis|pre|pro|re)/;

#The most importat sub:
#Input:  word form and POS tag (Penn style)
#Output: lemma and was_negative_prefix
sub lemmatize {
    my ( $self, $word, $tag ) = @_;
    my $negative_prefix = 0;

    if ( ( $tag !~ /^NNP/ || $self->lowercase_proper_names ) && $word ne 'I' ) {
        $word = lc $word;
    }

    my $entry = $self->exceptions->{$tag}{$word};
    if ($entry) {
        return @$entry;

    }
    else {
        if ( $self->cut_negation ) {
            ( $word, $negative_prefix ) = $self->_cut_negative_prefix( $word, $tag );
        }
        return ( $self->_lemmatize_by_rules( $word, $tag ), $negative_prefix );
    }
}

sub _cut_negative_prefix {
    my ( $self, $word, $tag ) = @_;

    # We are interested only in adjectives, adverbs and nouns.
    # English verbs are negated usually by "not" (don't,...).
    # Proper nouns (NNP,NNPS) are also left unchanged (Disney, Intel, Irvin... Non-IBM).
    if ( $tag =~ /^(J.*|R.*|NN|NNS)$/ and $word =~ $self->negation ) {
        $word =~ s/^(un|in|im|non-?|dis-?|il|ir)//;
        return ( $word, 1 );
    }
    return ( $word, 0 );
}

sub _lemmatize_NNS_NNPS {
    my ( $self, $word ) = @_;
    return $word if $word =~ s/men$/man/;          #over 600 words (in BNC)
    return $word if $word =~ s/shoes$/shoe/;
    return $word if $word =~ s/wives$/wife/;
    return $word if $word =~ s/(${C}us)es$/$1/;    #buses bonuses

    return $word if $word =~ s/(${V}se)s$/$1/;
    return $word if $word =~ s/(.${CXY}z)es$/$1/;
    return $word if $word =~ s/(${VY}ze)s$/$1/;
    return $word if $word =~ s/($S2)es$/$1/;
    return $word if $word =~ s/(.${V}rse)s$/$1/;
    return $word if $word =~ s/onses$/onse/;
    return $word if $word =~ s/($S)es$/$1/;

    return $word if $word =~ s/(.$C)ies$/$1y/;     #ponies vs ties
    return $word if $word =~ s/(${CXY}o)es$/$1/;
    return $word if $word =~ s/s$//;
    return $word;
}

sub _lemmatize_VBG {                               ## no critic (Subroutines::ProhibitExcessComplexity) this is complex
    my ( $self, $word ) = @_;
    return $word if $word =~ s/(${CXY}z)ing$/$1/;
    return $word if $word =~ s/(${VY}z)ing$/$1e/;
    return $word if $word =~ s/($S2)ing$/$1/;
    return $word if $word =~ s/($C${V}ll)ing$/$1/;
    return $word if $word =~ s/($C${V}($CXY)\2)ing$/$1/;      #cancel-ling vs call-ing - exception is needed
    return $word if $word =~ s/^($CXY)ing$/$1/;
    return $word if $word =~ s/^($PRE*$C${V}ng)ing$/$1/;
    return $word if $word =~ s/icking$/ick/;
    return $word if $word =~ s/(${C}in)ing$/$1e/;
    return $word if $word =~ s/($C$V[npwx])ing$/$1/;
    return $word if $word =~ s/(qu$V${C})ing$/$1e/;
    return $word if $word =~ s/(u${V}d)ing$/$1e/;
    return $word if $word =~ s/(${C}let)ing$/$1e/;
    return $word if $word =~ s/^($PRE*$C+[ei]t)ing$/$1e/;
    return $word if $word =~ s/([ei]t)ing$/$1/;
    return $word if $word =~ s/($PRE$CXY${CXY}eat)ing$/$1/;
    return $word if $word =~ s/($V$CXY${CXY}eat)ing$/$1e/;
    return $word if $word =~ s/(.[eo]at)ing$/$1/;             #treating vs creating
    return $word if $word =~ s/(.${V}at)ing$/$1e/;
    return $word if $word =~ s/($V$V[cgsv])ing$/$1e/;         #announcing increasing
    return $word if $word =~ s/($V$V$C)ing$/$1/;
    return $word if $word =~ s/(.[rw]l)ing$/$1/;
    return $word if $word =~ s/(.th)ing$/$1e/;
    return $word if $word =~ s/($CXY[cglsv])ing$/$1e/;        #involving
    return $word if $word =~ s/($CXY$CXY)ing$/$1/;            #reporting
    return $word if $word =~ s/uing$/ue/;
    return $word if $word =~ s/($VY$VY)ing$/$1/;
    return $word if $word =~ s/ying$/y/;
    return $word if $word =~ s/(${CXY}o)ing$/$1/;
    return $word if $word =~ s/^($PRE*$C+or)ing$/$1e/;
    return $word if $word =~ s/($C[clt]or)ing$/$1e/;
    return $word if $word =~ s/([eo]r)ing$/$1/;               #offering
    return $word if $word =~ s/ing$/e/;
    return $word;
}

sub _lemmatize_VBD_VBN {                                      ## no critic (Subroutines::ProhibitExcessComplexity) this is complex
    my ( $self, $word ) = @_;
    return $word if $word =~ s/en$/e/;
    return $word if $word =~ s/(${CXY}z)ed$/$1/;
    return $word if $word =~ s/(${VY}z)ed$/$1e/;
    return $word if $word =~ s/($S2)ed$/$1/;
    return $word if $word =~ s/($C${V}ll)ed$/$1/;
    return $word if $word =~ s/($C${V}($CXY)\2)ed$/$1/;       #cancel-led vs call-ed - wordlist is needed
    return $word if $word =~ s/^($CXY)ed$/$1/;
    return $word if $word =~ s/^($PRE*$C${V}ng)ed$/$1/;
    return $word if $word =~ s/icked$/ick/;
    return $word if $word =~ s/(${C}(in|[clnt]or))ed$/$1e/;
    return $word if $word =~ s/($C$V[npwx])ed$/$1/;
    return $word if $word =~ s/^($PRE*$C+or)ed$/$1e/;
    return $word if $word =~ s/([eo]r)ed$/$1/;
    return $word if $word =~ s/(${C})ied$/$1y/;
    return $word if $word =~ s/(qu$V${C})ed$/$1e/;
    return $word if $word =~ s/(u${V}d)ed$/$1e/;
    return $word if $word =~ s/(${C}let)ed$/$1e/;
    return $word if $word =~ s/^($PRE*$C+[ei]t)ed$/$1e/;
    return $word if $word =~ s/([ei]t)ed$/$1/;
    return $word if $word =~ s/($PRE$CXY${CXY}eat)ed$/$1/;
    return $word if $word =~ s/($V$CXY${CXY}eat)ed$/$1e/;
    return $word if $word =~ s/(.[eo]at)ed$/$1/;              #treated vs created
    return $word if $word =~ s/(.${V}at)ed$/$1e/;
    return $word if $word =~ s/($V$V[cgsv])ed$/$1e/;          #announced
    return $word if $word =~ s/($V$V$C)ed$/$1/;
    return $word if $word =~ s/(.[rw]l)ed$/$1/;
    return $word if $word =~ s/(.th)ed$/$1e/;
    return $word if $word =~ s/ued$/ue/;
    return $word if $word =~ s/($CXY[cglsv])ed$/$1e/;         #involved
    return $word if $word =~ s/($CXY$CXY)ed$/$1/;             #reported
    return $word if $word =~ s/($VY$VY)ed$/$1/;
    return $word if $word =~ s/ed$/e/;
    return $word;
}

sub _lemmatize_VBZ {
    my ( $self, $word ) = @_;
    return $word if $word =~ s/(${V}se)s$/$1/;
    return $word if $word =~ s/(.${CXY}z)es$/$1/;
    return $word if $word =~ s/(${VY}ze)s$/$1/;
    return $word if $word =~ s/($S2)es$/$1/;
    return $word if $word =~ s/(.${V}rse)s$/$1/;
    return $word if $word =~ s/onses$/onse/;
    return $word if $word =~ s/($S)es$/$1/;

    return $word if $word =~ s/(.$C)ies$/$1y/;      #tries, relies vs lies
    return $word if $word =~ s/(${CXY}o)es$/$1/;    #does, undergoes
    return $word if $word =~ s/(.)s$/$1/;
    return $word;
}

sub _lemmatize_JJR_RBR {
    my ( $self, $word ) = @_;
    return $word if $word =~ s/([^e]ll)er$/$1/;                           #smaller
    return $word if $word =~ s/($C)\1er$/$1/;                             #bigger
    return $word if $word =~ s/ier$/y/;                                   #earlier
    return $word if $word =~ s/($V$V$C)er$/$1/;                           #weaker
    return $word if $word =~ s/($C$V[npwx])er$/$1/;                       #lower
    return $word if $word =~ s/($V$C)er$/$1e/;                            #nicer wider
    return $word if $word =~ s/([bcdfghjklmpqrstvwxz][cglsv])er$/$1e/;    #larger,stranger vs stronger, younger
    return $word if $word =~ s/([ue])er$/$1e/;                            #freer
    return $word if $word =~ s/er$//;                                     #harder
    return $word;
}

sub _lemmatize_JJS_RBS {
    my ( $self, $word ) = @_;
    return $word if $word =~ s/([^e]ll)est$/$1/;                           #smallest
    return $word if $word =~ s/(.)\1est$/$1/;                              #biggest
    return $word if $word =~ s/iest$/y/;                                   #earliest
    return $word if $word =~ s/($V$V$C)est$/$1/;                           #weakest
    return $word if $word =~ s/($C$V[npwx])est$/$1/;                       #lowest
    return $word if $word =~ s/($V$C)est$/$1e/;                            #nicest widest
    return $word if $word =~ s/([bcdfghjklmpqrstvwxz][cglsv])est$/$1e/;    #largest vs strongest
    return $word if $word =~ s/(.{3,})est$/$1/;                            #hardest
    return $word;
}

sub _lemmatize_by_rules {
    my ( $self, $word, $tag ) = @_;

    my $lemma = $tag =~ /NNP?S/
        ? $self->_lemmatize_NNS_NNPS($word)
        : $tag =~ /^VBG/   ? $self->_lemmatize_VBG($word)
        : $tag =~ /VB[DN]/ ? $self->_lemmatize_VBD_VBN($word)
        : $tag eq 'VBZ' ? $self->_lemmatize_VBZ($word)
        : $tag =~ /JJR|RBR/ ? $self->_lemmatize_JJR_RBR($word)
        : $tag =~ /JJS|RBS/ ? $self->_lemmatize_JJS_RBS($word)
        : $word
        ;
    return $word if $lemma eq '';    # Otherwise e.g. "est"->""
    return $lemma;
}

sub _build_exceptions {
    my $self = shift;
    my %exceptions;
    log_debug( $self->exceptions_filename );
    open my $ex_file, "<:encoding(utf-8)", $self->exceptions_filename or log_fatal($!);
    while (<$ex_file>) {
        chomp;
        my ( $word, $tag, $lemma, $negative_prefix ) = split /\t/;

        $negative_prefix = ( defined $negative_prefix and $negative_prefix eq '1' );
        $exceptions{$tag}{$word} = [ $lemma, $negative_prefix ];
    }
    close $ex_file;
    return \%exceptions;
}

sub _build_negation {
    my $self    = shift;
    my $pattern = '';
    my @lines   = read_file( $self->negation_filename, binmode => ':encoding(utf-8)', err_mode => 'log_fatal' );

    # or log_fatal('Cannot load lemmatization exceptions from ' . $self->negation_filename);
    chomp(@lines);
    $pattern = join '|', @lines;

    #$pattern =~ s/-/\-/g;
    my $negation = qr/^($pattern)/;
    return $negation;
}

1;

__END__

Cutting off negative prefixes is quite discutable.
Even if we filter out cases when:
a) a word starts with (un|in|im|dis|il|ir) but it is not a prefix (Intel, disaster,...)
b) it is a prefix but not negative (indoor, impress,...)
Still there are other cases, when etymologicaly it is a negative prefix, but...
unease, uneasily, uneasiness,... is definitelly not a negation of ease, easily, easiness

indiscriminately ??
indiscriminate ??

=pod

=head1 NAME

Treex::Tool::EnglishMorpho::Lemmatizer - rule based lemmatizer for English

=head1 SYNOPSIS

 use Treex::Tool::EnglishMorpho::Lemmatizer;
 my $lemmatizer    = Treex::Tool::EnglishMorpho::Lemmatizer->new();
 my ($word,  $tag) = qw( goes VBZ );
 my ($lemma, $neg) = $lemmatizer->lemmatize($word, $tag);
 # $lemma = 'go', $neg = 0
 ($lemma, $neg) = $lemmatizer->lemmatize('unhappy', 'JJ');
 # $lemma = 'happy', $neg = 1

=head1 METHODS

=over 4

=item lemmatize

Accepts pair of word and tag.
Produces pair with its lemma and indication if word was negation

=back

=head1 DESCRIPTION

Covers:

=over

=item * noun -s (dogs -> dog, ponies -> pony,..., mice -> mouse)

=item * verb -s (does -> do,...)

=item * verb -ing

=item * verb -ed, -en

=item * adjective/adverb -er

=item * adjective/adverb -est

=item * cut off negative prefixes (un|in|im|non|dis|il|ir)

=back

=head2 Input requirements

=over

=item Tokenization

I<doesn't> should be tokenized as two words: I<does> and I<n't>
(It will be lemmatized as I<do> and I<not>).

=item Tagging

Correct tagging (Penn style) is quite crucial for Lemmatizer to work.
For example it doesn't change words with tags NN and NNP
(it changes only NNS and NNPS). So (I<pence>, NN) -> I<pence>,
but (I<pence>, NNS) -> I<penny>.

=back

=head2 Differences from the previous implementation

Modul C<PEDT::MorphologyAnalysis> uses Morpha (written in Flex)
and in some cases gives different lemmatization.

=over

=item Adverbs and adjectives.

Morpha leaves comparatives and superlatives unchanged.
C<PEDT::MorphologyAnalysis> does only basic analysis (I<later> -> I<lat>).

=item Capitalization of proper names

=item Changes of NN

=item Latin words

Declination of words with latin origin is not covered by any Lemmatizer
rules on purpose.
There are few widely known english words with latin origin which are
(or should be) covered by exception files (f.e. indices NNS -> index).
In my opinion, it is better, especially for translation purposes,
to leave the other latin words unchanged. Mostly they will have the same
form also in the target language (biological terms like Spheniscidae).
BTW: Errors made by Morpha latin fallbacks are sometimes funny:
sci-fi -> sci-fus, Mitsubishi -> mitsubishus, Shanghai -> shanghaus,...

=back

=head1 TODO

=over

=item * this POD documentation !!!

=item * better list of exceptions

=item * change exceptions format from tsv to stored perl hash

=back

=head1 AUTHOR

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright © 2008 - 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

