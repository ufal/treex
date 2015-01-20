package Treex::Block::T2T::TrLAddVariants;
use Moose;
use Treex::Core::Common;

use Treex::Tool::Memcached::Memcached;
use TranslationModel::Static::Model;
use TranslationModel::Combined::Interpolated;

extends 'Treex::Block::T2T::BaseTrLAddVariants';

override 'process_start' => sub {
    my $self = shift;

    super();

    my @interpolated_sequence = ();

    my $use_memcached =  $self->scenario && $self->scenario->runner && $self->scenario->runner->cache && Treex::Tool::Memcached::Memcached::get_memcached_hostname();

    if ( $self->discr_weight > 0 ) {
        my $discr_model = $self->load_model( $self->_model_factory->create_model($self->discr_type), $self->discr_model, $use_memcached );
        push( @interpolated_sequence, { model => $discr_model, weight => $self->discr_weight } );
    }
    
    my $static_model   = $self->load_model( TranslationModel::Static::Model->new(), $self->static_model, $use_memcached );
    push( @interpolated_sequence, { model => $static_model, weight => $self->static_weight } );

    $self->_set_model( TranslationModel::Combined::Interpolated->new( { models => \@interpolated_sequence } ) );
    
    return;
};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::T2T::TrLAddVariants -- add t-lemma translation variants from translation models (language-independent)

=head1 DESCRIPTION

Adding t-lemma translation variants. The selection of variants
is based on the discriminative (discr) and the dictionary (static) model.

=back

=head1 AUTHOR

Michal Novák <mnovak@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
