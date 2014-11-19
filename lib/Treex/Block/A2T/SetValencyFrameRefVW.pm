package Treex::Block::A2T::SetValencyFrameRefVW;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;
use Treex::Block::Print::VWForValencyFrames;
use Treex::Tool::ML::VowpalWabbit::CsoaaLdfClassifier;

extends 'Treex::Core::Block';

has '+language' => ( required => 1 );

has 'valency_dict_name' => ( is => 'ro', isa => 'Str', required => 1 );

has 'valency_dict_prefix' => ( is => 'ro', isa => 'Str', default => '' );

has 'sempos_filter' => ( is => 'ro', isa => 'Str', default => '' );

has 'model_file' => ( is => 'ro', isa => 'Str', required => 1 );

has 'features_file' => ( is => 'ro', isa => 'Str', required => 1 );

has '_valframe_feats' => ( is => 'rw' );

has '_classif' => ( is => 'rw' );

sub process_start {

    my ($self) = @_;

    my $classif = Treex::Tool::ML::VowpalWabbit::CsoaaLdfClassifier->new( { model_path => $self->model_file } );
    $self->_set_classif($classif);

    my $valframe_feats = Treex::Block::Print::VWForValencyFrames->new(
        {
            language          => $self->language,
            features_file     => $self->features_file,
            valency_dict_name => $self->valency_dict_name,
        }
    );
    $self->_set_valframe_feats($valframe_feats);

    return;
}

sub process_ttree {

    my ( $self, $troot ) = @_;

    # apply sempos filter
    my $sempos_filter = $self->sempos_filter;
    my @tnodes        = grep {
        my $sempos = $_->gram_sempos // '';
        $sempos =~ /$sempos_filter/
    } $troot->get_descendants( { ordered => 1 } );

    return if ( !@tnodes );    # no nodes passed the filter in this sentence

    for ( my $i = 0; $i < @tnodes; ++$i ) {

        $tnodes[$i]->set_val_frame_rf();    # force-undef the valency frame beforhand to enable predicting 1st frame

        my ( $feat_str, $frame_id ) = $self->_valframe_feats->get_feats_and_class( $tnodes[$i] );
        $frame_id = $frame_id // '';

        $tnodes[$i]->wild->{val_frame_set} = 'VALLEX-1st';
        if ($feat_str) {
            my $predicted = $self->_classif->classify($feat_str);
            if ($predicted) {
                $frame_id = $predicted;
                $tnodes[$i]->wild->{val_frame_set} = 'ML';
            }
        }

        if ( $frame_id ne '' and $frame_id !~ /#/ and $self->valency_dict_prefix ) {
            $frame_id = $self->valency_dict_prefix . $frame_id;
        }
        $tnodes[$i]->set_val_frame_rf($frame_id);
    }
    return;
}

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::A2T::SetValencyFrameRefVW

=head1 DESCRIPTION

TODO

=head1 PARAMETERS

=head2 sempos_filter

Use this parameter if you want to set valency frames eg. for verbs only
(sempos_filter=v). The filter is a regexp on the gram/sempos attribute of t-nodes.
The default is empty, ie. all nodes will be allowed to the classification.

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2014 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
