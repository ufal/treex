package Treex::Tool::DerivMorpho::Lexeme;

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
#    isa     => 'Ref',
    trigger => \&_set_source_lexeme_trigger,
    documentation => 'part of speech, single-letter PDT m-layer convention',
);

has 'deriv_type' => (
    is      => 'rw',
    isa     => 'Str',
    documentation => 'type of word-formative derivation',
);

has 'lexeme_creator' => (
    is      => 'rw',
    isa     => 'Str',
    documentation => 'who generated this lexeme',
);

has 'derivation_creator' => (
    is      => 'rw',
    isa     => 'Str',
    documentation => 'who generated the link between this lexeme and its source lexeme',
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
    if (defined $new_source) {
        $new_source->_derived_lexemes->{ $self } = $self;
        weaken( $new_source->_derived_lexemes->{ $self} );
    }
}

sub get_derived_lexemes {
    my ( $self ) = shift;
    return values %{$self->_derived_lexemes};

}

sub get_root_lexeme {
    my ( $self ) = shift;
    my $root_lexeme = $self;
    my %passed;
    while ( $root_lexeme->source_lexeme ) {
        if ($passed{$root_lexeme}) {
            print STDERR "Warning: cycle in derivational relations\n";
            last;
        }
        $passed{$root_lexeme} = 1;
        $root_lexeme = $root_lexeme->source_lexeme;
    }
    return $root_lexeme;
}

1;
