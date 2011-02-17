package Treex::Core::Block;
use Moose;
use Treex::Moose;
use Treex::Core::Resource;

has selector => ( is => 'ro', isa => 'Selector', default => '', );
has language => ( is => 'ro', isa => 'Maybe[LangCode]', builder => 'build_language' );
has scenario => (
    is       => 'ro',
    isa      => 'Treex::Core::Scenario',
    writer   => '_set_scenario',
    weak_ref => 1,
);

# If the block name contains language (e.g. W2A::EN::Tokenize contains "en")
# or target-language (e.g. T2T::CS2EN::FixNEgation contains "en"),
# it is returned as a default value of the attribute $self->language
# so it is not necessary to write the line
#   has '+language' => ( default => 'en' );
# in all *::EN::* blocks and all *::??2EN::* blocks.
sub build_language {
    my $self = shift;
    pos_validated_list (\@_);

    my ($lang) = $self->get_block_name() =~ /::(?:[A-Z][A-Z]2)?([A-Z][A-Z])::/;
    if ( $lang && Treex::Moose::is_lang_code( lc $lang ) ) {
        return lc $lang;
    }
    else {
        return undef;
    }
}

# TODO
# has robust => ( is=> 'ro', isa=>'Bool', default=>0,
#                 documentation=>'no fatal errors in robust mode');

sub BUILD {
    my $self = shift;
    pos_validated_list (\@_);

    foreach my $rel_path_to_file ( $self->get_required_share_files ) {
        Treex::Core::Resource::require_file_from_share( $rel_path_to_file, 'the block ' . $self->get_block_name );
    }

    return;
}

sub get_required_share_files {
    my $self = shift;
    pos_validated_list (\@_);
    return ();
}

sub process_document {
    my $self = shift;
    my ($document) = pos_validated_list (
        \@_,
        { isa => 'Treex::Core::Document' },
    );

    if ( !$document->get_bundles() ) {
        log_fatal "There are no bundles in the document and block " . ref($self) .
            " doesn't override the method process_document";
    }
    foreach my $bundle ( $document->get_bundles() ) {
        $self->process_bundle($bundle);
    }
    return 1;
}

sub process_bundle {
    my $self = shift;
    my ($bundle) = pos_validated_list (
        \@_,
        { isa => 'Treex::Core::Bundle' },
    );

    log_fatal "Parameter language was not set and block " . ref($self)
        . " doesn't override the method process_bundle" if !$self->language;
    my $zone = $bundle->get_zone( $self->language, $self->selector );
    log_fatal(
        "Zone (lang="
            . $self->language
            . ", selector="
            . $self->selector
            . ") was not found in a bundle and block " . ref($self)
            . " doesn't override the method process_bundle"
        )
        if !$zone;
    return $self->process_zone($zone);
}

sub _try_process_layer {
    my $self = shift;
    my ($zone, $layer) = pos_validated_list (
        \@_,
        { isa => 'Treex::Core::Zone' },
        { isa => 'Layer' },
    );
    
    return 0 if !$zone->has_tree($layer);
    my $tree = $zone->get_tree($layer);
    my $meta = $self->meta;

    if ( my $m = $meta->find_method_by_name("process_${layer}tree") ) {
        ##$self->process_atree($tree);
        $m->execute( $self, $tree );
        return 1;
    }

    if ( my $m = $meta->find_method_by_name("process_${layer}node") ) {
        foreach my $node ( $tree->get_descendants() ) {
            ##$self->process_anode($node);
            $m->execute( $self, $node );
        }
        return 1;
    }

    return 0;
}

sub process_zone {
    my $self = shift;
    my ($zone) = pos_validated_list (
        \@_,
        { isa => 'Treex::Core::Zone' },
    );
    
    my $overriden;

    for my $layer (qw(a t n p)) {
        $overriden ||= $self->_try_process_layer( $zone, $layer );
    }
    log_fatal "One of the methods /process_(document|bundle|zone|[atnp](tree|node))/ "
        . "must be overriden and the corresponding [atnp] trees must be present in bundles.\n"
        . "The zone '" . $zone->get_label() . "' contains trees ( "
        . ( join ',', map { $_->get_layer() } $zone->get_all_trees() ) . ")."
        if !$overriden;
}

