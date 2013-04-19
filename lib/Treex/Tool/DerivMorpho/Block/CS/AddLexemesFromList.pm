package Treex::Tool::DerivMorpho::Block::CS::AddLexemesFromList;
use Moose;
extends 'Treex::Tool::DerivMorpho::Block';

has file => (
    is            => 'ro',
    isa           => 'Str',
    documentation => q(file name to load),
);

has maxlimit => (
    is => 'ro',
    isa => 'Int',
    documentation => q(maximum number of lexemes to create),
);

sub process_dictionary {
    my ($self,$dict) = @_;

    open my $LIST, '<:utf8', $self->file or log_fatal $!;

    my $line;
    while (<$LIST>) {
        $line++;
        last if defined $self->maxlimit and $line > $self->maxlimit;

        my ($long_lemma, $pos) = split;
        my $short_lemma = Treex::Tool::Lexicon::CS::truncate_lemma($long_lemma, 1); # homonym number deleted too
        if ($short_lemma =~ /../ and $short_lemma =~ /[[:lower:]]/) {
            $dict->create_lexeme({
                lemma  => $short_lemma,
                mlemma => $long_lemma,
                pos => $pos,
                lexeme_origin => 'czeng',
            });
        }
    }

    return $dict;
}

1;
