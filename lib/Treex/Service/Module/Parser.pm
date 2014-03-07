package Treex::Service::Module::Parser;

use Moose;
use Treex::Core::Loader qw/load_module/;
use Treex::Core::Log;
use namespace::autoclean;

extends 'Treex::Service::Module';

has 'parser' => (
    is => 'ro',
    does => 'Treex::Tool::Parser::Role',
    writer => '_set_parser'
);

sub initialize {
    my ($self, $args_ref) = @_;

    my $parser_name = delete $args_ref->{parser_name};
    my $parser = "Treex::Tool::Parser::$parser_name";
    log_fatal "Can't use service as a parser" if $parser_name eq 'Service';
    load_module($parser);

    $self->_set_parser($parser->new($args_ref));
}

sub process {
    return shift->parser->parse_sentence(@_);
}

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Service::Module::Parser - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Service::Module::Parser;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Service::Module::Parser,

Blah blah blah.

=head2 EXPORT

None by default.

=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Michal Sedlak, E<lt>sedlakmichal@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=head1 BUGS

None reported... yet.

=cut
