package Treex::Block::A2T::SetFunctorsVW;

use Moose;
use Treex::Core::Common;
use Treex::Block::Print::VWForFunctors;
use Treex::Tool::ML::VowpalWabbit::CsoaaLdfClassifier;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has 'model_file' => ( is => 'ro', isa => 'Str', required => 1 );

has 'features_file' => ( is => 'ro', isa => 'Str', required => 1 );

has '_feats' => ( is => 'rw' );

has '_classif' => ( is => 'rw' );


sub process_start {

    my ($self) = @_;

    my $classif = Treex::Tool::ML::VowpalWabbit::CsoaaLdfClassifier->new( { model_path => $self->model_file } );
    $self->_set_classif($classif);

    my $feats = Treex::Block::Print::VWForFunctors->new(
        {
            language                => $self->language,
            features_file           => $self->features_file,
        }
    );
    $self->_set_feats($feats);

    return;
}

sub process_tnode {

    my ( $self, $tnode ) = @_;

    # force-undef functor, otherwise the system will think this is the "correct" one
    my $old_functor = $tnode->functor;
    $tnode->set_functor();    

    my ( $feat_str ) = $self->_feats->get_feats_and_class( $tnode );    
    my $predicted = $self->_classif->classify($feat_str);
    if ($predicted) {
        $tnode->set_functor($predicted);
    }
    else {
        $tnode->set_functor($old_functor);  # fallback to "old" functor (should never happen)
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetFunctorsVW

=head1 DESCRIPTION

Setting functors using the VowpalWabbit linear classifier.

=head1 PARAMETERS

=over

=item model_file

Path to a trained VowpalWabbit model file (in share or plain relative/absolute path).

=item features_file

Path to features configuration file (in YAML format).

=back 

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2015 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
