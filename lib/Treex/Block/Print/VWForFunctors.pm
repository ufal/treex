package Treex::Block::Print::VWForFunctors;

use Moose;
use Treex::Core::Common;
use Treex::Tool::Vallex::ValencyFrame;
use Treex::Tool::FeatureExtract;

extends 'Treex::Block::Print::VWVectors';

my $FUNCTORS = [
    'ACMP', 'ACT', 'ADDR', 'ADVS', 'AIM', 'APP', 'APPS', 'ATT', 'AUTH', 'BEN', 'CAUS', 'CM', 
    'CNCS', 'COMPL', 'COND', 'CONFR', 'CONJ', 'CONTRA', 'CONTRD', 'CPHR', 'CPR', 'CRIT', 'CSQ', 
    'DENOM', 'DIFF', 'DIR1', 'DIR2', 'DIR3', 'DISJ', 'DPHR', 'EFF', 'EXT', 'FPHR', 'GRAD', 
    'HER', 'ID', 'INTF', 'INTT', 'LOC', 'MANN', 'MAT', 'MEANS', 'MOD', 'NE', 'OPER', 'ORIG', 
    'PAR', 'PARTL', 'PAT', 'PREC', 'PRED', 'REAS', 'REG', 'RESL', 'RESTR', 'RHEM', 'RSTR', 'SM', 
    'SUBS', 'TFHL', 'TFRWH', 'THL', 'THO', 'TOWH', 'TPAR', 'TSIN', 'TTILL', 'TWHEN', 'VOCAT'
];

# Skip nodes with unset/weird functors
sub should_skip {
    my ( $self, $tnode ) = @_;
    return 1 if ( ( $tnode->functor // '???' ) eq '???' );
    return 0;
}

# Return all features as a VW string + the correct class (or undef, if not available)
# tag each class with its label + optionally sentence/word id, if they are set
sub get_feats_and_class {
    my ( $self, $tnode, $inst_id ) = @_;

    my ($functor) = $tnode->functor;

    # get all features, formatted for VW
    my $feats = $self->_feat_extract->get_features_vw($tnode);

    # TODO make this filtering better somehow
    $feats = [ grep { $_ !~ /^(functor|parent)[=:]/ } @$feats ];

    # format for the output
    my $feat_str = 'shared |S ' . join( ' ', @$feats ) . "\n";

    for ( my $i = 0; $i < @$FUNCTORS; ++$i ) {
        my $cost = '';
        my $tag  = '\'' . ( $inst_id // '' ) . $FUNCTORS->[$i];
        if ($functor) {
            $cost = ':' . ( $FUNCTORS->[$i] eq $functor ? 0 : 1 );
            if ( $FUNCTORS->[$i] eq $functor ) {
                $tag .= '--correct';
            }
        }
        $feat_str .= ( $i + 1 ) . $cost . ' ' . $tag;
        $feat_str .= ' |T functor=' . $FUNCTORS->[$i] . "\n";
    }
    $feat_str .= "\n";
    return ( $feat_str, $functor );
}

1;

__END__
