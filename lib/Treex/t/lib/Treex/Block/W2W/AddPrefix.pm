package Treex::Block::W2W::AddPrefix;

use Moose;
use Treex::Core::Config;
use Treex::Tool::PrefixerService;
use Treex::Tool::Prefixer;
use namespace::autoclean;

extends 'Treex::Core::Block';

has prefix => (
    is  => 'ro',
    isa => 'Str',
);

has _prefixer => (
    is  => 'ro',
    writer => '_set_prefixer'
);

sub process_start {
    my ($self) = shift;

    my $prefixer = Treex::Core::Config->use_services ?
      Treex::Tool::PrefixerService->new(args => { prefix => $self->prefix })
          : Treex::Tool::Prefixer->new(prefix => $self->prefix);
    $self->_set_prefixer($prefixer);
}

sub process_atree {
    my ( $self, $atree ) = @_;
    my @nodes = $atree->get_descendants({ordered=>1});

    return if !@nodes;

    my $forms_rf = [map { $_->form } @nodes];
    my $prefixed = $self->_prefixer->prefix_words($forms_rf);

    for (@nodes) {
        $_->set_form(shift @$prefixed);
    }

    return;
}


__PACKAGE__->meta->make_immutable;

1;
__END__

=head1 NAME

Treex::Block::W2W::AddPrefix - Perl extension for blah blah blah

=head1 SYNOPSIS

   use Treex::Block::W2W::AddPrefix;
   blah blah blah

=head1 DESCRIPTION

Stub documentation for Treex::t::lib::Treex::Block::W2W::AddPrefix,

Blah blah blah.

=head1 AUTHOR

Michal Sedlak E<lt>sedlak@ufal.mff.cuni.czE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Michal Sedlak

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.2 or,
at your option, any later version of Perl 5 you may have available.

=cut
