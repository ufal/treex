package Treex::Tool::Lexicon::DerivDict::Lexeme;

use Moose;
use MooseX::SemiAffordanceAccessor;

has 'lemma' => (
    is      => 'rw',
    isa     => 'Str',
    documentation => 'basic word form',
);

has 'lemma' => (
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
    documentation => 'part of speech, single-letter PDT m-layer convention',
);

has 'deriv_type' => (
    is      => 'rw',
    isa     => 'Str',
    documentation => 'type of word-formative derivation',
);



1;
