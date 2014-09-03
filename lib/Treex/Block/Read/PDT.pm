package Treex::Block::Read::PDT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BasePMLReader';

use Treex::PML; # Without this, the following use Treex::PML::Instance generates many warnings, e.g. "Can't locate PML.pm"
use Treex::PML::Factory;
use Treex::PML::Instance;

has 'top_layer' => ( is => 'rw', isa => 'Str', default => 't' );

has '+_layers' => ( builder => '_build_layers', lazy_build => 1 );
has '+_file_suffix' => ( default => '\.[mat](\.gz)?$' );

has language => ( isa => 'Treex::Type::LangCode', is => 'ro', required=>1 );

sub _build_layers {
    my ($self) = @_;
    if ($self->top_layer eq 'm'){
        return ['m'];
    }
    elsif ($self->top_layer eq 'a'){
        return ['a'];
    }
    elsif ($self->top_layer eq 't'){
        return ['t', 'a'];
    }
    else {
        log_fatal('The top_layer parameter must be one of "t", "a", "m"');
    }
}

override '_load_all_files' => sub {

    my ( $self, $base_filename ) = @_;
    my %pmldoc;

    foreach my $layer ( @{ $self->_layers } ) {
        my $filename = "${base_filename}.${layer}";
        if (!-e $filename) {
            $filename .= ".gz";
        }
        log_info "Loading $filename";
        $pmldoc{$layer} = $self->_pmldoc_factory->createDocumentFromFile($filename);
    }
    return \%pmldoc;
};

override '_create_val_refs' => sub {
    my ( $self, $pmldoc, $document ) = @_;

    return if not $pmldoc->{t};

    my $cs_vallex = $pmldoc->{t}->metaData('refnames')->{'vallex'};
    $cs_vallex = $pmldoc->{t}->metaData('references')->{$cs_vallex};

    my ( %refnames, %refs );
    $refnames{'vallex'} = $self->_pmldoc_factory->createAlt( ['v'] );
    $refs{'v'} = $cs_vallex;
    $document->changeMetaData( 'references', \%refs );
    $document->changeMetaData( 'refnames',   \%refnames );
};

override '_convert_all_trees' => sub {

    my ( $self, $pmldoc, $document ) = @_;
    
    # get the number of trees (from either a-layer or m-layer)
    my $trees_count = $pmldoc->{a} // $pmldoc->{m};
    $trees_count = scalar( $trees_count->trees );   

    # convert the trees one-by-one
    foreach my $tree_number ( 0 .. $trees_count - 1 ) {

        my $bundle = $document->create_bundle;
        my $zone = $bundle->create_zone( $self->language, $self->selector );
        my $aroot = $zone->create_atree();
        
        if ( $pmldoc->{m} ) {
            $self->_convert_mtree( $pmldoc->{m}->tree($tree_number), $aroot );
        }
        else {
            if ( $pmldoc->{t} ) {
                my $troot = $zone->create_ttree;
                $self->_convert_ttree( $pmldoc->{t}->tree($tree_number), $troot, undef );
            }
    
            $self->_convert_atree( $pmldoc->{a}->tree($tree_number), $aroot );
        }
    
        $zone->set_sentence( $aroot->get_subtree_string );
    }

};

1;

__END__

=encoding utf-8

=head1 NAME

Treex::Block::Read::PDT

=head1 DESCRIPTION

Importing trees from PDT 2.0/2.5/3.0.

=head1 PARAMETERS

=over

=item schema_dir

Must be set to the directory with corresponding PML schemas.

=item top_layer

The topmost annotation layer to be converted. Must be set to 't', 'a', or 'm'. Defaults to 't'.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011,2014 by Institute of Formal and Applied Linguistics, Charles University in Prague
