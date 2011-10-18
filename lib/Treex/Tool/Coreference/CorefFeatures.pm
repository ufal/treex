package Treex::Tool::Coreference::CorefFeatures;
use Moose::Role;

requires 'extract_features';

# TODO following is here just for the time being. it is not abstract enough
requires 'count_collocations';
requires 'count_np_freq';
requires 'mark_doc_clause_nums';

sub create_binary_instances {
    my ( $self, $anaph, $ante_cands, $ords ) = @_;


    if (!defined $ords) {
        $ords = [ 0 .. @$ante_cands-1 ];
    }

    my $instances;
    #print STDERR "ANTE_CANDS: " . @$ante_cands . "\n";
    for (my $i = 0; $i < @$ante_cands; $i++) {
        my $cand = $ante_cands->[$i];
        my $features = $self->extract_features( $anaph, $cand, $ords->[$i] );
        $instances->{ $cand->id } = $features;
    }
    return $instances;
}

sub create_unary_instance {
    my ($self, $anaph ) = @_;
    
    return $self->extract_features( $anaph );
}

sub create_instances {
    my ( $self, $anaph, $ante_cands, $ords ) = @_;

    my $features = $self->create_binary_instances( $anaph, $ante_cands, $ords );
    $features->{ $anaph->id } = $self->create_unary_instance( $anaph );

    return $features;
}



# TODO doc
1;
