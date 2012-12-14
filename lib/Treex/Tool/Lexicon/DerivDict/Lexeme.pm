package Treex::Tool::Lexicon::DerivDict::Lexeme;

use Moose;
use MooseX::SemiAffordanceAccessor;

use Scalar::Util qw(weaken);

has 'lemma' => (
    is      => 'rw',
    isa     => 'Str',
    documentation => 'basic word form',
);

has 'mlemma' => (
    is      => 'rw',
    isa     => 'Str',
    documentation => 'lemma in the PDT m-layer style, including technical suffices',
);

has 'pos' => (
    is      => 'rw',
    isa     => 'Str',
    documentation => 'part of speech, single-letter PDT m-layer convention',
);

has 'source_lexeme' => (
    is      => 'rw',
    isa     => 'Ref',
    trigger => \&_set_source_lexeme_trigger,
    documentation => 'part of speech, single-letter PDT m-layer convention',
);

has 'deriv_type' => (
    is      => 'rw',
    isa     => 'Str',
    documentation => 'type of word-formative derivation',
);

has '_dictionary' => (
    is      => 'rw',
    isa     => 'Ref',
    documentation => 'the dictionary in which this lexeme is contained',
);

has '_derived_lexemes' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub {{}},
    documentation => 'array of lexemes that point to his one by their source_lexeme references',
);


sub _set_source_lexeme_trigger {
    my ( $self, $new_source, $old_source ) = @_;
    if ( defined $old_source ) {
        delete $old_source->_derived_lexemes->{$self};
    }
    $new_source->_derived_lexemes->{ $self } = $self;
    weaken( $new_source->_derived_lexemes->{ $self} );
}

sub get_derived_lexemes {
    my ( $self ) = shift;
    return values %{$self->_derived_lexemes};

}

1;
