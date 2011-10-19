package Treex::Tool::Coreference::CorefFeatures;
use Moose::Role;

requires 'extract_features';

# TODO following is here just for the time being. it is not abstract enough
requires 'init_doc_features';

sub create_instances {
    my ( $self, $anaph, $ante_cands, $ords ) = @_;


    if (!defined $ords) {
        my @antes_only_cands = grep { $_ != $anaph } @$ante_cands;
        $ords = [ 0 .. @antes_only_cands-1 ];
    }

    my $instances;
    #print STDERR "ANTE_CANDS: " . @$ante_cands . "\n";
    foreach my $cand (@$ante_cands) {
        
        my $features;
        if ($cand == $anaph) {
            $features = $self->extract_features( $anaph );
        }
        else {
            my $ord = shift @$ords;
            $features = $self->extract_features( $anaph, $cand, $ord );
        }

        $instances->{ $cand->id } = $features;
    }
    return $instances;
}


# TODO doc
1;
