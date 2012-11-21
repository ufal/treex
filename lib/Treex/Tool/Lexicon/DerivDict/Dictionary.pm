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
    if ( $self->_lemma2lexemes{$new_lexeme->lemma} ) {
        push @{$self->_lemma2lexemes{$new_lexeme->lemma}}, $new_lexeme
    }
    else {
        $self->_lemma2lexemes{$new_lexeme->lemma} = [ $new_lexeme ];
    }
}

sub save {
    my ( $self, $filename ) = @_;

}

sub load {
    my ( $self, $filename ) = @_;

}


1;
