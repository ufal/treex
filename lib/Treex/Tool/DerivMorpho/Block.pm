package Treex::Tool::DerivMorpho::Block;

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

sub my_directory {
    my %call_info;
    @call_info{
        qw(pack file line sub has_args wantarray evaltext is_require)
        } = caller(0);
    $call_info{file} =~ s/[^\/]+$//;
    return $call_info{file};
}

sub signature {
    my ( $self ) = @_;
    my $signature = ref($self);
    $signature =~ s/Treex::Tool::DerivMorpho::Block:://;
    return $signature;
}

1;
