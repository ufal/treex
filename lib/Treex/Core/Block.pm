package Treex::Core::Block;
use Moose;
use Treex::Core::Common;
use Treex::Core::Resource;

has selector => ( is => 'ro', isa => 'Treex::Type::Selector',        default => '', );
has language => ( is => 'ro', isa => 'Maybe[Treex::Type::LangCode]', builder => 'build_language' );
has scenario => (
    is       => 'ro',
    isa      => 'Treex::Core::Scenario',
    writer   => '_set_scenario',
    weak_ref => 1,
);

has grep_bundle => (
    is            => 'ro',
    isa           => 'Int',                                            # or regex in future?
    default       => 0,
    documentation => 'apply process_bundle only on the n-th bundle,'
        . ' 0 (default) means apply to all bundles. Useful for debugging.',
);

# If the block name contains language (e.g. W2A::EN::Tokenize contains "en")
# or target-language (e.g. T2T::CS2EN::FixNegation contains "en"),
# it is returned as a default value of the attribute $self->language
# so it is not necessary to write the line
#   has '+language' => ( default => 'en' );
# in all *::EN::* blocks and all *::??2EN::* blocks.
sub build_language {
    my $self = shift;
    my ($lang) = $self->get_block_name() =~ /::(?:[A-Z][A-Z]2)?([A-Z][A-Z])::/;
    if ( $lang && Treex::Core::Types::is_lang_code( lc $lang ) ) {
        return lc $lang;
    }
    else {
        return;
    }
}

sub zone_label {
    my ($self) = @_;
    my $label = $self->language or return;
    if ( defined $self->selector && $self->selector ne '' ) {
        $label .= '_' . $self->selector;
    }
    return $label;
}

# TODO
# has robust => ( is=> 'ro', isa=>'Bool', default=>0,
#                 documentation=>'no fatal errors in robust mode');

sub BUILD {
    my $self = shift;
    $self->require_files_from_share( $self->get_required_share_files() );
    return;
}

sub require_files_from_share {
    my ( $self, @rel_paths ) = @_;
    my $my_name = 'the block ' . $self->get_block_name();
    foreach my $rel_path (@rel_paths) {
        Treex::Core::Resource::require_file_from_share( $rel_path, $my_name );
    }
    return;
}

sub get_required_share_files {
    my ($self) = @_;

    # By default there are no required share files.
    # The purpose of this method is to be overriden if needed.
    return ();
}

sub process_document {
    my $self = shift;
    my ($document) = pos_validated_list(
        \@_,
        { isa => 'Treex::Core::Document' },
    );

    if ( !$document->get_bundles() ) {
        log_fatal "There are no bundles in the document and block " . $self->get_block_name() .
            " doesn't override the method process_document";
    }

    my $bundleNo = 1;
    foreach my $bundle ( $document->get_bundles() ) {
        if ( !$self->grep_bundle || $self->grep_bundle == $bundleNo ) {
            $self->process_bundle( $bundle, $bundleNo );
        }
        $bundleNo++;
    }
    return 1;
}

sub process_bundle {
    my ( $self, $bundle, $bundleNo ) = @_;

    log_fatal "Parameter language was not set and block " . $self->get_block_name()
        . " doesn't override the method process_bundle" if !$self->language;
    my $zone = $bundle->get_zone( $self->language, $self->selector );
    log_fatal(
        "Zone (lang="
            . $self->language
            . ", selector="
            . $self->selector
            . ") was not found in a bundle and block " . $self->get_block_name()
            . " doesn't override the method process_bundle"
        )
        if !$zone;
    return $self->process_zone( $zone, $bundleNo );
}

sub _try_process_layer {
    my $self = shift;
    my ( $zone, $layer, $bundleNo ) = @_;

    return 0 if !$zone->has_tree($layer);
    my $tree = $zone->get_tree($layer);
    my $meta = $self->meta;

    if ( my $m = $meta->find_method_by_name("process_${layer}tree") ) {
        ##$self->process_atree($tree);
        $m->execute( $self, $tree, $bundleNo );
        return 1;
    }

    if ( my $m = $meta->find_method_by_name("process_${layer}node") ) {
        foreach my $node ( $tree->get_descendants() ) {
            ##$self->process_anode($node);
            $m->execute( $self, $node, $bundleNo );
        }
        return 1;
    }

    return 0;
}

sub process_zone {
    my ( $self, $zone, $bundleNo ) = @_;

    my $overriden;

    for my $layer (qw(a t n p)) {
        $overriden ||= $self->_try_process_layer( $zone, $layer, $bundleNo );
    }
    log_fatal "One of the methods /process_(document|bundle|zone|[atnp](tree|node))/ "
        . "must be overriden and the corresponding [atnp] trees must be present in bundles.\n"
        . "The zone '" . $zone->get_label() . "' contains trees ( "
        . ( join ',', map { $_->get_layer() } $zone->get_all_trees() ) . ")."
        if !$overriden;
    return;
}

