package Treex::Block::Print::VWVectors;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;
use Treex::Tool::FeatureExtract;

extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.vw' );

has '+language' => ( required => 1 );

has 'features_file' => ( is => 'ro', isa => 'Str', required => 1 );

has '_feat_extract' => ( is => 'rw', default => 0 );

#
#
#

sub BUILD {
    my ($self) = @_;

    $self->_set_feat_extract( Treex::Tool::FeatureExtract->new( { features_file => $self->features_file } ) );
}

sub process_ttree {

    my ( $self, $ttree ) = @_;

    my @tnodes  = $ttree->get_descendants( { ordered => 1 } );
    my $word_id = 1;
    my $sent_id = $ttree->get_document->file_stem . $ttree->get_document->file_number . '##' . $ttree->id;
    $sent_id =~ s/[-_]root$//;

    foreach my $tnode (@tnodes) {

        next if ( $self->should_skip($tnode) );

        # prepare instance tag
        my $inst_id = $self->get_inst_id( $sent_id, $word_id++ );

        # try to get features
        my ($feat_str) = $self->get_feats_and_class( $tnode, $inst_id );

        # if there are features, print them out
        if ($feat_str) {
            print { $self->_file_handle } $feat_str;
        }
    }

    return;
}

sub get_inst_id {
    my ( $self, $sent_id, $word_id ) = @_;

    my $inst_id = '';
    if ( $sent_id and $word_id ) {
        $inst_id = $sent_id . '-' . $word_id;
        $inst_id =~ s/##.*-s/-s/;
        $inst_id .= '=';
    }
    return $inst_id;
}

1;

__END__
