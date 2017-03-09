package Treex::Block::W2A::LA::TagTreeTaggerIT;

use strict;
use warnings;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::W2A::TagTreeTagger';


override '_build_model' => sub {
    my ($self) = @_;
    #log_fatal "W2A::TagTreeTagger requires parameter model (or at least language)" if !$self->language || $self->language eq 'all';
    my $model = 'tagger/treetagger/model/laIT.par';
    my ($filename) = $self->require_files_from_share($model);
    return $filename;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::W2A::LA::TagTreeTaggerIT

=head1 DESCRIPTION

This is just a small modification of L<Treex::Block::W2A::LA::TagTreeTaggerIT> which adds the path to the
default model for Latin Index Thomisticus.

=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>

=head1 COPYRIGHT AND LICENSE

Copyright © 2017 by CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan - Italy)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.