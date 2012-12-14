package Treex::Tool::Lexicon::DerivDict::Dictionary;

use Moose;
use MooseX::SemiAffordanceAccessor;
use Treex::Tool::Lexicon::DerivDict::Lexeme;

use Treex::Core::Log;

use Scalar::Util qw(weaken);

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
    $new_lexeme->_set_dictionary($self);
    weaken($new_lexeme->{_dictionary}); # to avoid memory leaks due to ref. cycles

    push @{$self->_lexemes}, $new_lexeme;
    if ( $self->_lemma2lexemes->{$new_lexeme->lemma} ) {
        push @{$self->_lemma2lexemes->{$new_lexeme->lemma}}, $new_lexeme;
    }
    else {
        $self->_lemma2lexemes->{$new_lexeme->lemma} = [ $new_lexeme ];
    }
    return $new_lexeme;
}

sub save {
    my ( $self, $filename ) = @_;
    $self->_set_lexemes( [ sort {$a->lemma cmp $b->lemma} $self->get_lexemes ] );

    my $lexeme_number = 0;
    foreach my $lexeme ($self->get_lexemes) {
        $lexeme->{_lexeme_number} = $lexeme_number;
        $lexeme_number++;
    }

    $lexeme_number = 0;
    foreach my $lexeme ($self->get_lexemes) {
        my $source_lexeme_number = $lexeme->source_lexeme ? $lexeme->source_lexeme->{_lexeme_number} : '';
        print join "\t",($lexeme->{_lexeme_number}, $lexeme->lemma, $lexeme->mlemma, $lexeme->pos,
                         ($lexeme->source_lexeme ? $lexeme->source_lexeme->{_lexeme_number} : '-'),
                         $lexeme->deriv_type || '-',
                     );
        print "\n";
        $lexeme_number++;
    }
}

sub _number2id {

}

sub load {
    my ( $self, $filename ) = @_;

}

sub add_derivation {
    my ( $self, $arg_ref ) = @_;
    my ( $source_lexeme, $derived_lexeme, $deriv_type ) =
        map { $arg_ref->{$_} } qw(source_lexeme derived_lexeme deriv_type);

    log_fatal("Undefined source lexeme") if not defined $source_lexeme;
    log_fatal("Undefined derived lexeme") if not defined $derived_lexeme;
    $derived_lexeme->set_source_lexeme($source_lexeme);
    $derived_lexeme->set_deriv_type($deriv_type);
}


1;
