package Treex::Block::Util::SetGlobal;

use Moose;
use Treex::Core::Common;
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

=pod

=encoding utf-8

=head1 NAME

Treex::Block::Util::SetGlobal

=head1 DESCRIPTION

Special block for setting global parameters in scenarios. E.g., instead of:

 Read::PlainText language=en from=file.txt
 W2A::Tokenize language=en
 W2A::Tag language=en
 ...

you can write:

 Util::SetGlobal language=en
 Read::PlainText from=file.txt
 W2A::Tokenize
 W2A::Tag
 ...

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
