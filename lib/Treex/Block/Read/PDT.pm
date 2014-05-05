package Treex::Block::Read::PDT;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BasePMLReader';

use Treex::PML; # Without this, the following use Treex::PML::Instance generates many warnings, e.g. "Can't locate PML.pm"
use Treex::PML::Factory;
use Treex::PML::Instance;

has 't_layer' => ( is => 'rw', isa => 'Bool', default => 1 );
has '+_layers' => ( builder => '_build_layers', lazy_build => 1 );
has '+_file_suffix' => ( default => '\.[at](\.gz)?$' );

has language => ( isa => 'Treex::Type::LangCode', is => 'ro', required=>1 );

sub _build_layers {
    my ($self) = @_;
    return $self->t_layer ? [ 'a', 't' ] : ['a'];
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

    foreach my $tree_number ( 0 .. ( $pmldoc->{a}->trees - 1 ) ) {

        my $bundle = $document->create_bundle;
        my $zone = $bundle->create_zone( $self->language, $self->selector );

        if ( $pmldoc->{t} ) {
            my $troot = $zone->create_ttree;
            $self->_convert_ttree( $pmldoc->{t}->tree($tree_number), $troot, undef );
        }

        my $aroot = $zone->create_atree;
        $self->_convert_atree( $pmldoc->{a}->tree($tree_number), $aroot );

        $zone->set_sentence( $aroot->get_subtree_string );
    }

};

1;

__END__

=head1 Treex::Block::Read::PDT

Import from PDT 2.0 trees.

=head2 Parameters

=over 4

=item schema_dir

Must be set to the directory with corresponding PML schemas.

=item t_layer

Must be set to 0 if t-layer is not available or is not needed.

=back
  
=cut

# Copyright 2011 Ondrej Dusek

# This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README.
