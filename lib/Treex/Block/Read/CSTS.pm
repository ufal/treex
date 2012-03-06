package Treex::Block::Read::CSTS;
use Moose;
use Treex::Core::Common;
extends 'Treex::Block::Read::BasePMLReader';

use Treex::PML::Factory;
use Treex::PML::Instance;

has '+_layers' => ( default => sub { ['a'] } );
has '+_file_suffix' => ( default => '\.csts(\.gz)?$' );

has language => ( isa => 'Treex::Type::LangCode', is => 'ro', required => 1 );

# We actually don't need any schemas for CSTS
has '+schema_dir' => ( required => 0 );

sub BUILD {
    Treex::PML::AddBackends(qw(CSTS));
}

override '_load_all_files' => sub {

    my ( $self, $base_filename ) = @_;
    my %pmldoc;
    my $filename = $base_filename;

    # TODO possibly try also '.cst' as an extension
    if ( !-e $filename ) {
        $filename .= '.csts';
    }
    if ( !-e $filename ) {
        $filename .= '.gz';
    }
    if ( !-e $filename ) {
        $filename =~ s/\.csts\.gz/.gz/;
    }
    log_info "Loading $filename";
    $pmldoc{a} = $self->_pmldoc_factory->createDocumentFromFile($filename);
    return \%pmldoc;
};

override '_create_val_refs' => sub {
    return;
};

override '_convert_all_trees' => sub {

    my ( $self, $pmldoc, $document ) = @_;

    foreach my $tree_number ( 0 .. ( $pmldoc->{a}->trees - 1 ) ) {

        my $bundle = $document->create_bundle;
        my $zone = $bundle->create_zone( $self->language, $self->selector );

        my $aroot = $zone->create_atree;
        $self->_convert_atree( $pmldoc->{a}->tree($tree_number), $aroot );

        $zone->set_sentence( $aroot->get_subtree_string );
    }
    return;
};

Readonly my $PML2CSTS => {
    'ord'            => 'sentord',
    'no_space_after' => 'nospace',
};

override '_convert_atree' => sub {
    my ( $self, $pml_node, $treex_node ) = @_;

    # copy attributes

    foreach my $attr_name ( 'ord', 'afun', 'no_space_after', 'form' ) {

        my $csts_attr_name = $PML2CSTS->{$attr_name} // $attr_name;

        if ( defined( $pml_node->attr($csts_attr_name) ) ) {
            $self->_copy_attr( $pml_node, $treex_node, $csts_attr_name, $attr_name );
        }
    }

    # lemma (golden or automatic)
    if ( defined( $pml_node->attr('lemma') ) ) {
        $self->_copy_attr( $pml_node, $treex_node, 'lemma', 'lemma' );
    }
    elsif ( defined( $pml_node->attr('lemauto') ) ) {
        $self->_copy_attr( $pml_node, $treex_node, 'lemauto', 'lemma' );
    }

    # tag (golden or automatic)
    if ( defined( $pml_node->attr('tag') ) ) {
        $self->_copy_attr( $pml_node, $treex_node, 'tag', 'tag' );
    }
    elsif ( defined( $pml_node->attr('tagauto') ) ) {
        $self->_copy_attr( $pml_node, $treex_node, 'tagauto', 'tag' );
    }

    # member
    if ( ( $pml_node->attr('memberof') // '' ) =~ m/^(CO|AP)$/ ) {
        $treex_node->set_is_member(1);
    }

    # parenthesis
    if ( ( $pml_node->attr('parenthesis') // '' ) eq 'PA' ) {
        $treex_node->set_is_parenthesis_root(1);
    }

    # recurse deeper
    foreach my $pml_child ( $pml_node->children ) {
        my $treex_child = $treex_node->create_child;
        $self->_convert_atree( $pml_child, $treex_child );
    }
    return;
};

1;

__END__

=head1 NAME

Treex::Block::Read::PDT

=head1 DESCRIPTION

Reads from the PDT 1.0 / Czech morphology CSTS data format using L<Treex::PML::Backend::CSTS>.

Only a-layer attributes are saved, as t-layer attributes seem to never have actually been used. Possible 
morphological analyses are lost since there's no place for them in the Treex file format, only the true 
tag (automatic/golden) is retrieved.   

The L<Treex::PML::Backend::CSTS> module itself depends on the presence of the C<nsgmls> program
on the system. Please install the C<sp> package if you don't have C<nsgmls> installed.

=head1 NOTES

=over

=item * 

The SGML parsing is kinda slow

=item * 

There are many attributes of CSTS that I don't know what they're for, so they're left unnoticed.

=back

=head1 AUTHOR

Ondřej Dušek <odusek@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2012 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