sub get_block_name {
    my $self = shift;
    pos_validated_list (\@_);
    return ref($self);
}

1;

__END__

=head1 NAME

TectoMT::Block !!!!!!!!!!!!! needs to be updated

=head1 SYNOPSIS

 package BlockGroup::My_Block;
 
 use strict; use warnings; use utf8;
 
 use base qw(TectoMT::Block);
 
 sub process_bundle {
    my $self = shift;
    my ($bundle) = pos_validated_list (
        \@_,
        { isa => 'Treex::Core::Bundle' },
    );
    
    # processing
    
 }

=head1 DESCRIPTION

C<TectoMT::Block> is a base class serving as a common ancestor of
all TectoMT blocks.
C<TectoMT::Block> can't be used directly in any scenario.
Use it's descendants which implement method C<process_bundle()>
(or C<process_document()>) instead.

=head1 CONSTRUCTOR

=over 4

=item my $block = BlockGroup::My_Block->new();

Instance of a block derived from TectoMT::Block can be created
by the constructor (optionally, a reference to a hash of block parameters
can be specified as the constructor's argument, see BLOCK PARAMETRIZATION).
However, it is not likely to appear in your code since block initialization
is usually invoked automatically when initializing a scenario.

=back

=head1 METHODS FOR BLOCK EXECUTION

=over 4

=item $block->process_document($document);

Applies the block instance on the given instance of C<TectoMT::Document>.
The default implementation iterates over all bundles in a document
and calls C<process_bundle()>.
So in most cases you don't need to override this method.

=item $block->process_bundle($bundle);

Applies the block instance on the given bundle (C<TectoMT::Bundle>).
This is the method you must implement to make your block working
(unless you override C<process_document()>).

=item $block->process_stream($stream);

Applies the block instance on the given stream (C<TectoMT::Bundle>).


=back

=head1 BLOCK PARAMETRIZATION

=over 4

=item my $block = BlockGroup::My_Block->new({$name1=>$value1,$name2=>$value2...});

Block instances can be parametrized by a hash containing parameter name/value
pairs.

=item my $param_value = $block->get_parameter($param_name);

Parameter values used in block construction can
be revealed by get_parameter method (but cannot be changed).

=back

=head1 MISCEL

=over 4

=item my $block_name = $block->get_block_name();

It returns the name of the block module.

=item my @needed_files = $block->get_required_share_files();

If a block requires some files to be present in the shared part
of TectoMT, their list (with relative paths starting in $TMT_ROOT/share/) can be specified
by redefining by this method. By default, an empty list is returned. Presence
of the files is automatically checked in the block constructor. If some of
the required file is missing, the constructor tries to download it
from http://ufallab.ms.mff.cuni.cz.

This method should be used especially for downloading statistical models,
but not for installed tools or libraries.

 sub get_required_share_files {
#PREPARED FOR PARAM CHECK
    my $self = shift;
    my () = pos_validated_list (
        \@_,
        { isa => '' },
    );
     my $self = shift;
     return (
         'data/models/mytool/'.$self->language.'/features.gz',
         'data/models/mytool/'.$self->language.'/weights.tsv',
     );
 }


=back

=head1 SEE ALSO

L<TectoMT::Node|TectoMT::Node>,
L<TectoMT::Bundle|TectoMT::Bundle>,
L<TectoMT::Document|TectoMT::Document>,
L<TectoMT::Scenario|TectoMT::Scenario>,

=head1 AUTHOR

Zdenek Zabokrtsky <zabokrtsky@ufal.mff.cuni.cz>
Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT

Copyright 2006-2011 Zdenek Zabokrtsky, Martin Popel
This file is distributed under the GNU General Public License v2. See $TMT_ROOT/README

