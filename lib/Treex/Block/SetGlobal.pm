package Treex::Block::SetGlobal;
use Moose;
use Treex::Moose;
extends 'Treex::Core::Block';

sub BUILD {
    my ( $self, $arg_ref ) = @_;
    my $scenario = $arg_ref->{scenario} or log_fatal "no scenario given";
    while ( my ( $name, $value ) = each %{$arg_ref} ) {
        if ( $name ne 'scenario' ) {
            $scenario->set_global_param( $name, $value );
        }
    }
    return;
}

sub process_document {
    return 1;
}

1;

__END__

=head1 NAME

Treex::Block::SetGlobal

=head1 DESCRIPTION

Special block for setting global parameters in scenarios. E.g., instead of:

 Read::PlainText language=en from=file.txt
 W2A::Tokenize language=en
 W2A::Tag language=en
 ...

you can write:

 SetGlobal language=en
 Read::PlainText from=file.txt
 W2A::Tokenize
 W2A::Tag
 ...

=head1 COPYRIGHT

Copyright 2011 Martin Popel
This file is distributed under the GNU GPL v2 or later. See $TMT_ROOT/README
