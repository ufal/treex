package Treex::Tool::Lexicon::DerivDict::Dictionary;

use Moose;
use MooseX::SemiAffordanceAccessor;
use Treex::Tool::Lexicon::DerivDict::Lexeme;

has '_lexemes' => (
    is      => 'rw',
    isa     => 'ArrayRef',
    default => sub {[]},
    documentation => 'all lexemes loaded in the dictionary',
);

has '_lemma2lexemes' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {{}},
    documentation => 'an index that maps lemmas to lexeme instances',
);

has '_mlemma2lexeme' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {{}},
    documentation => 'an index that maps lemmas to lexeme instances',
);

sub get_lexemes {
    my $self = shift @_;
    return @{$self->_lexemes};
}

sub create_lexeme {
    my $self = shift @_;
    my $new_lexeme = Treex::Tool::Lexicon::DerivDict::Lexeme->new(@_);
    push @{$self->lexemes}, $new_lexeme;
    if ( $self->_lemma2lexemes->{$new_lexeme->lemma} ) {
        push @{$self->_lemma2lexemes->{$new_lexeme->lemma}}, $new_lexeme;
    }
    else {
        $self->_lemma2lexemes->{$new_lexeme->lemma} = [ $new_lexeme ];
    }
}

sub save {
    my ( $self, $filename ) = @_;
    $self->_set_lexemes( sort {$a->lemma cmp $b->lemma} $self->get_lexemes );

    my $lexeme_number = 0;
    foreach my $lexeme ($self->get_lexemes) {
        $lexeme->{_lexeme_number} = $lexeme_number;
        $lexeme_number++;
    }

    $lexeme_number = 0;
    foreach my $lexeme ($self->get_lexemes) {
        my $source_lexeme_number = $lexeme->source_lexeme ? $lexeme->source_lexeme->{_lexeme_number} : '';
        print join "\t",($lexeme->{_lexeme_number}, $lexeme->lemma, $lexeme->pos, $lexeme->mlemma, $source_lexeme};
        print "\n";
        $lexeme_number++;
    }
}

sub _number2id {

}

sub load {
    my ( $self, $filename ) = @_;

}


1;
