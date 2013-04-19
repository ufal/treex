package Treex::Tool::DerivMorpho::Lexeme;

use Moose;
use MooseX::SemiAffordanceAccessor;

sub process_dictionary {
    my ( $self, $dictionary ) = @_;
    foreach my $lexeme ($dictionary->get_lexemes) {
        $self->process_lexeme($lexeme);
    }
}

sub process_lexeme {
    my ( $self, $lexeme ) = @_;
    die "either process_lexeme or process_dictionary must be specified";
}

1;