sub process_end {
    my ($self) = @_;
    # default implementation is empty, but can be overriden
    return;
}

sub get_block_name {
    my $self = shift;
    return ref($self);
}

1;

__END__

=for Pod::Coverage BUILD build_language

=encoding utf-8

=head1 NAME

Treex::Core::Block - the basic data-processing unit in the Treex framework

=head1 SYNOPSIS

 package Treex::Block::My::Block;
 use Moose;
 use Treex::Core::Common;
 extends 'Treex::Core::Block';
 
 sub process_bundle {
    my ( $self, $bundle) = @_;
 
    # bundle processing
 
 }

=head1 DESCRIPTION

C<Treex::Core::Block> is a base class serving as a common ancestor of
all Treex blocks.
C<Treex::Core::Block> can't be used directly in any scenario.
Use it's descendants which implement one of the methods
C<process_document()>, C<process_bundle()>, C<process_zone()>,
C<process_[atnp]tree()> or C<process_[atnp]node()>.


=head1 CONSTRUCTOR

=over 4

=item my $block = Treex::Block::My::Block->new();

Instance of a block derived from C<Treex::Core::Block> can be created
by the constructor (optionally, a reference to a hash of block parameters
can be specified as the constructor's argument, see L</BLOCK PARAMETRIZATION>).
However, it is not likely to appear in your code since block initialization
is usually invoked automatically when initializing a scenario.

=back

=head1 METHODS FOR BLOCK EXECUTION

You must override one of the following methods:

=over 4

=item $block->process_document($document);

Applies the block instance on the given instance of 
L<Treex::Core::Document>. The default implementation 
iterates over all bundles in a document and calls C<process_bundle()>. So in 
most cases you don't need to override this method.

=item $block->process_bundle($bundle);

Applies the block instance on the given bundle 
(L<Treex::Core::Bundle>).

=item $block->process_zone($zone);

Applies the block instance on the given bundle zone 
(L<Treex::Core::BundleZone>). Unlike 
C<process_document> and C<process_bundle>, C<process_zone> requires block 
attribute C<language> (and possibly also C<selector>) to be specified.

=item $block->process_end();

This method is called after all documents are processed.
The default implementation is empty, but derived classes can override it
to e.g. print some final summaries, statistics etc.
Overriding this method is preferable to both
standard Perl END blocks (where you cannot access C<$self> and instance attributes),
and DEMOLISH (which is not called in some cases, e.g. C<treex --watch>).

=back

=head1 BLOCK PARAMETRIZATION

=over 4

=item my $block = BlockGroup::My_Block->new({$name1=>$value1,$name2=>$value2...});

Block instances can be parametrized by a hash containing parameter name/value
pairs.

=item my $param_value = $block->get_parameter($param_name);

Parameter values used in block construction can
be revealed by C<get_parameter> method (but cannot be changed).

=back

=head1 MISCEL

=over 4

=item my $langcode_selector = $block->zone_label();

=item my $block_name = $block->get_block_name();

It returns the name of the block module.

=item my @needed_files = $block->get_required_share_files();

If a block requires some files to be present in the shared part of Treex, 
their list (with relative paths starting in 
L<Treex::Core::Config->share_dir|Treex::Core::Config/share_dir>) can be 
specified by redefining by this method. By default, an empty list is returned. 
Presence of the files is automatically checked in the block constructor. If 
some of the required file is missing, the constructor tries to download it 
from L<http://ufallab.ms.mff.cuni.cz>.

This method should be used especially for downloading statistical models,
but not for installed tools or libraries.

 sub get_required_share_files {
     my $self = shift;
     return (
         'data/models/mytool/'.$self->language.'/features.gz',
         'data/models/mytool/'.$self->language.'/weights.tsv',
     );
 }

=item require_files_from_share()

This method checks existence of files given as parameters, it tries to download them if they are not present

=back

=head1 SEE ALSO

L<Treex::Core::Node>,
L<Treex::Core::Bundle>,
L<Treex::Core::Document>,
L<Treex::Core::Scenario>,

=head1 AUTHOR

Zdeněk Žabokrtský <zabokrtsky@ufal.mff.cuni.cz>

Martin Popel <popel@ufal.mff.cuni.cz>

=head1 COPYRIGHT AND LICENSE

Copyright © 2011 by Institute of Formal and Applied Linguistics, Charles University in Prague

This module is free software; you can redistribute it and/or modify it under the same terms as Perl itself.
