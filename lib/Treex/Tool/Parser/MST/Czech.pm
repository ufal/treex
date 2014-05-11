package Treex::Tool::Parser::MST::Czech;

use Moose;
use Parser::MST::Czech;
use Treex::Core::Config;
use namespace::autoclean;

with 'Treex::Tool::Parser::Role';
with 'Treex::Service::Role'
  if Treex::Core::Config->use_services;


has 'model'        => ( is => 'rw', isa => 'Str' );
has 'model_memory' => ( is => 'rw', isa => 'Str' );

has parser => (
    is  => 'ro',
    isa => 'Parser::MST::Czech',
    writer => 'set_parser'
);

sub initialize {
    my $self = shift;
    return if $self->parser;

    my $parser = Parser::MST::Czech->new({
        ($self->model ? (model => $self->model) : ()),
        ($self->model_memory ? (model_memory => $self->model_memory) : ()),
    });

    $self->set_parser($parser);
}

sub process {
    my $self = shift;
    $self->parser->parse_sentence(@_);
}

sub parse_sentence { shift->process(@_) }

__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Tool::Parser::MST::Czech - Wrapper over Parser::MST::Czech

=head1 SYNOPSIS

   use Treex::Tool::Parser::MST::Czech;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::Tool::Parser::MST::Czech,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
