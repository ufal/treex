package Treex::Tool::Factory;

use strict;
use warnings;

use Moose ();
use Moose::Exporter;
use Treex::Tool::Factory::Meta::Class;

Moose::Exporter->setup_import_methods(
    with_meta => [ qw/implementation_does implementation_class_via implementation_service_attr/ ],
    also => 'Moose',
);

sub implementation_does {
    my ($meta, @args) = @_;

    my @roles = ref $args[0] eq 'ARRAY' ? @{ $args[0] } : @args;

    $meta->implementation_roles(\@roles);
    return;
}

sub implementation_class_via {
    my ($meta, $code) = @_;

    $meta->implementation_class_maker($code);
    return;
}

sub implementation_service_attr {
    my ($meta, $attr) = @_;

    $meta->implementation_service_attr($attr);
    return;
}

sub init_meta {
    my ( $self, %options ) = @_;

    Moose->init_meta( %options, metaclass => 'Treex::Tool::Factory::Meta::Class' );

    Moose::Util::MetaRole::apply_base_class_roles(
        for_class => $options{for_class},
        roles     => ['Treex::Tool::Factory::Role'],
    );

    return $options{for_class}->meta();
}

1;
__END__

=head1 NAME

Treex::Tool::Factory - Factory class inspired by MooseX::AbstractFactory

=head1 SYNOPSIS

   use Treex::Tool::Factory;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Tool::Factory,

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
