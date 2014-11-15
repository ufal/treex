package Treex::Block::Print::VWForValencyFrames;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;
use Treex::Tool::FeatureExtract;

extends 'Treex::Block::Write::BaseTextWriter';

has '+extension' => ( default => '.vw' );

has '+language' => ( required => 1 );

has 'valency_dict_name' => ( is => 'ro', isa => 'Str', default => 'engvallex.xml' );

has 'valency_dict_prefix' => ( is => 'ro', isa => 'Str', default => 'en-v#' );

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

    # Get all needed informations for each node and save it to the ARFF storage
    my @tnodes   = $ttree->get_descendants( { ordered => 1 } );
    my $word_id = 1;
    my $sent_id = $ttree->get_document->file_stem . $ttree->get_document->file_number . '##' . $ttree->id;
    $sent_id =~ s/[-_]root$//;

    foreach my $tnode (@tnodes) {

        # skip non-verbs, verbs with unset valency frame
        next if ( ( ( $tnode->gram_sempos || '' ) ne 'v' ) or ( not $tnode->val_frame_rf ) );
        
        # try to get features
        my ($feat_str) = $self->get_feats_and_class( $tnode, $sent_id, $word_id++ );

        # if there are features (i.e. more different valency frames to predict), print them out
        if ($feat_str) {
            print { $self->_file_handle } $feat_str;
        }
    }

    return;
}

# Return all features as a VW string + the correct class (or undef, if not available)
# tag each class with its label + optionally sentence/word id, if they are set
sub get_feats_and_class {
    my ( $self, $tnode, $sent_id, $word_id ) = @_;

    my ( $class, $classes ) = $self->_get_classes($tnode);
    
    # skip weird cases
    if ( $class and ( not any { $_ eq $class } @$classes ) ) {
        log_warn 'Correct class not found in Vallex for given lemma: ' . $class . ' ' . $tnode->t_lemma . ' ' . $tnode->id . ' // ' . join( ' ', @$classes );
        return ( undef, undef );
    }
    if (@$classes == 1){
        return ( undef, $classes->[0] ); # just return first class if there is nothing to predict
    }

    # get all features, formatted for VW
    my $feats = $self->_feat_extract->get_features_vw($tnode);

    # TODO make this filtering better somehow
    $feats = [ grep { $_ !~ /^(val_frame\.rf|parent|number_of_senses)[=:]/ } @$feats ];

    # prepare instance tag
    my $inst_id = '';
    if ($sent_id and $word_id){
        my $inst_id = $sent_id . '-' . $word_id;
        $inst_id =~ s/##.*-s/-s/;
        $inst_id .= '=';
    }

    # format for the output
    my $feat_str = 'shared |S ' . join( ' ', @$feats ) . "\n";

    for ( my $i = 0; $i < @$classes; ++$i ) {
        my $cost = '';
        my $tag  = '\'' . $inst_id . $classes->[$i];
        if ($class) {
            $cost = ':' . ( $classes->[$i] eq $class ? 0 : 1 );
            if ( $classes->[$i] eq $class ) {
                $tag .= '--correct';
            }
        }
        $feat_str .= ( $i + 1 ) . $cost . ' ' . $tag . ' |T val_frame_rf=' . $classes->[$i] . "\n";
    }
    $feat_str .= "\n";
    return ( $feat_str, $class // $classes->[0] ); # return feature string output + correct or first class
}

# Return possible classes and the right class (or undef, if not defined)
sub _get_classes {
    my ( $self, $tnode ) = @_;
    
    my $lemma = lc $tnode->t_lemma; # TODO how is it with spaces/underscores?
    my $sempos = $tnode->gram_sempos // 'v'; # sempos: default to verbs, use just 1st part
    $sempos =~ s/\..*//;
    
    my (@frames) = Treex::Tool::Vallex::ValencyFrame::get_frames_for_lemma( $self->valency_dict_name, $self->language, $lemma, $sempos );
    my @frame_ids = map { $self->valency_dict_prefix . $_->id } @frames;
    return $tnode->val_frame_rf, \@frame_ids;
}

1;

__END__
