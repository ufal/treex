package Treex::Block::W2A::TagHunPoS;
use Moose;
use Treex::Core::Common;
use Treex::Tool::Tagger::HunPoS;

extends 'Treex::Block::W2A::Tag';

has model => ( isa => 'Str', is => 'ro', lazy_build => 1 );

sub _build_model {
    my ($self) = @_;
    log_fatal "W2A::TagHunPoS requires parameter model (or at least language)" if !$self->language || $self->language eq 'all';
    my $model = 'tagger/hunpostagger/models/' . $self->language . '.model';
    my ($filename) = $self->require_files_from_share($model);
    return $filename;
}

sub _build_tagger{
    my ($self) = @_;
    $self->_args->{model} = $self->model;
    return Treex::Tool::Tagger::HunPoS->new($self->_args);
}



1;


__END__



=encoding utf-8

=head1 Treex::Block::W2A::TagHunPoS

=head1 Available pre-trained models
        
        Model      Language  Summary
        --------------------------------------
        en.model   English   english-wsj-1.0               (see https://code.google.com/archive/p/hunpos/downloads)
        hu.model   Hungarian hungarian-szeged-kr-1.0
        per.model  Persian   TagPer                        (see http://stp.lingfil.uu.se/~mojgan/tagper.html)
        la.model   Latin     Index Thomisticus


=head1 AUTHORS

Christophe Onambélé <christophe.onambele@unicatt.it>


=head1 COPYRIGHT AND LICENSE

Copyright © 2016 by The CIRCSE Research Centre, Università Cattolica del Sacro Cuore (Milan, Italy)

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.